// เทสต์งานงวดของฝ่ายบัญชี: นำเข้าข้อมูลบุคลากรจาก DPIS และเตรียมข้อมูลเดือนที่ผ่านมาเป็นงวดปัจจุบัน
// (สถานะล่าสุด กันกดซ้ำ JOB_RUNNING, DPIS_ERROR, สรุปก่อนทำ, ยืนยันก่อนล้าง CONFIRM_REQUIRED)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/screens/period_jobs_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/services/debt_api.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/screen_parts.dart';

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
    Widget screen, {
    String as = FakeBackend.account,
  }) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => signIn(as));
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

  group('นำเข้าข้อมูลบุคลากร', () {
    final run = find.byKey(DpisImportScreen.runKey);

    testWidgets('แสดงสถานะล่าสุด: จำนวนคน เวลา (เวลาไทย) และผู้สั่ง', (
      tester,
    ) async {
      await pump(tester, DpisImportScreen(apiService: api));

      expect(backend.calls, ['GET /api/period/dpis-import']);
      expect(find.text(DpisImportScreen.menuTitle), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(DpisImportScreen.totalKey)).data,
        '36 คน',
      );
      expect(find.text('30 คน'), findsOneWidget);
      expect(find.text('6 คน'), findsOneWidget);
      // 2025-06-20T02:15Z = 09:15 เวลาไทย
      expect(find.text('20 มิถุนายน 2568 เวลา 09:15:00 น.'), findsOneWidget);
      expect(find.text(FakeBackend.account), findsOneWidget);
    });

    testWidgets('ยังไม่เคยนำเข้า: บอกชัดเจน', (tester) async {
      backend.p2
        ..dpisG = 0
        ..dpisE = 0
        ..dpisLastAt = null
        ..dpisLastBy = null;
      await pump(tester, DpisImportScreen(apiService: api));
      expect(find.text(DpisImportScreen.neverText), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(DpisImportScreen.totalKey)).data,
        '0 คน',
      );
    });

    testWidgets('สั่งนำเข้าสำเร็จ: แสดงผลครั้งนี้ และสถานะล่าสุดเปลี่ยน', (
      tester,
    ) async {
      await pump(tester, DpisImportScreen(apiService: api));
      backend.clearLog();
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(backend.calls, [
        'POST /api/period/dpis-import',
        'GET /api/period/dpis-import',
      ]);
      expect(find.text('ผลการนำเข้าครั้งนี้'), findsOneWidget);
      expect(find.text('38 คน'), findsNWidgets(2)); // ผลครั้งนี้ + สถานะล่าสุด
      expect(find.text('36 คน'), findsOneWidget); // จำนวนเดิมก่อนนำเข้า
      expect(find.text('ข้ามเพราะเลขบัตรไม่ถูกต้อง'), findsOneWidget);
      // DPIS นับได้แต่ไม่ส่งรายชื่อมา
      expect(
        tester.widget<Text>(find.byKey(DpisImportScreen.missingKey)).data,
        'ข้าราชการ 1 คน ลูกจ้างประจำ 0 คน',
      );
      expect(find.text('25 มิถุนายน 2568 เวลา 09:30:00 น.'), findsOneWidget);
      expect(
        find.textContaining('นำเข้าข้อมูลบุคลากรจาก DPIS สำเร็จ'),
        findsOneWidget,
      );
      await settleSnackBar(tester);
    });

    testWidgets('มีงานค้าง (JOB_RUNNING): แจ้งให้รอ ข้อมูลเดิมไม่เปลี่ยน', (
      tester,
    ) async {
      backend.p2.jobRunning = true;
      await pump(tester, DpisImportScreen(apiService: api));
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(FakeBackend.jobRunningMessage),
        findsOneWidget,
      );
      expect(
        find.textContaining(DpisImportScreen.jobRunningText),
        findsOneWidget,
      );
      expect(find.text('ผลการนำเข้าครั้งนี้'), findsNothing);
      expect(backend.p2.dpisG, 30);
      // ปุ่มกลับมากดได้ ไม่ค้างหมุน
      expect(tester.widget<PrimaryActionButton>(run).loading, isFalse);
    });

    testWidgets(
      'DPIS ล่ม (502 DPIS_ERROR): แสดงข้อความของ backend และบอกว่าข้อมูลเดิมยังอยู่',
      (tester) async {
        backend.p2.dpisFails = true;
        await pump(tester, DpisImportScreen(apiService: api));
        await tester.tap(run);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(FakeBackend.dpisErrorMessage),
          findsOneWidget,
        );
        expect(
          find.textContaining(DpisImportScreen.dpisErrorText),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.byKey(DpisImportScreen.totalKey)).data,
          '36 คน',
        );
        expect(auth.isLoggedIn, isTrue);

        // ลองใหม่ได้ทันที
        backend.p2.dpisFails = false;
        await tester.tap(run);
        await tester.pumpAndSettle();
        expect(find.text('ผลการนำเข้าครั้งนี้'), findsOneWidget);
        await settleSnackBar(tester);
      },
    );

    test('ข้อผิดพลาดตาม code และสิทธิ์ (เส้น API)', () async {
      await signIn(FakeBackend.account);
      backend.p2.dpisFails = true;
      await expectLater(
        api.runDpisImport(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ErrorCodes.dpisError)
              .having((e) => e.statusCode, 'status', 502),
        ),
      );
      backend.p2
        ..dpisFails = false
        ..jobRunning = true;
      await expectLater(
        api.runDpisImport(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.jobRunning,
          ),
        ),
      );
      await auth.logout();

      await signIn(FakeBackend.user);
      for (final call in [
        api.getDpisImport,
        api.runDpisImport,
        api.getPrepare,
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
    });
  });

  group('เตรียมข้อมูลเดือนที่ผ่านมาเป็นงวดปัจจุบัน', () {
    final run = find.byKey(PreparePeriodScreen.runKey);
    final check = find.byKey(PreparePeriodScreen.confirmCheckKey);
    final confirm = find.descendant(
      of: find.byKey(PreparePeriodScreen.confirmButtonKey),
      matching: find.byType(ElevatedButton),
    );

    testWidgets(
      'สรุปก่อนทำ: งวดปลายทาง/ต้นทาง จำนวนบุคลากร รายการเดิม และคำเตือนว่าจะล้าง',
      (tester) async {
        await pump(tester, PreparePeriodScreen(apiService: api));

        expect(backend.calls, ['GET /api/period/prepare']);
        expect(find.text('กรกฎาคม 2568'), findsOneWidget);
        expect(find.text('มิถุนายน 2568'), findsOneWidget);
        expect(find.text('36 คน'), findsOneWidget);
        expect(find.text('32 รายการ'), findsOneWidget);
        // มียอดหนี้ 3 รายการ (คนที่ 1 ของ 901 และสองคนของ 902)
        expect(find.text('3 รายการ'), findsOneWidget);
        expect(
          find.textContaining('งวดนี้มีรายการอยู่แล้ว 32 รายการ'),
          findsOneWidget,
        );
        expect(
          find.textContaining('โดย ${FakeBackend.account}'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'งวดมีรายการแล้ว: เปิดหน้าต่างยืนยันที่บอกจำนวนที่จะล้าง ต้องติ๊กรับทราบก่อน แล้วส่ง confirm_replace',
      (tester) async {
        backend.p2.editsSincePrepare = 7;
        await pump(tester, PreparePeriodScreen(apiService: api));
        backend.clearLog();

        await tester.tap(run);
        await tester.pumpAndSettle();
        expect(find.text('ยืนยันการเตรียมงวดใหม่'), findsOneWidget);
        expect(
          find.textContaining(
            'ล้างรายการของงวด กรกฎาคม 2568 ทั้งหมด 32 รายการ',
          ),
          findsOneWidget,
        );
        expect(find.text('7 ครั้ง'), findsWidgets);
        // ยังไม่ติ๊ก: ปุ่มยืนยันกดไม่ได้ และยังไม่เรียก backend
        expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);
        expect(backend.calls, isEmpty);

        // ยกเลิก: ไม่ทำอะไร
        await tester.tap(find.widgetWithText(OutlinedButton, 'ยกเลิก'));
        await tester.pumpAndSettle();
        expect(backend.calls, isEmpty);
        expect(backend.p2.debts.first['c40302'], 1500.5);

        await tester.tap(run);
        await tester.pumpAndSettle();
        await tester.tap(check);
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(backend.calls, [
          'POST /api/period/prepare',
          'GET /api/period/prepare',
        ]);
        expect(backend.bodyOf('POST /api/period/prepare'), {
          'confirm_replace': true,
        });
        expect(find.text('ผลการเตรียมงวดครั้งนี้'), findsOneWidget);
        expect(find.text('ล้างรายการเดิม'), findsOneWidget);
        expect(
          find.textContaining('เตรียมข้อมูลงวดเรียบร้อยแล้ว'),
          findsOneWidget,
        );
        expect(backend.p2.debts.first['c40302'], 0);
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'สรุปบนจอเก่า (ตอนเปิดยังไม่มีรายการ) แต่ backend ตอบ CONFIRM_REQUIRED: ถามยืนยันด้วยจำนวนจาก details แล้วส่งใหม่',
      (tester) async {
        final saved = [...backend.p2.debts];
        backend.p2.debts.clear();
        await pump(tester, PreparePeriodScreen(apiService: api));
        expect(find.text('0 รายการ'), findsWidgets);
        // ระหว่างที่หน้าจอเปิดอยู่ มีคนเตรียมงวดไปแล้ว
        backend.p2.debts.addAll(saved);
        backend.clearLog();

        await tester.tap(run);
        await tester.pumpAndSettle();
        // คำขอแรกไม่มีคำยืนยัน -> 409 CONFIRM_REQUIRED -> หน้าต่างยืนยัน
        expect(backend.calls, ['POST /api/period/prepare']);
        expect(backend.bodyOf('POST /api/period/prepare'), isEmpty);
        expect(find.text('ยืนยันการเตรียมงวดใหม่'), findsOneWidget);
        expect(find.textContaining('ทั้งหมด 32 รายการ'), findsOneWidget);
        expect(backend.p2.debts.first['c40302'], 1500.5);

        await tester.tap(check);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(backend.count('POST /api/period/prepare'), 2);
        expect(backend.bodyOf('POST /api/period/prepare'), {
          'confirm_replace': true,
        });
        expect(find.text('ผลการเตรียมงวดครั้งนี้'), findsOneWidget);
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'งวดยังไม่มีรายการ: ไม่ต้องยืนยัน ส่งได้เลยโดยไม่มี confirm_replace',
      (tester) async {
        backend.p2.debts.clear();
        await pump(tester, PreparePeriodScreen(apiService: api));
        backend.clearLog();
        await tester.tap(run);
        await tester.pumpAndSettle();

        expect(find.text('ยืนยันการเตรียมงวดใหม่'), findsNothing);
        expect(backend.bodyOf('POST /api/period/prepare'), isEmpty);
        expect(find.text('ผลการเตรียมงวดครั้งนี้'), findsOneWidget);
        await settleSnackBar(tester);
      },
    );

    testWidgets('ยังไม่มีข้อมูลบุคลากร: บอกให้นำเข้าก่อน ปุ่มกดไม่ได้', (
      tester,
    ) async {
      backend.p2
        ..dpisG = 0
        ..dpisE = 0;
      await pump(tester, PreparePeriodScreen(apiService: api));

      expect(find.text(PreparePeriodScreen.noDpisText), findsOneWidget);
      expect(tester.widget<PrimaryActionButton>(run).onPressed, isNull);
    });

    testWidgets('เตรียมงวดครั้งล่าสุดล้ม: เตือนว่าหน่วยงานยังแก้ยอดไม่ได้', (
      tester,
    ) async {
      backend.p2
        ..periodReady = false
        ..prepareStatus = 'FAILED';
      await pump(tester, PreparePeriodScreen(apiService: api));
      expect(find.text(PreparePeriodScreen.notReadyText), findsOneWidget);
    });

    testWidgets('มีงานค้าง (JOB_RUNNING): แจ้งให้รอ ไม่ล้างอะไร', (
      tester,
    ) async {
      backend.p2.debts.clear();
      backend.p2.jobRunning = true;
      await pump(tester, PreparePeriodScreen(apiService: api));
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(FakeBackend.jobRunningMessage),
        findsOneWidget,
      );
      expect(find.text('ผลการเตรียมงวดครั้งนี้'), findsNothing);
    });

    test('CONFIRM_REQUIRED มี details บอกจำนวนที่จะล้าง (เส้น API)', () async {
      await signIn(FakeBackend.account);
      try {
        await api.runPrepare();
        fail('ควรได้ CONFIRM_REQUIRED');
      } on ApiException catch (e) {
        expect(e.statusCode, 409);
        expect(e.isConfirmRequired, isTrue);
        expect(e.details, {
          'month': '07',
          'year': '2568',
          'rows_to_clear': 32,
          'rows_with_debt': 3,
          'edits_since_prepare': 0,
        });
      }
      expect(backend.p2.debts.first['c40302'], 1500.5);
    });
  });
}
