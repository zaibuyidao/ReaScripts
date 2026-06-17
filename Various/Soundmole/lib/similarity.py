# NoIndex: true
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
import sqlite3
import sys
import tempfile
import time
from typing import Callable, Iterable

import numpy as np


FILE_RE = re.compile(r'^\s*FILE\s+"((?:\\.|[^"])*)"')
CHECKPOINT_BATCH_SIZE = 64


def configure_certificate_store() -> None:
    if os.name == "nt":
        return

    try:
        import certifi
    except ImportError:
        return

    cert_file = certifi.where()
    if cert_file:
        os.environ.setdefault("SSL_CERT_FILE", cert_file)
        os.environ.setdefault("REQUESTS_CA_BUNDLE", cert_file)
        os.environ.setdefault("CURL_CA_BUNDLE", cert_file)


def configure_model_cache() -> None:
    """Keep model support files inside Soundmole's managed virtual environment."""
    if sys.prefix == sys.base_prefix:
        return
    cache_root = Path(sys.prefix) / "cache"
    os.environ["HF_HOME"] = str(cache_root / "huggingface")
    os.environ["TORCH_HOME"] = str(cache_root / "torch")
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"


def configured_device(torch: object) -> tuple[str, str]:
    profile_path = Path(sys.prefix) / "soundmole_profile.json"
    try:
        profile = json.loads(profile_path.read_text(encoding="utf-8"))
    except (OSError, TypeError, ValueError, json.JSONDecodeError):
        profile = {}
    accelerator = str(profile.get("accelerator", "cpu")).lower()
    if accelerator != "gpu":
        return "cpu", "cpu"
    if torch.cuda.is_available():
        return "cuda", "gpu"
    if (
        hasattr(torch.backends, "mps")
        and torch.backends.mps.is_available()
    ):
        return "mps", "gpu"
    raise RuntimeError(
        "The Soundmole GPU profile is installed, but no compatible GPU is "
        "available. Repair CLAP using the CPU profile or check the GPU driver."
    )


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
            if Path(path).name.startswith("._"):
                continue
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


def create_test_embedder(
) -> tuple[Callable[[list[str]], np.ndarray], str, str, str]:
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

    return embed, "test-hash", "cpu", "cpu"


def create_clap_embedder(
    model_name: str,
) -> tuple[Callable[[list[str]], np.ndarray], str, str, str]:
    configure_certificate_store()
    configure_model_cache()
    try:
        import laion_clap
        import torch
    except ImportError as exc:
        raise RuntimeError(
            "CLAP dependency is missing. Open Soundmole Settings > Similarity "
            "and choose Install or Repair CLAP."
        ) from exc

    device, accelerator = configured_device(torch)
    model = laion_clap.CLAP_Module(enable_fusion=False, device=device)
    if model_name and model_name.upper() != "CLAP" and Path(model_name).is_file():
        model.load_ckpt(str(Path(model_name)))
        resolved_name = str(Path(model_name))
    else:
        model.load_ckpt()
        resolved_name = "CLAP"

    def embed(paths: list[str]) -> np.ndarray:
        with torch.inference_mode():
            vectors = model.get_audio_embedding_from_filelist(
                x=paths, use_tensor=False
            )
        return normalized_rows(np.asarray(vectors, dtype=np.float32))

    return embed, resolved_name, device, accelerator


def batches(values: list[str], size: int) -> Iterable[list[str]]:
    for start in range(0, len(values), size):
        yield values[start : start + size]


