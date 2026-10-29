"""
tests/test_who_growth.py
=======================
Test xep loai the trang theo chuan WHO BMI-for-age (bang LMS chinh thuc).

Kiem tra:
- Z-score tinh theo cong thuc LMS khop cac nguong WHO (SD-2, SD+1, SD+2).
- Phan loai dung theo nguong cho tung nhom tuoi/gioi tinh.
- Fallback khi thieu ngay sinh / gioi tinh / vuot 19 tuoi.
"""

from datetime import date

import pytest

from app.models.health_examination import HealthCategory
from app.services.who_bmi_lms import BMI_LMS
from app.services.who_growth import (
    FALLBACK_OVERWEIGHT_MAX,
    FALLBACK_UNDERWEIGHT_MAX,
    MAX_AGE_MONTHS,
    age_in_months,
    bmi_thresholds,
    bmi_zscore,
    classify_bmi_who,
)


def _z(bmi: float, l_val: float, m_val: float, s_val: float) -> float:
    return ((bmi / m_val) ** l_val - 1) / (l_val * s_val)


# ── Bang LMS ─────────────────────────────────────────────────────────────

def test_lms_table_covers_full_range():
    """Bang LMS phu du 0..228 thang cho ca 2 gioi tinh."""
    for sex in ("boys", "girls"):
        table = BMI_LMS[sex]
        assert min(table) == 0
        assert max(table) == MAX_AGE_MONTHS
        assert len(table) == MAX_AGE_MONTHS + 1
        assert set(table) == set(range(0, MAX_AGE_MONTHS + 1))


@pytest.mark.parametrize("sex", ["boys", "girls"])
def test_lms_thresholds_match_who_zscores(sex):
    """Nguong trong bang LMS phai ung voi Z = -2 / +1 / +2 theo cong thuc WHO."""
    for month, (l_val, m_val, s_val, sd2neg, sd1, sd2) in BMI_LMS[sex].items():
        assert _z(sd2neg, l_val, m_val, s_val) == pytest.approx(-2.0, abs=0.005)
        assert _z(sd1, l_val, m_val, s_val) == pytest.approx(1.0, abs=0.005)
        assert _z(sd2, l_val, m_val, s_val) == pytest.approx(2.0, abs=0.005)


def test_lms_values_sane():
    """M la trung vi BMI: tang den khoang 6 thang roi giam dan (doi dung ngu WHO)."""
    table = BMI_LMS["boys"]
    assert table[0][1] < table[6][1]
    assert table[6][1] > table[24][1]
    # M luon duong, S luon duong.
    for month, (l_val, m_val, s_val, sd2neg, sd1, sd2) in table.items():
        assert m_val > 0
        assert s_val > 0
        assert sd2neg < sd1 < sd2


# ── age_in_months ────────────────────────────────────────────────────────

def test_age_in_months_basic():
    assert age_in_months(date(2021, 5, 10), date(2026, 10, 20)) == 65
    # Chua den ngay sinh -> tru 1 thang.
    assert age_in_months(date(2021, 5, 10), date(2026, 10, 9)) == 64
    # Chua sinh -> 0.
    assert age_in_months(date(2026, 10, 20), date(2026, 10, 20)) == 0


# ── bmi_zscore ───────────────────────────────────────────────────────────

def test_bmi_zscore_matches_thresholds():
    """Z-score tinh tu BMI phai trung voi Z-score cua nguong WHO tuong ung."""
    birth = date(2021, 1, 1)
    exam = date(2026, 1, 1)  # 60 thang
    row = BMI_LMS["boys"][60]
    l_val, m_val, s_val, sd2neg, sd1, sd2 = row

    assert bmi_zscore(sd2neg, birth_date=birth, exam_date=exam, gender="male") == pytest.approx(-2.0, abs=0.005)
    assert bmi_zscore(sd1, birth_date=birth, exam_date=exam, gender="male") == pytest.approx(1.0, abs=0.005)
    assert bmi_zscore(sd2, birth_date=birth, exam_date=exam, gender="male") == pytest.approx(2.0, abs=0.005)


def test_bmi_zscore_none_when_missing_info():
    exam = date(2026, 1, 1)
    assert bmi_zscore(15.0, birth_date=None, exam_date=exam, gender="male") is None
    assert bmi_zscore(15.0, birth_date=date(2021, 1, 1), exam_date=exam, gender=None) is None
    # > 19 tuoi -> vuot pham vi chuan WHO
    assert bmi_zscore(
        15.0, birth_date=date(2005, 1, 1), exam_date=exam, gender="male"
    ) is None


