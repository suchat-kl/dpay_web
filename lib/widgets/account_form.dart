// ส่วนประกอบร่วมของหน้าต่างฟอร์ม (dialog เพิ่ม/แก้ไขข้อมูล และหน้าต่างเกี่ยวกับบัญชี)
// หน้าตาเดียวกับหน้าเปลี่ยนรหัสผ่าน: โครงหน้าต่าง แถบข้อความ ช่องกรอก ปุ่มคู่ท้ายหน้าต่าง กติการหัสผ่าน
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

/// ฟอนต์ของหน้าต่างชุดนี้ ระบุชัดทุกจุดตามข้อกำหนดฟอนต์ไทยของโปรเจกต์
const String kAccountFont = 'NotoSansThai';

/// ผลตรวจรหัสผ่านตามเงื่อนไขของระบบ — กติกากลาง ตรงกับ `PasswordPolicy.validateStrength` ของ backend
///
/// 8-72 ตัวอักษร มีพิมพ์ใหญ่ (A-Z) พิมพ์เล็ก (a-z) ตัวเลข และอักขระพิเศษอย่างน้อยอย่างละ 1 ตัว
/// ทุกหน้าที่ตั้งรหัสผ่าน (เปลี่ยนรหัสผ่าน กำหนดรหัสผ่านใหม่ สร้างผู้ใช้) ใช้คลาสนี้กับ [PasswordRuleList]
/// ถ้า backend แก้กติกาให้แก้ที่นี่ที่เดียว
class PasswordRules {
  final bool hasMinLength;

  /// ยาวไม่เกิน [maxLength] (BCrypt ใช้แค่ 72 ไบต์แรก)
  final bool withinMaxLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;

  static const int minLength = 8;
  static const int maxLength = 72;

  /// อักขระพิเศษ = ตัวใดก็ได้ที่ไม่ใช่ A-Z a-z 0-9 (นิยามเดียวกับ backend: `[^A-Za-z0-9]`)
  static final RegExp specialChar = RegExp(r'[^A-Za-z0-9]');

  const PasswordRules._({
    required this.hasMinLength,
    required this.withinMaxLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  factory PasswordRules.of(String password) => PasswordRules._(
    hasMinLength: password.length >= minLength,
    withinMaxLength: password.length <= maxLength,
    hasUppercase: password.contains(RegExp(r'[A-Z]')),
    hasLowercase: password.contains(RegExp(r'[a-z]')),
    hasDigit: password.contains(RegExp(r'\d')),
    hasSpecialChar: password.contains(specialChar),
  );

  /// จำนวนเงื่อนไขที่ผ่าน (0-5) ไม่นับความยาวสูงสุด
  int get score =>
      (hasMinLength ? 1 : 0) +
      (hasUppercase ? 1 : 0) +
      (hasLowercase ? 1 : 0) +
      (hasDigit ? 1 : 0) +
      (hasSpecialChar ? 1 : 0);

  bool get allPassed => score == 5 && withinMaxLength;

  /// ข้อความเมื่อรหัสผ่านยังไม่ครบเงื่อนไข
  static const String notMetMessage =
      'กรุณาตั้งรหัสผ่านให้ตรงตามเงื่อนไขที่กำหนด';

  /// ข้อความเมื่อรหัสผ่านยาวเกิน
  static const String tooLongMessage =
      'รหัสผ่านต้องยาวไม่เกิน $maxLength ตัวอักษร';
}

/// กล่องเงื่อนไขการตั้งรหัสผ่าน ติ๊กถูกทีละข้อตามที่ผู้ใช้พิมพ์
class PasswordRuleList extends StatelessWidget {
  final PasswordRules rules;

  const PasswordRuleList({super.key, required this.rules});

  static const String title = 'เงื่อนไขการตั้งรหัสผ่าน';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    Widget item(String text, bool ok) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: isDesktop ? 18 : 16,
            color: ok ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: kAccountFont,
                fontSize: isDesktop ? 13 : 12,
                color: ok ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: kAccountFont,
              fontSize: isDesktop ? 14 : 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          item(
            'ยาว ${PasswordRules.minLength}-${PasswordRules.maxLength} ตัวอักษร',
            rules.hasMinLength && rules.withinMaxLength,
          ),
          item('มีตัวอักษรพิมพ์ใหญ่อย่างน้อย 1 ตัว (A-Z)', rules.hasUppercase),
          item('มีตัวอักษรพิมพ์เล็กอย่างน้อย 1 ตัว (a-z)', rules.hasLowercase),
          item('มีตัวเลขอย่างน้อย 1 ตัว (0-9)', rules.hasDigit),
          item(
            'มีอักขระพิเศษอย่างน้อย 1 ตัว (เช่น ! @ # \$ % - _)',
            rules.hasSpecialChar,
          ),
        ],
      ),
    );
  }
}

