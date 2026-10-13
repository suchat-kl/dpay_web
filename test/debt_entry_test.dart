// เทสต์หน้า "บันทึกข้อมูล" (แก้ไขยอดหนี้รายคน): ตารางแก้ในแถว บันทึกเฉพาะที่แก้ ค้นชื่อ ยอดรวม
// ประวัติ ดูงวดย้อนหลังแบบอ่านอย่างเดียว ขอบเขตหน่วยงาน ช่วงแก้ไขปิด
// และยืนยันว่าหน้านี้ไม่มีการเพิ่มคน ปรับรายชื่อ ย้ายหน่วยงาน หรือลบรายการ (ทุกบทบาท)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/models/period.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/debt_entry_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/services/debt_api.dart';
import 'package:dpay/utils/money.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/debt_dialogs.dart';
import 'package:dpay/widgets/div_selector.dart';
import 'package:dpay/widgets/screen_parts.dart';
import 'package:dpay/widgets/sheet_table.dart';
import 'package:dpay/widgets/app_pagination.dart';

import 'fake_backend.dart';

String _id(int n) => 'debt${n.toString().padLeft(4, '0')}'.padRight(24, '0');

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

  Future<void> pump(WidgetTester tester, {required String as}) async {
    tester.view.physicalSize = const Size(1500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await signIn(as);
      await SettingsProvider().load();
    });
    backend.clearLog();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DebtEntryScreen(apiService: api),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Finder cell(int n, String field) => find.descendant(
    of: find.byKey(DebtEntryScreen.cellKey(_id(n), field)),
    matching: find.byType(TextFormField),
  );
  Finder row(int n) => find.byKey(DebtEntryScreen.rowKey(_id(n)));
  String summary(WidgetTester tester, String field) =>
      tester.widget<Text>(find.byKey(DebtEntryScreen.summaryKey(field))).data!;
  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<PrimaryActionButton>(find.byKey(DebtEntryScreen.saveKey))
          .onPressed !=
      null;

  /// หน้านี้แก้ได้เฉพาะยอดหนี้: ไม่มีช่องติ๊ก เพิ่มคน ปรับรายชื่อ ย้ายหน่วยงาน หรือลบ
  void expectAmountsOnly() {
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(SheetHeaderCheckbox), findsNothing);
    expect(find.text(SheetButton.addLabel), findsNothing);
    expect(find.text(SheetButton.deleteLabel), findsNothing);
    expect(find.text(SheetButton.selectAllLabel), findsNothing);
    expect(find.textContaining('ปรับรายชื่อ'), findsNothing);
    expect(find.byTooltip('ย้ายหน่วยงาน'), findsNothing);
    expect(find.byIcon(Icons.drive_file_move_outline), findsNothing);
    expect(find.byIcon(Icons.sync), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(DebtEntryScreen.saveKey));
    await tester.pumpAndSettle();
  }

  group('หน่วยงานทั่วไป (USER ขอบเขต OWN)', () {
    testWidgets(
      'เปิดหน้า: หน่วยงานตัวเอง ข้าราชการ หน้าแรก 10 จาก 25 คน ยอดรวมต่อรหัส มีเฉพาะการแก้ยอด',
      (tester) async {
        await pump(tester, as: FakeBackend.user);

        expect(find.text(DebtEntryScreen.menuTitle), findsOneWidget);
        expect(find.byKey(DivSelector.fixedKey), findsOneWidget);
        expect(backend.calls, [
          'GET /api/divs',
          'GET /api/debts',
          'GET /api/debts/summary',
        ]);
        expect(backend.queryOf('GET /api/debts'), {
          'type': 'G',
          'div': '901',
          'page': 0,
          'size': 10,
        });
        expect(find.text('ทั้งหมด 25 คน'), findsOneWidget);
        expect(find.text('หน้า 1 จาก 3'), findsOneWidget);
        expect(
          find.byWidgetPredicate((w) => w.key.toString().contains('debt-row-')),
          findsNWidgets(10),
        );
        expect(row(1), findsOneWidget);
        expect(
          find.descendant(
            of: row(1),
            matching: find.text('นายสมมุติ01 ตัวอย่าง'),
          ),
          findsOneWidget,
        );
        // ชายก่อนหญิง: คนที่ 2 (หญิง) อยู่หน้าถัดไปหรือท้ายหน้า
        expect(
          tester.getTopLeft(row(1)).dy,
          lessThan(tester.getTopLeft(row(3)).dy),
        );
        // หัวคอลัมน์ 5 รหัส ไม่มี 40604
        for (final code in ['40302', '40303', '40315', '40803', '41100']) {
          expect(find.textContaining(code), findsWidgets, reason: code);
        }
        expect(find.textContaining('40604'), findsNothing);
        // ค่าในช่อง: มียอดแสดงตัวเลข ยอด 0 เป็นช่องว่าง ชิดขวา
        final first = tester.widget<TextField>(
          find.descendant(
            of: cell(1, 'c40302'),
            matching: find.byType(TextField),
          ),
        );
        expect(first.controller!.text, '1500.50');
        expect(first.textAlign, TextAlign.right);
        expect(
          find.descendant(of: row(1), matching: find.text('1,700.50')),
          findsOneWidget,
        );
        // ยอดรวมของหน่วยงานจาก /summary
        expect(summary(tester, 'c40302'), '1,500.50');
        expect(summary(tester, 'c41100'), '200.00');
        expect(summary(tester, 'c40303'), '0.00');
        expect(find.byKey(DebtEntryScreen.summaryKey('c40604')), findsNothing);

        // หน้านี้แก้ได้เฉพาะยอดหนี้ และบอกที่มาของรายชื่อ
        expectAmountsOnly();
        expect(find.text(DebtEntryScreen.rosterNote), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.periodKey), findsOneWidget);
        expect(find.text('งวด กรกฎาคม 2568'), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsNothing);
        expect(find.byKey(DebtEntryScreen.readOnlyKey), findsNothing);
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsNothing);
        expect(saveEnabled(tester), isFalse);
      },
    );

    testWidgets(
      'แก้ยอดในแถว: ขึ้นสถานะแก้ไขค้าง ยอดรวมแถวเปลี่ยน บันทึกส่งเฉพาะแถวและรหัสที่แก้ในคำขอเดียว',
      (tester) async {
        await pump(tester, as: FakeBackend.user);

        await tester.enterText(cell(1, 'c40303'), '2,000');
        await tester.enterText(cell(1, 'c40315'), '99.5');
        await tester.enterText(cell(3, 'c41100'), '50');
        await tester.pumpAndSettle();

        expect(find.text(DebtEntryScreen.dirtyText), findsOneWidget);
        expect(saveEnabled(tester), isTrue);
        // แถวที่แก้มีเครื่องหมาย แถวที่ไม่ได้แก้ไม่มี
        expect(find.byKey(DebtEntryScreen.changedKey(_id(1))), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.changedKey(_id(3))), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.changedKey(_id(5))), findsNothing);
        expect(
          find.descendant(of: row(1), matching: find.text('3,800.00')),
          findsOneWidget,
        );

        backend.clearLog();
        await save(tester);

        expect(backend.count('PUT /api/debts'), 1);
        expect(backend.bodyOf('PUT /api/debts'), {
          'items': [
            {'id': _id(1), 'c40303': '2000.00', 'c40315': '99.50'},
            {'id': _id(3), 'c41100': '50.00'},
          ],
        });
        expect(find.textContaining('บันทึกข้อมูลสำเร็จ'), findsOneWidget);
        expect(find.textContaining('(2 รายการ)'), findsOneWidget);
        // โหลดใหม่: ไม่มีแก้ไขค้าง ยอดรวมของหน่วยงานเปลี่ยน
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsNothing);
        expect(saveEnabled(tester), isFalse);
        expect(summary(tester, 'c40303'), '2,000.00');
        expect(summary(tester, 'c41100'), '250.00');
        expect(backend.p2.debts.first['c40315'], 99.5);
        await settleSnackBar(tester);
      },
    );

    testWidgets('แก้แล้วพิมพ์กลับเป็นค่าเดิม: ไม่ถือว่ามีการแก้ไข', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      await tester.enterText(cell(1, 'c40302'), '9');
      await tester.pumpAndSettle();
      expect(find.byKey(DebtEntryScreen.dirtyKey), findsOneWidget);
      await tester.enterText(cell(1, 'c40302'), '1,500.50');
      await tester.pumpAndSettle();
      expect(find.byKey(DebtEntryScreen.dirtyKey), findsNothing);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('จำนวนเงินผิดรูป: บอกแถวและรหัส ไม่เรียก backend', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      await tester.enterText(cell(1, 'c40803'), '12.345');
      await tester.pumpAndSettle();
      backend.clearLog();
      await save(tester);

      expect(find.textContaining('แถวที่ 1'), findsOneWidget);
      expect(find.textContaining('AIA ประกันชีวิต'), findsWidgets);
      expect(find.textContaining(Money.invalidMessage), findsOneWidget);
      expect(backend.calls, isEmpty);
    });

    testWidgets(
      'มีแก้ไขค้างแล้วเปลี่ยนประเภท: ถามก่อน ยกเลิก = คงอยู่ ยืนยัน = ทิ้งแล้วโหลดลูกจ้างประจำ',
      (tester) async {
        await pump(tester, as: FakeBackend.user);
        await tester.enterText(cell(1, 'c40303'), '10');
        await tester.pumpAndSettle();
        backend.clearLog();

        await tester.tap(find.byKey(DebtEntryScreen.typeKey('E')));
        await tester.pumpAndSettle();
        expect(find.text(DebtEntryScreen.discardQuestion), findsOneWidget);
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
        expect(backend.calls, isEmpty);
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsOneWidget);

        await tester.tap(find.byKey(DebtEntryScreen.typeKey('E')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ทิ้งการแก้ไข'));
        await tester.pumpAndSettle();
        expect(backend.queryOf('GET /api/debts')!['type'], 'E');
        expect(find.text('ทั้งหมด 3 คน'), findsOneWidget);
        expect(row(26), findsOneWidget);
        expect(row(1), findsNothing);
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsNothing);
        // ไม่ได้บันทึกค่าที่ทิ้ง
        expect(backend.p2.debts.first['c40303'], 0);
      },
    );

    testWidgets('ปิดหน้าทั้งที่มีแก้ไขค้าง: ถามก่อนออก', (tester) async {
      tester.view.physicalSize = const Size(1500, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => signIn(FakeBackend.user));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DebtEntryScreen(apiService: api),
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
      await tester.enterText(cell(1, 'c40303'), '10');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('ปิด'));
      await tester.pumpAndSettle();
      expect(find.text(DebtEntryScreen.discardQuestion), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(find.byType(DebtEntryScreen), findsOneWidget);

      await tester.tap(find.byTooltip('ปิด'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ทิ้งการแก้ไข'));
      await tester.pumpAndSettle();
      expect(find.byType(DebtEntryScreen), findsNothing);
    });

    testWidgets('ค้นด้วยนามสกุล: ส่งทาง POST /search ชื่อไม่อยู่ใน URL', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      backend.clearLog();

      await tester.enterText(find.byKey(DebtEntryScreen.surnameKey), 'ทดสอบ');
      await tester.tap(find.byKey(DebtEntryScreen.searchKey));
      await tester.pumpAndSettle();

      expect(backend.calls.first, 'POST /api/debts/search');
      expect(backend.queryOf('POST /api/debts/search'), isEmpty);
      expect(backend.bodyOf('POST /api/debts/search'), {
        'type': 'G',
        'div': '901',
        'surname': 'ทดสอบ',
        'page': 0,
        'size': 10,
      });
      expect(backend.calls, isNot(contains('GET /api/debts')));
      // ข้าราชการของ 901 ที่นามสกุล "ทดสอบ" = ลำดับ 5, 10, 15, 20, 25
      expect(find.text('ทั้งหมด 5 คน'), findsOneWidget);
      expect(row(5), findsOneWidget);
      expect(row(1), findsNothing);
    });

    testWidgets('ไปหน้าถัดไป และเปลี่ยนจำนวนแถวต่อหน้า (ตัวเลือก 5/10/15/20)', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      final pager = find.byType(AppPagination);
      await tester.tap(find.descendant(of: pager, matching: find.text('2')));
      await tester.pumpAndSettle();
      expect(backend.queryOf('GET /api/debts')!['page'], 1);
      // 10 คนแรกอยู่หน้าแรก ลำดับที่ต่อจากหน้าแรก
      expect(find.text('11'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w.key.toString().contains('debt-row-')),
        findsNWidgets(10),
      );

      await tester.tap(
        find.descendant(
          of: pager,
          matching: find.byType(DropdownButtonFormField<int>),
        ),
      );
      await tester.pumpAndSettle();
      for (final n in [5, 10, 15, 20]) {
        expect(find.text('$n แถว'), findsWidgets);
      }
      expect(find.text('50 แถว'), findsNothing);
      expect(find.text('100 แถว'), findsNothing);
      await tester.tap(find.text('20 แถว').last);
      await tester.pumpAndSettle();
      expect(backend.queryOf('GET /api/debts')!['size'], 20);
      expect(backend.queryOf('GET /api/debts')!['page'], 0);
      expect(find.text('หน้า 1 จาก 2'), findsOneWidget);
    });

    testWidgets(
      'ช่วงแก้ไขปิด: ตารางอ่านอย่างเดียว มีแถบบอกช่วงที่เปิด ปุ่มบันทึกกดไม่ได้',
      (tester) async {
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await pump(tester, as: FakeBackend.user);

        final notice = find.byKey(DebtEntryScreen.readOnlyKey);
        expect(notice, findsOneWidget);
        expect(
          find.descendant(
            of: notice,
            matching: find.textContaining(DebtEntryScreen.windowClosedText),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: notice,
            matching: find.textContaining(
              'ตั้งแต่ 23 มิถุนายน 2568 เวลา 06:00 น. ถึง 3 กรกฎาคม 2568 เวลา 11:00 น.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(cell(1, 'c40302')).enabled,
          isFalse,
        );
        expect(saveEnabled(tester), isFalse);
        // ยังดูรายการ ยอดรวม และประวัติได้
        expect(row(1), findsOneWidget);
        expect(summary(tester, 'c40302'), '1,500.50');
        expect(find.byKey(DebtEntryScreen.auditKey(_id(1))), findsOneWidget);
      },
    );

    testWidgets(
      'ช่วงแก้ไขปิดระหว่างที่หน้าจอเปิดอยู่: backend ตอบ EDIT_WINDOW_CLOSED ตอนบันทึก → แจ้งและเปลี่ยนเป็นอ่านอย่างเดียว',
      (tester) async {
        await pump(tester, as: FakeBackend.user);
        await tester.enterText(cell(1, 'c40303'), '10');
        await tester.pumpAndSettle();
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await save(tester);

        expect(
          find.textContaining(FakeBackend.editWindowClosedMessage),
          findsOneWidget,
        );
        expect(find.textContaining('ไม่ถูกบันทึก'), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.readOnlyKey), findsOneWidget);
        expect(
          tester.widget<TextFormField>(cell(1, 'c40302')).enabled,
          isFalse,
        );
        expect(saveEnabled(tester), isFalse);
        expect(backend.p2.debts.first['c40303'], 0);
        // หน้าจออื่นได้สถานะช่วงแก้ไขล่าสุดด้วย
        expect(SettingsProvider().canEditNow, isFalse);
      },
    );

    testWidgets('งวดยังเตรียมไม่เสร็จ: อ่านอย่างเดียวพร้อมข้อความของงวด', (
      tester,
    ) async {
      backend.p2.periodReady = false;
      await pump(tester, as: FakeBackend.user);

      expect(
        find.descendant(
          of: find.byKey(DebtEntryScreen.readOnlyKey),
          matching: find.text(DebtEntryScreen.notReadyText),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextFormField>(cell(1, 'c40302')).enabled, isFalse);
    });

    testWidgets(
      'งวดถูกเปลี่ยนระหว่างแก้ (NOT_CURRENT_PERIOD) และงวดไม่พร้อมตอนบันทึก (PERIOD_NOT_READY)',
      (tester) async {
        await pump(tester, as: FakeBackend.user);
        await tester.enterText(cell(1, 'c40303'), '10');
        await tester.pumpAndSettle();

        backend.p2.notCurrentPeriod = true;
        await save(tester);
        expect(
          find.textContaining(FakeBackend.notCurrentPeriodMessage),
          findsOneWidget,
        );
        expect(
          find.textContaining('งวดปัจจุบันถูกเปลี่ยนแล้ว'),
          findsOneWidget,
        );

        backend.p2
          ..notCurrentPeriod = false
          ..periodReady = false;
        await save(tester);
        expect(
          find.textContaining(FakeBackend.periodNotReadyMessage),
          findsOneWidget,
        );
        expect(backend.p2.debts.first['c40303'], 0);
      },
    );

    testWidgets('ประวัติการแก้ไขรายแถว: ว่าง และหลังแก้ยอด', (tester) async {
      await pump(tester, as: FakeBackend.user);
      await tester.tap(find.byKey(DebtEntryScreen.auditKey(_id(1))));
      await tester.pumpAndSettle();
      expect(find.byType(DebtAuditDialog), findsOneWidget);
      expect(find.text(DebtAuditDialog.emptyText), findsOneWidget);
      await tester.tap(find.byTooltip('ปิด').last);
      await tester.pumpAndSettle();

      await tester.enterText(cell(1, 'c40303'), '2000');
      await tester.pumpAndSettle();
      await save(tester);
      await settleSnackBar(tester);
      await tester.tap(find.byKey(DebtEntryScreen.auditKey(_id(1))));
      await tester.pumpAndSettle();

      expect(backend.calls, contains('GET /api/debts/${_id(1)}/audit'));
      expect(find.text('แก้ยอด'), findsOneWidget);
      expect(find.text('ธ.ออมสิน: 0.00 → 2,000.00'), findsOneWidget);
      expect(
        find.textContaining('25 มิถุนายน 2568 เวลา 09:30:00 น. โดย 901'),
        findsOneWidget,
      );
    });

    testWidgets(
      'ทำเครื่องหมายแถวที่ไม่อยู่ในรายชื่อ DPIS เมื่อ backend ส่ง in_roster',
      (tester) async {
        backend.p2.sendInRoster = true;
        await pump(tester, as: FakeBackend.user);
        expect(
          find.descendant(
            of: row(3),
            matching: find.text(DebtEntryScreen.notInRosterText),
          ),
          findsOneWidget,
        );
        expect(find.text(DebtEntryScreen.notInRosterText), findsOneWidget);
      },
    );

    testWidgets('backend ยังไม่มีช่อง in_roster: ไม่ทำเครื่องหมาย ไม่พัง', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      expect(find.text(DebtEntryScreen.notInRosterText), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ฝ่ายบัญชี (ACCOUNT ขอบเขต ALL)', () {
    testWidgets(
      'เลือกหน่วยงานอื่นได้ แก้ได้แม้ช่วงแก้ไขปิด — ไม่มีเพิ่มคน/ปรับรายชื่อ/ย้าย/ลบ แม้เป็นฝ่ายบัญชี',
      (tester) async {
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await pump(tester, as: FakeBackend.account);

        // เริ่มที่หน่วยงานตัวเอง 902 (2 คน)
        expect(find.byType(DropdownMenu<String>), findsOneWidget);
        expect(find.text('ทั้งหมด 2 คน'), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.readOnlyKey), findsNothing);
        expect(
          tester.widget<TextFormField>(cell(29, 'c40303')).enabled,
          isTrue,
        );
        expectAmountsOnly();
        expect(find.byKey(DebtEntryScreen.auditKey(_id(29))), findsOneWidget);

        // เปลี่ยนไปหน่วยงาน 901
        await tester.enterText(find.byType(DropdownMenu<String>), '901');
        await tester.pumpAndSettle();
        await tester.tap(find.text('901 หน่วยงานตัวอย่างที่ 1').last);
        await tester.pumpAndSettle();
        expect(backend.queryOf('GET /api/debts')!['div'], '901');
        expect(find.text('ทั้งหมด 25 คน'), findsOneWidget);

        // แก้ยอดได้ทั้งที่ช่วงปิด
        await tester.enterText(cell(1, 'c40803'), '300');
        await tester.pumpAndSettle();
        await save(tester);
        expect(backend.p2.debts.first['c40803'], 300);
        await settleSnackBar(tester);
        expectAmountsOnly();
        // ทั้งหมดที่ส่งไปคือการอ่านและการแก้ยอด
        expect(backend.calls.where((c) => !c.startsWith('GET ')).toSet(), {
          'PUT /api/debts',
        });
      },
    );

    testWidgets(
      'มีแก้ไขค้างแล้วเปลี่ยนหน่วยงาน: ยกเลิก = กลับไปหน่วยงานเดิมและค่าที่แก้ยังอยู่',
      (tester) async {
        await pump(tester, as: FakeBackend.account);
        await tester.enterText(cell(29, 'c40302'), '77');
        await tester.pumpAndSettle();
        backend.clearLog();

        await tester.enterText(find.byType(DropdownMenu<String>), '901');
        await tester.pumpAndSettle();
        await tester.tap(find.text('901 หน่วยงานตัวอย่างที่ 1').last);
        await tester.pumpAndSettle();
        expect(find.text(DebtEntryScreen.discardQuestion), findsOneWidget);
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();

        expect(backend.calls, isEmpty);
        expect(row(29), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsOneWidget);
        // ตัวเลือกหน่วยงานกลับไปแสดง 902
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byType(DropdownMenu<String>),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text,
          startsWith('902'),
        );
      },
    );
  });

  group('ดูงวดย้อนหลัง (อ่านอย่างเดียว)', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byKey(DebtEntryScreen.periodButtonKey));
      await tester.pumpAndSettle();
    }

    Future<void> pickMonth(WidgetTester tester, int month) async {
      await tester.tap(find.byKey(ValueKey('month-$month')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'เลือกงวดก่อนหน้า: ส่ง month/year ไปกับรายการ ยอดรวม และการค้นหา ตารางอ่านอย่างเดียว ไม่มีปุ่มบันทึก',
      (tester) async {
        await pump(tester, as: FakeBackend.user);
        // งวดปัจจุบัน: ไม่ส่ง month/year (backend ใช้งวดปัจจุบันเอง)
        expect(
          backend.queryOf('GET /api/debts')!.containsKey('month'),
          isFalse,
        );
        await openPicker(tester);
        backend.clearLog();
        await pickMonth(tester, 6);

        expect(backend.calls, ['GET /api/debts', 'GET /api/debts/summary']);
        expect(backend.queryOf('GET /api/debts'), {
          'type': 'G',
          'div': '901',
          'month': '06',
          'year': '2568',
          'page': 0,
          'size': 10,
        });
        expect(backend.queryOf('GET /api/debts/summary'), {
          'type': 'G',
          'div': '901',
          'month': '06',
          'year': '2568',
        });
        expect(find.text('งวด มิถุนายน 2568'), findsOneWidget);
        final notice = find.byKey(DebtEntryScreen.pastNoticeKey);
        expect(notice, findsOneWidget);
        expect(
          find.descendant(
            of: notice,
            matching: find.text(
              'กำลังดูงวดย้อนหลัง มิถุนายน 2568 — ดูได้อย่างเดียว',
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(DebtEntryScreen.backToCurrentKey), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.readOnlyKey), findsNothing);

        // ตารางอ่านอย่างเดียว ไม่มีปุ่มบันทึก ยอดรวมเป็นของงวดนั้น
        expect(find.text('ทั้งหมด 12 คน'), findsOneWidget);
        final past1 = 'past0001'.padRight(24, '0');
        final pastCell = find.descendant(
          of: find.byKey(DebtEntryScreen.cellKey(past1, 'c40302')),
          matching: find.byType(TextFormField),
        );
        expect(tester.widget<TextFormField>(pastCell).enabled, isFalse);
        expect(find.byKey(DebtEntryScreen.saveKey), findsNothing);
        expect(summary(tester, 'c40302'), '900.00');
        expect(summary(tester, 'c41100'), '100.00');
        expectAmountsOnly();
        // งวดย้อนหลังไม่มีช่อง in_roster: ไม่ทำเครื่องหมาย
        expect(find.text(DebtEntryScreen.notInRosterText), findsNothing);

        // ค้นหาในงวดย้อนหลัง
        backend.clearLog();
        await tester.enterText(find.byKey(DebtEntryScreen.surnameKey), 'ทดสอบ');
        await tester.tap(find.byKey(DebtEntryScreen.searchKey));
        await tester.pumpAndSettle();
        expect(backend.bodyOf('POST /api/debts/search'), {
          'type': 'G',
          'div': '901',
          'month': '06',
          'year': '2568',
          'surname': 'ทดสอบ',
          'page': 0,
          'size': 10,
        });
        expect(backend.queryOf('POST /api/debts/search'), isEmpty);
        expect(find.text('ทั้งหมด 2 คน'), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsOneWidget);
        // ไม่มีการเขียนใด ๆ
        expect(backend.calls.any((c) => c.startsWith('PUT ')), isFalse);
      },
    );

    testWidgets('ปุ่ม "กลับไปงวดปัจจุบัน": กลับมาแก้ไขได้ ไม่ส่ง month/year', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      await openPicker(tester);
      await pickMonth(tester, 6);
      backend.clearLog();

      await tester.tap(find.byKey(DebtEntryScreen.backToCurrentKey));
      await tester.pumpAndSettle();
      expect(backend.queryOf('GET /api/debts')!.containsKey('month'), isFalse);
      expect(
        backend.queryOf('GET /api/debts/summary')!.containsKey('year'),
        isFalse,
      );
      expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsNothing);
      expect(find.text('งวด กรกฎาคม 2568'), findsOneWidget);
      expect(find.byKey(DebtEntryScreen.saveKey), findsOneWidget);
      expect(tester.widget<TextFormField>(cell(1, 'c40302')).enabled, isTrue);
      expect(find.text('ทั้งหมด 25 คน'), findsOneWidget);
    });

    testWidgets('เลือกงวดในอนาคตไม่ได้: เดือนหลังงวดปัจจุบันและปีถัดไปกดไม่ได้', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      await openPicker(tester);
      backend.clearLog();

      await pickMonth(tester, 8);
      await pickMonth(tester, 12);
      expect(backend.calls, isEmpty);
      expect(find.text('งวด กรกฎาคม 2568'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('ปีถัดไป'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );

      // ปีก่อนหน้า: เลือกได้ครบทุกเดือน
      await tester.tap(find.byTooltip('ปีก่อนหน้า'));
      await tester.pumpAndSettle();
      expect(backend.queryOf('GET /api/debts')!['year'], '2567');
      expect(backend.queryOf('GET /api/debts')!['month'], '07');
      await pickMonth(tester, 12);
      expect(backend.queryOf('GET /api/debts')!['month'], '12');
      expect(find.text('งวด ธันวาคม 2567'), findsOneWidget);

      // กลับมาปีของงวดปัจจุบัน: เดือนถูกดึงกลับไม่ให้เกินงวดปัจจุบัน = งวดปัจจุบัน
      await tester.tap(find.byTooltip('ปีถัดไป'));
      await tester.pumpAndSettle();
      expect(find.text('งวด กรกฎาคม 2568'), findsOneWidget);
      expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsNothing);
      expect(backend.queryOf('GET /api/debts')!.containsKey('month'), isFalse);
    });

    testWidgets('งวดที่ไม่มีข้อมูล: ข้อความว่าง ยังมีแถบงวดย้อนหลัง', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.user);
      await openPicker(tester);
      await pickMonth(tester, 3);

      expect(backend.queryOf('GET /api/debts')!['month'], '03');
      expect(find.text(DebtEntryScreen.emptyText), findsOneWidget);
      expect(find.text('ทั้งหมด 0 คน'), findsOneWidget);
      expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w.key.toString().contains('debt-row-')),
        findsNothing,
      );
      expect(summary(tester, 'c40302'), '0.00');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'เปลี่ยนงวดขณะมีการแก้ไขค้าง: ถามก่อน ยกเลิก = อยู่งวดเดิม ยืนยัน = ทิ้งแล้วไปงวดที่เลือก',
      (tester) async {
        await pump(tester, as: FakeBackend.user);
        await openPicker(tester);
        await tester.enterText(cell(1, 'c40303'), '10');
        await tester.pumpAndSettle();
        backend.clearLog();

        await pickMonth(tester, 6);
        expect(find.text(DebtEntryScreen.discardQuestion), findsOneWidget);
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
        expect(backend.calls, isEmpty);
        expect(find.text('งวด กรกฎาคม 2568'), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsOneWidget);

        await pickMonth(tester, 6);
        await tester.tap(find.text('ทิ้งการแก้ไข'));
        await tester.pumpAndSettle();
        expect(backend.queryOf('GET /api/debts')!['month'], '06');
        expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsOneWidget);
        expect(find.byKey(DebtEntryScreen.dirtyKey), findsNothing);
        expect(backend.p2.debts.first['c40303'], 0);
      },
    );

    testWidgets('ฝ่ายบัญชีก็ดูงวดย้อนหลังได้อย่างเดียว และดูประวัติรายแถวได้', (
      tester,
    ) async {
      await pump(tester, as: FakeBackend.account);
      await tester.enterText(find.byType(DropdownMenu<String>), '901');
      await tester.pumpAndSettle();
      await tester.tap(find.text('901 หน่วยงานตัวอย่างที่ 1').last);
      await tester.pumpAndSettle();
      await openPicker(tester);
      await pickMonth(tester, 6);

      expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsOneWidget);
      expect(find.byKey(DebtEntryScreen.saveKey), findsNothing);
      expectAmountsOnly();
      final past1 = 'past0001'.padRight(24, '0');
      await tester.tap(find.byKey(DebtEntryScreen.auditKey(past1)));
      await tester.pumpAndSettle();
      expect(find.byType(DebtAuditDialog), findsOneWidget);
      expect(backend.calls, contains('GET /api/debts/$past1/audit'));
    });
  });

  group('สิทธิ์และขอบเขตหน่วยงาน (เส้น API)', () {
    test('หน่วยงานทั่วไปดูหน่วยงานอื่นไม่ได้', () async {
      await signIn(FakeBackend.user);
      expect((await api.getDebts(div: '901', type: 'G')).totalItems, 25);
      for (final call in [
        () => api.getDebts(div: '902', type: 'G'),
        () => api.getDebtSummary(div: '902', type: 'G'),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', ErrorCodes.divForbidden)
                .having((e) => e.isDivForbidden, 'isDivForbidden', isTrue),
          ),
        );
      }
      expect(backend.p2.debts, hasLength(32));
    });

    test(
      'งวดย้อนหลัง: is_current_period เท็จ และแก้ไม่ได้แม้เป็นฝ่ายบัญชี',
      () async {
        await signIn(FakeBackend.account);
        final past = await api.getDebts(
          div: '901',
          type: 'G',
          period: Period.of(6, 2568),
        );
        expect(past.isCurrentPeriod, isFalse);
        expect(past.editable, isFalse);
        expect(past.month, '06');
        expect(past.totalItems, 12);
        expect(past.items.first.inRoster, isNull);
        final current = await api.getDebts(div: '901', type: 'G');
        expect(current.isCurrentPeriod, isTrue);
        expect(current.editable, isTrue);
      },
    );

    test(
      'ขอบเขต CENTER: เห็นหน่วยงานส่วนกลาง ไม่เห็นหน่วยงานนอกส่วนกลาง',
      () async {
        await signIn(FakeBackend.centerDept);
        expect((await api.getDebts(div: '902', type: 'G')).totalItems, 2);
        await expectLater(
          api.getDebts(div: '901', type: 'G'),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test(
      'ช่วงแก้ไขปิด: หน่วยงานทั่วไปบันทึกไม่ได้ (EDIT_WINDOW_CLOSED) ฝ่ายบัญชีได้',
      () async {
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await signIn(FakeBackend.user);
        final page = await api.getDebts(div: '901', type: 'G');
        expect(page.editable, isFalse);
        final row = page.items.first..amounts['c40303'] = 500;
        await expectLater(
          api.saveDebts([row]),
          throwsA(
            isA<ApiException>().having(
              (e) => e.isEditWindowClosed,
              'isEditWindowClosed',
              isTrue,
            ),
          ),
        );
        await auth.logout();

        await signIn(FakeBackend.account);
        final mine = await api.getDebts(div: '901', type: 'G');
        expect(mine.editable, isTrue);
        final r = mine.items.first..amounts['c40303'] = 500;
        final body = await api.saveDebts([r]);
        expect(body['updated'], 1);
      },
    );

    test('บันทึกหลายแถว: มีแถวใดไม่ผ่าน ไม่บันทึกแถวใดเลย', () async {
      await signIn(FakeBackend.account);
      final a = (await api.getDebts(div: '901', type: 'G')).items.first
        ..amounts['c40303'] = 500;
      final b = (await api.getDebts(div: '902', type: 'G')).items.first
        ..amounts['c40303'] = Money.maxSatang + 1;
      await expectLater(
        api.saveDebts([a, b]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.badRequest,
          ),
        ),
      );
      expect(backend.p2.debts.first['c40303'], 0);
    });
  });
}
