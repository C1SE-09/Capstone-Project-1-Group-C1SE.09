"""
tests/test_conflict_resolution.py
==================================
Unit tests cho conflict_resolution_service.
"""

from app.services.conflict_resolution_service import (
    are_contradictory,
    clean_phrase,
    merge_category_phrases,
    resolve_conflicts,
    resolve_conflicts_in_text,
)


def test_clean_phrase():
    assert clean_phrase("ăn ngon nhưng") == "ăn ngon"
    assert clean_phrase("nhưng ăn không ngon") == "ăn không ngon"
    assert clean_phrase("sau đó bé ăn cháo") == "bé ăn cháo"
    assert clean_phrase("  ,ăn cháo; ") == "ăn cháo"


def test_meals_conflict_quality():
    # ăn ngon vs ăn không ngon -> contradictory
    assert are_contradictory("ăn ngon", "ăn không ngon", "meals") is True
    # ăn ngon vs ăn cháo -> NOT contradictory (món ăn)
    assert are_contradictory("ăn ngon", "ăn cháo", "meals") is False
    # ăn cháo vs ăn không ngon -> NOT contradictory (món ăn)
    assert are_contradictory("ăn cháo", "ăn không ngon", "meals") is False

    # Trường hợp người dùng mô tả: ["ăn ngon", "ăn cháo"] + ["ăn không ngon"]
    res = resolve_conflicts(["ăn ngon", "ăn cháo", "ăn không ngon"], "meals")
    assert res == ["ăn cháo", "ăn không ngon"]


def test_meals_feeding_method():
    # tự xúc vs cô phải đút -> contradictory
    assert are_contradictory("tự xúc", "cô phải đút", "meals") is True
    res = resolve_conflicts(["tự xúc", "ăn cơm", "cô phải đút"], "meals")
    assert res == ["ăn cơm", "cô phải đút"]


def test_sleeping_conflict():
    # ngủ một mạch vs trằn trọc khó ngủ -> contradictory
    assert are_contradictory("ngủ một mạch", "trằn trọc khó ngủ", "sleeping") is True
    # ngủ ngon vs ngủ ngắn -> contradictory
    assert are_contradictory("ngủ ngon", "ngủ ngắn", "sleeping") is True
    # ngủ ngon vs ôm gấu bông -> NOT contradictory
    assert are_contradictory("ngủ ngon", "ôm gấu bông", "sleeping") is False

    res = resolve_conflicts(
        ["ngủ một mạch", "ôm gấu bông", "trằn trọc khó ngủ"], "sleeping"
    )
    assert res == ["ôm gấu bông", "trằn trọc khó ngủ"]


def test_health_conflict():
    # khỏe mạnh vs mệt mỏi / sốt nhẹ -> contradictory
    assert are_contradictory("khỏe mạnh", "sốt nhẹ", "health") is True
    assert are_contradictory("khỏe mạnh", "sổ mũi", "health") is True
    # hai triệu chứng không mâu thuẫn nhau
    assert are_contradictory("ho nhẹ", "sổ mũi", "health") is False

    res = resolve_conflicts(["khỏe mạnh", "sốt nhẹ", "cho uống nước ấm"], "health")
    assert res == ["sốt nhẹ", "cho uống nước ấm"]


def test_mood_conflict():
    # vui vẻ vs khóc nhè -> contradictory
    assert are_contradictory("vui vẻ", "khóc nhè", "mood") is True
    # tập trung vs lơ đễnh -> contradictory
    assert are_contradictory("tập trung", "lơ đễnh", "mood") is True

    res = resolve_conflicts(["vui vẻ", "vẽ tranh đẹp", "khóc nhè"], "mood")
    assert res == ["vẽ tranh đẹp", "khóc nhè"]


def test_activities_conflict():
    # chơi cùng bạn vs chơi một mình -> contradictory
    assert are_contradictory("chơi cùng bạn", "chơi một mình", "activities") is True
    # hai hoạt động cụ thể không mâu thuẫn
    assert are_contradictory("vẽ tranh", "xếp hình", "activities") is False

    res = resolve_conflicts(
        ["chơi cùng bạn", "vẽ tranh", "chơi một mình"], "activities"
    )
    assert res == ["vẽ tranh", "chơi một mình"]


def test_merge_category_phrases():
    curr = ["ăn ngon", "ăn cháo"]
    merged = merge_category_phrases(curr, "ăn không ngon", "meals")
    assert merged == ["ăn cháo", "ăn không ngon"]

    # Thêm món ăn mới: không mất gì
    merged2 = merge_category_phrases(["ăn cháo"], "uống sữa", "meals")
    assert merged2 == ["ăn cháo", "uống sữa"]


def test_resolve_conflicts_in_text():
    text = "ăn ngon, ăn cháo, ăn không ngon"
    assert resolve_conflicts_in_text(text, "meals") == "ăn cháo, ăn không ngon"
    assert resolve_conflicts_in_text(None, "meals") is None
    assert resolve_conflicts_in_text("", "meals") is None
