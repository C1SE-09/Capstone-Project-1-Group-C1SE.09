import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/no_assignment_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/report_editor.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

class _VisualAuthRepository extends AuthRepository {
  @override
  Future<({String username, String password})?> readRememberedLogin() async =>
      null;
}

class _TeacherAccountDashboard extends HttpDashboardRepository {
  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
        teacherId: 'teacher-1',
        fullName: 'Nguyễn Thị Hương',
        email: 'teacher@example.com',
      );

  @override
  Future<List<Child>> getClassChildren(String classId) async => const [];
}

class _TeacherAccountClassRepository extends HttpClassDataRepository {
  @override
  Future<ClassInfo> getClassInfo(String classId) async => const ClassInfo(
        classId: 'class-1',
        schoolId: 'school-1',
        name: 'Lớp Mầm 1',
      );
}

class _ReviewDashboard extends HttpDashboardRepository {
  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
        teacherId: 'teacher-1',
        fullName: 'Cô Nguyễn Thị Mai',
        email: 'teacher@example.com',
      );

  @override
  Future<List<Child>> getClassChildren(String classId) async => const [
        Child(
          childId: 'child-1',
          classId: 'class-1',
          fullName: 'Nguyễn Minh An',
        ),
      ];

  @override
  Future<ClassDashboardSummary> getClassDashboard(
          String classId, DateTime date) async =>
      const ClassDashboardSummary(
        classInfo: ClassInfo(
          classId: 'class-1',
          schoolId: 'school-1',
          name: 'Lớp Mầm 1',
        ),
        teacherName: 'Cô Nguyễn Thị Mai',
        totalChildren: 1,
        completedCount: 0,
        draftCount: 0,
        missingCount: 1,
        pendingChildren: [],
      );
}

class _ReviewTeacherRepository extends TeacherRepository {
  _ReviewTeacherRepository({
    List<Map<String, dynamic>>? responses,
    this.throwOnSend = false,
    this.failedPublishIds = const {},
  }) : responses = responses ?? [];

  final List<Map<String, dynamic>> responses;
  final List<List<String>> sendRequests = [];
  final bool throwOnSend;
  final Set<String> failedPublishIds;

  @override
  Future<Map<String, dynamic>> approveItem({
    required String voiceRecordId,
    required String teacherId,
    required String kind,
    String? childId,
    String? classId,
    Map<String, String?>? extraction,
  }) async =>
      {
        'draft_report_ids': ['draft-$kind-${childId ?? classId}'],
      };

  @override
  Future<Map<String, dynamic>> sendBatch({
    required String teacherId,
    List<String>? reportIds,
    String? classId,
    String? reportDate,
  }) async {
    sendRequests.add(List<String>.from(reportIds ?? const []));
    if (throwOnSend) throw StateError('batch send unavailable');
    return responses.isEmpty
        ? {
        'sent': reportIds?.length ?? 0,
        'skipped': 0,
        'failed': 0,
          }
        : responses.removeAt(0);
  }

  @override
  Future<Map<String, dynamic>> publishReport({
    required String reportId,
    required String teacherId,
  }) async {
    if (failedPublishIds.contains(reportId)) {
      throw StateError('individual send unavailable');
    }
    return {'status': 'sent'};
  }

  @override
  Future<void> deleteDraftReports(List<String> reportIds) async {}
}

class _DeniedRecorder extends AudioRecorder {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> dispose() async {}
}

