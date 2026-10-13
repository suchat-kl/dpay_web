// กติการหัสผ่านต้องตรงกับ backend (PasswordPolicy.validateStrength):
// 8-72 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก ตัวเลข และอักขระพิเศษ (ตัวใดก็ได้ที่ไม่ใช่ A-Z a-z 0-9)
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/widgets/account_form.dart';

import 'fake_backend.dart';

void main() {
  test('อักขระพิเศษ = ตัวใดก็ได้ที่ไม่ใช่ตัวอักษรอังกฤษหรือตัวเลข', () {
    const special = r'''!@#$%^&*()_+-=[]{};':"\|,.<>/?~` ''';
    for (final c in special.split('')) {
      expect(PasswordRules.of('Abcdefg1$c').allPassed, isTrue, reason: c);
    }
    // อักษรไทยก็นับเป็นอักขระพิเศษตามนิยามของ backend
    expect(PasswordRules.of('Abcdefg1ก').hasSpecialChar, isTrue);
    expect(PasswordRules.of('Abcdefg12').hasSpecialChar, isFalse);
  });

  test('แต่ละเงื่อนไขและคะแนน', () {
    final weak = PasswordRules.of('abc');
    expect(weak.hasMinLength, isFalse);
    expect(weak.hasLowercase, isTrue);
    expect(weak.hasUppercase, isFalse);
    expect(weak.hasDigit, isFalse);
    expect(weak.hasSpecialChar, isFalse);
    expect(weak.score, 1);
    expect(weak.allPassed, isFalse);

    expect(PasswordRules.of('Abcdef1!').allPassed, isTrue);
    expect(PasswordRules.of('Abcde1!').allPassed, isFalse); // 7 ตัว
    expect(PasswordRules.of('abcdef1!').allPassed, isFalse);
    expect(PasswordRules.of('ABCDEF1!').allPassed, isFalse);
    expect(PasswordRules.of('Abcdefg!').allPassed, isFalse);
  });

  test('ยาวได้ไม่เกิน 72 ตัว', () {
    final ok = 'Aa1!${'x' * 68}';
    final tooLong = '${ok}x';
    expect(ok.length, PasswordRules.maxLength);
    expect(PasswordRules.of(ok).allPassed, isTrue);
    expect(PasswordRules.of(tooLong).withinMaxLength, isFalse);
    expect(PasswordRules.of(tooLong).allPassed, isFalse);
  });

  test('ผลตรงกับตัวตรวจของ backend จำลองทุกกรณี', () {
    for (final p in [
      '',
      'short1!',
      'Abcdef1!',
      'abcdef1!',
      'ABCDEF1!',
      'Abcdefgh',
      'Abcdefg1',
      'Abcdefg1 ',
      'Aa1!${'x' * 68}',
      'Aa1!${'x' * 69}',
      FakeBackend.passwordOf('901'),
    ]) {
      expect(
        PasswordRules.of(p).allPassed,
        FakeBackend.passwordProblem(p) == null,
        reason: 'รหัสผ่านยาว ${p.length} ตัว',
      );
    }
  });
}