class EmbeddingCheckpoint:
    """Persist completed embeddings so large builds can resume after interruption."""

    def __init__(self, sim_dir: Path, model: str) -> None:
        sim_dir.mkdir(parents=True, exist_ok=True)
        self.path = sim_dir / "embedding_checkpoint.sqlite3"
        self.connection = sqlite3.connect(self.path)
        self.connection.execute("PRAGMA journal_mode=WAL")
        self.connection.execute("PRAGMA synchronous=NORMAL")
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS metadata ("
            "key TEXT PRIMARY KEY, value TEXT NOT NULL)"
        )
        self.connection.execute(
            "CREATE TABLE IF NOT EXISTS embeddings ("
            "path TEXT PRIMARY KEY, size INTEGER NOT NULL, "
            "mtime_ns INTEGER NOT NULL, dimension INTEGER NOT NULL, "
            "vector BLOB NOT NULL)"
        )
        stored = self.connection.execute(
            "SELECT value FROM metadata WHERE key = 'model'"
        ).fetchone()
        if not stored or stored[0] != model:
            self.connection.execute("DELETE FROM embeddings")
            self.connection.execute(
                "INSERT OR REPLACE INTO metadata(key, value) VALUES('model', ?)",
                (model,),
            )
            self.connection.commit()
        self.pending: list[tuple[str, int, int, int, bytes]] = []

    def load_reusable(
        self, fingerprints: dict[str, dict[str, int]]
    ) -> dict[str, np.ndarray]:
        reusable: dict[str, np.ndarray] = {}
        for path, size, mtime_ns, dimension, vector in self.connection.execute(
            "SELECT path, size, mtime_ns, dimension, vector FROM embeddings"
        ):
            current = fingerprints.get(path)
            if (
                not current
                or current["size"] != size
                or current["mtime_ns"] != mtime_ns
                or dimension <= 0
                or len(vector) != dimension * 4
            ):
                continue
            reusable[path] = np.frombuffer(vector, dtype="<f4").copy()
        return reusable

    def add(
        self, path: str, fingerprint_value: dict[str, int], vector: np.ndarray
    ) -> None:
        row = np.asarray(vector, dtype="<f4").reshape(-1)
        self.pending.append(
            (
                path,
                fingerprint_value["size"],
                fingerprint_value["mtime_ns"],
                int(row.size),
                row.tobytes(),
            )
        )
        if len(self.pending) >= CHECKPOINT_BATCH_SIZE:
            self.flush()

    def flush(self) -> None:
        if not self.pending:
            return
        self.connection.executemany(
            "INSERT OR REPLACE INTO embeddings"
            "(path, size, mtime_ns, dimension, vector) VALUES(?, ?, ?, ?, ?)",
            self.pending,
        )
        self.connection.commit()
        self.pending.clear()

    def close(self, remove: bool = False) -> None:
        self.flush()
        self.connection.close()
        if remove:
            for suffix in ("", "-wal", "-shm"):
                try:
                    Path(str(self.path) + suffix).unlink(missing_ok=True)
                except OSError:
                    pass


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
    resumed_count = 0
    device = ""
    accelerator = ""
    sim_dir = db_path.with_suffix(".sim")
    sim_dir.mkdir(parents=True, exist_ok=True)
    status_path = sim_dir / "status.json"

    def status(state: str, processed: int, total: int, failed: int,
               current: str = "", error: str = "") -> None:
        elapsed = max(0.0, time.time() - started)
        newly_processed = max(0, processed - resumed_count)
        rate = newly_processed / elapsed if elapsed > 0 else 0.0
        eta = (total - processed) / rate if rate > 0 and total > processed else 0.0
        atomic_write_json(
            status_path,
            {
                "status": state,
                "processed": processed,
                "total": total,
                "failed": failed,
                "elapsed": round(elapsed, 3),
                "rate": round(rate, 3),
                "eta": round(eta, 3),
                "resumed": resumed_count,
                "device": device,
                "accelerator": accelerator,
                "current": current,
                "error": error,
            },
        )

    status("scanning", 0, 0, 0)
    paths = read_database_paths(db_path)
    total = len(paths)
    if total == 0:
        raise RuntimeError("The database contains no FILE records.")

    embed, resolved_model, device, accelerator = (
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

    checkpoint = EmbeddingCheckpoint(sim_dir, resolved_model)
    reusable.update(checkpoint.load_reusable(current_fingerprints))
    pending = [path for path in pending if path not in reusable]
    resumed_count = len(reusable)
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
                checkpoint.add(path, current_fingerprints[path], vector)
                processed += 1
        except Exception:
            # Isolate failures so one unsupported/corrupt file does not abort a build.
            for path in group:
                try:
                    vectors_by_path[path] = embed([path])[0]
                    checkpoint.add(
                        path, current_fingerprints[path], vectors_by_path[path]
                    )
                    processed += 1
                except Exception as exc:
                    failures.append({"path": path, "error": str(exc)})
        status(
            "embedding", processed, total, len(failures),
            Path(group[-1]).name if group else "",
        )

    checkpoint.flush()
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
            "accelerator": accelerator,
            "device": device,
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
    checkpoint.close(remove=True)


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
        existing: dict[str, object] = {}
        try:
            if status_path.is_file():
                existing = json.loads(status_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            pass
        for key, value in {
            "processed": 0,
            "total": 0,
            "failed": 0,
            "elapsed": 0,
            "rate": 0,
            "eta": 0,
            "resumed": 0,
            "device": "",
            "accelerator": "",
        }.items():
            existing.setdefault(key, value)
        existing.update(
            {
                "status": "error",
                "current": "",
                "error": str(exc),
            }
        )
        atomic_write_json(
            status_path,
            existing,
        )
        print(f"Soundmole similarity build failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
