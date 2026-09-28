"""
Test: Class-Wide vs Child-Specific Override Logic
"""

from app.models.child import Child
from app.services.extraction_service import extract_multi_person


def get_mock_children():
    return [
        Child(child_id=1, full_name="Nguyễn Văn Lan", nickname="Lan", class_id=1, status="active"),
        Child(child_id=2, full_name="Trần Thị Minh", nickname="Minh", class_id=1, status="active"),
        Child(child_id=3, full_name="Lê Hoàng Nam", nickname="Nam", class_id=1, status="active"),
        Child(child_id=4, full_name="Hoàng Thu Ngân", nickname="Ngân", class_id=1, status="active"),
    ]

def print_result(result, transcript):
    print(f"\n{'='*70}")
    print(f"TRANSCRIPT:\n{transcript}")
    print(f"{'='*70}")
    
    print("\n📊 SUMMARY:")
    print(f"   Class-wide segments: {result['class_wide_segments']}")
    print(f"   Ambiguous: {result['ambiguous_segments']}")
    
    print("\n📋 SEGMENTS:")
    for i, seg in enumerate(result['segments']):
        scope = "🌍 CLASS-WIDE" if seg['is_class_wide'] else "👤 CHILD-SPECIFIC"
        print(f"\n   [{i+1}] {scope}")
        print(f"       \"{seg['text']}\"")
        
        if seg['child_matches']:
            names = [m['full_name'] for m in seg['child_matches']]
            print(f"       → Applies to: {', '.join(names)}")
        
        ext = seg['extraction']
        extracted = [f"{k}={v}" for k, v in ext.items() if v]
        if extracted:
            print(f"       → Extracted: {', '.join(extracted)}")
    
    print("\n👶 FINAL CHILD EXTRACTIONS:")
    children = get_mock_children()
    for child_id, data in result['child_extractions'].items():
        child = next(c for c in children if str(c.child_id) == str(child_id))
        print(f"\n   {child.full_name}:")
        for key, value in data.items():
            status = "✅" if value else "❌"
            print(f"      {status} {key}: {value or '(none)'}")


def test_override_logic():
    """Test: Cả lớp default + child-specific override"""
    print("\n" + "="*70)
    print("🧪 TEST: Override Logic")
    print("="*70)
    
    # Transcript mẫu theo ý user
    transcript = """
    Cả lớp ăn no, ngủ ngon.
    Ngân ngủ không ngon, cứ nói chuyện.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_result(result, transcript)
    
    print("\n" + "="*70)
    print("EXPECTED:")
    print("  Lan: meals='ăn no', sleeping='ngủ ngon'")
    print("  Minh: meals='ăn no', sleeping='ngủ ngon'") 
    print("  Nam: meals='ăn no', sleeping='không ngon' ← override!")


def test_school_day():
    """Test: Ngày học bình thường"""
    print("\n" + "="*70)
    print("🧪 TEST: School Day")
    print("="*70)
    
    transcript = """
    Sáng nay cả lớp học bài rất ngoan.
    Lan giơ tay trả lời câu hỏi, được cô khen.
    Minh ngồi im, chưa giơ tay.
    Giờ ăn trưa, cả lớp ăn ngon.
    Nam không chịu ăn, cứ khóc.
    Chiều chơi ngoài sân, cả lớp vui vẻ.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_result(result, transcript)


def test_mixed():
    """Test: Mixed - class-wide và child-specific"""
    print("\n" + "="*70)
    print("🧪 TEST: Mixed Class-wide & Child-specific")
    print("="*70)
    
    transcript = """
    Hôm nay các bé đều ăn ngon.
    Lan uống thêm sữa.
    Cả lớp ngủ trưa rất ngoan.
    Minh ho nhẹ, cần theo dõi.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_result(result, transcript)


if __name__ == "__main__":
    test_override_logic()
    test_school_day()
    test_mixed()
    
    print("\n" + "="*70)
    print("✅ TESTS COMPLETED!")
    print("="*70)
