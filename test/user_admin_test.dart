// เทสต์เมนู "ผู้ใช้งาน": กำหนดรหัสผ่านใหม่ให้หน่วยงาน (RESETPWD/ADMIN) และจัดการผู้ใช้ (ADMIN)
// รวมเส้น /api/admin/* ตามสัญญาของ backend

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/models/user_admin.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/screens/user_list_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/reset_password_dialog.dart';
import 'package:dpay/widgets/user_dialog.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();

  Future<void> signIn(String username) =>
      auth.login(username, FakeBackend.passwordOf(username));

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
  });

  tearDown(() => auth.logout());

  Future<void> pump(
    WidgetTester tester,
    UserListMode mode, {
    required String as,
  }) async {
    tester.view.physicalSize = const Size(1300, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => signIn(as));
    backend.clearLog();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: UserListScreen(apiService: api, mode: mode),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Finder row(String username) =>
      find.byKey(UserListScreen.rowKey('u$username'));
  Finder action(String username) =>
      find.byKey(UserListScreen.actionKey('u$username'));
  Finder fieldOf(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );
  Finder inDialog(Type dialog, Finder f) =>
      find.descendant(of: find.byType(dialog), matching: f);

  bool enabled(WidgetTester tester, String username) =>
      tester.widget<ButtonStyleButton>(action(username)).onPressed != null;

  group('โมเดล UserAdmin', () {
    test('อ่าน JSON ของ backend ครบทุกช่อง', () {
      final u = UserAdmin.fromJson({
        'id': '665f0c2a9b1e',
        'username': '901',
        'password': null,
        'fullName': 'หน่วยงานตัวอย่างที่ 1',
        'email': null,
        'div': '901',
        'divName': 'หน่วยงานตัวอย่างที่ 1',
        'roles': ['USER', 'CENTER_DEPT'],
        'active': true,
        'locked': true,
        'mustChangePassword': true,
        'lastLogin': '2025-06-24T08:30:00',
      });
      expect(u.id, '665f0c2a9b1e');
      expect(u.email, '');
      expect(u.roles, ['USER', 'CENTER_DEPT']);
      expect(u.locked, isTrue);
      expect(u.mustChangePassword, isTrue);
      expect(u.lastLogin, DateTime(2025, 6, 24, 8, 30));
    });

    test(
      'ช่องขาดใช้ค่าตั้งต้น ไม่ล้ม และตัวข้อมูลที่ส่งไม่มี id/รหัสผ่านเกิน',
      () {
        final u = UserAdmin.fromJson({'id': 'x1', 'username': '950'});
        expect(u.fullName, '');
        expect(u.roles, isEmpty);
        expect(u.active, isFalse);
        expect(u.lastLogin, isNull);

        const draft = UserAdmin(
          id: 'x1',
          username: '950',
          fullName: 'หน่วยงานทดสอบ',
          div: '950',
          roles: ['USER'],
        );
        expect(draft.toUpdateJson(), {
          'fullName': 'หน่วยงานทดสอบ',
          'email': '',
          'div': '950',
          'roles': ['USER'],
          'active': true,
          'locked': false,
        });
        expect(draft.toCreateJson('Init@950x').keys, [
          'username',
          'password',
          'fullName',
          'email',
          'div',
          'roles',
        ]);
      },
    );
  });

  group('เส้น /api/admin (ไม่ผ่านหน้าจอ)', () {
    test('รายการผู้ใช้: แบ่งหน้า ค้นหา และไม่มีรหัสผ่านในคำตอบ', () async {
      await signIn(FakeBackend.admin);
      final page1 = await api.searchAdminUsers();
      expect(page1['totalItems'], 26);
      expect(page1['totalPages'], 3);
      expect(page1['users'], hasLength(10));
      expect((page1['users'] as List).first['username'], '901');
      expect(
        (page1['users'] as List).every((u) => u['password'] == null),
        isTrue,
      );
      expect(backend.queryOf('GET /api/admin/users'), {'page': 0, 'size': 10});

      final found = await api.searchAdminUsers(keyword: '92', page: 0, size: 5);
      expect(backend.queryOf('GET /api/admin/users'), {
        'keyword': '92',
        'page': 0,
        'size': 5,
      });
      expect(found['totalItems'], 7); // 920-926
    });

    test('บทบาทและหน่วยงานของฟอร์มผู้ใช้', () async {
      await signIn(FakeBackend.admin);
      final roles = await api.getRoles();
      expect(roles.map((r) => r['code']), Roles.order);
      expect(roles.last['name'], 'ผู้ดูแลระบบ จัดการบัญชีผู้ใช้');
      final divs = await api.getAdminDivs();
      expect(divs, hasLength(30));
      expect(divs.first.label, '901 หน่วยงานตัวอย่างที่ 1');
      expect(divs.where((d) => d.center).map((d) => d.div), [
        '902',
        '903',
        '904',
        '905',
        '909',
      ]);

      // โหลดบทบาทไม่สำเร็จ: ใช้ชุดตั้งต้นของระบบ ฟอร์มยังเลือกบทบาทได้
      backend.rolesStatus = 500;
      final fallback = await api.getRoles();
      expect(fallback.map((r) => r['code']), Roles.order);
      expect(fallback.first['name'], 'หน่วยงาน');
    });

    test('สิทธิ์ของแต่ละบทบาทต่อเส้นจัดการผู้ใช้', () async {
      Matcher forbidden() => throwsA(
        isA<ApiException>().having((e) => e.code, 'code', ErrorCodes.forbidden),
      );
      // บัญชีทั่วไป / ฝ่ายบัญชี: เข้าไม่ได้ทั้งหมด
      for (final u in [FakeBackend.user, FakeBackend.account]) {
        await signIn(u);
        await expectLater(api.searchAdminUsers(), forbidden(), reason: u);
        await expectLater(
          api.resetUserPassword('u910', 'Newpass@2569x'),
          forbidden(),
          reason: u,
        );
        await auth.logout();
      }

      // RESETPWD: ดูรายการและตั้งรหัสผ่านได้ แต่สร้าง/แก้/ดูหน่วยงานทั้งหมดไม่ได้
      await signIn(FakeBackend.resetPwd);
      expect((await api.searchAdminUsers())['totalItems'], 26);
      expect((await api.getAdminUser('u910')).username, '910');
      await expectLater(api.getAdminDivs(), forbidden());
      await expectLater(
        api.updateAdminUser(await api.getAdminUser('u910')),
        forbidden(),
      );
      await expectLater(
        api.createAdminUser(
          const UserAdmin(
            username: '950',
            fullName: 'หน่วยงานทดสอบ',
            div: '910',
            roles: ['USER'],
          ),
          'Init@950x',
        ),
        forbidden(),
      );
      expect(backend.users.containsKey('950'), isFalse);
    });

    test(
      'ตั้งรหัสผ่านใหม่: ส่งเฉพาะ newPassword บัญชีเป้าหมายต้องเปลี่ยนรหัสผ่านและถูกออกจากระบบ',
      () async {
        await signIn(FakeBackend.resetPwd);
        final message = await api.resetUserPassword('u910', 'Newpass@2569x');

        expect(message, FakeBackend.resetDoneMessage);
        expect(backend.bodyOf('POST /api/admin/users/u910/reset-password'), {
          'newPassword': 'Newpass@2569x',
        });
        expect(backend.users['910']!.password, 'Newpass@2569x');
        expect(backend.users['910']!.mustChange, isTrue);

        // ตั้งให้ตัวเองไม่ได้ / บัญชีสิทธิ์สูงไม่ได้ (ถ้าไม่ใช่ ADMIN)
        await expectLater(
          api.resetUserPassword('u903', 'Newpass@2569x'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', ErrorCodes.badRequest)
                .having(
                  (e) => e.toString(),
                  'message',
                  FakeBackend.resetSelfMessage,
                ),
          ),
        );
        for (final target in ['u902', 'u909']) {
          await expectLater(
            api.resetUserPassword(target, 'Newpass@2569x'),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.code, 'code', ErrorCodes.forbidden)
                  .having(
                    (e) => e.toString(),
                    'message',
                    FakeBackend.resetPrivilegedMessage,
                  ),
            ),
            reason: target,
          );
        }
        await auth.logout();

        // ADMIN ตั้งให้ฝ่ายบัญชีได้
        await signIn(FakeBackend.admin);
        await api.resetUserPassword('u902', 'Newpass@2569x');
        expect(backend.users['902']!.mustChange, isTrue);
      },
    );
  });

  group('กำหนดรหัสผ่านใหม่ให้หน่วยงาน', () {
    testWidgets(
      'RESETPWD: รายการแบ่งหน้า ปุ่มกดไม่ได้กับบัญชีตัวเองและบัญชีสิทธิ์สูง ไม่มีปุ่มเพิ่มผู้ใช้',
      (tester) async {
        await pump(
          tester,
          UserListMode.resetPassword,
          as: FakeBackend.resetPwd,
        );

        expect(find.text(UserListScreen.resetTitle), findsOneWidget);
        expect(find.text('เพิ่มผู้ใช้'), findsNothing);
        expect(find.text('ทั้งหมด 26 บัญชี'), findsOneWidget);
        expect(row('901'), findsOneWidget);
        expect(row('910'), findsOneWidget);
        expect(row('911'), findsNothing); // หน้าถัดไป
        expect(
          find.descendant(
            of: row('902'),
            matching: find.text('902  ·  กองบัญชีตัวอย่าง'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row('902'), matching: find.text('ฝ่ายบัญชี')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row('906'),
            matching: find.text('รอเปลี่ยนรหัสผ่าน'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row('907'), matching: find.text('ล็อก')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row('908'), matching: find.text('ระงับ')),
          findsOneWidget,
        );

        expect(enabled(tester, '901'), isTrue);
        expect(enabled(tester, '902'), isFalse); // ACCOUNT
        expect(enabled(tester, '903'), isFalse); // ตัวเอง
        expect(enabled(tester, '909'), isFalse); // ADMIN
        expect(
          find.byTooltip(UserListScreen.ownAccountTooltip),
          findsOneWidget,
        );
        expect(
          find.byTooltip(UserListScreen.privilegedTooltip),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('ค้นหาหน่วยงาน แล้วไปหน้าถัดไปและเปลี่ยนจำนวนแถวต่อหน้า', (
      tester,
    ) async {
      await pump(tester, UserListMode.resetPassword, as: FakeBackend.resetPwd);

      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();
      expect(backend.queryOf('GET /api/admin/users'), {'page': 1, 'size': 10});
      expect(row('911'), findsOneWidget);
      expect(row('901'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'ค้นหา'), '92');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // ค้นใหม่กลับไปหน้าแรก
      expect(backend.queryOf('GET /api/admin/users'), {
        'keyword': '92',
        'page': 0,
        'size': 10,
      });
      expect(find.text('ทั้งหมด 7 บัญชี'), findsOneWidget);
      expect(row('920'), findsOneWidget);
      expect(row('911'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'ค้นหา'),
        'ไม่มีหน่วยงานนี้',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(UserListScreen.emptyText), findsOneWidget);

      await tester.tap(find.byTooltip('ล้างคำค้น'));
      await tester.pumpAndSettle();
      expect(find.text('ทั้งหมด 26 บัญชี'), findsOneWidget);
      await settleSnackBar(tester);
    });

    testWidgets('เลือกหน่วยงานแล้วกำหนดรหัสผ่านใหม่สำเร็จ', (tester) async {
      await pump(tester, UserListMode.resetPassword, as: FakeBackend.resetPwd);

      await tester.tap(action('901'));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordDialog), findsOneWidget);
      expect(find.text('ให้หน่วยงาน 901'), findsOneWidget);
      expect(find.text(ResetPasswordDialog.notice), findsOneWidget);

      final newField = inDialog(
        ResetPasswordDialog,
        find.widgetWithText(TextFormField, ResetPasswordDialog.newHint),
      );
      final confirmField = inDialog(
        ResetPasswordDialog,
        find.widgetWithText(TextFormField, ResetPasswordDialog.confirmHint),
      );
      final submit = find.widgetWithText(ElevatedButton, 'บันทึกรหัสผ่านใหม่');

      // ยืนยันไม่ตรง / ไม่ครบเงื่อนไข: ไม่เรียก backend
      backend.clearLog();
      await tester.enterText(newField, 'Newpass@2569x');
      await tester.enterText(confirmField, 'Newpass@2569y');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);

      await tester.enterText(newField, 'newpass2569');
      await tester.enterText(confirmField, 'newpass2569');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text('กรุณาตั้งรหัสผ่านให้ตรงตามเงื่อนไขที่กำหนด'),
        findsOneWidget,
      );
      expect(backend.calls, isEmpty);

      await tester.enterText(newField, 'Newpass@2569x');
      await tester.enterText(confirmField, 'Newpass@2569x');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(backend.bodyOf('POST /api/admin/users/u901/reset-password'), {
        'newPassword': 'Newpass@2569x',
      });
      expect(find.byType(ResetPasswordDialog), findsNothing);
      expect(find.text(FakeBackend.resetDoneMessage), findsOneWidget);
      expect(backend.users['901']!.mustChange, isTrue);
      // รายการโหลดใหม่ เห็นป้ายรอเปลี่ยนรหัสผ่าน
      expect(
        find.descendant(
          of: row('901'),
          matching: find.text('รอเปลี่ยนรหัสผ่าน'),
        ),
        findsOneWidget,
      );
      await settleSnackBar(tester);
    });

    testWidgets('backend ปฏิเสธ: แสดงข้อความในหน้าต่าง ไม่ปิด', (tester) async {
      await pump(tester, UserListMode.resetPassword, as: FakeBackend.resetPwd);
      // ระหว่างที่เปิดรายการอยู่ บัญชี 901 ได้บทบาทสิทธิ์สูงเพิ่ม
      backend.users['901']!.roles = ['USER', 'RESETPWD'];

      await tester.tap(action('901'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, ResetPasswordDialog.newHint),
        'Newpass@2569x',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, ResetPasswordDialog.confirmHint),
        'Newpass@2569x',
      );
      final submit = find.widgetWithText(ElevatedButton, 'บันทึกรหัสผ่านใหม่');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordDialog), findsOneWidget);
      expect(find.text(FakeBackend.resetPrivilegedMessage), findsOneWidget);
      expect(backend.users['901']!.password, FakeBackend.passwordOf('901'));
    });

    testWidgets('ADMIN: กำหนดรหัสผ่านให้บัญชีสิทธิ์สูงได้ ยกเว้นบัญชีตัวเอง', (
      tester,
    ) async {
      await pump(tester, UserListMode.resetPassword, as: FakeBackend.admin);

      expect(enabled(tester, '902'), isTrue);
      expect(enabled(tester, '903'), isTrue);
      expect(enabled(tester, '909'), isFalse);
      expect(find.byTooltip(UserListScreen.privilegedTooltip), findsNothing);
    });
  });

  group('จัดการผู้ใช้', () {
    testWidgets(
      'รายการ: ปุ่มแก้ไขทุกแถว ปุ่มเพิ่มผู้ใช้ และเวลาเข้าใช้ล่าสุดเป็นวันที่ไทย',
      (tester) async {
        await pump(tester, UserListMode.manage, as: FakeBackend.admin);

        expect(find.text(UserListScreen.manageTitle), findsOneWidget);
        expect(find.text('เพิ่มผู้ใช้'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'แก้ไข'), findsNWidgets(10));
        expect(enabled(tester, '909'), isTrue);
        expect(
          find.text('เข้าใช้ล่าสุด 24 มิถุนายน 2568 เวลา 08:30:00 น.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'แก้ไขผู้ใช้: เปลี่ยนชื่อ หน่วยงาน บทบาท แล้วบันทึก — ส่ง PUT ตามสัญญา',
      (tester) async {
        await pump(tester, UserListMode.manage, as: FakeBackend.admin);

        await tester.tap(action('901'));
        await tester.pumpAndSettle();
        expect(backend.calls, contains('GET /api/admin/users/u901'));
        expect(backend.calls, contains('GET /api/admin/roles'));
        expect(backend.calls, contains('GET /api/admin/divs'));
        expect(find.text('แก้ไขผู้ใช้: 901'), findsOneWidget);
        // ชื่อผู้ใช้และรหัสผ่านแก้ในหน้าต่างนี้ไม่ได้
        expect(find.byKey(UserDialog.usernameKey), findsNothing);
        expect(find.byKey(UserDialog.passwordKey), findsNothing);
        // บัญชีไม่ได้ถูกล็อก ไม่มีสวิตช์ปลดล็อก
        expect(find.byKey(UserDialog.lockedKey), findsNothing);
        expect(
          tester
              .widget<FilterChip>(find.byKey(UserDialog.roleKey('USER')))
              .selected,
          isTrue,
        );

        await tester.enterText(
          fieldOf(UserDialog.fullNameKey),
          'หน่วยงานตัวอย่างที่ 1 (แก้ไข)',
        );
        await tester.enterText(
          fieldOf(UserDialog.emailKey),
          'unit901@example.com',
        );
        await tester.tap(find.byKey(UserDialog.roleKey('CENTER_DEPT')));
        await tester.pumpAndSettle();

        // เลือกหน่วยงานใหม่จากรายการที่ค้นหาได้
        await tester.enterText(find.byType(DropdownMenu<String>), '915');
        await tester.pumpAndSettle();
        await tester.tap(find.text('915 หน่วยงานตัวอย่างที่ 15').last);
        await tester.pumpAndSettle();

        final save = find.widgetWithText(ElevatedButton, 'บันทึก');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(backend.bodyOf('PUT /api/admin/users/u901'), {
          'fullName': 'หน่วยงานตัวอย่างที่ 1 (แก้ไข)',
          'email': 'unit901@example.com',
          'div': '915',
          'roles': ['USER', 'CENTER_DEPT'],
          'active': true,
          'locked': false,
        });
        expect(find.byType(UserDialog), findsNothing);
        expect(find.text('บันทึกข้อมูลผู้ใช้ 901 แล้ว'), findsOneWidget);
        expect(
          find.descendant(
            of: row('901'),
            matching: find.text('หน่วยงานส่วนกลาง'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row('901'),
            matching: find.text('หน่วยงาน 915 หน่วยงานตัวอย่างที่ 15'),
          ),
          findsOneWidget,
        );
        await settleSnackBar(tester);
      },
    );

    testWidgets('ระงับบัญชี และปลดล็อกบัญชีที่ถูกล็อก', (tester) async {
      await pump(tester, UserListMode.manage, as: FakeBackend.admin);

      // ปลดล็อก 907
      await tester.tap(action('907'));
      await tester.pumpAndSettle();
      expect(find.byKey(UserDialog.lockedKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(UserDialog.lockedKey));
      await tester.tap(find.byKey(UserDialog.lockedKey));
      await tester.pumpAndSettle();
      var save = find.widgetWithText(ElevatedButton, 'บันทึก');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(backend.bodyOf('PUT /api/admin/users/u907')!['locked'], isFalse);
      expect(backend.users['907']!.locked, isFalse);
      expect(
        find.descendant(of: row('907'), matching: find.text('ล็อก')),
        findsNothing,
      );
      await settleSnackBar(tester);

      // ระงับ 910
      await tester.tap(action('910'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(UserDialog.activeKey));
      await tester.tap(find.byKey(UserDialog.activeKey));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('ระงับแล้ว เข้าสู่ระบบไม่ได้'),
        findsOneWidget,
      );
      save = find.widgetWithText(ElevatedButton, 'บันทึก');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(backend.bodyOf('PUT /api/admin/users/u910')!['active'], isFalse);
      expect(backend.users['910']!.active, isFalse);
      expect(
        find.descendant(of: row('910'), matching: find.text('ระงับ')),
        findsOneWidget,
      );
      await settleSnackBar(tester);
    });

    testWidgets('ระงับบัญชีตัวเอง: backend ปฏิเสธ แสดงข้อความในหน้าต่าง', (
      tester,
    ) async {
      await pump(tester, UserListMode.manage, as: FakeBackend.admin);

      await tester.tap(action('909'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(UserDialog.activeKey));
      await tester.tap(find.byKey(UserDialog.activeKey));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(ElevatedButton, 'บันทึก');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.byType(UserDialog), findsOneWidget);
      expect(find.text(FakeBackend.deactivateSelfMessage), findsOneWidget);
      expect(backend.users['909']!.active, isTrue);
    });

    testWidgets(
      'เพิ่มผู้ใช้: ตรวจช่องก่อนส่ง แล้วสร้างได้ — ส่ง POST ตามสัญญา บัญชีใหม่ต้องเปลี่ยนรหัสผ่าน',
      (tester) async {
        await pump(tester, UserListMode.manage, as: FakeBackend.admin);

        await tester.tap(find.text('เพิ่มผู้ใช้'));
        await tester.pumpAndSettle();
        expect(find.text(UserDialog.createTitle), findsWidgets);
        expect(find.byKey(UserDialog.activeKey), findsNothing);

        final save = find.widgetWithText(ElevatedButton, 'บันทึก');
        // ไม่กรอกอะไรเลย
        backend.clearLog();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text(UserDialog.usernameRuleMessage), findsOneWidget);
        expect(find.text(UserDialog.nameRuleMessage), findsOneWidget);
        expect(find.text(UserDialog.divRequiredMessage), findsOneWidget);
        expect(find.text('กรุณากรอกรหัสผ่านตั้งต้น'), findsOneWidget);
        expect(backend.calls, isEmpty);

        await tester.enterText(fieldOf(UserDialog.usernameKey), '950');
        await tester.enterText(
          fieldOf(UserDialog.fullNameKey),
          'หน่วยงานทดสอบที่ 50',
        );
        await tester.enterText(find.byType(DropdownMenu<String>), '930');
        await tester.pumpAndSettle();
        await tester.tap(find.text('930 หน่วยงานตัวอย่างที่ 30').last);
        await tester.pumpAndSettle();
        await tester.enterText(fieldOf(UserDialog.passwordKey), 'Init@950x');
        await tester.pumpAndSettle();

        // ยังไม่ได้เลือกบทบาท
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text(UserDialog.roleRequiredMessage), findsOneWidget);
        expect(backend.calls, isEmpty);

        await tester.ensureVisible(find.byKey(UserDialog.roleKey('USER')));
        await tester.tap(find.byKey(UserDialog.roleKey('USER')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(backend.bodyOf('POST /api/admin/users'), {
          'username': '950',
          'password': 'Init@950x',
          'fullName': 'หน่วยงานทดสอบที่ 50',
          'email': '',
          'div': '930',
          'roles': ['USER'],
        });
        expect(find.byType(UserDialog), findsNothing);
        expect(find.text('เพิ่มผู้ใช้ 950 แล้ว'), findsOneWidget);
        expect(backend.users['950']!.mustChange, isTrue);
        expect(find.text('ทั้งหมด 27 บัญชี'), findsOneWidget);
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'เพิ่มผู้ใช้: เลือกหน่วยงานแล้วเติมชื่อผู้ใช้ด้วยรหัสหน่วยงาน พิมพ์เองแล้วไม่เขียนทับ ลบแล้วกลับไปเติมตาม',
      (tester) async {
        await pump(tester, UserListMode.manage, as: FakeBackend.admin);
        await tester.tap(find.text('เพิ่มผู้ใช้'));
        await tester.pumpAndSettle();

        String username() => tester
            .widget<TextFormField>(fieldOf(UserDialog.usernameKey))
            .controller!
            .text;
        Future<void> pickDiv(String code, String label) async {
          await tester.enterText(find.byType(DropdownMenu<String>), code);
          await tester.pumpAndSettle();
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }

        expect(username(), '');
        await pickDiv('928', '928 หน่วยงานตัวอย่างที่ 28');
        expect(username(), '928');
        // เปลี่ยนหน่วยงานทั้งที่ยังไม่ได้พิมพ์เอง: ชื่อผู้ใช้ตามไป
        await pickDiv('929', '929 หน่วยงานตัวอย่างที่ 29');
        expect(username(), '929');

        // บัญชีพิเศษ: พิมพ์เองแล้วเลือกหน่วยงานใหม่ไม่เขียนทับ
        await tester.enterText(fieldOf(UserDialog.usernameKey), '9990');
        await pickDiv('930', '930 หน่วยงานตัวอย่างที่ 30');
        expect(username(), '9990');

        // ลบจนว่าง: กลับไปเติมตามหน่วยงานที่เลือก
        await tester.enterText(fieldOf(UserDialog.usernameKey), '');
        await pickDiv('928', '928 หน่วยงานตัวอย่างที่ 28');
        expect(username(), '928');

        // สร้างด้วยชื่อผู้ใช้ที่เติมให้
        await tester.enterText(
          fieldOf(UserDialog.fullNameKey),
          'หน่วยงานตัวอย่างที่ 28',
        );
        await tester.enterText(fieldOf(UserDialog.passwordKey), 'Init@928x');
        await tester.ensureVisible(find.byKey(UserDialog.roleKey('USER')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(UserDialog.roleKey('USER')));
        await tester.pumpAndSettle();
        final save = find.widgetWithText(ElevatedButton, 'บันทึก');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        final body = backend.bodyOf('POST /api/admin/users')!;
        expect(body['username'], '928');
        expect(body['div'], '928');
        expect(backend.users['928']!.div, '928');
        await settleSnackBar(tester);
      },
    );

    testWidgets('ชื่อผู้ใช้: รับเฉพาะตัวเลข 3-10 หลัก ข้อความเตือนเป็นไทย', (
      tester,
    ) async {
      expect(UserDialog.usernamePattern.hasMatch('999'), isTrue);
      expect(UserDialog.usernamePattern.hasMatch('1234567890'), isTrue);
      for (final bad in ['', '12', '12345678901', 'abc', '12a', '1.2']) {
        expect(UserDialog.usernamePattern.hasMatch(bad), isFalse, reason: bad);
      }

      await pump(tester, UserListMode.manage, as: FakeBackend.admin);
      await tester.tap(find.text('เพิ่มผู้ใช้'));
      await tester.pumpAndSettle();
      backend.clearLog();

      // ตัวอักษรพิมพ์ไม่ติด และยาวได้ไม่เกิน 10 หลัก
      await tester.enterText(fieldOf(UserDialog.usernameKey), 'ab1c2');
      await tester.pumpAndSettle();
      final field = fieldOf(UserDialog.usernameKey);
      expect(tester.widget<TextFormField>(field).controller!.text, '12');
      final save = find.widgetWithText(ElevatedButton, 'บันทึก');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text(UserDialog.usernameRuleMessage), findsOneWidget);
      expect(UserDialog.usernameRuleMessage, contains('ตัวเลข 3-10 หลัก'));
      expect(backend.calls, isEmpty);

      await tester.enterText(field, '123456789012345');
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text.length, 10);

      // backend ใช้กติกาเดียวกัน
      await tester.runAsync(() async {
        await expectLater(
          api.createAdminUser(
            const UserAdmin(
              username: 'ab12',
              fullName: 'หน่วยงานทดสอบ',
              div: '910',
              roles: ['USER'],
            ),
            'Init@910x',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.toString(),
              'message',
              FakeBackend.usernameRuleMessage,
            ),
          ),
        );
      });
    });

    testWidgets('เพิ่มผู้ใช้ที่ชื่อซ้ำ / รหัสผ่านไม่ครบเงื่อนไข', (
      tester,
    ) async {
      await pump(tester, UserListMode.manage, as: FakeBackend.admin);
      await tester.tap(find.text('เพิ่มผู้ใช้'));
      await tester.pumpAndSettle();

      await tester.enterText(fieldOf(UserDialog.usernameKey), '901');
      await tester.enterText(fieldOf(UserDialog.fullNameKey), 'หน่วยงานซ้ำ');
      await tester.enterText(find.byType(DropdownMenu<String>), '901');
      await tester.pumpAndSettle();
      await tester.tap(find.text('901 หน่วยงานตัวอย่างที่ 1').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(UserDialog.roleKey('USER')));
      await tester.tap(find.byKey(UserDialog.roleKey('USER')));
      await tester.enterText(fieldOf(UserDialog.passwordKey), 'weakpass');
      await tester.pumpAndSettle();

      final save = find.widgetWithText(ElevatedButton, 'บันทึก');
      backend.clearLog();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('กรุณาตั้งรหัสผ่านให้ตรงตามเงื่อนไขที่กำหนด'),
        findsOneWidget,
      );
      expect(backend.calls, isEmpty);

      await tester.enterText(fieldOf(UserDialog.passwordKey), 'Init@901x');
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(UserDialog), findsOneWidget);
      expect(find.text(FakeBackend.usernameTakenMessage), findsOneWidget);
    });

    testWidgets('กดยกเลิกในหน้าต่างแก้ไข: ไม่บันทึก ไม่โหลดรายการใหม่', (
      tester,
    ) async {
      await pump(tester, UserListMode.manage, as: FakeBackend.admin);
      await tester.tap(action('902'));
      await tester.pumpAndSettle();
      backend.clearLog();

      final cancel = find.widgetWithText(OutlinedButton, 'ยกเลิก');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.byType(UserDialog), findsNothing);
      expect(backend.calls, isEmpty);
    });
  });
}
