"""
name_matching_service.py

Service matching tên trẻ với transcript sử dụng scoring system.

Logic:
- Đếm số từ trong transcript match với full_name của mỗi bé
- Score = matched_words / total_words_in_full_name
- Nickname được bonus thêm để tăng confidence

Ví dụ:
    Full name: "Nguyễn Văn Lan"

    Transcript: "Nguyễn Văn Lan ăn ngon"  → 3/3 từ → confidence = 1.0
    Transcript: "Nguyễn Lan ăn ngon"       → 2/3 từ → confidence = 0.67
    Transcript: "Lan ăn ngon"              → 1/3 từ → confidence = 0.33
"""

from dataclasses import dataclass

from app.models.child import Child
from sqlalchemy.orm import Session

# =============== CONFIG ===============

# Ngưỡng confidence tối thiểu để coi là match
MIN_CONFIDENCE_THRESHOLD = 0.3  # 30% words phải match

# Trọng số cho nickname (bonus thêm vào score)
NICKNAME_BONUS = 0.15  # +15% nếu có match nickname

# Số từ tối thiểu phải match để được coi là candidate
MIN_MATCHED_WORDS = 1


# =============== DATACLASS ===============


@dataclass
class NameMatch:
    """Kết quả matching cho 1 bé."""

    child_id: str
    full_name: str
    nickname: str | None
    matched_words: list[str]  # VD: ["nguyễn", "lan"]
    confidence: float  # VD: 0.67
    is_ambiguous: bool = False  # True nếu có bé khác cùng confidence

    def __repr__(self):
        return (
            f"NameMatch(child_id={self.child_id}, "
            f"matched={self.matched_words}, "
            f"confidence={self.confidence:.2f})"
        )


@dataclass
class SegmentMatch:
    """Kết quả matching cho 1 segment trong transcript."""

    segment_text: str
    matches: list[NameMatch]  # Danh sách bé match được (có thể > 1)
    is_ambiguous: bool  # True nếu > 1 bé cùng confidence cao nhất


# =============== HELPER FUNCTIONS ===============


def _tokenize(text: str) -> list[str]:
    """Tách text thành list từ (lowercase)."""
    if not text:
        return []
    # Remove punctuation, lowercase, split
    import re

    text = re.sub(r'[.!?,;:\(\)\[\]"\'\-–—]', " ", text.lower())
    return [w.strip() for w in text.split() if w.strip()]


def _calculate_word_overlap(text_words: list[str], name_words: list[str]) -> list[str]:
    """Tìm các từ trong text mà match với name_words."""
    name_words_lower = set(name_words)
    return [w for w in text_words if w in name_words_lower]


def _calculate_nickname_overlap(text_words: list[str], nickname: str | None) -> bool:
    """Kiểm tra nickname có xuất hiện trong text không."""
    if not nickname:
        return False

    nickname_words = _tokenize(nickname)
    # Check if any nickname word appears in text
    text_words_set = set(text_words)
    return any(w in text_words_set for w in nickname_words)


def match_single_text(
    text: str,
    children: list[Child],
    min_confidence: float = MIN_CONFIDENCE_THRESHOLD,
    include_ambiguous: bool = True,
) -> list[NameMatch]:
    """
    Match tất cả các bé với 1 đoạn text.

    Args:
        text: Đoạn text cần match (VD: "Nguyễn Lan ăn ngon")
        children: Danh sách Child objects
        min_confidence: Ngưỡng confidence tối thiểu
        include_ambiguous: Nếu True, trả về tất cả bé có confidence >= min
                          Nếu False, chỉ trả về bé có confidence cao nhất

    Returns:
        List[NameMatch] - Danh sách các bé match được
    """
    if not text or not children:
        return []

    text_words = _tokenize(text)

    matches = []
    for child in children:
        full_name = child.full_name or ""
        name_words = _tokenize(full_name)

        if not name_words:
            continue

        # 1. Calculate name match
        matched_words = _calculate_word_overlap(text_words, name_words)
        name_score = len(matched_words) / len(name_words) if name_words else 0

        # 2. Calculate nickname bonus
        nickname_bonus = 0
        if _calculate_nickname_overlap(text_words, child.nickname):
            # Nickname match = bonus
            nickname_bonus = NICKNAME_BONUS

        # 3. Total confidence
        confidence = min(name_score + nickname_bonus, 1.0)  # Cap at 1.0

        # 4. Check minimum threshold
        if confidence < min_confidence or len(matched_words) < MIN_MATCHED_WORDS:
            continue

        matches.append(
            NameMatch(
                child_id=str(child.child_id),
                full_name=full_name,
                nickname=child.nickname,
                matched_words=matched_words,
                confidence=confidence,
            )
        )

    # Sort by confidence descending
    matches.sort(key=lambda x: -x.confidence)

    # Mark ambiguous (nếu có > 1 bé cùng confidence cao nhất)
    if len(matches) > 1 and include_ambiguous:
        top_confidence = matches[0].confidence
        for m in matches:
            m.is_ambiguous = (
                m.confidence == top_confidence
                and len([x for x in matches if x.confidence == top_confidence]) > 1
            )

    return matches


