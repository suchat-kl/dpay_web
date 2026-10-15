import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/edit_window.dart';
import '../models/period.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../utils/permission.dart';
import '../widgets/alert_message_box.dart';
import '../widgets/footer.dart';
import '../widgets/header.dart';
import '../widgets/period_progress.dart';
import '../widgets/screen_parts.dart';

/// หน้าแรกของระบบ — ลำดับจากบนลงล่าง (ผู้ใช้สั่ง 13 ต.ค. 2569 ไม่มีส่วนหัวภาพขนาดใหญ่/ปุ่มเข้าสู่ระบบในเนื้อหาแล้ว):
///
/// 1. ยังไม่เข้าสู่ระบบ: "เข้าสู่ระบบด้วยรหัสหน่วยงานและรหัสผ่านของหน่วยงาน" — จอกว้างอยู่แถวเดียวกับชื่อระบบในแถบบน
///    (ผู้ใช้สั่ง 13 ต.ค. 2569) จอแคบเป็นแถบบาง ๆ สีธีมบนสุดของหน้านี้ (ปุ่มเข้าสู่ระบบอยู่ที่แถบบนของแอป)
/// 2. **ข้อความแจ้งผู้ใช้งาน** (`GET /api/alert-message`) กล่องเดียวบนสุดของเนื้อหา — แสดงที่หน้านี้หน้าเดียวของระบบ
///    และเฉพาะก่อนเข้าสู่ระบบ (ผู้ใช้สั่ง 13 ต.ค. 2569: หลังเข้าสู่ระบบไม่ต้องแสดง)
/// 3. หลังเข้าสู่ระบบ: การ์ดหน่วยงานของผู้ใช้ งวดปัจจุบัน และสถานะระยะเวลาแก้ไขข้อมูล
/// 4. ฝ่ายบัญชี (ACCOUNT): การ์ด "ความคืบหน้าของงวด" ([PeriodProgress])
///
/// ค่าทั้งหมดอ่านจาก [SettingsProvider] หน้านี้สั่งโหลดข้อความแจ้งเองทุกครั้งที่เปิด
/// ส่วนงวดและระยะเวลาแก้ไข `main.dart` สั่งโหลดเมื่อเข้าสู่ระบบ
class HomeScreen extends StatefulWidget {
  final AuthProvider authProvider;

  const HomeScreen({super.key, required this.authProvider});

  /// ข้อความบอกวิธีเข้าสู่ระบบเมื่อยังไม่เข้าสู่ระบบ (ตัวเดียวกับที่แถบบนแสดงตอนจอกว้าง)
  static const String loginPrompt = CustomHeader.loginPrompt;

  static const Key loginStripKey = ValueKey('home-login-strip');
  static const Key divCardKey = ValueKey('home-div');
  static const Key periodCardKey = ValueKey('home-period');
  static const Key editWindowCardKey = ValueKey('home-edit-window');
  static const Key editStatusKey = ValueKey('home-edit-status');
  static const Key canEditKey = ValueKey('home-can-edit');

  static const String divCardTitle = 'หน่วยงานของท่าน';
  static const String periodCardTitle = 'งวดปัจจุบัน';
  static const String editWindowCardTitle = 'ระยะเวลาแก้ไขข้อมูล';
  static const String openLabel = 'เปิดให้แก้ไข';
  static const String closedLabel = 'ปิด';
  static const String canEditText = 'บัญชีนี้บันทึกและแก้ไขข้อมูลได้ในขณะนี้';
  static const String cannotEditText =
      'บัญชีนี้ยังแก้ไขข้อมูลไม่ได้ในขณะนี้ (ดูข้อมูลได้อย่างเดียว)';
  static const String accountAlwaysText =
      'ฝ่ายบัญชีแก้ไขข้อมูลได้ตลอด ไม่ขึ้นกับระยะเวลานี้';
  static const String adminAlwaysText =
      'ผู้ดูแลระบบมีสิทธิ์ทั้งหมด แก้ไขข้อมูลได้ตลอด ไม่ขึ้นกับระยะเวลานี้';
  static const String mustChangeText =
      'กรุณาเปลี่ยนรหัสผ่านก่อน จึงจะเห็นงวดปัจจุบันและระยะเวลาแก้ไขข้อมูล';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = SettingsProvider();

