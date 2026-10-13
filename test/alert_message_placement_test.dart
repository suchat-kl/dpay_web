// "ข้อความแจ้งผู้ใช้งาน" แสดงที่หน้าแรกหน้าเดียว (ผู้ใช้สั่ง): หน้าแรกมีกล่องข้อความหนึ่งกล่องทั้งก่อนและหลังเข้าสู่ระบบ
// หน้าอื่น หน้าต่างเข้าสู่ระบบ และเมนู ไม่มี — ยกเว้นหน้าแก้ไขข้อความของฝ่ายบัญชี (ตัวอย่างการแสดงผลเป็นส่วนของการแก้ไข)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/main.dart';
import 'package:dpay/models/master_data.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/alert_message_screen.dart';
import 'package:dpay/screens/cgd_files_screen.dart';
import 'package:dpay/screens/chapana_import_screen.dart';
import 'package:dpay/screens/coming_soon_screen.dart';
import 'package:dpay/screens/debt_entry_screen.dart';
import 'package:dpay/screens/deduct_screen.dart';
import 'package:dpay/screens/div_status_screen.dart';
import 'package:dpay/screens/edit_window_screen.dart';
import 'package:dpay/screens/home_screen.dart';
import 'package:dpay/screens/loan_check_screen.dart';
import 'package:dpay/screens/loan_screen.dart';
import 'package:dpay/screens/master_screen.dart';
import 'package:dpay/screens/period_jobs_screen.dart';
import 'package:dpay/screens/period_screen.dart';
import 'package:dpay/screens/report_screen.dart';
import 'package:dpay/screens/saha_import_screen.dart';
import 'package:dpay/screens/user_list_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/widgets/alert_message_box.dart';
import 'package:dpay/widgets/header.dart';
import 'package:dpay/widgets/login_dialog.dart';
import 'package:dpay/widgets/period_progress.dart';
import 'package:dpay/widgets/sidebar_menu.dart';
import 'package:universal_html/html.dart' as html;

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  const message = 'ข้อความแจ้งสำหรับทดสอบตำแหน่งการแสดงผล 2568';

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();

  setUp(() async {
    backend = await installFakeBackend();
    backend.alertMessage = message;
    auth = AuthProvider();
  });

  tearDown(() => auth.logout());

  /// ข้อความแจ้ง (กล่อง หัวข้อ หรือเนื้อความ) ต้องไม่อยู่บนจอ
  void expectNoAlert() {
    expect(find.byType(AlertMessageBox), findsNothing);
    expect(find.text(AlertMessageBox.title), findsNothing);
    expect(find.textContaining(message), findsNothing);
  }

  /// หน้าแรก: กล่องเดียว เนื้อความครั้งเดียว
  void expectOneAlert() {
    expect(find.byType(AlertMessageBox), findsOneWidget);
    expect(find.text(AlertMessageBox.title), findsOneWidget);
    expect(find.textContaining(message), findsOneWidget);
  }

  Future<void> startApp(WidgetTester tester, {String? as}) async {
    tester.view.physicalSize = const Size(1400, 2600);
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

  group('หน้าแรก: กล่องข้อความหนึ่งกล่อง', () {
    testWidgets('ก่อนเข้าสู่ระบบ', (tester) async {
      await startApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expectOneAlert();
      expect(backend.count('GET /api/alert-message'), 1);
    });

    for (final account in [
      FakeBackend.user,
      FakeBackend.account,
      FakeBackend.admin,
    ]) {
      testWidgets('หลังเข้าสู่ระบบ (บัญชี $account)', (tester) async {
        await startApp(tester, as: account);
        expectOneAlert();
        // การ์ดความคืบหน้าของงวด (ฝ่ายบัญชี) ไม่มีข้อความแจ้งซ้ำ
        expect(
          find.descendant(
            of: find.byType(PeriodProgress),
            matching: find.textContaining(message),
          ),
          findsNothing,
        );
      });
    }
  });

  group('ที่อื่นไม่มีข้อความแจ้ง', () {
    testWidgets('หน้าต่างเข้าสู่ระบบ และเมนูข้าง', (tester) async {
      await startApp(tester);
      await tester.tap(find.byKey(CustomHeader.loginButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(LoginDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LoginDialog),
          matching: find.byType(AlertMessageBox),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(LoginDialog),
          matching: find.textContaining(message),
        ),
        findsNothing,
      );
      // ทั้งจอยังมีกล่องเดียว (ของหน้าแรกที่อยู่ใต้หน้าต่าง)
      expect(find.byType(AlertMessageBox), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      await openMenu(tester);
      expect(
        find.descendant(
          of: find.byType(SidebarMenu),
          matching: find.textContaining(message),
        ),
        findsNothing,
      );
    });

    testWidgets('เปิดหน้าจอจากเมนูในแอปจริง: บันทึกข้อมูล และรายงาน', (
      tester,
    ) async {
      await startApp(tester, as: FakeBackend.user);
      expectOneAlert();
      for (final item in [
        (SidebarMenu.debtEntryTitle, DebtEntryScreen),
        (SidebarMenu.reportTitle, ReportScreen),
      ]) {
        await openMenu(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SidebarMenu),
            matching: find.text(item.$1),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(item.$2), findsOneWidget);
        expectNoAlert();
        await tester.tap(find.byTooltip('ปิด'));
        await tester.pumpAndSettle();
        // กลับหน้าแรก: ยังมีกล่องเดียว
        expectOneAlert();
      }
    });

    final screens = <String, Widget Function()>{
      'บันทึกข้อมูล': () => DebtEntryScreen(apiService: api),
      'รายงาน': () => ReportScreen(apiService: api),
      'รายงานส่งธนาคาร': () => BankReportScreen(apiService: api),
      'สถานะการบันทึกของหน่วยงาน': () => DivStatusScreen(apiService: api),
      'ความคืบหน้าของงวด': () => Scaffold(
        body: SingleChildScrollView(child: PeriodProgress(apiService: api)),
      ),
      'กำหนดเดือนปี': () => PeriodScreen(apiService: api),
      'ระยะเวลาแก้ไขข้อมูล': () => EditWindowScreen(apiService: api),
      'นำเข้าข้อมูลบุคลากร': () => DpisImportScreen(apiService: api),
      'เตรียมข้อมูลงวด': () => PreparePeriodScreen(apiService: api),
      'นำเข้าข้อมูลฌาปนกิจ': () => ChapanaImportScreen(apiService: api),
      'นำเข้าข้อมูลสหกรณ์': () => SahaImportScreen(apiService: api),
      'ตรวจยอดเงินกู้': () => LoanCheckScreen(apiService: api),
      'ไฟล์ส่งกรมบัญชีกลาง': () => CgdFilesScreen(apiService: api),
      'ทะเบียน กบข/กสจ': () => DeductScreen(apiService: api),
      'เลขที่บัญชีเงินกู้': () => LoanScreen(apiService: api),
      'ข้อมูลหลัก (ธนาคาร)': () =>
          MasterScreen(apiService: api, resource: MasterResource.banks),
      'กำหนดรหัสผ่านใหม่ให้หน่วยงาน': () =>
          UserListScreen(apiService: api, mode: UserListMode.resetPassword),
      'หน้ากำลังพัฒนา': () => const ComingSoonScreen(
        title: 'รายงานฌาปนกิจ-สลิป',
        group: 'ฌาปนกิจและสหกรณ์',
      ),
    };

    testWidgets(
      'ทุกหน้าจอของระบบ (${screens.length} หน้า): ไม่มีกล่องหรือเนื้อความของข้อความแจ้ง',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.runAsync(() async {
          await auth.login(
            FakeBackend.account,
            FakeBackend.passwordOf(FakeBackend.account),
          );
          // โหลดข้อความแจ้งไว้ใน SettingsProvider แล้ว (เหมือนผู้ใช้ผ่านหน้าแรกมาก่อน)
          await SettingsProvider().load();
          await SettingsProvider().loadAlertMessage();
        });
        expect(SettingsProvider().alertMessage, message);
        for (final e in screens.entries) {
          await tester.pumpWidget(const SizedBox.shrink());
          backend.clearLog();
          await tester.pumpWidget(
            MaterialApp(theme: AppTheme.lightTheme, home: e.value()),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertMessageBox), findsNothing, reason: e.key);
          expect(find.text(AlertMessageBox.title), findsNothing, reason: e.key);
          expect(find.textContaining(message), findsNothing, reason: e.key);
          // หน้าอื่นไม่ได้ไปโหลดข้อความแจ้งมาด้วย
          expect(
            backend.calls,
            isNot(contains('GET /api/alert-message')),
            reason: e.key,
          );
        }
      },
    );

    testWidgets(
      'ข้อยกเว้นเดียว: หน้าแก้ไขข้อความของฝ่ายบัญชี มีตัวอย่างการแสดงผลหนึ่งกล่อง',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.runAsync(
          () => auth.login(
            FakeBackend.account,
            FakeBackend.passwordOf(FakeBackend.account),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AlertMessageScreen(apiService: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertMessageBox), findsOneWidget);
      },
    );
  });
}
