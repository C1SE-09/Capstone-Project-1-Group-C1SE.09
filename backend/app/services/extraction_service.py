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

import json


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

    json_text = json.dumps({
        "meals": None,
        "sleeping": None,
        "health": None,
        "activities": None,
        "mood": None
    })

    return json.loads(json_text)