  AuthProvider get _auth => widget.authProvider;

  @override
  void initState() {
    super.initState();
    // โหลดหลังเฟรมแรก: การโหลดแจ้งผู้ฟังทันที ซึ่งทำระหว่าง build ไม่ได้
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _settings.loadAlertMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_auth, _settings]),
      builder: (context, _) {
        final isDesktop = MediaQuery.of(context).size.width > 1024;
        return SingleChildScrollView(
          child: Column(
            children: [
              // ก่อนเข้าสู่ระบบ จอแคบ: แถบข้อความบาง ๆ แถวบนสุด
              // (จอกว้างข้อความนี้อยู่แถวเดียวกับชื่อระบบในแถบบนแล้ว — ดู CustomHeader)
              if (!_auth.isLoggedIn && !CustomHeader.promptFitsHeader(context))
                _loginStrip(isDesktop),
              Container(
                width: double.infinity,
                color: AppTheme.backgroundColor,
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 12,
                  isDesktop ? 20 : 12,
                  isDesktop ? 32 : 12,
                  isDesktop ? 40 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ข้อความแจ้งผู้ใช้งาน: แสดงเฉพาะก่อนเข้าสู่ระบบ กล่องเดียวบนสุดของหน้า
                        // (ผู้ใช้สั่ง 13 ต.ค. 2569: หลังเข้าสู่ระบบไม่ต้องแสดง)
                        if (!_auth.isLoggedIn)
                          AlertMessageBox(
                            message: _settings.alertMessage ?? '',
                            loading:
                                _settings.alertLoading &&
                                _settings.alertMessage == null,
                            error: _settings.alertMessage == null
                                ? _settings.alertError
                                : null,
                            onRetry: _settings.loadAlertMessage,
                          ),
                        if (_auth.isLoggedIn) _buildStatusSection(),
                        // ความคืบหน้าของงานประจำงวด พร้อมทางลัดไปแต่ละเมนู — ฝ่ายบัญชีเห็นทุกขั้น
                        // ผู้ใช้ทั่วไปเห็นเฉพาะขั้นหน่วยงานบันทึกหนี้กับรายงาน
                        if (_auth.isLoggedIn &&
                            !_auth.mustChangePassword &&
                            (_auth.canView(Perm.prepare) ||
                                _auth.canView(Perm.debtEntry))) ...[
                          SizedBox(height: isDesktop ? 24 : 16),
                          PeriodProgress(apiService: ApiService()),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const CustomFooter(),
            ],
          ),
        );
      },
    );
  }

  /// แถบบาง ๆ บนสุดของหน้าแรกก่อนเข้าสู่ระบบ: บอกวิธีเข้าสู่ระบบหนึ่งบรรทัด (ปุ่มเข้าสู่ระบบอยู่ที่แถบบนของแอป)
  Widget _loginStrip(bool isDesktop) => Container(
    key: HomeScreen.loginStripKey,
    width: double.infinity,
    color: AppTheme.primaryColor,
    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 12, vertical: 8),
    child: Text(
      HomeScreen.loginPrompt,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'NotoSansThai',
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.35,
      ),
    ),
  );

  /// การ์ดสถานะหลังเข้าสู่ระบบ: หน่วยงาน งวดปัจจุบัน ระยะเวลาแก้ไขข้อมูล
  Widget _buildStatusSection() {
    if (_auth.mustChangePassword) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _divCard(),
          const SizedBox(height: 12),
          const NoticeBar(
            type: NoticeType.warning,
            text: HomeScreen.mustChangeText,
          ),
        ],
      );
    }
    final error = _settings.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          NoticeBar(
            type: NoticeType.error,
            title: 'โหลดงวดปัจจุบันและระยะเวลาแก้ไขข้อมูลไม่สำเร็จ',
            text: error,
            action: TextButton.icon(
              onPressed: _settings.load,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('ลองใหม่', style: screenText(size: 14)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ResponsiveGrid(
          minItemWidth: 300,
          maxColumns: 3,
          spacing: 14,
          children: [_divCard(), _periodCard(), _editWindowCard()],
        ),
      ],
    );
  }

  Widget _card({
    required Key key,
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: screenText(
                    size: 14.5,
                    weight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _divCard() => _card(
    key: HomeScreen.divCardKey,
    icon: Icons.apartment,
    color: AppTheme.infoColor,
    title: HomeScreen.divCardTitle,
    children: [
      Text(
        _auth.divLabel,
        style: screenText(size: 19, weight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'ชื่อผู้ใช้ ${_auth.username ?? '-'}',
        style: screenText(size: 13.5, color: AppTheme.textSecondary),
      ),
      Text(
        'เลือกหน่วยงานได้: ${_auth.divScope.label}',
        style: screenText(size: 13.5, color: AppTheme.textSecondary),
      ),
    ],
  );

  Widget _loadingLine() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    ),
  );

  Widget _periodCard() {
    final Period? period = _settings.period;
    return _card(
      key: HomeScreen.periodCardKey,
      icon: Icons.calendar_month,
      color: AppTheme.accentColor,
      title: HomeScreen.periodCardTitle,
      children: [
        if (period == null)
          _settings.loading
              ? _loadingLine()
              : Text('-', style: screenText(size: 19))
        else ...[
          Text(
            period.label,
            style: screenText(size: 22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'งวดที่ทุกหน่วยงานกำลังทำงาน',
            style: screenText(size: 13.5, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _editWindowCard() {
    final EditWindow? w = _settings.editWindow;
    return _card(
      key: HomeScreen.editWindowCardKey,
      icon: Icons.timer_outlined,
      color: AppTheme.warningColor,
      title: HomeScreen.editWindowCardTitle,
      trailing: w == null
          ? null
          : StatusChip(
              w.open ? HomeScreen.openLabel : HomeScreen.closedLabel,
              w.open ? AppTheme.successColor : AppTheme.dangerColor,
              key: HomeScreen.editStatusKey,
              solid: true,
            ),
      children: [
        if (w == null)
          _settings.loading
              ? _loadingLine()
              : Text('-', style: screenText(size: 19))
        else ...[
          if (w.isSet) ...[
            Text('ตั้งแต่ ${w.beginLabel}', style: screenText(size: 15.5)),
            Text('ถึง ${w.endLabel}', style: screenText(size: 15.5)),
          ] else
            Text(EditWindow.notSetLabel, style: screenText(size: 15.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                w.canEditNow ? Icons.check_circle : Icons.block,
                size: 18,
                color: w.canEditNow
                    ? AppTheme.successColor
                    : AppTheme.dangerColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  w.canEditNow
                      ? HomeScreen.canEditText
                      : HomeScreen.cannotEditText,
                  key: HomeScreen.canEditKey,
                  style: screenText(
                    size: 14.5,
                    weight: FontWeight.w600,
                    color: w.canEditNow
                        ? AppTheme.successColor
                        : AppTheme.dangerColor,
                  ),
                ),
              ),
            ],
          ),
          // ผู้ดูแลระบบ/ฝ่ายบัญชีแก้ได้แม้ช่วงปิด บอกเหตุไว้ไม่ให้สับสนกับป้าย "ปิด"
          // (ผู้ดูแลระบบมีสิทธิ์ทั้งหมด — บอกเป็นของผู้ดูแลก่อน แม้บัญชีนั้นมีบทบาทฝ่ายบัญชีด้วย)
          if (!w.open && w.canEditNow && (_auth.isAdmin || _auth.isAccount))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _auth.isAdmin
                    ? HomeScreen.adminAlwaysText
                    : HomeScreen.accountAlwaysText,
                style: screenText(size: 13, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ],
    );
  }
}
