"""
test_name_matching.py

Test script để verify name_matching + extract_multi_person
với các transcript mẫu.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

# Force UTF-8 output on Windows
if sys.platform == "win32":
    import io

    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

import re
from dataclasses import dataclass


# Mock Child object cho test
@dataclass
class MockChild:
    child_id: str
    full_name: str
    nickname: str | None = None
    class_id: str | None = None


# Sample children
CHILDREN = [
    MockChild("child-001", "Nguyễn Văn Lan", "Lan"),
    MockChild("child-002", "Trần Minh Hoàng", "Hoàng"),
    MockChild("child-003", "Lê Thị Mai", "Mai"),
    MockChild("child-004", "Phạm Đức Anh", "Anh"),
    MockChild("child-005", "Đỗ Thu Hà", "Hà"),
]

# ============================================================
# TEST DATA
# ============================================================

TEST_TRANSCRIPTS = [
    # Test 1: Full name match
    "Nguyễn Văn Lan ăn ngon lắm, hết suất cơm. Trần Minh Hoàng ngủ trưa ngon lành hai tiếng.",
    # Test 2: Partial name match (last name only)
    "Lan ăn ngon. Hoàng ho nhẹ. Mai vẽ tranh đẹp lắm.",
    # Test 3: Nickname match
    "Bé Lan ăn ngon. Bé Hoàng ngủ trưa ngon. Cả lớp vui chơi.",
    # Test 4: Ambiguous (2 children in same segment)
    "Nguyễn Văn Lan và Trần Minh Hoàng cùng ăn ngon. Cả hai đều vui vẻ.",
    # Test 5: No name match
    "Hôm nay trời đẹp. Cả lớp ra sân chơi. Cô giáo rất vui.",
    # Test 6: Mixed - some matched, some not
    "Lan ăn ngon. Trời mưa to. Hoàng ho nhẹ. Mai ngủ trưa hai tiếng.",
    # Test 7: Single child multiple facts
    "Nguyễn Văn Lan ăn ngon, ngủ trưa ngon, ho nhẹ, vẽ tranh đẹp và rất vui vẻ.",
    # Test 8: Vietnamese name patterns
    "Bé Lan ăn sáng ngon. Bé Hoàng uống sữa. Cô cho cả lớp ra ngoài chơi.",
]


# ============================================================
# NAME MATCHING LOGIC (copy từ service)
# ============================================================

MIN_CONFIDENCE_THRESHOLD = 0.3
NICKNAME_BONUS = 0.15
MIN_MATCHED_WORDS = 1


def _tokenize(text: str):
    if not text:
        return []
    text = re.sub(r'[.!?,;:\(\)\[\]"\'\-–—]', " ", text.lower())
    return [w.strip() for w in text.split() if w.strip()]


def _calculate_word_overlap(text_words, name_words):
    name_words_lower = set(name_words)
    return [w for w in text_words if w in name_words_lower]


def _calculate_nickname_overlap(text_words, nickname):
    if not nickname:
        return False
    nickname_words = _tokenize(nickname)
    text_words_set = set(text_words)
    return any(w in text_words_set for w in nickname_words)


@dataclass
class NameMatch:
    child_id: str
    full_name: str
    nickname: str | None
    matched_words: list
    confidence: float
    is_ambiguous: bool = False


def match_single_text(text: str, children: list, min_confidence: float = 0.3):
    if not text or not children:
        return []

    text_words = _tokenize(text)
    matches = []

    for child in children:
        full_name = child.full_name or ""
        name_words = _tokenize(full_name)

        if not name_words:
            continue

        # Calculate name match
        matched_words = _calculate_word_overlap(text_words, name_words)
        name_score = len(matched_words) / len(name_words) if name_words else 0

        # Nickname bonus
        nickname_bonus = 0
        if _calculate_nickname_overlap(text_words, child.nickname):
            nickname_bonus = NICKNAME_BONUS

        # Total confidence
        confidence = min(name_score + nickname_bonus, 1.0)

        # Check minimum threshold
        if confidence < min_confidence or len(matched_words) < MIN_MATCHED_WORDS:
            continue

        matches.append(
            NameMatch(
                child_id=child.child_id,
                full_name=full_name,
                nickname=child.nickname,
                matched_words=matched_words,
                confidence=confidence,
            )
        )

    # Sort by confidence
    matches.sort(key=lambda x: -x.confidence)

    # Mark ambiguous
    if len(matches) > 1:
        top_confidence = matches[0].confidence
        for m in matches:
            m.is_ambiguous = (
                m.confidence == top_confidence
                and len([x for x in matches if x.confidence == top_confidence]) > 1
            )

    return matches


# ============================================================
# TEST RUNNER
# ============================================================


def run_tests():
    print("=" * 70)
    print("[TEST] NAME MATCHING SERVICE")
    print("=" * 70)

    for i, transcript in enumerate(TEST_TRANSCRIPTS, 1):
        print(f"\n{'-' * 70}")
        print(f"[TEST {i}]")
        print(f"{'-' * 70}")
        print(f'Transcript: "{transcript}"')

        # Split by sentence
        segments = re.split(r"[.!?\n]+", transcript)
        segments = [s.strip() for s in segments if s.strip()]

        print(f"\n>> Segments: {len(segments)}")

        total_matches = 0
        ambiguous_count = 0
        unmatched_count = 0

        for j, segment in enumerate(segments, 1):
            matches = match_single_text(segment, CHILDREN)

            print(f'\n  Segment {j}: "{segment}"')

            if not matches:
                print("    [NO MATCH]")
                unmatched_count += 1
            else:
                top_confidence = matches[0].confidence
                top_matches = [m for m in matches if m.confidence == top_confidence]

                if len(top_matches) > 1:
                    print(
                        f"    [AMBIGUOUS - {len(top_matches)} children same confidence]"
                    )
                    ambiguous_count += 1
                else:
                    print("    [MATCHED]")

                for m in matches[:5]:  # Show top 5
                    amb_flag = "[AMB]" if m.is_ambiguous else "    "
                    print(
                        f"      {amb_flag} {m.full_name} ({m.nickname or 'no nickname'})"
                    )
                    print(f"           matched_words: {m.matched_words}")
                    print(f"           confidence: {m.confidence:.2f}")

                total_matches += 1

        print(
            f"\n  [SUMMARY] matched: {total_matches} | ambiguous: {ambiguous_count} | unmatched: {unmatched_count}"
        )


def interactive_test():
    print("\n" + "=" * 70)
    print("[INTERACTIVE TEST MODE]")
    print("=" * 70)
    print("Nhap transcript de test (Enter 2 lan de chay, Ctrl+C de thoat)")
    print("-" * 70)

    lines = []
    while True:
        try:
            line = input()
            if line == "":
                if lines:
                    transcript = " ".join(lines)
                    print(f"\n{'=' * 50}")
                    print(f'Testing: "{transcript}"')
                    print("=" * 50)

                    segments = re.split(r"[.!?\n]+", transcript)
                    segments = [s.strip() for s in segments if s.strip()]

                    for j, segment in enumerate(segments, 1):
                        matches = match_single_text(segment, CHILDREN)
                        print(f'\n  Segment {j}: "{segment}"')

                        if not matches:
                            print("    [NO MATCH]")
                        else:
                            for m in matches:
                                print(
                                    f"    [OK] {m.full_name} ({m.nickname or 'no nickname'})"
                                )
                                print(
                                    f"        matched: {m.matched_words}, confidence: {m.confidence:.2f}"
                                )

                    lines = []
                    print("\n" + "-" * 50)
                    print("Tiep tuc nhap transcript:")
                else:
                    break
            else:
                lines.append(line)
        except (KeyboardInterrupt, EOFError):
            print("\n\n[BYE]")
            break


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--interactive":
        interactive_test()
    else:
        run_tests()
        print("\n" + "=" * 70)
        print("Run với --interactive để test thêm:")
        print("  python test_name_matching.py --interactive")
        print("=" * 70)
