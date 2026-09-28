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

import os
import re

import torch
from torch import nn

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
        output = self.fc(output)         # Output shape: (batch, seq_len, num_classes)
        return output


# Load model khi import
MODEL_PATH = os.path.join(os.path.dirname(__file__), "bio_lstm_model.pt")

_label_to_id = None
_id_to_label = None
_vocab = None
_model = None
_device = None


def _load_model():
    global _model, _vocab, _label_to_id, _id_to_label, _device
    if _model is not None:
        return

    _device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    checkpoint = torch.load(MODEL_PATH, map_location=_device)
    _vocab = checkpoint['vocab']
    _label_to_id = checkpoint['label_to_id']
    _id_to_label = {v: k for k, v in _label_to_id.items()}

    _model = LSTMClassifier(
        vocab_size=len(_vocab),
        embedding_dim=checkpoint['embedding_dim'],
        hidden_dim=checkpoint['hidden_dim'],
        num_classes=len(_label_to_id)
    )
    _model.load_state_dict(checkpoint['model_state_dict'])
    _model.to(_device)
    _model.eval()


def _tokenizer(text: str):
    text = text.lower()
    text = re.sub(r'[.!?,;:]', '', text)
    return text.split()


def _numericalize(text: str):
    tokens = _tokenizer(text)
    return [_vocab.get(token, _vocab['<unk>']) for token in tokens]

def _extract_bio_phrases(tokens, pred_labels):
    """Parse BIO tags thành list phrases theo từng label.."""
    result = {
        "meals": [],
        "sleeping": [],
        "health": [],
        "activities": [],
        "mood": []
    }
    
    current_phrase = []
    current_label = None
    
    for token, pred_label in zip(tokens, pred_labels):
        if pred_label == "O":
            if current_label and current_phrase:
                label_name = current_label.replace("B-", "").replace("I-", "").lower()
                if label_name in result:
                    result[label_name].append(" ".join(current_phrase))
                current_phrase = []
                current_label = None
        elif pred_label.startswith("B-"):
            if current_label and current_phrase:
                label_name = current_label.replace("B-", "").replace("I-", "").lower()
                if label_name in result:
                    result[label_name].append(" ".join(current_phrase))
            current_phrase = [token]
            current_label = pred_label
        elif pred_label.startswith("I-") and current_label:
            current_phrase.append(token)
    
    # Xử lý phrase cuối
    if current_label and current_phrase:
        label_name = current_label.replace("B-", "").replace("I-", "").lower()
        if label_name in result:
            result[label_name].append(" ".join(current_phrase))
    
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

    pred_labels = [_id_to_label[pred.item()] for pred in predictions[:len(tokens)]]
    
    # Parse BIO tags
    phrases_by_label = _extract_bio_phrases(tokens, pred_labels)
    
    # Chuyển list → string (nối bằng ", ")
    result = {}
    for key, phrases in phrases_by_label.items():
        result[key] = ", ".join(phrases) if phrases else None

    return result


# =============== MULTI-PERSON EXTRACTION ===============

# Keywords indicate class-wide statements
CLASS_WIDE_KEYWORDS = [
    "cả lớp", "các bé", "mọi người", "tất cả", "ai cũng",
    "hôm nay", "sáng nay", "chiều nay"
]


