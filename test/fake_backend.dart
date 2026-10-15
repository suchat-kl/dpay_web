// backend จำลองสำหรับเทสต์ ตอบตามสัญญาของ backend ระบบหักหนี้ระยะที่ 1
// (C:\AI\springboot\dpay — controller/*, dto/*, exception/ErrorCodes.java, service/*)
//
// ใช้เป็น HttpClientAdapter ของ Dio ทั้งสองตัวใน ApiService (dio และ publicDio)
// จึงทดสอบ AuthInterceptor ตัวจริงได้ ไม่ต้องจำลอง interceptor
// ข้อมูลทั้งหมดเป็นค่าสมมุติ (รหัสหน่วยงาน 9xx ไม่มีจริง) ไม่มีชื่อบุคคล รหัสผ่าน หรือ token จริง

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/services/api_service.dart';

part 'fake_backend_phase2.dart';
part 'fake_backend_phase3.dart';

/// โหลดฟอนต์ไทยตัวจริงของโปรเจกต์ ไม่งั้นเทสต์ใช้ฟอนต์ทดสอบที่ทุกตัวอักษรกว้างเท่ากัน
/// ข้อความไทยจะกว้างเกินจริงจนล้นกรอบ (ใช้ใน `setUpAll` หรือ `tester.runAsync`)
Future<void> loadAppFonts() async {
  for (final family in ['NotoSansThai', 'Sarabun', 'Kanit']) {
    final loader = FontLoader(family);
    for (final w in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/$family-$w.ttf'));
    }
    await loader.load();
  }
}

/// บัญชีหนึ่งบัญชีใน backend จำลอง (ชื่อผู้ใช้ = รหัสหน่วยงาน 3 หลัก)
class FakeUser {
  final String id;
  final String username;
  String password;
  String fullName;
  String? email;
  String div;
  List<String> roles;
  bool active;
  bool locked;
  bool mustChange;
  String? lastLogin;

  FakeUser({
    required this.username,
    required this.password,
    required this.fullName,
    required this.roles,
    String? div,
    this.email,
    this.active = true,
    this.locked = false,
    this.mustChange = false,
    this.lastLogin,
  }) : id = 'u$username',
       div = div ?? username;
}

class FakeBackend implements HttpClientAdapter {
  /// รหัสผ่านของบัญชีจำลองทุกบัญชี = `Unit@<ชื่อผู้ใช้>x` (ค่าสมมุติ ผ่านกติการหัสผ่าน)
  static String passwordOf(String username) => 'Unit@${username}x';

  // ── บัญชีที่ใช้ในเทสต์ (ครบ 6 บทบาท) ──
  /// หน่วยงานทั่วไป (USER) ขอบเขต OWN
  static const String user = '901';

  /// ฝ่ายบัญชี (ACCOUNT + ALL_DEPT)
  static const String account = '902';

  /// กำหนดรหัสผ่าน (RESETPWD + USER)
  static const String resetPwd = '903';

  /// หน่วยงานส่วนกลาง (CENTER_DEPT + USER) ขอบเขต CENTER
  static const String centerDept = '904';

  /// ทุกหน่วยงาน (ALL_DEPT + USER) ขอบเขต ALL
  static const String allDept = '905';

  /// ต้องเปลี่ยนรหัสผ่านก่อนใช้งาน (USER)
  static const String newbie = '906';

  /// บัญชีถูกล็อก
  static const String lockedUser = '907';

  /// บัญชีถูกระงับ
  static const String disabledUser = '908';

  /// ผู้ดูแลระบบ (ADMIN + RESETPWD)
  static const String admin = '909';

  /// หน่วยงาน: 901-930 ส่วนกลาง = 902-905 และ 909
  final List<Map<String, dynamic>> divs = [
    for (var i = 901; i <= 930; i++)
      {
        'div': '$i',
        'divname': switch (i) {
          902 => 'กองบัญชีตัวอย่าง',
          909 => 'ศูนย์ดูแลระบบตัวอย่าง',
          _ => 'หน่วยงานตัวอย่างที่ ${i - 900}',
        },
        'center': (i >= 902 && i <= 905) || i == 909,
      },
  ];

  /// รหัสสังกัดของหน่วยงาน (dpay_divconv)
  final Map<String, List<String>> successDepts = {
    '901': ['G000901', 'E000901'],
    '902': ['G000902'],
  };

