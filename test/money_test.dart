// เทสต์ตัวช่วยของระยะที่ 2: จำนวนเงิน (สตางค์) เลขประจำตัวประชาชน วันที่ ddMMyyyy พ.ศ. และโมเดลรายการหนี้

import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/models/debt.dart';
import 'package:dpay/models/master_data.dart';
import 'package:dpay/utils/money.dart';

import 'fake_backend.dart';

void main() {
  group('Money', () {
    test('อ่านข้อความที่พิมพ์เป็นสตางค์ ว่าง = 0 มีจุลภาคได้', () {
      expect(Money.parse(''), 0);
      expect(Money.parse(null), 0);
      expect(Money.parse('1500.5'), 150050);
      expect(Money.parse('1,500.50'), 150050);
      expect(Money.parse(' 20 '), 2000);
      expect(Money.parse('0.07'), 7);
      expect(Money.parse('12.'), 1200);
      expect(Money.parse('9999999.99'), Money.maxSatang);
    });

    test('ผิดรูป ติดลบ ทศนิยมเกิน 2 ตำแหน่ง หรือเกินช่วง = null', () {
      for (final bad in [
        'abc',
        '-1',
        '1.234',
        '10000000',
        '1.2.3',
        '.5',
        '1e3',
      ]) {
        expect(Money.parse(bad), isNull, reason: bad);
      }
    });

    test(
      'อ่าน JSON ของ backend (ตัวเลขหรือข้อความ) ไม่คลาดเคลื่อนจากทศนิยม',
      () {
        expect(Money.fromJson(1500.5), 150050);
        expect(Money.fromJson(1200.75), 120075);
        expect(Money.fromJson(0.1 + 0.2), 30);
        expect(Money.fromJson(20), 2000);
        expect(Money.fromJson('1,500.50'), 150050);
        expect(Money.fromJson(null), 0);
        expect(Money.fromJson('ไม่ใช่ตัวเลข'), 0);
      },
    );

    test('จัดรูปแสดงผล ช่องกรอก และค่าที่ส่ง backend', () {
      expect(Money.format(150050), '1,500.50');
      expect(Money.format(0), '0.00');
      expect(Money.format(Money.maxSatang), '9,999,999.99');
      expect(Money.input(0), '');
      expect(Money.input(150050), '1500.50');
      expect(Money.toJson(7), '0.07');
      expect(Money.toJson(200000), '2000.00');
    });
  });

  group('IdCard', () {
    test('ตรวจ 13 หลักและหลักตรวจสอบ', () {
      final valid = fakeIdCard(1);
      expect(IdCard.isValid(valid), isTrue);
      expect(
        IdCard.isValid('${valid.substring(0, 4)}-${valid.substring(4)} '),
        isTrue,
      );
      // เปลี่ยนหลักสุดท้าย = หลักตรวจสอบผิด
      final wrong =
          '${valid.substring(0, 12)}${(int.parse(valid[12]) + 1) % 10}';
      expect(IdCard.isValid(wrong), isFalse);
      for (final bad in ['', '123', '${valid}1', 'abcdefghijklm', null]) {
        expect(IdCard.isValid(bad), isFalse, reason: '$bad');
      }
    });

    test('แสดงแบบปิดบางส่วน', () {
      final id = fakeIdCard(7);
      final masked = IdCard.masked(id);
      expect(masked, contains('xxxxx'));
      expect(masked, isNot(contains(id.substring(5, 10))));
      expect(IdCard.masked('123'), '123');
    });
  });

  group('BeDate', () {
    test('อ่านและเขียน ddMMyyyy ปี พ.ศ.', () {
      expect(BeDate.parse('01102535'), DateTime(1992, 10, 1));
      expect(BeDate.format(DateTime(1992, 10, 1)), '01102535');
      expect(BeDate.format(DateTime(2026, 2, 28)), '28022569');
      expect(BeDate.format(null), '');
    });

    test('ว่าง ผิดรูป หรือวันที่ที่ไม่มีจริง = null', () {
      for (final bad in [
        '',
        null,
        '1102535',
        '31022568',
        '00012568',
        'abcdefgh',
      ]) {
        expect(BeDate.parse(bad), isNull, reason: '$bad');
      }
      // 29 ก.พ. มีเฉพาะปีอธิกสุรทิน (พ.ศ. 2567 = ค.ศ. 2024)
      expect(BeDate.parse('29022567'), DateTime(2024, 2, 29));
      expect(BeDate.parse('29022568'), isNull);
    });
  });

  group('โมเดลรายการหนี้', () {
    test('DebtCodes: 5 รหัส ไม่มี 40604', () {
      expect(DebtCodes.fields, [
        'c40302',
        'c40303',
        'c40315',
        'c40803',
        'c41100',
      ]);
      expect(DebtCodes.fields, isNot(contains('c40604')));
      expect(DebtCodes.codeOf('c40302'), '40302');
      expect(DebtCodes.nameOf('c40803'), 'AIA ประกันชีวิต');
      expect(MasterResource.cancelledDebtCode, '40604');
    });

    test(
      'DebtRow: อ่าน JSON ยอดรวม ช่องที่แก้ และตัวข้อมูลที่ส่ง (เฉพาะรหัสที่แก้)',
      () {
        final row = DebtRow.fromJson({
          'id': 'x1',
          'type': 'G',
          'div': '901',
          'title': 'นาย',
          'name': 'สมมุติ',
          'surname': 'ตัวอย่าง',
          'c40302': 1500.5,
          'c41100': '200',
          'c40604': 999,
        });
        expect(row.fullName, 'นายสมมุติ ตัวอย่าง');
        expect(row.total, 170050);
        expect(row.amounts.containsKey('c40604'), isFalse);
        expect(row.inRoster, isNull);
        expect(row.dirty, isFalse);

        row.amounts['c40303'] = 200000;
        row.amounts['c41100'] = 0;
        expect(row.changedFields, ['c40303', 'c41100']);
        expect(row.dirty, isTrue);
        expect(row.toUpdateJson(), {
          'id': 'x1',
          'c40303': '2000.00',
          'c41100': '0.00',
        });
        // แก้กลับเป็นค่าเดิม = ไม่ถือว่าแก้
        row.amounts['c40303'] = 0;
        row.amounts['c41100'] = 20000;
        expect(row.dirty, isFalse);
      },
    );

    test('DebtRow.in_roster: มีช่องก็อ่าน ไม่มีก็ไม่พัง', () {
      expect(
        DebtRow.fromJson({'id': 'a', 'in_roster': false}).inRoster,
        isFalse,
      );
      expect(DebtRow.fromJson({'id': 'a', 'in_roster': true}).inRoster, isTrue);
      expect(DebtRow.fromJson({'id': 'a'}).inRoster, isNull);
    });

    test('DebtPage: ช่องขาดถือว่าแก้ไม่ได้ (ปลอดภัยไว้ก่อน)', () {
      final page = DebtPage.fromJson({'items': [], 'totalPages': 0});
      expect(page.editable, isFalse);
      expect(page.isCurrentPeriod, isTrue);
      expect(page.periodReady, isTrue);
    });

    test(
      'วันเวลาจาก backend: ข้อความ ISO (UTC) และเลขมิลลิวินาที เป็นเวลาไทย',
      () {
        expect(
          parseServerTime('2025-06-25T02:30:00.000+00:00'),
          DateTime(2025, 6, 25, 9, 30),
        );
        expect(
          parseServerTime(
            DateTime.utc(2025, 6, 25, 2, 30).millisecondsSinceEpoch,
          ),
          DateTime(2025, 6, 25, 9, 30),
        );
        // ไม่มีเขตเวลา = เวลาไทยอยู่แล้ว
        expect(
          parseServerTime('2025-06-25T09:30:00'),
          DateTime(2025, 6, 25, 9, 30),
        );
        expect(parseServerTime(null), isNull);
        expect(formatServerTime(null), '-');
        expect(
          formatServerTime('2025-06-25T02:30:00Z'),
          '25 มิถุนายน 2568 เวลา 09:30:00 น.',
        );
      },
    );

    test('DebtAudit: อ่าน changes เป็นสตางค์', () {
      final a = DebtAudit.fromJson({
        'action': 'UPDATE',
        'by': '901',
        'at': '2025-06-25T02:30:00Z',
        'changes': {
          'c40303': {'from': 0, 'to': 2000},
        },
      });
      expect(a.actionName, 'แก้ยอด');
      expect(a.changes['c40303'], (0, 200000));
      // เวลาแบบ ISO-8601 มี offset +07:00 ตามสัญญา
      expect(
        DebtAudit.fromJson({
          'action': 'UPDATE',
          'at': '2026-10-13T10:00:00+07:00',
        }).at,
        DateTime(2026, 10, 13, 10),
      );
      // ประวัติเก่าจากช่วงทดสอบ และ action ที่ไม่รู้จัก: ข้อความกลาง ๆ ไม่พัง
      for (final action in ['ADD', 'TRANSFER', 'DELETE', 'SOMETHING_NEW', '']) {
        final old = DebtAudit.fromJson({'action': action, 'changes': null});
        expect(old.actionName, DebtAudit.otherName, reason: action);
        expect(old.isUpdate, isFalse);
        expect(old.changes, isEmpty);
      }
    });
  });
}
