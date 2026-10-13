import 'package:flutter/material.dart';

import '../config/theme.dart';

/// กล่องแสดงข้อความแจ้งผู้ใช้งาน — ใช้ทั้งที่หน้าแรกและเป็นตัวอย่างในหน้าแก้ข้อความ (หน้าตาเดียวกัน)
///
/// ข้อความเป็นข้อความล้วนหลายบรรทัด ยาวได้หลายร้อยตัวอักษร: แสดงตามบรรทัดที่พิมพ์มา ตัดบรรทัดตามความกว้าง
/// ระยะบรรทัดโปร่ง เลือกคัดลอกได้ **ไม่ตีความเป็น HTML** (แท็กที่พิมพ์มาจะเห็นเป็นตัวอักษร)
class AlertMessageBox extends StatelessWidget {
  /// ข้อความที่แสดง ว่าง (หรือมีแต่ช่องว่าง) = แสดง [emptyText]
  final String message;

  /// กำลังโหลด: แสดงวงหมุนแทนข้อความ
  final bool loading;

  /// ข้อความผิดพลาดของการโหลด (แสดงแทนข้อความ พร้อมปุ่มลองใหม่ถ้ามี [onRetry])
  final String? error;
  final VoidCallback? onRetry;

  const AlertMessageBox({
    super.key,
    required this.message,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  static const String title = 'ข้อความแจ้งผู้ใช้งาน';
  static const String emptyText = 'ไม่มีข้อความแจ้งในขณะนี้';

  /// คีย์ของตัวข้อความ ใช้หาในเทสต์
  static const Key textKey = ValueKey('alert-message-text');

  static const String _font = 'Sarabun';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final text = message.trim();

    Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    } else if (error != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error!,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 15,
              color: AppTheme.dangerColor,
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ลองใหม่', style: TextStyle(fontFamily: _font)),
            ),
        ],
      );
    } else if (text.isEmpty) {
      body = const Text(
        emptyText,
        style: TextStyle(
          fontFamily: _font,
          fontSize: 15,
          color: AppTheme.textSecondary,
        ),
      );
    } else {
      body = SelectableText(
        text,
        key: textKey,
        style: TextStyle(
          fontFamily: _font,
          fontSize: isDesktop ? 17 : 16,
          height: 1.7,
          color: AppTheme.textPrimary,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // แถบหัวกล่อง สีเหลืองอ่อนให้สังเกตเห็นว่าเป็นประกาศ
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 14,
              vertical: 10,
            ),
            color: AppTheme.secondaryColor.withValues(alpha: 0.16),
            child: const Row(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  color: AppTheme.onSecondaryColor,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(isDesktop ? 20 : 14), child: body),
        ],
      ),
    );
  }
}
