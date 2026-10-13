// เทสต์หน้า "สถานะการบันทึกของหน่วยงาน" (ACCOUNT): สรุป ตัวกรอง เรียง แบ่งหน้า กดแถวไปหน้าบันทึกข้อมูล
// คัดลอกรายชื่อ งวดที่ไม่มีประวัติการแก้ไข และ backend ที่ยังไม่มีเส้นนี้ — ข้อมูลทั้งหมดเป็นค่าสมมุติ

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/debt_entry_screen.dart';
import 'package:dpay/screens/div_status_screen.dart';
import 'package:dpay/screens/period_jobs_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/services/work_api.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/period_progress.dart';
import 'package:dpay/widgets/screen_parts.dart';
import 'package:dpay/widgets/work_parts.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();

  /// ข้อความที่ถูกคัดลอกลงคลิปบอร์ด
  final copied = <String>[];

  setUp(() async {
    backend = await installFakeBackend();
    // ให้ทุกหน่วยงาน (30 แห่ง) มีรายการในงวด — เส้นนี้คืนเฉพาะหน่วยงานที่มีรายการ
    backend.p2.seedAllDivs();
    auth = AuthProvider();
    copied.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add('${(call.arguments as Map)['text']}');
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await auth.logout();
  });

  /// จำลองว่าหน่วยงาน [div] แก้ยอดไปแล้ว [times] ครั้ง
  void edit(String div, {int times = 1}) {
    for (var i = 0; i < times; i++) {
      backend.p2.audits.insert(0, {
        'xtion_id': 'x',
        'action': 'UPDATE',
        'div': div,
        'by': div,
        'at': '2025-06-25T09:30:00+07:00',
        'changes': {
          'c40303': {'from': 0, 'to': 100},
        },
      });
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    Widget? screen,
    String as = FakeBackend.account,
  }) async {
    tester.view.physicalSize = const Size(1500, 2600);
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
        home: screen ?? DivStatusScreen(apiService: api),
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

  Finder row(String div) => find.byKey(DivStatusScreen.rowKey(div));
  int rowCount(WidgetTester tester) => find
      .byWidgetPredicate((w) => '${w.key}'.contains('div-status-row-'))
      .evaluate()
      .length;
  String chip(WidgetTester tester, String div) => tester
      .widget<StatusChip>(find.byKey(DivStatusScreen.statusKey(div)))
      .text;

  testWidgets(
    'สรุป แถบความคืบหน้า และตารางเรียงตามลำดับหน่วยงาน: ป้ายสถานะ จำนวนครั้ง แก้ล่าสุดเป็นวันที่ไทย',
    (tester) async {
      edit('901', times: 2);
      await pump(tester);
      expect(backend.calls, ['GET /api/debts/div-status']);
      expect(backend.queryOf('GET /api/debts/div-status'), isEmpty);

      final summary = find.byKey(DivStatusScreen.summaryKey);
      expect(
        find.descendant(
          of: summary,
          matching: find.text('บันทึกแล้ว 1 จาก 30 หน่วยงาน'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(DivStatusScreen.progressKey),
            )
            .value,
        closeTo(1 / 30, 0.0001),
      );
      for (final text in ['30 หน่วยงาน', '29 หน่วยงาน', '58 คน', '3 คน']) {
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
            'นับการแก้ยอดหลังเตรียมงวดเมื่อ 22 มิถุนายน 2568',
          ),
        ),
        findsOneWidget,
      );

      // เกณฑ์ของ "ยังไม่บันทึก" อธิบายไว้ใต้การ์ดสรุป (ไม่มีปุ่มยืนยันว่าตรวจแล้ว)
      expect(
        find.descendant(
          of: summary,
          matching: find.text(DivStatusScreen.criteriaText),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.textContaining('ยืนยันว่าตรวจแล้ว'),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );
      expect(find.byKey(DivStatusScreen.notReadyKey), findsNothing);

      // หน้าแรก 10 หน่วยงานตามลำดับ
      expect(rowCount(tester), 10);
      expect(
        tester.getTopLeft(row('901')).dy,
        lessThan(tester.getTopLeft(row('902')).dy),
      );
      expect(row('911'), findsNothing);
      expect(find.text('แสดง 30 จาก 30 หน่วยงาน'), findsOneWidget);

      expect(chip(tester, '901'), DivStatusScreen.editedLabel);
      expect(chip(tester, '902'), DivStatusScreen.notEditedLabel);
      expect(
        find.descendant(
          of: row('901'),
          matching: find.text('25 มิถุนายน 2568 เวลา 09:30:00 น.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row('901'), matching: find.text('25')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row('902'),
          matching: find.text('กองบัญชีตัวอย่าง'),
        ),
        findsOneWidget,
      );

      // โหลดใหม่: สถานะล่าสุด
      edit('902');
      backend.clearLog();
      await tapKey(tester, DivStatusScreen.refreshKey);
      expect(backend.calls, ['GET /api/debts/div-status']);
      expect(chip(tester, '902'), DivStatusScreen.editedLabel);
      expect(find.text('บันทึกแล้ว 2 จาก 30 หน่วยงาน'), findsOneWidget);
    },
  );

  testWidgets(
    'ตัวกรองสถานะ ส่วนกลาง/ภูมิภาค ค้นรหัสหรือชื่อ เรียงตามหัวคอลัมน์ และแบ่งหน้า',
    (tester) async {
      edit('901');
      edit('903');
      await pump(tester);
      backend.clearLog();

      await tapKey(tester, DivStatusScreen.statusFilterKey('edited'));
      expect(rowCount(tester), 2);
      expect(find.text('แสดง 2 จาก 30 หน่วยงาน'), findsOneWidget);
      await tapKey(tester, DivStatusScreen.statusFilterKey('not'));
      expect(find.text('แสดง 28 จาก 30 หน่วยงาน'), findsOneWidget);
      expect(row('901'), findsNothing);

      // ส่วนกลาง 5 หน่วยงาน (902-905, 909) ที่ยังไม่บันทึก = 4
      await tapKey(tester, DivStatusScreen.regionFilterKey('center'));
      expect(rowCount(tester), 4);
      expect(row('903'), findsNothing);
      await tapKey(tester, DivStatusScreen.statusFilterKey('all'));
      expect(rowCount(tester), 5);
      await tapKey(tester, DivStatusScreen.regionFilterKey('region'));
      expect(find.text('แสดง 25 จาก 30 หน่วยงาน'), findsOneWidget);
      await tapKey(tester, DivStatusScreen.regionFilterKey('all'));

      await tester.enterText(find.byKey(DivStatusScreen.searchKey), '915');
      await tester.pumpAndSettle();
      expect(rowCount(tester), 1);
      expect(row('915'), findsOneWidget);
      await tester.enterText(find.byKey(DivStatusScreen.searchKey), 'บัญชี');
      await tester.pumpAndSettle();
      expect(rowCount(tester), 1);
      expect(row('902'), findsOneWidget);
      await tester.enterText(
        find.byKey(DivStatusScreen.searchKey),
        'ไม่มีหน่วยงานนี้',
      );
      await tester.pumpAndSettle();
      expect(find.text(DivStatusScreen.emptyText), findsOneWidget);
      await tester.enterText(find.byKey(DivStatusScreen.searchKey), '');
      await tester.pumpAndSettle();

      // เรียงรหัสมากไปน้อย
      await tester.tap(find.text('รหัส'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('รหัส'));
      await tester.pumpAndSettle();
      expect(row('930'), findsOneWidget);
      expect(row('901'), findsNothing);
      // เรียงตามสถานะ: บันทึกแล้วอยู่ท้าย กดอีกครั้งขึ้นก่อน
      await tester.tap(find.text('สถานะ'));
      await tester.pumpAndSettle();
      expect(row('901'), findsNothing);
      await tester.tap(find.text('สถานะ'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(row('901')).dy,
        lessThan(tester.getTopLeft(row('903')).dy),
      );
      expect(
        tester.getTopLeft(row('903')).dy,
        lessThan(tester.getTopLeft(row('902')).dy),
      );

      // แบ่งหน้าฝั่งหน้าเว็บ: ไม่เรียก backend
      await tester.tap(find.text('รหัส'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      expect(find.text('หน้า 3 จาก 3'), findsOneWidget);
      expect(row('921'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('50 แถว'), findsNothing);
      await tester.tap(find.text('20 แถว').last);
      await tester.pumpAndSettle();
      expect(rowCount(tester), 20);
      expect(backend.calls, isEmpty);
    },
  );

  testWidgets('กดแถว: ไปหน้าบันทึกข้อมูลของหน่วยงานและงวดนั้น', (tester) async {
    await pump(tester);
    await tapKey(tester, DivStatusScreen.rowKey('904'));
    expect(
      tester.widget<DebtEntryScreen>(find.byType(DebtEntryScreen)).initialDiv,
      '904',
    );
    expect(backend.queryOf('GET /api/debts')!['div'], '904');
    expect(backend.queryOf('GET /api/debts')!.containsKey('month'), isFalse);
    await tester.tap(find.byTooltip('ปิด').last);
    await tester.pumpAndSettle();

    // งวดย้อนหลัง: ส่งงวดไปด้วย และหน้าบันทึกข้อมูลเปิดแบบอ่านอย่างเดียว
    await tapKey(tester, PeriodPicker.buttonKey);
    await tapKey(tester, const ValueKey('month-6'));
    expect(backend.queryOf('GET /api/debts/div-status'), {
      'month': '06',
      'year': '2568',
    });
    await tapKey(tester, DivStatusScreen.rowKey('901'));
    expect(backend.queryOf('GET /api/debts'), {
      'type': 'G',
      'div': '901',
      'month': '06',
      'year': '2568',
      'page': 0,
      'size': 10,
    });
    expect(find.byKey(DebtEntryScreen.pastNoticeKey), findsOneWidget);
  });

  testWidgets('คัดลอกรายชื่อหน่วยงานที่ยังไม่บันทึก: รหัส + ชื่อ ลงคลิปบอร์ด', (
    tester,
  ) async {
    edit('901');
    await pump(tester);
    await tapKey(tester, DivStatusScreen.copyKey);
    expect(copied, hasLength(1));
    final lines = copied.single.split('\n');
    expect(
      lines.first,
      'หน่วยงานที่ยังไม่บันทึกหนี้ งวด กรกฎาคม 2568 (29 หน่วยงาน)',
    );
    expect(lines, hasLength(30));
    expect(lines[1], '902 กองบัญชีตัวอย่าง');
    expect(lines.any((l) => l.startsWith('901 ')), isFalse);
    expect(find.text('คัดลอกแล้ว 29 หน่วยงาน'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // ทุกหน่วยงานบันทึกแล้ว: ไม่มีอะไรให้คัดลอก
    for (var d = 902; d <= 930; d++) {
      edit('$d');
    }
    await tapKey(tester, DivStatusScreen.refreshKey);
    await tapKey(tester, DivStatusScreen.copyKey);
    expect(copied, hasLength(1));
    expect(find.text(DivStatusScreen.allDoneText), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(DivStatusScreen.progressKey),
          )
          .value,
      1,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'audit_available เท็จ: แจ้งว่าบอกสถานะไม่ได้ ไม่มีป้าย "ยังไม่บันทึก" ไม่มีตัวกรองสถานะ/ปุ่มคัดลอก',
    (tester) async {
      backend.p3.auditAvailable = false;
      await pump(tester);
      expect(find.byKey(DivStatusScreen.noAuditKey), findsOneWidget);
      expect(find.text(DivStatusScreen.noAuditText), findsOneWidget);
      expect(find.text(DivStatusScreen.notEditedLabel), findsNothing);
      expect(find.text(DivStatusScreen.editedLabel), findsNothing);
      expect(find.byKey(DivStatusScreen.statusKey('901')), findsNothing);
      expect(find.byKey(DivStatusScreen.copyKey), findsNothing);
      expect(find.byKey(DivStatusScreen.progressKey), findsNothing);
      expect(find.byKey(DivStatusScreen.statusFilterKey('not')), findsNothing);
      // ข้อมูลที่ยังบอกได้: จำนวนหน่วยงาน/คน และตัวกรองภูมิภาค
      expect(rowCount(tester), 10);
      expect(find.text('58 คน'), findsOneWidget);
      expect(find.byKey(DivStatusScreen.criteriaKey), findsNothing);
      await tapKey(tester, DivStatusScreen.regionFilterKey('center'));
      expect(rowCount(tester), 5);
    },
  );

  testWidgets(
    'backend ยังไม่มีเส้นนี้ (404): บอกว่ายังใช้ไม่ได้ ไม่พัง ลองใหม่ได้',
    (tester) async {
      backend.p3.divStatusMissing = true;
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(DivStatusScreen.unavailableKey), findsOneWidget);
      expect(find.text(DivStatusScreen.unavailableText), findsOneWidget);
      expect(find.byKey(DivStatusScreen.summaryKey), findsNothing);
      expect(rowCount(tester), 0);

      backend.p3.divStatusMissing = false;
      await tester.tap(find.text('ลองใหม่'));
      await tester.pumpAndSettle();
      expect(find.byKey(DivStatusScreen.unavailableKey), findsNothing);
      expect(find.byKey(DivStatusScreen.summaryKey), findsOneWidget);
    },
  );

  testWidgets('ไม่ใช่ฝ่ายบัญชี: backend ปฏิเสธ แสดงข้อความ', (tester) async {
    await pump(tester, as: FakeBackend.user);
    expect(find.byType(NoticeBar), findsOneWidget);
    expect(find.byKey(DivStatusScreen.unavailableKey), findsNothing);
    expect(find.byKey(DivStatusScreen.summaryKey), findsNothing);
    Object? error;
    await tester.runAsync(() async {
      try {
        await api.getDivStatus();
      } catch (e) {
        error = e;
      }
    });
    expect(
      error,
      isA<ApiException>().having((e) => e.code, 'code', ErrorCodes.forbidden),
    );
  });

  testWidgets(
    'ตามสัญญาจริง: div_order เป็นข้อความ/null (null ต่อท้าย) แถวไม่ระบุหน่วยงานอยู่ท้ายสุด กดไม่ได้ ไม่อยู่ในรายชื่อที่คัดลอก',
    (tester) async {
      backend.p3.divStatusOddRows = true;
      await pump(tester);
      expect(find.text('บันทึกแล้ว 0 จาก 32 หน่วยงาน'), findsOneWidget);
      // ไปหน้าสุดท้าย (32 รายการ หน้าละ 10 = 4 หน้า)
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();
      expect(rowCount(tester), 2);
      expect(
        tester.getTopLeft(row('999')).dy,
        lessThan(tester.getTopLeft(row('')).dy),
      );
      expect(
        find.descendant(
          of: row(''),
          matching: find.text(DivStatusScreen.noDivName),
        ),
        findsOneWidget,
      );
      // เรียงมากไปน้อยตามลำดับ: ไม่ระบุหน่วยงานขึ้นก่อน แล้วตามด้วยหน่วยงานนอกข้อมูลหลัก
      expect(tester.widget<InkWell>(row('')).onTap, isNull);
      expect(tester.widget<InkWell>(row('999')).onTap, isNotNull);
      backend.clearLog();
      await tester.tap(row(''), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(DebtEntryScreen), findsNothing);
      expect(backend.calls, isEmpty);

      // ค้นด้วยชื่อ "ไม่ระบุ" เจอแถวนั้น
      await tester.enterText(find.byKey(DivStatusScreen.searchKey), 'ไม่ระบุ');
      await tester.pumpAndSettle();
      expect(rowCount(tester), 1);
      await tester.enterText(find.byKey(DivStatusScreen.searchKey), '');
      await tester.pumpAndSettle();

      await tapKey(tester, DivStatusScreen.copyKey);
      final lines = copied.single.split('\n');
      expect(lines.first, contains('(31 หน่วยงาน)'));
      expect(lines.last, '999 หน่วยงานนอกข้อมูลหลัก');
      expect(lines.any((l) => l.contains(DivStatusScreen.noDivName)), isFalse);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'period_ready เท็จ: แถบแจ้งพร้อมปุ่มไปหน้าเตรียมข้อมูลงวด รายการยังเห็น',
    (tester) async {
      backend.p2.periodReady = false;
      await pump(tester);
      expect(find.byKey(DivStatusScreen.notReadyKey), findsOneWidget);
      expect(find.text(DivStatusScreen.notReadyText), findsOneWidget);
      expect(rowCount(tester), 10);
      await tapKey(tester, DivStatusScreen.goPrepareKey);
      expect(find.byType(PreparePeriodScreen), findsOneWidget);
      expect(backend.calls, contains('GET /api/period/prepare'));
    },
  );

  testWidgets(
    'งวดที่ไม่มีรายการ: 200 items ว่าง สรุปเป็นศูนย์ ตารางว่าง ไม่พัง',
    (tester) async {
      await pump(tester);
      await tapKey(tester, PeriodPicker.buttonKey);
      await tapKey(tester, const ValueKey('month-3'));
      expect(tester.takeException(), isNull);
      expect(find.byKey(DivStatusScreen.unavailableKey), findsNothing);
      expect(find.text(DivStatusScreen.noRowsText), findsOneWidget);
      expect(find.text('0 หน่วยงาน'), findsOneWidget);
      expect(find.text('0 คน'), findsNWidgets(2));
      expect(rowCount(tester), 0);
      // งวดย้อนหลังที่ไม่ได้เตรียมด้วยระบบใหม่: ไม่มีประวัติ ไม่มีแถบความคืบหน้า
      expect(find.byKey(DivStatusScreen.noAuditKey), findsOneWidget);
      expect(find.byKey(DivStatusScreen.progressKey), findsNothing);
    },
  );

  group('ความคืบหน้าของงวด: ขั้น "หน่วยงานบันทึกหนี้"', () {
    Widget host() => Scaffold(
      body: SingleChildScrollView(child: PeriodProgress(apiService: api)),
    );
    String? status(WidgetTester tester) {
      final f = find.byKey(PeriodProgress.statusKey(5));
      return f.evaluate().isEmpty ? null : tester.widget<StatusChip>(f).text;
    }

    testWidgets('แสดง "บันทึกแล้ว N จาก M หน่วยงาน" และกดไปหน้าสถานะ', (
      tester,
    ) async {
      edit('901');
      edit('915');
      await pump(tester, screen: host());
      expect(backend.calls, contains('GET /api/debts/div-status'));
      expect(find.text('บันทึกแล้ว 2 จาก 30 หน่วยงาน'), findsOneWidget);
      expect(status(tester), PeriodProgress.todoLabel);

      await tapKey(tester, PeriodProgress.stepKey(5));
      expect(find.byType(DivStatusScreen), findsOneWidget);
      await tester.tap(find.byTooltip('ปิด'));
      await tester.pumpAndSettle();

      for (var d = 901; d <= 930; d++) {
        edit('$d');
      }
      await tapKey(tester, PeriodProgress.refreshKey);
      expect(find.text('บันทึกแล้ว 30 จาก 30 หน่วยงาน'), findsOneWidget);
      expect(status(tester), PeriodProgress.doneLabel);
    });

    testWidgets(
      'backend ยังไม่มีเส้น: ขั้นนี้เป็นทางลัดไปหน้าบันทึกข้อมูล ไม่พัง',
      (tester) async {
        backend.p3.divStatusMissing = true;
        await pump(tester, screen: host());
        expect(tester.takeException(), isNull);
        expect(status(tester), isNull);
        expect(find.textContaining('จาก 30 หน่วยงาน'), findsNothing);
        expect(find.textContaining('แก้ยอดหลังเตรียมงวด'), findsOneWidget);
        await tapKey(tester, PeriodProgress.stepKey(5));
        expect(find.byType(DebtEntryScreen), findsOneWidget);
      },
    );

    testWidgets(
      'งวดไม่มีประวัติการแก้ไข: ไม่บอกจำนวนที่บันทึกแล้ว กดไปหน้าสถานะได้',
      (tester) async {
        backend.p3.auditAvailable = false;
        await pump(tester, screen: host());
        expect(status(tester), isNull);
        expect(find.textContaining('จาก 30 หน่วยงาน'), findsNothing);
        await tapKey(tester, PeriodProgress.stepKey(5));
        expect(find.byType(DivStatusScreen), findsOneWidget);
        expect(find.byKey(DivStatusScreen.noAuditKey), findsOneWidget);
      },
    );
  });
}