class _FailingRecorder extends AudioRecorder {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    throw StateError('recorder unavailable');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('Login shows the Figma welcome and classroom illustration while retaining remember control',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: LoginScreen(
        authRepository: _VisualAuthRepository(),
        onLogin: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(find.byKey(const ValueKey('loginIllustration')), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login keeps password compact with a centered, accessible reveal control',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: LoginScreen(
        authRepository: _VisualAuthRepository(),
        onLogin: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    final usernameBox = find.ancestor(
      of: fields.first,
      matching: find.byType(Container),
    ).first;
    final passwordBox = find.ancestor(
      of: fields.last,
      matching: find.byType(Container),
    ).first;
    expect(tester.getSize(usernameBox).height, closeTo(58, .1));
    expect(tester.getSize(passwordBox).height, closeTo(58, .1));

    final reveal = find.byType(IconButton);
    expect(tester.getSize(reveal).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(reveal).height, greaterThanOrEqualTo(48));
    expect(tester.getCenter(reveal).dy,
        closeTo(tester.getCenter(passwordBox).dy, .1));
    await tester.enterText(fields.last, 'test-password');
    await tester.ensureVisible(reveal);
    await tester.tap(reveal);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.last).obscureText, isFalse);
    expect(tester.widget<TextField>(fields.last).controller!.text, 'test-password');
    expect(tester.getSize(passwordBox).height, closeTo(58, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login hints are subdued and exploration labels have no separate fill',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: LoginScreen(
        authRepository: _VisualAuthRepository(),
        onLogin: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    final palette = KPalette.loginWarmSage;
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      final hint = field.decoration!.hintStyle!;
      expect(hint.fontWeight, FontWeight.w400);
      expect(hint.color, palette.inkFaint);
      expect(hint.color!.computeLuminance(),
          greaterThan(field.style!.color!.computeLuminance()));
      final contrast = (palette.surfaceSunken.computeLuminance() + .05) /
          (hint.color!.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
    for (final label in ['Giáo viên', 'Phụ huynh']) {
      final pill = tester.widget<Container>(find.ancestor(
        of: find.text(label),
        matching: find.byType(Container),
      ).first);
      expect((pill.decoration as BoxDecoration?)?.color,
          anyOf(isNull, Colors.transparent));
    }
  });

  testWidgets('NoAssignmentScreen uses the Figma empty-state illustration and logout action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: NoAssignmentScreen(
        title: 'Chưa được phân lớp',
        message: 'Liên hệ nhà trường để được hỗ trợ.',
        onBack: () {},
        backButtonLabel: 'Đăng xuất',
        gardenVoice: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GardenVoiceScope), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Chưa được phân lớp'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChangePasswordScreen uses the GV page scope and requirement hint',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: ChangePasswordScreen(authRepository: _VisualAuthRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GardenVoiceScope), findsOneWidget);
    expect(find.text('Yêu cầu mật khẩu mới'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Child actions show the Figma daily note and full-screen actions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    ui.Child? recordedChild;
    ui.Child? editedChild;
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: Scaffold(
        body: ClassListScreen(
          initialHealthOnly: false,
          className: 'Lớp Mầm 1',
          schoolName: 'Trường Mầm non',
          onRecord: (child) => recordedChild = child,
          onEdit: (child) => editedChild = child,
          children: const [
            ui.Child(
              id: 'child-1',
              name: 'Nguyễn Minh An',
              status: ui.ReportStatus.none,
              present: true,
              time: '',
              severity: ui.Severity.none,
              allergy: 'Đậu phộng',
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Nguyễn Minh An')).style?.fontWeight,
      FontWeight.w800,
    );
    await tester.tap(find.text('Nguyễn Minh An'));
    await tester.pumpAndSettle();

    expect(find.text('Ghi nhận trong ngày'), findsOneWidget);
    expect(find.text('Dị ứng đậu phộng'), findsOneWidget);
    expect(find.text('Ghi âm cho bé'), findsOneWidget);
    expect(find.text('Soạn báo cáo'), findsOneWidget);
    await tester.tap(find.text('Ghi âm cho bé'));
    await tester.pumpAndSettle();
    expect(recordedChild?.name, 'Nguyễn Minh An');
    expect(editedChild, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Child actions do not duplicate an allergy label prefix',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: Scaffold(
        body: ClassListScreen(
          initialHealthOnly: false,
          onRecord: (_) {},
          onEdit: (_) {},
          children: const [
            ui.Child(
              id: 'child-2',
              name: 'Trần Bảo Ngọc',
              status: ui.ReportStatus.none,
              present: true,
              time: '',
              severity: ui.Severity.none,
              allergy: 'Dị ứng đậu phộng',
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trần Bảo Ngọc'));
    await tester.pumpAndSettle();

    expect(find.text('Dị ứng đậu phộng'), findsOneWidget);
    expect(find.text('Dị ứng Dị ứng đậu phộng'), findsNothing);
  });

  testWidgets('Teacher account opens password change as the Figma full screen',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TeacherAccountScreen(
              onLogout: () {},
              repository: _TeacherAccountDashboard(),
              classRepository: _TeacherAccountClassRepository(),
            ),
          ),
        ),
        GoRoute(
          path: '/change-password',
          builder: (context, state) => ChangePasswordScreen(
            authRepository: _VisualAuthRepository(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      theme: kinderTheme(),
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đổi mật khẩu'));
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();

    expect(find.text('Bảo vệ tài khoản KinderLog'), findsOneWidget);
    expect(find.text('Yêu cầu mật khẩu mới'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('Recording permission denial uses the Figma recovery dialog',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: RecordingScreen(
        mode: RecordMode.child,
        onSubmit: (_) {},
        audioRecorder: _DeniedRecorder(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bắt đầu ghi âm'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có quyền micro'), findsOneWidget);
    expect(find.text('Mở cài đặt'), findsOneWidget);
    expect(find.text('Để sau'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recorder failure uses the Figma retry dialog', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: RecordingScreen(
        mode: RecordMode.child,
        onSubmit: (_) {},
        audioRecorder: _FailingRecorder(),
        pathProvider: (_) async => 'test.m4a',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bắt đầu ghi âm'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa thể ghi âm'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Đóng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Classwide review, send, and completion use the Figma states',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final teacherRepository = _ReviewTeacherRepository(responses: [
      {
        'sent': 1,
        'skipped': 0,
        'failed': 1,
        'results': [
          {
            'daily_report_id': 'draft-classwide-class-1',
            'result': 'sent',
          },
          {
            'daily_report_id': 'draft-child-child-1',
            'result': 'failed',
          },
        ],
      },
      {
        'sent': 1,
        'skipped': 0,
        'failed': 0,
        'results': [
          {
            'daily_report_id': 'draft-child-child-1',
            'result': 'sent',
          },
        ],
      },
    ]);
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: GardenVoiceScope(
        child: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            classWideExtraction: {
              'activities': 'Vẽ tranh mùa thu, rất hứng thú.',
            },
            childExtractions: {
              'child-1': {
                'meals': 'Ăn hết suất cơm.',
                'sleeping': 'Ngủ từ 12:00 đến 13:45.',
              },
            },
          ),
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: _ReviewDashboard(),
          teacherRepository: teacherRepository,
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duyệt tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Duyệt báo cáo cả lớp'), findsOneWidget);
    expect(find.text('Riêng Nguyễn Minh An'), findsOneWidget);
    expect(find.text('Áp dụng cho cả lớp'), findsOneWidget);
    expect(find.text('Vẽ tranh mùa thu, rất hứng thú.'), findsOneWidget);
    await tester.tap(find.text('Xác nhận gửi cho cả lớp'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi 1 báo cáo; còn 1 báo cáo chưa gửi. Vui lòng thử lại.'),
        findsOneWidget);
    expect(find.text('Xác nhận gửi cho cả lớp'), findsOneWidget);
    expect(teacherRepository.sendRequests.first, hasLength(2));
    await tester.tap(find.text('Xác nhận gửi cho cả lớp'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi báo cáo'), findsOneWidget);
    expect(find.text('Về tổng quan lớp'), findsOneWidget);
    expect(teacherRepository.sendRequests.last,
        ['draft-child-child-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discarding classwide content does not claim it was sent to all parents',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final teacherRepository = _ReviewTeacherRepository();

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: GardenVoiceScope(
        child: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            classWideExtraction: {'activities': 'Vẽ tranh mùa thu.'},
            childExtractions: {
              'child-1': {'meals': 'Ăn hết suất cơm.'},
            },
          ),
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: _ReviewDashboard(),
          teacherRepository: teacherRepository,
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Loại bỏ').first);
    await tester.tap(find.text('Loại bỏ').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Duyệt'));
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hoàn thành'));
    await tester.tap(find.text('Hoàn thành'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi thành công.'), findsOneWidget);
    expect(
      find.text(
          'Báo cáo ngày đã được gửi đến phụ huynh của từng bé trong lớp Mầm 1.'),
      findsNothing,
    );
    expect(teacherRepository.sendRequests.single, ['draft-child-child-1']);
  });

  testWidgets('Batch fallback does not report success when one report still fails',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final teacherRepository = _ReviewTeacherRepository(
      throwOnSend: true,
      failedPublishIds: {'draft-child-child-1'},
    );

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: GardenVoiceScope(
        child: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            classWideExtraction: {'activities': 'Vẽ tranh mùa thu.'},
            childExtractions: {
              'child-1': {'meals': 'Ăn hết suất cơm.'},
            },
          ),
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: _ReviewDashboard(),
          teacherRepository: teacherRepository,
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duyệt tất cả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận gửi cho cả lớp'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi 1 báo cáo; còn 1 báo cáo chưa gửi. Vui lòng thử lại.'),
        findsOneWidget);
    expect(find.text('Đã gửi báo cáo'), findsNothing);
    expect(find.text('Xác nhận gửi cho cả lớp'), findsOneWidget);
  });

  testWidgets('Skipping an unmatched segment offers Figma reprocessing action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: GardenVoiceScope(
        child: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          extraction: const ExtractionData(
            childExtractions: {
              'child-1': {
                'meals': 'Ăn hết suất cơm.',
                'sleeping': 'Ngủ từ 12:00 đến 13:45.',
              },
            },
            rawJson: {
              'unmatched_segments': [
                {
                  'text': 'vẽ tranh mùa thu',
                  'extraction': {'activities': 'Vẽ tranh mùa thu.'},
                },
              ],
            },
          ),
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: _ReviewDashboard(),
          teacherRepository: _ReviewTeacherRepository(),
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ qua đoạn này'));
    await tester.pumpAndSettle();

    expect(find.text('Đoạn chưa rõ “vẽ tranh mùa thu” đã được bỏ qua.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Duyệt'));
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();
    final sendButton =
        find.widgetWithText(FilledButton, 'Gửi báo cáo cho phụ huynh');
    expect(sendButton, findsOneWidget);
    expect(tester.widget<FilledButton>(sendButton).onPressed, isNotNull);
    expect(find.text('Xử lý lại đoạn ghi'), findsOneWidget);
    await tester.ensureVisible(find.text('Xử lý lại đoạn ghi'));
    await tester.tap(find.text('Xử lý lại đoạn ghi'));
    await tester.pumpAndSettle();
    expect(find.text('Gán đoạn này'), findsOneWidget);
  });

  testWidgets('Batch 5 auth and settings states stay usable at 320dp and 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final screen in <Widget>[
      LoginScreen(
        authRepository: _VisualAuthRepository(),
        onLogin: (_) {},
      ),
      NoAssignmentScreen(
        title: 'Chưa được phân lớp',
        message:
            'Tài khoản của bạn chưa được Ban giám hiệu phân vào lớp nào. Vui lòng liên hệ nhà trường để được hỗ trợ, hoặc thử đăng nhập lại sau.',
        onBack: () {},
        gardenVoice: true,
      ),
      ChangePasswordScreen(authRepository: _VisualAuthRepository()),
      ReportEditorScreen(
        child: const ui.Child(
          id: '',
          name: 'Trần Bảo Ngọc',
          status: ui.ReportStatus.draft,
          present: true,
          time: '',
          severity: ui.Severity.none,
        ),
        classId: 'class-1',
        repository: _TeacherAccountDashboard(),
        classRepository: _TeacherAccountClassRepository(),
        onSent: () {},
      ),
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: kinderTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: screen,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showBugReportBottomSheet(context),
            child: const Text('Mở góp ý'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở góp ý'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
