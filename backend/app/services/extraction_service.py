"""
extraction_service.py

AI Service cho trích xuất dữ liệu từ transcript.

INPUT MẪU (Single):
"Hôm nay bé Lan ăn ngon lắm, hết suất cơm. Bé ngủ trưa ngon lành 2 tiếng.
 Chiều bé ho nhẹ. Bé vẽ tranh đẹp lắm. Bé rất vui vẻ."

OUTPUT MẪU:
{
    "meals": "ăn ngon, hết suất cơm",
    "sleeping": "ngủ trưa ngon lành 2 tiếng",
    "health": "ho nhẹ",
    "activities": "vẽ tranh đẹp",
    "mood": "vui vẻ"
}

INPUT MẪU (Multi-Person):
"Nguyễn Văn Lan ăn ngon. Trần Minh Hoàng ngủ trưa ngon. Cả lớp vui chơi."

OUTPUT MẪU (Multi-Person):
{
    "segments": [
        {
            "text": "Nguyễn Văn Lan ăn ngon",
            "child_matches": [
                {"child_id": "...", "full_name": "Nguyễn Văn Lan", "confidence": 1.0}
            ],
            "extraction": {"meals": "ăn ngon", ...}
        },
        ...
    ],
    "child_extractions": {
        "child_uuid_1": {"meals": "...", "sleeping": "...", ...},
        "child_uuid_2": {...}
    }
}

"""

import logging
import math
import os
import re
import threading

import torch
from torch import nn

logger = logging.getLogger(__name__)

# =============== MODEL LOADING ===============


class LSTMClassifier(nn.Module):
    def __init__(self, vocab_size, embedding_dim, hidden_dim, num_classes):
        super().__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)
        self.lstm = nn.LSTM(embedding_dim, hidden_dim, batch_first=True)
        self.fc = nn.Linear(hidden_dim, num_classes)

    def forward(self, x):
        embedded = self.embedding(x)
        output, _ = self.lstm(embedded)  # Giữ toàn bộ hidden states
        output = self.fc(output)  # Output shape: (batch, seq_len, num_classes)
        return output


# Load model khi import
MODEL_PATH = os.path.join(os.path.dirname(__file__), "bio_lstm_model_v3.pt")

_label_to_id = None
_id_to_label = None
_vocab = None
_model = None
_device = None
_load_lock = threading.Lock()


def _load_model():
    """Thread-safe singleton model loader với double-check locking."""
    global _model, _vocab, _label_to_id, _id_to_label, _device
    if _model is not None:
        return

    with _load_lock:
        # Double-check sau khi acquire lock (thread khác có thể đã load xong)
        if _model is not None:
            return

        _device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

        checkpoint = torch.load(MODEL_PATH, map_location=_device)
        _vocab = checkpoint["vocab"]
        _label_to_id = checkpoint["label_to_id"]
        _id_to_label = {v: k for k, v in _label_to_id.items()}

        _model = LSTMClassifier(
            vocab_size=len(_vocab),
            embedding_dim=checkpoint["embedding_dim"],
            hidden_dim=checkpoint["hidden_dim"],
            num_classes=len(_label_to_id),
        )
        _model.load_state_dict(checkpoint["model_state_dict"])
        _model.to(_device)
        _model.eval()

        logger.info("[Extraction] LSTM model loaded on %s", _device)


def _tokenizer(text: str):
    text = text.lower()
    text = re.sub(r"[.!?,;:]", "", text)
    return text.split()


def _numericalize(text: str):
    tokens = _tokenizer(text)
    return [_vocab.get(token, _vocab["<unk>"]) for token in tokens]


