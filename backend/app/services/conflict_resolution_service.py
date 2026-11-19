"""
app/services/conflict_resolution_service.py
============================================
Bộ xử lý đối nghịch / mâu thuẫn ngữ nghĩa (Conflict Resolution Engine)
cho trích xuất báo cáo học sinh mầm non.

MỤC ĐÍCH:
Khi tổng hợp thông tin cho một thực thể (học sinh hoặc cả lớp) theo từng mục
(meals, sleeping, health, activities, mood):
1. Thông tin bổ sung / không liên quan (như món ăn: "ăn cháo", "uống sữa",
   hoặc hoạt động: "vẽ tranh", "xếp hình"): CỘNG DỒN, giữ nguyên.
2. Thông tin đối nghịch về trạng thái / tính chất (như "ăn ngon" vs "ăn không ngon",
   "ngủ một mạch" vs "trằn trọc khó ngủ", "khỏe mạnh" vs "sốt nhẹ"):
   CỤM ĐẾN SAU SẼ ĐÈ / LOẠI BỎ CỤM TRƯỚC ĐÓ.

VÍ DỤ:
- ["ăn ngon", "ăn cháo"] + ["ăn không ngon"]
  -> ["ăn cháo", "ăn không ngon"] ("ăn ngon" bị xóa vì đối nghịch "ăn không ngon", "ăn cháo" giữ nguyên).
- ["ngủ một mạch", "ôm gấu bông"] + ["trằn trọc khó ngủ"]
  -> ["ôm gấu bông", "trằn trọc khó ngủ"].
"""

from __future__ import annotations

import logging
import re
from typing import Sequence

logger = logging.getLogger(__name__)

# ===========================================================================
# 1. BẢNG PHÂN CỤM NGỮ NGHĨA & CỰC ĐỐI NGHỊCH (THEO TRAIN-LABELS V3)
# ===========================================================================

