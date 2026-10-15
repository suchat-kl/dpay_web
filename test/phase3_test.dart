// เทสต์ระยะที่ 3: นำเข้าสหกรณ์/ฌาปนกิจ ไฟล์ส่งกรมบัญชีกลาง ตรวจยอดเงินกู้ รายงานส่งธนาคาร รายงาน PDF
// ความคืบหน้าของงวด และตัวช่วยดาวน์โหลดไฟล์ (ใช้ตัวจำลองแทนการแตะ DOM ของเบราว์เซอร์)
// ข้อมูลทั้งหมดเป็นค่าสมมุติ

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/models/debt.dart';
import 'package:dpay/models/period.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/cgd_files_screen.dart';
import 'package:dpay/screens/chapana_import_screen.dart';
import 'package:dpay/screens/div_status_screen.dart';
import 'package:dpay/screens/debt_entry_screen.dart';
import 'package:dpay/screens/deduct_screen.dart';
import 'package:dpay/screens/loan_check_screen.dart';
import 'package:dpay/screens/report_screen.dart';
import 'package:dpay/screens/saha_import_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/services/work_api.dart';
import 'package:dpay/utils/file_download.dart';
import 'package:dpay/utils/file_pick.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/debt_dialogs.dart';
import 'package:dpay/widgets/period_progress.dart';
import 'package:dpay/widgets/person_finder.dart';
import 'package:dpay/widgets/screen_parts.dart';
import 'package:dpay/widgets/sheet_table.dart';
import 'package:dpay/widgets/work_parts.dart';

import 'fake_backend.dart';

/// ตัวส่งไฟล์จำลอง: เก็บไฟล์ที่ "ดาวน์โหลด" และชื่อไฟล์ที่ถูกเปิดดู/ทิ้ง
class FakeSaver extends FileSaver {
  final List<DownloadedFile> files = [];
  final List<String> opened = [];
  final List<String> disposed = [];

  @override
  SavedFile save(DownloadedFile file) {
    files.add(file);
    return _FakeSaved(file.fileName, this);
  }
}

class _FakeSaved implements SavedFile {
  @override
  final String fileName;
  final FakeSaver owner;

  _FakeSaved(this.fileName, this.owner);

  @override
  void open() => owner.opened.add(fileName);