def _extract_bio_phrases(tokens, pred_labels):
    """Parse BIO tags thành list phrases theo từng label.

    Xử lý các trường hợp BIO sai mà model hay dự đoán:
      - I-X không có B-X nào mở trước  -> coi như B-X.
        (Cách cũ bỏ rơi token này, làm mất cả entity.)
      - I-X khác loại với B đang mở   -> đóng entity cũ, mở entity mới B-X.
        (Cách cũ nối nhầm token sang field khác.)
      - Nhãn có loại lạ (vd B-UNK)     -> coi như O, không dính vào entity trước.
    """
    result = {"meals": [], "sleeping": [], "health": [], "activities": [], "mood": []}

    current_phrase = []
    current_type = None

    def flush():
        nonlocal current_phrase, current_type
        if current_type and current_phrase and current_type in result:
            result[current_type].append(" ".join(current_phrase))
        current_phrase = []
        current_type = None

    for token, pred_label in zip(tokens, pred_labels):
        if pred_label == "O":
            flush()
            continue

        if not pred_label.startswith(("B-", "I-")):
            flush()
            continue

        ent_type = pred_label[2:].lower()
        if ent_type not in result:
            flush()
            continue

        if pred_label.startswith("I-") and current_type == ent_type:
            current_phrase.append(token)
        else:
            flush()
            current_phrase = [token]
            current_type = ent_type

    flush()
    return result


# =============== EXTRACTION FUNCTION ===============


def extract_from_transcript(transcript: str) -> dict:
    """
    Gọi model NLP trích xuất thông tin từ transcript (dùng BIO tagging).

    Args:
        transcript: Text từ STT

    Returns:
        dict: {
            "meals": str | None,      # String duy nhất (nối các phrase bằng ", ")
            "sleeping": str | None,
            "health": str | None,
            "activities": str | None,
            "mood": str | None
        }
    """
    if not transcript or not transcript.strip():
        return {
            "meals": None,
            "sleeping": None,
            "health": None,
            "activities": None,
            "mood": None,
        }

    _load_model()

    tokens = _tokenizer(transcript)
    input_ids = _numericalize(transcript)

    with torch.no_grad():
        tensor = torch.tensor([input_ids]).to(_device)
        output = _model(tensor)
        predictions = output.argmax(dim=-1)[0]  # shape: (seq_len,)

    pred_labels = [_id_to_label[pred.item()] for pred in predictions[: len(tokens)]]

    # Parse BIO tags
    phrases_by_label = _extract_bio_phrases(tokens, pred_labels)

    # Chuyển list → string (nối bằng ", ")
    result = {}
    for key, phrases in phrases_by_label.items():
        result[key] = ", ".join(phrases) if phrases else None

    return result


# =============== MULTI-PERSON EXTRACTION ===============

# Keywords indicate class-wide statements.
# NOTE: Temporal markers (“hôm nay”, “sáng nay”, “chiều nay”) đã được LOẠI Bỏ.
# Lý do: chúng là context starter (mở đầu câu), không phải class-wide marker.
# VD: "hôm nay Lan ăn ngon" → "hôm nay" chỉ thời gian, segment vẫn match Lan OK.
# Class-wide markers thực sự: cả lớp, các bé, mọi người, tất cả, ai cũng.
CLASS_WIDE_KEYWORDS = [
    "cả lớp", "các bé", "mọi người", "tất cả", "ai cũng",
]

# Confidence tối thiểu của child match để GHI ĐÈ class-wide keyword.
# Nếu match >= threshold → segment thuộc về child đó, không phải class-wide.
CHILD_MATCH_CONFIDENCE_THRESHOLD = 0.5

# Class-wide extraction fields (used to bucket class-wide statements).
# Dùng chung cho class_wide_lists init và iteration loop.
CLASS_WIDE_FIELDS: tuple[str, ...] = (
    "meals", "sleeping", "health", "activities", "mood",
)


def _is_class_wide_segment(segment_text: str, matches: list) -> bool:
    """
    Kiểm tra xem segment có phải là statement cho cả lớp không.

    Quy tắc ưu tiên (theo thứ tự):
    1. Nếu MATCH được child với confidence cao (>= CHILD_MATCH_CONFIDENCE_THRESHOLD)
       → segment thuộc về child đó, KHÔNG phải class-wide (kể cả khi có keyword).
    2. Nếu MATCH yếu (confidence < threshold) → coi như noise, vẫn check class-wide keyword.
    3. Không match ai → dùng class-wide keyword để quyết định.

    Lý do: keyword "cả lớp" có thể xuất hiện trong câu chứa tên bé cụ thể
    (ví dụ "cả lớp vui chơi nhưng Lan ăn hết suất"). Trong trường hợp này,
    child match mạnh hơn nên thắng keyword.
    """
    # Có child match đủ mạnh → segment này gắn với child đó
    if matches and matches[0].confidence >= CHILD_MATCH_CONFIDENCE_THRESHOLD:
        return False

    # Không có match hoặc match yếu → dùng keyword
    segment_lower = segment_text.lower()
    for keyword in CLASS_WIDE_KEYWORDS:
        if keyword in segment_lower:
            return True

    # Không có match và không có keyword → unmatched
    return False


