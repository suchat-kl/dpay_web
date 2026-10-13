import 'package:flutter/material.dart';

/// ช่องหนึ่งช่องของตารางข้อมูลหลัก (ทุกช่องเป็นข้อความตามสัญญา `/api/master/{resource}`)
class MasterField {
  /// ชื่อช่องของ backend เช่น bank_code
  final String key;
  final String label;
  final bool required;

  /// รับเฉพาะตัวเลข
  final bool digits;
  final int minLength;
  final int maxLength;

  /// ตัวเลือกตายตัว (ค่า -> ข้อความที่แสดง) เช่น t/f ของหน่วยงานส่วนกลาง
  final Map<String, String>? choices;

  /// สัดส่วนความกว้างของคอลัมน์ในตาราง
  final int flex;

  const MasterField(
    this.key,
    this.label, {
    this.required = false,
    this.digits = false,
    this.minLength = 0,
    this.maxLength = 100,
    this.choices,
    this.flex = 2,
  });

  /// ตรวจค่าที่กรอก คืนข้อความผิดพลาด (ผ่าน = null)
  String? validate(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'กรุณากรอก$label' : null;
    if (digits && !RegExp(r'^\d+$').hasMatch(v)) {
      return '$labelต้องเป็นตัวเลข';
    }
    if (v.length < minLength || v.length > maxLength) {
      return minLength == maxLength
          ? '$labelต้องยาว $minLength ${digits ? 'หลัก' : 'ตัวอักษร'}'
          : '$labelต้องยาว ${minLength > 0 ? '$minLength-' : 'ไม่เกิน '}$maxLength ${digits ? 'หลัก' : 'ตัวอักษร'}';
    }
    return null;
  }

  /// ข้อความที่แสดงในตาราง (แปลงค่าของตัวเลือกเป็นข้อความ)
  String display(String? value) => choices?[value] ?? (value ?? '');
}

/// ตารางข้อมูลหลักหนึ่งตาราง: ชื่อ path ช่อง และตัวกรองบังคับ (สาขาต้องเลือกธนาคารก่อน)
class MasterResource {
  /// ชื่อใน path เช่น banks
  final String path;

  /// ชื่อเมนู/หัวเรื่อง
  final String title;

  /// คำเรียกหนึ่งรายการ ใช้ในข้อความยืนยัน เช่น "ธนาคาร"
  final String itemName;
  final IconData icon;
  final List<MasterField> fields;

  /// ต้องเลือกธนาคารก่อนจึงแสดงรายการ (ตารางสาขา) — ค่า bank_code ถูกเติมให้ตอนเพิ่ม
  final bool needsBank;

  const MasterResource({
    required this.path,
    required this.title,
    required this.itemName,
    required this.icon,
    required this.fields,
    this.needsBank = false,
  });

  /// ข้อความสั้น ๆ ของหนึ่งรายการ (ช่องแรก + ช่องที่สอง) ใช้ในข้อความยืนยัน/ผลการลบ
  String describe(Map<String, String> item) => [
    for (final f in fields.take(2))
      if ((item[f.key] ?? '').isNotEmpty) item[f.key],
  ].join(' ');

  static const banks = MasterResource(
    path: 'banks',
    title: 'รายชื่อธนาคาร',
    itemName: 'ธนาคาร',
    icon: Icons.account_balance,
    fields: [
      MasterField(
        'bank_code',
        'รหัสธนาคาร',
        required: true,
        digits: true,
        minLength: 3,
        maxLength: 3,
        flex: 2,
      ),
      MasterField('bank_name', 'ชื่อธนาคาร', required: true, flex: 6),
      MasterField('shrt', 'ชื่อย่อ', maxLength: 20, flex: 2),
      MasterField('shrt_th', 'ชื่อย่อไทย', maxLength: 20, flex: 2),
      MasterField(
        'rec_no',
        'ลำดับ',
        required: true,
        digits: true,
        minLength: 1,
        maxLength: 3,
        flex: 2,
      ),
    ],
  );

  static const branches = MasterResource(
    path: 'branches',
    title: 'รายชื่อสาขาธนาคาร',
    itemName: 'สาขา',
    icon: Icons.store_mall_directory_outlined,
    needsBank: true,
    fields: [
      MasterField(
        'bank_brch',
        'รหัสสาขา',
        required: true,
        digits: true,
        minLength: 3,
        maxLength: 4,
        flex: 2,
      ),
      MasterField('name', 'ชื่อสาขา', required: true, flex: 7),
    ],
  );

  /// รหัสหนี้ — 40604 (สโมสร) ยกเลิกแล้ว backend ไม่ส่งมาและไม่ให้เพิ่ม
  static const debtCodes = MasterResource(
    path: 'debt-codes',
    title: 'รหัสหนี้',
    itemName: 'รหัสหนี้',
    icon: Icons.tag,
    fields: [
      MasterField(
        'mcode',
        'รหัสหนี้',
        required: true,
        digits: true,
        minLength: 5,
        maxLength: 5,
        flex: 2,
      ),
      MasterField('shrt', 'ชื่อรหัสหนี้', required: true, flex: 7),
    ],
  );

  static const divs = MasterResource(
    path: 'divs',
    title: 'รายชื่อหน่วยงาน',
    itemName: 'หน่วยงาน',
    icon: Icons.apartment,
    fields: [
      MasterField(
        'div',
        'รหัสหน่วยงาน',
        required: true,
        digits: true,
        minLength: 3,
        maxLength: 10,
        flex: 2,
      ),
      MasterField('divname', 'ชื่อหน่วยงาน', required: true, flex: 7),
      MasterField(
        'div_order',
        'ลำดับ',
        required: true,
        digits: true,
        minLength: 1,
        maxLength: 6,
        flex: 2,
      ),
      MasterField(
        'center_dept',
        'ส่วนกลาง',
        required: true,
        choices: {'t': 'ส่วนกลาง', 'f': 'ไม่ใช่'},
        flex: 2,
      ),
    ],
  );

  /// รหัสหนี้ที่ยกเลิกแล้ว ห้ามเพิ่ม (backend ปฏิเสธเช่นกัน)
  static const String cancelledDebtCode = '40604';
}
