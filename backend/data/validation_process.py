import json
import re

# =========================
# 1. Read validation.jsonl
# =========================

data = []

with open("validation.jsonl", "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()

        # Skip empty lines
        if not line:
            continue

        data.append(json.loads(line))

print("Number of data:", len(data))


# =========================
# 2. Preprocessing
# =========================

samples = []

for item in data:

    print("processing item")

    transcript = item["transcript"]
    output = item["output"]

    # Split transcript into sentences
    sentences = re.split(r"[.!?]", transcript)

    for sentence in sentences:

        sentence = sentence.strip()

        if not sentence:
            continue

        # Check which label the sentence belongs to
        for label, keywords in output.items():

            if keywords is None:
                continue

            keywords_list = [
                x.strip()
                for x in keywords.split(",")
            ]

            if any(keyword in sentence for keyword in keywords_list):

                samples.append({
                    "text": sentence,
                    "label": label
                })

                break


# =========================
# 3. Check result
# =========================

print("Number of samples:", len(samples))


# =========================
# 4. Save processed data
# =========================

with open("validation.json", "w", encoding="utf-8") as f:

    json.dump(
        samples,
        f,
        ensure_ascii=False,
        indent=2
    )

print("Saved validation.json")