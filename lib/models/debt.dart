import '../utils/money.dart';
import '../utils/util.dart';

/// รหัสหนี้ที่บันทึกได้ 5 รหัส (ชื่อช่องของ backend กับชื่อที่แสดง) — **ไม่มี 40604 (สโมสร ยกเลิกแล้ว)**
class DebtCodes {
  DebtCodes._();

  /// ชื่อช่อง ตามลำดับคอลัมน์ของตาราง
  static const List<String> fields = [
    'c40302',
    'c40303',
    'c40315',
    'c40803',
    'c41100',
  ];

  static const Map<String, String> names = {
    'c40302': 'ธ.อาคารสงเคราะห์',
    'c40303': 'ธ.ออมสิน',
    'c40315': 'ธ.กรุงไทย',
    'c40803': 'AIA ประกันชีวิต',
    'c41100': 'หนี้สินอื่นๆ',
  };

  /// รหัส 5 หลักของช่อง เช่น c40302 -> 40302
  static String codeOf(String field) => field.substring(1);

  static String nameOf(String field) => names[field] ?? field;
}

/// ประเภทบุคลากร
class EmpType {
  EmpType._();

  static const String g = 'G';
  static const String e = 'E';
  static const Map<String, String> names = {g: 'ข้าราชการ', e: 'ลูกจ้างประจำ'};

  static String nameOf(String? type) => names[type] ?? (type ?? '-');
}

/// วันเวลาที่ backend ส่งมา (ข้อความ ISO หรือเลขมิลลิวินาที) เป็นเวลาไทย ไม่มี/อ่านไม่ได้ = null
DateTime? parseServerTime(Object? v) {
  DateTime? utc;
  if (v is num) {
    utc = DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  } else if (v is String && v.isNotEmpty) {
    final d = DateTime.tryParse(v);
    if (d == null) return null;
    // ข้อความที่ไม่มีเขตเวลาถือเป็นเวลาไทยอยู่แล้ว
    if (!d.isUtc) return d;
    utc = d;
  }
  if (utc == null) return null;
  final t = utc.add(const Duration(hours: 7));
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

/// วันเวลาไทยสำหรับแสดง ไม่มี = "-"
String formatServerTime(Object? v) {
  final d = parseServerTime(v);
  return d == null ? '-' : Util.formatThaiDateTime(d);
}

/// รายการหนี้รายเดือนของหนึ่งคน (แถวของ `GET /api/debts`)
///
/// ยอดเก็บเป็นสตางค์ [amounts] = ค่าที่แก้อยู่บนจอ [original] = ค่าตอนโหลด ใช้หาว่าช่องใดถูกแก้
class DebtRow {
  final String id;
  final String type;
  final String div;
  final String divName;

  /// เลขประจำตัวประชาชน (ข้อมูลส่วนบุคคล ห้ามลง log)
  final String idcard;
  final String title;
  final String name;
  final String surname;
  final String posName;

  /// อยู่ในรายชื่อของหน่วยงานตาม DPIS ไหม — backend รุ่นที่ยังไม่มีช่องนี้ = null (ไม่ทำเครื่องหมาย)
  final bool? inRoster;
  final Map<String, int> original;
  final Map<String, int> amounts;

  /// ข้อความในช่องที่พิมพ์แล้วอ่านเป็นจำนวนเงินไม่ได้ (ช่อง -> ข้อความที่พิมพ์)
  final Map<String, String> invalid = {};

  DebtRow({
    required this.id,
    required this.type,
    required this.div,
    this.divName = '',
    this.idcard = '',
    this.title = '',
    this.name = '',
    this.surname = '',
    this.posName = '',
    this.inRoster,
    required Map<String, int> amounts,
  }) : original = Map.of(amounts),
       amounts = Map.of(amounts);

  factory DebtRow.fromJson(Map<String, dynamic> j) => DebtRow(
    id: j['id']?.toString() ?? '',
    type: j['type']?.toString() ?? '',
    div: j['div']?.toString() ?? '',
    divName: j['divname']?.toString() ?? '',
    idcard: j['idcard']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    surname: j['surname']?.toString() ?? '',
    posName: j['pos_name']?.toString() ?? '',
    inRoster: j['in_roster'] is bool ? j['in_roster'] as bool : null,
    amounts: {for (final f in DebtCodes.fields) f: Money.fromJson(j[f])},
  );

  /// ชื่อเต็ม เช่น "นายสมมุติ ตัวอย่าง"
  String get fullName => '$title$name $surname'.trim();

  /// ยอดรวม 5 รหัสของแถว (สตางค์)
  int get total => amounts.values.fold(0, (a, b) => a + b);

  /// ช่องที่ค่าต่างจากตอนโหลด
  List<String> get changedFields => [
    for (final f in DebtCodes.fields)
      if (amounts[f] != original[f]) f,
  ];

  bool get dirty => changedFields.isNotEmpty || invalid.isNotEmpty;

  /// ตัวข้อมูลของแถวนี้ใน `PUT /api/debts` — ส่งเฉพาะรหัสที่แก้
  Map<String, dynamic> toUpdateJson() => {
    'id': id,
    for (final f in changedFields) f: Money.toJson(amounts[f]!),
  };
}

/// คำตอบของ `GET /api/debts` / `POST /api/debts/search`
class DebtPage {
  final List<DebtRow> items;
  final int totalPages;
  final int totalItems;
  final String month;
  final String year;

  /// เป็นงวดปัจจุบันไหม (แก้ยอดได้เฉพาะงวดปัจจุบัน)
  final bool isCurrentPeriod;

  /// งวดเตรียมเสร็จแล้วไหม (ไม่ = ฝ่ายบัญชีต้องเตรียมงวดก่อน)
  final bool periodReady;

  /// ผู้ใช้คนนี้แก้ยอดของรายการชุดนี้ได้ตอนนี้ไหม (backend ตัดสิน)
  final bool editable;

  const DebtPage({
    this.items = const [],
    this.totalPages = 0,
    this.totalItems = 0,
    this.month = '',
    this.year = '',
    this.isCurrentPeriod = true,
    this.periodReady = true,
    this.editable = false,
  });

  factory DebtPage.fromJson(Map<String, dynamic> j) => DebtPage(
    items: [
      for (final e in j['items'] as List? ?? const [])
        if (e is Map) DebtRow.fromJson(Map<String, dynamic>.from(e)),
    ],
    totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
    totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
    month: j['month']?.toString() ?? '',
    year: j['year']?.toString() ?? '',
    // ช่องที่ backend ไม่ส่งมา: ถือว่าเป็นงวดปัจจุบันที่พร้อม แต่แก้ไม่ได้ (ปลอดภัยไว้ก่อน)
    isCurrentPeriod: j['is_current_period'] != false,
    periodReady: j['period_ready'] != false,
    editable: j['editable'] == true,
  );
}

/// ยอดรวมของหนึ่งรหัสหนี้ (`GET /api/debts/summary`)
class DebtSummaryItem {
  final String field;
  final String name;

  /// จำนวนคนที่ยอด > 0
  final int count;

  /// ยอดรวม (สตางค์)
  final int amount;

  const DebtSummaryItem({
    required this.field,
    required this.name,
    this.count = 0,
    this.amount = 0,
  });

  factory DebtSummaryItem.fromJson(Map<String, dynamic> j) {
    final field = j['field']?.toString() ?? 'c${j['code'] ?? ''}';
    return DebtSummaryItem(
      field: field,
      name: j['name']?.toString() ?? DebtCodes.nameOf(field),
      count: (j['count'] as num?)?.toInt() ?? 0,
      amount: Money.fromJson(j['amount']),
    );
  }
}

/// หนึ่งรายการของประวัติการแก้ไข (`GET /api/debts/{id}/audit`)
class DebtAudit {
  /// UPDATE / ADD / TRANSFER / DELETE
  final String action;
  final String by;
  final DateTime? at;

  /// ช่อง -> (ค่าเดิม, ค่าใหม่) เป็นสตางค์ (มีเฉพาะ UPDATE)
  final Map<String, (int, int)> changes;

  const DebtAudit({
    required this.action,
    this.by = '',
    this.at,
    this.changes = const {},
  });

  factory DebtAudit.fromJson(Map<String, dynamic> j) {
    final changes = <String, (int, int)>{};
    final raw = j['changes'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          changes['$k'] = (Money.fromJson(v['from']), Money.fromJson(v['to']));
        }
      });
    }
    return DebtAudit(
      action: j['action']?.toString() ?? '',
      by: j['by']?.toString() ?? '',
      at: parseServerTime(j['at']),
      changes: changes,
    );
  }

  /// ปัจจุบัน backend บันทึกเฉพาะ UPDATE — ประวัติเก่าจากช่วงทดสอบ (ADD / TRANSFER / DELETE)
  /// และ action ที่ไม่รู้จัก แสดงเป็นข้อความกลาง ๆ
  static const String updateName = 'แก้ยอด';
  static const String otherName = 'รายการเดิมของระบบ';

  bool get isUpdate => action == 'UPDATE';

  String get actionName => isUpdate ? updateName : otherName;
}

