import 'package:flutter/material.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/utils/snackbar_helper.dart';
import 'package:dpay/widgets/change_password_dialog.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_dialog.dart';

/// แถบบนของแอป: ไอคอน + ชื่อระบบ ปุ่มเลือกธีม และปุ่มเข้าสู่ระบบ / เมนูผู้ใช้
class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final AuthProvider authProvider;

  const CustomHeader({super.key, required this.authProvider});

  /// ข้อความบอกวิธีเข้าสู่ระบบ แสดงก่อนเข้าสู่ระบบ — จอกว้างอยู่แถวเดียวกับชื่อระบบในแถบบน
  /// จอแคบ (ต่ำกว่า [loginPromptMinWidth]) แถบบนไม่พอ หน้าแรกแสดงเป็นแถบบาง ๆ ใต้แถบบนแทน
  static const String loginPrompt =
      'เข้าสู่ระบบด้วยรหัสหน่วยงานและรหัสผ่านของหน่วยงาน';
  static const Key loginPromptKey = ValueKey('header-login-prompt');
  static const double loginPromptMinWidth = 900;

  /// จอกว้างพอให้ข้อความบอกวิธีเข้าสู่ระบบอยู่ในแถบบนหรือไม่
  static bool promptFitsHeader(BuildContext context) =>
      MediaQuery.of(context).size.width >= loginPromptMinWidth;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final showPrompt = !authProvider.isLoggedIn && promptFitsHeader(context);

    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 4,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              AppConfig.systemIcon,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          // ต้องเป็น Expanded/Flexible และตัดท้ายด้วยจุดไข่ปลา
          // ไม่งั้นชื่อระบบยาวกว่าแถบบนตอนเปิดด้วยจอแคบ แล้ว Row จะ overflow
          Flexible(
            flex: showPrompt ? 0 : 1,
            fit: showPrompt ? FlexFit.loose : FlexFit.tight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConfig.systemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isNarrow ? 14 : 16,
                  ),
                ),
                Text(
                  AppConfig.organizationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isNarrow ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          // ก่อนเข้าสู่ระบบ (จอกว้าง): วิธีเข้าสู่ระบบอยู่แถวเดียวกับชื่อระบบ กึ่งกลางที่ว่างของแถบบน
          if (showPrompt)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  loginPrompt,
                  key: loginPromptKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        // หน่วยงานของผู้ใช้ (เฉพาะจอกว้าง ชื่อหน่วยงานยาวได้จึงจำกัดความกว้างและตัดท้าย)
        if (authProvider.isLoggedIn && MediaQuery.of(context).size.width > 1200)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'หน่วยงาน ${authProvider.divLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),

        _buildThemeButton(),

        // เข้าสู่ระบบแล้ว = เมนูผู้ใช้ ยังไม่เข้า = ปุ่มเข้าสู่ระบบ
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: authProvider.isLoggedIn
              ? _buildUserMenu(context)
              : _buildLoginButton(context),
        ),
      ],
    );
  }

  /// ปุ่มเข้าสู่ระบบที่แถบบน — ทางเข้าสู่ระบบทางเดียวของแอป (หน้าแรกไม่มีปุ่มซ้ำแล้ว)
  static const Key loginButtonKey = ValueKey('header-login');

  /// คำอธิบายของปุ่มจานสี
  static const String themeButtonTooltip = 'เปลี่ยนธีม';

  /// ปุ่มจานสี เลือกธีมของทั้งระบบ (จำไว้ในเบราว์เซอร์ ดู main.dart)
  Widget _buildThemeButton() {
    return PopupMenuButton<String>(
      tooltip: themeButtonTooltip,
      icon: const Icon(Icons.palette_outlined, color: Colors.white),
      initialValue: AppTheme.current.id,
      onSelected: AppTheme.select,
      itemBuilder: (context) => [
        for (final palette in AppTheme.palettes)
          PopupMenuItem<String>(
            value: palette.id,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.primaryPale, width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    palette.name,
                    style: const TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (palette.id == AppTheme.current.id)
                  Icon(Icons.check, size: 18, color: palette.primary),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextButton.icon(
        key: loginButtonKey,
        onPressed: () => _showLoginDialog(context),
        icon: const Icon(Icons.person, color: Colors.white, size: 20),
        label: const Text(
          'เข้าสู่ระบบ',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: Text(
                authProvider.initials,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            // ชื่อที่แสดงเป็นชื่อหน่วยงานซึ่งยาวได้ จอแคบเหลือแค่รูปวงกลม จอกว้างตัดท้ายด้วยจุดไข่ปลา
            if (MediaQuery.of(context).size.width >= 600) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  authProvider.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            _showProfileDialog(context);
            break;
          case 'change_password':
            _showChangePasswordDialog(context);
            break;
          case 'logout':
            await authProvider.logout();
            if (context.mounted) {
              context.showSuccessSnackBar('ออกจากระบบเรียบร้อย');
            }
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          // หัวเมนู: ชื่อ ชื่อผู้ใช้ และบทบาทสูงสุด
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authProvider.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (authProvider.username != null)
                  Text(
                    authProvider.username!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    authProvider.highestRole,
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 12),
                Text('ข้อมูลส่วนตัว'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'change_password',
            child: Row(
              children: [
                Icon(Icons.lock_reset, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 12),
                Text('เปลี่ยนรหัสผ่าน'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: AppTheme.dangerColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  'ออกจากระบบ',
                  style: TextStyle(color: AppTheme.dangerColor),
                ),
              ],
            ),
          ),
        ];
        return items;
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangePasswordDialog(
        username: authProvider.username ?? '',
        apiService: ApiService(),
      ),
    ).then((result) {
      // แถบแจ้งผลสำเร็จแสดงจากในหน้าต่างเองแล้ว
      if (result == true && context.mounted) {
        _showLogoutConfirmation(context);
      }
    });
  }

  /// หลังเปลี่ยนรหัสผ่านของตัวเอง: แนะนำให้ออกจากระบบแล้วเข้าใหม่ด้วยรหัสใหม่
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('คำแนะนำด้านความปลอดภัย'),
        content: const Text(
          'เพื่อความปลอดภัย แนะนำให้ออกจากระบบและเข้าสู่ระบบใหม่ด้วยรหัสผ่านใหม่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ภายหลัง'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authProvider.logout();
            },
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  /// เปิดหน้าต่างเข้าสู่ระบบ (ข้อความต้อนรับแสดงจากในหน้าต่างเองเมื่อสำเร็จ)
  void _showLoginDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => LoginDialog(authProvider: authProvider),
    );
  }

  /// ข้อมูลของผู้ที่เข้าสู่ระบบ อ่านอย่างเดียว (ผู้ใช้แก้ชื่อ/หน่วยงาน/บทบาทเองไม่ได้)
  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ข้อมูลผู้ใช้'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                authProvider.initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ชื่อ: ${authProvider.displayName}',
              textAlign: TextAlign.center,
            ),
            if (authProvider.username != null)
              Text('ผู้ใช้งาน: ${authProvider.username}'),
            Text('หน่วยงาน: ${authProvider.divLabel}'),
            Text('เลือกหน่วยงานได้: ${authProvider.divScope.label}'),
            const SizedBox(height: 8),
            Text(
              'บทบาท: ${authProvider.roleDisplayNames.join(", ")}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
