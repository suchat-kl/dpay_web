// เทสต์หน้าต่างเปลี่ยนรหัสผ่านของตัวเอง (POST /api/auth/changepassword {oldPassword, newPassword})

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/widgets/account_form.dart';
import 'package:dpay/widgets/change_password_dialog.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();
  const me = FakeBackend.user;
  final oldPass = FakeBackend.passwordOf(me);

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
  });

  tearDown(() => auth.logout());

  /// เปิดหน้าต่างจากปุ่มบนหน้าเปล่า คืนตัวเก็บผลที่หน้าต่างคืนตอนปิด
  Future<List<bool?>> open(WidgetTester tester, {bool forced = false}) async {
    tester.view.physicalSize = const Size(1200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => auth.login(me, oldPass));
    backend.clearLog();
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ChangePasswordDialog(
                    username: me,
                    apiService: api,
                    forced: forced,
                  ),
                ),
              ),
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    return results;
  }

  final oldField = find.widgetWithText(
    TextFormField,
    ChangePasswordDialog.oldHint,
  );
  final newField = find.widgetWithText(
    TextFormField,
    ChangePasswordDialog.newHint,
  );
  final confirmField = find.widgetWithText(
    TextFormField,
    ChangePasswordDialog.confirmHint,
  );
  final submit = find.widgetWithText(
    ElevatedButton,
    ChangePasswordDialog.title,
  );

  Future<void> fill(
    WidgetTester tester,
    String old,
    String next, [
    String? confirm,
  ]) async {
    await tester.enterText(oldField, old);
    await tester.enterText(newField, next);
    await tester.enterText(confirmField, confirm ?? next);
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  testWidgets('แสดงชื่อผู้ใช้ (แก้ไม่ได้) และเงื่อนไขรหัสผ่านตาม backend', (
    tester,
  ) async {
    await open(tester);

    expect(find.text(ChangePasswordDialog.normalSubtitle), findsOneWidget);
    expect(find.widgetWithText(TextFormField, me), findsOneWidget);
    expect(find.text(PasswordRuleList.title), findsOneWidget);
    expect(find.text('ยาว 8-72 ตัวอักษร'), findsOneWidget);
    expect(find.textContaining('พิมพ์ใหญ่'), findsOneWidget);
    expect(find.textContaining('พิมพ์เล็ก'), findsOneWidget);
    expect(find.textContaining('ตัวเลข'), findsOneWidget);
    expect(find.textContaining('อักขระพิเศษ'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    // พิมพ์รหัสผ่านใหม่: เงื่อนไขติ๊กถูกทีละข้อ
    await tester.enterText(newField, 'abc');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.enterText(newField, 'Newpass@2569x');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
  });

  testWidgets(
    'ไม่กรอก / ยืนยันไม่ตรง / เหมือนรหัสเดิม: เตือน ไม่เรียก backend',
    (tester) async {
      await open(tester);

      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('กรุณากรอกรหัสผ่านเดิม'), findsOneWidget);
      expect(find.text('กรุณากรอกรหัสผ่านใหม่'), findsOneWidget);
      expect(find.text('กรุณายืนยันรหัสผ่านใหม่'), findsOneWidget);

      await fill(tester, oldPass, 'Newpass@2569x', 'Newpass@2569y');
      expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);

      await fill(tester, oldPass, oldPass);
      expect(
        find.text('รหัสผ่านใหม่ต้องไม่เหมือนรหัสผ่านเดิม'),
        findsOneWidget,
      );

      expect(backend.calls, isEmpty);
    },
  );

  testWidgets(
    'รหัสผ่านใหม่ไม่ครบเงื่อนไข / ยาวเกิน 72 ตัว: เตือน ไม่เรียก backend',
    (tester) async {
      await open(tester);

      await fill(tester, oldPass, 'newpass2569');
      expect(find.text(PasswordRules.notMetMessage), findsOneWidget);

      await fill(tester, oldPass, 'Aa1!${'x' * 69}');
      expect(find.text(PasswordRules.tooLongMessage), findsOneWidget);
      expect(backend.calls, isEmpty);
    },
  );

  testWidgets(
    'รหัสผ่านเดิมผิด: แสดงข้อความของ backend หน้าต่างไม่ปิด ปิดแถบข้อความได้',
    (tester) async {
      final results = await open(tester);
      await fill(tester, 'Wrong@0000x', 'Newpass@2569x');

      expect(backend.calls, ['POST /api/auth/changepassword']);
      expect(find.text(FakeBackend.wrongOldPasswordMessage), findsOneWidget);
      expect(find.byType(ChangePasswordDialog), findsOneWidget);
      expect(results, isEmpty);
      expect(backend.users[me]!.password, oldPass);

      await tester.ensureVisible(find.byIcon(Icons.close));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text(FakeBackend.wrongOldPasswordMessage), findsNothing);
    },
  );

  testWidgets(
    'เปลี่ยนสำเร็จ: ส่งเฉพาะรหัสเดิมกับรหัสใหม่ ปิดหน้าต่างคืน true',
    (tester) async {
      final results = await open(tester);
      await fill(tester, oldPass, 'Newpass@2569x');

      expect(backend.bodyOf('POST /api/auth/changepassword'), {
        'oldPassword': oldPass,
        'newPassword': 'Newpass@2569x',
      });
      expect(find.byType(ChangePasswordDialog), findsNothing);
      expect(results, [true]);
      expect(find.textContaining('เปลี่ยนรหัสผ่านสำเร็จ'), findsOneWidget);
      expect(backend.users[me]!.password, 'Newpass@2569x');
      expect(auth.isLoggedIn, isTrue);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('กดยกเลิก: ปิดหน้าต่างคืน false ไม่เรียก backend', (
    tester,
  ) async {
    final results = await open(tester);
    final cancel = find.widgetWithText(OutlinedButton, 'ยกเลิก');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordDialog), findsNothing);
    expect(results, [false]);
    expect(backend.calls, isEmpty);
  });

  testWidgets('แบบบังคับ: ไม่มีปุ่มยกเลิก มีปุ่มออกจากระบบ (คืน false)', (
    tester,
  ) async {
    final results = await open(tester, forced: true);

    expect(find.text(ChangePasswordDialog.forcedSubtitle), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ยกเลิก'), findsNothing);
    final leave = find.widgetWithText(OutlinedButton, 'ออกจากระบบ');
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('ปุ่มแสดง/ซ่อนรหัสผ่าน', (tester) async {
    await open(tester);
    EditableText editable() => tester.widget<EditableText>(
      find.descendant(of: oldField, matching: find.byType(EditableText)),
    );
    expect(editable().obscureText, isTrue);
    await tester.tap(find.byTooltip('แสดงรหัสผ่าน').first);
    await tester.pumpAndSettle();
    expect(editable().obscureText, isFalse);
    expect(find.byTooltip('ซ่อนรหัสผ่าน'), findsOneWidget);
  });
}
