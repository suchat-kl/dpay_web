import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/div_dept.dart';
import '../models/user_admin.dart';
import '../services/api_service.dart';
import '../utils/permission.dart';
import 'account_form.dart';
import 'div_selector.dart';

/// หน้าต่างสร้าง/แก้ไขผู้ใช้ (เฉพาะ ADMIN)
///
/// [user] เป็น null = สร้างบัญชีใหม่ (`POST /api/admin/users` ชื่อผู้ใช้เติมจากรหัสหน่วยงานที่เลือก แก้ได้ + รหัสผ่านตั้งต้น)
/// ไม่ใช่ null = แก้ไขบัญชีนั้น (`PUT /api/admin/users/{id}` ชื่อผู้ใช้แก้ไม่ได้ มีสวิตช์ระงับ/ปลดล็อก)
/// บทบาทมาจาก `/api/admin/roles` หน่วยงานมาจาก `/api/admin/divs`
/// บันทึกสำเร็จ = ปิดหน้าต่างพร้อมคืน [UserAdmin] ที่ backend ตอบ (ยกเลิก = null)
/// ไม่มีปุ่มลบ: backend ไม่มีเส้นลบ ให้ระงับการใช้งานแทน
class UserDialog extends StatefulWidget {
  final UserAdmin? user;
  final ApiService apiService;

  const UserDialog({super.key, this.user, required this.apiService});

  static const Key usernameKey = ValueKey('user-username');
  static const Key fullNameKey = ValueKey('user-fullname');
  static const Key emailKey = ValueKey('user-email');
  static const Key passwordKey = ValueKey('user-password');
  static const Key activeKey = ValueKey('user-active');
  static const Key lockedKey = ValueKey('user-locked');

  /// คีย์ของป้ายเลือกบทบาท [code]
  static Key roleKey(String code) => ValueKey('user-role-$code');

  static const String createTitle = 'เพิ่มผู้ใช้';
  static const String roleRequiredMessage = 'กรุณาเลือกบทบาทอย่างน้อย 1 บทบาท';
  static const String divRequiredMessage = 'กรุณาเลือกหน่วยงาน';
  static const String usernameRuleMessage =
      'ชื่อผู้ใช้ต้องเป็นตัวเลข 3-10 หลัก (ปกติใช้รหัสหน่วยงาน)';

