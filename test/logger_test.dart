// เทสต์ AppLogger.redact — ด่านที่กัน access_token / refresh_token / password
// ไม่ให้หลุดลง log ของ endpoint auth
//
// หมายเหตุ: flutter test รันในโหมด debug เสมอ (kDebugMode == true)
// redact จึงทำงานจริงในเทสต์ ส่วนใน release build จะคืน null

import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/utils/logger.dart';

void main() {
  group('AppLogger.redact', () {
    test('ปิดบัง access_token และ refresh_token ใน response ของ login', () {
      final response = {
        'access_token': 'fake-access-token-value',
        'refresh_token': 'fake-refresh-token-value',
        'username': 'somchai',
        'full_name': 'สมชาย ทดสอบ',
        'roles': ['ADMIN'],
      };

      final out = AppLogger.redact(response) as Map;

      expect(out['access_token'], '***REDACTED***');
      expect(out['refresh_token'], '***REDACTED***');

      // ข้อมูลที่ไม่อ่อนไหวต้องอ่านได้เหมือนเดิม
      expect(out['username'], 'somchai');
      expect(out['full_name'], 'สมชาย ทดสอบ');
      expect(out['roles'], ['ADMIN']);
    });

    test('ปิดบัง password ทุกรูปแบบ', () {
      final out =
          AppLogger.redact({
                'password': 'p@ssw0rd',
                'oldPassword': 'old',
                'newPassword': 'new',
                'secret': 's',
                'apiKey': 'k',
                'Authorization': 'Bearer abc',
              })
              as Map;

      for (final key in out.keys) {
        expect(out[key], '***REDACTED***', reason: 'คีย์ $key ต้องถูกปิดบัง');
      }
    });

    test('ปิดบัง token ที่ซ้อนอยู่ใน map ชั้นใน', () {
      final out =
          AppLogger.redact({
                'status': 'ok',
                'data': {
                  'user': {'username': 'somchai', 'token': 'nested-secret'},
                },
              })
              as Map;

      final data = out['data'] as Map;
      final user = data['user'] as Map;

      expect(out['status'], 'ok');
      expect(user['username'], 'somchai');
      expect(user['token'], '***REDACTED***');
    });

    test('ปิดบัง token ที่อยู่ใน list', () {
      final out =
          AppLogger.redact({
                'sessions': [
                  {'id': 1, 'access_token': 'a'},
                  {'id': 2, 'access_token': 'b'},
                ],
              })
              as Map;

      final sessions = out['sessions'] as List;

      expect((sessions[0] as Map)['id'], 1);
      expect((sessions[0] as Map)['access_token'], '***REDACTED***');
      expect((sessions[1] as Map)['access_token'], '***REDACTED***');
    });

    test('ค่าที่ไม่ใช่ map/list ส่งกลับตามเดิม', () {
      expect(AppLogger.redact('ข้อความธรรมดา'), 'ข้อความธรรมดา');
      expect(AppLogger.redact(42), 42);
      expect(AppLogger.redact(null), null);
    });

    test('map ที่ไม่มีคีย์อ่อนไหว ไม่ถูกแตะต้อง', () {
      final out = AppLogger.redact({'itemId': 12, 'name': 'รายการ A'}) as Map;

      expect(out['itemId'], 12);
      expect(out['name'], 'รายการ A');
    });
  });

  group('AppLogger.on', () {
    test('เปิดอยู่ตอนรันเทสต์ (debug mode)', () {
      // ถ้าข้อนี้ fail แปลว่าเทสต์ถูกรันในโหมด release
      // ซึ่ง redact จะคืน null และเทสต์ข้างบนจะไม่มีความหมาย
      expect(AppLogger.on, isTrue);
    });
  });
}