  late final Map<String, FakeUser> users = {
    for (final u in [
      FakeUser(
        username: user,
        password: passwordOf(user),
        fullName: 'หน่วยงานตัวอย่างที่ 1',
        roles: ['USER'],
        lastLogin: '2025-06-24T08:30:00',
      ),
      FakeUser(
        username: account,
        password: passwordOf(account),
        fullName: 'กองบัญชีตัวอย่าง',
        roles: ['ACCOUNT', 'ALL_DEPT'],
      ),
      FakeUser(
        username: resetPwd,
        password: passwordOf(resetPwd),
        fullName: 'หน่วยงานตัวอย่างที่ 3',
        roles: ['USER', 'RESETPWD'],
      ),
      FakeUser(
        username: centerDept,
        password: passwordOf(centerDept),
        fullName: 'หน่วยงานตัวอย่างที่ 4',
        roles: ['USER', 'CENTER_DEPT'],
      ),
      FakeUser(
        username: allDept,
        password: passwordOf(allDept),
        fullName: 'หน่วยงานตัวอย่างที่ 5',
        roles: ['USER', 'ALL_DEPT'],
      ),
      FakeUser(
        username: newbie,
        password: passwordOf(newbie),
        fullName: 'หน่วยงานตัวอย่างที่ 6',
        roles: ['USER'],
        mustChange: true,
      ),
      FakeUser(
        username: lockedUser,
        password: passwordOf(lockedUser),
        fullName: 'หน่วยงานตัวอย่างที่ 7',
        roles: ['USER'],
        locked: true,
      ),
      FakeUser(
        username: disabledUser,
        password: passwordOf(disabledUser),
        fullName: 'หน่วยงานตัวอย่างที่ 8',
        roles: ['USER'],
        active: false,
      ),
      FakeUser(
        username: admin,
        password: passwordOf(admin),
        fullName: 'ศูนย์ดูแลระบบตัวอย่าง',
        email: 'admin909@example.com',
        roles: ['RESETPWD', 'ADMIN'],
      ),
      // บัญชีหน่วยงานเพิ่มเติมให้รายการผู้ใช้แบ่งหน้าได้ (รวมทั้งหมด 26 บัญชี)
      for (var i = 910; i <= 926; i++)
        FakeUser(
          username: '$i',
          password: passwordOf('$i'),
          fullName: 'หน่วยงานตัวอย่างที่ ${i - 900}',
          roles: ['USER'],
        ),
    ])
      u.username: u,
  };

  /// บทบาทที่ /api/admin/roles ตอบ (ลำดับและคำอธิบายเดียวกับ backend)
  List<Map<String, dynamic>> roles = [
    {
      'name': 'USER',
      'description': 'หน่วยงาน บันทึกรายการหักหนี้ของหน่วยงานตัวเอง',
    },
    {
      'name': 'ACCOUNT',
      'description':
          'ฝ่ายบัญชี/เงินเดือน เตรียมข้อมูล ตั้งงวด ข้อความแจ้ง และช่วงเวลาแก้ไข',
    },
    {'name': 'RESETPWD', 'description': 'ตั้งรหัสผ่านใหม่ให้บัญชีหน่วยงาน'},
    {'name': 'CENTER_DEPT', 'description': 'เลือกหน่วยงานส่วนกลางได้'},
    {'name': 'ALL_DEPT', 'description': 'เลือกได้ทุกหน่วยงาน'},
    {'name': 'ADMIN', 'description': 'ผู้ดูแลระบบ จัดการบัญชีผู้ใช้'},
  ];

  // ── ค่าตั้งกลาง ──
  String periodMonth = '07';
  String periodYear = '2568';

  /// ข้อความแจ้งผู้ใช้งาน (หลายบรรทัด)
  String alertMessage =
      'แจ้งหน่วยงานทุกแห่ง\n'
      'งวดนี้เปิดให้บันทึกรายการหักหนี้ตามระยะเวลาที่กำหนด\n'
      'หากพบปัญหาให้ติดต่อกองบัญชีตัวอย่าง';

  String? beginDate = '2025-06-23';
  String? endDate = '2025-07-03';
  String beginTime = '06:00';
  String endTime = '11:00';

  /// เวลาของเครื่อง backend จำลอง (เวลาไทย) ใช้ตัดสินว่าช่วงแก้ไขเปิดอยู่ไหม
  DateTime serverTime = DateTime(2025, 6, 25, 9, 30);

  /// กติกาเดียวกับ backend: ช่วงต่อเนื่องช่วงเดียว รวมปลาย ละเอียดระดับนาที ค่าขาด = ปิด
  bool get windowOpen {
    DateTime? at(String? date, String time) {
      final d = DateTime.tryParse('${date ?? ''}T$time:00');
      return d;
    }

    final begin = at(beginDate, beginTime);
    final end = at(endDate, endTime);
    if (begin == null || end == null) return false;
    return !serverTime.isBefore(begin) && !serverTime.isAfter(end);
  }

  // ── ตัวปรับสำหรับจำลองสถานการณ์ ──
  /// จริง = ทุกคำขอต่อเซิร์ฟเวอร์ไม่ได้ (จำลองเน็ตหลุด / backend ปิดอยู่)
  bool unreachable = false;

  /// ไม่เป็น null = /api/admin/roles ตอบรหัสสถานะนี้แทน (จำลอง backend ล่ม)
  int? rolesStatus;

  /// ไม่เป็น null = GET /api/alert-message ตอบรหัสสถานะนี้แทน
  int? alertStatus;

  /// path ที่จำลองให้ตอบ 500 (เช่นเส้นสรุปล้ม) — ตรวจก่อนเส้นอื่นทั้งหมด
  final Set<String> failPaths = {};

