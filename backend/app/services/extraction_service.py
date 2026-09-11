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
        embedd = self.embedding(x)
        out_put, (hidden, _) = self.lstm(embedd)
        hidden = hidden[-1]
        out_put = self.fc(hidden)
        return out_put


# Load model khi import
MODEL_PATH = os.path.join(os.path.dirname(__file__), "text_classifier_model.pt")

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


# =============== EXTRACTION FUNCTION ===============

def extract_from_transcript(transcript: str) -> dict:
    """
    Gọi model NLP trích xuất thông tin từ transcript.

    Args:
        transcript: Text từ STT

    Returns:
        dict: {
            "meals": str | None,
            "sleeping": str | None,
            "health": str | None,
            "activities": str | None,
            "mood": str | None
        }
    """
    _load_model()

    # Tách câu (mỗi dấu chấm/ngắt dòng = 1 câu)
    sentences = re.split(r'[.\n]+', transcript)
    sentences = [s.strip() for s in sentences if s.strip()]

    # Khởi tạo kết quả
    result = {
        "meals": None,
        "sleeping": None,
        "health": None,
        "activities": None,
        "mood": None
    }

    for sentence in sentences:
        with torch.no_grad():
            nums = _numericalize(sentence)
            tensor = torch.tensor([nums]).to(_device)
            output = _model(tensor)
            pred_id = output.argmax(dim=1).item()
            label = _id_to_label[pred_id]

            # Gán kết quả (ghi đè nếu có nhiều câu cùng loại)
            if result[label] is None:
                result[label] = sentence

    return result