  /// กติกาชื่อผู้ใช้: ตัวเลขล้วน 3-10 หลัก (รหัสหน่วยงานตอนนี้ยาวสุด 4 หลัก เผื่อไว้ถึง 10)
  static final RegExp usernamePattern = RegExp(r'^\d{3,10}$');
  static const String nameRuleMessage =
      'กรุณากรอกชื่อที่แสดง อย่างน้อย 3 ตัวอักษร';

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.user?.username);
  late final _fullName = TextEditingController(text: widget.user?.fullName);
  late final _email = TextEditingController(text: widget.user?.email);
  final _password = TextEditingController();
  late final Set<String> _roles = {...?widget.user?.roles};
  late String? _div = (widget.user?.div ?? '').isEmpty
      ? null
      : widget.user!.div;
  late bool _active = widget.user?.active ?? true;
  late bool _locked = widget.user?.locked ?? false;

  /// บทบาทที่เลือกได้ {code, name} ว่าง = กำลังโหลด
  List<Map<String, String>> _allRoles = [];
  List<DivDept>? _divs;
  bool _saving = false;
  String? _error;
  String? _divError;

  /// ผู้ใช้พิมพ์ชื่อผู้ใช้เองแล้ว (เช่นบัญชีพิเศษที่ไม่ตรงกับรหัสหน่วยงาน) เลือกหน่วยงานจะไม่เขียนทับ
  bool _usernameTyped = false;

  bool get _isEdit => widget.user != null;

  /// เลือกหน่วยงาน: ตอนสร้างบัญชีใหม่ เติมชื่อผู้ใช้ด้วยรหัสหน่วยงานให้ ถ้าผู้ใช้ยังไม่ได้พิมพ์เอง
  void _onDivChanged(String? div) => setState(() {
    _div = div;
    _divError = null;
    if (!_isEdit && !_usernameTyped && div != null) _username.text = div;
  });

  @override
  void initState() {
    super.initState();
    _loadChoices();
  }

  @override
  void dispose() {
    for (final c in [_username, _fullName, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChoices() async {
    final roles = await widget.apiService.getRoles();
    if (!mounted) return;
    setState(() {
      _allRoles = [
        ...roles,
        // บทบาทที่บัญชีถืออยู่แต่ไม่อยู่ในรายการ ให้เห็นและเอาออกได้
        for (final r in _roles)
          if (!roles.any((e) => e['code'] == r))
            {'code': r, 'name': Roles.nameOf(r)},
      ];
    });
    try {
      final divs = await widget.apiService.getAdminDivs();
      if (mounted) setState(() => _divs = divs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _divs = const [];
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() {
      _divError = _div == null ? UserDialog.divRequiredMessage : null;
      _error = null;
    });
    if (!valid || _div == null) return;
    if (_roles.isEmpty) {
      setState(() => _error = UserDialog.roleRequiredMessage);
      return;
    }
    if (!_isEdit) {
      final rules = PasswordRules.of(_password.text);
      if (!rules.allPassed) {
        setState(() {
          _error = rules.withinMaxLength
              ? PasswordRules.notMetMessage
              : PasswordRules.tooLongMessage;
        });
        return;
      }
    }

    setState(() => _saving = true);
    final draft = UserAdmin(
      id: widget.user?.id ?? '',
      username: _username.text.trim(),
      fullName: _fullName.text.trim(),
      email: _email.text.trim(),
      div: _div!,
      // ส่งตามลำดับมาตรฐานของระบบ ไม่ใช่ลำดับที่กดเลือก
      roles: [
        for (final r in _allRoles)
          if (_roles.contains(r['code'])) r['code']!,
      ],
      active: _active,
      locked: _locked,
    );
    try {
      final saved = _isEdit
          ? await widget.apiService.updateAdminUser(draft)
          : await widget.apiService.createAdminUser(draft, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      fontFamily: kAccountFont,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
    );
    const small = TextStyle(fontFamily: kAccountFont, fontSize: 13);
    return AccountDialogShell(
      icon: _isEdit ? Icons.manage_accounts : Icons.person_add,
      title: _isEdit
          ? 'แก้ไขผู้ใช้: ${widget.user!.username}'
          : UserDialog.createTitle,
      subtitle: _isEdit
          ? 'ชื่อผู้ใช้แก้ไขไม่ได้'
          : 'ผู้ใช้ต้องเปลี่ยนรหัสผ่านเองตอนเข้าสู่ระบบครั้งแรก',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AccountBanner.error(
                _error!,
                onClose: () => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
            ],
            if (!_isEdit) ...[
              AccountField(
                key: UserDialog.usernameKey,
                label: 'ชื่อผู้ใช้ (ตัวเลข 3-10 หลัก)',
                hint: 'เลือกหน่วยงานแล้วระบบเติมรหัสหน่วยงานให้',
                helper:
                    'ปกติใช้รหัสหน่วยงาน แก้เองได้สำหรับบัญชีพิเศษที่ไม่ตรงกับรหัสหน่วยงาน',
                // พิมพ์เอง = ไม่เติมทับ ลบจนว่าง = กลับไปเติมตามหน่วยงาน
                onChanged: (v) => _usernameTyped = v.trim().isNotEmpty,
                icon: Icons.badge_outlined,
                controller: _username,
                enabled: !_saving,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) =>
                    UserDialog.usernamePattern.hasMatch((v ?? '').trim())
                    ? null
                    : UserDialog.usernameRuleMessage,
              ),
              const SizedBox(height: 14),
            ],
            AccountField(
              key: UserDialog.fullNameKey,
              label: 'ชื่อที่แสดง (ชื่อหน่วยงานเจ้าของบัญชี)',
              icon: Icons.person_outline,
              controller: _fullName,
              enabled: !_saving,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              validator: (v) => (v ?? '').trim().length < 3
                  ? UserDialog.nameRuleMessage
                  : null,
            ),
            const SizedBox(height: 14),
            AccountField(
              key: UserDialog.emailKey,
              label: 'อีเมล (ไม่บังคับ)',
              icon: Icons.email_outlined,
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              // ไม่บังคับ ตรวจรูปแบบเฉพาะเมื่อกรอก
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                    ? null
                    : 'รูปแบบอีเมลไม่ถูกต้อง';
              },
            ),
            const SizedBox(height: 18),
            if (_divs == null)
              const LinearProgressIndicator()
            else
              DivDropdown(
                divs: _divs!,
                value: _div,
                enabled: !_saving,
                errorText: _divError,
                onChanged: _onDivChanged,
              ),
            const SizedBox(height: 16),
            const Text('บทบาท', style: label),
            const SizedBox(height: 6),
            if (_allRoles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final r in _allRoles)
                    FilterChip(
                      key: UserDialog.roleKey(r['code']!),
                      label: Text(Roles.nameOf(r['code']!), style: small),
                      // ชี้แล้วเห็นรหัสบทบาทและคำอธิบายเต็มจาก backend
                      tooltip: '${r['code']}: ${r['name']}',
                      selected: _roles.contains(r['code']),
                      onSelected: _saving
                          ? null
                          : (v) => setState(() {
                              v
                                  ? _roles.add(r['code']!)
                                  : _roles.remove(r['code']);
                            }),
                    ),
                ],
              ),
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              PasswordField(
                key: UserDialog.passwordKey,
                label: 'รหัสผ่านตั้งต้น',
                hint: 'กรอกรหัสผ่านตั้งต้น',
                controller: _password,
                enabled: !_saving,
                onChanged: (_) => setState(() {}),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'กรุณากรอกรหัสผ่านตั้งต้น'
                    : null,
              ),
              const SizedBox(height: 12),
              PasswordRuleList(rules: PasswordRules.of(_password.text)),
            ],
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                key: UserDialog.activeKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('เปิดใช้งานบัญชี', style: label),
                subtitle: Text(
                  _active
                      ? 'ใช้งานได้ตามปกติ'
                      : 'ระงับแล้ว เข้าสู่ระบบไม่ได้ และถูกออกจากระบบทันทีเมื่อบันทึก',
                  style: small,
                ),
                value: _active,
                activeThumbColor: AppTheme.successColor,
                onChanged: _saving ? null : (v) => setState(() => _active = v),
              ),
              if (widget.user!.locked)
                SwitchListTile(
                  key: UserDialog.lockedKey,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('บัญชีถูกล็อก', style: label),
                  subtitle: const Text(
                    'ล็อกจากการใส่รหัสผ่านผิดหลายครั้ง ปิดสวิตช์นี้เพื่อปลดล็อก',
                    style: small,
                  ),
                  value: _locked,
                  activeThumbColor: AppTheme.warningColor,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _locked = v),
                ),
            ],
            const SizedBox(height: 22),
            AccountActionButtons(
              confirmText: 'บันทึก',
              confirmIcon: Icons.save_outlined,
              loading: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _save,
            ),
          ],
        ),
      ),
    );
  }
}
