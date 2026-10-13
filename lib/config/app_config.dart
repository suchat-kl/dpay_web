import 'package:flutter/material.dart';

/// ค่าคงที่ประจำระบบหักหนี้ — ชื่อระบบ ไอคอน และคีย์ของที่เก็บในเบราว์เซอร์อยู่ที่นี่จุดเดียว
///
/// ทุกหน้าจออ่านชื่อระบบ ไอคอน และคีย์ของที่เก็บในเบราว์เซอร์จากคลาสนี้
/// ห้ามพิมพ์ชื่อระบบหรือคีย์ซ้ำลงในหน้าจอ (ดูรายการจุดที่ต้องเปลี่ยนใน README.md)
class AppConfig {
  AppConfig._();

  /// ชื่อระบบ แสดงที่แถบบน หน้าแรก หน้าต่างเข้าสู่ระบบ เมนูข้าง และส่วนท้าย
  static const String systemName = 'ระบบหักหนี้';

  /// ชื่อหน่วยงานเจ้าของระบบ แสดงใต้ชื่อระบบและในแถบลิขสิทธิ์
  static const String organizationName = 'กรมทางหลวง';

  /// คำอธิบายสั้น ๆ ของระบบ แสดงที่ส่วนท้ายหน้าแรก
  static const String systemTagline =
      'บันทึกและจัดการรายการหักหนี้ของข้าราชการและลูกจ้างประจำ';

  /// ไอคอนประจำระบบ (แถบบน เมนูข้าง หน้าต่างเข้าสู่ระบบ ภาพหัวหน้าแรก ส่วนท้าย)
  static const IconData systemIcon = Icons.account_balance_wallet_outlined;

  /// เลขเวอร์ชันที่แสดงท้ายเมนูข้าง (ให้ตรงกับ `version` ใน pubspec.yaml)
  static const String version = '1.0.0';

  /// คำนำหน้าคีย์ของที่เก็บในเบราว์เซอร์
  ///
  /// หลายระบบที่วางบนเครื่องเดียวกันใช้ origin เดียวกัน คีย์จึงต้องไม่ชนกัน
  /// ไม่งั้นธีม/เมนูที่ตรึงจะปนกัน และออกจากระบบที่หนึ่งจะลบ token ของอีกที่
  static const String storagePrefix = 'dpay_';

  /// localStorage: รหัสธีมที่ผู้ใช้เลือก
  static const String themeStorageKey = '${storagePrefix}theme';

  /// localStorage: ตรึงเมนูข้างไว้หรือไม่ ('1' / '0')
  static const String menuPinnedStorageKey = '${storagePrefix}menu_pinned';

  /// ชื่อคลังของ flutter_secure_storage (token และข้อมูล session)
  /// คีย์ใน localStorage จะเป็น `<ชื่อนี้>` และ `<ชื่อนี้>.<คีย์>`
  static const String secureStorageName = '${storagePrefix}secure_storage';
}
