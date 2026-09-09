"""
demo_stt.py
===========
Script demo nhan dien giong noi (Speech-to-Text) don gian.
Chi load model PhoWhisper va in ra text tu file audio.

Cach chay:
    cd backend
    python demo_stt.py
    python demo_stt.py --file path/to/audio.mp3
    python demo_stt.py --file path/to/audio.mp3 --device cpu
"""

import argparse
import io
import logging
import sys
import time
from pathlib import Path

# Fix UnicodeEncodeError tren Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

_BACKEND_DIR = Path(__file__).resolve().parent
DEFAULT_AUDIO = _BACKEND_DIR / "test_audio_rin.mp3"


def parse_args():
    parser = argparse.ArgumentParser(description="Demo STT PhoWhisper")
    parser.add_argument(
        "--file", "-f",
        type=str,
        default=str(DEFAULT_AUDIO),
        help="Duong dan file audio",
    )
    parser.add_argument(
        "--device", "-d",
        choices=["auto", "cuda", "cpu"],
        default="auto",
        help="Device: auto, cuda, cpu (mac dinh: auto)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    audio_path = Path(args.file)

    print("\n" + "=" * 60)
    print("  PhoWhisper STT --- Demo nhan dien giong noi tieng Viet")
    print("=" * 60)

    if not audio_path.exists():
        print(f"\n[LOI] Khong tim thay file audio: {audio_path}")
        print("      Dung --file <duong_dan> de chi dinh file khac.")
        sys.exit(1)

    size_mb = audio_path.stat().st_size / 1024 / 1024
    print(f"\n  File  : {audio_path.name}")
    print(f"  Size  : {size_mb:.2f} MB")
    print(f"  Device: {args.device.upper()}")

    # --- Load model ---
    print("\n[1/2] Dang load model PhoWhisper (lan dau se tai tu HuggingFace)...")
    t_load = time.perf_counter()

    try:
        from faster_whisper import WhisperModel

        device = args.device
        if device == "auto":
            try:
                import ctranslate2
                device = "cuda" if ctranslate2.get_cuda_device_count() > 0 else "cpu"
            except (ImportError, RuntimeError, AttributeError):
                device = "cpu"

        model = WhisperModel(
            "vudang449/PhoWhisper-large-ct2",
            device=device,
            compute_type="int8",
            num_workers=1,
        )
        load_time = time.perf_counter() - t_load
        print(f"  [OK] Model da load tren {device.upper()} ({load_time:.1f}s)")

    except ImportError:
        print("\n[LOI] Thieu thu vien faster-whisper.")
        print("      Cai dat: pip install faster-whisper")
        sys.exit(1)
    except (RuntimeError, ValueError, OSError) as e:
        print(f"\n[LOI] Khong the load model: {e}")
        sys.exit(1)

    # --- Transcribe ---
    print("\n[2/2] Dang nhan dien giong noi...")
    t_transcribe = time.perf_counter()

    try:
        segments, info = model.transcribe(
            str(audio_path),
            language="vi",
            vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 500},
            beam_size=5,
            condition_on_previous_text=False,
        )

        text_parts = []
        for segment in segments:
            part = segment.text.strip()
            if part:
                text_parts.append(part)

        transcript = " ".join(text_parts)
        elapsed = time.perf_counter() - t_transcribe

    except (RuntimeError, ValueError, OSError) as e:
        print(f"\n[LOI] Nhan dien that bai: {e}")
        sys.exit(1)

    # --- In ket qua ---
    print("\n" + "=" * 60)
    print("  KET QUA NHAN DIEN")
    print("=" * 60)

    if transcript:
        print(f"\n{transcript}\n")
    else:
        print("\n(Khong nhan dien duoc noi dung)\n")

    print("=" * 60)
    print(f"  Thoi gian nhan dien : {elapsed:.2f}s")
    print(f"  So ky tu            : {len(transcript)}")
    print(f"  Ngon ngu phat hien  : {info.language} (conf: {info.language_probability:.0%})")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
