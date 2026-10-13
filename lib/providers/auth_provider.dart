import 'package:flutter/foundation.dart';
import '../models/div_dept.dart';
import '../services/api_service.dart';
import '../utils/permission.dart';

/// สถานะเข้าสู่ระบบของแอป — หน้าจอฟังตัวนี้ (ChangeNotifier) แล้ววาดใหม่เมื่อเข้า/ออกจากระบบ
///
/// ข้อมูล session จริงอยู่ที่ [ApiService] (singleton) คลาสนี้เป็นหน้าต่างให้หน้าจออ่าน
/// และรวม getter ของบทบาท / หน่วยงาน / สิทธิ์เปิดหน้าจอ / ชื่อที่แสดงไว้ที่เดียว
class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool get isLoggedIn => _apiService.isLoggedIn;

  /// ชื่อผู้ใช้ = รหัสหน่วยงาน/รหัสงาน 3 หลัก
  String? get username => _apiService.username;
  String? get fullName => _apiService.fullName;

  /// รหัสหน่วยงานของผู้ใช้
  String? get div => _apiService.div;

  /// ชื่อหน่วยงานของผู้ใช้
  String? get divName => _apiService.divName;

  /// ขอบเขตหน่วยงานที่ผู้ใช้เลือกได้ (ของตัวเอง / ส่วนกลาง / ทั้งหมด)
  DivScope get divScope => _apiService.divScope;

  /// ชื่อบทบาทแบบสั้น (USER, ACCOUNT, ...)
  List<String> get roles => _apiService.roles;

  bool hasRole(String role) => _apiService.hasRole(role);

  /// ผู้ดูแลระบบ (จัดการผู้ใช้)
  bool get isAdmin => hasRole(Roles.admin);

  /// ฝ่ายบัญชี (ตั้งงวด ข้อความแจ้ง ระยะเวลาแก้ไข)
  bool get isAccount => hasRole(Roles.account);

  /// ผู้ที่เข้าสู่ระบบอยู่เปิดหน้าจอ [screenCode] (ดู `Perm`) ได้ไหม
  bool canView(String screenCode) => _apiService.canView(screenCode);

  AuthProvider() {
    // ApiService แจ้งทุกครั้งที่สถานะเข้าสู่ระบบเปลี่ยน รวมกรณี token ต่ออายุไม่ได้แล้วถูกออกจากระบบ
    // และกรณี backend แจ้งว่าต้องเปลี่ยนรหัสผ่านก่อน
    _apiService.onLoginStateChanged = (loggedIn) {
      notifyListeners();
    };
  }

  /// เข้าสู่ระบบด้วยชื่อผู้ใช้/รหัสผ่าน ไม่สำเร็จโยน `ApiException` ที่มีข้อความให้ผู้ใช้อ่าน
  Future<void> login(String username, String password) async {
    await _apiService.login(username, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.logout();
    notifyListeners();
  }

  /// กู้ session ที่ค้างในเบราว์เซอร์ตอนเปิดหน้าเว็บ (เรียกครั้งเดียวใน main.dart)
  /// กู้ได้แล้วถามข้อมูลล่าสุดจาก backend อีกครั้ง (บทบาท/หน่วยงาน/ต้องเปลี่ยนรหัสผ่าน อาจเปลี่ยนไปแล้ว)
  Future<bool> loadSession() async {
    final result = await _apiService.loadSession();
    if (result) await _apiService.loadProfile();
    notifyListeners();
    return _apiService.isLoggedIn;
  }

  /// ต้องเปลี่ยนรหัสผ่านก่อนใช้งานส่วนอื่น
  bool get mustChangePassword => _apiService.mustChangePassword;

  /// ชื่อที่แสดงของผู้ใช้ที่เข้าสู่ระบบ (ข้อความต้อนรับ แถบบน เมนูข้าง หน้าแรก ข้อมูลผู้ใช้)
  ///
  /// ใช้ชื่อที่แสดงของบัญชี ไม่มีใช้ชื่อหน่วยงาน ไม่มีอีกใช้ชื่อผู้ใช้
  /// ทุกจุดที่แสดงชื่อใช้ getter นี้ ไม่อ่าน `fullName` ตรง ๆ (อาจว่างหรือเป็น null)
  String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    final dept = (divName ?? '').trim();
    if (dept.isNotEmpty) return dept;
    return username ?? 'ผู้ใช้';
  }

  /// หน่วยงานของผู้ใช้ในบรรทัดเดียว เช่น "030 กองการเงินและบัญชี" ไม่มีข้อมูล = "-"
  String get divLabel {
    final code = (div ?? '').trim();
    final name = (divName ?? '').trim();
    if (code.isEmpty && name.isEmpty) return '-';
    return [code, name].where((s) => s.isNotEmpty).join(' ');
  }

  /// อักษรย่อสำหรับรูปวงกลมแทนตัวผู้ใช้
  String get initials {
    // ตัดด้วยช่องว่างกี่ตัวก็ได้แล้วทิ้งชิ้นที่ว่าง เพราะชื่อในฐานข้อมูล
    // บางระเบียนมีช่องว่างซ้อนหรือช่องว่างท้ายชื่อ ถ้าตัดด้วย ' ' เฉย ๆ
    // จะได้ชิ้นว่างมาแล้ว [0] ระเบิดเป็น RangeError ทั้งหน้าจอ
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// ชื่อบทบาทภาษาไทยของรหัสบทบาทใด ๆ ไม่รู้จัก = คืนรหัสเดิม
  static String roleName(String code) => Roles.nameOf(code);

  /// ชื่อไทยของทุกบทบาทที่ถือ เรียงตามลำดับมาตรฐานของระบบ
  List<String> get roleDisplayNames {
    final sorted = [...roles]..sort((a, b) => _rank(a).compareTo(_rank(b)));
    return sorted.map(roleName).toList();
  }

  static int _rank(String role) {
    final i = Roles.order.indexOf(role);
    return i < 0 ? Roles.order.length : i;
  }

  /// บทบาทที่ใช้แสดงบนป้ายโปรไฟล์ เอาตัวที่บอกงานหลักของบัญชีได้ชัดที่สุด
  ///
  /// CENTER_DEPT / ALL_DEPT เป็นบทบาทบอกขอบเขตหน่วยงาน ไม่ใช่งาน จึงอยู่หลังบทบาทงาน
  String get highestRole {
    const rank = [
      Roles.admin,
      Roles.account,
      Roles.resetPwd,
      Roles.user,
      Roles.allDept,
      Roles.centerDept,
    ];
    for (final r in rank) {
      if (hasRole(r)) return roleName(r);
    }
    return roles.isEmpty ? roleName(Roles.user) : roleName(roles.first);
  }
}
