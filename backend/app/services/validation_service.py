"""
validation_service.py

Service kiểm tra nội dung transcript trước khi trích xuất (extraction).

Mục đích:
- Đảm bảo transcript có nội dung liên quan đến báo cáo học sinh mầm non
- Ngăn chặn việc extract từ nội dung không liên quan (VD: bài giảng, thời tiết, tin tức)

Keywords được extract từ training data (train-v1.jsonl, test-v1.jsonl, validation-v1.jsonl) tương lai khi có nâng cấp model sẽ có thay đổi thêm
"""

import re

# ============================================================================
# KEYWORD LISTS - Extracted từ ~1800+ training samples - Tương lai nâng cấp model thay đổi thêm
# ============================================================================

# Từ chỉ trẻ em/học sinh
CHILD_REFERENCES: list[str] = [
    "bé", "con", "bạn", "học sinh", "trẻ", "nhà mình", "em", "cháu",
    "bé nhà", "con mình",
    # Tình cảm / thân mật
    "nhóc", "cưng",
    # Giới tính rõ ràng
    "con gái", "con trai",
]

# Từ khóa liên quan đến ĂN UỐNG
EATING_KEYWORDS: list[str] = [
    # Động từ/hiện tượng
    "ăn", "bỏ mứa", "chán ăn", "tự xúc", "ngậm cơm", "dỗ", "nhai", "nuốt",
    "hết", "thèm", "đòi", "xin thêm",
    "ăn không hết", "ăn hết phần", "ăn vặt", "đòi ăn",
    "kén ăn", "xúc được", "nếm",
    # Thức ăn
    "cơm", "cháo", "sữa", "bánh", "thịt", "trứng", "rau", "canh",
    "sữa chua", "suất", "phần", "bát", "đũa",
    "bún", "phở", "mì", "bánh mì", "chè", "xôi",
    # Đồ uống
    "nước", "sữa tươi", "sữa bột", "nước cam",
    # Tráng miệng / hoa quả
    "trái cây", "hoa quả", "cam", "táo", "chuối", "nho",
    # Mô tả ăn
    "ngoan", "hào hứng", "ngon", "ít", "nhanh", "chậm", "ngon lành",
    # Trạng thái no/đói
    "no", "đói", "no nê", "no bụng",
]

# Từ khóa liên quan đến NGỦ
SLEEPING_KEYWORDS: list[str] = [
    # Động từ/hiện tượng
    "ngủ", "trằn trọc", "thức giấc", "quấy", "khóc đòi",
    "tè dầm", "một mạch", "lim dim", "li bì",
    "ngon giấc", "say sưa", "thiếp đi", "ngủ thiếp",
    "giật mình", "khóc thét", "mơ", "ác mộng",
    # Thời gian ngủ
    "giấc", "trưa", "buổi trưa", "ngắn", "dài",
    "giấc sáng", "giấc chiều", "giấc tối", "giấc ngủ",
    "đi ngủ", "nghỉ trưa", "nằm",
    # Đồ vật
    "giường", "nôi", "chiếu",
    # Yêu cầu khi ngủ
    "đòi bế", "đòi mẹ", "xin uống nước", "xin đi vệ sinh", "ngồi dậy",
]

# Từ khóa liên quan đến SỨC KHỎE
HEALTH_KEYWORDS: list[str] = [
    # Triệu chứng tích cực
    "khỏe", "khỏe mạnh", "bình thường", "ốm đau",
    # Triệu chứng tiêu hóa
    "đau bụng", "nôn ói", "tiêu chảy", "táo bón",
    # Triệu chứng hô hấp
    "ho", "sổ mũi", "nghẹn", "đau họng", "rát họng", "ho khù khụ",
    "viêm họng", "viêm mũi", "viêm phổi", "viêm tai",
    # Triệu chứng đau
    "đau đầu", "nhức đầu", "đau răng", "nhức răng",
    # Triệu chứng da
    "ngứa", "nổi mẩn",
    "dị ứng", "mề đay", "phát ban",
    # Triệu chứng chung
    "sốt", "ấm đầu", "hắt hơi", "mệt", "lừ đừ",
    "ốm", "mệt mỏi", "bệnh", "thương",
    # Chấn thương
    "té", "ngã", "va", "bị thương", "xước", "bầm",
    # Y tế
    "bác sĩ", "thuốc", "uống thuốc", "tiêm", "chích",
]

