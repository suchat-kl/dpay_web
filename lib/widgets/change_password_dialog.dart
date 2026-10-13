import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'account_form.dart';

/// หน้าต่างเปลี่ยนรหัสผ่านของตัวเอง (`POST /api/auth/changepassword {oldPassword, newPassword}`)
///
/// backend รู้ว่าเป็นบัญชีไหนจาก token [username] ใช้แสดงให้ผู้ใช้เห็นเท่านั้น ไม่ได้ส่งไป
/// สำเร็จ = ปิดหน้าต่างพร้อมคืน true
class ChangePasswordDialog extends StatefulWidget {
  final String username;
  final ApiService apiService;

  /// บังคับเปลี่ยน (บัญชีที่เพิ่งสร้าง หรือผู้ดูแลเพิ่งตั้งรหัสผ่านใหม่ให้ — backend เป็นผู้บอก): ปิดหน้านี้ไม่ได้
  /// ปุ่มยกเลิกเปลี่ยนเป็นออกจากระบบ คืนค่า false ให้ผู้เรียกไปออกจากระบบ
  final bool forced;

  const ChangePasswordDialog({
    super.key,
    required this.username,
    required this.apiService,
    this.forced = false,
  });

  static const String title = 'เปลี่ยนรหัสผ่าน';
  static const String forcedSubtitle =
      'ต้องเปลี่ยนรหัสผ่านก่อนจึงจะใช้งานส่วนอื่นของระบบได้';
  static const String normalSubtitle = 'กรุณากรอกรหัสผ่านให้ตรงตามเงื่อนไข';
  static const String oldHint = 'กรอกรหัสผ่านเดิม';
  static const String newHint = 'กรอกรหัสผ่านใหม่';
  static const String confirmHint = 'กรุณากรอกรหัสผ่านใหม่อีกครั้ง';
  static const String successMessage =
      'เปลี่ยนรหัสผ่านสำเร็จ\nกรุณาใช้รหัสผ่านใหม่ในการเข้าสู่ระบบครั้งต่อไป';

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final _username = TextEditingController(text: widget.username);

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final rules = PasswordRules.of(_newPassword.text);
    if (!rules.allPassed) {
      setState(() {
        _errorMessage = rules.withinMaxLength
            ? PasswordRules.notMetMessage
            : PasswordRules.tooLongMessage;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.changePassword(
        _oldPassword.text,
        _newPassword.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      context.showSuccessSnackBar(ChangePasswordDialog.successMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // บังคับเปลี่ยน: กด Esc หรือย้อนกลับแล้วไม่ปิด
      canPop: !widget.forced,
      child: AccountDialogShell(
        icon: Icons.lock_reset,
        title: ChangePasswordDialog.title,
        subtitle: widget.forced
            ? ChangePasswordDialog.forcedSubtitle
            : ChangePasswordDialog.normalSubtitle,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                AccountBanner.error(
                  _errorMessage!,
                  onClose: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 16),
              ],
              AccountField(
                label: 'ชื่อผู้ใช้',
                icon: Icons.person,
                controller: _username,
                readOnly: true,
              ),
              const SizedBox(height: 16),
              PasswordField(
                label: 'รหัสผ่านเดิม',
                hint: ChangePasswordDialog.oldHint,
                controller: _oldPassword,
                enabled: !_isLoading,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่านเดิม' : null,
              ),
              const SizedBox(height: 16),
              PasswordField(
                label: 'รหัสผ่านใหม่',
                hint: ChangePasswordDialog.newHint,
                icon: Icons.lock,
                controller: _newPassword,
                enabled: !_isLoading,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                  if (v == _oldPassword.text) {
                    return 'รหัสผ่านใหม่ต้องไม่เหมือนรหัสผ่านเดิม';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                label: 'ยืนยันรหัสผ่านใหม่',
                hint: ChangePasswordDialog.confirmHint,
                icon: Icons.lock,
                controller: _confirmPassword,
                enabled: !_isLoading,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่านใหม่';
                  if (v != _newPassword.text) return 'รหัสผ่านไม่ตรงกัน';
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!_isLoading) _submit();
                },
              ),
              const SizedBox(height: 20),
              PasswordRuleList(rules: PasswordRules.of(_newPassword.text)),
              const SizedBox(height: 24),
              AccountActionButtons(
                cancelText: widget.forced ? 'ออกจากระบบ' : 'ยกเลิก',
                confirmText: ChangePasswordDialog.title,
                loading: _isLoading,
                onCancel: () => Navigator.of(context).pop(false),
                onConfirm: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
