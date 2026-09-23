import sys

sys.path.insert(0, ".") 

from extraction_service import extract_from_transcript

transcript = "Bé Lan ăn ngon lắm hết suất cơm. Bé ngủ trưa ngon lành 2 tiếng. Chiều bé ho nhẹ. Bé vẽ tranh đẹp lắm. Bé rất vui vẻ."

result = extract_from_transcript(transcript)
print(result)