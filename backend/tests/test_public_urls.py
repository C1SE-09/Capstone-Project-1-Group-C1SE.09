"""Unit tests cho app/core/public_url.py."""

from app.config import settings
from app.core.public_url import build_public_url, normalize_public_url


def test_build_public_url_prefers_public_base(monkeypatch):
    monkeypatch.setattr(settings, "minio_public_url", "https://cdn.example.com/")
    assert build_public_url("audio", "a.m4a") == "https://cdn.example.com/audio/a.m4a"


def test_build_public_url_rewrites_docker_host(monkeypatch):
    monkeypatch.setattr(settings, "minio_public_url", "")
    monkeypatch.setattr(settings, "minio_endpoint", "minio:9000")
    monkeypatch.setattr(settings, "minio_secure", False)
    assert build_public_url("audio", "a.m4a") == "http://localhost:9000/audio/a.m4a"


def test_build_public_url_keeps_external_endpoint(monkeypatch):
    monkeypatch.setattr(settings, "minio_public_url", "")
    monkeypatch.setattr(settings, "minio_endpoint", "storage.example.com")
    monkeypatch.setattr(settings, "minio_secure", True)
    assert build_public_url("audio", "a.m4a") == "https://storage.example.com/audio/a.m4a"


def test_normalize_public_url_rewrites_legacy_hosts(monkeypatch):
    monkeypatch.setattr(settings, "minio_public_url", "https://cdn.example.com")
    for host in ("minio:9000", "localhost:9000", "127.0.0.1:9000"):
        assert (
            normalize_public_url(f"http://{host}/bug_reports/x.png")
            == "https://cdn.example.com/bug_reports/x.png"
        )


def test_normalize_public_url_noop_without_public_base(monkeypatch):
    monkeypatch.setattr(settings, "minio_public_url", "")
    url = "http://minio:9000/bug_reports/x.png"
    assert normalize_public_url(url) == url


def test_normalize_public_url_keeps_external_and_relative(monkeypatch):
    monkeypatch.setattr(settings, "minio_public_url", "https://cdn.example.com")
    assert normalize_public_url("https://other.com/x.png") == "https://other.com/x.png"
    assert normalize_public_url("/bug_reports/x.png") == "/bug_reports/x.png"


def test_normalize_public_url_keeps_query(monkeypatch):
    monkeypatch.setattr(settings, "minio_public_url", "https://cdn.example.com")
    assert (
        normalize_public_url("http://minio:9000/x.png?token=1")
        == "https://cdn.example.com/x.png?token=1"
    )
