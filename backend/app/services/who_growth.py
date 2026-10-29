"""
app/services/who_growth.py
===========================
Xep loai the trang tre em theo nguong WHO BMI-for-age (ban rut gon).

Nguon: WHO Child Growth Standards 2006 (0-60 thang) + WHO Growth Reference
2007 (61-120 thang). Bang duoi day la nguong BMI gioi han cho 5 nhom tuoi,
tinh tu bang LMS goc cua WHO (da lam tron 0.5 de doc duoc).

Quy uoc xep loai:
- BMI < nguong_suy_dinh_duong  -> SUY DINH DUONG
- BMI > nguong_thua_can        -> THUA CAN
- con lai                     -> BINH THUONG

Neu thieu ngay sinh hoac gioi tinh (khong tinh duoc tuoi) thi dung nguong
chung cho tre mam non de xep loai.
"""

from __future__ import annotations

import logging
from datetime import date

from app.models.health_examination import HealthCategory

logger = logging.getLogger(__name__)

# (so thang toi da, nguong suy dinh duong, nguong thua can) cho be trai / be gai
# Chi lay cac moc thang theo nhom tuoi, khong can bang LMS day du.
BMI_BANDS: tuple[tuple[int, float, float, float, float], ...] = (
    (23, 14.0, 19.5, 13.5, 19.5),  # 0-23 thang  (0-2 tuoi)
    (47, 13.5, 18.5, 13.0, 18.5),  # 24-47 thang (2-4 tuoi)
    (71, 13.0, 16.5, 12.5, 17.0),  # 48-71 thang (4-6 tuoi)
    (95, 13.0, 17.0, 12.5, 17.5),  # 72-95 thang (6-8 tuoi)
    (120, 13.5, 18.0, 13.0, 18.5),  # 96-120 thang (8-10 tuoi)
)

# Nguong chung khi khong biet tuoi/hoi tinh (tre mam non 3-6 tuoi).
FALLBACK_UNDERWEIGHT_MAX = 13.5
FALLBACK_OVERWEIGHT_MAX = 18.5

# Gioi han tuoi ma chuan WHO con ap dung duoc.
MAX_AGE_MONTHS = 120


def age_in_months(birth: date, on: date) -> int:
    """So thang tuoi da hoan thanh (lam tron xuong)."""
    months = (on.year - birth.year) * 12 + (on.month - birth.month)
    if on.day < birth.day:
        months -= 1
    return max(0, months)


def _is_boy(gender: str | None) -> bool | None:
    """Chuan hoa gioi tinh. None neu khong xac dinh duoc."""
    g = (gender or "").strip().lower()
    if g in ("male", "nam", "m", "boy", "trai"):
        return True
    if g in ("female", "nu", "nữ", "f", "girl", "gai", "gái"):
        return False
    return None


def bmi_thresholds(
    *,
    birth_date: date | None,
    exam_date: date,
    gender: str | None,
) -> tuple[float, float]:
    """Tra ve (nguong suy dinh duong, nguong thua can) theo tuoi va gioi tinh."""
    boy = _is_boy(gender)
    if birth_date is None or boy is None:
        return (FALLBACK_UNDERWEIGHT_MAX, FALLBACK_OVERWEIGHT_MAX)

    months = age_in_months(birth_date, exam_date)
    if months > MAX_AGE_MONTHS:
        return (FALLBACK_UNDERWEIGHT_MAX, FALLBACK_OVERWEIGHT_MAX)

    for max_months, boy_under, boy_over, girl_under, girl_over in BMI_BANDS:
        if months <= max_months:
            return (
                (boy_under, boy_over) if boy else (girl_under, girl_over)
            )
    return (FALLBACK_UNDERWEIGHT_MAX, FALLBACK_OVERWEIGHT_MAX)


def classify_bmi_who(
    bmi: float,
    *,
    birth_date: date | None,
    exam_date: date,
    gender: str | None,
) -> HealthCategory:
    """Xep loai the trang theo nguong WHO theo tuoi va gioi tinh."""
    under_max, over_min = bmi_thresholds(
        birth_date=birth_date, exam_date=exam_date, gender=gender
    )
    if bmi < under_max:
        return HealthCategory.UNDERWEIGHT
    if bmi > over_min:
        return HealthCategory.OVERWEIGHT
    return HealthCategory.NORMAL
