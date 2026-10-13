/// จำนวนเงินของระบบหักหนี้ — เก็บเป็น**สตางค์ (int)** ทั้งหน้าเว็บ ไม่บวก/เทียบ double ตรง ๆ
///
/// กติกาเดียวกับ backend: ไม่ติดลบ ทศนิยมไม่เกิน 2 ตำแหน่ง ไม่เกิน 9,999,999.99
/// แสดงผลรูป `1,500.50` ส่ง backend เป็นข้อความตัวเลข `"1500.50"` (backend รับทั้งตัวเลขและข้อความ)
class Money {
  Money._();

  /// ยอดสูงสุดที่ backend รับ (สตางค์)
  static const int maxSatang = 999999999;

  static const String invalidMessage =
      'จำนวนเงินต้องเป็นตัวเลขไม่ติดลบ ทศนิยมไม่เกิน 2 ตำแหน่ง และไม่เกิน 9,999,999.99';

  static final RegExp _pattern = RegExp(r'^\d{1,7}(\.\d{0,2})?$');

  /// อ่านข้อความที่ผู้ใช้พิมพ์ (มีจุลภาคคั่นหลักพันได้) เป็นสตางค์ ว่าง = 0 ผิดรูป/เกินช่วง = null
  static int? parse(String? text) {
    final t = (text ?? '').replaceAll(',', '').trim();
    if (t.isEmpty) return 0;
    if (!_pattern.hasMatch(t)) return null;
    final parts = t.split('.');
    final frac = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
    final value = int.parse(parts[0]) * 100 + int.parse(frac);
    return value > maxSatang ? null : value;
  }

  /// อ่านค่าจาก JSON ของ backend (ตัวเลขหรือข้อความ) เป็นสตางค์ ไม่มี/อ่านไม่ได้ = 0
  static int fromJson(Object? v) {
    if (v == null) return 0;
    if (v is int) return v * 100;
    if (v is num) return (v * 100).round();
    return parse('$v') ?? 0;
  }

  /// แสดงผล เช่น 150050 -> "1,500.50"
  static String format(int satang) {
    final whole = (satang ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$whole.${(satang % 100).toString().padLeft(2, '0')}';
  }

  /// ค่าในช่องกรอก: 0 = ว่าง นอกนั้นไม่มีจุลภาค เช่น "1500.50"
  static String input(int satang) => satang == 0 ? '' : toJson(satang);

  /// ค่าที่ส่ง backend เช่น "1500.50"
  static String toJson(int satang) =>
      '${satang ~/ 100}.${(satang % 100).toString().padLeft(2, '0')}';
}

/// เลขประจำตัวประชาชน 13 หลัก — เป็นข้อมูลส่วนบุคคล **ห้ามลง log และห้ามใส่ใน URL**
class IdCard {
  IdCard._();

  static const String invalidMessage =
      'เลขประจำตัวประชาชนไม่ถูกต้อง (ต้องเป็นตัวเลข 13 หลัก และหลักตรวจสอบถูกต้อง)';

  /// ตัดช่องว่างและขีดออก เหลือแต่ตัวเลข
  static String clean(String? text) =>
      (text ?? '').replaceAll(RegExp(r'[\s-]'), '');

  /// ตัวเลข 13 หลัก และหลักตรวจสอบ (หลักที่ 13) ถูกต้อง
  static bool isValid(String? text) {
    final id = clean(text);
    if (!RegExp(r'^\d{13}$').hasMatch(id)) return false;
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(id[i]) * (13 - i);
    }
    return (11 - sum % 11) % 10 == int.parse(id[12]);
  }

  /// แสดงแบบปิดบางส่วน เช่น "1-2345-xxxxx-12-3" ใช้ในรายการที่ไม่จำเป็นต้องเห็นทั้งเลข
  static String masked(String? text) {
    final id = clean(text);
    if (id.length != 13) return id;
    return '${id[0]}-${id.substring(1, 5)}-xxxxx-${id.substring(10, 12)}-${id[12]}';
  }
}

/// วันที่รูป `ddMMyyyy` ปี พ.ศ. ที่ทะเบียนบุคลากรของ backend ใช้ (เช่น "01102535")
class BeDate {
  BeDate._();

  /// อ่านเป็น DateTime (ค.ศ.) ว่าง / ผิดรูป / ไม่ใช่วันที่ที่มีจริง = null
  static DateTime? parse(String? text) {
    final t = (text ?? '').trim();
    if (!RegExp(r'^\d{8}$').hasMatch(t)) return null;
    final d = int.parse(t.substring(0, 2));
    final m = int.parse(t.substring(2, 4));
    final y = int.parse(t.substring(4)) - 543;
    final date = DateTime(y, m, d);
    return date.year == y && date.month == m && date.day == d ? date : null;
  }

  /// แปลงเป็น `ddMMyyyy` ปี พ.ศ. null = ข้อความว่าง
  static String format(DateTime? date) => date == null
      ? ''
      : '${date.day.toString().padLeft(2, '0')}'
            '${date.month.toString().padLeft(2, '0')}'
            '${date.year + 543}';
}
