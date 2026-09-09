import json
import re

data = []
with open("raw_train.jsonl", "r", encoding="utf-8") as f:
    for line in f:
        data.append(json.loads(line))
print("Number of data: ", len(data))
samples = []
for item in data:
    transcript = item["transcript"]
    output = item["output"]
    sentences = re.split(r"[.!?]", transcript)
    for sentence in sentences:
        if not sentence:
            continue
        for label, keywords in output.items():
            if keywords is None:
                continue
            keywords_list = [x.strip() for x in keywords.split(",")]
            if any(keyword in sentence for keyword in keywords_list):
                samples.append({"text": sentence, "label": label})
                break
print("Number off sample", len(samples))

with open("train.json", "w", encoding="utf-8") as f:
    json.dump(samples, f, ensure_ascii=False, indent=2)
print("Saved")