# Từ khóa liên quan đến HOẠT ĐỘNG
ACTIVITIES_KEYWORDS: list[str] = [
    # Hoạt động cụ thể
    "vẽ tranh", "xếp hình", "nặn đất", "đọc truyện", "kể chuyện",
    "hát", "nhảy múa", "âm nhạc", "gấp giấy", "tô màu",
    "chơi cầu trượt", "trốn tìm", "chơi đồ hàng", "ngắm hoa",
    # Đồ chơi thông minh
    "xếp lego", "ghép hình", "xếp khối", "lắp ráp",
    # Chơi ngoài trời
    "chơi cát", "chơi nước", "chơi đất",
    # Thủ công
    "cắt dán", "cắt giấy", "dán", "dán sticker",
    # Dã ngoại
    "đi dạo", "tham quan", "công viên", "vườn trường",
    # Thể thao
    "đá bóng", "ném bóng", "bắt bóng",
    # Vệ sinh cá nhân (giáo dục kỹ năng)
    "rửa tay", "đánh răng", "tắm",
    # Học tập
    "đếm", "đọc sách", "tập nói", "tập đếm",
    # Kỹ năng xã hội
    "chia sẻ", "giúp đỡ", "kết bạn",
    # Thu dọn
    "xếp đồ chơi", "dọn dẹp", "thu dọn",
    # Mô tả hoạt động
    "chơi", "hoạt động", "ngoài trời", "tập trung", "lơ đễnh",
    "tích cực", "năng động", "chạy nhảy",
    # Tương tác
    "cùng bạn", "với bạn", "với cô", "chơi một mình","nói chuyện",
    # Hoạt động khác
    "xé giấy", "hay giành đồ chơi"
]

# Từ khóa liên quan đến TÂM TRẠNG/CẢM XÚC
MOOD_KEYWORDS: list[str] = [
    # Tích cực
    "vui vẻ", "ngoan", "hào hứng",
    "tươi vui", "vui tươi", "rạng rỡ", "phấn khởi",
    "thích thú", "yêu thích",
    "được khen", "được cô khen",
    # Tiêu cực — giận / cáu
    "buồn", "quậy phá", "nghịch ngợm", "nhõng nhẽo", "tủi thân",
    "khóc nhè", "khó chịu",
    "cáu", "cáu bẳn", "giận", "cau có", "bực bội", "bực mình",
    # Hờn dỗi / bướng bỉnh
    "hờn dỗi", "ngang bướng", "bướng bỉnh", "lì lợm", "ngang ngược",
    # Sợ / lo
    "sợ", "sợ hãi", "lo lắng", "hồi hộp",
    # Tò mò / tích cực
    "tò mò", "ham hỏi", "ham học hỏi",
    # Trung tính/mô tả
    "lơ đễnh", "bình thường",
    "bình tĩnh", "yên tĩnh", "hiền",
]

# Từ khóa báo hiệu nội dung KHÔNG liên quan (negative patterns)
# Lưu ý: transcript có thể chứa pattern irrelevant NHƯNG vẫn hợp lệ nếu
# có child context (vd: "trời mưa, bé Lan ốm"). Rule 2 sẽ xử lý trường hợp này.
IRRELEVANT_PATTERNS: list[str] = [
    # Giáo dục/lớp học (người lớn)
    r"bài giảng", r"giáo viên", r"sinh viên", r"điểm danh",
    r"kiểm tra", r"thi cử", r"bài tập", r"toán", r"văn",
    # Tin tức/thời sự
    r"tin tức", r"thời sự", r"báo chí", r"chính trị",
    # Thời tiết (không phải sức khỏe trẻ)
    r"trời mưa", r"trời nắng", r"nhiệt độ",
    # Công việc/văn phòng
    r"công việc", r"họp", r"deadline", r"email",
    # Thể thao (người lớn)
    r"bóng đá", r"tennis", r"gym", r"chạy bộ",
    # Giải trí người lớn
    r"ca sĩ", r"diễn viên", r"nghệ sĩ", r"showbiz", r"phim ảnh",
    r"karaoke",
    # Đồ uống có cồn / thuốc lá
    r"uống bia", r"uống rượu", r"bia rượu", r"hút thuốc",
    # Đời tư cá nhân
    r"vợ chồng", r"chồng tôi", r"vợ tôi",
    r"bạn trai", r"bạn gái", r"hẹn hò",
    # Tài chính người lớn
    r"lương", r"tiền lương", r"ngân hàng", r"vay tiền",
    # Du lịch
    r"du lịch", r"máy bay", r"khách sạn", r"resort",
    # Mạng xã hội
    r"youtube", r"tiktok", r"mạng xã hội", r"facebook",
    # Test/demo
    r"^test\s", r"^demo\s", r"^abc\s",
]


