"""
Simulate toàn bộ UI flow từ multi_result → list ObservationItem như user thấy.

Logic UI (record_screens.dart::_buildObservations):
  1. Nếu classWideExtraction có nội dung → 1 classwide item
  2. Với mỗi child trong lớp, nếu id/name nằm trong childExtractions → 1 child item
  3. Nếu rawJson.unmatched_segments có list → 1 unmatched item / segment
     (Fallback: derive từ segments list)

Chạy:  cmd /c "venv\\Scripts\\python.exe -m app.services.test.test_ui_simulation"
"""

from app.models.child import Child
from app.services.extraction_service import extract_multi_person


def get_mock_children():
    """
    6 trẻ thuộc 2 lớp:
      Medium (class_id=1): Nguyễn Bảo, Trần Ánh, Trần Anh, Lê Khang
      Khác  (class_id=2): Phạm Lan, Đỗ Chi
    """
    return [
        Child(child_id=1, full_name="Nguyễn Bảo", nickname="Bảo", class_id=1),
        Child(child_id=2, full_name="Trần Ánh", nickname="Ánh", class_id=1),
        Child(child_id=3, full_name="Trần Anh", nickname="Anh", class_id=1),
        Child(child_id=4, full_name="Lê Khang", nickname="Khang", class_id=1),
        Child(child_id=5, full_name="Phạm Lan", nickname="Lan", class_id=2),
        Child(child_id=6, full_name="Đỗ Chi", nickname="Chi", class_id=2),
    ]


def _pick(cw, key, fallback):
    v = cw.get(key) if cw else None
    s = (v or "").strip() if isinstance(v, str) else ""
    return s if s else fallback


def _build_observation_items(multi_result, children):
    """Re-implement Flutter _buildObservations trong Python để test."""
    items = []

    cw = multi_result.get("class_wide_extraction") or {}
    child_map = multi_result.get("child_extractions") or {}
    segments = multi_result.get("segments") or []

    # 1. Classwide (nếu có nội dung thật)
    has_cw = isinstance(cw, dict) and any(
        (v or "").strip() for v in cw.values()
    )
    if has_cw:
        items.append({
            "id": "classwide",
            "name": "Chung cả lớp",
            "kind": "classwide",
            "matched": True,
            "decision": "pending",
            "eating":      _pick(cw, "meals",      "Cả lớp ăn theo thực đơn chung."),
            "sleep":       _pick(cw, "sleeping",   "Cả lớp ngủ đúng giờ."),
            "activities":  _pick(cw, "activities", "Tham gia hoạt động chung của lớp."),
            "mood":        _pick(cw, "mood",       "Vui vẻ, hào hứng."),
            "health":      _pick(cw, "health",     ""),
        })

    # 2. Child items - chỉ các bé có override trong child_extractions
    for child in children:
        data = None
        if str(child.child_id) in child_map:
            data = child_map[str(child.child_id)]
        elif child.full_name in child_map:
            data = child_map[child.full_name]
        elif child.nickname in child_map:
            data = child_map[child.nickname]
        if not isinstance(data, dict):
            continue
        items.append({
            "id": str(child.child_id),
            "name": child.full_name,
            "childId": str(child.child_id),
            "nickname": child.nickname,
            "kind": "child",
            "matched": True,
            "decision": "pending",
            "eating":      (data.get("meals") or "").strip()      or "Ăn theo thực đơn lớp.",
            "sleep":       (data.get("sleeping") or "").strip()   or "Ngủ theo giờ chung.",
            "activities":  (data.get("activities") or "").strip()  or "",
            "mood":        (data.get("mood") or "").strip()        or "",
            "health":      (data.get("health") or "").strip()      or "",
        })

    # 3. Unmatched items
    #    Backend merge orphan short segments (< 3 words, no match) vào class-wide.
    #    Derive unmatched từ segments list: skip orphan (short, no match).
    u_idx = 0
    for seg in segments:
        if not isinstance(seg, dict):
            continue
        is_cw_seg = seg.get("is_class_wide") is True
        matches = seg.get("child_matches")
        has_matches = isinstance(matches, list) and len(matches) > 0
        if not is_cw_seg and not has_matches:
            text = (seg.get("text") or "").strip()
            # Orphan short segments đã được merge vào class-wide ở backend
            if text and len(text.split()) >= 3:
                items.append({
                    "id": f"unmatched_{u_idx}",
                    "name": "Chưa rõ bé nào",
                    "kind": "unmatched",
                    "matched": False,
                    "decision": "pending",
                    "snippet": text,
                    "eating":     "Chưa có thông tin",
                    "sleep":      "Chưa có thông tin",
                    "activities": "Chưa có thông tin",
                    "mood":       "Chưa có thông tin",
                })
                u_idx += 1

    return items


def _print_item(idx, item):
    print(f"   ┌── Item #{idx+1}")
    if item["kind"] == "classwide":
        print("   │  🏫  Chung cả lớp")
    elif item["kind"] == "child":
        print(f"   │  👶  {item['name']} (nickname={item['nickname']!r})")
    elif item["kind"] == "unmatched":
        print("   │  ❓  Chưa rõ bé nào")
        print(f"   │      snippet: {item['snippet']!r}")
    print(f"   │  kind    : {item['kind']}")
    print(f"   │  decision: {item['decision']}")
    print(f"   │  eating    : {item['eating']}")
    print(f"   │  sleep     : {item['sleep']}")
    print(f"   │  activities: {item['activities']}")
    print(f"   │  mood      : {item['mood']}")
    print(f"   │  health    : {item.get('health', '')}")
    print("   └────────")


def simulate_ui(label, transcript, children):
    multi = extract_multi_person(transcript=transcript, children=children, min_confidence=0.3)
    items = _build_observation_items(multi, children)

    print(f"\n{'='*70}")
    print(f"INPUT: {transcript!r}")
    print(f"{'='*70}")
    print(f"  → {len(items)} item(s) user sees on review screen:")
    for i, it in enumerate(items):
        _print_item(i, it)


TEST_CASES = [
    ("Class Bảo Medium",
     "cả lớp ăn cơm no riêng bé bảo ăn tt hơn mọi khi hay quấy khóc"),
    ("Ánh Anh Khang",
     "ánh hôm nay hát hay lắm còn anh thì ngủ trưa ngon khang buồn ngủ một chút"),
    ("Unmatched",
     "có một bé quất khóc lúc ngủ trưa nhưng cô không nhớ là bé nào"),
    ("Class Medium (sạch)",
     "hôm nay cả lớp ăn rất ngon tất cả các bé ngủ trưa say giấc chiều ai cũng vui vẻ"),
    ("Class Bảo Ánh",
     "cả lớp ăn ngon bảo ho nhẹ ánh sốt"),
    ("Bảo 1 lần",
     "bảo ho nhẹ"),
    ("Chi Class",
     "chi sốt ba mươi tám độ cô cho uống thuốc ròi cả lớp còn lại khoẻ mạnh bình thường"),
]


def main():
    children = get_mock_children()
    print("\n" + "#"*70)
    print("# Simulate UI từ multi_result → list ObservationItem")
    print("#"*70)

    for label, text in TEST_CASES:
        simulate_ui(label, text, children)


if __name__ == "__main__":
    main()