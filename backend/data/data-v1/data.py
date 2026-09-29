import json
import re
from collections import Counter
from pathlib import Path

folder = Path(__file__).parent

VALID_FIELDS = {"meals", "sleeping", "health", "activities", "mood"}


def load_jsonl(file_name):
    data = []

    with open(folder / file_name, "r", encoding="utf-8") as f:
        for line_number, line in enumerate(f, start=1):
            line = line.strip()

            if not line:
                continue

            try:
                data.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"Invalid JSON at line {line_number}: {e}")

    print(f"\n{file_name}:")
    print(f"Samples: {len(data)}")

    return data


train = load_jsonl("train-v1.jsonl")
validate = load_jsonl("validation-v1.jsonl")
test = load_jsonl("test-v1.jsonl")


def get_text(item):
    return item.get("transcript", "").strip()


def normalize_text(text):
    text = text.lower()
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def check_normalized_duplicate(data, name):
    texts = [normalize_text(get_text(item)) for item in data]

    counter = Counter(texts)

    duplicates = {text: count for text, count in counter.items() if count > 1}

    print(f"\n{name} - NORMALIZED DUPLICATE")
    print(f"Unique transcripts: {len(counter)}")
    print(f"Duplicate transcripts: {len(duplicates)}")
    print(f"Duplicate samples: {sum(count - 1 for count in duplicates.values())}")

    if duplicates:
        print("\nExamples:")

        for text, count in list(duplicates.items())[:10]:
            print(f"[{count}x] {text}")


def check_cross_duplicates(data1, data2, name1, name2):
    map_1 = {normalize_text(get_text(item)): item for item in data1 if get_text(item)}

    map_2 = {normalize_text(get_text(item)): item for item in data2 if get_text(item)}

    duplicate = set(map_1) & set(map_2)

    print(f"\n{name1} <-> {name2}")
    print(f"Data leakage: {len(duplicate)}")

    if duplicate:
        print("\nExamples:")

        for text in list(duplicate)[:10]:
            print("\nTEXT:")
            print(text)

            print(f"\n{name1} OUTPUT:")
            print(map_1[text]["output"])

            print(f"\n{name2} OUTPUT:")
            print(map_2[text]["output"])


def check_structure(data, name):
    invalid_structure = 0
    missing_transcript = 0
    empty_transcript = 0
    invalid_output = 0

    for i, item in enumerate(data):
        if not isinstance(item, dict):
            invalid_structure += 1
            continue

        # Check transcript
        if "transcript" not in item or not isinstance(item["transcript"], str):
            missing_transcript += 1

        elif not item["transcript"].strip():
            empty_transcript += 1

        # Check output
        if "output" not in item or not isinstance(item["output"], dict):
            invalid_output += 1

    print(f"\n{name} - STRUCTURE")
    print(f"Invalid structure: {invalid_structure}")
    print(f"Missing/invalid transcript: {missing_transcript}")
    print(f"Empty transcript: {empty_transcript}")
    print(f"Missing/invalid output: {invalid_output}")


def check_output_fields(data, name):
    missing_fields = []
    invalid_fields = []

    for i, item in enumerate(data):
        if not isinstance(item, dict):
            continue

        output = item.get("output")

        if not isinstance(output, dict):
            continue

        # Missing fields
        for field in VALID_FIELDS:
            if field not in output:
                missing_fields.append((i, field))

        # Unexpected fields
        for field in output:
            if field not in VALID_FIELDS:
                invalid_fields.append((i, field))

    print(f"\n{name} - OUTPUT FIELDS")

    print(f"Missing fields: {len(missing_fields)}")

    if missing_fields:
        print("\nExamples:")

        for index, field in missing_fields[:10]:
            print(f"Index {index}: missing {field}")

    print(f"Unexpected fields: {len(invalid_fields)}")

    if invalid_fields:
        print("\nExamples:")

        for index, field in invalid_fields[:10]:
            print(f"Index {index}: unexpected {field}")


def check_output_values(data, name):
    invalid_values = []

    for i, item in enumerate(data):
        if not isinstance(item, dict):
            continue

        output = item.get("output")

        if not isinstance(output, dict):
            continue

        for field in VALID_FIELDS:
            value = output.get(field)

            # null is allowed
            if value is None:
                continue

            # String is allowed
            if isinstance(value, str):
                if not value.strip():
                    invalid_values.append((i, field, "empty string"))

                continue

            # Anything else is invalid
            invalid_values.append((i, field, type(value).__name__))

    print(f"\n{name} - OUTPUT VALUES")
    print(f"Invalid values: {len(invalid_values)}")

    if invalid_values:
        print("\nExamples:")

        for index, field, value_type in invalid_values[:10]:
            print(f"Index {index}: {field} -> {value_type}")


def check_empty_outputs(data, name):
    empty_outputs = 0

    for item in data:
        output = item.get("output", {})

        if not isinstance(output, dict):
            continue

        if all(output.get(field) is None for field in VALID_FIELDS):
            empty_outputs += 1

    print(f"\n{name} - EMPTY OUTPUT")
    print(f"All fields null: {empty_outputs}")


# =========================
# RUN CHECKS
# =========================

check_normalized_duplicate(train, "TRAIN")
check_normalized_duplicate(validate, "VALIDATION")
check_normalized_duplicate(test, "TEST")

check_cross_duplicates(train, validate, "TRAIN", "VALIDATION")

check_cross_duplicates(train, test, "TRAIN", "TEST")

check_cross_duplicates(validate, test, "VALIDATION", "TEST")

check_structure(train, "TRAIN")
check_structure(validate, "VALIDATION")
check_structure(test, "TEST")

check_output_fields(train, "TRAIN")
check_output_fields(validate, "VALIDATION")
check_output_fields(test, "TEST")

check_output_values(train, "TRAIN")
check_output_values(validate, "VALIDATION")
check_output_values(test, "TEST")

check_empty_outputs(train, "TRAIN")
check_empty_outputs(validate, "VALIDATION")
check_empty_outputs(test, "TEST")
