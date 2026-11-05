import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../screens/loan_check_screen.dart';
import '../services/api_service.dart';
import 'screen_parts.dart';
import 'work_parts.dart';

/// ด่านของข้อ 8 "ตรวจยอดเงินกู้กับหนี้เดือน" (ผู้ใช้สั่ง 5 พ.ย. 2569)
///
/// ข้อ 9 ไฟล์ส่งกรมบัญชีกลาง และข้อ 10 รายงานส่งธนาคาร ใช้ได้เมื่อยอดเงินกู้ตรงกับหนี้เดือนทุกธนาคาร
/// และไม่มีคนที่มีหนี้ธนาคารแต่ไม่มีเลขบัญชี — ไม่ผ่านให้เตือนให้กลับไปแก้ที่ข้อ 8 ก่อน
/// ตรวจเฉพาะงวดปัจจุบัน: เลขบัญชีเงินกู้ไม่แยกงวด งวดย้อนหลังเทียบกันไม่ได้ จึงไม่ล็อก
/// backend กันซ้ำอีกชั้น: ดาวน์โหลดไฟล์/ออกรายงานของงวดปัจจุบันที่ยังไม่ผ่าน = 409 `LOAN_CHECK_REQUIRED` ([fromError])
class LoanGate {
  LoanGate._();

  static const String title = 'ต้องแก้ที่ "ตรวจยอดเงินกู้กับหนี้เดือน" ก่อน';
  static const String lockedLabel = 'รอแก้ตรวจยอดเงินกู้กับหนี้เดือน';
  static const String goLabel = 'ไปตรวจยอดเงินกู้กับหนี้เดือน';
  static const Key noticeKey = ValueKey('loan-gate-notice');
  static const Key goKey = ValueKey('loan-gate-go');

  /// ผลของ `GET /api/loans/check` ผ่านด่านหรือไม่
  static bool passed(Map<String, dynamic> check) =>
      check['ok'] == true &&
      intOf(check['mismatch_count']) == 0 &&
      intOf(check['missing_account']) == 0;

  /// สรุปสิ่งที่ต้องแก้ เช่น "ยอดไม่ตรง 3 รายการ · ไม่มีเลขบัญชี 1 คน"
  static String problems(Map<String, dynamic> check) {
    final wrong = intOf(check['mismatch_count']);
    final missing = intOf(check['missing_account']);
    return [
      if (wrong > 0 || check['ok'] != true)
        'ยอดเงินกู้ไม่ตรงกับหนี้เดือน ${countText(wrong)} รายการ',
      if (missing > 0) 'ไม่มีเลขบัญชีเงินกู้ ${countText(missing)} คน',
    ].join(' · ');
  }

  /// ข้อความเตือนเต็ม — [action] คือสิ่งที่ทำไม่ได้ เช่น "ดาวน์โหลดไฟล์ส่งกรมบัญชีกลาง"
  static String message(Map<String, dynamic> check, String action) =>
      '${problems(check)}\n'
      'กรุณากลับไปแก้ที่ "${LoanCheckScreen.menuTitle}" ให้เรียบร้อยก่อน จึงจะ$actionได้';

  /// ข้อความจาก 409 LOAN_CHECK_REQUIRED ของ backend (ผลตรวจเปลี่ยนระหว่างที่เปิดหน้าอยู่)
  static String fromError(ApiException e, String action) {
    final details = e.details;
    return details == null
        ? '${e.message}\nจึงยัง$actionไม่ได้'
        : message(Map<String, dynamic>.from(details), action);
  }

  /// ข้อความเมื่อตรวจข้อ 8 ไม่สำเร็จ (ล็อกไว้ก่อน)
  static String failedText(String error) =>
      'ตรวจยอดเงินกู้กับหนี้เดือนไม่สำเร็จ จึงยังใช้หน้านี้ไม่ได้: $error';

  /// เปิดหน้าข้อ 8 แล้วรอจนผู้ใช้กลับมา
  static Future<void> openCheck(BuildContext context, ApiService api) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LoanCheckScreen(apiService: api),
        ),
      );
}

/// แถบเตือนของด่านข้อ 8 ในหน้าข้อ 9/10 พร้อมปุ่มไปหน้าข้อ 8 — กลับมาแล้วเรียก [onReturn] ให้ตรวจใหม่
class LoanGateNotice extends StatelessWidget {
  final ApiService apiService;
  final String text;
  final VoidCallback onReturn;

  const LoanGateNotice({
    super.key = LoanGate.noticeKey,
    required this.apiService,
    required this.text,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return NoticeBar(
      type: NoticeType.warning,
      title: LoanGate.title,
      text: text,
      action: ElevatedButton.icon(
        key: LoanGate.goKey,
        onPressed: () async {
          await LoanGate.openCheck(context, apiService);
          onReturn();
        },
        icon: const Icon(Icons.fact_check_outlined, size: 18),
        label: Text(
          LoanGate.goLabel,
          style: screenText(size: 14, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
