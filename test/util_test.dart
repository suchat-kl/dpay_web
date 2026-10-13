// เทสต์ตัวช่วยวันที่ภาษาไทยและการจัดรูปตัวเลขใน lib/utils/util.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/utils/util.dart';

void main() {
  group('Util วันที่ภาษาไทย', () {
    test('formatThaiDate แสดงชื่อเดือนเต็มและปี พ.ศ.', () {
      expect(Util.formatThaiDate(DateTime(2026, 8, 18)), '18 สิงหาคม 2569');
      expect(Util.formatThaiDate(DateTime(2025, 10, 1)), '1 ตุลาคม 2568');
      expect(Util.formatThaiDate(DateTime(2026, 1, 5)), '5 มกราคม 2569');
    });

    test('formatThaiDate วันสิ้นปีและ 29 กุมภาพันธ์ปีอธิกสุรทิน', () {
      expect(Util.formatThaiDate(DateTime(2026, 12, 31)), '31 ธันวาคม 2569');
      expect(Util.formatThaiDate(DateTime(2028, 2, 29)), '29 กุมภาพันธ์ 2571');
    });

    test('formatThaiDateShort เดือนย่อและปี พ.ศ.', () {
      expect(Util.formatThaiDateShort(DateTime(2026, 8, 18)), '18 ส.ค. 2569');
      expect(Util.formatThaiDateShort(DateTime(2026, 1, 5)), '5 ม.ค. 2569');
      expect(Util.formatThaiDateShort(DateTime(2025, 12, 31)), '31 ธ.ค. 2568');
    });

    test('formatThaiDateStr รับข้อความ ISO จาก backend', () {
      expect(Util.formatThaiDateStr('2026-09-30'), '30 กันยายน 2569');
      expect(Util.formatThaiDateStr('2026-10-08T14:30:00'), '8 ตุลาคม 2569');
    });

    test(
      'formatThaiDateStr ค่าว่างคืนขีด ข้อความที่อ่านไม่ได้คืนข้อความเดิม',
      () {
        expect(Util.formatThaiDateStr(null), '-');
        expect(Util.formatThaiDateStr(''), '-');
        expect(Util.formatThaiDateStr('ไม่ใช่วันที่'), 'ไม่ใช่วันที่');
      },
    );

    test('toBuddhistYearDisplay เป็นตัวเลข วว/ดด/ปปปป (พ.ศ.)', () {
      expect(Util.toBuddhistYearDisplay(DateTime(2026, 7, 30)), '30/07/2569');
      expect(Util.toBuddhistYearDisplay(DateTime(2026, 1, 5)), '05/01/2569');
    });

    test('formatChristianDate เป็น ค.ศ. รูป yyyy-MM-dd สำหรับส่ง backend', () {
      expect(Util.formatChristianDate(DateTime(2026, 8, 18)), '2026-08-18');
      expect(Util.formatChristianDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('buddhistYear = ค.ศ. + 543', () {
      expect(Util.buddhistYear(DateTime(2026, 1, 1)), 2569);
      expect(Util.buddhistYear(DateTime(2025, 12, 31)), 2568);
    });

    test('formatThaiDateWithWeekday มีวันในสัปดาห์นำหน้า', () {
      expect(
        Util.formatThaiDateWithWeekday(DateTime(2026, 1, 16)),
        'ศุกร์ 16 มกราคม 2569',
      );
      expect(
        Util.formatThaiDateWithWeekday(DateTime(2026, 10, 11)),
        'อาทิตย์ 11 ตุลาคม 2569',
      );
      expect(
        Util.formatThaiDateWithWeekday(DateTime(2026, 6, 1)),
        'จันทร์ 1 มิถุนายน 2569',
      );
    });

    test('formatThaiDateTime / formatThaiTime เวลา 24 ชั่วโมงถึงวินาที', () {
      final d = DateTime(2026, 10, 12, 9, 5, 7);
      expect(Util.formatThaiTime(d), '09:05:07 น.');
      expect(Util.formatThaiDateTime(d), '12 ตุลาคม 2569 เวลา 09:05:07 น.');
      expect(
        Util.formatThaiTime(DateTime(2026, 1, 1, 23, 59, 59)),
        '23:59:59 น.',
      );
    });

    test('thaiMonthName เดือน 1-12 เป็นชื่อเต็ม นอกช่วงคืนตัวเลขเดิม', () {
      expect(Util.thaiMonthName(1), 'มกราคม');
      expect(Util.thaiMonthName(12), 'ธันวาคม');
      expect(Util.thaiMonthName(0), '0');
      expect(Util.thaiMonthName(13), '13');
    });

    test('รายการชื่อเดือนและวันครบจำนวน', () {
      expect(Util.thaiMonths.length, 12);
      expect(Util.thaiMonthsShort.length, 12);
      expect(Util.thaiWeekdays.length, 7);
      expect(Util.thaiMonths[9], 'ตุลาคม');
      expect(Util.thaiMonthsShort[9], 'ต.ค.');
    });

    test('formatThaiMonthYearShort จากข้อความ yyyy-MM', () {
      expect(Util.formatThaiMonthYearShort('2568-03'), 'มี.ค. 2568');
      // ปีที่น้อยกว่า 2400 ถือเป็น ค.ศ.
      expect(Util.formatThaiMonthYearShort('2025-3'), 'มี.ค. 2568');
      expect(Util.formatThaiMonthYearShort(' 2569-12 '), 'ธ.ค. 2569');
      expect(Util.formatThaiMonthYearShort('2568-13'), isNull);
      expect(Util.formatThaiMonthYearShort('2568-00'), isNull);
      expect(Util.formatThaiMonthYearShort('ไม่ใช่'), isNull);
      expect(Util.formatThaiMonthYearShort(''), isNull);
      expect(Util.formatThaiMonthYearShort(null), isNull);
    });
  });

  group('Util.formatCount', () {
    test('คั่นหลักพันด้วยจุลภาค', () {
      expect(Util.formatCount(0), '0');
      expect(Util.formatCount(999), '999');
      expect(Util.formatCount(1000), '1,000');
      expect(Util.formatCount(155613), '155,613');
      expect(Util.formatCount(1234567), '1,234,567');
    });
  });
}
