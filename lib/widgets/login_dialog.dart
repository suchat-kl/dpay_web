import 'package:flutter/material.dart';
import 'package:dpay/providers/auth_provider.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import 'account_form.dart';

/// หน้าต่างเข้าสู่ระบบด้วยชื่อผู้ใช้ (รหัสหน่วยงาน 3 หลัก) และรหัสผ่าน สำเร็จแล้วปิดตัวเองและคืนค่า true
///
/// ระบบนี้มีแต่บัญชีหน่วยงาน ไม่มีลงทะเบียนเอง ไม่มี ThaID และไม่มีการยืนยันสองชั้น
class LoginDialog extends StatefulWidget {
  final AuthProvider authProvider;

  /// ชื่อผู้ใช้ที่เติมไว้ให้ตอนเปิด
  final String? initialUsername;

  /// ข้อความแจ้งสีเขียวเหนือช่องกรอกตอนเปิด
  final String? initialMessage;

  const LoginDialog({
    super.key,
    required this.authProvider,
    this.initialUsername,
    this.initialMessage,
  });

  /// คีย์ของแถบหัวสีของหน้าต่าง ใช้วัดความสูงในเทสต์
  static const Key headerKey = ValueKey('login-dialog-header');

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  /// ข้อความแจ้งสีเขียวเหนือช่องกรอก (ผู้เปิดหน้าต่างส่งมา) หายเมื่อกดเข้าสู่ระบบ
  late String? _infoMessage = widget.initialMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.initialUsername ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await widget.authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      _finishLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// ได้ token แล้ว: แจ้งต้อนรับและปิดหน้าต่าง
  void _finishLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยินดีต้อนรับ ${widget.authProvider.displayName}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 20,
        vertical: isDesktop ? 24 : 16,
      ),
      child: Container(
        width: isDesktop ? 480 : screenWidth * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        // ตัดเนื้อหาตามมุมโค้งของหน้าต่าง กันส่วนที่เลื่อนโผล่ทับแถบหัว
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: LoginDialog.headerKey,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 28 : 20,
                vertical: isDesktop ? 26 : 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              // แถบหัวแบบเตี้ย: ไอคอนกับชื่อเรื่องอยู่แถวเดียวกัน
              // (ไอคอนใหญ่ซ้อนเหนือชื่อเรื่องกินความสูงจนต้องเลื่อนหาปุ่มเข้าสู่ระบบบนจอโน้ตบุ๊ก)
              child: Row(
                children: [
                  Container(
                    width: isDesktop ? 52 : 44,
                    height: isDesktop ? 52 : 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      AppConfig.systemIcon,
                      color: AppTheme.primaryColor,
                      size: isDesktop ? 28 : 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'เข้าสู่ระบบ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isDesktop ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConfig.systemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isDesktop ? 13 : 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ฟอร์ม — จอเตี้ยเลื่อนเฉพาะส่วนนี้ แถบหัวอยู่เหนือพื้นที่เลื่อน ไม่ทับเนื้อหา
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                  vertical: isDesktop ? 22 : 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _errorMessage = null),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red.shade700,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_infoMessage != null) ...[
                        AccountBanner.success(
                          _infoMessage!,
                          onClose: () => setState(() => _infoMessage = null),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _usernameController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: 'ชื่อผู้ใช้',
                          hintText: 'รหัสหน่วยงาน 3 หลัก',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกชื่อผู้ใช้';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่าน',
                          hintText: 'กรอกรหัสผ่าน',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                        ),
                        style: const TextStyle(fontSize: 16),
                        // กด Enter ในช่องรหัสผ่าน = กดปุ่มเข้าสู่ระบบ
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _handleLogin();
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกรหัสผ่าน';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        height: isDesktop ? 50 : 44,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.login, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'เข้าสู่ระบบ',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 16 : 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        height: isDesktop ? 50 : 44,
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cancelColor,
                            side: const BorderSide(color: AppTheme.cancelColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'ยกเลิก',
                            style: TextStyle(fontSize: isDesktop ? 16 : 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
