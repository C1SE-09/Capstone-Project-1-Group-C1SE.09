
import json
import random
from collections import Counter
from pathlib import Path


BASE_DIR = Path(__file__).parent

TRAIN_FILE = BASE_DIR / "train.json"
VALIDATION_FILE = BASE_DIR / "validation.json"
TEST_FILE = BASE_DIR / "test.json"


OUTPUT_TRAIN = BASE_DIR / "new_train.json"
OUTPUT_VALIDATION = BASE_DIR / "new_validation.json"
OUTPUT_TEST = BASE_DIR / "new_test.json"


TRAIN_RATIO = 0.7
VALIDATION_RATIO = 0.15
TEST_RATIO = 0.15

RANDOM_SEED = 42


def load_json(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(data, file_path):
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def normalize_text(text):
    return " ".join(text.lower().strip().split())


def remove_duplicates(data):
    unique_data = []
    seen = set()

    for item in data:
        text = normalize_text(item["text"])
        label = item["label"]

        key = (text, label)

        if key not in seen:
            seen.add(key)
            unique_data.append(item)

    return unique_data


def check_label_conflicts(data):
    text_labels = {}

    for item in data:
        text = normalize_text(item["text"])
        label = item["label"]

        if text not in text_labels:
            text_labels[text] = set()

        text_labels[text].add(label)

    conflicts = {
        text: labels
        for text, labels in text_labels.items()
        if len(labels) > 1
    }

    return conflicts


def stratified_split(data):
    random.seed(RANDOM_SEED)

    grouped_data = {}

    for item in data:
        label = item["label"]

        if label not in grouped_data:
            grouped_data[label] = []

        grouped_data[label].append(item)

    train = []
    validation = []
    test = []

    for label, items in grouped_data.items():
        random.shuffle(items)

        total = len(items)

        train_count = int(total * TRAIN_RATIO)
        validation_count = int(total * VALIDATION_RATIO)

        train_items = items[:train_count]
        validation_items = items[
            train_count:train_count + validation_count
        ]
        test_items = items[
            train_count + validation_count:
        ]

        train.extend(train_items)
        validation.extend(validation_items)
        test.extend(test_items)

    random.shuffle(train)
    random.shuffle(validation)
    random.shuffle(test)

    return train, validation, test


def print_distribution(name, data):
    counter = Counter(item["label"] for item in data)

    print(f"\n{name}")
    print(f"Total: {len(data)}")

    for label, count in counter.items():
        percentage = count / len(data) * 100
        print(f"{label}: {count} ({percentage:.2f}%)")


train_old = load_json(TRAIN_FILE)
validation_old = load_json(VALIDATION_FILE)
test_old = load_json(TEST_FILE)

print("Original dataset")
print_distribution("Train", train_old)
print_distribution("Validation", validation_old)
print_distribution("Test", test_old)


all_data = train_old + validation_old + test_old

print(f"\nTotal before removing duplicates: {len(all_data)}")


conflicts = check_label_conflicts(all_data)

print(f"Label conflicts: {len(conflicts)}")

if conflicts:
    print("\nExamples of conflicting labels:")

    for text, labels in list(conflicts.items())[:10]:
        print(f"Text: {text}")
        print(f"Labels: {labels}")


all_data = remove_duplicates(all_data)

print(f"\nTotal after removing duplicates: {len(all_data)}")


train, validation, test = stratified_split(all_data)


save_json(train, OUTPUT_TRAIN)
save_json(validation, OUTPUT_VALIDATION)
save_json(test, OUTPUT_TEST)


print("\nNew dataset")

print_distribution("Train", train)
print_distribution("Validation", validation)
print_distribution("Test", test)


train_texts = set(normalize_text(item["text"]) for item in train)
validation_texts = set(normalize_text(item["text"]) for item in validation)
test_texts = set(normalize_text(item["text"]) for item in test)

print("\nData leakage check")

print(
    "Train ∩ Validation:",
    len(train_texts & validation_texts)
)

print(
    "Train ∩ Test:",
    len(train_texts & test_texts)
)

print(
    "Validation ∩ Test:",
    len(validation_texts & test_texts)
)