  /// จริง = ผล login ไม่มีช่อง must_change_password (หน้าเว็บต้องรู้จาก 403 PASSWORD_CHANGE_REQUIRED เอง)
  bool hideMustChangeInLogin = false;

  // ── ข้อความของ backend ที่เทสต์อ้างถึง ──
  static const String badCredentialsMessage =
      'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';
  static const String lockedMessage =
      'บัญชีถูกล็อกชั่วคราวเพราะใส่รหัสผ่านผิด 5 ครั้ง กรุณาลองใหม่ในอีก 10 นาที';
  static const String disabledMessage =
      'บัญชีนี้ถูกระงับการใช้งาน กรุณาติดต่อผู้ดูแลระบบ';
  static const String unauthenticatedMessage = 'กรุณาเข้าสู่ระบบ';
  static const String forbiddenMessage = 'ไม่มีสิทธิ์ใช้งานส่วนนี้';
  static const String divForbiddenMessage =
      'ไม่มีสิทธิ์กับข้อมูลของหน่วยงานนี้';
  static const String mustChangeMessage = 'กรุณาเปลี่ยนรหัสผ่านก่อนใช้งาน';
  static const String wrongOldPasswordMessage = 'รหัสผ่านเดิมไม่ถูกต้อง';
  static const String sameOldPasswordMessage =
      'รหัสผ่านใหม่ต้องไม่เหมือนกับรหัสผ่านเดิม';
  static const String usernameRuleMessage =
      'ชื่อผู้ใช้ต้องเป็นตัวเลข 3-10 หลัก';
  static const String usernameTakenMessage = 'ชื่อผู้ใช้นี้ถูกใช้งานแล้ว';
  static const String userNotFoundMessage = 'ไม่พบผู้ใช้ที่ระบุ';
  static const String resetSelfMessage =
      'ตั้งรหัสผ่านใหม่ให้บัญชีของตัวเองไม่ได้ กรุณาใช้เมนูเปลี่ยนรหัสผ่าน';
  static const String resetPrivilegedMessage =
      'ตั้งรหัสผ่านให้บัญชีนี้ไม่ได้ กรุณาติดต่อผู้ดูแลระบบ';
  static const String resetDoneMessage =
      'ตั้งรหัสผ่านใหม่สำเร็จ ผู้ใช้ต้องเปลี่ยนรหัสผ่านตอนเข้าสู่ระบบครั้งถัดไป';
  static const String savedMessage = 'บันทึกข้อมูลสำเร็จ';
  static const String windowOrderMessage =
      'วัน-เวลาสิ้นสุดต้องไม่ก่อนวัน-เวลาเริ่ม';
  static const String deactivateSelfMessage =
      'ระงับการใช้งานบัญชีของตัวเองไม่ได้';
  // ── ข้อความของระยะที่ 2 ──
  static const String masterDuplicateMessage = 'ข้อมูลซ้ำกับที่มีอยู่';
  static const String masterInUseMessage =
      'ลบหรือเปลี่ยนรหัสไม่ได้ เพราะมีข้อมูลอื่นอ้างถึง';
  static const String jobRunningMessage =
      'มีผู้สั่งงานนี้ค้างอยู่ กรุณารอสักครู่';
  static const String dpisErrorMessage =
      'เรียกระบบข้อมูลบุคลากร (DPIS) ไม่สำเร็จ กรุณาลองใหม่ภายหลัง';
  static const String periodNotReadyMessage =
      'การเตรียมข้อมูลงวดยังไม่เสร็จ ยังแก้ไขยอดไม่ได้';
  static const String notCurrentPeriodMessage =
      'แก้ไขได้เฉพาะรายการของงวดปัจจุบัน';
  static const String deductDuplicateMessage =
      'เลขประจำตัวประชาชนนี้มีทะเบียนอยู่แล้ว';
  static const String loanDuplicateMessage = 'บุคคลนี้มีเลขที่บัญชีนี้อยู่แล้ว';

  /// ข้อมูลและตัวปรับของระยะที่ 2 (ข้อมูลหลัก งานงวด รายการหนี้ ทะเบียน เงินกู้)
  final FakePhase2 p2 = FakePhase2();

  /// ข้อมูลและตัวปรับของระยะที่ 3 (สหกรณ์ ฌาปนกิจ ไฟล์ส่งกรมบัญชีกลาง กระทบยอดเงินกู้ รายงาน)
  final FakePhase3 p3 = FakePhase3();

  /// จำนวนสูงสุดที่ /api/persons/search คืน (ของจริง 50 — เทสต์ลดลงเพื่อดู truncated)
  int personSearchLimit = 50;

  static const String editWindowClosedMessage =
      'อยู่นอกช่วงวัน-เวลาที่เปิดให้แก้ไขข้อมูล';

  /// ทุกคำขอที่เข้ามา รูป "METHOD path"
  final List<String> calls = [];

