import 'package:dio/dio.dart';
import 'api_service.dart';
import 'package:dpay/utils/logger.dart';

/// แนบ access token ให้ทุกคำขอ และต่ออายุ token อัตโนมัติเมื่อ backend ตอบ 401
///
/// backend ระบบหักหนี้ตอบ **401 `UNAUTHENTICATED`** เมื่อไม่มี token / token ใช้ไม่ได้แล้ว
/// ส่วน **403** มี `code` บอกเหตุเสมอ (บทบาทไม่พอ ไม่มีสิทธิ์กับหน่วยงาน นอกช่วงเวลาแก้ไข ต้องเปลี่ยนรหัสผ่าน)
/// ซึ่งต่ออายุ token ไปก็ไม่หาย จึงต่ออายุเฉพาะ 401 เท่านั้น (refresh token ใช้ได้ครั้งเดียว ไม่ควรเผาทิ้ง)
///
/// ลำดับเมื่อเจอ 401 ของเส้นที่ต้องยืนยันตัวตน
/// 1. ขอ token ชุดใหม่ด้วย refresh token (คำขออื่นที่ล้มระหว่างนี้เข้าคิวรอ ไม่ขอซ้ำ)
/// 2. สำเร็จ: ยิงคำขอเดิมและคำขอในคิวซ้ำด้วย token ใหม่ **ครั้งเดียว**
///    ยิงซ้ำแล้วยังได้ 401 ส่งข้อผิดพลาดให้ผู้เรียก ไม่วนต่ออายุ
/// 3. ไม่สำเร็จ (refresh token หมดอายุ/ถูกยกเลิก): ออกจากระบบ แอปพากลับหน้าแรก (ดู main.dart)
class AuthInterceptor extends Interceptor {
  final ApiService apiService;

  bool _isRefreshing = false;
  final List<Map<String, dynamic>> _pendingRequests = [];

  AuthInterceptor(this.apiService);

  /// เส้นที่ไม่แนบ token และเจอ 401 ก็ไม่ต่ออายุ token
  /// (รหัสผ่านผิดตอบ 401 ต้องส่งให้หน้าจอแสดงข้อความ ไม่ใช่ไปต่ออายุ token)
  /// จับคู่แบบ "path มีข้อความนี้อยู่" — `GET /api/alert-message` เป็นเส้นสาธารณะเช่นกัน
  /// แต่ `PUT` ของ path เดียวกันต้องแนบ token จึงไม่อยู่ในรายการนี้ (ฝั่งอ่านใช้ `publicDio` แทน)
  static const List<String> publicEndpoints = [
    '/api/auth/login',
    '/api/auth/refresh-token',
  ];

  static bool isPublicPath(String path) =>
      publicEndpoints.any((e) => path.contains(e));

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;

    final needsAuth = !isPublicPath(path);

    if (needsAuth) {
      final token = await apiService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final requestPath = err.requestOptions.path;

      // เส้น public และเส้นออกจากระบบ ไม่ต่ออายุ token
      if (isPublicPath(requestPath) || requestPath.contains('/auth/logout')) {
        return handler.next(err);
      }

      // คำขอนี้ต่ออายุ token แล้วยิงซ้ำมาแล้วครั้งหนึ่ง ยังได้ 401 อีก
      // ส่งข้อผิดพลาดให้ผู้เรียกแสดงข้อความ ไม่ต่ออายุวนซ้ำ
      if (err.requestOptions.extra[_retriedKey] == true) {
        return handler.next(err);
      }

      // กำลังต่ออายุอยู่แล้ว: เข้าคิวรอ ห้ามขอ token ซ้ำ (refresh token ใช้ได้ครั้งเดียว)
      if (_isRefreshing) {
        if (AppLogger.on) {
          AppLogger.d('⏳ กำลังต่ออายุ token อยู่ เข้าคิว: $requestPath');
        }
        _pendingRequests.add({
          'options': err.requestOptions,
          'handler': handler,
        });
        return;
      }

      _isRefreshing = true;
      if (AppLogger.on) AppLogger.d('🔄 เริ่มต่ออายุ token');

      try {
        await apiService.refreshToken();
        _isRefreshing = false;

        final newToken = await apiService.getAccessToken();

        if (AppLogger.on) {
          AppLogger.d(
            '✅ ต่ออายุแล้ว ยิงซ้ำ ${_pendingRequests.length + 1} คำขอ',
          );
        }

        // คำขอในคิวก่อน แล้วจึงคำขอที่เริ่มการต่ออายุ
        for (final pending in _pendingRequests) {
          final opts = pending['options'] as RequestOptions;
          final hdlr = pending['handler'] as ErrorInterceptorHandler;
          opts.headers['Authorization'] = 'Bearer $newToken';
          _retryRequest(opts, hdlr);
        }
        _pendingRequests.clear();

        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        _retryRequest(err.requestOptions, handler);
      } catch (e) {
        if (AppLogger.on) AppLogger.e('❌ ต่ออายุ token ไม่สำเร็จ: $e');
        _isRefreshing = false;

        for (final pending in _pendingRequests) {
          final hdlr = pending['handler'] as ErrorInterceptorHandler;
          hdlr.reject(err);
        }
        _pendingRequests.clear();

        handler.reject(err);

        // ต่ออายุไม่ได้ = session หมดแล้ว ออกจากระบบ (refreshToken() ออกให้แล้ว เรียกซ้ำไม่มีผลเสีย)
        await apiService.logout();
      }
    } else {
      handler.next(err);
    }
  }

  /// ป้ายใน `RequestOptions.extra` ว่าคำขอนี้ถูกยิงซ้ำหลังต่ออายุ token แล้ว
  static const String _retriedKey = 'auth_retried';

  void _retryRequest(RequestOptions options, ErrorInterceptorHandler handler) {
    if (AppLogger.on) AppLogger.d('🔄 ยิงซ้ำ: ${options.path}');
    options.extra[_retriedKey] = true;
    apiService.dio
        .fetch(options)
        .then(
          (response) {
            if (AppLogger.on) AppLogger.i('✅ ยิงซ้ำสำเร็จ: ${options.path}');
            handler.resolve(response);
          },
          onError: (e) {
            if (AppLogger.on) AppLogger.e('❌ ยิงซ้ำไม่สำเร็จ: ${options.path}');
            if (e is DioException) {
              handler.reject(e);
            } else {
              handler.reject(DioException(requestOptions: options, error: e));
            }
          },
        );
  }
}
