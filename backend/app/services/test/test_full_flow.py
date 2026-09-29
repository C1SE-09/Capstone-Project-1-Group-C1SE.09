"""
Test Full Flow: Transcript → Name Matching → Model Extraction
"""

from app.models.child import Child
from app.services.extraction_service import (
    extract_from_transcript,
    extract_multi_person,
)


def get_mock_children():
    return [
        Child(child_id=1, full_name="Nguyễn Văn Lan", nickname="Lan", class_id=1, status="active"),
        Child(child_id=2, full_name="Trần Thị Minh", nickname="Minh", class_id=1, status="active"),
        Child(child_id=3, full_name="Lê Hoàng Nam", nickname="Nam", class_id=1, status="active"),
        Child(child_id=4, full_name="Phạm Thu Hà", nickname="Hà", class_id=1, status="active"),
        Child(child_id=5, full_name="Đỗ Đức Anh", nickname="Anh", class_id=1, status="active"),
    ]

def print_full_result(result, transcript):
    print(f"\n{'='*60}")
    print(f"TRANSCRIPT:\n{transcript}")
    print(f"{'='*60}")
    
    print("\n📊 SUMMARY:")
    print(f"   Total segments: {len(result['segments'])}")
    print(f"   Ambiguous: {result['ambiguous_segments']}")
    print(f"   Unmatched: {result['unmatched_segments']}")
    
    print("\n📋 SEGMENTS:")
    for i, seg in enumerate(result['segments']):
        print(f"\n   [Segment {i+1}] \"{seg['text']}\"")
        
        # Child matches
        if seg['child_matches']:
            for m in seg['child_matches']:
                print(f"      -> Child: {m['full_name']} ({m['nickname']}) | Conf: {m['confidence']:.0%}")
        else:
            print("      -> No child match")
        
        # Extraction
        ext = seg['extraction']
        extracted = [f"{k}={v}" for k, v in ext.items() if v]
        if extracted:
            print(f"      -> Extracted: {', '.join(extracted)}")
    
    print("\n👶 CHILD EXTRACTIONS:")
    for child_id, data in result['child_extractions'].items():
        child = next(c for c in get_mock_children() if str(c.child_id) == str(child_id))
        print(f"\n   {child.full_name}:")
        for key, value in data.items():
            if value:
                print(f"      - {key}: {value}")
    
    return result

def test_1_simple_single_child():
    """Test: 1 child, đơn giản"""
    print("\n" + "="*70)
    print("TEST 1: Simple Single Child")
    print("="*70)
    
    transcript = "Bé Lan ăn ngon hết suất cơm. Bé ngủ trưa rất ngoan."
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_full_result(result, transcript)

def test_2_multi_child():
    """Test: Nhiều child, facts riêng"""
    print("\n" + "="*70)
    print("TEST 2: Multi-Child with Separate Facts")
    print("="*70)
    
    transcript = """
    Sáng nay Lan ăn ngon hết bát cháo.
    Minh không chịu ăn, cứ khóc.
    Chiều cả lớp ra sân chơi.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_full_result(result, transcript)

def test_3_conflict():
    """Test: 2 children cùng segment (conflict)"""
    print("\n" + "="*70)
    print("TEST 3: Two Children Same Segment (Conflict)")
    print("="*70)
    
    transcript = "Lan và Minh cãi nhau trong giờ chơi, cả hai đều không ngoan."
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_full_result(result, transcript)

def test_4_teacher_instruction():
    """Test: Teacher instruction + child fact"""
    print("\n" + "="*70)
    print("TEST 4: Teacher Instruction + Child Fact")
    print("="*70)
    
    transcript = """
    Cô cho Lan ra ngoài vì bé ho nhiều.
    Lan rất buồn vì phải nghỉ học.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_full_result(result, transcript)

def test_5_all_facts():
    """Test: Tất cả các loại facts"""
    print("\n" + "="*70)
    print("TEST 5: All Fact Types")
    print("="*70)
    
    transcript = """
    Lan ăn ngon hết bát cơm, uống sữa đầy đủ.
    Bé ngủ trưa rất ngoan, ngủ li bì 2 tiếng.
    Chiều bé ho nhẹ, sổ mũi một chút.
    Lan vẽ tranh rất đẹp, được cô khen.
    Bé rất vui vẻ, hào hứng học bài.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_full_result(result, transcript)

def test_6_no_names():
    """Test: Không có tên child"""
    print("\n" + "="*70)
    print("TEST 6: No Child Names (All Class)")
    print("="*70)
    
    transcript = """
    Cả lớp hát bài hát mới rất vui.
    Các bé đều ngoan, cô khen cả lớp.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_full_result(result, transcript)

def test_7_complex_school_day():
    """Test: Ngày học phức tạp"""
    print("\n" + "="*70)
    print("TEST 7: Complex School Day")
    print("="*70)
    
    transcript = """
    Sáng thứ hai, cả lớp học bài rất ngoan.
    Bé Lan giơ tay trả lời câu hỏi, được cô khen thông minh.
    Minh ngồi im, chưa giơ tay lần nào.
    Giờ ăn trưa, Lan ăn hết suất, Minh bỏ cơm.
    Sau ngủ trưa, Hà dậy sớm, Nam còn buồn ngủ.
    Chiều chơi ngoài sân, cả lớp vui vẻ.
    """
    children = get_mock_children()
    
    result = extract_multi_person(transcript, children)
    print_full_result(result, transcript)

def test_8_model_only():
    """Test: Model extraction only (không có name matching)"""
    print("\n" + "="*70)
    print("TEST 8: Model Extraction Only (No Name Matching)")
    print("="*70)
    
    transcript = "Lan ăn ngon hết bát cơm. Bé ngủ trưa ngoan. Chiều ho nhẹ. Vẽ tranh đẹp. Rất vui vẻ."
    
    result = extract_from_transcript(transcript)
    
    print(f"\n📝 Transcript: {transcript}")
    print("\n📊 Model Extraction Result:")
    for key, value in result.items():
        status = "✅" if value else "❌"
        print(f"   {status} {key}: {value}")

if __name__ == "__main__":
    print("\n" + "="*70)
    print("🧪 FULL FLOW TEST - Transcript → Name Matching → Model Extraction")
    print("="*70)
    
    test_1_simple_single_child()
    test_2_multi_child()
    test_3_conflict()
    test_4_teacher_instruction()
    test_5_all_facts()
    test_6_no_names()
    test_7_complex_school_day()
    test_8_model_only()
    
    print("\n" + "="*70)
    print("✅ ALL TESTS COMPLETED!")
    print("="*70)