  /// query string ของแต่ละคำขอ เรียงตรงกับ [calls]
  final List<Map<String, dynamic>> queries = [];

  /// ตัวข้อมูลของแต่ละคำขอ เรียงตรงกับ [calls] (ไม่มี = null)
  final List<Map<String, dynamic>?> bodies = [];

  /// ค่า Authorization ของแต่ละคำขอ เรียงตรงกับ [calls] (ไม่มี = null)
  final List<String?> authHeaders = [];

  /// ล้างบันทึกคำขอทั้งหมด (ใช้หลังเข้าสู่ระบบใน setUp เพื่อดูเฉพาะคำขอของเทสต์)
  /// connectTimeout ของแต่ละคำขอ (บนเว็บคือเวลาที่รอ backend ประมวลผลจนได้ header)
  final List<Duration?> connectTimeouts = [];

  void clearLog() {
    calls.clear();
    queries.clear();
    bodies.clear();
    authHeaders.clear();
    connectTimeouts.clear();
  }

  /// ตัวข้อมูลของคำขอล่าสุดที่ตรงกับ [call] (รูป "METHOD path")
  Map<String, dynamic>? bodyOf(String call) {
    final i = calls.lastIndexOf(call);
    return i < 0 ? null : bodies[i];
  }

  /// query string ของคำขอล่าสุดที่ตรงกับ [call]
  Map<String, dynamic>? queryOf(String call) {
    final i = calls.lastIndexOf(call);
    return i < 0 ? null : queries[i];
  }

  int count(String call) => calls.where((c) => c == call).length;

  /// access token ที่ยังใช้ได้ -> username
  final Map<String, String> _access = {};

  /// refresh token ที่ยังใช้ได้ -> username
  final Map<String, String> _refresh = {};

  int _serial = 0;

  /// จำลอง access token หมดอายุฝั่ง backend (เวลาใน token ยังไม่ถึง หน้าเว็บจึงไม่รู้ล่วงหน้า)
  void expireAccessTokens() => _access.clear();

  /// จำลอง refresh token ถูกเพิกถอน ต่ออายุไม่ได้อีก
  void revokeRefreshTokens() => _refresh.clear();

  /// refresh token ที่ยังใช้ได้ทั้งหมด (ใช้ตรวจว่าตัวเก่าถูกเผาแล้ว)
  Set<String> get liveRefreshTokens => _refresh.keys.toSet();

  void _revokeAll(String username) {
    _access.removeWhere((_, u) => u == username);
    _refresh.removeWhere((_, u) => u == username);
  }

  /// token รูป JWT มีช่อง exp อีก 1 ชั่วโมง ให้ ApiService.isTokenExpired อ่านได้ (ค่าสมมุติ ไม่ได้เซ็น)
  String _jwt(String username) {
    String part(Object o) =>
        base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    return '${part({'alg': 'none'})}.'
        '${part({'sub': username, 'exp': exp, 'n': ++_serial})}.sig';
  }

