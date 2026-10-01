import sys

try:
    import torch
    print(f"torch {torch.__version__} OK")
except ImportError as e:
    print(f"torch FAIL: {e}")
    sys.exit(1)

try:
    import app.services.extraction_service as es
    print("extraction_service OK")
    print("functions:", [n for n in dir(es) if not n.startswith("__")][:20])
except (ImportError, ModuleNotFoundError) as e:
    print(f"extraction_service FAIL: {e}")
    sys.exit(1)