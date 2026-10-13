import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../widgets/screen_parts.dart';

/// หน้า "กำลังพัฒนา" ของเมนูที่ backend ยังไม่มี API ให้เรียก
///
/// เมนูข้างแสดงครบตามโครงเมนูของระบบเดิม (เตรียมข้อมูล / บันทึกข้อมูล / รายงาน) เมนูที่ยังไม่ได้ทำเปิดมาที่หน้านี้
/// เมื่อทำหน้าจอจริงเสร็จ ให้เปลี่ยนรายการในเมนูข้างไปเปิดหน้าจอนั้นแทน (ดู `SidebarMenu.prepareGroups`)
class ComingSoonScreen extends StatelessWidget {
  /// ชื่อเมนูที่ผู้ใช้กดเข้ามา
  final String title;

  /// ชื่อกลุ่มเมนู (แสดงที่แถบบนของหน้าจอ)
  final String group;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.group,
    this.icon = Icons.construction,
  });

  static const String heading = 'กำลังพัฒนา';
  static const String message =
      'เมนูนี้อยู่ระหว่างการพัฒนา ยังไม่เปิดให้ใช้งานในช่วงทดสอบนี้\n'
      'ระหว่างนี้ยังใช้งานส่วนนี้ที่ระบบเดิมได้ตามปกติ';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, group),
      body: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(icon: icon, title: title, subtitle: group),
                  const SizedBox(height: 16),
                  const NoticeBar(
                    type: NoticeType.info,
                    title: heading,
                    text: message,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
