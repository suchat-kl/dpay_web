/// ผู้ใช้หนึ่งบัญชีในหน้าจัดการผู้ใช้ / กำหนดรหัสผ่านใหม่ (รูปเดียวกับ `UserAdminDTO` ของ backend)
///
/// [UserAdmin.fromJson] ทนต่อช่องที่ backend ไม่ส่งมา (ใช้ค่าตั้งต้นแทน) และข้ามช่องที่ไม่รู้จัก
class UserAdmin {
  /// รหัสเอกสารของบัญชี (ObjectId ของ MongoDB เป็นข้อความ) ว่าง = บัญชีใหม่ที่ยังไม่ได้บันทึก
  final String id;

  /// ชื่อผู้ใช้ = รหัสหน่วยงาน/รหัสงาน 3 หลัก
  final String username;

  /// ชื่อที่แสดงของบัญชี (ชื่อหน่วยงานเจ้าของบัญชี)
  final String fullName;

  /// ไม่บังคับ ไม่มี = ข้อความว่าง
  final String email;

  /// รหัสหน่วยงานของบัญชี
  final String div;

  /// ชื่อหน่วยงานของ [div] (อ่านอย่างเดียว backend หาให้)
  final String divName;

  /// ชื่อบทบาทแบบสั้น เช่น USER, ACCOUNT
  final List<String> roles;

  /// เท็จ = ระงับการใช้งาน เข้าสู่ระบบไม่ได้
  final bool active;

  /// ล็อกจากการใส่รหัสผ่านผิดหลายครั้ง ผู้ดูแลปลดให้ได้
  final bool locked;

  /// ต้องเปลี่ยนรหัสผ่านตอนเข้าสู่ระบบครั้งถัดไป
  final bool mustChangePassword;
  final DateTime? lastLogin;

  const UserAdmin({
    this.id = '',
    required this.username,
    required this.fullName,
    this.email = '',
    this.div = '',
    this.divName = '',
    this.roles = const [],
    this.active = true,
    this.locked = false,
    this.mustChangePassword = false,
    this.lastLogin,
  });

  factory UserAdmin.fromJson(Map<String, dynamic> j) {
    return UserAdmin(
      id: j['id']?.toString() ?? '',
      username: j['username']?.toString() ?? '',
      fullName: j['fullName']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      div: j['div']?.toString() ?? '',
      divName: j['divName']?.toString() ?? '',
      roles: [
        for (final r in j['roles'] as List? ?? const [])
          if (r != null) '$r',
      ],
      active: j['active'] == true,
      locked: j['locked'] == true,
      mustChangePassword: j['mustChangePassword'] == true,
      lastLogin: j['lastLogin'] is String
          ? DateTime.tryParse(j['lastLogin'] as String)
          : null,
    );
  }

  /// ตัวข้อมูลของ PUT /api/admin/users/{id} — id อยู่ใน path ชื่อผู้ใช้แก้ไม่ได้ จึงไม่ส่งสองช่องนี้
  Map<String, dynamic> toUpdateJson() => {
    'fullName': fullName,
    'email': email,
    'div': div,
    'roles': roles,
    'active': active,
    'locked': locked,
  };

  /// ตัวข้อมูลของ POST /api/admin/users (สร้างบัญชีใหม่) [password] = รหัสผ่านตั้งต้น
  Map<String, dynamic> toCreateJson(String password) => {
    'username': username,
    'password': password,
    'fullName': fullName,
    'email': email,
    'div': div,
    'roles': roles,
  };
}
