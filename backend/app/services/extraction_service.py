"""
extraction_service.py

AI Service cho trích xuất dữ liệu từ transcript.

INPUT MẪU:
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
