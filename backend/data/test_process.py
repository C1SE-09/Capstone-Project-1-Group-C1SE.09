import json
import re

data = []
with open("raw_test.jsonl", "r", encoding = 'utf-8') as f:
    for line in f:
        data.append(json.loads(line))
print(len(data))
samples = []
for item in data:
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