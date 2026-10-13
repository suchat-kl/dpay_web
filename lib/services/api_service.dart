import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/models/div_dept.dart';
import 'package:dpay/models/edit_window.dart';
import 'package:dpay/models/period.dart';
import 'package:dpay/models/user_admin.dart';
import 'package:dpay/services/auth_interceptor.dart';
import 'package:dpay/utils/logger.dart';
import 'package:dpay/utils/permission.dart';

/// ตัวเรียก API ของทั้งแอป (singleton) — เก็บ token และข้อมูล session ไว้ด้วย
///
/// สัญญา API ยึดตาม backend ระบบหักหนี้ (`C:\AI\springboot\dpay` ดูตารางใน README.md ของโปรเจกต์นี้)
/// เพิ่ม endpoint ใหม่: เขียนเมธอดในคลาสนี้ เรียกผ่าน [_authedRequest] แล้วโยน [_apiError] เมื่อไม่ใช่ 200
/// เส้นที่ไม่ต้องเข้าสู่ระบบใช้ [publicDio]
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  /// Dio หลัก มี interceptor แนบ token / ต่ออายุ token
  late final Dio dio;

  /// Dio ของเส้นที่ไม่ต้องยืนยันตัวตน ไม่มี interceptor ของ token
  late final Dio publicDio;
  late final FlutterSecureStorage storage;

  /// URL ของ API — เลือกตอน run/build ด้วย `--dart-define=API_BASE=...`
  ///
  ///   flutter run -d chrome --dart-define=API_BASE=https://suchat-dev.doh.go.th/dpayapi
  ///   flutter build web --no-wasm-dry-run --dart-define=API_BASE=(URL ของ API บนเครื่องจริง)
  ///
  /// ค่าตั้งต้นเป็นเครื่องนักพัฒนา (พอร์ตตั้งต้นของ backend) เท่านั้น **build ขึ้นเครื่องจริงต้องส่งค่านี้เองทุกครั้ง**
  /// ไม่ต้องใส่ / ปิดท้าย เพราะ path ที่ต่อท้ายขึ้นต้นด้วย / อยู่แล้ว
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:9005',
  );

  // ── คีย์ในคลังเก็บ token (flutter_secure_storage) ──
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  /// ข้อมูลผู้ใช้ของ session (JSON: username, full_name, div, div_name, roles, div_scope)
  static const String userDataKey = 'user_data';

  /// ต้องเปลี่ยนรหัสผ่านก่อนใช้งาน เก็บไว้ให้รอดการโหลดหน้าใหม่
  static const String mustChangePasswordKey = 'must_change_password';

  String? _username;
  String? _fullName;
  String? _div;
  String? _divName;
  List<String> _roles = [];
  DivScope _divScope = DivScope.own;
  bool _mustChangePassword = false;
  bool _isLoggedIn = false;

  /// แจ้งเมื่อสถานะเข้าสู่ระบบ / ข้อมูลผู้ใช้ / การบังคับเปลี่ยนรหัสผ่านเปลี่ยน (`AuthProvider` ฟังอยู่)
  Function(bool isLoggedIn)? onLoginStateChanged;

  ApiService._internal() {
    // ตั้งชื่อคลังเก็บเฉพาะของระบบนี้ ค่าเริ่มต้นของ package ใช้ชื่อเดียวกันทุกแอปใน origin เดียวกัน
    // ถ้าไม่แยก token จะปนกับระบบอื่นที่อยู่บนเครื่องเดียวกัน
    // และ deleteAll() ตอนออกจากระบบจะลบ token ของอีกระบบไปด้วย
    storage = const FlutterSecureStorage(
      webOptions: WebOptions(
        dbName: AppConfig.secureStorageName,
        publicKey: AppConfig.secureStorageName,
      ),
    );

    publicDio = Dio(_baseOptions());
    dio = Dio(_baseOptions());

    // log เฉพาะคำขอที่ผิดพลาด เฉพาะ debug build และผ่าน AppLogger.redact() เสมอ
    // ไม่ใช้ LogInterceptor ของ Dio: มันพิมพ์ด้วย print และเปิด header/body ได้
    // (header มี 'Authorization: Bearer <token>' ทุกคำขอ body ของเส้น auth มีรหัสผ่านกับ token)
    if (kDebugMode) {
      publicDio.interceptors.add(_errorLog());
      dio.interceptors.add(_errorLog());
    }

    dio.interceptors.add(AuthInterceptor(this));
  }

  static BaseOptions _baseOptions() => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    // Access-Control-Allow-Origin เป็น header ของ *คำตอบ* ที่ backend ต้องส่งมา
    // ใส่ฝั่งนี้ไม่มีผลกับ CORS แถมทำให้เบราว์เซอร์ยิง preflight เกินจำเป็น
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    receiveDataWhenStatusError: true,
    followRedirects: true,
    maxRedirects: 3,
  );

  static Interceptor _errorLog() => InterceptorsWrapper(
    onError: (e, handler) {
      if (AppLogger.on) {
        AppLogger.lazy(
          () =>
              '🔴 ${e.response?.statusCode ?? e.type.name} '
              '${e.requestOptions.method} ${e.requestOptions.path}\n'
              '${AppLogger.redact(e.response?.data)}',
          tag: 'API',
        );
      }
      handler.next(e);
    },
  );

  String? get username => _username;

  /// ชื่อที่แสดงของบัญชี (ชื่อหน่วยงานเจ้าของบัญชี)
  String? get fullName => _fullName;

  /// รหัสหน่วยงานของผู้ใช้
  String? get div => _div;

  /// ชื่อหน่วยงานของ [div]
  String? get divName => _divName;

  /// ชื่อบทบาทแบบสั้น (USER, ACCOUNT, ...)
  List<String> get roles => _roles;

  /// ขอบเขตหน่วยงานที่ผู้ใช้เลือกได้
  DivScope get divScope => _divScope;
  bool get isLoggedIn => _isLoggedIn;

  bool hasRole(String role) => _roles.contains(role);

  /// ต้องเปลี่ยนรหัสผ่านก่อนใช้งานส่วนอื่น (backend ตอบ `must_change_password` หรือ 403 PASSWORD_CHANGE_REQUIRED)
  /// หน้าเว็บจะเปิดหน้าเปลี่ยนรหัสผ่านแบบปิดไม่ได้จนกว่าจะเปลี่ยน
  bool get mustChangePassword => _isLoggedIn && _mustChangePassword;

  /// ผู้ที่เข้าสู่ระบบอยู่เปิดหน้าจอ [screenCode] (ดู `Perm`) ได้ไหม — ตัดสินจากบทบาท
  ///
  /// ยังไม่เข้าสู่ระบบ หรือยังต้องเปลี่ยนรหัสผ่าน (backend ปิดทุกส่วนนอก /api/auth) = ไม่ได้ทุกหน้าจอ
  bool canView(String screenCode) =>
      _isLoggedIn && !_mustChangePassword && Perm.allows(screenCode, _roles);

  // ============ เข้าสู่ระบบ / ออกจากระบบ ============

  /// เข้าสู่ระบบด้วยชื่อผู้ใช้/รหัสผ่าน คืนตัวข้อมูลที่ backend ตอบ
  /// ไม่สำเร็จโยน [ApiException] (ข้อความภาษาไทยของ backend + `code` เช่น BAD_CREDENTIALS, ACCOUNT_LOCKED)
  ///
  /// ห้าม log รหัสผ่าน (แม้แต่ความยาว) และห้าม log ตัวข้อมูลโดยไม่ผ่าน `AppLogger.redact`
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      if (AppLogger.on) AppLogger.d('🔵 Login: $baseUrl/api/auth/login');

      final response = await publicDio.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );

      if (AppLogger.on) {
        AppLogger.lazy(
          () =>
              '🟢 Login ${response.statusCode}: '
              '${AppLogger.redact(response.data)}',
          tag: 'AUTH',
        );
      }

      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        await _applyLogin(data);
        return data;
      }
      throw ApiException(
        'เข้าสู่ระบบไม่สำเร็จ (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (AppLogger.on) {
        AppLogger.e('🔴 Login: ${e.type} ${e.response?.statusCode}');
      }
      throw _fromDio(
        e,
        unauthorizedMessage: 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง',
      );
    }
  }

  /// เก็บ token และข้อมูลผู้ใช้หลังเข้าสู่ระบบสำเร็จ
  /// ช่องที่ backend ไม่ส่งมาใช้ค่าตั้งต้น ยกเว้น `access_token` ที่ต้องมี
  Future<void> _applyLogin(Map<String, dynamic> data) async {
    final accessToken = data['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const ApiException('ไม่พบ access_token ในการตอบกลับ');
    }

    await storage.write(key: accessTokenKey, value: accessToken);
    await storage.write(
      key: refreshTokenKey,
      value: data['refresh_token']?.toString(),
    );
    _isLoggedIn = true;
    await _applyProfile(data);

    onLoginStateChanged?.call(true);

    if (AppLogger.on) AppLogger.i('🟢 เข้าสู่ระบบ: $_username $_roles');
  }

  /// ตั้งข้อมูลผู้ใช้จากผล login หรือ /api/auth/me (ชื่อช่องเดียวกัน) แล้วเก็บลงคลังให้รอดการโหลดหน้าใหม่
  Future<void> _applyProfile(Map<String, dynamic> data) async {
    _username = data['username']?.toString();
    _fullName = data['full_name']?.toString();
    _div = data['div']?.toString();
    _divName = data['div_name']?.toString();
    _roles = [
      for (final r in data['roles'] as List? ?? const [])
        if (r != null) '$r',
    ];
    _divScope = DivScope.parse(data['div_scope']);

    await storage.write(
      key: userDataKey,
      value: jsonEncode({
        'username': _username,
        'full_name': _fullName,
        'div': _div,
        'div_name': _divName,
        'roles': _roles,
        'div_scope': _divScope.code,
      }),
    );
    await _setMustChangePassword(data['must_change_password'] == true);
  }

  Future<void> _setMustChangePassword(bool value) async {
    _mustChangePassword = value;
    if (value) {
      await storage.write(key: mustChangePasswordKey, value: 'true');
    } else {
      await storage.delete(key: mustChangePasswordKey);
    }
  }

  /// backend ตอบ 403 PASSWORD_CHANGE_REQUIRED ระหว่างใช้งาน (เช่น session ที่กู้มายังไม่รู้ว่าต้องเปลี่ยน)
  /// ตั้งสถานะบังคับเปลี่ยนแล้วแจ้งผู้ฟัง แอปจะเปิดหน้าเปลี่ยนรหัสผ่านที่ปิดไม่ได้ (ดู main.dart)
  Future<void> _flagPasswordChangeRequired() async {
    if (!_isLoggedIn || _mustChangePassword) return;
    await _setMustChangePassword(true);
    onLoginStateChanged?.call(true);
  }

  /// ข้อมูลล่าสุดของผู้ที่เข้าสู่ระบบจาก `GET /api/auth/me` (บทบาท/หน่วยงานอาจถูกผู้ดูแลแก้ระหว่างที่ session ค้างอยู่)
  ///
  /// คืนค่า `can_edit_now` ของคำตอบ เรียกไม่สำเร็จ = null และคงข้อมูลเดิมไว้ (เน็ตสะดุดไม่ทำให้เมนูหาย)
  Future<bool?> loadProfile() async {
    try {
      final r = await _authedRequest('GET', '/api/auth/me');
      if (r.statusCode != 200 || r.data is! Map) return null;
      final data = Map<String, dynamic>.from(r.data as Map);
      await _applyProfile(data);
      onLoginStateChanged?.call(_isLoggedIn);
      return data['can_edit_now'] == true;
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ โหลดข้อมูลผู้ใช้ไม่สำเร็จ: $e');
      return null;
    }
  }

  /// ข้อความภาษาไทยของข้อผิดพลาดจาก Dio ใช้ `message` ของ backend ก่อนถ้ามี
  static String _getErrorMessage(
    DioException e, {
    String? unauthorizedMessage,
  }) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'หมดเวลาในการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง';
      case DioExceptionType.sendTimeout:
        return 'หมดเวลาในการส่งข้อมูล กรุณาลองใหม่อีกครั้ง';
      case DioExceptionType.receiveTimeout:
        return 'หมดเวลาในการรับข้อมูล กรุณาลองใหม่อีกครั้ง';
      case DioExceptionType.connectionError:
        return 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้\nกรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต';
      case DioExceptionType.badResponse:
        final message = _messageFrom(e.response?.data);
        if (message != null) return message;
        final statusCode = e.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
          case 401:
            return unauthorizedMessage ?? 'กรุณาเข้าสู่ระบบใหม่';
          case 403:
            return 'ไม่มีสิทธิ์ใช้งานส่วนนี้';
          case 404:
            return 'ไม่พบบริการที่เรียก (404) กรุณาตรวจสอบค่า API_BASE';
          case 500:
            return 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์ กรุณาลองใหม่อีกครั้ง';
          case 502:
            return 'เซิร์ฟเวอร์ไม่พร้อมให้บริการ (Bad Gateway)';
          case 503:
            return 'เซิร์ฟเวอร์กำลังอยู่ในระหว่างการบำรุงรักษา';
          default:
            return 'เกิดข้อผิดพลาด (${statusCode ?? 'ไม่ทราบรหัส'})';
        }
      case DioExceptionType.cancel:
        return 'คำขอถูกยกเลิก';
      case DioExceptionType.badCertificate:
        return 'ใบรับรองความปลอดภัยของเซิร์ฟเวอร์ไม่ถูกต้อง';
      default:
        return 'เกิดข้อผิดพลาดในการเชื่อมต่อ\n${e.message ?? ''}';
    }
  }

  static ApiException _fromDio(DioException e, {String? unauthorizedMessage}) =>
      ApiException(
        _getErrorMessage(e, unauthorizedMessage: unauthorizedMessage),
        statusCode: e.response?.statusCode,
        code: _codeFrom(e.response?.data),
        details: _detailsFrom(e.response?.data),
      );

  bool _isRefreshing = false;

  /// ขอ token ชุดใหม่ด้วย refresh token
  ///
  /// refresh token ของ backend ใช้ได้**ครั้งเดียว** ทุกครั้งได้ตัวใหม่มาแทน จึงห้ามยิงซ้อน:
  /// คำขอที่มาระหว่างกำลังต่ออายุจะรอผลของรอบที่ทำอยู่ ไม่ยิงซ้ำ
  /// ไม่สำเร็จ = ออกจากระบบแล้วโยน Exception (แอปพากลับหน้าแรกเอง ดู main.dart)
  Future<void> refreshToken() async {
    if (_isRefreshing) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return _isRefreshing;
      });
      return;
    }

    _isRefreshing = true;

    try {
      final oldRefreshToken = await storage.read(key: refreshTokenKey);
      if (oldRefreshToken == null) {
        throw Exception('ไม่มี refresh token');
      }

      final response = await publicDio.post(
        '/api/auth/refresh-token',
        data: {'refresh_token': oldRefreshToken},
      );

      final data = response.data;
      if (response.statusCode != 200 ||
          data is! Map ||
          data['access_token'] is! String) {
        throw Exception('ต่ออายุ token ไม่สำเร็จ (${response.statusCode})');
      }
      await storage.write(key: accessTokenKey, value: data['access_token']);
      // backend หมุน refresh token ให้ใหม่ทุกครั้ง ตัวเดิมใช้ไม่ได้อีก ต้องเก็บตัวใหม่ทันที
      final newRefreshToken = data['refresh_token'];
      if (newRefreshToken is String && newRefreshToken.isNotEmpty) {
        await storage.write(key: refreshTokenKey, value: newRefreshToken);
      }
      if (AppLogger.on) AppLogger.i('🟢 ต่ออายุ token สำเร็จ');
    } catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 ต่ออายุ token ไม่สำเร็จ: $e');
      await logout();
      throw const ApiException('หมดเวลาการใช้งาน กรุณาเข้าสู่ระบบใหม่');
    } finally {
      _isRefreshing = false;
    }
  }

  /// ออกจากระบบ: แจ้ง backend ให้ยกเลิก token ชุดนี้ (ไม่สำเร็จก็ออกต่อ) แล้วล้างข้อมูลในเครื่อง
  ///
  /// แนบ access token ใน header และส่ง `{refresh_token}` ให้ backend ยกเลิกทั้งคู่
  /// ยิงผ่าน [publicDio] แล้วแนบ header เอง เพื่อไม่ให้ interceptor ไปต่ออายุ token ที่กำลังจะทิ้ง
  Future<void> logout() async {
    try {
      final accessToken = await storage.read(key: accessTokenKey);
      if (accessToken != null) {
        final refreshToken = await storage.read(key: refreshTokenKey);
        await publicDio.post(
          '/api/auth/logout',
          data: {'refresh_token': ?refreshToken},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ แจ้งออกจากระบบไม่สำเร็จ: $e');
    }

    _username = null;
    _fullName = null;
    _div = null;
    _divName = null;
    _roles = [];
    _divScope = DivScope.own;
    _mustChangePassword = false;
    _isLoggedIn = false;

    try {
      await storage.deleteAll();
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ ล้างที่เก็บ token ไม่สำเร็จ: $e');
    }
    onLoginStateChanged?.call(false);
    if (AppLogger.on) AppLogger.i('✅ ออกจากระบบแล้ว');
  }

  /// กู้ session จากที่เก็บของเบราว์เซอร์ตอนเปิดหน้าเว็บ คืนจริงถ้ามี session ค้างอยู่
  Future<bool> loadSession() async {
    try {
      final accessToken = await storage.read(key: accessTokenKey);
      final userData = await storage.read(key: userDataKey);
      if (accessToken == null || userData == null) return false;

      final user = jsonDecode(userData);
      if (user is! Map || user['username'] is! String) return false;

      _username = user['username'] as String;
      _fullName = user['full_name']?.toString();
      _div = user['div']?.toString();
      _divName = user['div_name']?.toString();
      _roles = [
        for (final r in user['roles'] as List? ?? const [])
          if (r != null) '$r',
      ];
      _divScope = DivScope.parse(user['div_scope']);
      _mustChangePassword =
          await storage.read(key: mustChangePasswordKey) == 'true';
      _isLoggedIn = true;
      onLoginStateChanged?.call(true);
      if (AppLogger.on) AppLogger.i('🟢 กู้ session: $_username');
      return true;
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ กู้ session ไม่สำเร็จ: $e');
    }
    return false;
  }

  Future<String?> getAccessToken() async {
    return await storage.read(key: accessTokenKey);
  }

  /// access token หมดอายุแล้ว หรือเหลือไม่ถึง 60 วินาที (อ่าน `exp` จาก JWT)
  /// ไม่มี token / อ่านไม่ออก = ถือว่าหมดอายุ
  Future<bool> isTokenExpired() async {
    try {
      final token = await getAccessToken();
      if (token == null) return true;

      final parts = token.split('.');
      if (parts.length != 3) return true;

      final decoded = utf8.decode(base64.decode(base64.normalize(parts[1])));
      final Map<String, dynamic> map = json.decode(decoded);

      final exp = (map['exp'] as num?)?.toInt();
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now()
          .add(const Duration(seconds: 60))
          .isAfter(expiryDate);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('อ่านวันหมดอายุของ token ไม่ได้: $e');
      return true;
    }
  }

  /// ต่ออายุ token ก่อนยิงคำขอถ้าใกล้หมดอายุ
  Future<void> _ensureToken() async {
    if (await isTokenExpired()) {
      try {
        await refreshToken();
      } catch (e) {
        throw const ApiException(
          'กรุณาเข้าสู่ระบบใหม่',
          statusCode: 401,
          code: ErrorCodes.unauthenticated,
        );
      }
    }
  }

  // ============ รหัสผ่าน ============

  /// ผู้ใช้เปลี่ยนรหัสผ่านของตัวเองด้วยรหัสผ่านเดิม (backend รู้ว่าเป็นบัญชีไหนจาก token)
  /// สำเร็จแล้วเลิกบังคับเปลี่ยนรหัสผ่าน — ไม่ log ตัวข้อมูลที่ส่ง (มีรหัสผ่าน)
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final r = await _authedRequest(
      'POST',
      '/api/auth/changepassword',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    if (r.statusCode != 200 || (r.data is Map && r.data['success'] == false)) {
      throw _apiError(r, 'เปลี่ยนรหัสผ่านไม่สำเร็จ');
    }
    await _setMustChangePassword(false);
    onLoginStateChanged?.call(_isLoggedIn);
  }

  // ============ ค่าตั้งกลาง: ข้อความแจ้ง งวดปัจจุบัน ระยะเวลาแก้ไข ============

  static const String alertMessagePath = '/api/alert-message';
  static const String periodPath = '/api/period';
  static const String editWindowPath = '/api/edit-window';

  /// ความยาวสูงสุดของข้อความแจ้งที่ backend รับ
  static const int alertMessageMaxLength = 5000;

  /// ข้อความแจ้งผู้ใช้งาน — เส้นสาธารณะ อ่านได้โดยไม่ต้องเข้าสู่ระบบ
  /// เป็นข้อความล้วนหลายบรรทัด **ห้ามแสดงเป็น HTML** ไม่มีข้อความ = ข้อความว่าง
  Future<String> getAlertMessage() async {
    try {
      final r = await publicDio.get(alertMessagePath);
      if (r.statusCode == 200 && r.data is Map) {
        return '${r.data['msg'] ?? ''}';
      }
      throw _apiError(r, 'โหลดข้อความแจ้งไม่สำเร็จ');
    } on DioException catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 GET $alertMessagePath: ${e.type}');
      throw _fromDio(e);
    }
  }

  /// แก้ข้อความแจ้งผู้ใช้งาน (เฉพาะ ACCOUNT) คืนข้อความที่ backend เก็บจริง (ตัดช่องว่างหัวท้ายแล้ว)
  Future<String> updateAlertMessage(String message) async {
    final r = await _authedRequest(
      'PUT',
      alertMessagePath,
      data: {'msg': message},
    );
    if (r.statusCode == 200 && r.data is Map) return '${r.data['msg'] ?? ''}';
    throw _apiError(r, 'บันทึกข้อความแจ้งไม่สำเร็จ');
  }

  /// งวดปัจจุบัน (เดือน ปี พ.ศ.)
  Future<Period> getPeriod() async {
    final r = await _authedRequest('GET', periodPath);
    if (r.statusCode == 200 && r.data is Map) {
      return Period.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'โหลดงวดปัจจุบันไม่สำเร็จ');
  }

  /// ตั้งงวดปัจจุบัน (เฉพาะ ACCOUNT)
  Future<Period> updatePeriod(Period period) async {
    final r = await _authedRequest('PUT', periodPath, data: period.toJson());
    if (r.statusCode == 200 && r.data is Map) {
      return Period.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'บันทึกงวดปัจจุบันไม่สำเร็จ');
  }

  /// ระยะเวลาแก้ไขข้อมูล พร้อมสถานะเปิด/ปิด และ `can_edit_now` ของบัญชีนี้
  Future<EditWindow> getEditWindow() async {
    final r = await _authedRequest('GET', editWindowPath);
    if (r.statusCode == 200 && r.data is Map) {
      return EditWindow.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'โหลดระยะเวลาแก้ไขข้อมูลไม่สำเร็จ');
  }

  /// ตั้งระยะเวลาแก้ไขข้อมูล (เฉพาะ ACCOUNT) เวลาเป็นรูป HH:mm
  Future<EditWindow> updateEditWindow({
    required DateTime beginDate,
    required DateTime endDate,
    required String beginTime,
    required String endTime,
  }) async {
    final r = await _authedRequest(
      'PUT',
      editWindowPath,
      data: EditWindow.requestJson(
        beginDate: beginDate,
        endDate: endDate,
        beginTime: beginTime,
        endTime: endTime,
      ),
    );
    if (r.statusCode == 200 && r.data is Map) {
      return EditWindow.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'บันทึกระยะเวลาแก้ไขข้อมูลไม่สำเร็จ');
  }

  // ============ หน่วยงาน ============

  /// หน่วยงานที่ผู้ใช้คนนี้เลือกได้ (ตัวเอง / ส่วนกลาง / ทั้งหมด ตามบทบาท — backend ตัดสิน)
  Future<DivChoices> getDivs() async {
    final r = await _authedRequest('GET', '/api/divs');
    if (r.statusCode == 200 && r.data is Map) {
      return DivChoices.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'โหลดรายชื่อหน่วยงานไม่สำเร็จ');
  }

  /// รหัสสังกัด G/E ของหน่วยงาน ไม่มีสิทธิ์กับหน่วยงานนั้น = 403 DIV_FORBIDDEN
  Future<SuccessDept> getSuccessDept(String div) async {
    final r = await _authedRequest(
      'GET',
      '/api/divs/${Uri.encodeComponent(div)}/success-dept',
    );
    if (r.statusCode == 200 && r.data is Map) {
      return SuccessDept.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'โหลดรหัสสังกัดของหน่วยงานไม่สำเร็จ');
  }

  // ============ จัดการผู้ใช้ (ADMIN / RESETPWD) ============

  static const String adminUsersPath = '/api/admin/users';

  /// path ของผู้ใช้หนึ่งบัญชี
  static String adminUserPath(String id) =>
      '$adminUsersPath/${Uri.encodeComponent(id)}';

  /// รายการบทบาททั้งหมด คืน {code: ชื่อสั้นของบทบาท, name: คำอธิบาย} (เฉพาะ ADMIN)
  ///
  /// backend ส่ง `[{name, description}]` เรียกไม่สำเร็จใช้ชุดตั้งต้นของระบบ หน้าจอจึงยังเลือกบทบาทได้
  Future<List<Map<String, String>>> getRoles() async {
    try {
      final r = await _authedRequest('GET', '/api/admin/roles');
      final list = r.data;
      if (r.statusCode == 200 && list is List) {
        final roles = <Map<String, String>>[];
        for (final role in list.whereType<Map>()) {
          final code = role['name']?.toString() ?? '';
          if (code.isEmpty) continue;
          final description = role['description']?.toString() ?? '';
          roles.add({
            'code': code,
            'name': description.isNotEmpty ? description : Roles.nameOf(code),
          });
        }
        return roles;
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 โหลดรายการบทบาทไม่สำเร็จ: $e');
    }
    return [
      for (final code in Roles.order)
        {'code': code, 'name': Roles.nameOf(code)},
    ];
  }

  /// รายชื่อหน่วยงานทั้งหมด ใช้ทำตัวเลือกในฟอร์มผู้ใช้ (เฉพาะ ADMIN)
  Future<List<DivDept>> getAdminDivs() async {
    final r = await _authedRequest('GET', '/api/admin/divs');
    final list = r.data;
    if (r.statusCode == 200 && list is List) {
      return [
        for (final d in list.whereType<Map>())
          DivDept.fromJson(Map<String, dynamic>.from(d)),
      ];
    }
    throw _apiError(r, 'โหลดรายชื่อหน่วยงานไม่สำเร็จ');
  }

  /// รายการผู้ใช้แบบแบ่งหน้า ค้นด้วย [keyword] (ADMIN, RESETPWD)
  /// คืน `{users:[...], currentPage, totalItems, totalPages, pageSize}`
  Future<Map<String, dynamic>> searchAdminUsers({
    String? keyword,
    int page = 0,
    int size = 10,
  }) async {
    final r = await _authedRequest(
      'GET',
      adminUsersPath,
      query: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'page': page,
        'size': size,
      },
    );
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data as Map);
    }
    throw _apiError(r, 'โหลดรายชื่อผู้ใช้ไม่สำเร็จ');
  }

  /// ผู้ใช้หนึ่งบัญชี ใช้ตอนเปิดแก้ไข
  Future<UserAdmin> getAdminUser(String id) async {
    final r = await _authedRequest('GET', adminUserPath(id));
    if (r.statusCode == 200 && r.data is Map) {
      return UserAdmin.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'โหลดข้อมูลผู้ใช้ไม่สำเร็จ');
  }

  /// สร้างบัญชีใหม่ด้วยรหัสผ่านตั้งต้น [password] (เฉพาะ ADMIN) ผู้ใช้ต้องเปลี่ยนรหัสผ่านตอนเข้าครั้งแรก
  Future<UserAdmin> createAdminUser(UserAdmin u, String password) async {
    final r = await _authedRequest(
      'POST',
      adminUsersPath,
      data: u.toCreateJson(password),
    );
    if (r.statusCode == 200 && r.data is Map) {
      return UserAdmin.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'สร้างผู้ใช้ไม่สำเร็จ');
  }

  /// บันทึกผู้ใช้ (ชื่อ อีเมล หน่วยงาน บทบาท สถานะใช้งาน/ล็อก) (เฉพาะ ADMIN)
  Future<UserAdmin> updateAdminUser(UserAdmin u) async {
    final r = await _authedRequest(
      'PUT',
      adminUserPath(u.id),
      data: u.toUpdateJson(),
    );
    if (r.statusCode == 200 && r.data is Map) {
      return UserAdmin.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw _apiError(r, 'บันทึกข้อมูลผู้ใช้ไม่สำเร็จ');
  }

  /// กำหนดรหัสผ่านใหม่ให้บัญชี [id] (ADMIN, RESETPWD) คืนข้อความของ backend
  /// บัญชีนั้นถูกออกจากระบบทันที และต้องเปลี่ยนรหัสผ่านเองตอนเข้าสู่ระบบครั้งถัดไป
  Future<String> resetUserPassword(String id, String newPassword) async {
    final r = await _authedRequest(
      'POST',
      '${adminUserPath(id)}/reset-password',
      data: {'newPassword': newPassword},
    );
    if (r.statusCode == 200) {
      return _messageFrom(r.data) ?? 'กำหนดรหัสผ่านใหม่สำเร็จ';
    }
    throw _apiError(r, 'กำหนดรหัสผ่านใหม่ไม่สำเร็จ');
  }

  // ============ ตัวช่วยของคำขอที่ต้องเข้าสู่ระบบ ============

  /// คำขอที่ต้องเข้าสู่ระบบ — ใช้กับ endpoint ใหม่ของระบบได้เลย
  ///
  /// รับ 4xx กลับมาให้ผู้เรียกแปลเป็นข้อความเอง ([_apiError]) ยกเว้น **401** (token ใช้ไม่ได้)
  /// ที่ปล่อยให้ interceptor ต่ออายุ token แล้วยิงซ้ำหนึ่งครั้ง ยิงซ้ำแล้วยังได้ 401 โยน [ApiException]
  /// 403 ของ backend นี้มี `code` บอกเหตุเสมอ (FORBIDDEN, DIV_FORBIDDEN, EDIT_WINDOW_CLOSED,
  /// PASSWORD_CHANGE_REQUIRED) ไม่เกี่ยวกับ token จึงไม่ต่ออายุ
  Future<Response<dynamic>> _authedRequest(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Duration? receiveTimeout,
    bool bytes = false,
  }) async {
    await _ensureToken();
    try {
      final r = await dio.request(
        path,
        queryParameters: query,
        data: data,
        options: Options(
          method: method,
          receiveTimeout: receiveTimeout,
          // ไฟล์ต้องรับเป็นไบต์ตรง ๆ ห้ามแปลงเป็นข้อความ (ไฟล์ TIS-620 / PDF / xlsx / zip)
          responseType: bytes ? ResponseType.bytes : null,
          // 502 DPIS_ERROR มีข้อความของ backend ให้ผู้เรียกแสดง จึงรับกลับมาเหมือน 4xx
          validateStatus: (s) => s != null && s != 401 && (s < 500 || s == 502),
        ),
      );
      // ขอเป็นไบต์แต่ backend ตอบข้อผิดพลาด (JSON): แปลงกลับเป็น Map ให้ผู้เรียกอ่าน code/message ได้ตามปกติ
      if (bytes && r.statusCode != 200 && r.data is List<int>) {
        try {
          r.data = jsonDecode(utf8.decode(r.data as List<int>));
        } catch (_) {
          r.data = null;
        }
      }
      if (r.statusCode == 403 &&
          _codeFrom(r.data) == ErrorCodes.passwordChangeRequired) {
        await _flagPasswordChangeRequired();
      }
      return r;
    } on DioException catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 $method $path: ${e.type}');
      throw _fromDio(e);
    }
  }

  /// ข้อผิดพลาดจากคำตอบที่ไม่ใช่ 200: ใช้ `message` ของ backend ก่อน ไม่มีจึงใช้ [fallback]
  static ApiException _apiError(Response<dynamic> r, String fallback) =>
      ApiException(
        _messageFrom(r.data) ?? '$fallback (${r.statusCode})',
        statusCode: r.statusCode,
        code: _codeFrom(r.data),
        details: _detailsFrom(r.data),
      );

  /// ช่อง details ของข้อผิดพลาด ไม่มี = null
  static Map<String, dynamic>? _detailsFrom(dynamic body) {
    final d = body is Map ? body['details'] : null;
    return d is Map ? Map<String, dynamic>.from(d) : null;
  }

  /// คำขอที่ต้องเข้าสู่ระบบ สำหรับเมธอดของ API ที่แยกไฟล์ออกไป (`extension ... on ApiService` เช่น services/debt_api.dart)
  /// พฤติกรรมเดียวกับเมธอดในคลาสนี้: ต่ออายุ token เมื่อ 401 รับ 4xx กลับมาให้ผู้เรียกโยน [errorOf]
  /// [receiveTimeout] ใช้กับงานที่ backend ทำนาน (นำเข้า DPIS เตรียมงวด)
  /// [data] เป็น Map (JSON) หรือ `FormData` (อัปโหลดไฟล์) · [bytes] = รับคำตอบเป็นไบต์ (ดาวน์โหลดไฟล์)
  Future<Response<dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Duration? receiveTimeout,
    bool bytes = false,
  }) => _authedRequest(
    method,
    path,
    query: query,
    data: data,
    receiveTimeout: receiveTimeout,
    bytes: bytes,
  );

  /// ข้อผิดพลาดจากคำตอบที่ไม่สำเร็จ (ข้อความ + code + details ของ backend)
  static ApiException errorOf(Response<dynamic> r, String fallback) =>
      _apiError(r, fallback);

  /// ข้อความที่ backend ส่งมา (ช่อง message) ไม่มี = null
  static String? _messageFrom(dynamic body) {
    if (body is Map && body['message'] != null) return '${body['message']}';
    return null;
  }

  /// รหัสข้อผิดพลาดที่ backend ส่งมา (ช่อง code) ไม่มี = null
  static String? _codeFrom(dynamic body) {
    final code = body is Map ? body['code'] : null;
    return code is String && code.isNotEmpty ? code : null;
  }
}