CONFLICT_RULES: dict[str, list[tuple[str, dict[str, list[str]]]]] = {
    "meals": [
        (
            "eating_quality",
            {
                "POS": [
                    r"\b(?:ăn\s+(?:uống\s+)?(?:rất\s+)?(?:ngon|ngoan)|ngon\s+miệng|ăn\s+ngon\s+lành|"
                    r"hào\s+hứng\s+ăn|ăn\s+tì\s+tì|ăn\s+tích\s+cực|ăn\s+hết|ăn\s+gần\s+hết|"
                    r"tự\s+xúc\s+ăn\s+hết|húp\s+hết|uống\s+hết|vét\s+sạch|xong\s+tô|ăn\s+hết\s+sạch|"
                    r"ăn\s+hết\s+veo|bụng\s+no(?:\s+căng)?|ăn\s+no|đủ\s+no)\b"
                ],
                "NEG": [
                    r"\b(?:ăn\s+(?:rất\s+)?(?:không\s+ngon|không\s+ngoan)|không\s+ngon|chẳng\s+ngon|"
                    r"không\s+chịu\s+ăn|không\s+muốn\s+ăn|chán\s+ăn|lười\s+ăn|từ\s+chối\s+ăn|"
                    r"không\s+thèm\s+ăn|không\s+thích\s+ăn|chưa\s+ăn\s+được|không\s+ăn\s+được|"
                    r"không\s+ăn\s+tiếp|không\s+ăn|bỏ\s+cơm|bỏ\s+mứa|bỏ\s+suất|bỏ\s+hết|bỏ\s+luôn|"
                    r"để\s+thừa|ăn\s+ít|chỉ\s+ăn\s+ít|chỉ\s+nuốt\s+vài|chỉ\s+uống\s+một\s+ngụm|"
                    r"ăn\s+vài\s+miếng|ăn\s+được\s+ít|ăn\s+một\s+nửa|ăn\s+nửa|được\s+một\s+nửa|được\s+ít|"
                    r"ngậm\s+cơm|ngậm|nhè(?:\s+đồ\s+ăn|\s+cơm)?|nôn\s+ra|nôn\s+ói|bị\s+nghẹn|bị\s+sặc|"
                    r"nhai\s+lâu\s+nuốt\s+chậm)\b"
                ],
            },
        ),
        (
            "feeding_method",
            {
                "SELF": [
                    r"\b(?:tự\s+xúc|tự\s+bưng|tự\s+cầm\s+(?:thìa|muỗng|bình|nĩa|đũa)|"
                    r"tự\s+gắp|tự\s+giác|tự\s+ăn)\b"
                ],
                "ASSISTED": [
                    r"\b(?:cô\s+(?:phải\s+)?đút|phải\s+đút|cô\s+(?:phải\s+)?dỗ|phải\s+dỗ|"
                    r"cô\s+(?:phải\s+)?nhắc|phải\s+nhắc|đòi\s+(?:cô|mẹ)\s+đút|cô\s+lừa\s+lừa)\b"
                ],
            },
        ),
    ],
    "sleeping": [
        (
            "sleep_quality",
            {
                "POS": [
                    r"\b(?:ngủ\s+(?:rất\s+)?ngon|ngủ\s+say|ngủ\s+một\s+mạch|ngủ\s+li\s+bì|"
                    r"ngủ\s+dài|ngủ\s+trưa\s+ngon|ngủ\s+trưa\s+ngoan|giấc\s+ngon|ngủ\s+yên|"
                    r"thở\s+đều|dậy\s+(?:thì\s+)?tỉnh\s+táo)\b"
                ],
                "NEG": [
                    r"\b(?:ngủ\s+không\s+ngon|ngủ\s+không\s+yên|khó\s+ngủ|trằn\s+trọc|"
                    r"hay\s+thức\s+giấc|thức\s+giấc|không\s+chịu\s+ngủ|không\s+ngủ\s+được|"
                    r"ngủ\s+ngắn|ngủ\s+chập\s+chờn|giật\s+mình|quấy\s+khóc|gắt\s+ngủ|"
                    r"khóc\s+ngủ|khóc\s+đòi\s+mẹ|ngồi\s+dậy\s+khóc|quấy)\b"
                ],
            },
        ),
    ],
    "mood": [
        (
            "emotion",
            {
                "POS": [
                    r"\b(?:vui\s+vẻ|vui|hào\s+hứng|hớn\s+hở|sung\s+sướng|phấn\s+khích|"
                    r"thích\s+thú|khoái\s+chí|vui\s+tươi|vui\s+mừng|cười\s+toe\s+toét|mỉm\s+cười)\b"
                ],
                "NEG": [
                    r"\b(?:buồn|buồn\s+hiu|khó\s+chịu|khóc|khóc\s+nhè|khóc\s+lóc|khóc\s+to|"
                    r"quấy\s+phá|cáu\s+kỉnh|hờn\s+dỗi|tủi\s+thân|mếu\s+máo|hậm\s+hực|giận)\b"
                ],
            },
        ),
        (
            "focus",
            {
                "POS": [
                    r"\b(?:tập\s+trung|chăm\s+chỉ|kiên\s+nhẫn|kiên\s+trì|say\s+mê|lễ\s+phép)\b"
                ],
                "NEG": [r"\b(?:không\s+tập\s+trung|lơ\s+đễnh|nghịch\s+ngợm)\b"],
            },
        ),
    ],
    "health": [
        (
            "general_status",
            {
                "POS": [
                    r"\b(?:khỏe\s+mạnh|khỏe|bình\s+thường|không\s+sốt|tỉnh\s+táo)\b"
                ],
                "NEG": [
                    r"\b(?:mệt\s+mỏi|mệt|uể\s+oải|lừ\s+đừ|sốt|sốt\s+nhẹ|sốt\s+cao|ấm\s+đầu|ốm|"
                    r"sổ\s+mũi|ho(?:\s+khan|\s+nhẹ|\s+nhiều)?|đau\s+bụng|nôn\s+ói|tiêu\s+chảy|"
                    r"dị\s+ứng|ngứa)\b"
                ],
            },
        ),
    ],
    "activities": [
        (
            "social",
            {
                "TOGETHER": [
                    r"\b(?:chơi\s+cùng\s+bạn|chơi\s+với\s+bạn|tích\s+cực\s+tham\s+gia|hòa\s+đồng)\b"
                ],
                "ALONE": [
                    r"\b(?:chơi\s+một\s+mình|ngồi\s+thu\s+lu|không\s+tham\s+gia|bĩu\s+môi\s+ngồi\s+im)\b"
                ],
            },
        ),
    ],
}

