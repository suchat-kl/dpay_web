// เทสต์จอแคบ 320 จุด: ทุกหน้าจอและหน้าต่างของระยะที่ 1 ต้องไม่ล้นกรอบ (RenderFlex overflow = เทสต์ล้ม)
// ใช้ฟอนต์จริงของแอป ไม่งั้นฟอนต์ทดสอบกว้างเกินจริง

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/main.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/models/master_data.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/cgd_files_screen.dart';
import 'package:dpay/screens/chapana_import_screen.dart';
import 'package:dpay/screens/debt_entry_screen.dart';
import 'package:dpay/screens/div_status_screen.dart';
import 'package:dpay/screens/loan_check_screen.dart';
import 'package:dpay/screens/report_screen.dart';
import 'package:dpay/screens/saha_import_screen.dart';
import 'package:dpay/utils/file_pick.dart';
import 'package:dpay/widgets/period_progress.dart';
import 'package:dpay/screens/deduct_screen.dart';
import 'package:dpay/screens/loan_screen.dart';
import 'package:dpay/screens/master_screen.dart';
import 'package:dpay/screens/period_jobs_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/widgets/debt_dialogs.dart';
import 'package:dpay/widgets/person_finder.dart';
import 'package:dpay/widgets/sheet_table.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/screens/alert_message_screen.dart';
import 'package:dpay/screens/edit_window_screen.dart';
import 'package:dpay/screens/home_screen.dart';
import 'package:dpay/screens/period_screen.dart';
import 'package:dpay/screens/user_list_screen.dart';
import 'package:dpay/widgets/alert_message_box.dart';
import 'package:dpay/widgets/header.dart';
import 'package:dpay/widgets/change_password_dialog.dart';
import 'package:dpay/widgets/login_dialog.dart';
import 'package:dpay/widgets/reset_password_dialog.dart';
import 'package:dpay/widgets/sidebar_menu.dart';
import 'package:dpay/widgets/thai_date_range_picker.dart';
import 'package:dpay/widgets/user_dialog.dart';
import 'package:universal_html/html.dart' as html;

import 'fake_backend.dart';

const Size _phone = Size(320, 640);

