import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/review_common_widgets.dart';

enum RecordMode { classroom, child }

String recordAllergy(String value) => value
    .replaceFirst(RegExp(r'^Dị ứng\s*:?\s*', caseSensitive: false), '')
    .trim();

enum ObservationKind { normal, unmatched, classwide }

class ObservationItem {
  ObservationItem({
    required this.id,
    required this.name,
    this.childId,
    this.nickname,
    this.matched = true,
    this.decision = ObservationDecision.approved,
    this.kind = ObservationKind.normal,
    this.eating = '',
    this.sleep = '',
    this.activities = '',
    this.mood = '',
    this.health = '',
    this.note = '',
    this.snippet = '',
    this.severity = Severity.none,
  });

  final String id;
  String name;
  String? childId;
  String? nickname;

  String get fullNameWithNickname {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty && !name.contains('($nick)')) {
      return '$name ($nick)';
    }
    return name;
  }
  bool matched;
  ObservationDecision decision;
  ObservationKind kind;
  String eating;
  String sleep;
  String activities;
  String mood;
  String health;
  String note;
  String snippet;
  Severity severity;

  ObservationItem assign(Child child) {
    return ObservationItem(
      id: id,
      name: child.name,
      childId: child.id,
      nickname: child.nickname,
      matched: true,
      decision: ObservationDecision.pending,
      kind: ObservationKind.normal,
      eating: eating,
      sleep: sleep,
      activities: activities,
      mood: mood,
      health: health,
      note: note,
      snippet: snippet,
      severity: severity,
    );
  }
}
