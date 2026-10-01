# Stub torch before import (test chỉ test matching, ko cần model)
import sys
import types

fake_torch = types.ModuleType("torch")
fake_torch.device = lambda x: x
fake_torch.no_grad = lambda: None
fake_nn = types.ModuleType("torch.nn")
class FakeModule:
    def __init__(self, *a, **k): pass
    def __call__(self, *a, **k): return self
    def to(self, *a, **k): return self
    def eval(self): return self
    def load_state_dict(self, *a, **k): pass
fake_nn.Module = FakeModule
fake_nn.Embedding = FakeModule
fake_nn.LSTM = FakeModule
fake_nn.Linear = FakeModule
fake_torch.nn = fake_nn
fake_torch.tensor = lambda x, **k: x
fake_torch.load = lambda *a, **k: {"vocab": {"<unk>": 0}, "label_to_id": {}, "embedding_dim": 1, "hidden_dim": 1}
sys.modules["torch"] = fake_torch
sys.modules["torch.nn"] = fake_nn

from unittest.mock import MagicMock

from app.services.extraction_service import _is_class_wide_segment
from app.services.name_matching_service import match_single_text

children = [
    MagicMock(child_id='1', full_name='Bảo', nickname=None),
    MagicMock(child_id='2', full_name='Ánh', nickname=None),
]

transcripts = [
    'cả lớp ăn ngon bảo ho nhẹ',
    'bảo ăn ngon',
    'cả lớp ăn ngon ánh ngủ trưa ngon',
]

for t in transcripts:
    print(f'=== TRANSCRIPT: {t!r} ===')

    import re
    segments = re.split(r'[.!?\n]+', t)
    segments = [s.strip() for s in segments if s.strip()]
    print(f'Segments after split: {segments}')

    for seg in segments:
        matches = match_single_text(seg, children, min_confidence=0.3)
        is_class_wide = _is_class_wide_segment(seg, matches)
        bucket = 'CLASS-WIDE' if is_class_wide else ('CHILD-SPECIFIC' if matches else 'UNMATCHED')
        names = [(m.full_name, round(m.confidence, 2)) for m in matches]
        print(f'  Segment: {seg!r}')
        print(f'    matches: {names}')
        print(f'    is_class_wide: {is_class_wide}  ->  bucket: {bucket}')
    print()