# ============================================================================
# VALIDATION RESULT
# ============================================================================

class ValidationResult:
    """Kết quả kiểm tra transcript."""
    
    def __init__(
        self,
        is_valid: bool,
        matched_categories: list[str],
        matched_keywords: dict[str, int],
        reason: str | None = None,
        confidence_score: float = 0.0
    ):
        self.is_valid = is_valid
        self.matched_categories = matched_categories
        self.matched_keywords = matched_keywords
        self.reason = reason
        self.confidence_score = confidence_score
    
    def __repr__(self):
        return (
            f"ValidationResult(valid={self.is_valid}, "
            f"categories={self.matched_categories}, "
            f"score={self.confidence_score:.2f})"
        )


# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

def validate_transcript_content(transcript: str) -> ValidationResult:
    """
    Kiểm tra xem transcript có phải nội dung báo cáo học sinh mầm non không.
    
    Args:
        transcript: Text cần kiểm tra
        
    Returns:
        ValidationResult với thông tin chi tiết
        
    Raises:
        ValidationError: Nếu transcript không hợp lệ
    """
    if not transcript or not transcript.strip():
        raise ValidationError(
            "Transcript trống. Vui lòng nhập nội dung báo cáo.",
            reason="empty_transcript"
        )
    
    transcript_lower = transcript.lower()
    matched_categories: list[str] = []
    matched_keywords: dict[str, int] = {}
    
    # Đếm keywords cho mỗi category
    category_counts = {
        "child_references": 0,
        "eating": 0,
        "sleeping": 0,
        "health": 0,
        "activities": 0,
        "mood": 0
    }
    
    # 1. Check child references
    for kw in CHILD_REFERENCES:
        if kw in transcript_lower:
            category_counts["child_references"] += 1
    
    # 2. Check eating keywords
    for kw in EATING_KEYWORDS:
        if kw in transcript_lower:
            category_counts["eating"] += 1
    
    # 3. Check sleeping keywords
    for kw in SLEEPING_KEYWORDS:
        if kw in transcript_lower:
            category_counts["sleeping"] += 1
    
    # 4. Check health keywords
    for kw in HEALTH_KEYWORDS:
        if kw in transcript_lower:
            category_counts["health"] += 1
    
    # 5. Check activities keywords
    for kw in ACTIVITIES_KEYWORDS:
        if kw in transcript_lower:
            category_counts["activities"] += 1
    
    # 6. Check mood keywords
    for kw in MOOD_KEYWORDS:
        if kw in transcript_lower:
            category_counts["mood"] += 1
    
    # Lấy categories có keywords
    for cat, count in category_counts.items():
        if count > 0:
            matched_categories.append(cat)
            matched_keywords[cat] = count
    
    # 7. Check for irrelevant patterns
    irrelevant_matches = []
    for pattern in IRRELEVANT_PATTERNS:
        if re.search(pattern, transcript_lower):
            irrelevant_matches.append(pattern)
    
    # =========================================================================
    # VALIDATION RULES
    # =========================================================================
    
    # Rule 1: Transcript quá ngắn
    if len(transcript.strip()) < 10:
        raise ValidationError(
            "Transcript quá ngắn. Vui lòng nhập nội dung dài hơn.",
            reason="too_short"
        )
    
    # Rule 2: Transcript có patterns không liên quan
    # Chỉ reject khi có irrelevant AND không có child context.
    # Lý do: transcript có thể chứa từ ngữ "người lớn" (vd: "trời mưa", "email")
    # nhưng vẫn hợp lệ nếu có child_references (vd: "trời mưa, bé Lan ốm").
    has_child_context = category_counts["child_references"] > 0
    if irrelevant_matches and not has_child_context:
        raise ValidationError(
            "Nội dung transcript có vẻ không liên quan đến báo cáo học sinh. "
            "Vui lòng kiểm tra lại nội dung.",
            reason="irrelevant_content"
        )
    
    # Rule 3: Cần ít nhất 1 categories có keywords
    if len(matched_categories) < 1:
        raise ValidationError(
            "Transcript không có đủ thông tin báo cáo học sinh. "
            "Vui lòng kiểm tra lại nội dung.",
            reason="insufficient_categories"
        )
    
    # Rule 4: Cần ít nhất 1 trong 5 categories quan trọng (eating, sleeping, health, activities, mood)
    important_categories = ["eating", "sleeping", "health","activities","mood"]
    has_important = any(cat in matched_categories for cat in important_categories)
    
    if not has_important:
        raise ValidationError(
            "Transcript thiếu thông tin quan trọng về ăn uống, ngủ nghỉ hoặc sức khỏe. "
            "Vui lòng kiểm tra lại nội dung.",
            reason="missing_important_info"
        )
    
    # Calculate confidence score
    total_matches = sum(category_counts.values())
    confidence_score = min(total_matches / 10, 1.0)  # Normalize to 0-1
    
    return ValidationResult(
        is_valid=True,
        matched_categories=matched_categories,
        matched_keywords=category_counts,
        confidence_score=confidence_score
    )