  Map<String, dynamic> _issue(String username) {
    final access = _jwt(username);
    // ผู้ใช้หนึ่งคนมี access token ที่ใช้ได้ทีละตัว (แบบเดียวกับ backend)
    _access.removeWhere((_, u) => u == username);
    _access[access] = username;
    final token = 'fake-refresh-${++_serial}-$username';
    _refresh[token] = username;
    return {
      'access_token': access,
      'refresh_token': token,
      'token_type': 'Bearer',
      'expires_in': 900,
    };
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  /// ข้อผิดพลาดรูปเดียวของ backend: {code, message, success:false}
  ResponseBody _error(int status, String code, String message) =>
      _json(status, {'code': code, 'message': message, 'success': false});

  ResponseBody _bad(String message) => _error(400, 'BAD_REQUEST', message);

  ResponseBody _forbidden([String message = forbiddenMessage]) =>
      _error(403, 'FORBIDDEN', message);

  String _scope(FakeUser u) =>
      u.roles.contains('ALL_DEPT') || u.roles.contains('ADMIN')
      ? 'ALL'
      : u.roles.contains('CENTER_DEPT')
      ? 'CENTER'
      : 'OWN';

  String? _divName(String div) {
    for (final d in divs) {
      if (d['div'] == div) return d['divname'] as String;
    }
    return null;
  }

  bool _isCenter(String div) =>
      divs.any((d) => d['div'] == div && d['center'] == true);

  bool _canAccessDiv(FakeUser u, String div) {
    if (!RegExp(r'^\d{3}$').hasMatch(div)) return false;
    if (div == u.div) return true;
    return switch (_scope(u)) {
      'ALL' => true,
      'CENTER' => _isCenter(div),
      _ => false,
    };
  }

  // ฝ่ายบัญชีและผู้ดูแลระบบแก้ได้ตลอด ผู้ใช้ทั่วไปเฉพาะในระยะเวลาแก้ไข (แบบ AccessGuard.canEditNow)
  bool _canEditNow(FakeUser u) =>
      u.roles.contains('ACCOUNT') || u.roles.contains('ADMIN') || windowOpen;

  Map<String, dynamic> _profile(FakeUser u) => {
    'username': u.username,
    'full_name': u.fullName,
    'div': u.div,
    'div_name': _divName(u.div),
    'roles': u.roles,
    'div_scope': _scope(u),
  };

  /// รูปเดียวกับ UserAdminDTO (password ไม่ถูกส่งกลับ)
  Map<String, dynamic> userDto(FakeUser u) => {
    'id': u.id,
    'username': u.username,
    'password': null,
    'fullName': u.fullName,
    'email': u.email,
    'div': u.div,
    'divName': _divName(u.div),
    'roles': u.roles,
    'active': u.active,
    'locked': u.locked,
    'mustChangePassword': u.mustChange,
    'lastLogin': u.lastLogin,
  };

  Map<String, dynamic> _windowView(FakeUser u) => {
    'beginDate': beginDate,
    'endDate': endDate,
    'beginTime': beginTime,
    'endTime': endTime,
    'open': windowOpen,
    'can_edit_now': _canEditNow(u),
    'server_time': serverTime.toIso8601String().substring(0, 19),
  };

  /// กติกาเดียวกับ PasswordPolicy.validateStrength คืนข้อความผิดพลาด (ผ่าน = null)
  static String? passwordProblem(String? p) {
    if (p == null || p.length < 8) {
      return 'รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร';
    }
    if (p.length > 72) return 'รหัสผ่านต้องยาวไม่เกิน 72 ตัวอักษร';
    if (!p.contains(RegExp(r'[A-Z]'))) {
      return 'รหัสผ่านต้องมีตัวอักษรพิมพ์ใหญ่อย่างน้อย 1 ตัว';
    }
    if (!p.contains(RegExp(r'[a-z]'))) {
      return 'รหัสผ่านต้องมีตัวอักษรพิมพ์เล็กอย่างน้อย 1 ตัว';
    }
    if (!p.contains(RegExp(r'\d'))) {
      return 'รหัสผ่านต้องมีตัวเลขอย่างน้อย 1 ตัว';
    }
    if (!p.contains(RegExp(r'[^A-Za-z0-9]'))) {
      return 'รหัสผ่านต้องมีอักขระพิเศษอย่างน้อย 1 ตัว';
    }
    return null;
  }

  static const List<String> _roleOrder = [
    'USER',
    'ACCOUNT',
    'RESETPWD',
    'CENTER_DEPT',
    'ALL_DEPT',
    'ADMIN',
  ];

  /// ตรวจบทบาท/หน่วยงาน/ชื่อของฟอร์มผู้ใช้ คืนข้อความผิดพลาด (ผ่าน = null)
  String? _userFormProblem(Map<String, dynamic>? body) {
    final roles = (body?['roles'] as List?) ?? const [];
    for (final r in roles) {
      if (!_roleOrder.contains(r)) return 'ไม่พบบทบาท $r';
    }
    if (roles.isEmpty) return 'กรุณาเลือกบทบาทอย่างน้อย 1 บทบาท';
    final name = '${body?['fullName'] ?? ''}'.trim();
    if (name.length < 3) return 'กรุณากรอกชื่อที่แสดง อย่างน้อย 3 ตัวอักษร';
    final div = '${body?['div'] ?? ''}'.trim();
    if (div.isEmpty) return 'กรุณาระบุรหัสหน่วยงาน';
    if (!RegExp(r'^\d{3}$').hasMatch(div)) return 'รหัสหน่วยงานไม่ถูกต้อง';
    if (_divName(div) == null) return 'ไม่พบหน่วยงานรหัส $div';
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method;
    final auth = options.headers['Authorization'] as String?;
    calls.add('$method $path');
    authHeaders.add(auth);
    connectTimeouts.add(options.connectTimeout);
    final data = options.data;
    // อัปโหลดไฟล์ (multipart): บันทึกช่องของฟอร์ม + ชื่อและขนาดไฟล์ ให้เทสต์ตรวจได้
    final body = data is Map
        ? Map<String, dynamic>.from(data)
        : data is FormData
        ? <String, dynamic>{
            for (final f in data.fields) f.key: f.value,
            for (final f in data.files) ...{
              f.key: f.value.filename,
              '${f.key}_size': f.value.length,
            },
          }
        : null;
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    bodies.add(body);

    if (unreachable) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'จำลองต่อเซิร์ฟเวอร์ไม่ได้',
      );
    }

    if (failPaths.contains(path)) {
      return _error(500, 'INTERNAL_ERROR', 'จำลองเส้นนี้ล้ม');
    }

    // ── เส้นสาธารณะ 3 เส้น ──
    if (path == '/api/auth/login' && method == 'POST') {
      final u = users[body?['username']];
      if (u != null && u.locked) {
        return _error(401, 'ACCOUNT_LOCKED', lockedMessage);
      }
      if (u == null || u.password != body?['password']) {
        return _error(401, 'BAD_CREDENTIALS', badCredentialsMessage);
      }
      if (!u.active) {
        return _error(401, 'ACCOUNT_DISABLED', disabledMessage);
      }
      return _json(200, {
        ..._issue(u.username),
        'message': 'เข้าสู่ระบบสำเร็จ',
        ..._profile(u),
        if (!hideMustChangeInLogin) 'must_change_password': u.mustChange,
      });
    }