def segment_and_match(
    transcript: str,
    children: list[Child],
    min_confidence: float = MIN_CONFIDENCE_THRESHOLD,
) -> list[SegmentMatch]:
    """
    Tách transcript thành các segment (theo dấu chấm/câu) và match từng segment.

    Args:
        transcript: Full transcript text
        children: Danh sách Child objects
        min_confidence: Ngưỡng confidence tối thiểu

    Returns:
        List[SegmentMatch] - Kết quả cho mỗi segment
    """
    import re

    if not transcript or not children:
        return []

    # Split by sentence boundaries
    segments = re.split(r"[.!?\n]+", transcript)
    segments = [s.strip() for s in segments if s.strip()]

    results = []
    for segment in segments:
        segment_matches = match_single_text(
            segment, children, min_confidence=min_confidence
        )

        is_ambiguous = (
            len(segment_matches) > 1
            and segment_matches[0].confidence == segment_matches[1].confidence
        )

        results.append(
            SegmentMatch(
                segment_text=segment,
                matches=segment_matches,
                is_ambiguous=is_ambiguous,
            )
        )

    return results


# =============== HIGH-LEVEL API ===============


def match_children_for_transcript(
    transcript: str,
    db: Session,
    class_id: str | None = None,
    min_confidence: float = MIN_CONFIDENCE_THRESHOLD,
) -> dict:
    """
    High-level API: Match tất cả bé trong lớp với transcript.

    Args:
        transcript: Full transcript text
        db: Database session
        class_id: Lọc theo class_id (optional)
        min_confidence: Ngưỡng confidence tối thiểu

    Returns:
        {
            "segments": [
                {
                    "text": "Nguyễn Lan ăn ngon",
                    "matches": [
                        {"child_id": "...", "full_name": "...", "confidence": 0.67, ...}
                    ],
                    "is_ambiguous": False
                },
                ...
            ],
            "unique_children_matched": ["child_id_1", "child_id_2", ...],
            "total_segments": 5,
            "segments_with_matches": 3,
            "ambiguous_segments": 1,
        }
    """
    # Get all children in class
    query = db.query(Child)
    if class_id:
        query = query.filter(Child.class_id == class_id)
    children = query.all()

    if not children:
        return {
            "segments": [],
            "unique_children_matched": [],
            "total_segments": 0,
            "segments_with_matches": 0,
            "ambiguous_segments": 0,
        }

    # Segment and match
    segment_results = segment_and_match(transcript, children, min_confidence)

    # Collect unique child IDs
    unique_children = set()
    for seg in segment_results:
        for m in seg.matches:
            unique_children.add(m.child_id)

    # Count stats
    segments_with_matches = sum(1 for s in segment_results if s.matches)
    ambiguous_segments = sum(1 for s in segment_results if s.is_ambiguous)

    return {
        "segments": [
            {
                "text": seg.segment_text,
                "matches": [
                    {
                        "child_id": m.child_id,
                        "full_name": m.full_name,
                        "nickname": m.nickname,
                        "matched_words": m.matched_words,
                        "confidence": round(m.confidence, 2),
                        "is_ambiguous": m.is_ambiguous,
                    }
                    for m in seg.matches
                ],
                "is_ambiguous": seg.is_ambiguous,
            }
            for seg in segment_results
        ],
        "unique_children_matched": list(unique_children),
        "total_segments": len(segment_results),
        "segments_with_matches": segments_with_matches,
        "ambiguous_segments": ambiguous_segments,
    }


def get_best_match_for_segment(
    segment_text: str,
    children: list[Child],
    min_confidence: float = 0.5,  # Higher threshold for "best" match
) -> NameMatch | None:
    """
    Lấy match tốt nhất cho 1 segment (confidence cao nhất, không ambiguous).

    Args:
        segment_text: Text cần match
        children: Danh sách Child objects
        min_confidence: Ngưỡng confidence (mặc định 50% cho best match)

    Returns:
        NameMatch hoặc None nếu không có match rõ ràng
    """
    matches = match_single_text(segment_text, children, min_confidence=min_confidence)

    # Chỉ trả về nếu có đúng 1 match cao nhất
    if not matches:
        return None

    # Nếu có nhiều match cùng confidence → ambiguous → không trả về
    if len(matches) > 1 and matches[0].confidence == matches[1].confidence:
        return None

    return matches[0]