def _is_class_wide_segment(segment_text: str, matches: list) -> bool:
    """
    Kiểm tra xem segment có phải là statement cho cả lớp không.
    
    Returns True nếu:
    1. Chứa keywords như "cả lớp", "các bé"...
    2. KHÔNG match được child nào (no child matches)
    """
    segment_lower = segment_text.lower()
    
    # Check for class-wide keywords
    for keyword in CLASS_WIDE_KEYWORDS:
        if keyword in segment_lower:
            return True
    
    return not matches


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
    4. Gán cho tất cả children (default) hoặc child cụ thể (override)
    
    Logic:
    - Segment "cả lớp..." → gán cho TẤT CẢ children (default)
    - Segment match được child cụ thể → ghi đè (override) extraction của child đó
    
    Args:
        transcript: Full transcript text từ STT
        children: List[Child] - Danh sách tất cả bé trong lớp
        min_confidence: Ngưỡng confidence tối thiểu để match tên (default 30%)
    
    Returns:
        {
            "segments": [...],
            "child_extractions": {
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
    """
    import re

    from app.services.name_matching_service import match_single_text
    
    if not transcript or not transcript.strip():
        return {
            "segments": [],
            "child_extractions": {},
            "ambiguous_segments": 0,
            "unmatched_segments": 0,
            "class_wide_segments": 0,
        }
    
    # Split transcript into sentences
    segments_text = re.split(r'[.!?\n]+', transcript)
    segments_text = [s.strip() for s in segments_text if s.strip()]
    
    if not segments_text:
        return {
            "segments": [],
            "child_extractions": {},
            "ambiguous_segments": 0,
            "unmatched_segments": 0,
            "class_wide_segments": 0,
        }
    
    # Load model once
    _load_model()
    
    # Initialize all children with empty extractions (for tracking)
    all_child_ids = [str(c.child_id) for c in children]
    child_extractions = {}  # child_id -> {meals: [], sleeping: [], ...}
    for child_id in all_child_ids:
        child_extractions[child_id] = {
            "meals": [],
            "sleeping": [],
            "health": [],
            "activities": [],
            "mood": [],
        }
    
    # Track which fields were overridden by child-specific segments
    # child_id -> set of keys that were overridden
    overridden_fields = {}  # child_id -> {("meals",), ("sleeping",), ...}
    for child_id in all_child_ids:
        overridden_fields[child_id] = set()
    
    result_segments = []
    ambiguous_count = 0
    unmatched_count = 0
    class_wide_count = 0
    
    for segment_text in segments_text:
        # 1. Match children names in this segment
        matches = match_single_text(
            segment_text, 
            children, 
            min_confidence=min_confidence
        )
        
        # 2. Run NLP extraction on this segment
        extraction = _extract_single_segment(segment_text)
        
        # 3. Check if this is a class-wide segment
        is_class_wide = _is_class_wide_segment(segment_text, matches)
        
        # 4. Check if ambiguous
        is_ambiguous = (
            len(matches) > 1 and 
            matches[0].confidence == matches[1].confidence
        )
        
        # Build segment result
        segment_result = {
            "text": segment_text,
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
        
        if is_class_wide:
            class_wide_count += 1
            # Apply to ALL children (default)
            target_child_ids = all_child_ids
        elif matches:
            # Apply ONLY to matched children (override)
            target_child_ids = [m.child_id for m in matches]
        else:
            unmatched_count += 1
            target_child_ids = []
        
        # 5. Aggregate extractions for target children
        for child_id in target_child_ids:
            for key in child_extractions[child_id]:
                value = extraction.get(key)
                if value:
                    # Child-specific segment: override (clear old values first)
                    if not is_class_wide and matches:
                        child_extractions[child_id][key] = [value]
                        overridden_fields[child_id].add(key)
                    else:
                        # Class-wide: add to list (only if not already overridden)
                        if key not in overridden_fields.get(child_id, set()):
                            child_extractions[child_id][key].append(value)
        
        result_segments.append(segment_result)
    
    # Convert lists to comma-joined strings
    final_child_extractions = {}
    for child_id, data in child_extractions.items():
        final_child_extractions[child_id] = {
            key: ", ".join(values) if values else None
            for key, values in data.items()
        }
    
    return {
        "segments": result_segments,
        "child_extractions": final_child_extractions,
        "ambiguous_segments": ambiguous_count,
        "unmatched_segments": unmatched_count,
        "class_wide_segments": class_wide_count,
    }


def _extract_single_segment(segment_text: str) -> dict:
    """
    Trích xuất thông tin từ 1 segment ngắn (dùng model đã load).
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