/// ช่องรหัสผ่านพร้อมปุ่มแสดง/ซ่อน ใช้ [AccountField] เป็นฐาน
class PasswordField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool enabled;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const PasswordField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.enabled = true,
    this.icon = Icons.lock_outline,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AccountField(
      label: widget.label,
      hint: widget.hint,
      icon: widget.icon,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      suffix: IconButton(
        tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
        icon: Icon(
          _obscure ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

/// โครงหน้าต่าง: หัวไล่สี (ไอคอน + ชื่อ + คำอธิบาย) กับเนื้อหาที่เลื่อนได้
class AccountDialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  /// แสดงปุ่มกากบาทปิดที่มุมหัว (null = ไม่มีปุ่ม)
  final VoidCallback? onClose;

  const AccountDialogShell({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 600 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxWidth: 650),
        // ตัดเนื้อหาตามมุมโค้งของหน้าต่าง กันส่วนที่เลื่อนโผล่ทับแถบหัว
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
                vertical: isDesktop ? 16 : 12,
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
              child: Row(
                children: [
                  Container(
                    width: isDesktop ? 45 : 38,
                    height: isDesktop ? 45 : 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: AppTheme.primaryColor,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: kAccountFont,
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: kAccountFont,
                            fontSize: isDesktop ? 12 : 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: 'ปิด',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
            Flexible(
              // สวิตช์/ป้ายเลือก/ปุ่มไอคอนวาดคลื่นตอนกดบน Material ที่ใกล้ที่สุด ต้องมี Material อยู่ในกรอบสีขาวนี้
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 28 : 20),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// แถบข้อความในหน้าต่าง แดง = ข้อผิดพลาด, เขียว = สำเร็จ, ฟ้า = คำอธิบาย
class AccountBanner extends StatelessWidget {
  final String message;
  final MaterialColor color;
  final IconData icon;

  /// ปุ่มกากบาทปิดแถบ (null = ไม่มีปุ่ม)
  final VoidCallback? onClose;

  const AccountBanner.error(this.message, {super.key, this.onClose})
    : color = Colors.red,
      icon = Icons.error_outline;

  const AccountBanner.success(this.message, {super.key, this.onClose})
    : color = Colors.green,
      icon = Icons.check_circle_outline;

  const AccountBanner.info(this.message, {super.key, this.onClose})
    : color = Colors.blue,
      icon = Icons.info_outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: kAccountFont,
                color: color.shade700,
                fontSize: 13,
              ),
            ),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close, color: color.shade700, size: 18),
            ),
        ],
      ),
    );
  }
}

/// ช่องกรอกพร้อมป้ายชื่อด้านบน รูปแบบเดียวกันทุกช่อง
class AccountField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;

  /// อ่านอย่างเดียว พื้นเทา (ค่ายังเลือกคัดลอกได้)
  final bool readOnly;
  final bool obscureText;
  final Widget? suffix;
  final String? helper;

  /// ข้อความผิดพลาดจาก backend ของช่องนี้ แสดงใต้ช่องแบบเดียวกับผลของ [validator]
  /// (validator ไม่ผ่านจะแสดงข้อความของ validator แทน) ผู้เรียกล้างเองเมื่อผู้ใช้แก้ค่า
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  /// ใช้เมื่อช่องนี้อยู่ใน autocomplete ซึ่งต้องคุมโฟกัสและปุ่ม Enter เอง
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  const AccountField({
    super.key,
    required this.label,
    this.hint,
    required this.icon,
    required this.controller,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.suffix,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    // ช่องที่เปิดตัวเลือก (onTap) อ่านอย่างเดียวแต่ยังใช้งานได้ จึงไม่ทำพื้นเทา
    final greyed = readOnly && onTap == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: kAccountFont,
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: kAccountFont),
            errorStyle: const TextStyle(fontFamily: kAccountFont),
            errorText: errorText,
            errorMaxLines: 3,
            prefixIcon: Icon(icon, color: greyed ? Colors.grey : null),
            suffixIcon: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: greyed ? Colors.grey.shade300 : AppTheme.primaryColor,
                width: greyed ? 1 : 2,
              ),
            ),
            filled: true,
            fillColor: greyed ? Colors.grey.shade100 : AppTheme.fieldFillColor,
          ),
          style: TextStyle(
            fontFamily: kAccountFont,
            fontSize: isDesktop ? 16 : 14,
            color: greyed ? Colors.grey.shade700 : AppTheme.textPrimary,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: TextStyle(
              fontFamily: kAccountFont,
              fontSize: isDesktop ? 12 : 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// ปุ่มคู่ท้ายหน้าต่าง: ยกเลิก (ซ้าย) กับปุ่มหลัก (ขวา หมุนรอระหว่างทำงาน)
class AccountActionButtons extends StatelessWidget {
  final String cancelText;
  final String confirmText;
  final IconData confirmIcon;
  final bool loading;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  const AccountActionButtons({
    super.key,
    this.cancelText = 'ยกเลิก',
    required this.confirmText,
    this.confirmIcon = Icons.check,
    this.loading = false,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final height = isDesktop ? 50.0 : 44.0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: OutlinedButton(
              onPressed: loading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cancelColor,
                side: const BorderSide(color: AppTheme.cancelColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                cancelText,
                style: TextStyle(
                  fontFamily: kAccountFont,
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: height,
            child: ElevatedButton(
              onPressed: loading ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: loading
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
                        Icon(confirmIcon, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            confirmText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: kAccountFont,
                              fontSize: isDesktop ? 16 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
