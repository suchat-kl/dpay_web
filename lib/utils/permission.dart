// lib/utils/permission.dart
import '../services/api_service.dart';

/// บทบาทของระบบ — ชื่อสั้นตามที่ backend ส่งใน `roles[]` (ในฐานมีคำนำหน้า ROLE_ แต่ API ไม่มี)
class Roles {
  Roles._();

  /// หน่วยงาน บันทึกรายการหักหนี้ของหน่วยงานตัวเอง
  static const String user = 'USER';

  /// ฝ่ายบัญชี: เตรียมข้อมูล ตั้งงวด ข้อความแจ้ง ช่วงเวลาแก้ไข (ไม่ติดช่วงเวลาแก้ไข)
  static const String account = 'ACCOUNT';

  /// ตั้งรหัสผ่านใหม่ให้บัญชีหน่วยงาน
  static const String resetPwd = 'RESETPWD';

  /// เลือกหน่วยงานส่วนกลางได้
  static const String centerDept = 'CENTER_DEPT';

  /// เลือกได้ทุกหน่วยงาน
  static const String allDept = 'ALL_DEPT';

  /// ผู้ดูแลระบบ จัดการบัญชีผู้ใช้
  static const String admin = 'ADMIN';

  /// ทุกบทบาทตามลำดับที่แสดง (ลำดับเดียวกับ backend)
  static const List<String> order = [
    user,
    account,
    resetPwd,
    centerDept,
    allDept,
    admin,
  ];

  /// ชื่อไทยแบบสั้น ใช้เป็นป้ายบนรายการผู้ใช้และโปรไฟล์
  static const Map<String, String> names = {
    user: 'หน่วยงาน',
    account: 'ฝ่ายบัญชี',
    resetPwd: 'กำหนดรหัสผ่าน',
    centerDept: 'หน่วยงานส่วนกลาง',
    allDept: 'ทุกหน่วยงาน',
    admin: 'ผู้ดูแลระบบ',
  };

  /// ชื่อไทยของบทบาท ไม่รู้จัก = คืนรหัสเดิม
  static String nameOf(String code) => names[code] ?? code;

  /// บทบาทที่ผู้ถือ RESETPWD (ที่ไม่ใช่ ADMIN) ตั้งรหัสผ่านให้ไม่ได้ — กติกาเดียวกับ backend
  static const List<String> privileged = [admin, account, resetPwd];
}

/// หน้าจอ/เมนูของระบบ กับบทบาทที่เปิดได้ — จุดเดียวที่ผูกเมนูกับบทบาท
///
/// backend ของระบบนี้กันสิทธิ์ตามบทบาท (ไม่มีตารางสิทธิ์รายหน้าจอ) หน้าเว็บจึงตัดสินจาก `roles[]`
/// ของผู้ที่เข้าสู่ระบบ หน้าเว็บแค่ซ่อนเมนู การกันจริงอยู่ที่ backend เสมอ
/// หน้าจอใหม่: เพิ่มรหัสที่นี่และใน [_allowedRoles]
class Perm {
  Perm._();

  /// กำหนดเดือนปี (งวดปัจจุบัน)
  static const String period = 'SET_PERIOD';

  /// ข้อความแจ้งผู้ใช้งาน
  static const String alertMessage = 'SET_ALERT';

  /// ระยะเวลาแก้ไขข้อมูล
  static const String editWindow = 'SET_EDIT_WINDOW';

  /// กำหนดรหัสผ่านใหม่ให้หน่วยงาน
  static const String userResetPassword = 'USR_RESET_PWD';

  /// จัดการผู้ใช้ (รายการ สร้าง แก้ไข ระงับ ปลดล็อก บทบาท)
  static const String userManage = 'USR_MANAGE';

  /// เมนูกลุ่ม "เตรียมข้อมูล" ของฝ่ายบัญชี (ข้อมูลหลัก งานงวด ทะเบียนธนาคาร และเมนูที่ยังรอ API)
  static const String prepare = 'PREPARE';

  /// บันทึกข้อมูล (รายการหักหนี้ของหน่วยงาน) — ทุกบทบาท
  static const String debtEntry = 'DEBT_ENTRY';

  /// รายงาน — ทุกบทบาท
  static const String report = 'REPORT';

  /// บทบาทที่เปิดหน้าจอนั้นได้ (ถือบทบาทใดบทบาทหนึ่งก็พอ)
  static const Map<String, List<String>> _allowedRoles = {
    prepare: [Roles.account],
    debtEntry: Roles.order,
    report: Roles.order,
    period: [Roles.account],
    alertMessage: [Roles.account],
    editWindow: [Roles.account],
    userResetPassword: [Roles.resetPwd, Roles.admin],
    userManage: [Roles.admin],
  };

  /// ผู้ถือบทบาทชุด [roles] เปิดหน้าจอ [screenCode] ได้ไหม รหัสที่ไม่รู้จัก = ไม่ได้
  static bool allows(String screenCode, Iterable<String> roles) {
    final allowed = _allowedRoles[screenCode];
    return allowed != null && roles.any(allowed.contains);
  }

  /// ผู้ที่เข้าสู่ระบบอยู่เปิดหน้าจอนี้ได้ไหม (ยังไม่เข้าสู่ระบบ = ไม่ได้)
  static bool view(String screenCode) => ApiService().canView(screenCode);

  /// บัญชีผู้ดูแลระบบ
  static bool get isAdmin => ApiService().hasRole(Roles.admin);

  /// บัญชีฝ่ายบัญชี
  static bool get isAccount => ApiService().hasRole(Roles.account);
}

/// รหัสข้อผิดพลาดของ backend (ช่อง `code` ของคำตอบ `{code, message, success:false}`)
///
/// หน้าจอแยกกรณีด้วย `ApiException.code` เทียบกับค่าคงที่ชุดนี้ ห้ามจับคำในข้อความ
class ErrorCodes {
  ErrorCodes._();

  static const String unauthenticated = 'UNAUTHENTICATED';
  static const String badCredentials = 'BAD_CREDENTIALS';
  static const String accountLocked = 'ACCOUNT_LOCKED';
  static const String accountDisabled = 'ACCOUNT_DISABLED';
  static const String refreshTokenInvalid = 'REFRESH_TOKEN_INVALID';
  static const String forbidden = 'FORBIDDEN';
  static const String divForbidden = 'DIV_FORBIDDEN';
  static const String editWindowClosed = 'EDIT_WINDOW_CLOSED';
  static const String passwordChangeRequired = 'PASSWORD_CHANGE_REQUIRED';
  static const String duplicate = 'DUPLICATE';
  static const String inUse = 'IN_USE';
  static const String confirmRequired = 'CONFIRM_REQUIRED';
  static const String jobRunning = 'JOB_RUNNING';
  static const String loanAmountMismatch = 'LOAN_AMOUNT_MISMATCH';
  static const String slipApiNotConfigured = 'SLIP_API_NOT_CONFIGURED';
  static const String slipApiError = 'SLIP_API_ERROR';
  static const String periodNotReady = 'PERIOD_NOT_READY';
  static const String notCurrentPeriod = 'NOT_CURRENT_PERIOD';
  static const String dpisError = 'DPIS_ERROR';
  static const String badRequest = 'BAD_REQUEST';
  static const String notFound = 'NOT_FOUND';
  static const String methodNotAllowed = 'METHOD_NOT_ALLOWED';
  static const String internalError = 'INTERNAL_ERROR';
}
