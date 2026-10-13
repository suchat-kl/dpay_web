import '../utils/util.dart';

/// งวดปัจจุบันของระบบ (`GET /api/period`) — เดือน 2 หลัก กับปี พ.ศ. 4 หลัก เป็นข้อความทั้งคู่
class Period {
  /// เดือน "01" - "12"
  final String month;

  /// ปี พ.ศ. เช่น "2568"
  final String year;

  const Period({required this.month, required this.year});

  factory Period.fromJson(Map<String, dynamic> j) => Period(
    month: (j['month']?.toString() ?? '').trim(),
    year: (j['year']?.toString() ?? '').trim(),
  );

  /// จากตัวเลข เดือน 1-12 และปี พ.ศ.
  factory Period.of(int month, int year) =>
      Period(month: month.toString().padLeft(2, '0'), year: '$year');

  Map<String, dynamic> toJson() => {'month': month, 'year': year};

  /// เดือนเป็นตัวเลข 1-12 อ่านไม่ได้ / นอกช่วง = null
  int? get monthNumber {
    final m = int.tryParse(month);
    return m != null && m >= 1 && m <= 12 ? m : null;
  }

  /// ปี พ.ศ. เป็นตัวเลข อ่านไม่ได้ = null
  int? get yearNumber => int.tryParse(year);

  /// ค่าครบและอ่านได้ (ฐานที่ยังไม่เคยตั้งงวดจะได้ค่าว่าง)
  bool get isValid => monthNumber != null && yearNumber != null;

  /// ข้อความที่แสดง เช่น "กรกฎาคม 2568" ยังไม่ได้กำหนด = [notSetLabel]
  String get label =>
      isValid ? '${Util.thaiMonthName(monthNumber!)} $year' : notSetLabel;

  static const String notSetLabel = 'ยังไม่ได้กำหนด';
}