def _smart_split_transcript(text: str, children: list, min_confidence: float = 0.3) -> list[str]:
    """
    Anchor-based fallback splitter khi transcript KHÔNG có dấu chấm/câu kết thúc.

    Whisper raw output cho tiếng Việt thường trả về 1 chuỗi dài, ví dụ:
        "Lan ăn ngon hết suất cả lớp vui chơi Hoàng ho nhẹ"

    Cách hoạt động:
    1. Match tên bé trên toàn text (giống match_single_text).
    2. Tìm vị trí xuất hiện đầu tiên của mỗi từ trong matched_words.
    3. Tìm vị trí xuất hiện của CLASS_WIDE_KEYWORDS.
    4. Sắp xếp anchors (unique, tăng dần) → cắt text theo từng anchor.

    Returns:
        List[str] - các đoạn text con đã được tách (mỗi đoạn đều non-empty).
        Nếu không tìm được anchor nào, trả về [text] (giữ nguyên 1 segment).
    """
    from app.services.name_matching_service import match_single_text

    text_lower = text.lower()
    anchors: set[int] = set()

    # 1. Anchors từ tên bé match được.
    #    Mỗi bé có thể có NHIỀU anchor (mỗi lần xuất hiện của tên trong text
    #    là 1 anchor). Lý do: giáo viên có thể nhắc tên bé nhiều lần trong
    #    cùng 1 transcript, và mỗi lần nhắc là 1 subject riêng biệt.
    #    VD: "Bé An ăn ngon ... bé an ngủ không ngon"
    #        → anchor tại "An" lần 1 VÀ "an" lần 2
    #        → tách thành 2 segment độc lập
    #    (Cách cũ chỉ lấy `re.search` (1 vị trí đầu tiên) trên `matched_words[0]`,
    #    nên "An" lần 2 bị nuốt vào segment trước đó.)
    matches = match_single_text(text, children, min_confidence=min_confidence)
    for m in matches:
        if not m.matched_words:
            continue
        # Tìm TẤT CẢ vị trí xuất hiện của TỪNG từ trong matched_words.
        # (?<!\w)...(?!\w) để "an" không khớp trong "anh", "bình" không khớp "bình an"
        # matched_words chỉ chứa các từ từ full_name thực sự xuất hiện trong text,
        # nên mỗi match = 1 anchor hợp lệ.
        for word in m.matched_words:
            word_pattern = re.escape(word.lower())
            for hit in re.finditer(
                rf"(?<!\w){word_pattern}(?!\w)", text_lower
            ):
                if hit.start() > 0:
                    anchors.add(hit.start())

    # 2. Anchors từ class-wide keywords
    for kw in CLASS_WIDE_KEYWORDS:
        kw_lower = kw.lower()
        idx = 0
        while True:
            idx = text_lower.find(kw_lower, idx)
            if idx < 0:
                break
            if idx > 0:
                anchors.add(idx)
            idx += len(kw_lower)

    # Không tìm được anchor nào → giữ nguyên 1 segment
    if not anchors:
        return [text.strip()] if text.strip() else []

    # 3. Sắp xếp anchors tăng dần, cắt text
    sorted_anchors = sorted(anchors)
    segments: list[str] = []
    prev = 0
    for anchor in sorted_anchors:
        chunk = text[prev:anchor].strip()
        if chunk:
            segments.append(chunk)
        prev = anchor
    # Đoạn cuối cùng (từ anchor cuối đến hết text)
    tail = text[prev:].strip()
    if tail:
        segments.append(tail)

    return segments


# Bật/tắt việc loại bỏ tên bé khỏi text trước khi trích xuất
STRIP_MATCHED_NAMES = True