    if (path == '/api/auth/refresh-token' && method == 'POST') {
      // refresh token ใช้ได้ครั้งเดียว: ใช้แล้วถูกลบ ได้ตัวใหม่มาแทน
      final username = _refresh.remove(body?['refresh_token']);
      if (username == null) {
        return _error(
          403,
          'REFRESH_TOKEN_INVALID',
          'Refresh Token ใช้ไม่ได้แล้ว กรุณาเข้าสู่ระบบใหม่',
        );
      }
      return _json(200, {
        ..._issue(username),
        'message': 'ต่ออายุ token สำเร็จ',
      });
    }

    if (path == '/api/alert-message' && method == 'GET') {
      if (alertStatus != null) {
        return _error(
          alertStatus!,
          'INTERNAL_ERROR',
          'เกิดข้อผิดพลาด กรุณาลองใหม่ภายหลัง',
        );
      }
      return _json(200, {'msg': alertMessage});
    }

    // ── ที่เหลือต้องแนบ access token ที่ยังใช้ได้ ไม่งั้น 401 UNAUTHENTICATED ──
    final token = (auth != null && auth.startsWith('Bearer '))
        ? auth.substring(7)
        : null;
    final username = _access[token];
    if (username == null) {
      return _error(401, 'UNAUTHENTICATED', unauthenticatedMessage);
    }
    final me = users[username]!;
    // ผู้ดูแลระบบถือว่ามีทุกบทบาท (แบบ User.hasRole ของ backend)
    bool has(String role) =>
        me.roles.contains(role) || me.roles.contains('ADMIN');

    // ── /api/auth/** ใช้ได้แม้ต้องเปลี่ยนรหัสผ่าน ──
    if (path == '/api/auth/logout' && method == 'POST') {
      _access.remove(token);
      _refresh.remove(body?['refresh_token']);
      return _json(200, {'message': 'ออกจากระบบสำเร็จ', 'success': true});
    }

    if (path == '/api/auth/me' && method == 'GET') {
      return _json(200, {
        ..._profile(me),
        'can_edit_now': _canEditNow(me),
        'must_change_password': me.mustChange,
      });
    }

    if (path == '/api/auth/changepassword' && method == 'POST') {
      final oldPassword = body?['oldPassword'];
      final newPassword = body?['newPassword'];
      if (oldPassword is! String || oldPassword.isEmpty) {
        return _bad('กรุณากรอกรหัสผ่านเดิม');
      }
      if (newPassword is! String || newPassword.isEmpty) {
        return _bad('กรุณากรอกรหัสผ่านใหม่');
      }
      if (me.locked) {
        return _error(
          403,
          'ACCOUNT_LOCKED',
          'บัญชีผู้ใช้ถูกล็อก กรุณาติดต่อผู้ดูแลระบบ',
        );
      }
      if (oldPassword != me.password) return _bad(wrongOldPasswordMessage);
      if (newPassword == me.password) return _bad(sameOldPasswordMessage);
      final problem = passwordProblem(newPassword);
      if (problem != null) return _bad(problem);
      me.password = newPassword;
      me.mustChange = false;
      return _json(200, {'message': 'เปลี่ยนรหัสผ่านสำเร็จ', 'success': true});
    }

    // ── นอก /api/auth: บัญชีที่ต้องเปลี่ยนรหัสผ่านใช้ไม่ได้ ──
    if (me.mustChange) {
      return _error(403, 'PASSWORD_CHANGE_REQUIRED', mustChangeMessage);
    }

    // เส้นสมมุติของข้อมูลหักหนี้ (ระยะถัดไป): เขียนข้อมูลนอกช่วงเวลาแก้ไข = 403 EDIT_WINDOW_CLOSED
    if (path == '/api/test/write-debt') {
      if (!_canEditNow(me)) {
        return _error(403, 'EDIT_WINDOW_CLOSED', editWindowClosedMessage);
      }
      return _json(200, {'success': true});
    }

    // ── หน่วยงาน ──
    if (path == '/api/divs' && method == 'GET') {
      final scope = _scope(me);
      return _json(200, {
        'scope': scope,
        'own_div': me.div,
        'divs': [
          for (final d in divs)
            if (scope == 'ALL' ||
                d['div'] == me.div ||
                (scope == 'CENTER' && d['center'] == true))
              d,
        ],
        'success': true,
      });
    }

