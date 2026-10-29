"""Kho SDK giả cho ảnh thuốc, giữ kiểm tra namespace riêng của ảnh xin phép."""

from test_leave_requests import MemoryMinio


class PrescriptionMinio(MemoryMinio):
    def check(self, bucket_name):
        assert bucket_name.endswith("-medication-requests")
        if self.failure:
            raise RuntimeError("private-prescription-credentials-must-not-leak")
