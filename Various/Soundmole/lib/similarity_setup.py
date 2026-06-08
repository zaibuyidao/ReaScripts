# NoIndex: true
#!/usr/bin/env python3
"""Create and prepare Soundmole's managed CLAP Python environment."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time


STEPS = 4
MIN_PYTHON = (3, 10)
MAX_PYTHON = (3, 12)
WINDOWS_TORCH = {
    "cpu": (
        "torch==2.12.0+cpu",
        "torchvision==0.27.0+cpu",
        "https://download.pytorch.org/whl/cpu",
    ),
    "gpu": (
        "torch==2.11.0+cu128",
        "torchvision==0.26.0+cu128",
        "https://download.pytorch.org/whl/cu128",
    ),
}


def atomic_write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    with tempfile.NamedTemporaryFile(delete=False, dir=path.parent) as temp:
        temp.write(data)
        temp.flush()
        os.fsync(temp.fileno())
        temp_path = Path(temp.name)
    try:
        os.replace(temp_path, path)
    except PermissionError:
        path.write_bytes(data)
        temp_path.unlink(missing_ok=True)


def managed_python(runtime_dir: Path) -> Path:
    if os.name == "nt":
        return runtime_dir / "Scripts" / "python.exe"
    return runtime_dir / "bin" / "python3"


def managed_environment(runtime_dir: Path) -> dict[str, str]:
    env = os.environ.copy()
    cache_root = runtime_dir / "cache"
    env["HF_HOME"] = str(cache_root / "huggingface")
    env["TORCH_HOME"] = str(cache_root / "torch")
    env["PIP_CACHE_DIR"] = str(cache_root / "pip")
    env["PIP_DISABLE_PIP_VERSION_CHECK"] = "1"
    env["PYTHONUNBUFFERED"] = "1"
    return env


def run_logged(command: list[str], log_path: Path, env: dict[str, str]) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8", errors="replace") as log:
        log.write("\n$ " + " ".join(command) + "\n")
        log.flush()
        result = subprocess.run(
            command,
            stdout=log,
            stderr=subprocess.STDOUT,
            env=env,
            check=False,
        )
    if result.returncode != 0:
        last_output = ""
        try:
            lines = [
                line.strip()
                for line in log_path.read_text(
                    encoding="utf-8", errors="replace"
                ).splitlines()
                if line.strip()
            ]
            if lines:
                last_output = lines[-1]
        except OSError:
            pass
        detail = f" Last output: {last_output}" if last_output else ""
        raise RuntimeError(
            f"Command failed with exit code {result.returncode}.{detail} "
            f"See setup log: {log_path}"
        )


def find_model(python: Path, env: dict[str, str]) -> Path:
    command = [
        str(python),
        "-c",
        (
            "import pathlib, laion_clap; "
            "print(pathlib.Path(laion_clap.__file__).parent / "
            "'630k-audioset-best.pt')"
        ),
    ]
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        env=env,
        check=True,
    )
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return Path(lines[-1]) if lines else Path()


def read_runtime_profile(runtime_dir: Path) -> dict[str, str]:
    try:
        value = json.loads(
            (runtime_dir / "soundmole_profile.json").read_text(encoding="utf-8")
        )
        return {str(key): str(item) for key, item in value.items()}
    except (OSError, TypeError, ValueError, json.JSONDecodeError):
        return {}


def verification_code(accelerator: str) -> str:
    return (
        "import json, os, pathlib, sys; "
        "root=pathlib.Path(sys.prefix)/'cache'; "
        "os.environ['HF_HOME']=str(root/'huggingface'); "
        "os.environ['TORCH_HOME']=str(root/'torch'); "
        f"requested={accelerator!r}; "
        "import torch; "
        "device='cpu'; "
        "device=('cuda' if torch.cuda.is_available() else "
        "('mps' if hasattr(torch.backends, 'mps') and "
        "torch.backends.mps.is_available() else '')) if requested=='gpu' else 'cpu'; "
        "assert device, 'GPU profile requires NVIDIA CUDA on Windows or Apple Metal on macOS'; "
        "import laion_clap; "
        "model=laion_clap.CLAP_Module(enable_fusion=False, device=device); "
        "model.load_ckpt(verbose=False); "
        "profile={'accelerator':requested,'device':device,'torch':torch.__version__}; "
        "(pathlib.Path(sys.prefix)/'soundmole_profile.json').write_text("
        "json.dumps(profile, indent=2)+'\\n', encoding='utf-8'); "
        "print('Soundmole CLAP model ready on '+device)"
    )


def setup(
    runtime_dir: Path, status_path: Path, log_path: Path, accelerator: str
) -> None:
    started = time.time()
    base_python = Path(sys.executable).resolve()
    runtime_python = managed_python(runtime_dir)
    env = managed_environment(runtime_dir)
    accelerator = accelerator.lower()
    if accelerator not in {"cpu", "gpu"}:
        raise RuntimeError(f"Unsupported Soundmole accelerator profile: {accelerator}")

    def status(
        state: str,
        processed: int,
        current: str,
        error: str = "",
        model_path: str = "",
    ) -> None:
        atomic_write_json(
            status_path,
            {
                "status": state,
                "processed": processed,
                "total": STEPS,
                "failed": 1 if error else 0,
                "elapsed": round(time.time() - started, 3),
                "current": current,
                "error": error,
                "base_python": str(base_python),
                "python": str(runtime_python),
                "runtime_dir": str(runtime_dir),
                "model_path": model_path,
                "log_path": str(log_path),
                "accelerator_requested": accelerator,
                "accelerator": read_runtime_profile(runtime_dir).get(
                    "accelerator", ""
                ),
                "device": read_runtime_profile(runtime_dir).get("device", ""),
            },
        )

    selected_version = sys.version_info[:2]
    if not (MIN_PYTHON <= selected_version <= MAX_PYTHON):
        raise RuntimeError(
            "Soundmole CLAP currently supports 64-bit Python 3.10 through 3.12. "
            "LAION-CLAP requires NumPy below version 2, whose supported CPython "
            f"range ends at 3.12. Selected Python is {sys.version.split()[0]} "
            f"at {base_python}"
        )
    if struct.calcsize("P") != 8:
        raise RuntimeError(f"Soundmole CLAP setup requires 64-bit Python: {base_python}")

    runtime_dir.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(
        "Soundmole CLAP setup\n"
        f"Base Python: {base_python}\n"
        f"Managed environment: {runtime_dir}\n"
        f"Accelerator profile: {accelerator}\n",
        encoding="utf-8",
    )

    status("running", 0, "Creating Soundmole Python environment")
    run_logged(
        [str(base_python), "-m", "venv", str(runtime_dir)],
        log_path,
        env,
    )
    if not runtime_python.is_file():
        raise RuntimeError(f"Managed Python was not created: {runtime_python}")

    status("running", 1, "Updating Python installation tools")
    run_logged(
        [
            str(runtime_python),
            "-m",
            "pip",
            "install",
            "--upgrade",
            "pip",
            "setuptools",
            "wheel",
        ],
        log_path,
        env,
    )

    status("running", 2, "Installing CLAP and audio dependencies")
    torch_command = [str(runtime_python), "-m", "pip", "install", "--upgrade"]
    if os.name == "nt":
        torch_package, torchvision_package, index_url = WINDOWS_TORCH[accelerator]
        torch_command.extend(
            [torch_package, torchvision_package, "--index-url", index_url]
        )
    else:
        torch_command.extend(["torch", "torchvision"])
    run_logged(torch_command, log_path, env)
    run_logged(
        [
            str(runtime_python),
            "-m",
            "pip",
            "install",
            "--upgrade",
            "numpy<2",
            "transformers<5",
            "laion-clap==1.1.7",
        ],
        log_path,
        env,
    )

    status("running", 3, "Downloading and verifying the CLAP model")
    verify_code = verification_code(accelerator)
    run_logged([str(runtime_python), "-c", verify_code], log_path, env)

    model_path = find_model(runtime_python, env)
    if not model_path.is_file() or model_path.stat().st_size < 1_000_000_000:
        raise RuntimeError(f"CLAP model is missing or incomplete: {model_path}")

    status("done", STEPS, "Soundmole CLAP is ready", model_path=str(model_path))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--accelerator", choices=("cpu", "gpu"), default="cpu")
    args = parser.parse_args()

    runtime_dir = Path(args.runtime).expanduser().resolve()
    status_path = Path(args.status).expanduser().resolve()
    log_path = Path(args.log).expanduser().resolve()
    try:
        setup(runtime_dir, status_path, log_path, args.accelerator)
        return 0
    except Exception as exc:
        try:
            existing: dict[str, object] = {}
            if status_path.is_file():
                existing = json.loads(status_path.read_text(encoding="utf-8"))
            existing.update(
                {
                    "status": "error",
                    "failed": 1,
                    "current": "",
                    "error": str(exc),
                    "log_path": str(log_path),
                    "accelerator_requested": args.accelerator,
                }
            )
            atomic_write_json(status_path, existing)
        except Exception:
            pass
        print(f"Soundmole CLAP setup failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