def _strip_matched_names(segment_text: str, matches: list) -> str:
    """Bỏ các từ là tên bé ra khỏi segment trước khi đưa vào model.

    Vì sao cần: tên bé ở Việt Nam hay trùng từ thông dụng (An/ăn, Bình/bình,
    Khôi/khôi, Hà/hà). Model không có khái niệm "đây là tên riêng" nên gán
    B-MEALS cho "bình" chỉ vì trong tập train có nhiều cụm ăn uống chứa nó.

    Tên chỉ đóng vai trò anchor để biết segment này nói về bé nào, không mang
    thông tin sức khoẻ, nên bỏ đi là an toàn. Giữ nguyên text gốc cho frontend,
    chỉ thay text đưa vào model.
    """
    if not STRIP_MATCHED_NAMES or not segment_text or not matches:
        return segment_text

    name_words = set()
    for m in matches:
        for w in (getattr(m, "matched_words", None) or []):
            if w:
                name_words.add(w.lower())
        # Nickname cũng cần bỏ (có thể nhiều từ)
        for w in (getattr(m, "nickname", None) or "").lower().split():
            if w:
                name_words.add(w)

    if not name_words:
        return segment_text

    # Sắp xếp dài trước để "nguyễn văn" không bị "nguyễn" ăn mất trước.
    # Lookaround \w để chỉ khớp trọn từ, không khớp chuỗi con (vd "an" trong "anh").
    pattern = "|".join(
        re.escape(w) for w in sorted(name_words, key=len, reverse=True)
    )
    cleaned = re.sub(
        rf"(?<!\w)(?:{pattern})(?!\w)", " ", segment_text, flags=re.IGNORECASE
    )
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" \t\n,.;:!?-–—")

    # Cố tình KHÔNG giữ lại text gốc khi rỗng: segment chỉ chứa tên (vd anchor
    # bị smart-split tách riêng) không có nội dung sức khoẻ nào, để rỗng thì
    # _extract_single_segment trả về toàn None -- đúng ý.
    return cleaned


def _strip_class_wide_keywords(segment_text: str) -> str:
    """Bỏ class-wide keywords (cả lớp, các bé, ...) khỏi segment trước khi
    đưa vào model extraction.

    Vì sao cần: model được train với transcripts nói về 1 BÉ cụ thể, ít khi
    bắt đầu bằng "cả lớp". Khi test thấy model bị "lười" - thấy "cả lớp" ở
    đầu thì chỉ gán B-MOOD cho từ đầu tiên rồi O hết phần sau, bỏ sót
    activities/sleeping phía sau.

    Cách fix: bỏ "cả lớp"/"các bé"/... trước khi đưa vào model. Model vẫn học
    tốt với "vui chơi ngủ ngon" thuần (đã verify) nên chỉ cần strip anchor
    class-wide là đủ.

    Lưu ý: hàm này chỉ dùng cho `extraction_text` (input của model), KHÔNG
    đụng `segment_text` gốc trả về frontend (để metadata giữ nguyên).
    """
    if not segment_text:
        return segment_text

    # Pattern lookaround \w để chỉ match trọn từ, không khớp "lớp" trong "lớp học"...
    # (thực tế "lớp" thường đi với "cả" nên vẫn khớp, nhưng an toàn).
    pattern = "|".join(re.escape(kw) for kw in CLASS_WIDE_KEYWORDS)
    cleaned = re.sub(
        rf"(?<!\w)(?:{pattern})(?!\w)", " ", segment_text, flags=re.IGNORECASE
    )
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" \t\n,.;:!?-–—")
    return cleaned