/// ข้อผิดพลาดจาก backend ที่มีข้อความให้ผู้ใช้อ่าน ([toString] คืนข้อความล้วน)
///
/// หน้าจอแสดงด้วย `e.toString()` ได้เลย ต้องการแยกกรณีให้ดู [statusCode] หรือ [code] (ดู `ErrorCodes`)
/// **ห้ามจับคำในข้อความ** (ข้อความแก้ได้ทุกเมื่อ รหัสไม่เปลี่ยน)
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// รหัสข้อผิดพลาดของ backend (ช่อง `code`) ไม่มี = null
  final String? code;

  /// รายละเอียดเพิ่มของบาง code (ช่อง `details`) เช่น จำนวนรายการที่จะถูกล้างของ CONFIRM_REQUIRED
  final Map<String, dynamic>? details;

  const ApiException(this.message, {this.statusCode, this.code, this.details});

  /// งานจะล้างข้อมูลเดิม ต้องถามผู้ใช้แล้วส่งคำยืนยัน
  bool get isConfirmRequired => code == ErrorCodes.confirmRequired;

  /// นอกช่วงวัน-เวลาที่เปิดให้แก้ไขข้อมูล
  bool get isEditWindowClosed => code == ErrorCodes.editWindowClosed;

  /// ไม่มีสิทธิ์กับหน่วยงานที่ระบุ
  bool get isDivForbidden => code == ErrorCodes.divForbidden;

  /// บัญชีถูกล็อกจากการใส่รหัสผ่านผิดหลายครั้ง
  bool get isAccountLocked => code == ErrorCodes.accountLocked;

  @override
  String toString() => message;
}
