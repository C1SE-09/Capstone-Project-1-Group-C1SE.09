"""Kiểm tra registry app thật, không cần tải model ML hoặc gọi dịch vụ ngoài."""

import subprocess
import sys
from pathlib import Path


def test_reconciled_app_preserves_emergency_and_both_request_apis():
    # Process riêng tránh stub ML ảnh hưởng các test STT/report khác trong suite.
    result = subprocess.run(
        [sys.executable, "-c", """
import sys
from types import ModuleType
from fastapi import APIRouter

for name in ('app.api.endpoints.stt', 'app.api.teacher'):
    module = ModuleType(name)
    module.router = APIRouter()
    module.reports_router = APIRouter()
    sys.modules[name] = module

from app.main import app
paths = app.openapi()['paths']
expected = {
    '/api/teacher/health-incidents': {'post'},
    '/api/teacher/health-incidents/emergency-contacts/{child_id}': {'get'},
    '/api/teacher/health-incidents/{incident_id}': {'patch'},
    '/api/teacher/medications/today': {'get'},
    '/api/medication-requests': {'get', 'post'},
    '/api/leave-requests': {'post'},
    '/api/leave-requests/parent': {'post'},
}
for path, methods in expected.items():
    assert path in paths, f'Missing registered API: {path}'
    assert methods <= paths[path].keys(), path
"""],
        cwd=Path(__file__).resolve().parents[1], capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=30,
    )
    assert result.returncode == 0, result.stdout + result.stderr