Finder _inMenu(String text) =>
    find.descendant(of: find.byType(SidebarMenu), matching: find.text(text));

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
    // ชื่อหน่วยงานและข้อความแจ้งยาว ๆ ให้เห็นปัญหาล้นกรอบถ้ามี
    backend.divs[1]['divname'] =
        'กองบัญชีตัวอย่างที่มีชื่อยาวเป็นพิเศษเพื่อทดสอบการแสดงผลบนจอแคบ';
    backend.users[FakeBackend.account]!.fullName =
        'กองบัญชีตัวอย่างที่มีชื่อยาวเป็นพิเศษเพื่อทดสอบการแสดงผลบนจอแคบ';
    backend.alertMessage = [
      'ประกาศถึงหน่วยงานทุกแห่ง',
      for (var i = 1; i <= 10; i++)
        'ข้อ $i ${'รายละเอียดการส่งข้อมูลหักหนี้ของงวดนี้ ' * 2}'.trim(),
      'https://example.com/ลิงก์ยาวมากที่ไม่มีช่องว่างให้ตัดบรรทัดเลยสักตัวเดียวในข้อความนี้',
    ].join('\n');
  });

  tearDown(() => auth.logout());

  Future<void> start(WidgetTester tester, {String? as}) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    html.window.localStorage.remove(AppConfig.menuPinnedStorageKey);
    if (as != null) {
      await tester.runAsync(() => auth.login(as, FakeBackend.passwordOf(as)));
    }
    await tester.pumpWidget(DpayApp(authProvider: auth));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
  }

  /// เลื่อนเมนูจนเห็นรายการ (รายการท้ายเมนูยังไม่ถูกสร้างจนกว่าจะเลื่อนถึง)
  Future<void> showMenuItem(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(
      _inMenu(title),
      120,
      scrollable: find
          .descendant(
            of: find.byType(SidebarMenu),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  /// เลื่อนเมนูให้เห็นรายการแล้วกด
  Future<void> tapMenu(WidgetTester tester, String title) async {
    await showMenuItem(tester, title);
    await tester.tap(_inMenu(title));
    await tester.pumpAndSettle();
  }

  /// เลื่อนหน้าจอลงจนสุด ให้ทุกส่วนถูกจัดวางจริง
  Future<void> scrollThrough(WidgetTester tester, Finder scrollable) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
  }

  void expectNoOverflow(WidgetTester tester) {
    expect(tester.takeException(), isNull);
  }

  /// ทุกชิ้นของ [f] อยู่ในความกว้างของจอ
  void expectWithinScreen(WidgetTester tester, Finder f) {
    for (final e in f.evaluate()) {
      final box = e.renderObject! as RenderBox;
      final left = box.localToGlobal(Offset.zero).dx;
      expect(left, greaterThanOrEqualTo(0));
      expect(left + box.size.width, lessThanOrEqualTo(_phone.width));
    }
  }

  testWidgets(
    'หน้าแรกก่อนเข้าสู่ระบบ: ป้ายทดสอบ แถบบน ข้อความแจ้งยาว และปุ่มเข้าสู่ระบบ',
    (tester) async {
      await start(tester);
      expectNoOverflow(tester);
      // จอ 320 จุด: ปุ่มเข้าสู่ระบบที่แถบบนเห็นครบและกดได้ แถบข้อความไม่ล้น ข้อความแจ้งอยู่ถัดลงมา
      final login = find.byKey(CustomHeader.loginButtonKey);
      expect(login, findsOneWidget);
      expectWithinScreen(tester, login);
      expect(login.hitTestable(), findsOneWidget);
      expectWithinScreen(tester, find.byKey(HomeScreen.loginStripKey));
      expect(
        tester.getRect(find.byType(AlertMessageBox)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(HomeScreen.loginStripKey)).bottom,
        ),
      );
      expectWithinScreen(tester, find.byType(AlertMessageBox));
      expectWithinScreen(tester, find.byKey(AlertMessageBox.textKey));
      await scrollThrough(tester, find.byType(SingleChildScrollView).first);
      expectNoOverflow(tester);
    },
  );

  testWidgets('หน้าต่างเข้าสู่ระบบ และข้อความผิดพลาดยาว', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(CustomHeader.loginButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(LoginDialog), findsOneWidget);
    expectNoOverflow(tester);
    expectWithinScreen(tester, find.byType(LoginDialog));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่อผู้ใช้'),
      FakeBackend.lockedUser,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'รหัสผ่าน'),
      FakeBackend.passwordOf(FakeBackend.lockedUser),
    );
    final submit = find.descendant(
      of: find.byType(LoginDialog),
      matching: find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'),
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(FakeBackend.lockedMessage), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets(
    'หน้าแรกหลังเข้าสู่ระบบ: การ์ดหน่วยงาน (ชื่อยาว) งวด และระยะเวลาแก้ไข',
    (tester) async {
      backend.serverTime = DateTime(2025, 8, 1);
      await start(tester, as: FakeBackend.account);
      expectNoOverflow(tester);
      for (final key in [
        HomeScreen.divCardKey,
        HomeScreen.periodCardKey,
        HomeScreen.editWindowCardKey,
      ]) {
        expect(find.byKey(key), findsOneWidget);
        expectWithinScreen(tester, find.byKey(key));
      }
      expect(find.text(HomeScreen.accountAlwaysText), findsOneWidget);
      await scrollThrough(tester, find.byType(SingleChildScrollView).first);
      expectNoOverflow(tester);
    },
  );

  testWidgets('เมนูข้างของฝ่ายบัญชีและผู้ดูแลระบบ และเมนูผู้ใช้บนแถบบน', (
    tester,
  ) async {
    await start(tester, as: FakeBackend.account);
    await openMenu(tester);
    expectNoOverflow(tester);
    expect(_inMenu(SidebarMenu.periodGroupTitle), findsOneWidget);
    expect(_inMenu(SidebarMenu.prepareSectionTitle), findsOneWidget);
    expectWithinScreen(tester, find.byType(SidebarMenu));
    await showMenuItem(tester, SidebarMenu.changePasswordTitle);
    expectNoOverflow(tester);

    // ปิดเมนู แล้วเปิดเมนูผู้ใช้บนแถบบนและข้อมูลผู้ใช้
    await tester.tapAt(const Offset(310, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
    await tester.tap(find.text('ข้อมูลส่วนตัว'));
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
    expectWithinScreen(tester, find.byType(AlertDialog));
  });

  testWidgets('กำหนดเดือนปี รวมหน้าต่างยืนยัน', (tester) async {
    await start(tester, as: FakeBackend.account);
    await openMenu(tester);
    await tapMenu(tester, PeriodScreen.menuTitle);
    expect(find.byType(PeriodScreen), findsOneWidget);
    expectNoOverflow(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('month-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('month-12')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(PeriodScreen.saveButtonKey));
    await tester.pumpAndSettle();
    expectWithinScreen(tester, find.byKey(PeriodScreen.saveButtonKey));
    await tester.tap(find.byKey(PeriodScreen.saveButtonKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('ธันวาคม 2568 ใช่หรือไม่'), findsOneWidget);
    expectNoOverflow(tester);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
  });

  testWidgets('ข้อความแจ้งผู้ใช้งาน: ช่องแก้ไขและตัวอย่างการแสดงผล', (
    tester,
  ) async {
    await start(tester, as: FakeBackend.account);
    await openMenu(tester);
    await tapMenu(tester, AlertMessageScreen.menuTitle);
    expect(find.byType(AlertMessageScreen), findsOneWidget);
    expectNoOverflow(tester);
    expectWithinScreen(tester, find.byKey(AlertMessageScreen.fieldKey));
    await scrollThrough(tester, find.byType(ListView).first);
    expectNoOverflow(tester);
    expectWithinScreen(tester, find.byKey(AlertMessageScreen.previewKey));
  });

  testWidgets(
    'ระยะเวลาแก้ไขข้อมูล: ฟอร์ม คำอธิบาย ข้อความเตือน และปฏิทิน พ.ศ.',
    (tester) async {
      await start(tester, as: FakeBackend.account);
      await openMenu(tester);
      await tapMenu(tester, EditWindowScreen.menuTitle);
      expect(find.byType(EditWindowScreen), findsOneWidget);
      expectNoOverflow(tester);

      final endTime = find.descendant(
        of: find.byKey(EditWindowScreen.endTimeKey),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(endTime);
      await tester.pumpAndSettle();
      await tester.enterText(endTime, '99');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(EditWindowScreen.saveButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditWindowScreen.saveButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(EditWindowScreen.timeFormatMessage), findsOneWidget);
      expectNoOverflow(tester);

      // ปฏิทินช่วงวันที่: จอแคบแสดงเดือนเดียว ทุกมุมมองไม่ล้น
      final range = find.descendant(
        of: find.byKey(EditWindowScreen.rangeKey),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(range);
      await tester.pumpAndSettle();
      await tester.tap(range);
      await tester.pumpAndSettle();
      expect(find.byType(ThaiDateRangePickerDialog), findsOneWidget);
      expect(find.text('มิถุนายน 2568'), findsOneWidget);
      expect(
        find.byKey(ThaiDateRangePickerDialog.secondTitleKey),
        findsNothing,
      );
      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(ThaiDateRangePickerDialog));
      await tester.tap(find.byKey(ThaiDateRangePickerDialog.cancelKey));
      await tester.pumpAndSettle();
      await scrollThrough(tester, find.byType(ListView).first);
      expectNoOverflow(tester);
    },
  );

  testWidgets(
    'กำหนดรหัสผ่านใหม่ให้หน่วยงาน: รายการ ตัวแบ่งหน้า และหน้าต่างตั้งรหัสผ่าน',
    (tester) async {
      await start(tester, as: FakeBackend.admin);
      await openMenu(tester);
      await tapMenu(tester, UserListScreen.resetTitle);
      expect(find.byType(UserListScreen), findsOneWidget);
      expectNoOverflow(tester);
      expectWithinScreen(
        tester,
        find.byKey(UserListScreen.rowKey('u${FakeBackend.account}')),
      );

      final action = find.byKey(UserListScreen.actionKey('u902'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordDialog), findsOneWidget);
      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(ResetPasswordDialog));
      final cancel = find.widgetWithText(OutlinedButton, 'ยกเลิก');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      await scrollThrough(tester, find.byType(ListView).first);
      expectNoOverflow(tester);
    },
  );

  testWidgets('จัดการผู้ใช้: รายการ หน้าต่างแก้ไข และหน้าต่างเพิ่มผู้ใช้', (
    tester,
  ) async {
    await start(tester, as: FakeBackend.admin);
    await openMenu(tester);
    await tapMenu(tester, UserListScreen.manageTitle);
    expectNoOverflow(tester);

    // แก้ไขบัญชีที่ถูกล็อก (มีสวิตช์ครบสองตัว)
    final action = find.byKey(UserListScreen.actionKey('u907'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(UserDialog), findsOneWidget);
    expect(find.byKey(UserDialog.lockedKey), findsOneWidget);
    expectNoOverflow(tester);
    expectWithinScreen(tester, find.byType(UserDialog));
    var cancel = find.widgetWithText(OutlinedButton, 'ยกเลิก');
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    // กลับไปบนสุดของรายการ (ปุ่มเพิ่มผู้ใช้อยู่เหนือช่องค้นหา)
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มผู้ใช้'));
    await tester.pumpAndSettle();
    expect(find.byKey(UserDialog.passwordKey), findsOneWidget);
    expectNoOverflow(tester);
    // กดบันทึกทั้งที่ว่าง: ข้อความเตือนทุกช่องขึ้นพร้อมกัน
    final save = find.widgetWithText(ElevatedButton, 'บันทึก');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text(UserDialog.usernameRuleMessage), findsOneWidget);
    expectNoOverflow(tester);
    cancel = find.widgetWithText(OutlinedButton, 'ยกเลิก');
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
  });

  testWidgets('เปลี่ยนรหัสผ่านจากเมนู และหน้าต่างบังคับเปลี่ยนรหัสผ่าน', (
    tester,
  ) async {
    await start(tester, as: FakeBackend.user);
    await openMenu(tester);
    await tapMenu(tester, SidebarMenu.changePasswordTitle);
    expect(find.byType(ChangePasswordDialog), findsOneWidget);
    expectNoOverflow(tester);
    expectWithinScreen(tester, find.byType(ChangePasswordDialog));
    final submit = find.widgetWithText(
      ElevatedButton,
      ChangePasswordDialog.title,
    );
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
    final cancel = find.widgetWithText(OutlinedButton, 'ยกเลิก');
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordDialog), findsNothing);
    expectNoOverflow(tester);
  });

  testWidgets('บัญชีที่ต้องเปลี่ยนรหัสผ่าน: หน้าต่างบังคับและหน้าแรกไม่ล้น', (
    tester,
  ) async {
    await start(tester, as: FakeBackend.newbie);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordDialog), findsOneWidget);
    expect(find.text(ChangePasswordDialog.forcedSubtitle), findsOneWidget);
    expectNoOverflow(tester);
    expectWithinScreen(tester, find.byType(ChangePasswordDialog));
  });

  group('หน้าจอของระยะที่ 2', () {
    final api = ApiService();

    /// เปิดหน้าจอ [screen] ตรง ๆ บนจอ 320 จุด หลังเข้าสู่ระบบด้วยบัญชี [as]
    Future<void> open(
      WidgetTester tester,
      Widget screen, {
      String as = FakeBackend.account,
    }) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await auth.login(as, FakeBackend.passwordOf(as));
        await SettingsProvider().load();
      });
      // ล้างหน้าจอเดิมก่อน ไม่งั้นเปิดหน้าชนิดเดิมซ้ำในเทสต์เดียวกันจะได้ State เก่า
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: screen),
      );
      await tester.pumpAndSettle();
    }

    /// เลื่อนหน้าจอลงจนถึง [f] (ส่วนท้ายของหน้ายังไม่ถูกสร้างจนกว่าจะเลื่อนถึง) แล้วเลื่อนแนวนอนให้เห็นด้วย
    Future<void> reveal(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
    }

    Future<void> findPerson(WidgetTester tester, String idcard) async {
      await tester.enterText(find.byKey(PersonFinder.idcardKey), idcard);
      await tester.tap(find.byKey(PersonFinder.idcardButtonKey));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'ข้อมูลหลัก: ตารางแก้ในแถวกว้างเลื่อนแนวนอนได้ เพิ่มแถวและข้อความผิดพลาดใต้แถวไม่ล้น',
      (tester) async {
        await open(
          tester,
          MasterScreen(apiService: api, resource: MasterResource.banks),
        );
        expectNoOverflow(tester);
        // ตารางกว้างกว่าจอ: อยู่ในพื้นที่เลื่อนแนวนอน
        await reveal(tester, find.byType(SheetCard));
        expect(
          tester.getSize(find.byType(SheetCard)).width,
          greaterThan(_phone.width),
        );
        await tester.drag(find.byType(SheetScroll), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await scrollThrough(tester, find.byType(ListView).first);
        expectNoOverflow(tester);

        final add = find.text(SheetButton.addLabel);
        await reveal(tester, add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        // แถวว่าง: กดบันทึกแล้วข้อความผิดพลาดยาวอยู่ใต้แถว ไม่ล้นจอ
        final save = find.byKey(MasterScreen.saveKey);
        await reveal(tester, save);
        await tester.pumpAndSettle();
        expectWithinScreen(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byKey(MasterScreen.errorKey(3)), findsOneWidget);
        expectNoOverflow(tester);
        await scrollThrough(tester, find.byType(ListView).first);
        expectNoOverflow(tester);
      },
    );

    testWidgets('สาขาธนาคาร (เลือกธนาคารชื่อยาว) และหน่วยงาน', (tester) async {
      backend.p2.masters['banks']!.first['bank_name'] =
          'ธนาคารตัวอย่างที่มีชื่อยาวเป็นพิเศษเพื่อทดสอบการแสดงผลบนจอแคบ';
      await open(
        tester,
        MasterScreen(apiService: api, resource: MasterResource.branches),
      );
      expectNoOverflow(tester);
      await tester.tap(find.byKey(MasterScreen.bankFilterKey));
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      await tester.tap(find.textContaining('006 ').last);
      await tester.pumpAndSettle();
      expectNoOverflow(tester);

      await open(
        tester,
        MasterScreen(apiService: api, resource: MasterResource.divs),
      );
      expectNoOverflow(tester);
      await scrollThrough(tester, find.byType(ListView).first);
      expectNoOverflow(tester);
    });

    testWidgets('นำเข้าข้อมูลบุคลากร และผลการนำเข้า', (tester) async {
      await open(tester, DpisImportScreen(apiService: api));
      expectNoOverflow(tester);
      final run = find.byKey(DpisImportScreen.runKey);
      await reveal(tester, run);
      await tester.pumpAndSettle();
      expectWithinScreen(tester, run);
      await tester.tap(run);
      await tester.pumpAndSettle();
      expect(find.text('ผลการนำเข้าครั้งนี้'), findsOneWidget);
      expectNoOverflow(tester);
      await scrollThrough(tester, find.byType(ListView).first);
      expectNoOverflow(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('เตรียมข้อมูลงวด และหน้าต่างยืนยันก่อนล้าง', (tester) async {
      await open(tester, PreparePeriodScreen(apiService: api));
      expectNoOverflow(tester);
      final run = find.byKey(PreparePeriodScreen.runKey);
      await reveal(tester, run);
      await tester.pumpAndSettle();
      expectWithinScreen(tester, run);
      await tester.tap(run);
      await tester.pumpAndSettle();
      expect(find.text('ยืนยันการเตรียมงวดใหม่'), findsOneWidget);
      expectNoOverflow(tester);
      final check = find.byKey(PreparePeriodScreen.confirmCheckKey);
      await reveal(tester, check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });

    testWidgets(
      'บันทึกข้อมูล (หน่วยงานทั่วไป): ตารางเลื่อนแนวนอน แก้ยอด บันทึก ประวัติ และตัวเลือกงวด',
      (tester) async {
        await open(
          tester,
          DebtEntryScreen(apiService: api),
          as: FakeBackend.user,
        );
        expectNoOverflow(tester);
        await reveal(tester, find.byType(SheetCard));
        expect(
          tester.getSize(find.byType(SheetCard)).width,
          greaterThan(_phone.width),
        );
        expectWithinScreen(tester, find.byKey(DebtEntryScreen.saveKey));

        // เลื่อนตารางไปทางขวา แล้วแก้ยอด
        final id = 'debt0001'.padRight(24, '0');
        final cell = find.descendant(
          of: find.byKey(DebtEntryScreen.cellKey(id, 'c40303')),
          matching: find.byType(TextFormField),
        );
        await reveal(tester, cell);
        await tester.pumpAndSettle();
        await tester.enterText(cell, '100');
        await tester.pumpAndSettle();
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsOneWidget);
        expectNoOverflow(tester);
        await tester.tap(find.byKey(DebtEntryScreen.saveKey));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        final audit = find.byKey(DebtEntryScreen.auditKey(id));
        await reveal(tester, audit);
        await tester.pumpAndSettle();
        await tester.tap(audit);
        await tester.pumpAndSettle();
        expect(find.byType(DebtAuditDialog), findsOneWidget);
        expectNoOverflow(tester);
        expectWithinScreen(tester, find.byType(DebtAuditDialog));
        await tester.tap(find.byTooltip('ปิด').last);
        await tester.pumpAndSettle();

        await scrollThrough(tester, find.byType(CustomScrollView));
        expectNoOverflow(tester);
        // เลื่อนลงสุดแล้วหัวตารางยังตรึงอยู่บนจอ และยอดรวมอยู่ในแถบล่าง
        expect(find.byType(SheetPinnedHeader), findsOneWidget);
        final headTop = tester.getTopLeft(find.text('ที่')).dy;
        expect(headTop, inInclusiveRange(0, _phone.height - 72));
        // ตารางถูกเลื่อนไปทางขวาแล้ว หัวตารางเลื่อนแนวนอนตามตาราง (คอลัมน์แรกพ้นขอบซ้ายไปด้วยกัน)
        expect(tester.getTopLeft(find.text('ที่')).dx, lessThan(0));
        expect(
          find.byKey(DebtEntryScreen.summaryKey('c40302')),
          findsOneWidget,
        );

        // ตัวเลือกงวด และแถบงวดย้อนหลังพร้อมปุ่มกลับ
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
        await tester.pumpAndSettle();
        final change = find.byKey(DebtEntryScreen.periodButtonKey);
        await reveal(tester, change);
        await tester.pumpAndSettle();
        await tester.tap(change);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        final june = find.byKey(const ValueKey('month-6'));
        await reveal(tester, june);
        await tester.pumpAndSettle();
        await tester.tap(june);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        final past = find.byKey(DebtEntryScreen.pastNoticeKey);
        await reveal(tester, past);
        await tester.pumpAndSettle();
        expectWithinScreen(tester, past);
        expectWithinScreen(
          tester,
          find.byKey(DebtEntryScreen.backToCurrentKey),
        );
        await scrollThrough(tester, find.byType(CustomScrollView));
        expectNoOverflow(tester);
      },
    );

    testWidgets(
      'บันทึกข้อมูล: ช่วงแก้ไขปิด (แถบอ่านอย่างเดียว) และฝ่ายบัญชี (ตัวเลือกหน่วยงาน)',
      (tester) async {
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await open(
          tester,
          DebtEntryScreen(apiService: api),
          as: FakeBackend.user,
        );
        expectNoOverflow(tester);
        await reveal(tester, find.byKey(DebtEntryScreen.readOnlyKey));
        expect(find.byKey(DebtEntryScreen.readOnlyKey), findsOneWidget);
        expectNoOverflow(tester);
        expectWithinScreen(tester, find.byKey(DebtEntryScreen.readOnlyKey));
        await tester.runAsync(auth.logout);

        await open(tester, DebtEntryScreen(apiService: api));
        expectNoOverflow(tester);
        await scrollThrough(tester, find.byType(CustomScrollView));
        expectNoOverflow(tester);
      },
    );

    testWidgets(
      'ระยะที่ 3: นำเข้าสหกรณ์/ฌาปนกิจ ไฟล์ส่งกรมบัญชีกลาง ตรวจยอดเงินกู้ รายงานส่งธนาคาร รายงาน — จอ 320 ไม่ล้น',
      (tester) async {
        backend.p3
          ..chapanaRows = 32
          ..sahaRows['G'] = 10;
        final screens = <Widget>[
          SahaImportScreen(
            apiService: api,
            pickFile: () async => PickedFile('saha.txt', Uint8List(1060)),
          ),
          ChapanaImportScreen(apiService: api),
          CgdFilesScreen(apiService: api),
          LoanCheckScreen(apiService: api),
          BankReportScreen(apiService: api),
          ReportScreen(apiService: api),
          DivStatusScreen(apiService: api),
        ];
        for (final screen in screens) {
          await open(tester, screen);
          expectNoOverflow(tester);
          await scrollThrough(tester, find.byType(ListView).first);
          expectNoOverflow(tester);
        }

        // สหกรณ์: ผลตรวจไฟล์และรายการที่มีปัญหา (ข้อความยาว) ไม่ล้น
        await open(tester, screens.first);
        await reveal(tester, find.byKey(SahaImportScreen.pickKey));
        await tester.tap(find.byKey(SahaImportScreen.pickKey));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(SahaImportScreen.checkKey));
        await tester.tap(find.byKey(SahaImportScreen.checkKey));
        await tester.pumpAndSettle();
        expect(find.byKey(SahaImportScreen.checkResultKey), findsOneWidget);
        expectNoOverflow(tester);
        await scrollThrough(tester, find.byType(ListView).first);
        expectNoOverflow(tester);

        // รายงานส่งธนาคาร: แถบยอดไม่ตรงพร้อมปุ่มไปหน้าตรวจ อยู่ในจอ
        await open(tester, screens[4]);
        final ghb = find.descendant(
          of: find.byKey(BankReportScreen.runKey('GHB')),
          matching: find.byType(ElevatedButton),
        );
        await reveal(tester, ghb);
        await tester.tap(ghb);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(BankReportScreen.goCheckKey));
        expectNoOverflow(tester);
        expectWithinScreen(tester, find.byKey(BankReportScreen.mismatchKey));
        expectWithinScreen(tester, find.byKey(BankReportScreen.goCheckKey));
      },
    );

    testWidgets('ความคืบหน้าของงวดบนหน้าแรก: จอ 320 ไม่ล้น', (tester) async {
      await open(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: PeriodProgress(apiService: api)),
        ),
      );
      expectNoOverflow(tester);
      await scrollThrough(tester, find.byType(SingleChildScrollView).first);
      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byKey(PeriodProgress.stepKey(11)));
    });

    testWidgets('กบข/กสจ. สหกรณ์และภาษี: ตัวค้นหา ผลค้นชื่อ และฟอร์มทั้งหน้า', (
      tester,
    ) async {
      await open(tester, DeductScreen(apiService: api));
      expectNoOverflow(tester);
      await tester.enterText(find.byKey(PersonFinder.nameKey), 'สมมุติ');
      await tester.tap(find.byKey(PersonFinder.nameButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(PersonFinder.resultKey(0)), findsOneWidget);
      expectNoOverflow(tester);

      await findPerson(tester, fakeIdCard(1));
      expect(find.byKey(DeductScreen.personKey), findsOneWidget);
      expectNoOverflow(tester);
      await scrollThrough(tester, find.byType(ListView).first);
      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byKey(DeductScreen.saveKey));
    });

    testWidgets(
      'เลขที่บัญชีเงินกู้: ตารางเลื่อนแนวนอน เพิ่มแถว และข้อความเตือน',
      (tester) async {
        await open(tester, LoanScreen(apiService: api));
        await findPerson(tester, fakeIdCard(1));
        expectNoOverflow(tester);
        await reveal(tester, find.byType(SheetCard));
        expect(
          tester.getSize(find.byType(SheetCard)).width,
          greaterThan(_phone.width),
        );
        final add = find.text(SheetButton.addLabel);
        await reveal(tester, add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        final save = find.byKey(LoanScreen.saveKey);
        await reveal(tester, save);
        await tester.pumpAndSettle();
        expectWithinScreen(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.textContaining('แถวที่ 3'), findsOneWidget);
        expectNoOverflow(tester);
      },
    );
  });
}
