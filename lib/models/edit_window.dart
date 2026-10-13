import '../utils/util.dart';

/// ช่วงวัน-เวลาที่เปิดให้หน่วยงานแก้ไขข้อมูล (`GET /api/edit-window`)
///
/// เป็น**ช่วงต่อเนื่องช่วงเดียว** จากวันเริ่ม+เวลาเริ่ม ถึงวันสิ้นสุด+เวลาสิ้นสุด (รวมปลาย ละเอียดระดับนาที เวลาไทย)
/// ไม่ใช่ช่วงเวลาที่ซ้ำทุกวัน การตัดสินว่าเปิดอยู่ไหมเป็นของ backend ([open] / [canEditNow])
/// หน้าเว็บไม่คำนวณเองจากนาฬิกาของเครื่องผู้ใช้
class EditWindow {
  /// วันเริ่ม (ไม่มีเวลา) ยังไม่ได้ตั้ง / อ่านไม่ได้ = null
  final DateTime? beginDate;
  final DateTime? endDate;

  /// เวลาเริ่มของวันแรก รูป HH:mm
  final String beginTime;

  /// เวลาสิ้นสุดของวันสุดท้าย รูป HH:mm
  final String endTime;

  /// ช่วงเปิดอยู่ไหม (สำหรับหน่วยงานทั่วไป)
  final bool open;

  /// บัญชีที่เข้าสู่ระบบอยู่แก้ไขข้อมูลได้ตอนนี้ไหม (ACCOUNT แก้ได้เสมอ)
  final bool canEditNow;

  /// เวลาของเครื่อง backend ตอนตอบ (เวลาไทย) ไม่มี = null
  final DateTime? serverTime;

  const EditWindow({
    this.beginDate,
    this.endDate,
    this.beginTime = defaultBeginTime,
    this.endTime = defaultEndTime,
    this.open = false,
    this.canEditNow = false,
    this.serverTime,
  });

  /// เวลาตั้งต้นของงวด ใช้เมื่อ backend ไม่มีเวลามา / ค่าว่าง / ผิดรูป (ผู้ใช้ตัดสิน 13 ต.ค. 2569: 06:00 - 16:30)
  /// backend เป็นผู้ตั้งเวลากลับเป็นค่านี้เองเมื่อฝ่ายบัญชีเปลี่ยนงวด
  static const String defaultBeginTime = '06:00';
  static const String defaultEndTime = '16:30';

  factory EditWindow.fromJson(Map<String, dynamic> j) => EditWindow(
    beginDate: _date(j['beginDate']),
    endDate: _date(j['endDate']),
    beginTime: normalizeTime(j['beginTime']?.toString()) ?? defaultBeginTime,
    endTime: normalizeTime(j['endTime']?.toString()) ?? defaultEndTime,
    open: j['open'] == true,
    canEditNow: j['can_edit_now'] == true,
    serverTime: j['server_time'] is String
        ? DateTime.tryParse(j['server_time'] as String)
        : null,
  );

  static DateTime? _date(Object? v) {
    if (v is! String || v.trim().isEmpty) return null;
    final d = DateTime.tryParse(v.trim());
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// จัดเวลาให้เป็น HH:mm ("6:05" -> "06:05") ผิดรูป / นอกช่วง 00:00-23:59 = null
  static String? normalizeTime(String? text) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch((text ?? '').trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${m.group(2)}';
  }

  /// ตั้งวันเริ่มและวันสิ้นสุดครบแล้ว
  bool get isSet => beginDate != null && endDate != null;

  /// วัน-เวลาเริ่ม เช่น "23 มิถุนายน 2568 เวลา 06:00 น." ยังไม่ได้ตั้ง = "-"
  String get beginLabel => _label(beginDate, beginTime);

  /// วัน-เวลาสิ้นสุด
  String get endLabel => _label(endDate, endTime);

  static String _label(DateTime? date, String time) =>
      date == null ? '-' : '${Util.formatThaiDate(date)} เวลา $time น.';

  /// ช่วงทั้งหมดในบรรทัดเดียว เช่น "ตั้งแต่ ... ถึง ..." ยังไม่ได้ตั้ง = [notSetLabel]
  String get rangeLabel =>
      isSet ? 'ตั้งแต่ $beginLabel ถึง $endLabel' : notSetLabel;

  static const String notSetLabel = 'ยังไม่ได้กำหนดระยะเวลาแก้ไขข้อมูล';

  /// ตัวข้อมูลของ PUT /api/edit-window (วันที่ ค.ศ. yyyy-MM-dd เวลา HH:mm)
  static Map<String, dynamic> requestJson({
    required DateTime beginDate,
    required DateTime endDate,
    required String beginTime,
    required String endTime,
  }) => {
    'beginDate': Util.formatChristianDate(beginDate),
    'endDate': Util.formatChristianDate(endDate),
    'beginTime': beginTime,
    'endTime': endTime,
  };
}
