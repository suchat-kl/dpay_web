import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

/// ส่วนท้ายหน้าแรก: ไอคอน ชื่อระบบ หน่วยงาน คำอธิบายสั้น และแถบลิขสิทธิ์
/// ข้อความทั้งหมดมาจาก `AppConfig` ต้องการที่อยู่/เบอร์โทร/ลิงก์ ให้เพิ่มในไฟล์นี้
class CustomFooter extends StatelessWidget {
  const CustomFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 600;
        return Container(
          width: double.infinity,
          color: AppTheme.primaryColor,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(isMobile ? 24 : 32),
                child: _buildBrand(isMobile: isMobile),
              ),
              _buildCopyrightBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrand({bool isMobile = false}) {
    return Row(
      children: [
        Container(
          width: isMobile ? 40 : 50,
          height: isMobile ? 40 : 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          // ไอคอนเดียวกับแถบบน
          child: Icon(
            AppConfig.systemIcon,
            color: AppTheme.primaryColor,
            size: isMobile ? 24 : 30,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConfig.systemName,
                style: TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                AppConfig.organizationName,
                style: TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppConfig.systemTagline,
                style: TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// แถบลิขสิทธิ์ — ปีเป็น พ.ศ. ของวันที่เปิดหน้า (ไม่ต้องแก้ทุกปี)
  /// ยังไม่มีลิงก์ "นโยบายความเป็นส่วนตัว / ข้อกำหนดการใช้งาน" — มีเอกสารเมื่อใดค่อยเพิ่ม
  /// (ลิงก์ที่กดแล้วไม่เกิดอะไรทำให้ผู้ใช้สับสน)
  Widget _buildCopyrightBar(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'NotoSansThai',
      color: Colors.white70,
      fontSize: 12,
    );
    final buddhistYear = DateTime.now().year + 543;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2)),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            '© พ.ศ. $buddhistYear ${AppConfig.organizationName}',
            style: style,
          ),
          Text('•', style: style?.copyWith(color: Colors.white38)),
          Text('สงวนลิขสิทธิ์', style: style),
        ],
      ),
    );
  }
}
