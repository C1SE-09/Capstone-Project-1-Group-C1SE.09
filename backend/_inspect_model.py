"""Inspect model v2 checkpoint."""
import torch

m = torch.load("app/services/bio_lstm_model_version_2.pt", map_location="cpu")
print("Type:", type(m))
if isinstance(m, dict):
    print("Keys:", list(m.keys()))
    for k, v in m.items():
        if isinstance(v, torch.Tensor):
            print(f"  {k}: shape={v.shape}, dtype={v.dtype}")
        elif isinstance(v, dict):
            print(f"  {k}: dict with keys {list(v.keys())}")
        else:
            print(f"  {k}: {type(v)} = {v}")
elif isinstance(m, torch.nn.Module):
    print("Direct nn.Module")
    print(m)