def extract_multi_person(
    transcript: str,
    children: list,
    min_confidence: float = 0.3,
) -> dict:
    """
    Trích xuất thông tin cho NHIỀU bé từ 1 transcript cả lớp.

    Flow:
    1. Tách transcript thành các segment (theo câu)
    2. Dùng name_matching để xác định bé nào được nhắc đến trong mỗi segment
    3. Chạy NLP extraction cho từng segment
    4. Phân loại vào 3 bucket:
       - Class-wide (default): "cả lớp ăn ngon" → dùng cho TẤT CẢ children
       - Child-specific (override): "bé Lan ăn ít" → chỉ dùng cho bé Lan
       - Unmatched: không match được ai

    Logic mới (tách bucket):
    - Segment "cả lớp..." → append vào `class_wide_extraction`
    - Segment match được child cụ thể → REPLACE vào `child_extractions[child_id]`
      (chỉ chứa children CÓ override, không phải all 25)
    - Segment không match ai → `unmatched_segments` (không lưu content)

    Args:
        transcript: Full transcript text từ STT
        children: List[Child] - Danh sách tất cả bé trong lớp
        min_confidence: Ngưỡng confidence tối thiểu để match tên (default 30%)

    Returns:
        {
            "segments": [...],                          # Tất cả segments với metadata
            "class_wide_extraction": {                  # ← MỚI: default content cho cả lớp
                "meals": "...",                         #     (comma-joined nếu có nhiều)
                "sleeping": "...",
                "health": "...",
                "activities": "...",
                "mood": "..."
            },
            "child_extractions": {                      # CHỈ children có override
                "child_id": {
                    "meals": "...",
                    "sleeping": "...",
                    ...
                }
            },
            "ambiguous_segments": 1,
            "unmatched_segments": 2,
            "class_wide_segments": 1,
        }

    Note:
        Frontend merge logic: `final = merge(class_wide_extraction, child_extractions.get(child_id, {}))`
        - Class-wide dùng cho children KHÔNG có override
        - Child-specific REPLACE các field class-wide
    """
    import re

    from app.services.name_matching_service import match_single_text

    if not transcript or not transcript.strip():
        return {
            "segments": [],
            "class_wide_extraction": {
                "meals": None,
                "sleeping": None,
                "health": None,
                "activities": None,
                "mood": None,
            },
            "child_extractions": {},
            "ambiguous_segments": 0,
            "unmatched_segments": 0,
            "class_wide_segments": 0,
        }

    # ============ TÁCH TRANSCRIPT THÀNH SEGMENTS ============
    # Strategy: regex split theo dấu câu làm PRIMARY (chính xác khi có dấu).
    # Nếu regex chỉ tách được 1 segment (transcript không dấu - thường gặp với
    # Whisper VN) thì fallback smart split anchor-based.
    # Lý do không dùng smart split luôn: khi có dấu câu nhưng text chứa tên phổ
    # biến (vd "Văn" trong "Nguyễn Văn An"), match yếu với child khác có thể
    # tạo anchor sai giữa tên người (vd "Lê Văn Cường" match "văn" → cắt nhầm).
    segments_text: list[str] = []

    # Bước 1: regex split theo dấu câu / xuống dòng
    regex_segments = re.split(r'[.!?\n]+', transcript)
    regex_segments = [s.strip() for s in regex_segments if s.strip()]

    if len(regex_segments) >= 2:
        # Có dấu câu → dùng regex (chính xác hơn vì ranh giới rõ ràng)
        segments_text = regex_segments
    elif children:
        # Regex chỉ ra 1 segment (không dấu câu) → dùng smart split
        smart_segments = _smart_split_transcript(
            transcript, children, min_confidence=min_confidence
        )
        if len(smart_segments) >= 2:
            segments_text = smart_segments
        else:
            # Smart split cũng không tách được (không có anchor) → giữ 1 segment
            cleaned = transcript.strip()
            segments_text = [cleaned] if cleaned else []
    else:
        # Không có children để smart split → dùng regex (dù 1 segment)
        segments_text = regex_segments
        if not segments_text:
            cleaned = transcript.strip()
            segments_text = [cleaned] if cleaned else []

    if not segments_text:
        return {
            "segments": [],
            "class_wide_extraction": {
                "meals": None,
                "sleeping": None,
                "health": None,
                "activities": None,
                "mood": None,
            },
            "child_extractions": {},
            "ambiguous_segments": 0,
            "unmatched_segments": 0,
            "class_wide_segments": 0,
        }

    # Load model once
    _load_model()

    # ============ 3 BUCKETS RIÊNG BIỆT ============

    # Bucket 1: Class-wide content (append khi gặp segment class-wide)
    class_wide_lists: dict[str, list[str]] = {
        key: [] for key in CLASS_WIDE_FIELDS
    }

    # Bucket 2: Child-specific overrides (REPLACE khi gặp segment match child)
    # Chỉ chứa children CÓ override, không tạo sẵn cho all 25
    child_overrides_lists: dict[str, dict[str, list[str]]] = {}

    result_segments = []
    ambiguous_count = 0
    unmatched_count = 0
    class_wide_count = 0

    # Track context từ segment trước để inherit cho orphan segments.
    # Smart split giảm orphan gần hết, nhưng vẫn còn edge case (transcript
    # không có anchor → 1 segment duy nhất không match ai). Option D là
    # safety net: orphan → inherit subject của segment trước.
    prev_subject_type: str | None = None  # "child" | "class_wide" | None
    prev_child_id: str | None = None

    for segment_text in segments_text:
        # 1. Match children names in this segment
        matches = match_single_text(
            segment_text,
            children,
            min_confidence=min_confidence
        )

        # 1b. Bỏ tên bé đã match khỏi text trước khi trích xuất.
        #     Tên hay trùng từ thông dụng nên model dễ gán nhầm thành entity
        #     (vd "bình" -> B-MEALS, "an" -> B-MEALS).
        extraction_text = _strip_matched_names(segment_text, matches)

        # 1c. Bỏ luôn class-wide keyword ("cả lớp", "các bé", ...) nếu có.
        #     Model bị "lười" khi thấy "cả lớp" ở đầu: chỉ gán B-MOOD cho
        #     từ đầu rồi O hết phần sau. Strip anchor class-wide trước khi
        #     đưa vào model để các field phía sau (activities/sleeping/...)
        #     được nhận diện đầy đủ.
        extraction_text = _strip_class_wide_keywords(extraction_text)

        # 2. Run NLP extraction on this segment (dùng text đã bỏ tên + class-wide)
        extraction = _extract_single_segment(extraction_text)

        # 2b. Skip segment nếu model không extract được gì (orphan segment rỗng).
        #     Orphan như "bé" bị smart-split tách riêng không có nội dung gì,
        #     gọi model cũng ra toàn None → drop luôn để tránh báo cáo ảo.
        if all(v is None for v in extraction.values()):
            unmatched_count += 1
            continue

        # 3. Check if this is a class-wide segment
        is_class_wide = _is_class_wide_segment(segment_text, matches)

        # 4. Check if ambiguous (dùng math.isclose để tránh floating point equality)
        is_ambiguous = (
            len(matches) > 1
            and math.isclose(matches[0].confidence, matches[1].confidence, abs_tol=1e-3)
        )

        # Build segment result (giữ nguyên format để frontend dùng)
        segment_result = {
            "text": segment_text,
            "extraction_text": extraction_text,
            "is_class_wide": is_class_wide,
            "child_matches": [
                {
                    "child_id": m.child_id,
                    "full_name": m.full_name,
                    "nickname": m.nickname,
                    "matched_words": m.matched_words,
                    "confidence": round(m.confidence, 2),
                }
                for m in matches
            ],
            "extraction": extraction,
            "is_ambiguous": is_ambiguous,
        }

        if is_ambiguous:
            ambiguous_count += 1

        # ============ 5. Phân loại vào 3 buckets ============

        if is_class_wide:
            # Class-wide: append vào bucket 1
            class_wide_count += 1
            for key in CLASS_WIDE_FIELDS:
                value = extraction.get(key)
                if value:
                    class_wide_lists[key].append(value)
            # Nếu model không extract được gì → trả None (không guess).
            # Guess gây ra báo cáo có dữ liệu ảo, parent thấy sai còn tệ hơn
            # báo cáo trống.
            # Cập nhật context cho segment kế tiếp
            prev_subject_type = "class_wide"
            prev_child_id = None

        elif matches:
            # Child-specific: REPLACE vào bucket 2 cho từng matched child
            for m in matches:
                child_id = m.child_id
                # Chỉ thêm child vào bucket 2 khi LẦN ĐẦU gặp
                if child_id not in child_overrides_lists:
                    child_overrides_lists[child_id] = {
                        "meals": [],
                        "sleeping": [],
                        "health": [],
                        "activities": [],
                        "mood": [],
                    }
                # REPLACE (không append) cho mỗi field có giá trị
                for key in child_overrides_lists[child_id]:
                    value = extraction.get(key)
                    if value:
                        # Replace list với 1 phần tử (override cuối cùng thắng)
                        child_overrides_lists[child_id][key] = [value]
            # Cập nhật context cho segment kế tiếp (lấy match đầu tiên,
            # thường là match có confidence cao nhất)
            prev_subject_type = "child"
            prev_child_id = matches[0].child_id
        else:
            # Orphan: không match được child nào và không class-wide.
            # Safety net: inherit context từ segment trước để không mất info.
            # Ví dụ: "Bé Lan ăn ngon" (match Lan) → "Ho nhẹ" (orphan, inherit Lan).
            inherited = False
            if prev_subject_type == "child" and prev_child_id is not None:
                # Gán extraction cho child trước đó
                if prev_child_id not in child_overrides_lists:
                    child_overrides_lists[prev_child_id] = {
                        "meals": [],
                        "sleeping": [],
                        "health": [],
                        "activities": [],
                        "mood": [],
                    }
                for key in child_overrides_lists[prev_child_id]:
                    value = extraction.get(key)
                    if value:
                        # Append (orphan có thể có nhiều thông tin cho cùng 1 child)
                        child_overrides_lists[prev_child_id][key].append(value)
                inherited = True
            elif prev_subject_type == "class_wide":
                # Append vào class-wide bucket
                for key in CLASS_WIDE_FIELDS:
                    value = extraction.get(key)
                    if value:
                        class_wide_lists[key].append(value)
                inherited = True

            if inherited:
                segment_result["inherited_from"] = {
                    "type": prev_subject_type,
                    "child_id": prev_child_id,
                }
            else:
                # Thực sự không có context (segment đầu tiên hoặc transcript
                # không có anchor nào) → chỉ đếm
                unmatched_count += 1

        result_segments.append(segment_result)

    # ============ Convert lists → comma-joined strings ============

    # Bucket 1: class_wide_extraction
    class_wide_extraction = {
        key: ", ".join(values) if values else None
        for key, values in class_wide_lists.items()
    }
    if all(v is None for v in class_wide_extraction.values()):
        class_wide_extraction = None
    # Bucket 2: child_extractions (CHỈ children có override)
    child_extractions: dict[str, dict[str, str | None]] = {}
    for child_id, data in child_overrides_lists.items():
        child_extractions[child_id] = {
            key: ", ".join(values) if values else None
            for key, values in data.items()
        }

    return {
        "segments": result_segments,
        "class_wide_extraction": class_wide_extraction,
        "child_extractions": child_extractions,
        "ambiguous_segments": ambiguous_count,
        "unmatched_segments": unmatched_count,
        "class_wide_segments": class_wide_count,
    }


def _extract_single_segment(segment_text: str) -> dict:
    """
    Trích xuất thông tin từ 1 segment ngắn (dùng model đã load).

    Returns dict với toàn None nếu segment trống hoặc không có tokens hợp lệ.
    """
    if not segment_text or not segment_text.strip():
        return {
            "meals": None,
            "sleeping": None,
            "health": None,
            "activities": None,
            "mood": None,
        }

    tokens = _tokenizer(segment_text)

    # Guard: nếu tokenize ra rỗng (segment chỉ có dấu câu), trả None
    if not tokens:
        return {
            "meals": None,
            "sleeping": None,
            "health": None,
            "activities": None,
            "mood": None,
        }

    input_ids = _numericalize(segment_text)

    with torch.no_grad():
        tensor = torch.tensor([input_ids]).to(_device)
        output = _model(tensor)
        predictions = output.argmax(dim=-1)[0]

    pred_labels = [_id_to_label[pred.item()] for pred in predictions[:len(tokens)]]
    phrases_by_label = _extract_bio_phrases(tokens, pred_labels)

    result = {}
    for key, phrases in phrases_by_label.items():
        result[key] = ", ".join(phrases) if phrases else None

    return result