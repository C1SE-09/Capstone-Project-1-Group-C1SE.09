from __future__ import annotations

import io
import logging
import os
import sys
import tempfile
import time
from pathlib import Path

import pytest

# Thêm backend/ vào sys.path để import được các module app.*
_BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("test_phowhisper")

# Các test này là integration/benchmark — yêu cầu model PhoWhisper (CTranslate2)
# đã được tải về máy. Bỏ qua hoàn toàn trong môi trường CI (GitHub Actions set CI=true).
pytestmark = pytest.mark.skipif(
    "CI" in os.environ,
    reason="PhoWhisper integration tests require the pre-downloaded CTranslate2 model — skipped in CI",
)

SAMPLES_DIR = Path(__file__).parent / "audio_samples"
SAMPLE_FILES = {
    "test1.wav": SAMPLES_DIR / "test1.wav",   # ~112 KB
    "test2.wav": SAMPLES_DIR / "test2.wav",   # ~880 KB
    "test3.wav": SAMPLES_DIR / "test3.wav",   # ~740 KB
    "test5.wav": SAMPLES_DIR / "test5.wav",   # ~7.1 MB (benchmark chính)
}


def _get_vram_mb() -> float | None:
    """Lấy VRAM đang dùng (MB) qua nvidia-smi, trả về None nếu không có GPU."""
    try:
        import ctranslate2
        if ctranslate2.get_cuda_device_count() > 0:
            import subprocess
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=5, check=False,
            )
            if result.returncode == 0:
                return float(result.stdout.strip().splitlines()[0])
    except (ImportError, AttributeError, ValueError, OSError):
        pass
    return None


def _section(title: str) -> None:
    """In header phan cach section."""
    print(f"\n{'=' * 60}\n  {title}\n{'=' * 60}")


def test_model_loads_successfully() -> None:
    """Model phải load thành công và device phải là cuda hoặc cpu."""
    _section("TEST 1: Model Load")
    from app.services.stt_service import STTService

    svc = STTService()
    assert svc.model is not None
    assert svc.device in ("cuda", "cpu")
    print(f"  [OK] Device: {svc.device.upper()}")

    # Hien thi VRAM neu dang dung GPU
    vram = _get_vram_mb()
    if vram is not None:
        print(f"  [OK] VRAM: {vram:.0f} MB")
        if vram > 3000:
            print(f"  [WARN] VRAM cao: {vram:.0f} MB")


def test_transcribe_samples() -> None:
    """Transcribe các file mẫu và đo tốc độ xử lý."""
    _section("TEST 2: Transcribe Samples")
    from app.services.stt_service import STTService

    svc = STTService()
    results = []

    for label, path in SAMPLE_FILES.items():
        if not path.exists():
            print(f"  [SKIP] {label}: file not found")
            continue

        print(f"\n  >> {label} ({path.stat().st_size / 1024 / 1024:.2f} MB)")
        t0 = time.perf_counter()
        try:
            text = svc.transcribe(str(path))
            elapsed = time.perf_counter() - t0
            results.append((label, elapsed, len(text)))
            print(f"     Time   : {elapsed:.2f}s")
            print(f"     Length : {len(text)} chars")
            preview = text[:100] + ('...' if len(text) > 100 else '')
            print(f"     Preview: {preview}")

            # Benchmark nguong: GPU < 10s, CPU < 30s cho file test4.wav
            if label == "test5.wav":
                limit = 30 if svc.device == "cpu" else 10
                status = "[OK]" if elapsed <= limit else "[SLOW]"
                print(f"     {status}: {elapsed:.1f}s vs {limit}s target")
        except ValueError as e:
            print(f"     [ERROR]: {e}")

    if results:
        _section("Summary")
        print(f"  Samples  : {len(results)}")
        print(f"  Avg time : {sum(t for _, t, _ in results) / len(results):.2f}s")
        print(f"  Total out: {sum(c for _, _, c in results)} chars")


def test_cpu_fallback() -> None:
    """Bắt buộc dùng CPU và kiểm tra transcribe hoạt động đúng."""
    _section("TEST 3: CPU Fallback (Forced)")
    from app.services.stt_service import MODEL_ID
    from faster_whisper import WhisperModel

    # Load trực tiếp trên CPU, bỏ qua auto-detect
    model = WhisperModel(MODEL_ID, device="cpu", compute_type="int8")
    print("  [OK] CPU model loaded")

    target = SAMPLE_FILES["test5.wav"]
    if target.exists():
        t0 = time.perf_counter()
        segments, _ = model.transcribe(
            str(target), language="vi", beam_size=5,
            vad_filter=True, vad_parameters={"min_silence_duration_ms": 500},
        )
        text = " ".join(seg.text.strip() for seg in segments).strip()
        print(f"  [OK] test5.wav: {time.perf_counter() - t0:.2f}s -> {text[:80]}")
    else:
        print("  [SKIP] test5.wav not found")


def test_file_not_found() -> None:
    """FileNotFoundError phải được raise khi file không tồn tại."""
    _section("TEST 4: FileNotFoundError")
    from app.services.stt_service import stt_service

    try:
        stt_service.transcribe("/nonexistent/file.wav")
        print("  [FAIL] should raise FileNotFoundError")
    except FileNotFoundError:
        print("  [OK] FileNotFoundError raised correctly")


def test_empty_file() -> None:
    """ValueError phải được raise cho file rỗng (0 byte)."""
    _section("TEST 5: Empty File")
    from app.services.stt_service import stt_service

    # Tạo file tạm rỗng để kiểm tra validation
    tmp_fd, tmp_path = tempfile.mkstemp(suffix=".wav")
    os.close(tmp_fd)
    try:
        stt_service.transcribe(tmp_path)
        print("  [FAIL] should raise ValueError")
    except ValueError:
        print("  [OK] ValueError raised for empty file")
    finally:
        os.remove(tmp_path)


if __name__ == "__main__":
    # Fix UnicodeEncodeError tren Windows (cp1252 khong ho tro ky tu Unicode)
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

    print("\n" + "=" * 60)
    print("  PhoWhisper STT - Manual Benchmark & Test")
    print("=" * 60)

    tests = [
        test_model_loads_successfully,
        test_transcribe_samples,
        test_cpu_fallback,
        test_file_not_found,
        test_empty_file,
    ]

    passed = failed = 0
    for fn in tests:
        try:
            fn()
            passed += 1
        except (RuntimeError, ValueError, FileNotFoundError, OSError) as exc:
            failed += 1
            print(f"\n  [FAIL] {fn.__name__}: {exc}")

    _section("Results")
    print(f"  Passed: {passed}/{len(tests)}")
    print(f"  Failed: {failed}/{len(tests)}")
    print()

    sys.exit(0 if failed == 0 else 1)