def is_transcript_valid(transcript: str) -> bool:
    """
    Kiểm tra nhanh xem transcript có hợp lệ không.
    
    Args:
        transcript: Text cần kiểm tra
        
    Returns:
        True nếu transcript hợp lệ, False otherwise
    """
    try:
        validate_transcript_content(transcript)
        return True
    except ValidationError:
        return False


def get_validation_details(transcript: str) -> dict:
    """
    Lấy chi tiết validation mà không raise exception.
    
    Args:
        transcript: Text cần kiểm tra
        
    Returns:
        Dict chứa thông tin validation chi tiết
    """
    try:
        result = validate_transcript_content(transcript)
        return {
            "is_valid": result.is_valid,
            "matched_categories": result.matched_categories,
            "matched_keywords": result.matched_keywords,
            "confidence_score": result.confidence_score,
            "error": None
        }
    except ValidationError as e:
        return {
            "is_valid": False,
            "matched_categories": [],
            "matched_keywords": {},
            "confidence_score": 0.0,
            "error": str(e),
            "reason": e.reason
        }


# ============================================================================
# CUSTOM EXCEPTION
# ============================================================================

class ValidationError(Exception):
    """Exception raised khi transcript không hợp lệ."""
    
    def __init__(self, message: str, reason: str = "unknown"):
        self.message = message
        self.reason = reason
        super().__init__(self.message)


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    # Test cases
    test_transcripts = [
        # ✅ Valid transcripts
        "Hôm nay bé ăn ngon, tự xúc hết bát cơm. Ngủ trưa ngủ một mạch. Khỏe mạnh. Chơi cầu trượt vui vẻ.",
        "Con chán ăn, ngậm cơm. Trằn trọc khó ngủ. Bị ho nhẹ. Tâm trạng buồn.",
        
        # ❌ Invalid transcripts
        "Trời hôm nay nắng đẹp, nhiệt độ 30 độ C.",
        "Bài giảng toán hôm nay về phương trình bậc 2.",
        "Đội bóng đá Việt Nam thắng 3-1.",
    ]
    
    for i, transcript in enumerate(test_transcripts):
        print(f"\n{'='*60}")
        print(f"Test {i+1}: {'VALID' if is_transcript_valid(transcript) else 'INVALID'}")
        print(f"Transcript: {transcript[:80]}...")
        details = get_validation_details(transcript)
        print(f"Details: {details}")
