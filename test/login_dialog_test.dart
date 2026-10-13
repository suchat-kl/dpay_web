// เทสต์หน้าต่างเข้าสู่ระบบ: ตรวจช่องกรอกก่อนส่ง ข้อความเมื่อ backend ปฏิเสธ และขนาดบนจอโน้ตบุ๊ก

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/main.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/widgets/login_dialog.dart';

import 'fake_backend.dart';

const _user = FakeBackend.user;
const _admin = FakeBackend.admin;
final _userPass = FakeBackend.passwordOf(_user);
final _adminPass = FakeBackend.passwordOf(_admin);

void main() {
  late FakeBackend backend;
  late AuthProvider auth;

  // ออกจากระบบนอกโซนเวลาจำลองของ testWidgets (ในโซนนั้น await คำขอ Dio ตรง ๆ จะค้าง)
  tearDown(() => auth.logout());

  Future<void> open(
    WidgetTester tester, {
    String? initialUsername,
    String? initialMessage,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend = await installFakeBackend();
    auth = AuthProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginDialog(
            authProvider: auth,
            initialUsername: initialUsername,
            initialMessage: initialMessage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final submit = find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ');
  final username = find.widgetWithText(TextFormField, 'ชื่อผู้ใช้');
  final password = find.widgetWithText(TextFormField, 'รหัสผ่าน');

  testWidgets('หัวหน้าต่างแสดงชื่อระบบจาก AppConfig มีแค่สองช่องกรอก', (
    tester,
  ) async {
    await open(tester);
    expect(AppConfig.systemName, 'ระบบหักหนี้');
    expect(find.text(AppConfig.systemName), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    // ไม่มีทางเข้าอื่นนอกจากชื่อผู้ใช้/รหัสผ่าน (ไม่มี ThaID ลงทะเบียน หรือลืมรหัสผ่าน)
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets(
    'ไม่กรอกอะไรแล้วกดเข้าสู่ระบบ: เตือนทั้งสองช่อง ไม่เรียก backend',
    (tester) async {
      await open(tester);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('กรุณากรอกชื่อผู้ใช้'), findsOneWidget);
      expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
      expect(backend.calls, isEmpty);
      expect(auth.isLoggedIn, isFalse);
    },
  );

  testWidgets('กรอกชื่อผู้ใช้อย่างเดียว: เตือนเฉพาะช่องรหัสผ่าน', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(username, _admin);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อผู้ใช้'), findsNothing);
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
    expect(backend.calls, isEmpty);
  });

  testWidgets(
    'รหัสผ่านผิด: แสดงข้อความจาก backend ปิดแถบข้อความได้ และยังไม่เข้าสู่ระบบ',
    (tester) async {
      await open(tester);
      await tester.enterText(username, _admin);
      await tester.enterText(password, 'wrong');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(backend.calls, ['POST /api/auth/login']);
      expect(find.text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
      expect(auth.isLoggedIn, isFalse);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'), findsNothing);
    },
  );

  testWidgets('บัญชีถูกล็อก / ถูกระงับ: แสดงข้อความของ backend ตามกรณี', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(username, FakeBackend.lockedUser);
    await tester.enterText(
      password,
      FakeBackend.passwordOf(FakeBackend.lockedUser),
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(FakeBackend.lockedMessage), findsOneWidget);
    expect(auth.isLoggedIn, isFalse);

    await tester.enterText(username, FakeBackend.disabledUser);
    await tester.enterText(
      password,
      FakeBackend.passwordOf(FakeBackend.disabledUser),
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(FakeBackend.disabledMessage), findsOneWidget);
    expect(find.text(FakeBackend.lockedMessage), findsNothing);
    expect(auth.isLoggedIn, isFalse);
  });

  testWidgets('ชื่อผู้ใช้มีช่องว่างหัวท้าย: ตัดออกก่อนส่ง แล้วเข้าสู่ระบบได้', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(username, '  $_admin ');
    await tester.enterText(password, _adminPass);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(auth.isLoggedIn, isTrue);
    expect(auth.username, _admin);
    // เข้าสู่ระบบใช้คำขอเดียว ข้อมูลผู้ใช้และบทบาทมากับผล login
    expect(backend.calls, ['POST /api/auth/login']);
    expect(backend.bodyOf('POST /api/auth/login'), {
      'username': _admin,
      'password': _adminPass,
    });
  });

  testWidgets('กด Enter ในช่องรหัสผ่าน = กดปุ่มเข้าสู่ระบบ', (tester) async {
    await open(tester);
    await tester.enterText(username, _user);
    await tester.enterText(password, _userPass);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(auth.isLoggedIn, isTrue);
    expect(auth.username, _user);
  });

  testWidgets('เปิดพร้อมชื่อผู้ใช้และข้อความแจ้ง: เติมให้และแสดงแถบสีเขียว', (
    tester,
  ) async {
    await open(
      tester,
      initialUsername: _user,
      initialMessage: 'กรุณาเข้าสู่ระบบอีกครั้ง',
    );

    expect(tester.widget<TextFormField>(username).controller!.text, _user);
    expect(find.text('กรุณาเข้าสู่ระบบอีกครั้ง'), findsOneWidget);
  });

  testWidgets('ต่อเซิร์ฟเวอร์ไม่ได้: แสดงข้อความภาษาไทย ไม่ค้างหมุน', (
    tester,
  ) async {
    await open(tester);
    backend.unreachable = true;
    await tester.enterText(username, _admin);
    await tester.enterText(password, _adminPass);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(auth.isLoggedIn, isFalse);
    backend.unreachable = false;
  });

  group('จอโน้ตบุ๊ก 1366x720', () {
    const screen = Size(1366, 720);

    /// เปิดแอปเต็ม (มีป้ายช่วงทดสอบและแถบบน) แล้วเปิดหน้าต่างเข้าสู่ระบบจากปุ่มบนแถบบน
    Future<void> openInApp(WidgetTester tester) async {
      // วัดด้วยฟอนต์จริงของแอป (ฟอนต์ตั้งต้นของเทสต์กว้างกว่ามาก)
      await tester.runAsync(loadAppFonts);
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      backend = await installFakeBackend();
      auth = AuthProvider();
      await tester.pumpWidget(DpayApp(authProvider: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();
    }

    final dialog = find.byType(LoginDialog);
    Finder inDialog(Finder f) => find.descendant(of: dialog, matching: f);
    final header = find.byKey(LoginDialog.headerKey);

    /// อยู่ในจอทั้งชิ้น และอยู่ใต้แถบหัวของหน้าต่าง (ไม่ถูกแถบหัวบัง)
    void expectVisible(WidgetTester tester, Finder f) {
      final rect = tester.getRect(f);
      expect(rect.top, greaterThanOrEqualTo(tester.getRect(header).bottom));
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
    }

    testWidgets('แถบหัวเตี้ย (ไม่เกิน 140) ยังเห็นชื่อเรื่องกับชื่อระบบ '
        'ช่องกรอก ปุ่มเข้าสู่ระบบ และยกเลิก เห็นครบโดยไม่ต้องเลื่อน', (
      tester,
    ) async {
      await openInApp(tester);

      expect(tester.getSize(header).height, lessThanOrEqualTo(140));
      expect(
        find.descendant(of: header, matching: find.text('เข้าสู่ระบบ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text(AppConfig.systemName)),
        findsOneWidget,
      );

      // เนื้อหาพอดีกับหน้าต่าง ไม่มีอะไรให้เลื่อน
      final scroll = tester.state<ScrollableState>(
        inDialog(find.byType(Scrollable)).first,
      );
      expect(scroll.position.maxScrollExtent, 0);

      expectVisible(tester, inDialog(username));
      expectVisible(tester, inDialog(password));
      expectVisible(
        tester,
        inDialog(find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ')),
      );
      expectVisible(
        tester,
        inDialog(find.widgetWithText(OutlinedButton, 'ยกเลิก')),
      );
    });

    testWidgets('กดยกเลิก: ปิดหน้าต่าง ไม่เรียก backend', (tester) async {
      await openInApp(tester);
      await tester.tap(inDialog(find.widgetWithText(OutlinedButton, 'ยกเลิก')));
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
      // หน้าแรกโหลดข้อความแจ้ง (เส้นสาธารณะ) อย่างเดียว ไม่มีคำขอเข้าสู่ระบบ
      expect(backend.calls, ['GET /api/alert-message']);
      expect(auth.isLoggedIn, isFalse);
    });
  });
}
