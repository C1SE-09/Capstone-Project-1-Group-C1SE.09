"""
Test specific transcripts provided to verify:
  1. Multi-segment per transcript gets appended (class-wide + child + child_overrides)
  2. Cross-class scenario (Bảo, Ánh, Khang)
  3. Unmatched segments without child name still appear
  4. Class-wide-only blocks (no child names)

Chạy: python -m backend.app.services.test.test_user_scenarios
hoặc:  python backend/app/services/test/test_user_scenarios.py
"""

from app.models.child import Child
from app.services.extraction_service import (
    extract_multi_person,
)


def get_mock_children():
    """
    Mock 5 children from 2 lớp: Medium (Bảo, Ánh, Anh, Khang) + Khác (Lan, Chi).

    Lớp 1 (Medium): Nguyễn Bảo, Trần Ánh, Trần Anh, Lê Khang
    Lớp 2 (Kiác): Phạm Lan, Đỗ Chi
    """
    return [
        Child(child_id=1, full_name="Nguyễn Bảo", nickname="Bảo", class_id=1),
        Child(child_id=2, full_name="Trần Ánh", nickname="Ánh", class_id=1),
        Child(child_id=3, full_name="Trần Anh", nickname="Anh", class_id=1),
        Child(child_id=4, full_name="Lê Khang", nickname="Khang", class_id=1),
        # Bé lớp khác (để test cross-class nếu filter sai)
        Child(child_id=5, full_name="Phạm Lan", nickname="Lan", class_id=2),
        Child(child_id=6, full_name="Đỗ Chi", nickname="Chi", class_id=2),
    ]


def print_segment(seg):
    text = seg.get("text", "")
    is_cw = seg.get("is_class_wide")
    is_amb = seg.get("is_ambiguous")
    matches = seg.get("child_matches", [])
    extraction = seg.get("extraction", {})

    print(f"   text         : {text!r}")
    print(f"   is_class_wide: {is_cw}")
    print(f"   is_ambiguous : {is_amb}")
    if matches:
        for m in matches:
            print(
                f"   -> match     : {m['full_name']!r} "
                f"(conf={m['confidence']}, words={m['matched_words']})"
            )
    non_null = {k: v for k, v in extraction.items() if v}
    if non_null:
        print(f"   extraction   : {non_null}")
    else:
        print("   extraction   : (empty)")


def print_result(label, transcript, result):
    print(f"\n{'='*70}")
    print(f"TEST: {label}")
    print(f"{'='*70}")
    print(f"INPUT : {transcript}")
    print("OUTPUT:")
    print(f"   total segments         : {len(result['segments'])}")
    print(f"   class_wide_segments    : {result['class_wide_segments']}")
    print(f"   ambiguous_segments     : {result['ambiguous_segments']}")
    print(f"   unmatched_segments     : {result['unmatched_segments']}")
    print()
    print("   --- segments ---")
    for seg in result["segments"]:
        print_segment(seg)
    print()
    print("   --- class_wide_extraction ---")
    cwe = result["class_wide_extraction"]
    non_null = {k: v for k, v in cwe.items() if v}
    print(f"   {non_null if non_null else '(empty)'}")
    print()
    print("   --- child_extractions ---")
    ce = result["child_extractions"]
    if ce:
        for cid, data in ce.items():
            non_null_data = {k: v for k, v in data.items() if v}
            print(f"   child_id={cid}: {non_null_data if non_null_data else '(empty)'}")
    else:
        print("   (empty)")


# ---------- Test cases từ user ----------
TEST_CASES = [
    (
        "Class Bảo Medium - có 'cả lớp' + 1 bé đặc biệt (Bảo)",
        "cả lớp ăn cơm no riêng bé bảo ăn tt hơn mọi khi hay quấy khóc",
    ),
    (
        "Ánh Anh Khang - 3 bé không nhắc 'cả lớp'",
        "ánh hôm nay hát hay lắm còn anh thì ngủ trưa ngon khang buồn ngủ một chút",
    ),
    (
        "Unmatched - không nhắc tên bé cụ thể",
        "có một bé quất khóc lúc ngủ trưa nhưng cô không nhớ là bé nào",
    ),
    (
        "Class Medium - chỉ nhắc 'cả lớp', không có tên bé",
        "hôm nay cả lớp ăn rất ngon tất cả các bé ngủ trưa say giấc chiều ai cũng vui vẻ",
    ),
    (
        "Class Bảo Ánh - 'cả lớp' + 2 bé (Bảo, Ánh)",
        "cả lớp ăn ngon bảo ho nhẹ ánh sốt",
    ),
    (
        "Bảo (1 lần) - chỉ nhắc 1 bé không 'cả lớp'",
        "bảo ho nhẹ",
    ),
    (
        "Chi Class - 1 bé (Chi) + 'cả lớp'",
        "chi sốt ba mươi tám độ cô cho uống thuốc ròi cả lớp còn lại khoẻ mạnh bình thường",
    ),
]


def main():
    children = get_mock_children()

    print("\n" + "#" * 70)
    print("# Test pipeline extraction với 7 transcripts từ user")
    print("#" * 70)

    for label, text in TEST_CASES:
        result = extract_multi_person(
            transcript=text,
            children=children,
            min_confidence=0.3,
        )
        print_result(label, text, result)


if __name__ == "__main__":
    main()