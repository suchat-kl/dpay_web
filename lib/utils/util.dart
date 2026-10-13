import 'package:intl/intl.dart';

/// ตัวช่วยกลาง: วันที่ภาษาไทย (พ.ศ.) และการจัดรูปตัวเลข
///
/// ทั้งระบบแสดงวันที่ด้วยชื่อเดือนไทยและปี พ.ศ. ผ่านคลาสนี้เท่านั้น
/// ส่วนค่าที่ส่ง backend เป็น ค.ศ. รูป yyyy-MM-dd ([formatChristianDate])
/// เลือกวันที่ด้วย `showThaiDatePicker` (widgets/thai_date_picker.dart) ซึ่งแสดงปีเป็น พ.ศ.
class Util {
  Util._();

  /// วันที่ไทยแบบยาว เช่น "18 สิงหาคม 2569"
  static String formatThaiDate(DateTime date) {
    final thaiYear = date.year + 543;
    return '${date.day} ${thaiMonths[date.month - 1]} $thaiYear';
  }

  /// ชื่อเดือนภาษาไทยแบบเต็ม เรียงมกราคม-ธันวาคม
  static const List<String> thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  /// ชื่อเดือนภาษาไทยแบบย่อ เรียง ม.ค.-ธ.ค.
  static const List<String> thaiMonthsShort = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  /// เดือนย่อ + ปี พ.ศ. 4 หลัก จากข้อความรูป "yyyy-MM" ที่ปีเป็น พ.ศ. เช่น "2568-03" -> "มี.ค. 2568"
  /// (ปีที่น้อยกว่า 2400 ถือเป็น ค.ศ. บวก 543 ให้) ว่าง / ผิดรูป / เดือนนอกช่วง = null
  static String? formatThaiMonthYearShort(String? yearMonth) {
    final m = RegExp(
      r'^(\d{4})-(\d{1,2})$',
    ).firstMatch((yearMonth ?? '').trim());
    if (m == null) return null;
    var year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    if (year < 2400) year += 543;
    return '${thaiMonthsShort[month - 1]} $year';
  }

  /// วันที่ไทยแบบยาวพร้อมเวลา เช่น "12 ตุลาคม 2569 เวลา 11:22:09 น."
  static String formatThaiDateTime(DateTime d) =>
      '${formatThaiDate(d)} เวลา ${formatThaiTime(d)}';

  /// เวลา 24 ชั่วโมงถึงวินาที เช่น "11:22:09 น."
  static String formatThaiTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)} น.';
  }

  /// จำนวนเต็มมีจุลภาคคั่นหลักพัน เช่น 155613 -> "155,613"
  static String formatCount(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  /// ชื่อวันในสัปดาห์ เรียงจันทร์-อาทิตย์ ตาม [DateTime.weekday] (1 = จันทร์)
  static const List<String> thaiWeekdays = [
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  /// ชื่อเดือนภาษาไทยของเดือน 1-12 นอกช่วงคืนตัวเลขเดิม (ข้อมูลเดิมที่ผิดรูป)
  static String thaiMonthName(int month) =>
      month >= 1 && month <= 12 ? thaiMonths[month - 1] : '$month';

  /// วันที่ไทยพร้อมวันในสัปดาห์ เช่น "ศุกร์ 16 มกราคม 2569"
  static String formatThaiDateWithWeekday(DateTime date) =>
      '${thaiWeekdays[date.weekday - 1]} ${formatThaiDate(date)}';

  /// วันที่ไทยแบบยาวจากข้อความ ISO ของ backend ("2026-09-30" หรือมีเวลาต่อท้าย)
  /// ว่าง = "-" อ่านไม่ออก = คืนข้อความเดิม
  static String formatThaiDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return formatThaiDate(date);
    } catch (e) {
      return dateStr;
    }
  }

  /// วันที่ ค.ศ. รูป yyyy-MM-dd สำหรับส่ง backend
  static String formatChristianDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// วันที่ไทยแบบตัวเลข วว/ดด/ปปปป (พ.ศ.) เช่น "30/07/2569" — ใช้เฉพาะที่แคบ ปกติใช้ [formatThaiDate]
  static String toBuddhistYearDisplay(DateTime date) {
    final int buddhistYear = date.year + 543;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$buddhistYear';
  }

  /// วันที่ไทยแบบสั้น เดือนย่อ เช่น "18 ส.ค. 2569"
  static String formatThaiDateShort(DateTime date) =>
      '${date.day} ${thaiMonthsShort[date.month - 1]} ${date.year + 543}';

  /// ปี พ.ศ. ของวันที่ (ค.ศ. + 543)
  static int buddhistYear(DateTime date) => date.year + 543;
}
