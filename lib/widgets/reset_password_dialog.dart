import 'package:flutter/material.dart';
import '../models/user_admin.dart';
import '../services/api_service.dart';
import 'account_form.dart';

/// หน้าต่างกำหนดรหัสผ่านใหม่ให้บัญชี [user] (`POST /api/admin/users/{id}/reset-password {newPassword}`)
///
/// ใช้ได้กับ ADMIN และ RESETPWD บัญชีนั้นถูกออกจากระบบทันที และต้องเปลี่ยนรหัสผ่านเองตอนเข้าครั้งถัดไป
/// สำเร็จ = ปิดหน้าต่างพร้อมคืนข้อความของ backend (ยกเลิก = null)
class ResetPasswordDialog extends StatefulWidget {
  final UserAdmin user;
  final ApiService apiService;

  const ResetPasswordDialog({
    super.key,
    required this.user,
    required this.apiService,
  });

  static const String title = 'กำหนดรหัสผ่านใหม่';
  static const String newHint = 'กรอกรหัสผ่านใหม่';
  static const String confirmHint = 'กรอกรหัสผ่านใหม่อีกครั้ง';
  static const String notice =
      'เมื่อบันทึกแล้ว บัญชีนี้จะถูกออกจากระบบทันที '
      'และต้องเปลี่ยนรหัสผ่านเองตอนเข้าสู่ระบบครั้งถัดไป';

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final _account = TextEditingController(
    text: '${widget.user.username}  ·  ${widget.user.fullName}',
  );

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    _account.dispose();
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
      final message = await widget.apiService.resetUserPassword(
        widget.user.id,
        _newPassword.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(message);
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
    return AccountDialogShell(
      icon: Icons.lock_person,
      title: ResetPasswordDialog.title,
      subtitle: 'ให้หน่วยงาน ${widget.user.username}',
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
            const AccountBanner.info(ResetPasswordDialog.notice),
            const SizedBox(height: 16),
            AccountField(
              label: 'บัญชีผู้ใช้',
              icon: Icons.apartment,
              controller: _account,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            PasswordField(
              label: 'รหัสผ่านใหม่',
              hint: ResetPasswordDialog.newHint,
              icon: Icons.lock,
              controller: _newPassword,
              enabled: !_isLoading,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่านใหม่' : null,
            ),
            const SizedBox(height: 16),
            PasswordField(
              label: 'ยืนยันรหัสผ่านใหม่',
              hint: ResetPasswordDialog.confirmHint,
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
              confirmText: 'บันทึกรหัสผ่านใหม่',
              loading: _isLoading,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