    final dept = RegExp(r'^/api/divs/([^/]+)/success-dept$').firstMatch(path);
    if (dept != null && method == 'GET') {
      final div = Uri.decodeComponent(dept.group(1)!);
      if (!_canAccessDiv(me, div)) {
        return _error(403, 'DIV_FORBIDDEN', divForbiddenMessage);
      }
      final all = [...?successDepts[div]]..sort((a, b) => b.compareTo(a));
      String? first(String prefix) {
        for (final c in successDepts[div] ?? const <String>[]) {
          if (c.startsWith(prefix)) return c;
        }
        return null;
      }

      return _json(200, {
        'div': div,
        'g': first('G'),
        'e': first('E'),
        'success_depts': all,
      });
    }

    // ── ค่าตั้งกลาง ──
    if (path == '/api/period') {
      if (method == 'GET') {
        return _json(200, {'month': periodMonth, 'year': periodYear});
      }
      if (method == 'PUT') {
        if (!has('ACCOUNT')) return _forbidden();
        var mo = '${body?['month'] ?? ''}'.trim();
        final yr = '${body?['year'] ?? ''}'.trim();
        if (RegExp(r'^[1-9]$').hasMatch(mo)) mo = '0$mo';
        if (!RegExp(r'^(0[1-9]|1[0-2])$').hasMatch(mo)) {
          return _bad('เดือนต้องเป็น 01 ถึง 12');
        }
        if (!RegExp(r'^25\d{2}$').hasMatch(yr)) {
          return _bad('ปีต้องเป็นปี พ.ศ. 4 หลัก');
        }
        // เปลี่ยนเป็นงวดใหม่: backend ตั้งเวลาของระยะเวลาแก้ไขกลับเป็นค่าตั้งต้นของงวด
        if (mo != periodMonth || yr != periodYear) {
          beginTime = '06:00';
          endTime = '16:30';
        }
        periodMonth = mo;
        periodYear = yr;
        return _json(200, {
          'month': periodMonth,
          'year': periodYear,
          'message': savedMessage,
          'success': true,
        });
      }
    }

    if (path == '/api/alert-message' && method == 'PUT') {
      if (!has('ACCOUNT')) return _forbidden();
      final text = '${body?['msg'] ?? ''}'.trim();
      if (text.length > 5000) return _bad('ข้อความแจ้งยาวเกิน 5000 ตัวอักษร');
      alertMessage = text;
      return _json(200, {
        'msg': alertMessage,
        'message': savedMessage,
        'success': true,
      });
    }

    if (path == '/api/edit-window') {
      if (method == 'GET') return _json(200, _windowView(me));
      if (method == 'PUT') {
        if (!has('ACCOUNT')) return _forbidden();
        final bd = '${body?['beginDate'] ?? ''}'.trim();
        final ed = '${body?['endDate'] ?? ''}'.trim();
        final bt = '${body?['beginTime'] ?? '06:00'}'.trim();
        final et = '${body?['endTime'] ?? '11:00'}'.trim();
        final date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        final time = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');
        if (!date.hasMatch(bd)) {
          return _bad('วันที่เริ่มต้องอยู่ในรูป yyyy-MM-dd (ค.ศ.)');
        }
        if (!date.hasMatch(ed)) {
          return _bad('วันที่สิ้นสุดต้องอยู่ในรูป yyyy-MM-dd (ค.ศ.)');
        }
        if (!time.hasMatch(bt)) return _bad('เวลาเริ่มต้องอยู่ในรูป HH:mm');
        if (!time.hasMatch(et)) return _bad('เวลาสิ้นสุดต้องอยู่ในรูป HH:mm');
        String two(String t) => t.length == 4 ? '0$t' : t;
        final begin = DateTime.parse('${bd}T${two(bt)}:00');
        final end = DateTime.parse('${ed}T${two(et)}:00');
        if (end.isBefore(begin)) return _bad(windowOrderMessage);
        beginDate = bd;
        endDate = ed;
        beginTime = two(bt);
        endTime = two(et);
        return _json(200, {
          ..._windowView(me),
          'message': savedMessage,
          'success': true,
        });
      }
    }

    // ── จัดการผู้ใช้ ──
    final adminOrReset = has('ADMIN') || has('RESETPWD');

    if (path == '/api/admin/roles' && method == 'GET') {
      if (!has('ADMIN')) return _forbidden();
      if (rolesStatus != null) {
        return _error(
          rolesStatus!,
          'INTERNAL_ERROR',
          'เกิดข้อผิดพลาด กรุณาลองใหม่ภายหลัง',
        );
      }
      return _json(200, roles);
    }

    if (path == '/api/admin/divs' && method == 'GET') {
      if (!has('ADMIN')) return _forbidden();
      return _json(200, divs);
    }

    if (path == '/api/admin/users' && method == 'GET') {
      if (!adminOrReset) return _forbidden();
      final q = options.queryParameters;
      final keyword = '${q['keyword'] ?? ''}'.trim().toLowerCase();
      final page = (q['page'] as int?) ?? 0;
      final size = (q['size'] as int?) ?? 10;
      final list =
          users.values
              .where(
                (u) =>
                    keyword.isEmpty ||
                    '${u.username} ${u.fullName} ${u.div}'
                        .toLowerCase()
                        .contains(keyword),
              )
              .toList()
            ..sort((a, b) => a.username.compareTo(b.username));
      return _json(200, {
        'users': list.skip(page * size).take(size).map(userDto).toList(),
        'currentPage': page,
        'totalItems': list.length,
        'totalPages': (list.length / size).ceil(),
        'pageSize': size,
        'success': true,
      });
    }

