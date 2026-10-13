/// หน่วยงานหนึ่งแห่ง (แถวของ `div_dept`) รูป `{div, divname, center}`
class DivDept {
  /// รหัสหน่วยงาน 3 หลัก
  final String div;

  /// ชื่อหน่วยงาน
  final String name;

  /// หน่วยงานส่วนกลาง
  final bool center;

  const DivDept({required this.div, required this.name, this.center = false});

  factory DivDept.fromJson(Map<String, dynamic> j) => DivDept(
    div: j['div']?.toString() ?? '',
    name: j['divname']?.toString() ?? '',
    center: j['center'] == true,
  );

  /// ข้อความที่แสดงในตัวเลือก เช่น "030 กองการเงินและบัญชี" (ไม่มีชื่อ = รหัสอย่างเดียว)
  String get label => name.isEmpty ? div : '$div $name';
}

/// ขอบเขตหน่วยงานที่ผู้ใช้เลือกได้ (ช่อง `div_scope` / `scope` ของ backend)
enum DivScope {
  /// เฉพาะหน่วยงานของตัวเอง
  own,

  /// หน่วยงานส่วนกลาง + ของตัวเอง
  center,

  /// ทุกหน่วยงาน
  all;

  /// ค่าที่ไม่รู้จัก / ไม่มี = [own] (แคบที่สุด) การกันจริงอยู่ที่ backend
  static DivScope parse(Object? value) => switch ('$value'.toUpperCase()) {
    'ALL' => DivScope.all,
    'CENTER' => DivScope.center,
    _ => DivScope.own,
  };

  /// ค่าที่ backend ใช้ (OWN / CENTER / ALL)
  String get code => name.toUpperCase();

  /// คำอธิบายภาษาไทย
  String get label => switch (this) {
    DivScope.own => 'เฉพาะหน่วยงานของตัวเอง',
    DivScope.center => 'หน่วยงานส่วนกลางและหน่วยงานของตัวเอง',
    DivScope.all => 'ทุกหน่วยงาน',
  };
}

/// คำตอบของ `GET /api/divs`: หน่วยงานที่ผู้ใช้คนนี้เลือกได้
class DivChoices {
  final DivScope scope;

  /// รหัสหน่วยงานของผู้ใช้เอง
  final String ownDiv;
  final List<DivDept> divs;

  const DivChoices({
    required this.scope,
    required this.ownDiv,
    this.divs = const [],
  });

  factory DivChoices.fromJson(Map<String, dynamic> j) => DivChoices(
    scope: DivScope.parse(j['scope']),
    ownDiv: j['own_div']?.toString() ?? '',
    divs: [
      for (final d in j['divs'] as List? ?? const [])
        if (d is Map) DivDept.fromJson(Map<String, dynamic>.from(d)),
    ],
  );

  /// หน่วยงานของรหัสนี้ในรายการ ไม่พบ = null
  DivDept? find(String? div) {
    for (final d in divs) {
      if (d.div == div) return d;
    }
    return null;
  }

  /// เลือกหน่วยงานอื่นได้ (ขอบเขตกว้างกว่าของตัวเอง และมีมากกว่าหนึ่งแห่งให้เลือก)
  bool get selectable => scope != DivScope.own && divs.length > 1;
}

/// คำตอบของ `GET /api/divs/{div}/success-dept`: รหัสสังกัดของหน่วยงาน
class SuccessDept {
  final String div;

  /// รหัสสังกัดข้าราชการ (ขึ้นต้น G) ไม่มี = null
  final String? g;

  /// รหัสสังกัดลูกจ้างประจำ (ขึ้นต้น E) ไม่มี = null
  final String? e;
  final List<String> all;

  const SuccessDept({required this.div, this.g, this.e, this.all = const []});

  factory SuccessDept.fromJson(Map<String, dynamic> j) => SuccessDept(
    div: j['div']?.toString() ?? '',
    g: j['g']?.toString(),
    e: j['e']?.toString(),
    all: [
      for (final c in j['success_depts'] as List? ?? const [])
        if (c != null) '$c',
    ],
  );
}
