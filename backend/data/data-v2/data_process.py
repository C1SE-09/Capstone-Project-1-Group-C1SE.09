import json
import re
from collections import Counter
from pathlib import Path

folder = Path(__file__)

def load_json(file_name):
    with open(folder/file_name, "r", encoding="utf-8") as f:
        data = json.load(f)

    labels = []
    
    for item in data:
        label = item.get("label")
        labels.append(label)
    print(f"\n{file_name}:")
    print(len(data))
    print(Counter(labels))
    return data
train = load_json("train-v1.json")
validate = load_json("validation-v1.json")
test = load_json("test-v1.json")

def get_text(item):
    return item.get("text", "").strip()
def check_normalized_duplicate(data, name):
    texts = [normalize_text(get_text(item)) for item in data]
    counter = Counter(texts)
    duplicates = {
        text: count
        for text, count in counter.items()
        if count > 1
    }

    print(f"\n{name} - NORMALIZED DUPLICATE")
    print(f"Unique texts: {len(counter)}")
    print(f"Duplicate texts: {len(duplicates)}")
    print(f"Duplicate samples: {sum(count - 1 for count in duplicates.values())}")

    if duplicates:
        print("\nExamples:")
        for text, count in list(duplicates.items())[:10]:
            print(f"[{count}x] {text}")

def check_cross_duplicates(data1, data2, name1, name2):
    texts_1 = set(get_text(item) for item in data1)
    texts_2 = set(get_text(item) for item in data2)

    duplicate = texts_1 & texts_2

    print(f"\n{name1} <-> {name2}")
    print(f"Data leakage: {len(duplicate)}")

    if duplicate:
        print("Examples")
        for text in list(duplicate):
            print(f"{text}")
def check_structure(data, name):
    invalid_structure = 0
    missing_text = 0
    empty_text = 0
    missing_label = 0

    for i, item in enumerate(data):
        if not isinstance(item, dict):
            invalid_structure += 1
            continue

        if "text" not in item or item["text"] is None or not isinstance(item["text"], str):
            missing_text += 1
        elif not item["text"].strip():
            empty_text += 1
        if "label" not in item or item["label"] is None:
            missing_label += 1

    print(f"\n{name} - STRUCTURE")
    print(f"Invalid structure: {invalid_structure}")
    print(f"Missing/invalid text: {missing_text}")
    print(f"Empty text: {empty_text}")
    print(f"Missing label: {missing_label}")
VALID_LABELS = {
    "activities",
    "health",
    "meals",
    "mood",
    "sleeping"
}
def check_labels(data, name):
    invalid_labels = []

    for i, item in enumerate(data):
        label = item.get("label")

        if label not in VALID_LABELS:
            invalid_labels.append((i, label))

    print(f"\n{name} - LABEL")
    print(f"Invalid labels: {len(invalid_labels)}")

    if invalid_labels:
        for index, label in invalid_labels[:10]:
            print(f"Index {index}: {label}")
def normalize_text(text):
    text = text.lower()
    text = re.sub(r"\s+", " ", text)
    return text.strip()

check_normalized_duplicate(train, "TRAIN")
check_normalized_duplicate(validate, "VALIDATION")
check_normalized_duplicate(test, "TEST")

check_cross_duplicates(train, validate, "TRAIN", "VALIDATION")
check_cross_duplicates(train, test, "TRAIN", "TEST")
check_cross_duplicates(validate, test, "VALIDATION", "TEST")

check_structure(train, "TRAIN")
check_structure(validate, "VALIDATION")
check_structure(test, "TEST")

check_labels(train, "TRAIN")
check_labels(validate, "VALIDATION")
check_labels(test, "TEST")