    if (path == '/api/admin/users' && method == 'POST') {
      if (!has('ADMIN')) return _forbidden();
      final name = '${body?['username'] ?? ''}'.trim();
      if (!RegExp(r'^\d{3,10}$').hasMatch(name)) {
        return _bad(usernameRuleMessage);
      }
      if (users.containsKey(name)) return _bad(usernameTakenMessage);
      final weak = passwordProblem(body?['password'] as String?);
      if (weak != null) return _bad(weak);
      final problem = _userFormProblem(body);
      if (problem != null) return _bad(problem);
      final email = '${body?['email'] ?? ''}'.trim();
      final created = FakeUser(
        username: name,
        password: body!['password'] as String,
        fullName: '${body['fullName']}'.trim(),
        email: email.isEmpty ? null : email,
        div: '${body['div']}'.trim(),
        roles: List<String>.from(body['roles'] as List),
        mustChange: true,
      );
      users[name] = created;
      return _json(200, userDto(created));
    }

    final reset = RegExp(
      r'^/api/admin/users/([^/]+)/reset-password$',
    ).firstMatch(path);
    if (reset != null && method == 'POST') {
      if (!adminOrReset) return _forbidden();
      final newPassword = body?['newPassword'];
      if (newPassword is! String || newPassword.isEmpty) {
        return _bad('กรุณากรอกรหัสผ่านใหม่');
      }
      final target = _byId(Uri.decodeComponent(reset.group(1)!));
      if (target == null) return _error(404, 'NOT_FOUND', userNotFoundMessage);
      if (target.username == me.username) return _bad(resetSelfMessage);
      if (!has('ADMIN') &&
          target.roles.any(
            (r) => const ['ADMIN', 'ACCOUNT', 'RESETPWD'].contains(r),
          )) {
        return _forbidden(resetPrivilegedMessage);
      }
      final weak = passwordProblem(newPassword);
      if (weak != null) return _bad(weak);
      target.password = newPassword;
      target.mustChange = true;
      target.locked = false;
      _revokeAll(target.username);
      return _json(200, {'message': resetDoneMessage, 'success': true});
    }

    final one = RegExp(r'^/api/admin/users/([^/]+)$').firstMatch(path);
    if (one != null) {
      final target = _byId(Uri.decodeComponent(one.group(1)!));
      if (method == 'GET') {
        if (!adminOrReset) return _forbidden();
        if (target == null) {
          return _error(404, 'NOT_FOUND', userNotFoundMessage);
        }
        return _json(200, userDto(target));
      }
      if (method == 'PUT') {
        if (!has('ADMIN')) return _forbidden();
        if (target == null) {
          return _error(404, 'NOT_FOUND', userNotFoundMessage);
        }
        final self = target.username == me.username;
        final problem = _userFormProblem(body);
        if (problem != null) return _bad(problem);
        final roles = List<String>.from(body!['roles'] as List);
        final active = body['active'] == true;
        if (self && !active) return _bad(deactivateSelfMessage);
        if (self && !roles.contains('ADMIN')) {
          return _bad('ถอดบทบาท ADMIN ออกจากบัญชีของตัวเองไม่ได้');
        }
        final deactivated = target.active && !active;
        final email = '${body['email'] ?? ''}'.trim();
        target
          ..fullName = '${body['fullName']}'.trim()
          ..email = email.isEmpty ? null : email
          ..div = '${body['div']}'.trim()
          ..roles = roles
          ..active = active;
        if (body['locked'] != true) target.locked = false;
        if (deactivated) _revokeAll(target.username);
        return _json(200, userDto(target));
      }
    }

    final phase3Response = phase3(options, body, me);
    if (phase3Response != null) return phase3Response;

    final phase2Response = phase2(options, body, me);
    if (phase2Response != null) return phase2Response;

    return _error(404, 'NOT_FOUND', 'ไม่พบหน้าที่ร้องขอ');
  }

  FakeUser? _byId(String id) {
    for (final u in users.values) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  void close({bool force = false}) {}
}

/// ต่อ backend จำลองเข้ากับ ApiService (ตัวเดียวทั้งแอป) และล้าง session / ค่าตั้งกลางที่ค้างจากเทสต์ก่อนหน้า
Future<FakeBackend> installFakeBackend() async {
  FlutterSecureStorage.setMockInitialValues({});
  final api = ApiService();
  // ล้างสถานะในหน่วยความจำก่อน (ที่เก็บว่างแล้ว จึงไม่มีการเรียก /logout)
  await api.logout();
  SettingsProvider().reset();
  final backend = FakeBackend();
  api.dio.httpClientAdapter = backend;
  api.publicDio.httpClientAdapter = backend;
  return backend;
}
