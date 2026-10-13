// เทสต์ "บันทึกรายการหลัก" (ธนาคาร สาขา รหัสหนี้ หน่วยงาน) — ตารางแก้ไขในแถว
// แก้หลายแถวแล้วบันทึกครั้งเดียว เพิ่มแถว ลบที่เลือก เลือกทั้งหมด ข้อผิดพลาดรายแถว
// เตือนก่อนทิ้งการแก้ไข และสาขาตามธนาคาร

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/models/master_data.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/screens/master_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/widgets/app_pagination.dart';
import 'package:dpay/widgets/screen_parts.dart';
import 'package:dpay/widgets/sheet_table.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
  });

  tearDown(() => auth.logout());

  Future<void> pump(
    WidgetTester tester,
    MasterResource resource, {
    String username = FakeBackend.account,
  }) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => auth.login(username, FakeBackend.passwordOf(username)),
    );
    backend.clearLog();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MasterScreen(apiService: api, resource: resource),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Finder cell(int row, String field) =>
      find.byKey(MasterScreen.cellKey(row, field));

  String textOf(WidgetTester tester, int row, String field) => tester
      .widget<EditableText>(
        find.descendant(
          of: cell(row, field),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  Future<void> type(
    WidgetTester tester,
    int row,
    String field,
    String text,
  ) async {
    await tester.enterText(cell(row, field), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(MasterScreen.saveKey));
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<PrimaryActionButton>(find.byKey(MasterScreen.saveKey))
          .onPressed !=
      null;

  String errorOf(WidgetTester tester, int row) =>
      tester.widget<Text>(find.byKey(MasterScreen.errorKey(row))).data!;

  List<String> writes() => [
    for (final c in backend.calls)
      if (!c.startsWith('GET ')) c,
  ];

  group('แก้ไขในแถว', () {
    testWidgets('ทุกแถวเป็นช่องกรอก ยังไม่แก้ = ปุ่มบันทึกกดไม่ได้', (
      tester,
    ) async {
      await pump(tester, MasterResource.banks);
      expect(backend.calls, ['GET /api/master/banks']);
      expect(textOf(tester, 0, 'bank_code'), '006');
      expect(textOf(tester, 1, 'bank_code'), '014');
      expect(textOf(tester, 2, 'bank_name'), 'ธนาคารตัวอย่างสาม');
      expect(find.byKey(MasterScreen.dirtyKey), findsNothing);
      expect(saveEnabled(tester), isFalse);
      // ไม่มีปุ่มแก้ไขรายแถว/หน้าต่างแก้ไขอีกแล้ว
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets(
      'แก้หลายแถวแล้วบันทึกครั้งเดียว: PUT เฉพาะแถวและช่องที่เปลี่ยน',
      (tester) async {
        await pump(tester, MasterResource.banks);
        await type(tester, 0, 'bank_name', 'ธนาคารแก้ไขหนึ่ง');
        await type(tester, 2, 'shrt', 'TB9');
        await type(tester, 2, 'rec_no', '3');
        expect(find.byKey(MasterScreen.dirtyKey), findsOneWidget);
        expect(find.text(MasterScreen.dirtyText), findsOneWidget);
        backend.clearLog();

        await save(tester);
        expect(writes(), [
          'PUT /api/master/banks/bank006',
          'PUT /api/master/banks/bank030',
        ]);
        expect(backend.bodyOf('PUT /api/master/banks/bank006'), {
          'bank_name': 'ธนาคารแก้ไขหนึ่ง',
        });
        expect(backend.bodyOf('PUT /api/master/banks/bank030'), {
          'shrt': 'TB9',
          'rec_no': '3',
        });
        // บันทึกครบ: โหลดใหม่ ไม่เหลือการแก้ไขค้าง
        expect(backend.calls.last, 'GET /api/master/banks');
        expect(find.byKey(MasterScreen.dirtyKey), findsNothing);
        expect(saveEnabled(tester), isFalse);
        expect(textOf(tester, 0, 'bank_name'), 'ธนาคารแก้ไขหนึ่ง');
        await settleSnackBar(tester);
      },
    );

    testWidgets('พิมพ์แล้วแก้กลับเป็นค่าเดิม = ไม่ถือว่าแก้', (tester) async {
      await pump(tester, MasterResource.banks);
      await type(tester, 1, 'shrt', 'XX');
      expect(saveEnabled(tester), isTrue);
      await type(tester, 1, 'shrt', 'TB2');
      expect(find.byKey(MasterScreen.dirtyKey), findsNothing);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('หน่วยงาน: ส่วนกลางเป็นตัวเลือกในแถว', (tester) async {
      await pump(tester, MasterResource.divs);
      expect(textOf(tester, 0, 'div'), '901');
      await tester.tap(cell(0, 'center_dept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ส่วนกลาง').last);
      await tester.pumpAndSettle();
      backend.clearLog();
      await save(tester);
      expect(writes(), ['PUT /api/master/divs/div901']);
      expect(backend.bodyOf('PUT /api/master/divs/div901'), {
        'center_dept': 't',
      });
      await settleSnackBar(tester);
    });
  });

  group('เพิ่มแถว', () {
    testWidgets(
      'เพิ่มต่อท้ายหน้าปัจจุบัน ตรวจในแถวก่อนส่ง แล้ว POST เฉพาะแถวใหม่',
      (tester) async {
        await pump(tester, MasterResource.banks);
        backend.clearLog();
        await tester.tap(find.text(SheetButton.addLabel));
        await tester.pumpAndSettle();
        expect(cell(3, 'bank_code'), findsOneWidget);
        expect(textOf(tester, 3, 'bank_code'), '');
        expect(find.byKey(MasterScreen.dirtyKey), findsOneWidget);

        // แถวว่าง: แจ้งที่แถว ไม่เรียก backend
        await save(tester);
        expect(backend.calls, isEmpty);
        expect(find.text(MasterScreen.fixRowsMessage), findsOneWidget);
        expect(errorOf(tester, 3), contains('กรุณากรอกรหัสธนาคาร'));
        expect(errorOf(tester, 3), contains('กรุณากรอกชื่อธนาคาร'));

        // รูปแบบรหัสไม่ถูก
        await type(tester, 3, 'bank_code', '12');
        await type(tester, 3, 'bank_name', 'ธนาคารตัวอย่างใหม่');
        await type(tester, 3, 'rec_no', '4');
        await save(tester);
        expect(backend.calls, isEmpty);
        expect(errorOf(tester, 3), 'รหัสธนาคารต้องยาว 3 หลัก');

        // รหัสซ้ำกับแถวอื่นในหน้าเดียวกัน
        await type(tester, 3, 'bank_code', '006');
        await save(tester);
        expect(backend.calls, isEmpty);
        expect(errorOf(tester, 3), MasterScreen.duplicateInPage);

        await type(tester, 3, 'bank_code', '025');
        await save(tester);
        expect(writes(), ['POST /api/master/banks']);
        expect(backend.bodyOf('POST /api/master/banks'), {
          'bank_code': '025',
          'bank_name': 'ธนาคารตัวอย่างใหม่',
          'rec_no': '4',
        });
        expect(find.byKey(MasterScreen.dirtyKey), findsNothing);
        expect(find.text('025'), findsOneWidget);
        expect(backend.p2.masters['banks'], hasLength(4));
        await settleSnackBar(tester);
      },
    );

    testWidgets('รหัสหนี้ 40604 ยกเลิกแล้ว: ไม่แสดงและเพิ่มไม่ได้', (
      tester,
    ) async {
      await pump(tester, MasterResource.debtCodes);
      expect(find.text(MasterResource.cancelledDebtCode), findsNothing);
      backend.clearLog();
      await tester.tap(find.text(SheetButton.addLabel));
      await tester.pumpAndSettle();
      await type(tester, 5, 'mcode', MasterResource.cancelledDebtCode);
      await type(tester, 5, 'shrt', 'สโมสร');
      await save(tester);
      expect(backend.calls, isEmpty);
      expect(errorOf(tester, 5), MasterScreen.cancelledCodeMessage);
    });
  });

  group('ข้อผิดพลาดรายแถวจาก backend', () {
    testWidgets(
      'IN_USE: แถวที่ผ่านไม่ส่งซ้ำ แถวที่ไม่ผ่านคงค่าที่พิมพ์และแจ้งใต้แถว',
      (tester) async {
        await pump(tester, MasterResource.banks);
        // ธนาคาร 006 มีสาขาอ้างอยู่ แก้รหัสไม่ได้
        await type(tester, 0, 'bank_code', '007');
        await type(tester, 2, 'bank_name', 'ธนาคารแก้ไขสาม');
        backend.clearLog();
        await save(tester);
        expect(writes(), [
          'PUT /api/master/banks/bank006',
          'PUT /api/master/banks/bank030',
        ]);
        // ไม่โหลดใหม่ ค่าที่พิมพ์ยังอยู่
        expect(backend.calls, isNot(contains('GET /api/master/banks')));
        expect(textOf(tester, 0, 'bank_code'), '007');
        expect(errorOf(tester, 0), contains(FakeBackend.masterInUseMessage));
        expect(errorOf(tester, 0), contains(MasterScreen.inUseHint));
        expect(find.byKey(MasterScreen.errorKey(2)), findsNothing);
        expect(find.textContaining('บันทึกไม่สำเร็จ 1 แถว'), findsOneWidget);
        expect(find.byKey(MasterScreen.dirtyKey), findsOneWidget);
        expect(
          backend.p2.masters['banks']!.last['bank_name'],
          'ธนาคารแก้ไขสาม',
        );

        // กดบันทึกซ้ำ: ส่งเฉพาะแถวที่ยังไม่ผ่าน
        backend.clearLog();
        await save(tester);
        expect(writes(), ['PUT /api/master/banks/bank006']);

        // แก้กลับเป็นรหัสเดิม = ไม่มีอะไรค้าง
        await type(tester, 0, 'bank_code', '006');
        expect(find.byKey(MasterScreen.dirtyKey), findsNothing);
      },
    );

    testWidgets('DUPLICATE กับรายการนอกหน้าที่เห็น และ BAD_REQUEST', (
      tester,
    ) async {
      await pump(tester, MasterResource.debtCodes);
      await tester.enterText(find.byKey(MasterScreen.searchKey), 'AIA');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(backend.queryOf('GET /api/master/debt-codes')!['keyword'], 'AIA');
      expect(cell(1, 'mcode'), findsNothing);

      await tester.tap(find.text(SheetButton.addLabel));
      await tester.pumpAndSettle();
      await type(tester, 1, 'mcode', '40302');
      await type(tester, 1, 'shrt', 'รหัสซ้ำ');
      backend.clearLog();
      await save(tester);
      expect(writes(), ['POST /api/master/debt-codes']);
      expect(errorOf(tester, 1), contains(FakeBackend.masterDuplicateMessage));
      expect(errorOf(tester, 1), contains(MasterScreen.duplicateHint));
      expect(textOf(tester, 1, 'shrt'), 'รหัสซ้ำ');

      // แก้รหัสแล้วบันทึกผ่าน
      await type(tester, 1, 'mcode', '40999');
      await save(tester);
      expect(find.byKey(MasterScreen.dirtyKey), findsNothing);
      expect(
        backend.p2.masters['debt-codes']!.any((c) => c['mcode'] == '40999'),
        isTrue,
      );
      await settleSnackBar(tester);
    });

    testWidgets('BAD_REQUEST ของ backend แสดงที่แถวนั้น', (tester) async {
      await pump(tester, MasterResource.branches);
      await tester.tap(find.byKey(MasterScreen.bankFilterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('014 ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(SheetButton.addLabel));
      await tester.pumpAndSettle();
      await type(tester, 1, 'bank_brch', '0102');
      await type(tester, 1, 'name', 'สาขาตัวอย่างใหม่');
      // ธนาคารถูกลบไปจากอีกเครื่องระหว่างที่กรอก
      backend.p2.masters['banks']!.removeWhere((b) => b['bank_code'] == '014');
      await save(tester);
      expect(errorOf(tester, 1), contains('ไม่พบธนาคารรหัส 014'));
      expect(textOf(tester, 1, 'name'), 'สาขาตัวอย่างใหม่');
    });
  });

  group('ลบที่เลือก / เลือกทั้งหมด', () {
    testWidgets('ยังไม่เลือก: แจ้งเตือน ไม่เรียก backend', (tester) async {
      await pump(tester, MasterResource.banks);
      backend.clearLog();
      await tester.tap(find.text(SheetButton.deleteLabel));
      await tester.pump();
      expect(find.text(MasterScreen.nothingSelected), findsOneWidget);
      expect(backend.calls, isEmpty);
      await settleSnackBar(tester);
    });

    testWidgets(
      'เลือกทั้งหมดแล้วลบ: ลบทั้งชุดในคำขอเดียว รายการที่ถูกใช้อยู่ยังอยู่พร้อมเหตุผลใต้แถว แถวใหม่เอาออกเฉย ๆ',
      (tester) async {
        await pump(tester, MasterResource.banks);
        await tester.tap(find.text(SheetButton.addLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(SheetButton.selectAllLabel));
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          expect(
            tester.widget<Checkbox>(find.byKey(MasterScreen.checkKey(i))).value,
            isTrue,
          );
        }
        // กดซ้ำ = ยกเลิกทั้งหมด แล้วเลือกใหม่
        await tester.tap(find.text(SheetButton.selectAllLabel));
        await tester.pump();
        expect(
          tester.widget<Checkbox>(find.byKey(MasterScreen.checkKey(0))).value,
          isFalse,
        );
        await tester.tap(find.text(SheetButton.selectAllLabel));
        await tester.pump();

        backend.clearLog();
        await tester.tap(find.text(SheetButton.deleteLabel));
        await tester.pumpAndSettle();
        expect(find.textContaining('4 รายการที่เลือก'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'ลบ'));
        await tester.pumpAndSettle();

        // ลบทั้งชุดในคำขอเดียว (แถวใหม่ที่ยังไม่บันทึกไม่ถูกส่ง)
        expect(writes(), ['POST /api/master/banks/delete']);
        expect(backend.bodyOf('POST /api/master/banks/delete'), {
          'ids': ['bank006', 'bank014', 'bank030'],
        });
        // 006 และ 014 มีสาขา ลบไม่ได้ / 030 และแถวใหม่หายไป
        expect(cell(2, 'bank_code'), findsNothing);
        expect(textOf(tester, 0, 'bank_code'), '006');
        expect(errorOf(tester, 0), contains(FakeBackend.masterInUseMessage));
        expect(errorOf(tester, 1), contains('ลบไม่ได้'));
        expect(find.text('ลบแล้ว 2 รายการ ลบไม่ได้ 2 รายการ'), findsOneWidget);
        expect(backend.p2.masters['banks'], hasLength(2));
      },
    );

    testWidgets('ลบสำเร็จทั้งหมด: โหลดใหม่', (tester) async {
      await pump(tester, MasterResource.debtCodes);
      await tester.tap(find.byKey(MasterScreen.checkKey(4)));
      await tester.pump();
      backend.clearLog();
      await tester.tap(find.text(SheetButton.deleteLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'ลบ'));
      await tester.pumpAndSettle();
      expect(backend.calls, [
        'POST /api/master/debt-codes/delete',
        'GET /api/master/debt-codes',
      ]);
      expect(backend.bodyOf('POST /api/master/debt-codes/delete'), {
        'ids': ['code41100'],
      });
      expect(cell(4, 'mcode'), findsNothing);
      await settleSnackBar(tester);
    });
  });

  group('เตือนก่อนทิ้งการแก้ไข', () {
    Future<void> answer(WidgetTester tester, String button) async {
      expect(find.text(MasterScreen.discardQuestion), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, button));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'เรียงตามหัวคอลัมน์: ยกเลิก = คงค่าที่พิมพ์ / ทิ้ง = โหลดใหม่',
      (tester) async {
        await pump(tester, MasterResource.banks);
        // ยังไม่แก้: เรียงได้ทันที
        await tester.tap(find.text('รหัสธนาคาร *'));
        await tester.pumpAndSettle();
        expect(backend.queryOf('GET /api/master/banks')!['sort'], 'bank_code');
        expect(backend.queryOf('GET /api/master/banks')!['dir'], 'asc');

        await type(tester, 0, 'bank_name', 'ยังไม่บันทึก');
        backend.clearLog();
        await tester.tap(find.text('รหัสธนาคาร *'));
        await tester.pumpAndSettle();
        await answer(tester, 'ยกเลิก');
        expect(backend.calls, isEmpty);
        expect(textOf(tester, 0, 'bank_name'), 'ยังไม่บันทึก');

        await tester.tap(find.text('รหัสธนาคาร *'));
        await tester.pumpAndSettle();
        await answer(tester, 'ทิ้งการแก้ไข');
        expect(backend.calls, ['GET /api/master/banks']);
        expect(backend.queryOf('GET /api/master/banks')!['dir'], 'desc');
        expect(textOf(tester, 0, 'bank_code'), '030');
        expect(find.byKey(MasterScreen.dirtyKey), findsNothing);
      },
    );

    testWidgets('ค้นหา: ยกเลิกแล้วคำค้นกลับเป็นค่าเดิม', (tester) async {
      await pump(tester, MasterResource.banks);
      await type(tester, 0, 'bank_name', 'ยังไม่บันทึก');
      backend.clearLog();
      await tester.enterText(find.byKey(MasterScreen.searchKey), 'สอง');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await answer(tester, 'ยกเลิก');
      expect(backend.calls, isEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(MasterScreen.searchKey))
            .controller!
            .text,
        '',
      );
      expect(textOf(tester, 0, 'bank_name'), 'ยังไม่บันทึก');

      await tester.enterText(find.byKey(MasterScreen.searchKey), 'สอง');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await answer(tester, 'ทิ้งการแก้ไข');
      expect(backend.queryOf('GET /api/master/banks')!['keyword'], 'สอง');
      expect(textOf(tester, 0, 'bank_code'), '014');
      expect(cell(1, 'bank_code'), findsNothing);
    });

    testWidgets('เปลี่ยนหน้า (หน่วยงาน 30 รายการ)', (tester) async {
      await pump(tester, MasterResource.divs);
      expect(find.text('ทั้งหมด 30 รายการ'), findsOneWidget);
      expect(find.text('หน้า 1 จาก 3'), findsOneWidget);
      await type(tester, 0, 'divname', 'ยังไม่บันทึก');
      backend.clearLog();
      final page2 = find.descendant(
        of: find.byType(AppPagination),
        matching: find.text('2'),
      );
      await tester.tap(page2);
      await tester.pumpAndSettle();
      await answer(tester, 'ยกเลิก');
      expect(backend.calls, isEmpty);
      expect(find.text('หน้า 1 จาก 3'), findsOneWidget);

      await tester.tap(page2);
      await tester.pumpAndSettle();
      await answer(tester, 'ทิ้งการแก้ไข');
      expect(backend.queryOf('GET /api/master/divs')!['page'], 1);
      expect(find.text('หน้า 2 จาก 3'), findsOneWidget);
      expect(textOf(tester, 0, 'div'), '911');
    });
  });

  group('สาขาตามธนาคาร', () {
    Future<void> pickBank(WidgetTester tester, String code) async {
      await tester.tap(find.byKey(MasterScreen.bankFilterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('$code ').last);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'ต้องเลือกธนาคารก่อน เพิ่มสาขาเติม bank_code ให้ เปลี่ยนธนาคารขณะแก้ค้างต้องถาม',
      (tester) async {
        await pump(tester, MasterResource.branches);
        expect(find.text(MasterScreen.pickBankText), findsOneWidget);
        expect(backend.calls, ['GET /api/master/banks']);
        expect(find.byKey(MasterScreen.saveKey), findsNothing);

        await pickBank(tester, '006');
        expect(
          backend.queryOf('GET /api/master/branches')!['bank_code'],
          '006',
        );
        expect(textOf(tester, 0, 'bank_brch'), '0001');
        expect(textOf(tester, 1, 'bank_brch'), '0002');
        expect(cell(2, 'bank_brch'), findsNothing);

        await tester.tap(find.text(SheetButton.addLabel));
        await tester.pumpAndSettle();
        await type(tester, 2, 'bank_brch', '0003');
        await type(tester, 2, 'name', 'สาขาตัวอย่างใหม่');
        await type(tester, 0, 'name', 'สาขาแก้ไข');

        // เปลี่ยนธนาคารขณะมีการแก้ไขค้าง
        backend.clearLog();
        await pickBank(tester, '014');
        expect(find.text(MasterScreen.discardQuestion), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'ยกเลิก'));
        await tester.pumpAndSettle();
        expect(backend.calls, isEmpty);
        expect(textOf(tester, 2, 'bank_brch'), '0003');

        await save(tester);
        expect(writes(), [
          'PUT /api/master/branches/br0060001',
          'POST /api/master/branches',
        ]);
        expect(backend.bodyOf('PUT /api/master/branches/br0060001'), {
          'name': 'สาขาแก้ไข',
        });
        expect(backend.bodyOf('POST /api/master/branches'), {
          'bank_code': '006',
          'bank_brch': '0003',
          'name': 'สาขาตัวอย่างใหม่',
        });
        await settleSnackBar(tester);

        // ไม่มีอะไรค้าง: เปลี่ยนธนาคารได้เลย
        await pickBank(tester, '014');
        expect(find.text(MasterScreen.discardQuestion), findsNothing);
        expect(textOf(tester, 0, 'bank_brch'), '0101');
        expect(cell(1, 'bank_brch'), findsNothing);
      },
    );
  });

  group('สิทธิ์', () {
    testWidgets('ไม่ใช่ ACCOUNT: backend ปฏิเสธ แสดงข้อความ ไม่มีแถว', (
      tester,
    ) async {
      await pump(tester, MasterResource.banks, username: FakeBackend.user);
      expect(backend.calls, ['GET /api/master/banks']);
      expect(find.byType(NoticeBar), findsOneWidget);
      expect(cell(0, 'bank_code'), findsNothing);
    });
  });
}