/// บุคคลจากการค้นด้วยชื่อ-สกุล (`POST /api/persons/search`) — ใช้เลือกคนเท่านั้น ไม่มียอดหนี้
class PersonHit {
  final String idcard;
  final String type;
  final String fullName;
  final String div;
  final String divName;
  final String posName;

  const PersonHit({
    required this.idcard,
    this.type = '',
    this.fullName = '',
    this.div = '',
    this.divName = '',
    this.posName = '',
  });

  factory PersonHit.fromJson(Map<String, dynamic> j) => PersonHit(
    idcard: j['idcard']?.toString() ?? '',
    type: j['type']?.toString() ?? '',
    fullName: '${j['title'] ?? ''}${j['name'] ?? ''} ${j['surname'] ?? ''}'
        .trim(),
    div: j['div']?.toString() ?? '',
    divName: j['divname']?.toString() ?? '',
    posName: j['pos_name']?.toString() ?? '',
  );
}

/// บุคคลจาก `POST /api/persons/lookup`
class PersonInfo {
  final bool found;

  /// G / E (ไม่ทราบ = ว่าง)
  final String type;
  final bool inCurrentPeriod;
  final String div;
  final String fullName;

  /// วันเกิด / วันบรรจุ (อ่านจาก ddMMyyyy ปี พ.ศ.)
  final DateTime? birthDate;
  final DateTime? startDate;

  const PersonInfo({
    this.found = false,
    this.type = '',
    this.inCurrentPeriod = false,
    this.div = '',
    this.fullName = '',
    this.birthDate,
    this.startDate,
  });

  factory PersonInfo.fromJson(Map<String, dynamic> j) {
    final full = j['full_name']?.toString() ?? '';
    final joined = '${j['title'] ?? ''}${j['name'] ?? ''} ${j['surname'] ?? ''}'
        .trim();
    return PersonInfo(
      found: j['found'] == true,
      type: j['type']?.toString() ?? '',
      inCurrentPeriod: j['in_current_period'] == true,
      div: j['div']?.toString() ?? '',
      fullName: full.isNotEmpty ? full : joined,
      birthDate: BeDate.parse(j['birth_date']?.toString()),
      startDate: BeDate.parse(j['start_date']?.toString()),
    );
  }
}