  @override
  void dispose() => owner.disposed.add(fileName);
}

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  late FakeSaver saver;
  final api = ApiService();

  Future<void> signIn(String username) =>
      auth.login(username, FakeBackend.passwordOf(username));

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
    saver = FakeSaver();
    FileSaver.instance = saver;
  });

  tearDown(() async {
    FileSaver.instance = const BrowserFileSaver();
    await auth.logout();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String as = FakeBackend.account,
  }) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await signIn(as);
      await SettingsProvider().load();
    });
    backend.clearLog();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: screen),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  /// กดปุ่มดาวน์โหลดของ [DownloadButtons] ที่มีคีย์ [key]
  Future<void> download(WidgetTester tester, Key key) async {
    final button = find.descendant(
      of: find.byKey(key),
      matching: find.byType(ElevatedButton),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> pickPast(WidgetTester tester, int month) async {
    await tapKey(tester, PeriodPicker.buttonKey);
    await tapKey(tester, ValueKey('month-$month'));
  }

  group('ตัวช่วยดาวน์โหลดไฟล์ (เส้น API)', () {
    test('ชื่อไฟล์จาก Content-Disposition', () {
      expect(
        WorkApi.fileNameOf('attachment; filename="G-40302-2569-10.txt"', 'x'),
        'G-40302-2569-10.txt',
      );
      expect(
        WorkApi.fileNameOf('attachment; filename=rep1-901-G.pdf', 'x'),
        'rep1-901-G.pdf',
      );
      expect(
        WorkApi.fileNameOf(
          "attachment; filename*=UTF-8''rep%20a.pdf; filename=\"b.pdf\"",
          'x',
        ),
        'rep a.pdf',
      );
      expect(WorkApi.fileNameOf(null, 'fallback.pdf'), 'fallback.pdf');
      expect(WorkApi.fileNameOf('inline', 'fallback.pdf'), 'fallback.pdf');
    });

    test(
      'ไฟล์ข้อความ TIS-620 ได้ไบต์เท่าเดิมทุกไบต์ พร้อมชื่อและชนิด',
      () async {
        await signIn(FakeBackend.account);
        final f = await api.downloadCgdFile('G', '40302', name: 'x.txt');
        expect(f.bytes, Uint8List.fromList([0xA1, 0xA2, 13, 10]));
        expect(f.fileName, 'G-40302-2568-07.txt');
        expect(f.mime, 'text/plain');
        expect(f.isPdf, isFalse);
        // งวดย้อนหลัง: month/year อยู่ใน query (ไม่มีข้อมูลบุคคลใน URL)
        final old = await api.downloadCgdFile(
          'E',
          'Sum',
          name: 'x.txt',
          period: Period.of(6, 2568),
        );
        expect(old.fileName, 'E-Sum-2568-06.txt');
        expect(backend.queryOf('GET /api/cgd-files/E/Sum'), {
          'month': '06',
          'year': '2568',
        });
      },
    );

    test(
      'ไม่มีข้อมูลของรายงาน: 404 เป็น JSON ข้อผิดพลาด อ่าน code/message ได้',
      () async {
        await signIn(FakeBackend.account);
        backend.p3.reportMissing.add('rep1');
        await expectLater(
          api.downloadReport('rep1', type: 'G', div: '901'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.code, 'code', ErrorCodes.notFound)
                .having(
                  (e) => e.message,
                  'message',
                  FakePhase3.reportMissingMessage,
                ),
          ),
        );
        final ok = await api.downloadReport('rep2', div: '901');
        expect(ok.isPdf, isTrue);
        expect(ok.fileName, 'rep2-901-GE.pdf');
      },
    );

    test(
      'สิทธิ์: งานของฝ่ายบัญชีใช้ไม่ได้กับบทบาทอื่น รายงานตามขอบเขตหน่วยงาน',
      () async {
        await signIn(FakeBackend.user);
        for (final call in <Future<Object?> Function()>[
          api.getSahaSummary,
          api.getChapanaSummary,
          api.getCgdFiles,
          api.getLoanCheck,
          api.syncLoanAmounts,
          api.getMissingAccounts,
          () => api.downloadCgdZip(),
          () => api.downloadBankReport('AIA'),
          () => api.downloadReport('rep2-all-dept'),
          () => api.downloadReport('rep10'),
        ]) {
          await expectLater(
            call(),
            throwsA(
              isA<ApiException>().having(
                (e) => e.code,
                'code',
                ErrorCodes.forbidden,
              ),
            ),
          );
        }
        // รายงานของหน่วยงานตัวเองออกได้ หน่วยงานอื่น/ทุกหน่วยงานไม่ได้
        expect(
          (await api.downloadReport('rep1', type: 'G', div: '901')).fileName,
          'rep1-901-G.pdf',
        );
        for (final call in [
          () => api.downloadReport('rep1', type: 'G', div: '902'),
          () => api.downloadReport('debt-change', bank: 'GHB', div: '*'),
        ]) {
          await expectLater(
            call(),
            throwsA(
              isA<ApiException>().having(
                (e) => e.isDivForbidden,
                'isDivForbidden',
                isTrue,
              ),
            ),
          );
        }
        await auth.logout();
        await signIn(FakeBackend.account);
        expect(
          (await api.downloadReport(
            'debt-change',
            bank: 'GHB',
            div: '*',
          )).fileName,
          'debtChange-all-GHB.pdf',
        );
      },
    );
  });

  group('ไฟล์ส่งกรมบัญชีกลาง', () {
    testWidgets(
      'ตาราง 14 ไฟล์ จำนวนคน/ยอด เตือนอักขระที่ TIS-620 ไม่มี ดาวน์โหลดรายไฟล์และ zip',
      (tester) async {
        await pump(tester, CgdFilesScreen(apiService: api));
        expect(backend.calls, ['GET /api/cgd-files']);
        expect(backend.queryOf('GET /api/cgd-files'), isEmpty);
        for (final t in ['G', 'E']) {
          for (final c in FakePhase3.cgdCodes) {
            expect(find.byKey(CgdFilesScreen.rowKey(t, c)), findsOneWidget);
          }
        }
        expect(find.text('G-40302-2568-07.txt'), findsOneWidget);
        expect(find.text('4,500.50'), findsNWidgets(10));
        // ไฟล์ว่างของรหัสที่ไม่มีใครมียอด และคำเตือนอักขระ
        expect(find.text(CgdFilesScreen.emptyFileText), findsNWidgets(2));
        expect(
          find.descendant(
            of: find.byKey(CgdFilesScreen.rowKey('E', '41100')),
            matching: find.text(CgdFilesScreen.unmappableText(2)),
          ),
          findsOneWidget,
        );
        // ไม่มีเมนู/ปุ่ม "สร้างไฟล์" แยกเหมือนระบบเดิม
        expect(find.textContaining('สร้างไฟล์'), findsNothing);

        await tapKey(tester, CgdFilesScreen.fileKey('G', '40302'));
        expect(backend.calls.last, 'GET /api/cgd-files/G/40302');
        expect(saver.files.single.fileName, 'G-40302-2568-07.txt');
        expect(saver.files.single.bytes, [0xA1, 0xA2, 13, 10]);

        await download(tester, CgdFilesScreen.zipAllKey);
        expect(backend.queryOf('GET /api/cgd-files/zip'), isEmpty);
        expect(saver.files.last.fileName, 'CGD-2568-07.zip');
        expect(saver.files.last.mime, 'application/zip');
        expect(find.textContaining('CGD-2568-07.zip'), findsOneWidget);

        await tapKey(tester, CgdFilesScreen.zipKey('E'));
        expect(backend.queryOf('GET /api/cgd-files/zip'), {'type': 'E'});
        expect(saver.files.last.fileName, 'CGD-E-2568-07.zip');
      },
    );

    testWidgets(
      'งวดย้อนหลัง: ส่ง month/year ทั้งรายการและไฟล์ ไฟล์เดิมถูกทิ้ง',
      (tester) async {
        await pump(tester, CgdFilesScreen(apiService: api));
        await download(tester, CgdFilesScreen.zipAllKey);
        await pickPast(tester, 6);
        expect(backend.queryOf('GET /api/cgd-files'), {
          'month': '06',
          'year': '2568',
        });
        expect(saver.disposed, ['CGD-2568-07.zip']);
        expect(find.text('E-Sum-2568-06.txt'), findsOneWidget);
        await tapKey(tester, CgdFilesScreen.zipKey('G'));
        expect(backend.queryOf('GET /api/cgd-files/zip'), {
          'month': '06',
          'year': '2568',
          'type': 'G',
        });
      },
    );
  });

  group('ตรวจยอดเงินกู้กับหนี้เดือน', () {
    testWidgets(
      'ผลต่อธนาคาร + รายคนที่ไม่ตรง ปรับปรุงหนี้ธนาคาร (ยืนยันก่อน) ไฟล์หนี้ที่ต้องแก้ไข และคนที่ไม่มีเลขบัญชี',
      (tester) async {
        await pump(tester, LoanCheckScreen(apiService: api));
        expect(backend.calls, [
          'GET /api/loans/check',
          'GET /api/loans/missing-accounts',
        ]);
        expect(
          find.descendant(
            of: find.byKey(LoanCheckScreen.statusKey),
            matching: find.textContaining('มี 3 รายการ'),
          ),
          findsOneWidget,
        );
        final ghb = find.byKey(LoanCheckScreen.bankKey('GHB'));
        expect(
          find.descendant(of: ghb, matching: find.text('ไม่ตรง 2')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: ghb, matching: find.text('นายสมมุติ01 ตัวอย่าง')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: ghb, matching: find.text('1,500.50')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(LoanCheckScreen.bankKey('GSB')),
            matching: find.text('ตรง'),
          ),
          findsOneWidget,
        );
        // เลขบัตรเต็มไม่แสดงบนจอ
        expect(find.textContaining(fakeIdCard(1)), findsNothing);

        // คนที่ไม่มีเลขบัญชี
        final missing = find.byKey(LoanCheckScreen.missingKey);
        expect(
          find.descendant(
            of: missing,
            matching: find.text('นางสมมุติ30 ทดสอบ'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: missing, matching: find.text('GSB')),
          findsOneWidget,
        );

        // ปรับปรุงหนี้ธนาคาร: ถามก่อน ยกเลิก = ไม่ส่ง
        backend.clearLog();
        await tapKey(tester, LoanCheckScreen.syncKey);
        expect(find.text(LoanCheckScreen.syncQuestion), findsOneWidget);
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
        expect(backend.calls, isEmpty);

        await tapKey(tester, LoanCheckScreen.syncKey);
        await tester.tap(find.text(LoanCheckScreen.syncLabel).last);
        await tester.pumpAndSettle();
        expect(backend.calls.first, 'POST /api/loans/sync-amounts');
        expect(backend.calls, contains('GET /api/loans/check'));
        final result = find.byKey(LoanCheckScreen.syncResultKey);
        expect(
          find.descendant(
            of: result,
            matching: find.textContaining(
              'ตั้งยอดให้เท่าหนี้เดือนแล้ว 2 รายการ',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: result,
            matching: find.textContaining('เหลือ 1 รายการที่มีหลายบัญชี'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: ghb, matching: find.text('ไม่ตรง 1')),
          findsOneWidget,
        );
        await settleSnackBar(tester);

        await download(tester, LoanCheckScreen.mismatchFileKey);
        expect(saver.files.last.fileName, 'Bank-2568-07.txt');
        expect(saver.files.last.bytes, [0xA1, 13, 10]);
        await download(tester, LoanCheckScreen.missingFileKey);
        expect(saver.files.last.fileName, 'Acc-2568-07.txt');
      },
    );

    testWidgets(
      'ยอดตรงทั้งหมด: แจ้งผ่าน ปุ่มปรับปรุงกดไม่ได้ / งวดย้อนหลังไม่มีปุ่มปรับปรุง',
      (tester) async {
        backend.p3
          ..loanMismatches = []
          ..missingAccounts = [];
        await pump(
          tester,
          LoanCheckScreen(apiService: api, missingFirst: true),
        );
        expect(find.text(LoanCheckScreen.okText), findsOneWidget);
        expect(find.text(LoanCheckScreen.noMissingText), findsOneWidget);
        expect(
          tester
              .widget<PrimaryActionButton>(find.byKey(LoanCheckScreen.syncKey))
              .onPressed,
          isNull,
        );
        // เปิดจากเมนู "รายชื่อบุคคลที่ไม่มีเลขบัญชีธนาคาร": ส่วนนั้นอยู่ก่อนผลตรวจ
        expect(find.text(LoanCheckScreen.missingMenuTitle), findsNWidgets(2));
        expect(
          tester.getTopLeft(find.byKey(LoanCheckScreen.missingKey)).dy,
          lessThan(tester.getTopLeft(find.byKey(LoanCheckScreen.statusKey)).dy),
        );

        await pickPast(tester, 6);
        expect(backend.queryOf('GET /api/loans/check'), {
          'month': '06',
          'year': '2568',
        });
        expect(find.byKey(LoanCheckScreen.syncKey), findsNothing);
        expect(find.text(LoanCheckScreen.pastSyncText), findsOneWidget);
      },
    );
  });

  group('รายงานส่งธนาคาร', () {
    testWidgets(
      'AIA ออกได้เลย ธอส. ยอดยังไม่ตรง: แสดง details และพาไปหน้าตรวจยอดเงินกู้ แก้แล้วออกได้',
      (tester) async {
        await pump(tester, BankReportScreen(apiService: api));
        expect(backend.calls, isEmpty);

        await download(tester, BankReportScreen.runKey('AIA'));
        expect(backend.calls, ['GET /api/reports/bank/AIA']);
        expect(saver.files.single.fileName, 'rep-072568-AIA.xlsx');
        // ไฟล์/รายงานเป็นงานยาว: บนเว็บ connectTimeout คือเวลารอ backend จนได้คำตอบ ต้องไม่ใช่ 30 วินาทีตั้งต้น
        // (15 ต.ค. 2569 ธอส. ขึ้น "หมดเวลาในการเชื่อมต่อ")
        expect(backend.connectTimeouts.single, const Duration(minutes: 15));
        expect(find.byKey(BankReportScreen.mismatchKey), findsNothing);

        await download(tester, BankReportScreen.runKey('GHB'));
        final notice = find.byKey(BankReportScreen.mismatchKey);
        expect(notice, findsOneWidget);
        expect(
          find.descendant(
            of: notice,
            matching: find.textContaining(FakePhase3.mismatchMessage),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: notice,
            matching: find.textContaining(
              'ไม่ตรง 2 รายการ (ธนาคารอาคารสงเคราะห์ 2 รายการ)',
            ),
          ),
          findsOneWidget,
        );
        expect(saver.files, hasLength(1));

        await tapKey(tester, BankReportScreen.goCheckKey);
        expect(find.byType(LoanCheckScreen), findsOneWidget);
        expect(backend.calls, contains('GET /api/loans/check'));
        await tester.tap(find.byTooltip('ปิด').last);
        await tester.pumpAndSettle();

        backend.p3.loanMismatches = [];
        await download(tester, BankReportScreen.runKey('GHB'));
        expect(find.byKey(BankReportScreen.mismatchKey), findsNothing);
        expect(saver.files.last.fileName, 'rep-072568-GHB.xlsx');

        // ไม่มีข้อมูล
        backend.p3.reportMissing.add('bank-KTB');
        await download(tester, BankReportScreen.runKey('KTB'));
        expect(find.text(ReportScreen.noDataText), findsOneWidget);
        expect(saver.files, hasLength(2));
      },
    );
  });

  group('รายงาน', () {
    Finder runButton(String key) => find.descendant(
      of: find.byKey(ReportScreen.runKey(key)),
      matching: find.byType(ElevatedButton),
    );

    testWidgets(
      'หน่วยงานส่วนกลาง (เลือกได้หลายหน่วยงาน): ออกรายงานสรุปหน่วยงานประจำเดือนได้ตามระบบเดิม แต่ไม่เห็นรายงานอื่นของฝ่ายบัญชี',
      (tester) async {
        await pump(
          tester,
          ReportScreen(apiService: api),
          as: FakeBackend.centerDept,
        );
        expect(find.text('รายงานทั้งกรม'), findsOneWidget);
        expect(
          find.byKey(ReportScreen.runKey('rep2-all-dept')),
          findsOneWidget,
        );
        expect(find.byKey(ReportScreen.runKey('rep10')), findsNothing);
        await download(tester, ReportScreen.runKey('rep2-all-dept'));
        expect(backend.calls, contains('GET /api/reports/rep2-all-dept'));
        expect(find.textContaining('ไม่มีสิทธิ์'), findsNothing);
      },
    );

    testWidgets(
      'หน่วยงานทั่วไป: รายงานของหน่วยงานตัวเอง ออก PDF เปิดดูได้ ไม่มีข้อมูล = ข้อความใต้รายงาน',
      (tester) async {
        await pump(tester, ReportScreen(apiService: api), as: FakeBackend.user);
        // ไม่มีตัวเลือกทุกหน่วยงาน และไม่มีรายงานทั้งกรมของฝ่ายบัญชี
        expect(find.byKey(ReportScreen.allDivsKey), findsNothing);
        expect(find.byKey(ReportScreen.runKey('rep2-all-dept')), findsNothing);
        expect(find.byKey(ReportScreen.runKey('rep10')), findsNothing);
        for (final title in [
          'รายละเอียดการหักเงิน',
          'สรุปจำนวนเงินหัก',
          'รายละเอียดข้อมูลธนาคาร กบข/กสจ ฌาปนกิจ สหกรณ์',
          'รายชื่อบุคคลเพิ่มลดประจำเดือน',
          'เงินหนี้เปลี่ยน ธอส.',
          'เงินหนี้เปลี่ยน ออมสิน',
          'เงินหนี้เปลี่ยน กรุงไทย',
        ]) {
          expect(find.text(title), findsOneWidget, reason: title);
        }
        backend.clearLog();

        await download(tester, ReportScreen.runKey('rep1'));
        expect(backend.calls, ['GET /api/reports/rep1']);
        expect(backend.queryOf('GET /api/reports/rep1'), {
          'type': 'G',
          'div': '901',
        });
        expect(saver.files.single.fileName, 'rep1-901-G.pdf');
        expect(saver.files.single.isPdf, isTrue);
        await tester.tap(
          find.descendant(
            of: find.byKey(ReportScreen.runKey('rep1')),
            matching: find.text(DownloadButtons.openLabel),
          ),
        );
        expect(saver.opened, ['rep1-901-G.pdf']);

        // รายงานที่ไม่แยกประเภท: ไม่ส่ง type
        await download(tester, ReportScreen.runKey('rep2'));
        expect(backend.queryOf('GET /api/reports/rep2'), {'div': '901'});
        await download(tester, ReportScreen.runKey('debt-change-GSB'));
        expect(backend.queryOf('GET /api/reports/debt-change'), {
          'div': '901',
          'bank': 'GSB',
        });
        expect(saver.files.last.fileName, 'debtChange-901-GSB.pdf');

        // ไม่มีข้อมูล (404): ข้อความใต้รายงาน ไม่มีไฟล์
        backend.p3.reportMissing.add('rep3');
        final before = saver.files.length;
        await download(tester, ReportScreen.runKey('rep3'));
        expect(
          find.descendant(
            of: find.byKey(ReportScreen.noteKey('rep3')),
            matching: find.text(ReportScreen.noDataText),
          ),
          findsOneWidget,
        );
        expect(saver.files, hasLength(before));

        // DPIS ล่มตอนออกรายงานเพิ่มลด
        backend.p2.dpisFails = true;
        await download(tester, ReportScreen.runKey('rep4'));
        expect(
          find.descendant(
            of: find.byKey(ReportScreen.noteKey('rep4')),
            matching: find.textContaining(FakeBackend.dpisErrorMessage),
          ),
          findsOneWidget,
        );

        // เปลี่ยนประเภท: ไฟล์และข้อความเดิมถูกล้าง แล้วส่ง type ใหม่
        await tapKey(tester, ReportScreen.typeKey('E'));
        expect(find.byKey(ReportScreen.noteKey('rep3')), findsNothing);
        expect(find.text(DownloadButtons.openLabel), findsNothing);
        expect(saver.disposed, contains('rep1-901-G.pdf'));
        await download(tester, ReportScreen.runKey('rep1'));
        expect(backend.queryOf('GET /api/reports/rep1')!['type'], 'E');
      },
    );

    testWidgets(
      'ฝ่ายบัญชี (ขอบเขต ALL): รายงานทั้งกรม ทุกหน่วยงานใช้กับเงินหนี้เปลี่ยนเท่านั้น และงวดย้อนหลัง',
      (tester) async {
        await pump(tester, ReportScreen(apiService: api));
        expect(find.byKey(ReportScreen.allDivsKey), findsOneWidget);
        expect(
          find.text('รายละเอียดหักเงินสรุปหน่วยงานประจำเดือน'),
          findsOneWidget,
        );
        expect(find.text('ผู้เกษียณในรายการฌาปนกิจ'), findsOneWidget);

        await download(tester, ReportScreen.runKey('rep2-all-dept'));
        expect(backend.queryOf('GET /api/reports/rep2-all-dept'), isEmpty);
        expect(saver.files.last.fileName, 'rep2AllDept-GE.pdf');
        await download(tester, ReportScreen.runKey('rep10'));
        expect(saver.files.last.fileName, 'rep10-072568.pdf');

        await tapKey(tester, ReportScreen.allDivsKey);
        await download(tester, ReportScreen.runKey('debt-change-GHB'));
        expect(backend.queryOf('GET /api/reports/debt-change'), {
          'div': '*',
          'bank': 'GHB',
        });
        expect(saver.files.last.fileName, 'debtChange-all-GHB.pdf');
        // รายงานของหน่วยงานยังใช้หน่วยงานที่เลือก
        await download(tester, ReportScreen.runKey('rep1'));
        expect(backend.queryOf('GET /api/reports/rep1')!['div'], '902');

        await pickPast(tester, 6);
        await download(tester, ReportScreen.runKey('rep2'));
        expect(backend.queryOf('GET /api/reports/rep2'), {
          'month': '06',
          'year': '2568',
          'div': '902',
        });
      },
    );

    testWidgets(
      'กันกดซ้ำ: ระหว่างสร้างไฟล์ปุ่มกดไม่ได้และแสดงสถานะกำลังสร้าง',
      (tester) async {
        var taps = 0;
        Widget buttons({bool busy = false, bool blocked = false}) =>
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: DownloadButtons(
                  label: ReportScreen.runLabel,
                  busy: busy,
                  blocked: blocked,
                  onDownload: () => taps++,
                ),
              ),
            );
        await tester.pumpWidget(buttons());
        await tester.tap(find.byType(ElevatedButton));
        expect(taps, 1);

        await tester.pumpWidget(buttons(busy: true));
        expect(find.text(DownloadButtons.busyLabel), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
        expect(taps, 1);

        await tester.pumpWidget(buttons(blocked: true));
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );
        expect(runButton('rep1'), findsNothing);
      },
    );
  });

  group('นำเข้าข้อมูลฌาปนกิจ', () {
    testWidgets(
      'ยังไม่ได้นำเข้า → ดึงจาก DPIS → สรุป ผู้เกษียณ รายงาน rep10 → ดึงซ้ำต้องยืนยันแทนที่',
      (tester) async {
        await pump(tester, ChapanaImportScreen(apiService: api));
        expect(backend.calls, [
          'GET /api/chapana/summary',
          'GET /api/chapana/retired',
        ]);
        expect(find.text(ChapanaImportScreen.emptyText), findsOneWidget);
        expect(find.text(ChapanaImportScreen.noRetiredText), findsOneWidget);

        await tapKey(tester, ChapanaImportScreen.runKey);
        expect(backend.bodyOf('POST /api/chapana/import'), {
          'confirm_replace': false,
        });
        final result = find.byKey(ChapanaImportScreen.resultKey);
        expect(
          find.descendant(of: result, matching: find.text('35 รายการ')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: result, matching: find.text('32 คน')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(ChapanaImportScreen.summaryKey),
            matching: find.text('นำเข้าแล้ว'),
          ),
          findsOneWidget,
        );
        final retired = find.byKey(ChapanaImportScreen.retiredKey);
        expect(
          find.descendant(
            of: retired,
            matching: find.text('นายสมมุติเกษียณ01 ตัวอย่าง'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(fakeIdCard(201)), findsNothing);
        await settleSnackBar(tester);

        await download(tester, ChapanaImportScreen.reportKey);
        expect(saver.files.single.fileName, 'rep10-072568.pdf');

        // ดึงซ้ำ: ถามก่อนแทนที่ ยกเลิก = ไม่ส่ง
        backend.clearLog();
        await tapKey(tester, ChapanaImportScreen.runKey);
        expect(
          find.textContaining('มีข้อมูลฌาปนกิจแล้ว 32 รายการ'),
          findsOneWidget,
        );
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
        expect(backend.calls, isEmpty);
        await tapKey(tester, ChapanaImportScreen.runKey);
        await tester.tap(find.text('แทนที่ข้อมูลเดิม').last);
        await tester.pumpAndSettle();
        expect(backend.bodyOf('POST /api/chapana/import'), {
          'confirm_replace': true,
        });
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'backend ตอบ CONFIRM_REQUIRED (มีคนนำเข้าระหว่างที่เปิดหน้าอยู่): ถามแล้วส่งใหม่พร้อมคำยืนยัน',
      (tester) async {
        await pump(tester, ChapanaImportScreen(apiService: api));
        backend.p3.chapanaRows = 20;
        backend.clearLog();
        await tapKey(tester, ChapanaImportScreen.runKey);
        expect(backend.count('POST /api/chapana/import'), 1);
        expect(
          find.textContaining('มีข้อมูลฌาปนกิจแล้ว 20 รายการ'),
          findsOneWidget,
        );
        await tester.tap(find.text('แทนที่ข้อมูลเดิม').last);
        await tester.pumpAndSettle();
        expect(backend.count('POST /api/chapana/import'), 2);
        expect(backend.bodyOf('POST /api/chapana/import'), {
          'confirm_replace': true,
        });
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'งวดยังไม่เตรียม / DPIS ล่ม: ข้อความพร้อมคำแนะนำ ข้อมูลเดิมอยู่ครบ',
      (tester) async {
        backend.p2.periodReady = false;
        await pump(tester, ChapanaImportScreen(apiService: api));
        await tapKey(tester, ChapanaImportScreen.runKey);
        expect(
          find.textContaining(ChapanaImportScreen.notReadyHint),
          findsOneWidget,
        );
        backend.p2
          ..periodReady = true
          ..dpisFails = true;
        await tapKey(tester, ChapanaImportScreen.runKey);
        expect(
          find.textContaining(ChapanaImportScreen.dpisErrorHint),
          findsOneWidget,
        );
        expect(backend.p3.chapanaRows, 0);
      },
    );
  });

  group('นำเข้าข้อมูลสหกรณ์', () {
    PickedFile file(String name, {int rows = 10}) =>
        PickedFile(name, Uint8List(106 * rows));

    Future<void> open(WidgetTester tester, PickedFile? Function() next) => pump(
      tester,
      SahaImportScreen(apiService: api, pickFile: () async => next()),
    );

    bool enabled(WidgetTester tester, Key key) =>
        tester.widget<PrimaryActionButton>(find.byKey(key)).onPressed != null;

    testWidgets(
      'เลือกไฟล์ → ตรวจก่อน (dry_run) แสดงสรุปและปัญหาแยกชนิด → นำเข้า → นำเข้าซ้ำบอกจำนวนที่จะถูกแทน',
      (tester) async {
        await open(tester, () => file('coopG.dat'));
        // เปิดหน้าแล้วถามด้วยว่ามีการนำเข้าค้างอยู่ไหม (ไม่มี = ไม่ถามซ้ำ)
        expect(backend.calls.toSet(), {
          'GET /api/saha/summary',
          'GET /api/saha/unresolved',
          'GET /api/saha/import-status',
        });
        expect(backend.calls, hasLength(3));
        expect(find.byKey(SahaImportScreen.jobKey), findsNothing);
        expect(find.text(SahaImportScreen.emptySummaryText), findsOneWidget);
        expect(enabled(tester, SahaImportScreen.checkKey), isFalse);
        expect(enabled(tester, SahaImportScreen.importKey), isFalse);

        await tapKey(tester, SahaImportScreen.pickKey);
        expect(find.text('coopG.dat (1,060 ไบต์)'), findsOneWidget);
        expect(enabled(tester, SahaImportScreen.checkKey), isTrue);
        expect(enabled(tester, SahaImportScreen.importKey), isFalse);

        backend.clearLog();
        await tapKey(tester, SahaImportScreen.checkKey);
        expect(backend.calls, ['POST /api/saha/import']);
        expect(backend.bodyOf('POST /api/saha/import'), {
          'type': 'G',
          'dry_run': 'true',
          'confirm_replace': 'false',
          'file': 'coopG.dat',
          'file_size': 1060,
        });
        // ตรวจอย่างเดียว ยังไม่บันทึก
        expect(backend.p3.sahaRows['G'], 0);
        final facts = find.byKey(SahaImportScreen.checkResultKey);
        expect(
          find.descendant(of: facts, matching: find.text('10 แถว')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: facts, matching: find.text('10,002.50 บาท')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: facts, matching: find.text('6 รายการ')),
          findsOneWidget,
        );
        // ชื่อใกล้เคียง: บอกว่าจับคู่กับใคร ให้ตรวจทาน
        expect(
          find.textContaining('จับคู่กับ นายสมมุติใกล้ เคียงชื่อ'),
          findsOneWidget,
        );
        for (final kind in SahaImportScreen.problemKinds.entries) {
          final box = find.byKey(SahaImportScreen.problemKey(kind.key));
          expect(box, findsOneWidget, reason: kind.key);
          expect(
            find.descendant(of: box, matching: find.text(kind.value.$1)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(
            of: find.byKey(SahaImportScreen.problemKey('MULTIPLE_MATCH')),
            matching: find.textContaining('นายสมมุติซ้ำ ตัวอย่าง'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('พบ 2 คน'), findsOneWidget);
        // ปนอีกประเภทส่วนน้อย: มีชื่อภาษาไทยของชนิดและบอกว่าเคยจับคู่เป็นประเภทใด
        expect(
          find.descendant(
            of: find.byKey(SahaImportScreen.problemKey('OTHER_TYPE_MAPPING')),
            matching: find.textContaining('เคยจับคู่เป็นลูกจ้างประจำ'),
          ),
          findsOneWidget,
        );
        // เลขบัตรที่ระบบใช้ไปก่อนไม่แสดงเต็มบนจอ
        expect(find.textContaining(fakeIdCard(3)), findsNothing);
        expect(find.textContaining(fakeIdCard(15)), findsNothing);

        await tapKey(tester, SahaImportScreen.importKey);
        expect(backend.bodyOf('POST /api/saha/import')!['dry_run'], 'false');
        expect(
          backend.bodyOf('POST /api/saha/import')!['confirm_replace'],
          'false',
        );
        expect(backend.p3.sahaRows['G'], 10);
        expect(find.textContaining('ข้าราชการ 10 แถว'), findsOneWidget);
        // บันทึกเป็นหนึ่งรายการต่อเลขบัตร และแสดงรายการปัญหาของการนำเข้าครั้งนี้ด้วย
        expect(
          find.textContaining(
            'บันทึก 9 รายการ (หนึ่งรายการต่อเลขบัตร — รวมยอดคนที่มีหลายเลขสมาชิก 1 คน)',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(SahaImportScreen.importedProblemsKey),
          findsOneWidget,
        );
        expect(
          find.byKey(SahaImportScreen.problemKey('NOT_FOUND')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(SahaImportScreen.summaryKey),
            matching: find.textContaining('10 แถว · 10,002.50 บาท'),
          ),
          findsOneWidget,
        );
        // นำเข้าแล้วล้างไฟล์ที่เลือก ต้องเลือกและตรวจใหม่
        expect(enabled(tester, SahaImportScreen.checkKey), isFalse);
        await settleSnackBar(tester);

        // นำเข้าซ้ำ: ผลตรวจบอกข้อมูลเดิม ยืนยันก่อนแทนที่
        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        expect(
          find.textContaining('จะแทนที่ข้อมูลเดิม 10 รายการของข้าราชการ'),
          findsOneWidget,
        );
        backend.clearLog();
        await tapKey(tester, SahaImportScreen.importKey);
        expect(
          find.textContaining('มีข้อมูลสหกรณ์ของข้าราชการแล้ว 10 รายการ'),
          findsOneWidget,
        );
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
        expect(backend.calls, isEmpty);
        await tapKey(tester, SahaImportScreen.importKey);
        await tester.tap(find.text('แทนที่ข้อมูลเดิม').last);
        await tester.pumpAndSettle();
        expect(
          backend.bodyOf('POST /api/saha/import')!['confirm_replace'],
          'true',
        );
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'ไฟล์ใช้ไม่ได้: นามสกุลผิด ใหญ่เกิน 5 MB ผิดรูปแบบ (บอกบรรทัด) และเปลี่ยนประเภทต้องตรวจใหม่',
      (tester) async {
        final queue = <PickedFile>[
          file('saha.dat'),
          file('coopg.dat'),
          file('coopG.txt'),
          PickedFile('coopG.dat', Uint8List(0), size: 6 * 1024 * 1024),
          file('coopG.dat'),
          file('coopG.DAT', rows: 3),
          file('coopE.dat', rows: 3),
        ];
        await open(tester, () => queue.removeAt(0));
        backend.clearLog();

        // ชื่อไฟล์ต้องเป็น coopG.dat / coopE.dat (ตัวอักษรประเภทเป็นตัวพิมพ์ใหญ่ นามสกุลไม่สนตัวพิมพ์)
        expect(find.text(SahaImportScreen.fileNameHint), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await tapKey(tester, SahaImportScreen.pickKey);
          expect(find.text(SahaImportScreen.wrongNameText), findsOneWidget);
          expect(enabled(tester, SahaImportScreen.checkKey), isFalse);
        }
        await tapKey(tester, SahaImportScreen.pickKey);
        expect(find.text(SahaImportScreen.tooBigText), findsOneWidget);
        expect(backend.calls, isEmpty);

        backend.p3.sahaBadFile = true;
        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        expect(
          find.textContaining(FakePhase3.sahaBadFileMessage),
          findsOneWidget,
        );
        expect(find.textContaining('มี 2 บรรทัดที่ผิดรูปแบบ'), findsOneWidget);
        expect(find.textContaining('บรรทัดที่: 4, 9'), findsOneWidget);
        expect(find.byKey(SahaImportScreen.checkResultKey), findsNothing);
        backend.p3.sahaBadFile = false;

        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        expect(find.byKey(SahaImportScreen.checkResultKey), findsOneWidget);
        // เปลี่ยนเป็นลูกจ้างประจำทั้งที่ไฟล์เป็น coopG: ผลตรวจและไฟล์ถูกยกเลิก ต้องเลือก coopE.dat
        await tapKey(tester, SahaImportScreen.typeKey('E'));
        expect(find.byKey(SahaImportScreen.checkResultKey), findsNothing);
        expect(
          find.text(SahaImportScreen.fileTypeChangedText('E')),
          findsOneWidget,
        );
        expect(enabled(tester, SahaImportScreen.checkKey), isFalse);
        expect(enabled(tester, SahaImportScreen.importKey), isFalse);
        // เลือก coopE.dat: ประเภทตามชื่อไฟล์ ส่งเป็น E
        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        expect(backend.bodyOf('POST /api/saha/import')!['type'], 'E');
        expect(backend.bodyOf('POST /api/saha/import')!['file'], 'coopE.dat');
      },
    );

    testWidgets('เลือกไฟล์ coopE.dat: เลือกประเภทลูกจ้างประจำให้ตามชื่อไฟล์', (
      tester,
    ) async {
      await open(tester, () => file('coopE.dat'));
      expect(SahaImportScreen.typeOfFileName('coopE.dat'), 'E');
      expect(SahaImportScreen.typeOfFileName('C:\\fakepath\\coopG.DAT'), 'G');
      expect(SahaImportScreen.typeOfFileName('coope.dat'), isNull);
      await tapKey(tester, SahaImportScreen.pickKey);
      expect(find.text('coopE.dat (1,060 ไบต์)'), findsOneWidget);
      await tapKey(tester, SahaImportScreen.checkKey);
      expect(backend.bodyOf('POST /api/saha/import')!['type'], 'E');
      expect(find.byKey(SahaImportScreen.checkResultKey), findsOneWidget);
      // จำนวนที่หาเลขบัตรได้ แยกตามแหล่ง (คู่เดิม / งวดก่อน / รายชื่อ / รายการหนี้)
      for (final label in [
        'จับคู่ได้จากที่เคยจดไว้',
        'จากข้อมูลสหกรณ์งวดก่อน',
        'จากรายชื่อบุคลากร (ชื่อ-สกุล)',
        'จากรายการหนี้ของงวด (ชื่อ-สกุล)',
        'จากชื่อใกล้เคียง (ตรวจทานในรายการปัญหา)',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets(
      'ไฟล์น่าจะเป็นของอีกประเภท (400 SAHA_TYPE_MISMATCH): แสดงข้อความของ backend + ประเภทที่ควรเลือก ไม่มีผลตรวจ ไม่บันทึก',
      (tester) async {
        await open(tester, () => file('coopG.dat'));

        // ตรวจไฟล์ (dry_run) ถูกปฏิเสธ
        backend.p3.sahaOtherTypeFile = true;
        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        backend.p3.sahaOtherTypeFile = false;
        expect(
          find.textContaining(FakePhase3.sahaTypeMismatchMessage('G')),
          findsOneWidget,
        );
        expect(
          find.textContaining(SahaImportScreen.typeMismatchHint('E')),
          findsOneWidget,
        );
        expect(find.textContaining('ไฟล์นี้ยังไม่ถูกบันทึก'), findsOneWidget);
        expect(find.byKey(SahaImportScreen.checkResultKey), findsNothing);
        expect(enabled(tester, SahaImportScreen.importKey), isFalse);
        expect(backend.p3.sahaRows['G'], 0);

        // ตรวจผ่าน แต่ตอนนำเข้าจริงคู่เลขสมาชิกเปลี่ยนจนไฟล์กลายเป็นอีกประเภท: ผลตรวจเดิมถูกล้าง ต้องตรวจใหม่
        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        expect(find.byKey(SahaImportScreen.checkResultKey), findsOneWidget);
        backend.p3.sahaMismatchOnImport = true;
        await tapKey(tester, SahaImportScreen.importKey);
        expect(backend.bodyOf('POST /api/saha/import')!['dry_run'], 'false');
        expect(
          find.textContaining(SahaImportScreen.typeMismatchHint('E')),
          findsOneWidget,
        );
        expect(find.byKey(SahaImportScreen.checkResultKey), findsNothing);
        expect(enabled(tester, SahaImportScreen.importKey), isFalse);
        expect(backend.p3.sahaRows['G'], 0);
      },
    );

    testWidgets(
      'เปิดหน้าตอนที่มีการนำเข้าค้างอยู่ที่ server: บอกใครทำ งวดไหน เริ่มเมื่อไร ปิดปุ่ม แล้วอัปเดตเองเมื่อเสร็จ',
      (tester) async {
        backend.p3.sahaJob = {
          'owner': '030',
          'started_at': '2026-10-14T10:15:30.000+07:00',
          'expires_at': '2026-10-14T10:45:30.000+07:00',
          'detail': {'type': 'G', 'month': '10', 'year': '2569'},
        };
        await open(tester, () => file('coopG.dat'));
        expect(backend.calls, contains('GET /api/saha/import-status'));
        final bar = find.byKey(SahaImportScreen.jobKey);
        expect(bar, findsOneWidget);
        final text = SahaImportScreen.jobRunningText(backend.p3.sahaJob!);
        expect(text, contains('ข้าราชการ งวด 10/2569'));
        expect(text, contains('บัญชี 030'));
        expect(text, contains('14 ตุลาคม 2569'));
        expect(text, contains('10:15'));
        expect(find.textContaining('โดยบัญชี 030'), findsOneWidget);
        // ระหว่างนั้นเลือกไฟล์/ตรวจ/นำเข้าไม่ได้
        expect(
          tester
                  .widget<SheetButton>(find.byKey(SahaImportScreen.pickKey))
                  .onPressed !=
              null,
          isFalse,
        );
        expect(enabled(tester, SahaImportScreen.checkKey), isFalse);
        expect(enabled(tester, SahaImportScreen.importKey), isFalse);

        // ยังไม่เสร็จ: ถามซ้ำแล้วยังแสดงอยู่
        backend.clearLog();
        await tester.pump(SahaImportScreen.jobPollInterval);
        await tester.pumpAndSettle();
        expect(backend.calls, contains('GET /api/saha/import-status'));
        expect(bar, findsOneWidget);

        // งานเสร็จ (ผู้สั่งอาจปิดหน้าเว็บไปแล้ว): รอบถัดไปแถบหาย โหลดสรุปใหม่ และใช้ปุ่มได้
        backend.p3.sahaJob = null;
        backend.clearLog();
        await tester.pump(SahaImportScreen.jobPollInterval);
        await tester.pumpAndSettle();
        expect(bar, findsNothing);
        expect(find.text(SahaImportScreen.jobDoneText), findsOneWidget);
        expect(backend.calls, contains('GET /api/saha/summary'));
        expect(
          tester
                  .widget<SheetButton>(find.byKey(SahaImportScreen.pickKey))
                  .onPressed !=
              null,
          isTrue,
        );
        // หยุดถามแล้ว
        backend.clearLog();
        await tester.pump(SahaImportScreen.jobPollInterval * 2);
        expect(backend.calls, isNot(contains('GET /api/saha/import-status')));
      },
    );

    testWidgets(
      'กดนำเข้าแล้วมีงานของหน้าต่างอื่นค้างอยู่ (JOB_RUNNING): แสดงสถานะงานนั้นและรอ ไม่มีอะไรถูกบันทึก',
      (tester) async {
        await open(tester, () => file('coopG.dat'));
        expect(find.byKey(SahaImportScreen.jobKey), findsNothing);
        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        backend.p3.sahaJob = {
          'owner': '999',
          'started_at': '2026-10-14T09:00:00.000+07:00',
          'detail': {'type': 'E', 'month': '10', 'year': '2569'},
        };
        await tapKey(tester, SahaImportScreen.importKey);
        expect(find.textContaining('งานนี้กำลังทำอยู่'), findsOneWidget);
        expect(find.byKey(SahaImportScreen.jobKey), findsOneWidget);
        expect(
          find.textContaining('ลูกจ้างประจำ งวด 10/2569 โดยบัญชี 999'),
          findsOneWidget,
        );
        expect(enabled(tester, SahaImportScreen.importKey), isFalse);
        expect(backend.p3.sahaRows['G'], 0);

        backend.p3.sahaJob = null;
        await tester.pump(SahaImportScreen.jobPollInterval);
        await tester.pumpAndSettle();
        expect(find.byKey(SahaImportScreen.jobKey), findsNothing);
      },
    );

    testWidgets(
      'รายการที่ยังไม่ได้แก้: แบ่งหน้า แก้การจับคู่รายคน (เลขบัตรในตัวคำขอ) และเลขบัตรที่ผูกแล้ว',
      (tester) async {
        await open(tester, () => null);
        final card = find.byKey(SahaImportScreen.unresolvedKey);
        expect(
          find.descendant(of: card, matching: find.text('ทั้งหมด 12 รายการ')),
          findsOneWidget,
        );
        expect(backend.queryOf('GET /api/saha/unresolved'), {
          'page': 0,
          'size': 10,
        });
        expect(find.byKey(SahaImportScreen.fixKey('000201')), findsOneWidget);
        expect(find.byKey(SahaImportScreen.fixKey('000211')), findsNothing);

        await tapKey(tester, SahaImportScreen.fixKey('000201'));
        expect(find.byType(SahaMappingDialog), findsOneWidget);
        final saveButton = find.byKey(SahaMappingDialog.saveKey);
        expect(
          tester.widget<PrimaryActionButton>(saveButton).onPressed,
          isNull,
        );

        // เลขบัตรที่ผูกกับเลขสมาชิกอื่นอยู่แล้ว
        backend.clearLog();
        await tester.enterText(
          find.byKey(PersonFinder.idcardKey),
          fakeIdCard(30),
        );
        await tester.tap(find.byKey(PersonFinder.idcardButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(SahaMappingDialog.duplicateHint),
          findsOneWidget,
        );
        expect(find.byType(SahaMappingDialog), findsOneWidget);

        // เลือกคนจากการค้นชื่อ แล้วบันทึก
        await tester.enterText(find.byKey(PersonFinder.nameKey), 'สมมุติ05');
        await tester.tap(find.byKey(PersonFinder.nameButtonKey));
        await tester.pumpAndSettle();
        expect(backend.calls, contains('POST /api/persons/search'));
        await tester.tap(find.byKey(PersonFinder.resultKey(0)));
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(backend.bodyOf('PUT /api/saha/mapping'), {
          'saha_id': '000201',
          'idcard': fakeIdCard(5),
          'type': 'G',
        });
        expect(backend.calls.every((c) => !c.contains(fakeIdCard(5))), isTrue);
        expect(find.byType(SahaMappingDialog), findsNothing);
        expect(
          find.descendant(of: card, matching: find.text('ทั้งหมด 11 รายการ')),
          findsOneWidget,
        );
        expect(find.byKey(SahaImportScreen.fixKey('000201')), findsNothing);
        await settleSnackBar(tester);
      },
    );
  });

  group('งวดถูกเปลี่ยนระหว่างเปิดหน้าค้าง (409 NOT_CURRENT_PERIOD)', () {
    Future<void> expectHint(WidgetTester tester) async {
      expect(
        find.textContaining(FakeBackend.notCurrentPeriodMessage),
        findsOneWidget,
      );
      expect(find.textContaining('ทำได้เฉพาะงวดปัจจุบัน'), findsOneWidget);
      expect(find.textContaining('ปิดหน้านี้แล้วเปิดใหม่'), findsOneWidget);
    }

    testWidgets(
      'นำเข้าสหกรณ์: ตรวจไฟล์/นำเข้าถูกปฏิเสธ บอกให้เปิดหน้าใหม่ ไม่มีอะไรถูกบันทึก',
      (tester) async {
        await pump(
          tester,
          SahaImportScreen(
            apiService: api,
            pickFile: () async => PickedFile('coopG.dat', Uint8List(1060)),
          ),
        );
        await tapKey(tester, SahaImportScreen.pickKey);
        await tapKey(tester, SahaImportScreen.checkKey);
        backend.p2.notCurrentPeriod = true;
        backend.clearLog();
        await tapKey(tester, SahaImportScreen.importKey);
        expect(backend.calls, contains('POST /api/saha/import'));
        await expectHint(tester);
        expect(backend.p3.sahaRows['G'], 0);
        // โหลดงวดใหม่ให้หน้าจออื่นเห็นด้วย
        expect(backend.calls, contains('GET /api/period'));
      },
    );

    testWidgets('แก้การจับคู่สหกรณ์: ข้อความในหน้าต่าง หน้าต่างยังเปิดอยู่', (
      tester,
    ) async {
      await pump(tester, SahaImportScreen(apiService: api));
      await tapKey(tester, SahaImportScreen.fixKey('000201'));
      await tester.enterText(find.byKey(PersonFinder.idcardKey), fakeIdCard(5));
      await tester.tap(find.byKey(PersonFinder.idcardButtonKey));
      await tester.pumpAndSettle();
      backend.p2.notCurrentPeriod = true;
      await tester.tap(find.byKey(SahaMappingDialog.saveKey));
      await tester.pumpAndSettle();
      expect(find.byType(SahaMappingDialog), findsOneWidget);
      await expectHint(tester);
      expect(backend.p3.sahaUnresolved, hasLength(12));
    });

    testWidgets('นำเข้าฌาปนกิจ: ถูกปฏิเสธ บอกให้เปิดหน้าใหม่', (tester) async {
      await pump(tester, ChapanaImportScreen(apiService: api));
      backend.p2.notCurrentPeriod = true;
      await tapKey(tester, ChapanaImportScreen.runKey);
      await expectHint(tester);
      expect(backend.p3.chapanaRows, 0);
    });
  });

  group('ความคืบหน้าของงวด (หน้าแรกของฝ่ายบัญชี)', () {
    Widget host() => Scaffold(
      body: SingleChildScrollView(child: PeriodProgress(apiService: api)),
    );

    String? status(WidgetTester tester, int n) {
      final f = find.byKey(PeriodProgress.statusKey(n));
      return f.evaluate().isEmpty ? null : tester.widget<StatusChip>(f).text;
    }

    testWidgets(
      'แต่ละขั้นแสดงสถานะจากเส้นสรุป ขั้นที่ไม่มีเส้นสรุปเป็นทางลัด กดแล้วไปเมนูนั้น กลับมาโหลดสถานะใหม่',
      (tester) async {
        await pump(tester, host());
        expect(backend.calls, [
          'GET /api/period/dpis-import',
          'GET /api/period/prepare',
          'GET /api/debts/div-status',
          'GET /api/chapana/summary',
          'GET /api/saha/summary',
          'GET /api/loans/check',
        ]);
        expect(find.text(PeriodProgress.title), findsOneWidget);
        expect(find.byKey(PeriodProgress.stepKey(12)), findsOneWidget);
        expect(find.byKey(PeriodProgress.stepKey(13)), findsNothing);

        expect(status(tester, 1), PeriodProgress.doneLabel);
        expect(find.text('งวด กรกฎาคม 2568'), findsOneWidget);
        expect(status(tester, 2), PeriodProgress.doneLabel);
        expect(status(tester, 3), PeriodProgress.doneLabel);
        expect(find.textContaining('36 คน · ล่าสุด'), findsOneWidget);
        expect(status(tester, 4), PeriodProgress.doneLabel);
        // หน่วยงานบันทึกหนี้: จากเส้นสถานะรายหน่วยงาน (รายละเอียดอยู่ใน div_status_test)
        expect(status(tester, 5), PeriodProgress.todoLabel);
        expect(find.text('บันทึกแล้ว 0 จาก 4 หน่วยงาน'), findsOneWidget);
        expect(status(tester, 6), PeriodProgress.todoLabel);
        expect(status(tester, 7), PeriodProgress.todoLabel);
        expect(status(tester, 8), PeriodProgress.problemLabel);
        expect(find.textContaining('ไม่ตรง 3 รายการ'), findsOneWidget);
        // ไฟล์ส่งกรมบัญชีกลาง รายงานส่งธนาคาร รายงานฌาปนกิจ-สลิป รายงาน: ทางลัดเฉย ๆ
        // (ฌาปนกิจ-สลิปเรียกข้ามระบบ จึงไม่เรียกอัตโนมัติจากหน้าแรก)
        expect(backend.calls, isNot(contains('GET /api/chapana/slip-check')));
        for (final n in [9, 10, 11, 12]) {
          expect(status(tester, n), isNull, reason: 'ขั้นที่ $n');
        }

        // กดขั้น "นำเข้าข้อมูลฌาปนกิจ" ไปหน้าจอนั้น ทำงานแล้วกลับมา สถานะเปลี่ยน
        await tapKey(tester, PeriodProgress.stepKey(6));
        expect(find.byType(ChapanaImportScreen), findsOneWidget);
        await tapKey(tester, ChapanaImportScreen.runKey);
        await settleSnackBar(tester);
        backend.clearLog();
        await tester.tap(find.byTooltip('ปิด'));
        await tester.pumpAndSettle();
        expect(backend.calls, contains('GET /api/chapana/summary'));
        expect(status(tester, 6), PeriodProgress.doneLabel);
        expect(find.textContaining('32 คน · ผู้เกษียณ 3 คน'), findsOneWidget);

        // สหกรณ์ครบสองประเภทแต่ยังมีเลขบัตรปลอม = ต้องแก้ / เงินกู้ตรง = ทำแล้ว
        backend.p3
          ..sahaRows['G'] = 10
          ..sahaRows['E'] = 4
          ..loanMismatches = [];
        await tapKey(tester, PeriodProgress.refreshKey);
        expect(status(tester, 7), PeriodProgress.problemLabel);
        expect(find.textContaining('เลขบัตรปลอม 12'), findsOneWidget);
        expect(status(tester, 8), PeriodProgress.doneLabel);
        backend.p3.sahaUnresolved.clear();
        await tapKey(tester, PeriodProgress.refreshKey);
        expect(status(tester, 7), PeriodProgress.doneLabel);

        await tapKey(tester, PeriodProgress.stepKey(9));
        expect(find.byType(CgdFilesScreen), findsOneWidget);
      },
    );

    testWidgets('เส้นสรุปใช้ไม่ได้: ขั้นนั้นเป็นทางลัดเฉย ๆ ไม่พัง', (
      tester,
    ) async {
      backend.failPaths.addAll([
        '/api/period/dpis-import',
        '/api/period/prepare',
        '/api/debts/div-status',
        '/api/chapana/summary',
        '/api/saha/summary',
        '/api/loans/check',
      ]);
      await pump(tester, host());
      expect(tester.takeException(), isNull);
      expect(status(tester, 1), PeriodProgress.doneLabel);
      for (final n in [3, 4, 5, 6, 7, 8]) {
        expect(status(tester, n), isNull, reason: 'ขั้นที่ $n');
        expect(find.byKey(PeriodProgress.stepKey(n)), findsOneWidget);
      }
    });

    testWidgets(
      'ผู้ใช้ทั่วไป: เห็นเฉพาะขั้น 5 หน่วยงานบันทึกหนี้ กับ 12 รายงาน ไม่เรียกเส้นสรุป กดแล้วไปหน้าบันทึกข้อมูล/รายงาน',
      (tester) async {
        await pump(tester, host(), as: FakeBackend.user);
        expect(backend.calls, isEmpty, reason: 'ไม่เรียกเส้นสรุปของฝ่ายบัญชี');
        for (var n = 1; n <= 12; n++) {
          expect(
            find.byKey(PeriodProgress.stepKey(n)),
            n == 5 || n == 12 ? findsOneWidget : findsNothing,
            reason: 'ขั้นที่ $n',
          );
        }
        expect(status(tester, 5), isNull);

        await tapKey(tester, PeriodProgress.stepKey(5));
        expect(find.byType(DebtEntryScreen), findsOneWidget);
        expect(find.byType(DivStatusScreen), findsNothing);
        await tester.tap(find.byTooltip('ปิด'));
        await tester.pumpAndSettle();

        await tapKey(tester, PeriodProgress.stepKey(12));
        expect(find.byType(ReportScreen), findsOneWidget);
      },
    );
  });

  group('ของเดิมที่ใช้เส้นใหม่', () {
    testWidgets('ค้นบุคคลด้วยชื่อ: ผลเกิน 50 คนบอกให้พิมพ์เจาะจงขึ้น', (
      tester,
    ) async {
      backend.personSearchLimit = 3;
      await pump(tester, DeductScreen(apiService: api));
      await tester.enterText(find.byKey(PersonFinder.nameKey), 'สมมุติ');
      await tester.tap(find.byKey(PersonFinder.nameButtonKey));
      await tester.pumpAndSettle();
      expect(backend.bodyOf('POST /api/persons/search'), {'name': 'สมมุติ'});
      expect(find.text(PersonFinder.truncatedText), findsOneWidget);
      expect(find.byKey(PersonFinder.resultKey(2)), findsOneWidget);
      expect(find.byKey(PersonFinder.resultKey(3)), findsNothing);
    });

    testWidgets(
      'ประวัติการแก้ไข: รายการเก่า ADD/TRANSFER/DELETE และ action ที่ไม่รู้จัก แสดงเป็นข้อความกลาง ๆ ไม่พัง',
      (tester) async {
        final id = 'debt0001'.padRight(24, '0');
        backend.p2.audits.addAll([
          for (final action in ['ADD', 'TRANSFER', 'DELETE', 'NEW_KIND'])
            {
              'xtion_id': id,
              'action': action,
              'by': '902',
              'at': '2025-06-20T08:00:00+07:00',
              'changes': null,
            },
          {
            'xtion_id': id,
            'action': 'UPDATE',
            'by': '901',
            'at': '2025-06-25T09:30:00+07:00',
            'changes': {
              'c40303': {'from': 0, 'to': 2000},
            },
          },
        ]);
        await pump(
          tester,
          DebtEntryScreen(apiService: api),
          as: FakeBackend.user,
        );
        await tapKey(tester, DebtEntryScreen.auditKey(id));
        expect(find.byType(DebtAuditDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text(DebtAudit.otherName), findsNWidgets(4));
        expect(find.text(DebtAudit.updateName), findsOneWidget);
        for (final raw in ['ADD', 'TRANSFER', 'DELETE', 'NEW_KIND']) {
          expect(find.text(raw), findsNothing);
        }
        expect(find.text('ย้ายหน่วยงาน'), findsNothing);
        expect(find.text('ธ.ออมสิน: 0.00 → 2,000.00'), findsOneWidget);
        expect(
          find.textContaining('25 มิถุนายน 2568 เวลา 09:30:00 น. โดย 901'),
          findsOneWidget,
        );
      },
    );
  });
}
