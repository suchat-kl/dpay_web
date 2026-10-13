// เทสต์หน้า "รายงานฌาปนกิจ-สลิป" (ACCOUNT): เทียบยอดที่ต้องการหักกับยอดที่หักได้จริงในสลิป
// สรุป ตารางผู้ที่หักไม่ได้ รายงาน PDF งวดที่ยังไม่ได้นำเข้า และข้อผิดพลาดของระบบสลิปภาษี — ข้อมูลทั้งหมดเป็นค่าสมมุติ

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/chapana_import_screen.dart';
import 'package:dpay/screens/chapana_slip_screen.dart';
import 'package:dpay/screens/report_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/services/work_api.dart';
import 'package:dpay/utils/file_download.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/screen_parts.dart';
import 'package:dpay/widgets/work_parts.dart';

import 'fake_backend.dart';

class _Saver extends FileSaver {
  final List<DownloadedFile> files = [];
  final List<String> opened = [];

  @override
  SavedFile save(DownloadedFile file) {
    files.add(file);
    return _Saved(file.fileName, this);
  }
}

class _Saved implements SavedFile {
  @override
  final String fileName;
  final _Saver owner;
  _Saved(this.fileName, this.owner);

  @override
  void open() => owner.opened.add(fileName);

  @override
  void dispose() {}
}

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  late _Saver saver;
  final api = ApiService();

  setUp(() async {
    backend = await installFakeBackend();
    // นำเข้าฌาปนกิจของงวดปัจจุบันแล้ว (ข้าราชการ 29 ลูกจ้างประจำ 3)
    backend.p3.chapanaRows = 32;
    auth = AuthProvider();
    saver = _Saver();
    FileSaver.instance = saver;
  });

  tearDown(() async {
    FileSaver.instance = const BrowserFileSaver();
    await auth.logout();
  });

  Future<void> pump(
    WidgetTester tester, {
    String as = FakeBackend.account,
  }) async {
    tester.view.physicalSize = const Size(1500, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await auth.login(as, FakeBackend.passwordOf(as));
      await SettingsProvider().load();
    });
    backend.clearLog();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChapanaSlipScreen(apiService: api),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> run(WidgetTester tester) =>
      tapKey(tester, ChapanaSlipScreen.runKey);

  Finder reportButton() => find.descendant(
    of: find.byKey(ChapanaSlipScreen.reportKey),
    matching: find.byType(ElevatedButton),
  );
  int rowCount() => find
      .byWidgetPredicate((w) => '${w.key}'.contains('slip-row-'))
      .evaluate()
      .length;

  testWidgets(
    'ไม่เรียกระบบสลิปเองตอนเปิด กดตรวจสอบแล้วได้สรุปและตารางผู้ที่หักไม่ได้ (แบ่งหน้า เลขบัตรปิดบางส่วน จ่ายให้กับหลายบรรทัด)',
    (tester) async {
      await pump(tester);
      expect(backend.calls, isEmpty);
      expect(find.byKey(ChapanaSlipScreen.summaryKey), findsNothing);
      expect(find.byKey(ChapanaSlipScreen.reportKey), findsNothing);

      await run(tester);
      expect(backend.calls, ['GET /api/chapana/slip-check']);
      expect(backend.queryOf('GET /api/chapana/slip-check'), {'type': 'G'});
      expect(find.byKey(ChapanaSlipScreen.busyKey), findsNothing);

      final summary = find.byKey(ChapanaSlipScreen.summaryKey);
      for (final text in [
        '29 คน · 3,480.00 บาท',
        '17 คน',
        '3 คน',
        '9 คน',
        '12 คน · 1,440.00 บาท',
      ]) {
        expect(
          find.descendant(of: summary, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining(
            'ผลการเทียบของข้าราชการ งวด กรกฎาคม 2568',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(ChapanaSlipScreen.allPaidKey), findsNothing);
      // คำอธิบายความหมายของยอด
      expect(find.textContaining('เงินที่ต้องการหัก'), findsWidgets);
      expect(find.textContaining('เงินที่หักได้จริง'), findsWidgets);
      expect(find.textContaining('เงินไม่พอให้หัก'), findsOneWidget);

      // ตาราง: หน้าแรก 10 จาก 12 คน เรียงตามที่ backend ส่ง
      expect(rowCount(), 10);
      expect(find.text('ทั้งหมด 12 คน'), findsOneWidget);
      final first = find.byKey(ChapanaSlipScreen.rowKey(0));
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(find.byKey(ChapanaSlipScreen.rowKey(1))).dy),
      );
      for (final text in [
        '80001',
        'นายสมมุติหัก01 ตัวอย่าง',
        '120.00',
        '100.00',
        ChapanaSlipScreen.mismatchLabel,
        ChapanaSlipScreen.activeLabel,
      ]) {
        expect(
          find.descendant(of: first, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      // จ่ายให้กับ: สองบรรทัดตามที่ backend ส่ง
      expect(
        find.descendant(
          of: first,
          matching: find.text(
            '80001 นายสมมุติหัก01 ตัวอย่าง\n80991 นางสมมุติคู่สมรส ตัวอย่าง',
          ),
        ),
        findsOneWidget,
      );
      // เลขบัตรปิดบางส่วน ไม่แสดงเต็ม
      expect(find.textContaining(fakeIdCard(301)), findsNothing);
      expect(
        find.descendant(of: first, matching: find.textContaining('xxxxx')),
        findsOneWidget,
      );
      // คนที่ 4: ไม่มีในสลิป ยอดในสลิป 0 และเกษียณ
      final fourth = find.byKey(ChapanaSlipScreen.rowKey(3));
      expect(
        find.descendant(
          of: fourth,
          matching: find.text(ChapanaSlipScreen.notInSlipLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fourth, matching: find.text('0.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: fourth,
          matching: find.text(ChapanaSlipScreen.retiredLabel),
        ),
        findsOneWidget,
      );

      // หน้า 2 (ฝั่งหน้าเว็บ ไม่เรียก backend) — คนสุดท้าย DPIS ไม่มีสถานะบุคคล
      backend.clearLog();
      await tester.ensureVisible(find.text('2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      expect(rowCount(), 2);
      expect(find.byKey(ChapanaSlipScreen.rowKey(11)), findsOneWidget);
      expect(backend.calls, isEmpty);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('50 แถว'), findsNothing);
      await tester.tap(find.text('20 แถว').last);
      await tester.pumpAndSettle();
      expect(rowCount(), 12);
    },
  );

  testWidgets('รายงาน PDF ผู้ที่ไม่ถูกหัก: ดาวน์โหลดและเปิดดู', (tester) async {
    await pump(tester);
    await run(tester);
    await tester.ensureVisible(reportButton());
    await tester.pumpAndSettle();
    await tester.tap(reportButton());
    await tester.pumpAndSettle();
    expect(backend.queryOf('GET /api/reports/chapana-not-pay'), {'type': 'G'});
    expect(saver.files.single.fileName, 'rep9-072568-G.pdf');
    expect(saver.files.single.isPdf, isTrue);
    await tester.tap(find.text(DownloadButtons.openLabel));
    expect(saver.opened, ['rep9-072568-G.pdf']);
  });

  testWidgets(
    'เปลี่ยนประเภทต้องกดตรวจสอบใหม่ ทุกคนหักได้ครบ: สถานะสำเร็จ ไม่มีตาราง ปุ่มรายงานกดไม่ได้',
    (tester) async {
      await pump(tester);
      await run(tester);
      await tapKey(tester, ChapanaSlipScreen.typeKey('E'));
      // ผลเดิมถูกล้าง ยังไม่เรียกใหม่จนกว่าจะกดตรวจสอบ
      expect(find.byKey(ChapanaSlipScreen.summaryKey), findsNothing);
      expect(backend.count('GET /api/chapana/slip-check'), 1);

      await run(tester);
      expect(backend.queryOf('GET /api/chapana/slip-check'), {'type': 'E'});
      expect(find.byKey(ChapanaSlipScreen.allPaidKey), findsOneWidget);
      expect(find.text(ChapanaSlipScreen.allPaidText), findsOneWidget);
      expect(find.byKey(ChapanaSlipScreen.tableKey), findsNothing);
      expect(rowCount(), 0);
      expect(find.text('3 คน · 360.00 บาท'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(reportButton()).onPressed, isNull);
    },
  );

  testWidgets(
    'ยังไม่ได้นำเข้าฌาปนกิจของงวด (chapana_rows 0): แจ้งพร้อมลิงก์ไปหน้านำเข้า / งวดย้อนหลังส่ง month/year',
    (tester) async {
      backend.p3.chapanaRows = 0;
      await pump(tester);
      await run(tester);
      expect(find.byKey(ChapanaSlipScreen.noChapanaKey), findsOneWidget);
      expect(find.text(ChapanaSlipScreen.noChapanaText), findsOneWidget);
      expect(find.byKey(ChapanaSlipScreen.summaryKey), findsNothing);
      expect(find.byKey(ChapanaSlipScreen.allPaidKey), findsNothing);
      expect(find.byKey(ChapanaSlipScreen.reportKey), findsNothing);

      await tapKey(tester, ChapanaSlipScreen.goImportKey);
      expect(find.byType(ChapanaImportScreen), findsOneWidget);
      await tester.tap(find.byTooltip('ปิด').last);
      await tester.pumpAndSettle();

      await tapKey(tester, PeriodPicker.buttonKey);
      await tapKey(tester, const ValueKey('month-6'));
      expect(find.byKey(ChapanaSlipScreen.noChapanaKey), findsNothing);
      await run(tester);
      expect(backend.queryOf('GET /api/chapana/slip-check'), {
        'type': 'G',
        'month': '06',
        'year': '2568',
      });
    },
  );

  testWidgets(
    'ข้อผิดพลาดเฉพาะ: ยังไม่ได้ตั้งค่า (503) ระบบสลิปใช้ไม่ได้ (502) DPIS ล่ม (502) — ข้อความที่เข้าใจได้ กดใหม่ได้',
    (tester) async {
      await pump(tester);
      for (final c in {
        ErrorCodes.slipApiNotConfigured: ChapanaSlipScreen.notConfiguredText,
        ErrorCodes.slipApiError: ChapanaSlipScreen.slipErrorText,
        ErrorCodes.dpisError: ChapanaSlipScreen.dpisErrorText,
      }.entries) {
        backend.p3.slipError = c.key;
        await run(tester);
        expect(find.text(c.value), findsOneWidget, reason: c.key);
        expect(find.byKey(ChapanaSlipScreen.summaryKey), findsNothing);
        expect(
          tester
              .widget<PrimaryActionButton>(find.byKey(ChapanaSlipScreen.runKey))
              .onPressed,
          isNotNull,
        );
      }
      backend.p3.slipError = null;
      await run(tester);
      expect(find.text(ChapanaSlipScreen.dpisErrorText), findsNothing);
      expect(find.byKey(ChapanaSlipScreen.summaryKey), findsOneWidget);

      // ระบบสลิปล่มตอนออกรายงาน
      backend.p3.slipError = ErrorCodes.slipApiError;
      await tester.ensureVisible(reportButton());
      await tester.pumpAndSettle();
      await tester.tap(reportButton());
      await tester.pumpAndSettle();
      expect(find.text(ChapanaSlipScreen.slipErrorText), findsOneWidget);
      expect(saver.files, isEmpty);
    },
  );

  testWidgets('ไม่ใช่ฝ่ายบัญชี: backend ปฏิเสธ แสดงข้อความ', (tester) async {
    await pump(tester, as: FakeBackend.user);
    await run(tester);
    expect(find.byType(NoticeBar), findsOneWidget);
    expect(find.byKey(ChapanaSlipScreen.summaryKey), findsNothing);
  });

  test('เส้น API: 503 อ่าน code ได้ รายงานไม่มีผู้ไม่ถูกหัก = 404', () async {
    await auth.login(
      FakeBackend.account,
      FakeBackend.passwordOf(FakeBackend.account),
    );
    backend.p3.slipError = ErrorCodes.slipApiNotConfigured;
    await expectLater(
      api.getChapanaSlipCheck(type: 'G'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.code, 'code', ErrorCodes.slipApiNotConfigured),
      ),
    );
    backend.p3.slipError = null;
    await expectLater(
      api.downloadChapanaNotPay(type: 'E'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 404)),
    );
    expect(ReportScreen.noDataText, isNotEmpty);
  });
}
