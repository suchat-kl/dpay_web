// เทสต์ "บันทึกข้อมูลธนาคาร" ของฝ่ายบัญชี: ทะเบียน กบข/กสจ. สหกรณ์และภาษี (ฟอร์มรายคน)
// และเลขที่บัญชีเงินกู้ (ตารางแก้ในแถว) รวมตัวค้นหาบุคคลด้วยเลขบัตร/ชื่อ

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/screens/deduct_screen.dart';
import 'package:dpay/screens/loan_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/services/debt_api.dart';
import 'package:dpay/utils/money.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/person_finder.dart';
import 'package:dpay/widgets/screen_parts.dart';
import 'package:dpay/widgets/sheet_table.dart';

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

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => signIn(FakeBackend.account));
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

  /// ค้นด้วยเลขบัตรของคนลำดับที่ [n]
  Future<void> findById(WidgetTester tester, String idcard) async {
    await tester.enterText(find.byKey(PersonFinder.idcardKey), idcard);
    await tester.tap(find.byKey(PersonFinder.idcardButtonKey));
    await tester.pumpAndSettle();
  }

  Finder labeled(String label) => find.widgetWithText(TextFormField, label);
  String textOf(WidgetTester tester, Finder f) => tester
      .widget<TextField>(
        find.descendant(of: f, matching: find.byType(TextField)),
      )
      .controller!
      .text;

  group('ตัวค้นหาบุคคล', () {
    testWidgets('เลขบัตรผิดหลักตรวจสอบ: เตือน ไม่เรียก backend', (
      tester,
    ) async {
      await pump(tester, DeductScreen(apiService: api));
      backend.clearLog();
      final valid = fakeIdCard(1);
      await findById(
        tester,
        '${valid.substring(0, 12)}${(int.parse(valid[12]) + 1) % 10}',
      );
      expect(find.text(IdCard.invalidMessage), findsOneWidget);
      expect(backend.calls, isEmpty);
    });

    testWidgets(
      'ค้นด้วยชื่อ: POST /api/persons/search ทุกหน่วยงาน (ชื่อไม่อยู่ใน URL) เลือกจากรายการ เลขบัตรในรายการปิดบางส่วน',
      (tester) async {
        await pump(tester, DeductScreen(apiService: api));
        backend.clearLog();

        await tester.tap(find.byKey(PersonFinder.nameButtonKey));
        await tester.pumpAndSettle();
        expect(find.text(PersonFinder.nameRequired), findsOneWidget);
        expect(backend.calls, isEmpty);

        await tester.enterText(find.byKey(PersonFinder.nameKey), 'สมมุติ01');
        await tester.tap(find.byKey(PersonFinder.nameButtonKey));
        await tester.pumpAndSettle();
        expect(backend.calls, ['POST /api/persons/search']);
        expect(backend.queryOf('POST /api/persons/search'), isEmpty);
        expect(backend.bodyOf('POST /api/persons/search'), {
          'name': 'สมมุติ01',
        });
        expect(find.text(PersonFinder.truncatedText), findsNothing);
        expect(find.text('นายสมมุติ01 ตัวอย่าง'), findsOneWidget);
        // เลขบัตรเต็มไม่แสดงในรายการผลค้น
        expect(find.textContaining(fakeIdCard(1)), findsNothing);
        expect(find.textContaining('xxxxx'), findsOneWidget);

        await tester.tap(find.byKey(PersonFinder.resultKey(0)));
        await tester.pumpAndSettle();
        expect(backend.bodyOf('POST /api/persons/lookup'), {
          'idcard': fakeIdCard(1),
        });
        expect(backend.bodyOf('POST /api/deducts/find'), {
          'idcard': fakeIdCard(1),
        });
        // เลขบัตรไม่อยู่ใน path ของคำขอใดเลย
        expect(backend.calls.every((c) => !c.contains(fakeIdCard(1))), isTrue);
        expect(find.byKey(DeductScreen.personKey), findsOneWidget);
      },
    );

    testWidgets('ค้นชื่อแล้วไม่พบ', (tester) async {
      await pump(tester, LoanScreen(apiService: api));
      await tester.enterText(
        find.byKey(PersonFinder.surnameKey),
        'ไม่มีนามสกุลนี้',
      );
      await tester.tap(find.byKey(PersonFinder.nameButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(PersonFinder.noResult), findsOneWidget);
    });
  });

  group('กบข/กสจ. สหกรณ์และภาษี', () {
    final save = find.byKey(DeductScreen.saveKey);

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('เปิดหน้า: โหลดธนาคารและจังหวัดจากข้อมูลหลัก ยังไม่แสดงฟอร์ม', (
      tester,
    ) async {
      await pump(tester, DeductScreen(apiService: api));
      expect(backend.calls, [
        'GET /api/master/banks',
        'GET /api/master/provinces',
      ]);
      expect(find.text(DeductScreen.menuTitle), findsOneWidget);
      expect(find.byKey(DeductScreen.saveKey), findsNothing);
    });

    testWidgets(
      'พบทะเบียนเดิม: เติมค่าเดิม วันที่เป็นวันที่ไทย สาขาตามธนาคาร แก้แล้วส่งเฉพาะช่องที่เปลี่ยน',
      (tester) async {
        await pump(tester, DeductScreen(apiService: api));
        await findById(tester, fakeIdCard(1));

        expect(find.text('นายสมมุติ01 ตัวอย่าง'), findsOneWidget);
        expect(find.text(DeductScreen.newText), findsNothing);
        expect(backend.queryOf('GET /api/master/branches'), {
          'page': 0,
          'size': 2000,
          'bank_code': '006',
        });
        expect(
          textOf(tester, labeled('เลขที่บัญชีธนาคาร (10-15 หลัก)')),
          '1234567890',
        );
        expect(textOf(tester, labeled('เลขสมาชิกสหกรณ์')), '123');
        expect(textOf(tester, labeled('เบี้ยประกันชีวิต')), '12000.00');
        expect(textOf(tester, labeled('เงินบริจาค')), '');
        // kbk_dmy 01102550 = 1 ตุลาคม 2550
        expect(find.text('1 ตุลาคม 2550'), findsOneWidget);
        expect(find.text('006 ธนาคารตัวอย่างหนึ่ง'), findsOneWidget);
        expect(find.text('0001 สาขาตัวอย่างหนึ่ง'), findsOneWidget);
        expect(find.textContaining('วันบรรจุ 1 ตุลาคม 2545'), findsOneWidget);
        expect(find.textContaining('รหัสสหกรณ์ S01'), findsOneWidget);
        expect(find.byKey(DeductScreen.deleteKey), findsOneWidget);

        // ไม่แก้อะไรแล้วกดบันทึก: ไม่เรียก backend
        backend.clearLog();
        await submit(tester);
        expect(find.text('ไม่มีการแก้ไข'), findsOneWidget);
        expect(backend.calls, isEmpty);
        await settleSnackBar(tester);

        await tester.enterText(
          labeled('เลขที่บัญชีธนาคาร (10-15 หลัก)'),
          '9876543210123',
        );
        await tester.enterText(labeled('เงินบริจาค'), '1,500.5');
        await tester.enterText(labeled('เลขสมาชิกสหกรณ์'), '');
        await submit(tester);

        final id = 'deduct1'.padRight(24, '0');
        expect(backend.bodyOf('PUT /api/deducts/$id'), {
          'bank_acc': '9876543210123',
          'saha_id': '',
          'donate_amt': '1500.50',
        });
        expect(find.text(DeductScreen.savedMessage), findsOneWidget);
        expect(backend.p2.deducts.first['bank_acc'], '9876543210123');
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'เปลี่ยนธนาคาร: สาขาเดิมถูกล้าง โหลดสาขาของธนาคารใหม่ และเลือกจังหวัดเติมชื่อจังหวัดให้',
      (tester) async {
        await pump(tester, DeductScreen(apiService: api));
        await findById(tester, fakeIdCard(1));

        await tester.tap(find.text('006 ธนาคารตัวอย่างหนึ่ง'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('014 ธนาคารตัวอย่างสอง').last);
        await tester.pumpAndSettle();
        expect(
          backend.queryOf('GET /api/master/branches')!['bank_code'],
          '014',
        );
        expect(find.text('0001 สาขาตัวอย่างหนึ่ง'), findsNothing);

        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'สาขาธนาคาร'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('0101 สาขาตัวอย่างสาม').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('10 จังหวัดตัวอย่างหนึ่ง'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('50 จังหวัดตัวอย่างสอง').last);
        await tester.pumpAndSettle();
        await submit(tester);

        final id = 'deduct1'.padRight(24, '0');
        expect(backend.bodyOf('PUT /api/deducts/$id'), {
          'bank_code': '014',
          'bank_brch': '0101',
          'bank_prov': 'จังหวัดตัวอย่างสอง',
          'prov_code': '50',
        });
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'ยังไม่มีทะเบียน: ค่าเริ่มต้น (ประเภทตามบุคคล สถานะ = ใช้) เลือกวันที่ด้วยปฏิทิน พ.ศ. แล้วสร้างใหม่',
      (tester) async {
        final picked = <DateTime?>[];
        await pump(
          tester,
          DeductScreen(
            apiService: api,
            datePicker: (context, initial) async {
              picked.add(initial);
              return DateTime(2540, 3, 27 - 0).copyWith(year: 1997);
            },
          ),
        );
        await findById(tester, fakeIdCard(26));

        expect(find.text('นางสมมุติ26 ตัวอย่าง'), findsOneWidget);
        expect(find.text(DeductScreen.newText), findsOneWidget);
        expect(find.byKey(DeductScreen.deleteKey), findsNothing);
        // คนลำดับ 26 เป็นลูกจ้างประจำในงวดปัจจุบัน
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const ValueKey('deduct-emp_type-E')),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const ValueKey('deduct-rec_flg-0')),
              )
              .selected,
          isTrue,
        );

        await tester.enterText(
          labeled('เลขที่บัญชีธนาคาร (10-15 หลัก)'),
          '123',
        );
        await submit(tester);
        expect(find.textContaining('ต้องมีอย่างน้อย 10 หลัก'), findsOneWidget);
        expect(backend.calls, isNot(contains('POST /api/deducts')));

        await tester.enterText(
          labeled('เลขที่บัญชีธนาคาร (10-15 หลัก)'),
          '1234567890',
        );
        await tester.tap(find.byKey(DeductScreen.fieldKey('kbk_dmy')));
        await tester.pumpAndSettle();
        expect(picked, [null]);
        expect(find.text('27 มีนาคม 2540'), findsOneWidget);
        await tester.enterText(
          labeled(DeductScreen.amountFields['rmf_amt']!),
          '5000',
        );
        await submit(tester);

        expect(backend.bodyOf('POST /api/deducts'), {
          'id_card': fakeIdCard(26),
          'emp_type': 'E',
          'bank_acc': '1234567890',
          'kbk_flg': '1',
          'kbk_type': '1',
          'kbk_dmy': '27032540',
          'rec_flg': '0',
          'rmf_amt': '5000.00',
        });
        expect(find.text(DeductScreen.savedMessage), findsOneWidget);
        // โหลดใหม่เป็นรายการที่มีอยู่แล้ว
        expect(find.text(DeductScreen.newText), findsNothing);
        expect(find.byKey(DeductScreen.deleteKey), findsOneWidget);
        expect(backend.p2.deducts, hasLength(2));
        await settleSnackBar(tester);
      },
    );

    testWidgets('จำนวนเงินผิดรูป: เตือนใต้ช่อง ไม่เรียก backend', (
      tester,
    ) async {
      await pump(tester, DeductScreen(apiService: api));
      await findById(tester, fakeIdCard(1));
      backend.clearLog();
      await tester.enterText(
        labeled(DeductScreen.amountFields['ltf_amt']!),
        '1.234',
      );
      await submit(tester);
      expect(find.text(Money.invalidMessage), findsOneWidget);
      expect(backend.calls, isEmpty);
    });

    testWidgets('backend รายงาน duplicates: แจ้งให้ลบรายการที่เกิน', (
      tester,
    ) async {
      backend.p2.deductDuplicates[fakeIdCard(1)] = 2;
      await pump(tester, DeductScreen(apiService: api));
      await findById(tester, fakeIdCard(1));
      expect(find.byKey(DeductScreen.duplicatesKey), findsOneWidget);
      expect(find.textContaining('ซ้ำ 2 รายการ'), findsOneWidget);
    });

    testWidgets(
      'ไม่พบบุคคลใน DPIS: เตือน แต่ยังสร้างทะเบียนได้เมื่อเลือกประเภท',
      (tester) async {
        await pump(tester, DeductScreen(apiService: api));
        await findById(tester, fakeIdCard(777));
        expect(find.text(DeductScreen.notFoundText), findsOneWidget);

        await submit(tester);
        expect(find.text('กรุณาเลือกประเภทบุคลากร'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('deduct-emp_type-G')));
        await tester.pumpAndSettle();
        await submit(tester);
        expect(backend.bodyOf('POST /api/deducts'), {
          'id_card': fakeIdCard(777),
          'emp_type': 'G',
          'kbk_flg': '1',
          'kbk_type': '1',
          'rec_flg': '0',
        });
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'ช่อง กบข/กสจ: ป้ายไทยแทนตัวเลข ค่าที่เก็บยังเป็น 0/1 ไม่เป็นสมาชิก = ช่องที่เหลือของกลุ่มปิด',
      (tester) async {
        await pump(tester, DeductScreen(apiService: api));
        await findById(tester, fakeIdCard(1));

        for (final label in [
          DeductScreen.statusLabel,
          DeductScreen.kbkMemberLabel,
          DeductScreen.kbkSavingLabel,
          DeductScreen.kbkStartLabel,
          DeductScreen.kbkExtraDateLabel,
          'อัตราร้อยละการสะสม',
          'อัตราร้อยละการสะสมกรณีสมัครใจ',
          'ธนาคาร',
          'สาขาธนาคาร',
          'จังหวัด',
          'เลขสมาชิกสหกรณ์',
          'เลขสมาชิกฌาปนกิจ',
          'เงินบริจาค',
          'ดอกเบี้ยเงินกู้เพื่อที่อยู่อาศัย',
          'เบี้ยประกันชีวิต',
          'ค่าซื้อหน่วยลงทุนในกองทุนรวมเพื่อการเลี้ยงชีพ (RMF)',
          'ค่าซื้อหน่วยลงทุนในกองทุนระยะยาว (LTF)',
        ]) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        for (final text in ['ไม่เป็นสมาชิก', 'เป็นสมาชิก', 'ไม่สะสม', 'สะสม']) {
          expect(find.widgetWithText(ChoiceChip, text), findsOneWidget);
        }
        // ไม่มีตัวเลือกที่เป็นตัวเลข 0/1 ลอย ๆ
        expect(find.widgetWithText(ChoiceChip, '0'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, '1'), findsNothing);
        expect(
          find.textContaining('วันที่ปรับปรุง 15 มิถุนายน 2568'),
          findsOneWidget,
        );

        ChoiceChip chip(String key) =>
            tester.widget<ChoiceChip>(find.byKey(ValueKey(key)));
        // ทะเบียนตัวอย่าง: kbk_flg 1 (เป็นสมาชิก) kbk_type 0 (ไม่สะสม)
        expect(chip('deduct-kbk_flg-1').selected, isTrue);
        expect(chip('deduct-kbk_type-0').selected, isTrue);
        expect(chip('deduct-kbk_type-1').onSelected, isNotNull);
        expect(
          tester.widget<TextFormField>(labeled('อัตราร้อยละการสะสม')).enabled,
          isTrue,
        );

        await tester.tap(find.byKey(const ValueKey('deduct-kbk_flg-0')));
        await tester.pumpAndSettle();
        expect(find.text(DeductScreen.notMemberNote), findsOneWidget);
        expect(chip('deduct-kbk_type-1').onSelected, isNull);
        expect(
          tester.widget<TextFormField>(labeled('อัตราร้อยละการสะสม')).enabled,
          isFalse,
        );
        expect(
          tester
              .widget<TextFormField>(labeled('อัตราร้อยละการสะสมกรณีสมัครใจ'))
              .enabled,
          isFalse,
        );
        expect(
          tester
              .widget<InkWell>(find.byKey(DeductScreen.fieldKey('kbk_dmy')))
              .onTap,
          isNull,
        );

        // บันทึก: ส่งเฉพาะช่องที่เปลี่ยน ค่าของช่องที่ปิดไม่ถูกล้าง
        backend.clearLog();
        await submit(tester);
        final id = 'deduct1'.padRight(24, '0');
        expect(backend.bodyOf('PUT /api/deducts/$id'), {'kbk_flg': '0'});
        expect(backend.p2.deducts.first['kbk_pct'], '3');
        expect(backend.p2.deducts.first['kbk_dmy'], '01102550');
        await settleSnackBar(tester);
      },
    );

    testWidgets('ลบทะเบียน: ถามยืนยัน แล้วกลับเป็นสร้างใหม่', (tester) async {
      await pump(tester, DeductScreen(apiService: api));
      await findById(tester, fakeIdCard(1));
      final delete = find.byKey(DeductScreen.deleteKey);
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('ลบทะเบียนของ นายสมมุติ01 ตัวอย่าง'),
        findsOneWidget,
      );
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(
        backend.calls,
        contains('DELETE /api/deducts/${'deduct1'.padRight(24, '0')}'),
      );
      expect(backend.p2.deducts, isEmpty);
      expect(find.text(DeductScreen.newText), findsOneWidget);
      await settleSnackBar(tester);
    });
  });

  group('เลขที่บัญชีเงินกู้', () {
    final save = find.byKey(LoanScreen.saveKey);
    Finder cell(int row, String field) => find.descendant(
      of: find.byKey(LoanScreen.cellKey(row, field)),
      matching: find.byType(TextFormField),
    );
    bool saveEnabled(WidgetTester tester) =>
        tester.widget<PrimaryActionButton>(save).onPressed != null;

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('แสดงบัญชีของบุคคลเรียงตามลำดับ ป้ายโครงการ ไม่มีตัวเลือก 4', (
      tester,
    ) async {
      await pump(tester, LoanScreen(apiService: api));
      await findById(tester, fakeIdCard(1));

      expect(backend.bodyOf('POST /api/loans/find'), {'idcard': fakeIdCard(1)});
      expect(find.text('นายสมมุติ01 ตัวอย่าง'), findsOneWidget);
      expect(textOf(tester, cell(0, 'ghb_acc')), '1111111111');
      expect(textOf(tester, cell(1, 'ghb_acc')), '2222222222');
      expect(textOf(tester, cell(1, 'amt')), '1200.75');
      expect(textOf(tester, cell(0, 'year')), '2565');
      expect(find.text('ธอส.'), findsOneWidget);
      expect(find.text('ออมสิน'), findsOneWidget);
      expect(LoanScreen.flgNames.keys, ['1', '2', '3', '5', '6']);
      expect(LoanScreen.flgNames.containsKey('4'), isFalse);
      expect(saveEnabled(tester), isFalse);
      expect(find.byKey(LoanScreen.dirtyKey), findsNothing);

      // ตัวเลือกโครงการ: 5 รายการ ไม่มี 4
      await tester.tap(find.text('ธอส.'));
      await tester.pumpAndSettle();
      for (final name in LoanScreen.flgNames.values) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(find.textContaining('ธอท'), findsNothing);
      await tester.tap(find.text('ธอส. โครงการ 2').last);
      await tester.pumpAndSettle();
      expect(find.byKey(LoanScreen.dirtyKey), findsOneWidget);
    });

    testWidgets(
      'แก้ในแถว เพิ่มแถว ลบแถว แล้วบันทึก: ลบก่อน สร้างแถวใหม่ แก้เฉพาะช่องที่เปลี่ยน',
      (tester) async {
        await pump(tester, LoanScreen(apiService: api));
        await findById(tester, fakeIdCard(1));
        backend.clearLog();

        // แก้จำนวนเงินของแถวแรก
        await tester.enterText(cell(0, 'amt'), '5,500');
        await tester.pumpAndSettle();
        expect(find.text(LoanScreen.dirtyText), findsOneWidget);

        // ลบแถวที่สอง (เอาออกจากหน้าจอ)
        await tester.tap(find.byKey(LoanScreen.checkKey(1)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(SheetButton.deleteLabel));
        await tester.pumpAndSettle();
        expect(find.textContaining('กดบันทึกเพื่อยืนยัน'), findsOneWidget);
        await settleSnackBar(tester);
        expect(backend.calls, isEmpty);

        // เพิ่มแถวใหม่: ลำดับถัดไป ลำดับย่อย 1
        await tester.tap(find.text(SheetButton.addLabel));
        await tester.pumpAndSettle();
        expect(textOf(tester, cell(1, 'seq')), '2');
        expect(textOf(tester, cell(1, 'subseq')), '1');

        // แถวใหม่ยังกรอกไม่ครบ: บอกแถว ไม่เรียก backend
        await submit(tester);
        expect(
          find.text('แถวที่ 2 เลขที่บัญชีต้องเป็นตัวเลข 10-15 หลัก'),
          findsOneWidget,
        );
        await tester.enterText(cell(1, 'ghb_acc'), '3333333333');
        await tester.pumpAndSettle();
        await submit(tester);
        expect(find.text('แถวที่ 2 ยังไม่ได้เลือกโครงการ'), findsOneWidget);
        expect(backend.calls, isEmpty);

        await tester.tap(find.byKey(LoanScreen.cellKey(1, 'flg')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('กรุงไทย').last);
        await tester.pumpAndSettle();
        await tester.enterText(cell(1, 'year'), '2568');
        await tester.enterText(cell(1, 'amt'), '800');
        await tester.pumpAndSettle();
        await submit(tester);

        // บันทึกทั้งชุดในคำขอเดียว: ทุกบัญชีของคนนั้นหลังบันทึก (บัญชีที่ลบออกไม่อยู่ในชุด)
        expect(backend.calls.first, 'PUT /api/loans/set');
        expect(backend.count('PUT /api/loans/set'), 1);
        expect(
          backend.calls.where(
            (c) => c.startsWith('DELETE ') || c == 'POST /api/loans',
          ),
          isEmpty,
        );
        expect(backend.bodyOf('PUT /api/loans/set'), {
          'id_card': fakeIdCard(1),
          'items': [
            {
              'emp_type': 'G',
              'ghb_acc': '1111111111',
              'flg': '1',
              'year': '2565',
              'seq': '1',
              'subseq': '1',
              'amt': '5500.00',
            },
            {
              'emp_type': 'G',
              'ghb_acc': '3333333333',
              'flg': '6',
              'year': '2568',
              'seq': '2',
              'subseq': '1',
              'amt': '800.00',
            },
          ],
        });
        expect(find.text(LoanScreen.savedMessage), findsOneWidget);
        // โหลดใหม่: ไม่มีแก้ไขค้าง
        expect(find.byKey(LoanScreen.dirtyKey), findsNothing);
        expect(saveEnabled(tester), isFalse);
        expect(backend.p2.loans.map((l) => l['ghb_acc']), [
          '1111111111',
          '3333333333',
        ]);
        await settleSnackBar(tester);
      },
    );

    testWidgets('เลขที่บัญชีซ้ำในตาราง: เตือนก่อนส่ง', (tester) async {
      await pump(tester, LoanScreen(apiService: api));
      await findById(tester, fakeIdCard(1));
      backend.clearLog();
      await tester.enterText(cell(1, 'ghb_acc'), '1111111111');
      await tester.pumpAndSettle();
      await submit(tester);
      expect(
        find.text('เลขที่บัญชี 1111111111 ซ้ำกัน (แถวที่ 1 และ 2)'),
        findsOneWidget,
      );
      expect(backend.calls, isEmpty);
    });

    testWidgets(
      'ยังไม่มีบัญชี: ตารางว่าง เลือกทั้งหมดกดไม่ได้ เพิ่มแล้วบันทึกได้',
      (tester) async {
        await pump(tester, LoanScreen(apiService: api));
        await findById(tester, fakeIdCard(26));

        expect(find.text(LoanScreen.emptyText), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, SheetButton.selectAllLabel),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text(SheetButton.addLabel));
        await tester.pumpAndSettle();
        await tester.enterText(cell(0, 'ghb_acc'), '4444444444');
        await tester.tap(find.byKey(LoanScreen.cellKey(0, 'flg')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ออมสิน').last);
        await tester.pumpAndSettle();
        await submit(tester);

        final sent =
            (backend.bodyOf('PUT /api/loans/set')!['items'] as List).single
                as Map;
        expect(sent['emp_type'], 'E');
        expect(sent['flg'], '5');
        expect(backend.p2.loans, hasLength(3));
        await settleSnackBar(tester);
      },
    );

    testWidgets('มีแก้ไขค้างแล้วค้นคนใหม่: ถามก่อนทิ้ง', (tester) async {
      await pump(tester, LoanScreen(apiService: api));
      await findById(tester, fakeIdCard(1));
      await tester.enterText(cell(0, 'amt'), '1');
      await tester.pumpAndSettle();
      backend.clearLog();

      await findById(tester, fakeIdCard(26));
      expect(find.textContaining('ต้องการทิ้งการแก้ไขหรือไม่'), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);
      expect(find.text('นายสมมุติ01 ตัวอย่าง'), findsOneWidget);
    });
  });

  group('สิทธิ์และกติกาของ backend (เส้น API)', () {
    test('ทะเบียนและเงินกู้ใช้ได้เฉพาะ ACCOUNT', () async {
      await signIn(FakeBackend.user);
      for (final call in [
        () => api.lookupPerson(fakeIdCard(1)),
        () => api.findDeduct(fakeIdCard(1)),
        () => api.findLoans(fakeIdCard(1)),
        () => api.setLoans(fakeIdCard(1), const []),
        () => api.searchPersons(name: 'สมมุติ'),
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
      expect(backend.p2.loans, hasLength(2));
    });

    test('ทะเบียนซ้ำ / โครงการ 4 / เลขบัญชีซ้ำของคนเดียวกัน', () async {
      await signIn(FakeBackend.account);
      await expectLater(
        api.saveDeduct('', {'id_card': fakeIdCard(1), 'emp_type': 'G'}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.duplicate,
          ),
        ),
      );
      await expectLater(
        api.setLoans(fakeIdCard(1), [
          {'emp_type': 'G', 'ghb_acc': '5555555555', 'flg': '4'},
        ]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.badRequest,
          ),
        ),
      );
      await expectLater(
        api.setLoans(fakeIdCard(1), [
          {'emp_type': 'G', 'ghb_acc': '1111111111', 'flg': '1'},
          {'emp_type': 'G', 'ghb_acc': '1111111111', 'flg': '5'},
        ]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.duplicate,
          ),
        ),
      );
      // ไม่ผ่านรายการเดียว = ไม่บันทึกอะไรเลย
      expect(backend.p2.loans.map((l) => l['ghb_acc']), [
        '1111111111',
        '2222222222',
      ]);
      final person = await api.lookupPerson(fakeIdCard(777));
      expect(person.found, isFalse);
      expect(person.fullName, '');
    });
  });
}
