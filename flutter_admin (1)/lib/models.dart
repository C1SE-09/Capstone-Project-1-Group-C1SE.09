enum AdminTab { overview, features, account }

enum AdminCategory { teachers, students, parents, schedules }

class Teacher {
  const Teacher({
    required this.id,
    required this.name,
    required this.classes,
    required this.phone,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final List<String> classes;
  final String phone;
  final String email;
  final String role;
}

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.className,
    required this.nickname,
    required this.medicalNotes,
  });

  final String id;
  final String name;
  final String className;
  final String nickname;
  final String medicalNotes;
}

class ParentAccount {
  const ParentAccount({
    required this.id,
    required this.name,
    required this.linkedChildren,
    required this.phone,
    required this.email,
    required this.relationship,
  });

  final String id;
  final String name;
  final List<String> linkedChildren;
  final String phone;
  final String email;
  final String relationship;
}

class Schedule {
  const Schedule({
    required this.id,
    required this.day,
    required this.name,
    required this.start,
    required this.end,
    required this.room,
    required this.teacherName,
    required this.description,
  });

  final String id;
  final int day;
  final String name;
  final String start;
  final String end;
  final String room;
  final String teacherName;
  final String description;
}

class ScheduleConflict {
  const ScheduleConflict(this.first, this.second, this.message);

  final Schedule first;
  final Schedule second;
  final String message;
}

class ClassProgress {
  const ClassProgress({
    required this.className,
    required this.grade,
    required this.teacher,
    required this.total,
    required this.reported,
  });

  final String className;
  final String grade;
  final String teacher;
  final int total;
  final int reported;

  int get pending => total - reported;
  double get progress => reported / total;
}