# ── bmi_thresholds ───────────────────────────────────────────────────────

def test_thresholds_follow_who_table():
    birth = date(2021, 1, 1)
    exam = date(2026, 1, 1)  # 60 thang
    row = BMI_LMS["boys"][60]
    assert bmi_thresholds(birth_date=birth, exam_date=exam, gender="male") == (
        row[3],
        row[4],
    )


def test_thresholds_fallback_when_unknown():
    exam = date(2026, 1, 1)
    assert bmi_thresholds(birth_date=None, exam_date=exam, gender="male") == (
        FALLBACK_UNDERWEIGHT_MAX,
        FALLBACK_OVERWEIGHT_MAX,
    )
    assert bmi_thresholds(
        birth_date=date(2000, 1, 1), exam_date=exam, gender="male"
    ) == (FALLBACK_UNDERWEIGHT_MAX, FALLBACK_OVERWEIGHT_MAX)


# ── classify_bmi_who ─────────────────────────────────────────────────────

def test_classify_uses_who_thresholds_not_flat():
    """Phan loai phai theo nguong WHO, khong phai nguong flat 14/18."""
    birth = date(2021, 1, 1)
    exam = date(2026, 1, 1)  # 60 thang
    row = BMI_LMS["boys"][60]
    l_val, m_val, s_val, sd2neg, sd1, sd2 = row

    assert classify_bmi_who(
        sd2neg - 0.01, birth_date=birth, exam_date=exam, gender="male"
    ) == HealthCategory.UNDERWEIGHT
    assert classify_bmi_who(
        sd2neg + 0.01, birth_date=birth, exam_date=exam, gender="male"
    ) == HealthCategory.NORMAL
    assert classify_bmi_who(
        sd1 - 0.01, birth_date=birth, exam_date=exam, gender="male"
    ) == HealthCategory.NORMAL
    assert classify_bmi_who(
        sd1 + 0.01, birth_date=birth, exam_date=exam, gender="male"
    ) == HealthCategory.OVERWEIGHT


def test_classify_gender_specific_thresholds():
    """Be trai va be gai cung tuoi co nguong khac nhau."""
    birth = date(2021, 1, 1)
    exam = date(2026, 1, 1)  # 60 thang
    boy_row = BMI_LMS["boys"][60]
    girl_row = BMI_LMS["girls"][60]

    # Gia tri nằm giua nguong cua 2 gioi tinh -> ket qua khac nhau.
    boy_over = boy_row[4]
    girl_over = girl_row[4]
    assert boy_over != girl_over

    # Be trai: ngay tren nguong thua can cua be trai -> thua can
    assert classify_bmi_who(
        boy_over + 0.05, birth_date=birth, exam_date=exam, gender="male"
    ) == HealthCategory.OVERWEIGHT
    # Be gai cung BMI do: con binh thuong vi nguong be gai cao hon
    assert classify_bmi_who(
        boy_over + 0.05, birth_date=birth, exam_date=exam, gender="female"
    ) == HealthCategory.NORMAL


def test_classify_fallback_when_missing_dob():
    """Thieu ngay sinh -> dung nguong fallback chung."""
    exam = date(2026, 1, 1)
    assert classify_bmi_who(
        FALLBACK_UNDERWEIGHT_MAX - 0.1, birth_date=None, exam_date=exam, gender="male"
    ) == HealthCategory.UNDERWEIGHT
    assert classify_bmi_who(
        FALLBACK_OVERWEIGHT_MAX + 0.1, birth_date=None, exam_date=exam, gender="male"
    ) == HealthCategory.OVERWEIGHT
    assert classify_bmi_who(
        15.0, birth_date=None, exam_date=exam, gender="male"
    ) == HealthCategory.NORMAL


def test_classify_children_under_5_uses_standards_2006():
    """Bé 0-5 tuoi dung bang Standards 2006 (expanded table theo ngay)."""
    birth = date(2023, 6, 1)
    exam = date(2024, 6, 1)  # 12 thang
    row = BMI_LMS["boys"][12]
    l_val, m_val, s_val, sd2neg, sd1, sd2 = row

    assert classify_bmi_who(
        sd2neg - 0.01, birth_date=birth, exam_date=exam, gender="male"
    ) == HealthCategory.UNDERWEIGHT
    assert classify_bmi_who(
        sd1 + 0.01, birth_date=birth, exam_date=exam, gender="male"
    ) == HealthCategory.OVERWEIGHT

