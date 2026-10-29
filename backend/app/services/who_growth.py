"""
app/services/who_growth.py
===========================
Xep loai the trang tre em theo chuan WHO BMI-for-age.

Dung bang LMS (L, M, S) chinh thuc cua WHO:
  - WHO Child Growth Standards 2006 -> thang 0..60   (0-5 tuoi)
  - WHO Growth Reference 2007       -> thang 61..228 (5-19 tuoi)

Cong thuc Z-score (LMS):
    Z = ((X / M) ** L - 1) / S

Quy uoc xep loai (theo dinh nghia cua WHO):
  - Z < -2              -> SUY DINH DUONG   (thinness / underweight)
  - -2 <= Z <= +1       -> BINH THUONG      (normal weight)
  - Z > +1              -> THUA CAN         (overweight, co the can can)
  - Z > +2              -> thuong bi phan loai la "beo phi" (obesity), o day
                            van giu o nhom THUA CAN de don gian.

Neu thieu ngay sinh hoac khong xac dinh duoc gioi tinh thi dung nguong chung
cho tre mam non 3-6 tuoi de xep loai (fallback).
"""

from __future__ import annotations

import logging
from datetime import date

from app.models.health_examination import HealthCategory
from app.services.who_bmi_lms import lookup

logger = logging.getLogger(__name__)

# Gioi han tuoi ma chuan WHO con ap dung duoc (19 tuoi = 228 thang).
MAX_AGE_MONTHS = 228

# Nguong chung khi khong biet tuoi/hoi tinh (tre mam non 3-6 tuoi).
FALLBACK_UNDERWEIGHT_MAX = 13.5
FALLBACK_OVERWEIGHT_MAX = 18.5


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


def bmi_zscore(
    bmi: float,
    *,
    birth_date: date | None,
    exam_date: date,
    gender: str | None,
) -> float | None:
    """Tinh Z-score BMI-theo-tuoi theo chuan WHO. None neu khong tinh duoc."""
    boy = _is_boy(gender)
    if birth_date is None or boy is None:
        return None

    months = age_in_months(birth_date, exam_date)
    if months > MAX_AGE_MONTHS:
        return None

    row = lookup("boys" if boy else "girls", months)
    if row is None:
        return None

    l_value, m_value, s_value = row[0], row[1], row[2]
    if m_value <= 0 or s_value <= 0 or l_value == 0:
        return None
    # Cong thuc Z-score chuan cua WHO (LMS): Z = ((X/M)^L - 1) / (L * S)
    return ((bmi / m_value) ** l_value - 1) / (l_value * s_value)


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

    row = lookup("boys" if boy else "girls", months)
    if row is None:
        return (FALLBACK_UNDERWEIGHT_MAX, FALLBACK_OVERWEIGHT_MAX)

    # row = (L, M, S, sd2neg, sd1, sd2)
    return (row[3], row[4])


def classify_bmi_who(
    bmi: float,
    *,
    birth_date: date | None,
    exam_date: date,
    gender: str | None,
) -> HealthCategory:
    """Xep loai the trang theo chuan WHO theo tuoi va gioi tinh."""
    under_max, over_min = bmi_thresholds(
        birth_date=birth_date, exam_date=exam_date, gender=gender
    )
    if bmi < under_max:
        return HealthCategory.UNDERWEIGHT
    if bmi > over_min:
        return HealthCategory.OVERWEIGHT
    return HealthCategory.NORMAL
