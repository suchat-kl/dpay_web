import 'package:flutter/foundation.dart';
import '../models/edit_window.dart';
import '../models/period.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// ค่าตั้งกลางที่ทุกหน้าจอใช้ร่วมกัน: งวดปัจจุบัน ระยะเวลาแก้ไขข้อมูล `can_edit_now` และข้อความแจ้งผู้ใช้งาน
///
/// ตัวเดียวทั้งแอป (singleton แบบเดียวกับ `ApiService`) หน้าจอใดก็เรียก `SettingsProvider()` แล้วอ่านค่าได้เลย
/// ต้องการวาดใหม่เมื่อค่าเปลี่ยนให้ฟังด้วย `ListenableBuilder(listenable: SettingsProvider(), ...)`
///
/// วิธีใช้ในหน้าจอของระยะถัดไป
/// ```dart
/// final settings = SettingsProvider();
/// final period = settings.period;            // งวดที่กำลังทำงาน (null = ยังโหลดไม่เสร็จ)
/// if (!settings.canEditNow) { /* ปิดปุ่มบันทึก/ลบ */ }
/// ```
/// `canEditNow` ใช้เปิด/ปิดปุ่มเท่านั้น การบังคับจริงอยู่ที่ backend (403 `EDIT_WINDOW_CLOSED`)
/// เมื่อได้รหัสนั้นกลับมาให้เรียก [load] อีกครั้ง หน้าจอจะได้สถานะล่าสุด
///
/// ใครสั่งโหลด: `main.dart` เรียก [load] เมื่อเข้าสู่ระบบ (หรือกู้ session) และ [clear] เมื่อออกจากระบบ
/// หน้าแรกเรียก [loadAlertMessage] ทุกครั้งที่เปิด หน้าตั้งค่าของ ACCOUNT ส่งค่าที่บันทึกแล้วกลับมาด้วย set...
class SettingsProvider extends ChangeNotifier {
  static final SettingsProvider _instance = SettingsProvider._();
  factory SettingsProvider() => _instance;
  SettingsProvider._();

  final ApiService _api = ApiService();

  Period? _period;
  EditWindow? _editWindow;
  String? _alertMessage;
  bool _loading = false;
  bool _alertLoading = false;
  String? _error;
  String? _alertError;

  /// นับรอบการโหลด ผลของรอบเก่าที่กลับมาช้ากว่า (เช่นออกจากระบบไปแล้ว) ถูกทิ้ง
  int _serial = 0;

  /// งวดปัจจุบัน (เดือน ปี พ.ศ.) null = ยังไม่ได้โหลด / โหลดไม่สำเร็จ
  Period? get period => _period;

  /// ระยะเวลาแก้ไขข้อมูล null = ยังไม่ได้โหลด / โหลดไม่สำเร็จ
  EditWindow? get editWindow => _editWindow;

  /// บัญชีที่เข้าสู่ระบบอยู่แก้ไขข้อมูลหักหนี้ได้ตอนนี้ไหม (ACCOUNT ได้เสมอ) ยังไม่รู้ = ไม่ได้
  bool get canEditNow => _editWindow?.canEditNow ?? false;

  /// กำลังโหลดงวดและระยะเวลาแก้ไข
  bool get loading => _loading;

  /// ข้อความผิดพลาดของการโหลดงวด/ระยะเวลาแก้ไขครั้งล่าสุด สำเร็จ = null
  String? get error => _error;

  /// ข้อความแจ้งผู้ใช้งาน null = ยังไม่ได้โหลด, ข้อความว่าง = ไม่มีข้อความแจ้ง
  String? get alertMessage => _alertMessage;
  bool get alertLoading => _alertLoading;

  /// ข้อความผิดพลาดของการโหลดข้อความแจ้งครั้งล่าสุด สำเร็จ = null
  String? get alertError => _alertError;

  /// โหลดงวดปัจจุบันและระยะเวลาแก้ไข (ต้องเข้าสู่ระบบและไม่ติดบังคับเปลี่ยนรหัสผ่าน)
  /// ไม่โยนข้อผิดพลาด — ดูผลที่ [error]
  Future<void> load() async {
    final serial = ++_serial;
    _loading = true;
    _error = null;
    notifyListeners();
    Period? period;
    EditWindow? window;
    String? error;
    try {
      final results = await Future.wait([
        _api.getPeriod(),
        _api.getEditWindow(),
      ]);
      period = results[0] as Period;
      window = results[1] as EditWindow;
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ โหลดค่าตั้งกลางไม่สำเร็จ: $e');
      error = e.toString();
    }
    if (serial != _serial) return;
    _loading = false;
    if (error == null) {
      _period = period;
      _editWindow = window;
    }
    _error = error;
    notifyListeners();
  }

  /// โหลดข้อความแจ้งผู้ใช้งาน (เส้นสาธารณะ ไม่ต้องเข้าสู่ระบบ) ไม่โยนข้อผิดพลาด — ดูผลที่ [alertError]
  Future<void> loadAlertMessage() async {
    _alertLoading = true;
    _alertError = null;
    notifyListeners();
    try {
      _alertMessage = await _api.getAlertMessage();
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ โหลดข้อความแจ้งไม่สำเร็จ: $e');
      _alertError = e.toString();
    }
    _alertLoading = false;
    notifyListeners();
  }

  /// หน้ากำหนดเดือนปีบันทึกสำเร็จ: ใช้ค่าที่ backend ตอบทันที ไม่ต้องโหลดใหม่
  void setPeriod(Period period) {
    _period = period;
    notifyListeners();
  }

  /// หน้าระยะเวลาแก้ไขข้อมูลบันทึกสำเร็จ
  void setEditWindow(EditWindow window) {
    _editWindow = window;
    notifyListeners();
  }

  /// หน้าข้อความแจ้งผู้ใช้งานบันทึกสำเร็จ
  void setAlertMessage(String message) {
    _alertMessage = message;
    _alertError = null;
    notifyListeners();
  }

  /// ออกจากระบบ: ทิ้งงวดและระยะเวลาแก้ไข (เป็นข้อมูลของผู้ที่เข้าสู่ระบบ) คงข้อความแจ้งไว้ (สาธารณะ)
  void clear() {
    _serial++;
    _period = null;
    _editWindow = null;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  /// ล้างทุกค่ารวมข้อความแจ้ง ใช้ในเทสต์ก่อนเริ่มแต่ละกรณี
  @visibleForTesting
  void reset() {
    _alertMessage = null;
    _alertLoading = false;
    _alertError = null;
    clear();
  }
}
