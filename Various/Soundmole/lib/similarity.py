#!/usr/bin/env python3
"""Build Soundmole audio embeddings without blocking REAPER's UI."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import time
from typing import Callable, Iterable

import numpy as np


FILE_RE = re.compile(r'^\s*FILE\s+"((?:\\.|[^"])*)"')


def atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(delete=False, dir=path.parent) as temp:
        temp.write(data)
        temp.flush()
        os.fsync(temp.fileno())
        temp_path = Path(temp.name)
    try:
        os.replace(temp_path, path)
    except PermissionError:
        # Some managed Windows environments allow file writes but deny rename.
        # Fall back to a direct write so indexing remains usable.
        path.write_bytes(data)
        try:
            temp_path.unlink(missing_ok=True)
        except OSError:
            pass


def atomic_write_json(path: Path, value: object) -> None:
    data = json.dumps(value, ensure_ascii=False, indent=2).encode("utf-8")
    atomic_write_bytes(path, data + b"\n")


def decode_db_string(value: str) -> str:
    out: list[str] = []
    index = 0
    while index < len(value):
        char = value[index]
        if char == "\\" and index + 1 < len(value) and value[index + 1] in {'\\', '"'}:
            out.append(value[index + 1])
            index += 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


def read_database_paths(db_path: Path) -> list[str]:
    paths: list[str] = []
    seen: set[str] = set()
    with db_path.open("r", encoding="utf-8", errors="replace") as database:
        for line in database:
            match = FILE_RE.match(line)
            if not match:
                continue
            path = decode_db_string(match.group(1))
            key = os.path.normcase(os.path.normpath(path))
            if path and key not in seen:
                seen.add(key)
                paths.append(path)
    return paths


def fingerprint(path: str) -> dict[str, int]:
    stat = os.stat(path)
    return {"size": stat.st_size, "mtime_ns": stat.st_mtime_ns}


def normalized_rows(vectors: np.ndarray) -> np.ndarray:
    vectors = np.asarray(vectors, dtype=np.float32)
    if vectors.ndim == 1:
        vectors = vectors.reshape(1, -1)
    norms = np.linalg.norm(vectors, axis=1, keepdims=True)
    norms[~np.isfinite(norms) | (norms <= 0)] = 1.0
    return vectors / norms


def create_test_embedder() -> tuple[Callable[[list[str]], np.ndarray], str]:
    # Used only by automated/local verification. The UI always requests CLAP.
    dimension = 64

    def embed(paths: list[str]) -> np.ndarray:
        rows = []
        for path in paths:
            digest = hashlib.sha512(Path(path).read_bytes()).digest()
            row = np.frombuffer(digest, dtype=np.uint8).astype(np.float32)
            row = row[:dimension] - 127.5
            rows.append(row)
        return normalized_rows(np.stack(rows))

    return embed, "test-hash"


def create_clap_embedder(model_name: str) -> tuple[Callable[[list[str]], np.ndarray], str]:
    try:
        import laion_clap
    except ImportError as exc:
        raise RuntimeError(
            "CLAP dependency is missing. Install laion-clap into the Python "
            "selected by SOUNDMOLE_PYTHON."
        ) from exc

    model = laion_clap.CLAP_Module(enable_fusion=False)
    if model_name and model_name.upper() != "CLAP" and Path(model_name).is_file():
        model.load_ckpt(str(Path(model_name)))
        resolved_name = str(Path(model_name))
    else:
        model.load_ckpt()
        resolved_name = "CLAP"

    def embed(paths: list[str]) -> np.ndarray:
        vectors = model.get_audio_embedding_from_filelist(
            x=paths, use_tensor=False
        )
        return normalized_rows(np.asarray(vectors, dtype=np.float32))

    return embed, resolved_name


def batches(values: list[str], size: int) -> Iterable[list[str]]:
    for start in range(0, len(values), size):
        yield values[start : start + size]


def load_old_cache(
    sim_dir: Path, expected_model: str
) -> tuple[dict[str, dict[str, int]], dict[str, np.ndarray]]:
    fingerprints_path = sim_dir / "fingerprints.json"
    manifest_path = sim_dir / "manifest.json"
    ids_path = sim_dir / "ids.map"
    vectors_path = sim_dir / "vectors.f32"
    try:
        fingerprints = json.loads(fingerprints_path.read_text(encoding="utf-8"))
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest.get("model") != expected_model:
            return {}, {}
        dimension = int(manifest["dimension"])
        ids = ids_path.read_text(encoding="utf-8").splitlines()
        vectors = np.fromfile(vectors_path, dtype="<f4").reshape(len(ids), dimension)
    except (OSError, ValueError, KeyError, json.JSONDecodeError):
        return {}, {}
    return fingerprints, {path: vectors[index] for index, path in enumerate(ids)}


def build(db_path: Path, model_name: str, batch_size: int) -> None:
    started = time.time()
    sim_dir = db_path.with_suffix(".sim")
    sim_dir.mkdir(parents=True, exist_ok=True)
    status_path = sim_dir / "status.json"

    def status(state: str, processed: int, total: int, failed: int,
               current: str = "", error: str = "") -> None:
        atomic_write_json(
            status_path,
            {
                "status": state,
                "processed": processed,
                "total": total,
                "failed": failed,
                "elapsed": round(time.time() - started, 3),
                "current": current,
                "error": error,
            },
        )

    status("scanning", 0, 0, 0)
    paths = read_database_paths(db_path)
    total = len(paths)
    if total == 0:
        raise RuntimeError("The database contains no FILE records.")

    embed, resolved_model = (
        create_test_embedder()
        if model_name.lower() == "test-hash"
        else create_clap_embedder(model_name)
    )
    old_fingerprints, old_vectors = load_old_cache(sim_dir, resolved_model)
    valid_paths: list[str] = []
    current_fingerprints: dict[str, dict[str, int]] = {}
    failures: list[dict[str, str]] = []
    for path in paths:
        try:
            current_fingerprints[path] = fingerprint(path)
            valid_paths.append(path)
        except OSError as exc:
            failures.append({"path": path, "error": str(exc)})

    reusable: dict[str, np.ndarray] = {}
    pending: list[str] = []
    for path in valid_paths:
        if old_fingerprints.get(path) == current_fingerprints[path] and path in old_vectors:
            reusable[path] = old_vectors[path]
        else:
            pending.append(path)

    vectors_by_path: dict[str, np.ndarray] = dict(reusable)
    processed = len(reusable)
    status("embedding", processed, total, len(failures))

    for group in batches(pending, max(1, batch_size)):
        try:
            embedded = embed(group)
            if embedded.shape[0] != len(group):
                raise RuntimeError("CLAP returned an unexpected batch size.")
            for path, vector in zip(group, embedded):
                vectors_by_path[path] = vector
                processed += 1
        except Exception:
            # Isolate failures so one unsupported/corrupt file does not abort a build.
            for path in group:
                try:
                    vectors_by_path[path] = embed([path])[0]
                    processed += 1
                except Exception as exc:
                    failures.append({"path": path, "error": str(exc)})
        status(
            "embedding", processed, total, len(failures),
            Path(group[-1]).name if group else "",
        )

    ordered_paths = [path for path in valid_paths if path in vectors_by_path]
    if not ordered_paths:
        raise RuntimeError("No embeddings were generated.")
    vectors = normalized_rows(np.stack([vectors_by_path[path] for path in ordered_paths]))
    dimension = int(vectors.shape[1])

    status("writing", len(ordered_paths), total, len(failures))
    atomic_write_bytes(sim_dir / "vectors.f32", vectors.astype("<f4").tobytes())
    atomic_write_bytes(
        sim_dir / "ids.map",
        ("\n".join(ordered_paths) + "\n").encode("utf-8"),
    )
    atomic_write_json(
        sim_dir / "fingerprints.json",
        {path: current_fingerprints[path] for path in ordered_paths},
    )
    atomic_write_json(
        sim_dir / "manifest.json",
        {
            "version": 1,
            "status": "ready",
            "model": resolved_model,
            "backend": "exact-cosine",
            "dimension": dimension,
            "count": len(ordered_paths),
            "database_count": total,
            "failed": len(failures),
            "failures": failures[:100],
            "db_path": str(db_path),
            "updated_at_unix": int(time.time()),
        },
    )
    status("done", len(ordered_paths), total, len(failures))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True)
    parser.add_argument("--model", default="CLAP")
    parser.add_argument("--batch-size", type=int, default=8)
    args = parser.parse_args()

    db_path = Path(args.db).expanduser().resolve()
    sim_dir = db_path.with_suffix(".sim")
    status_path = sim_dir / "status.json"
    try:
        build(db_path, args.model, args.batch_size)
        return 0
    except Exception as exc:
        sim_dir.mkdir(parents=True, exist_ok=True)
        atomic_write_json(
            status_path,
            {
                "status": "error",
                "processed": 0,
                "total": 0,
                "failed": 0,
                "elapsed": 0,
                "current": "",
                "error": str(exc),
            },
        )
        print(f"Soundmole similarity build failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