# Tiền tố phủ định
NEG_PREFIXES = {"không", "chưa", "chẳng", "lười", "chán", "khó"}

# Từ thông dụng / động từ cơ bản không dùng làm từ gốc phân định mâu thuẫn
GENERIC_STOPWORDS = {
    "bé",
    "con",
    "em",
    "cháu",
    "cô",
    "bị",
    "rất",
    "lại",
    "thì",
    "ăn",
    "uống",
    "ngủ",
    "chơi",
    "học",
    "đi",
    "làm",
    "được",
    "cho",
    "vào",
}

# Từ thừa/liên từ nối ở đầu hoặc cuối phrase do BIO tagger cắt dính
LEAD_TRAIL_JUNK_PATTERNS = [
    r"^\s*(?:nhưng|rồi|lại|sau\s+đó|sau|thì|mà|và|còn)\s+",
    r"\s+(?:nhưng|sau\s+đó|sau|thì|mà|và)\s*$",
]


# ===========================================================================
# 2. HELPER FUNCTIONS
# ===========================================================================


def clean_phrase(phrase: str) -> str:
    """Làm sạch ký tự dấu câu và các liên từ thừa dính ở đầu/cuối cụm từ."""
    if not phrase:
        return ""
    p = phrase.strip(" \t\n,.;:!?-–—")
    for pat in LEAD_TRAIL_JUNK_PATTERNS:
        p = re.sub(pat, "", p, flags=re.IGNORECASE).strip(" \t\n,.;:!?-–—")
    return p


def get_dimension_polarity(phrase: str, category: str) -> tuple[str | None, str | None]:
    """
    Xác định (khía_cạnh, cực_tính) của phrase trong category.
    Ví dụ: ("ăn ngon", "meals") -> ("eating_quality", "POS")
           ("ăn cháo", "meals") -> (None, None)  # Món ăn, additive
    """
    p_lower = phrase.lower().strip()
    dims = CONFLICT_RULES.get(category, [])
    for dim_name, pol_dict in dims:
        for pol, patterns in pol_dict.items():
            for pat in patterns:
                if re.search(pat, p_lower):
                    return dim_name, pol
    return None, None


def check_stem_negation(p1: str, p2: str) -> bool:
    """
    Kiểm tra phủ định từ gốc (VD: 'vui vẻ' vs 'không vui', 'ngủ yên' vs 'ngủ không yên').
    Loại trừ các từ gốc chung như 'ăn', 'uống' để 'ăn cháo' không bị coi là phủ định 'ăn không ngon'.
    """
    t1 = set(re.sub(r"[.!?,;:]", "", p1.lower()).split())
    t2 = set(re.sub(r"[.!?,;:]", "", p2.lower()).split())
    has_neg1 = bool(t1 & NEG_PREFIXES)
    has_neg2 = bool(t2 & NEG_PREFIXES)

    if has_neg1 != has_neg2:
        common = (t1 - NEG_PREFIXES) & (t2 - NEG_PREFIXES) - GENERIC_STOPWORDS
        if common:
            return True
    return False


