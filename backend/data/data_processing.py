import json
import re
from collections import Counter
data = []
# Đọc Processed.json
with open("Processed.json", "r", encoding="utf-8") as f:
    samples = json.load(f)

print("Number of samples:", len(samples))

# Đếm số lượng từng label
label_counts = Counter(sample["label"] for sample in samples)

print("\nLabel distribution:")

for label, count in label_counts.items():
    print(f"{label}: {count}")

print(label_counts)
for sample in samples:
    if sample["label"] == "mood":
        print(sample["text"])

for item in data:
    print("processing item")
    transcript = item["transcript"]
    output = item["output"]

    sentences = re.split(r"[.!?]", transcript)

    for sentence in sentences:
        sentence = sentence.strip()

        if not sentence:
            continue

        for label, keywords in output.items():

            if keywords is None:
                continue

            keywords_list = [x.strip() for x in keywords.split(",")]

            if any(keyword in sentence for keyword in keywords_list):
                samples.append({
                    "text": sentence,
                    "label": label
                })
                break

print("Number of samples:", len(samples))

with open("Processed.json", "w", encoding="utf-8") as f:
    json.dump(samples, f, ensure_ascii=False, indent=2)

print("Saved Processed.json")