def are_contradictory(p1: str, p2: str, category: str) -> bool:
    """
    Kiểm tra xem hai phrase trong cùng category có đối nghịch nhau không.
    Trả về True nếu mâu thuẫn ngữ nghĩa (cần đè / loại bỏ).
    """
    d1, pol1 = get_dimension_polarity(p1, category)
    d2, pol2 = get_dimension_polarity(p2, category)

    # Nếu cùng khía cạnh nhưng khác cực tính -> MÂU THUẪN
    if d1 and d2 and d1 == d2 and pol1 != pol2:
        return True

    # Kiểm tra phủ định gốc từ chung
    if check_stem_negation(p1, p2):
        return True

    return False


# ===========================================================================
# 3. CORE CONFLICT RESOLVER
# ===========================================================================


def resolve_conflicts(phrases: Sequence[str], category: str) -> list[str]:
    """
    Giải quyết mâu thuẫn cho danh sách các phrase theo thứ tự thời gian xuất hiện.

    Quy tắc:
    - Nếu phrase mới đối nghịch với phrase cũ đã có: XÓA phrase cũ, THÊM phrase mới.
    - Nếu phrase mới là trùng lặp hoặc chuỗi con của phrase cũ không đối nghịch: BỎ QUA.
    - Nếu phrase cũ là chuỗi con ngắn hơn của phrase mới (vd 'cháo' vs 'ăn cháo'):
      thay thế bằng phrase mới đầy đủ hơn.
    - Các phrase độc lập (như món ăn 'ăn cháo', 'uống sữa') giữ nguyên vẹn.

    Args:
        phrases: Danh sách các cụm từ theo thứ tự thời gian.
        category: meals | sleeping | health | activities | mood

    Returns:
        Danh sách các cụm từ sau khi đã xử lý đối nghịch.
    """
    resolved: list[str] = []

    for raw_p in phrases:
        cleaned = clean_phrase(raw_p)
        if not cleaned:
            continue

        filtered: list[str] = []
        is_subsumed = False

        for old_p in resolved:
            # 1. Trùng lặp hoàn toàn
            if old_p.lower() == cleaned.lower():
                is_subsumed = True
                filtered.append(old_p)
                continue

            # 2. Đối nghịch ngữ nghĩa: phrase cũ bị phrase mới triệt tiêu
            if are_contradictory(old_p, cleaned, category):
                logger.debug(
                    "[ConflictResolution] Dropping '%s' because contradicted by '%s' in %s",
                    old_p,
                    cleaned,
                    category,
                )
                continue

            # 3. Phrase cũ là chuỗi con ngắn hơn (và không mâu thuẫn) -> nâng cấp lên phrase mới
            if old_p.lower() in cleaned.lower():
                continue

            # 4. Phrase mới là chuỗi con ngắn hơn của phrase cũ -> giữ phrase cũ
            if cleaned.lower() in old_p.lower():
                is_subsumed = True
                filtered.append(old_p)
                continue

            filtered.append(old_p)

        if not is_subsumed:
            filtered.append(cleaned)

        resolved = filtered

    return resolved


def merge_category_phrases(
    current_phrases: list[str],
    incoming: str | list[str] | None,
    category: str,
) -> list[str]:
    """
    Merge danh sách phrase hiện tại với phrase mới (chuỗi hoặc danh sách).
    Tự động tách dấu phẩy nếu incoming là chuỗi, sau đó chạy resolve_conflicts.
    """
    if not incoming:
        return current_phrases

    if isinstance(incoming, str):
        incoming_items = [p.strip() for p in incoming.split(",") if p.strip()]
    else:
        incoming_items = [str(p).strip() for p in incoming if str(p).strip()]

    combined = list(current_phrases) + incoming_items
    return resolve_conflicts(combined, category)


def resolve_conflicts_in_text(text: str | None, category: str) -> str | None:
    """Tiện ích xử lý chuỗi nối bằng dấu phẩy."""
    if not text or not text.strip():
        return None

    phrases = [p.strip() for p in text.split(",") if p.strip()]
    resolved = resolve_conflicts(phrases, category)
    return ", ".join(resolved) if resolved else None
