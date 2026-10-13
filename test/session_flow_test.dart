// เทสต์ session ทั้งเส้น ใช้ backend จำลอง (HttpClientAdapter) กับ ApiService / AuthInterceptor ตัวจริง
//
//   เข้าสู่ระบบ -> ข้อมูลผู้ใช้/บทบาท/ขอบเขตหน่วยงาน -> เจอ 401 แล้วต่ออายุ token (ใช้ครั้งเดียว หมุนตัวใหม่) และยิงซ้ำ
//   -> ข้อผิดพลาดตาม code -> บังคับเปลี่ยนรหัสผ่าน -> ต่ออายุไม่ได้ / ออกจากระบบ แล้วกลับหน้าแรก

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/main.dart';
import 'package:dpay/models/div_dept.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/cgd_files_screen.dart';
import 'package:dpay/screens/chapana_import_screen.dart';
import 'package:dpay/screens/loan_check_screen.dart';
import 'package:dpay/screens/report_screen.dart';
import 'package:dpay/screens/saha_import_screen.dart';
import 'package:dpay/screens/coming_soon_screen.dart';
import 'package:dpay/screens/div_status_screen.dart';
import 'package:dpay/screens/debt_entry_screen.dart';
import 'package:dpay/screens/deduct_screen.dart';
import 'package:dpay/screens/loan_screen.dart';
import 'package:dpay/screens/master_screen.dart';
import 'package:dpay/screens/period_jobs_screen.dart';
import 'package:dpay/screens/home_screen.dart';
import 'package:dpay/screens/period_screen.dart';
import 'package:dpay/screens/user_list_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/services/auth_interceptor.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/change_password_dialog.dart';
import 'package:dpay/widgets/login_dialog.dart';
import 'package:dpay/widgets/sidebar_menu.dart';
import 'package:universal_html/html.dart' as html;

import 'fake_backend.dart';

Finder _inMenu(String text) =>
    find.descendant(of: find.byType(SidebarMenu), matching: find.text(text));

String _pass(String username) => FakeBackend.passwordOf(username);

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();
  final settings = SettingsProvider();

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
  });

  tearDown(() async {
    await auth.logout();
  });

  Future<void> signIn(String username) => auth.login(username, _pass(username));

  group('session (ไม่ผ่านหน้าจอ)', () {
    test(
      'เข้าสู่ระบบ: เก็บ token และข้อมูลผู้ใช้จากผล login ใช้คำขอเดียว',
      () async {
        await signIn(FakeBackend.user);

        expect(auth.isLoggedIn, isTrue);
        expect(auth.username, '901');
        expect(auth.displayName, 'หน่วยงานตัวอย่างที่ 1');
        expect(auth.div, '901');
        expect(auth.divName, 'หน่วยงานตัวอย่างที่ 1');
        expect(auth.divLabel, '901 หน่วยงานตัวอย่างที่ 1');
        expect(auth.roles, ['USER']);
        expect(auth.divScope, DivScope.own);
        expect(auth.mustChangePassword, isFalse);
        expect(
          await api.storage.read(key: ApiService.accessTokenKey),
          isNotNull,
        );
        expect(
          await api.storage.read(key: ApiService.refreshTokenKey),
          isNotNull,
        );
        // ตัวข้อมูลของ login มีแค่ชื่อผู้ใช้กับรหัสผ่าน และไม่แนบ token
        expect(backend.calls, ['POST /api/auth/login']);
        expect(backend.bodyOf('POST /api/auth/login'), {
          'username': '901',
          'password': _pass('901'),
        });
        expect(backend.authHeaders.single, isNull);
      },
    );

    test('บทบาททั้ง 6: หน้าจอที่เปิดได้ ขอบเขตหน่วยงาน และป้ายบทบาท', () async {
      // บัญชี -> (หน้าจอที่เปิดได้, ขอบเขต, ป้ายบทบาท)
      final cases = {
        FakeBackend.user: (<String>[], DivScope.own, 'หน่วยงาน'),
        FakeBackend.account: (
          [Perm.period, Perm.alertMessage, Perm.editWindow],
          DivScope.all,
          'ฝ่ายบัญชี',
        ),
        FakeBackend.resetPwd: (
          [Perm.userResetPassword],
          DivScope.own,
          'กำหนดรหัสผ่าน',
        ),
        FakeBackend.centerDept: (<String>[], DivScope.center, 'หน่วยงาน'),
        FakeBackend.allDept: (<String>[], DivScope.all, 'หน่วยงาน'),
        FakeBackend.admin: (
          [Perm.userResetPassword, Perm.userManage],
          DivScope.own,
          'ผู้ดูแลระบบ',
        ),
      };
      const screens = [
        Perm.period,
        Perm.alertMessage,
        Perm.editWindow,
        Perm.userResetPassword,
        Perm.userManage,
      ];
      for (final e in cases.entries) {
        await signIn(e.key);
        for (final code in screens) {
          expect(
            auth.canView(code),
            e.value.$1.contains(code),
            reason: 'บัญชี ${e.key} หน้าจอ $code',
          );
        }
        expect(auth.divScope, e.value.$2, reason: e.key);
        expect(auth.highestRole, e.value.$3, reason: e.key);
        await auth.logout();
      }
    });

    test('ชื่อบทบาทไทย และลำดับการแสดงบทบาทที่ถือ', () async {
      expect(AuthProvider.roleName('USER'), 'หน่วยงาน');
      expect(AuthProvider.roleName('ADMIN'), 'ผู้ดูแลระบบ');
      expect(AuthProvider.roleName('OTHER'), 'OTHER');

      // backend ส่ง [RESETPWD, ADMIN] แสดงตามลำดับมาตรฐาน
      await signIn(FakeBackend.admin);
      expect(auth.isAdmin, isTrue);
      expect(auth.isAccount, isFalse);
      expect(auth.roleDisplayNames, ['กำหนดรหัสผ่าน', 'ผู้ดูแลระบบ']);
      expect(auth.initials, 'ศ');
    });

    test('ข้อผิดพลาดตอนเข้าสู่ระบบแยกได้ด้วย code', () async {
      Future<ApiException> fail(String user, String pass) async {
        try {
          await auth.login(user, pass);
        } on ApiException catch (e) {
          return e;
        }
        throw StateError('ควรเข้าสู่ระบบไม่สำเร็จ');
      }

      final wrong = await fail(FakeBackend.user, 'wrong');
      expect(wrong.code, ErrorCodes.badCredentials);
      expect(wrong.statusCode, 401);
      expect(wrong.toString(), FakeBackend.badCredentialsMessage);

      final locked = await fail(
        FakeBackend.lockedUser,
        _pass(FakeBackend.lockedUser),
      );
      expect(locked.code, ErrorCodes.accountLocked);
      expect(locked.isAccountLocked, isTrue);
      expect(locked.toString(), FakeBackend.lockedMessage);

      final disabled = await fail(
        FakeBackend.disabledUser,
        _pass(FakeBackend.disabledUser),
      );
      expect(disabled.code, ErrorCodes.accountDisabled);
      expect(disabled.toString(), FakeBackend.disabledMessage);

      expect(auth.isLoggedIn, isFalse);
      expect(await api.storage.readAll(), isEmpty);
      // เข้าสู่ระบบไม่สำเร็จ (401) ไม่ทำให้ไปต่ออายุ token
      expect(backend.count('POST /api/auth/refresh-token'), 0);
    });

    test('ต่อเซิร์ฟเวอร์ไม่ได้: ข้อความภาษาไทย ไม่มี code', () async {
      backend.unreachable = true;
      await expectLater(
        signIn(FakeBackend.user),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.message,
                'message',
                contains('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้'),
              )
              .having((e) => e.code, 'code', isNull),
        ),
      );
      backend.unreachable = false;
    });

    test('เส้นที่ไม่แนบ token มีแค่ login กับ refresh-token', () {
      expect(AuthInterceptor.isPublicPath('/api/auth/login'), isTrue);
      expect(AuthInterceptor.isPublicPath('/api/auth/refresh-token'), isTrue);
      expect(AuthInterceptor.isPublicPath('/api/auth/me'), isFalse);
      expect(AuthInterceptor.isPublicPath('/api/auth/changepassword'), isFalse);
      expect(AuthInterceptor.isPublicPath('/api/admin/users'), isFalse);
      // PUT ของข้อความแจ้งต้องแนบ token จึงไม่อยู่ในรายการ (ฝั่งอ่านใช้ publicDio)
      expect(AuthInterceptor.isPublicPath('/api/alert-message'), isFalse);
    });

    test(
      'token ใช้ไม่ได้ (401 UNAUTHENTICATED): ต่ออายุครั้งเดียว ได้ token คู่ใหม่ แล้วยิงคำขอเดิมซ้ำ',
      () async {
        await signIn(FakeBackend.user);
        final oldAccess = await api.storage.read(
          key: ApiService.accessTokenKey,
        );
        final oldRefresh = await api.storage.read(
          key: ApiService.refreshTokenKey,
        );
        backend.clearLog();

        // backend ถือว่า token หมดอายุแล้ว ทั้งที่เวลาใน token ยังไม่ถึง
        backend.expireAccessTokens();
        final period = await api.getPeriod();

        expect(period.label, 'กรกฎาคม 2568');
        expect(backend.calls, [
          'GET /api/period', // ได้ 401
          'POST /api/auth/refresh-token',
          'GET /api/period', // ยิงซ้ำ ได้ 200
        ]);
        expect(backend.bodyOf('POST /api/auth/refresh-token'), {
          'refresh_token': oldRefresh,
        });
        final newAccess = await api.storage.read(
          key: ApiService.accessTokenKey,
        );
        final newRefresh = await api.storage.read(
          key: ApiService.refreshTokenKey,
        );
        expect(newAccess, isNot(oldAccess));
        expect(newRefresh, isNot(oldRefresh));
        // refresh token ใช้ได้ครั้งเดียว: ตัวเก่าถูกเผา เหลือตัวใหม่ตัวเดียว
        expect(backend.liveRefreshTokens, {newRefresh});
        expect(backend.authHeaders[0], 'Bearer $oldAccess');
        expect(
          backend.authHeaders[1],
          isNull,
          reason: 'refresh-token ไม่แนบ token',
        );
        expect(backend.authHeaders[2], 'Bearer $newAccess');
        expect(auth.isLoggedIn, isTrue);
      },
    );

    test('ต่ออายุซ้ำสองรอบ: แต่ละรอบใช้ refresh token ตัวล่าสุดเสมอ', () async {
      await signIn(FakeBackend.user);
      final first = await api.storage.read(key: ApiService.refreshTokenKey);

      await api.refreshToken();
      final second = await api.storage.read(key: ApiService.refreshTokenKey);
      await api.refreshToken();
      final third = await api.storage.read(key: ApiService.refreshTokenKey);

      expect({first, second, third}.length, 3);
      expect(backend.liveRefreshTokens, {third});
      expect(auth.isLoggedIn, isTrue);
      expect((await api.getPeriod()).isValid, isTrue);
    });

    test(
      'คำขอพร้อมกันหลายตัวเจอ 401: ต่ออายุ token ครั้งเดียว ทุกคำขอสำเร็จ',
      () async {
        await signIn(FakeBackend.user);
        backend.clearLog();
        backend.expireAccessTokens();

        final results = await Future.wait([
          api.getPeriod(),
          api.getEditWindow(),
          api.getDivs(),
        ]);

        expect(results, hasLength(3));
        expect(backend.count('POST /api/auth/refresh-token'), 1);
        expect(auth.isLoggedIn, isTrue);
      },
    );

    test(
      'token ใช้ไม่ได้และต่ออายุไม่ได้: ออกจากระบบและล้าง session',
      () async {
        await signIn(FakeBackend.account);
        var notified = 0;
        auth.addListener(() => notified++);

        backend.expireAccessTokens();
        backend.revokeRefreshTokens();
        await expectLater(api.getPeriod(), throwsA(isA<ApiException>()));

        expect(auth.isLoggedIn, isFalse);
        expect(auth.canView(Perm.period), isFalse);
        expect(await api.storage.readAll(), isEmpty);
        expect(notified, greaterThan(0));
      },
    );

    test(
      '403 ตาม code (บทบาทไม่พอ): ไม่ต่ออายุ token ไม่ถูกออกจากระบบ',
      () async {
        await signIn(FakeBackend.user);
        backend.clearLog();

        await expectLater(
          api.updateAlertMessage('ลองแก้'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', ErrorCodes.forbidden)
                .having((e) => e.statusCode, 'status', 403)
                .having(
                  (e) => e.toString(),
                  'message',
                  FakeBackend.forbiddenMessage,
                ),
          ),
        );

        expect(backend.calls, ['PUT /api/alert-message']);
        expect(auth.isLoggedIn, isTrue);
      },
    );

    test('ข้อผิดพลาดตาม code: DIV_FORBIDDEN, NOT_FOUND, BAD_REQUEST', () async {
      await signIn(FakeBackend.user);
      // หน่วยงานตัวเองดูได้ หน่วยงานอื่นไม่ได้
      final own = await api.getSuccessDept('901');
      expect(own.g, 'G000901');
      expect(own.e, 'E000901');
      expect(own.all, ['G000901', 'E000901']);
      await expectLater(
        api.getSuccessDept('902'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ErrorCodes.divForbidden)
              .having((e) => e.isDivForbidden, 'isDivForbidden', isTrue),
        ),
      );
      await auth.logout();

      await signIn(FakeBackend.admin);
      await expectLater(
        api.getAdminUser('ไม่มีรหัสนี้'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ErrorCodes.notFound)
              .having((e) => e.statusCode, 'status', 404),
        ),
      );
      await expectLater(
        api.resetUserPassword('u901', 'สั้น'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ErrorCodes.badRequest,
          ),
        ),
      );
      expect(auth.isLoggedIn, isTrue);
    });

    test('ApiException: ตัวช่วยแยกกรณีตาม code', () {
      const closed = ApiException(
        FakeBackend.editWindowClosedMessage,
        statusCode: 403,
        code: ErrorCodes.editWindowClosed,
      );
      expect(closed.isEditWindowClosed, isTrue);
      expect(closed.isDivForbidden, isFalse);
      expect(closed.toString(), FakeBackend.editWindowClosedMessage);
      expect(const ApiException('x').isEditWindowClosed, isFalse);
    });

    test(
      'ออกจากระบบ: แนบ access token ส่ง refresh token ให้ยกเลิก แล้วล้างข้อมูลผู้ใช้',
      () async {
        await signIn(FakeBackend.account);
        final access = await api.storage.read(key: ApiService.accessTokenKey);
        final refresh = await api.storage.read(key: ApiService.refreshTokenKey);
        expect(auth.canView(Perm.period), isTrue);

        await auth.logout();

        expect(backend.calls.last, 'POST /api/auth/logout');
        expect(backend.authHeaders.last, 'Bearer $access');
        expect(backend.bodyOf('POST /api/auth/logout'), {
          'refresh_token': refresh,
        });
        expect(backend.liveRefreshTokens, isEmpty);
        expect(auth.isLoggedIn, isFalse);
        expect(auth.username, isNull);
        expect(auth.div, isNull);
        expect(auth.roles, isEmpty);
        expect(auth.divScope, DivScope.own);
        expect(auth.canView(Perm.period), isFalse);
        expect(await api.storage.readAll(), isEmpty);
        // เปิดหน้าเว็บใหม่หลังออกจากระบบ ต้องไม่มี session ให้กู้
        expect(await AuthProvider().loadSession(), isFalse);
      },
    );

    test(
      'เปิดหน้าเว็บใหม่ทั้งที่ยังไม่ออกจากระบบ: กู้ session แล้วถามข้อมูลล่าสุดจาก /api/auth/me',
      () async {
        await signIn(FakeBackend.user);
        backend.clearLog();
        // ระหว่างนั้นผู้ดูแลเพิ่มบทบาทให้บัญชีนี้
        backend.users[FakeBackend.user]!.roles = ['USER', 'CENTER_DEPT'];

        final reopened = AuthProvider();
        expect(await reopened.loadSession(), isTrue);
        expect(backend.calls, ['GET /api/auth/me']);
        expect(reopened.username, '901');
        expect(reopened.roles, ['USER', 'CENTER_DEPT']);
        expect(reopened.divScope, DivScope.center);

        // ข้อมูลผู้ใช้ในที่เก็บเป็น JSON ไม่มี token หรือรหัสผ่านปนอยู่
        final stored = jsonDecode(
          (await api.storage.read(key: ApiService.userDataKey))!,
        );
        expect(stored, {
          'username': '901',
          'full_name': 'หน่วยงานตัวอย่างที่ 1',
          'div': '901',
          'div_name': 'หน่วยงานตัวอย่างที่ 1',
          'roles': ['USER', 'CENTER_DEPT'],
          'div_scope': 'CENTER',
        });
      },
    );

    test(
      'กู้ session ตอนต่อ backend ไม่ได้: ใช้ข้อมูลที่เก็บไว้ ไม่ถูกออกจากระบบ',
      () async {
        await signIn(FakeBackend.account);
        backend.unreachable = true;

        final reopened = AuthProvider();
        expect(await reopened.loadSession(), isTrue);
        expect(reopened.roles, ['ACCOUNT', 'ALL_DEPT']);
        expect(reopened.divScope, DivScope.all);
        backend.unreachable = false;
      },
    );

    test('ข้อมูล session ในที่เก็บเสียหาย: ไม่กู้ และไม่ล้ม', () async {
      await api.storage.write(key: ApiService.accessTokenKey, value: 'a.b.c');
      await api.storage.write(
        key: ApiService.userDataKey,
        value: 'ไม่ใช่ JSON',
      );

      expect(await AuthProvider().loadSession(), isFalse);
      expect(auth.isLoggedIn, isFalse);
      expect(backend.calls, isEmpty);
    });

    test(
      'ต้องเปลี่ยนรหัสผ่าน: เปิดหน้าจอใดไม่ได้ จำไว้ข้ามการเปิดหน้าใหม่ เปลี่ยนแล้วใช้งานได้',
      () async {
        await signIn(FakeBackend.newbie);
        expect(auth.mustChangePassword, isTrue);

        // backend ปิดทุกส่วนนอก /api/auth
        await expectLater(
          api.getPeriod(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ErrorCodes.passwordChangeRequired,
            ),
          ),
        );
        // ข้อความแจ้งเป็นเส้นสาธารณะ อ่านได้เสมอ
        expect(await api.getAlertMessage(), backend.alertMessage);

        final reopened = AuthProvider();
        expect(await reopened.loadSession(), isTrue);
        expect(reopened.mustChangePassword, isTrue);

        backend.clearLog();
        await api.changePassword(_pass(FakeBackend.newbie), 'Newpass@2569x');
        // ไม่ส่งชื่อผู้ใช้ backend รู้จาก token
        expect(backend.bodyOf('POST /api/auth/changepassword'), {
          'oldPassword': _pass(FakeBackend.newbie),
          'newPassword': 'Newpass@2569x',
        });
        expect(auth.mustChangePassword, isFalse);
        expect(
          await api.storage.read(key: ApiService.mustChangePasswordKey),
          isNull,
        );
        expect((await api.getPeriod()).label, 'กรกฎาคม 2568');
      },
    );

    test(
      'backend ตอบ 403 PASSWORD_CHANGE_REQUIRED ทั้งที่ login ไม่ได้บอก: ตั้งสถานะบังคับเปลี่ยนเอง',
      () async {
        backend.hideMustChangeInLogin = true;
        await signIn(FakeBackend.newbie);
        expect(auth.mustChangePassword, isFalse);
        var notified = 0;
        auth.addListener(() => notified++);

        await expectLater(api.getEditWindow(), throwsA(isA<ApiException>()));

        expect(auth.mustChangePassword, isTrue);
        expect(notified, greaterThan(0));
        expect(
          await api.storage.read(key: ApiService.mustChangePasswordKey),
          'true',
        );
        // ไม่ใช่เรื่อง token: ไม่ต่ออายุ ไม่ออกจากระบบ
        expect(backend.count('POST /api/auth/refresh-token'), 0);
        expect(auth.isLoggedIn, isTrue);
      },
    );

    test(
      'SettingsProvider: งวด ระยะเวลาแก้ไข และ can_edit_now ตามบัญชี',
      () async {
        // ข้อความแจ้งโหลดได้โดยไม่ต้องเข้าสู่ระบบ
        await settings.loadAlertMessage();
        expect(settings.alertMessage, backend.alertMessage);
        expect(backend.authHeaders.last, isNull);
        expect(settings.period, isNull);
        expect(settings.canEditNow, isFalse);

        await signIn(FakeBackend.user);
        await settings.load();
        expect(settings.error, isNull);
        expect(settings.period!.label, 'กรกฎาคม 2568');
        expect(settings.editWindow!.open, isTrue);
        expect(settings.canEditNow, isTrue);

        // เลยช่วงแล้ว: หน่วยงานแก้ไม่ได้
        backend.serverTime = DateTime(2025, 7, 3, 11, 1);
        await settings.load();
        expect(settings.editWindow!.open, isFalse);
        expect(settings.canEditNow, isFalse);

        // นาทีสุดท้ายของช่วงยังเปิด (รวมปลาย)
        backend.serverTime = DateTime(2025, 7, 3, 11, 0);
        await settings.load();
        expect(settings.canEditNow, isTrue);

        // ออกจากระบบ: ทิ้งงวด/ระยะเวลา คงข้อความแจ้ง
        await auth.logout();
        settings.clear();
        expect(settings.period, isNull);
        expect(settings.editWindow, isNull);
        expect(settings.alertMessage, backend.alertMessage);

        // ฝ่ายบัญชีแก้ได้แม้ช่วงปิด
        backend.serverTime = DateTime(2025, 8, 1);
        await signIn(FakeBackend.account);
        await settings.load();
        expect(settings.editWindow!.open, isFalse);
        expect(settings.canEditNow, isTrue);
      },
    );

    test(
      'SettingsProvider: โหลดไม่สำเร็จเก็บข้อความไว้ที่ error ไม่โยน',
      () async {
        await signIn(FakeBackend.user);
        await settings.load();
        backend.unreachable = true;
        await settings.load();
        expect(settings.error, contains('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้'));
        // ค่าเดิมยังอยู่
        expect(settings.period, isNotNull);
        await settings.loadAlertMessage();
        expect(settings.alertError, isNotNull);
        backend.unreachable = false;
      },
    );
  });

  group('session (ผ่านหน้าจอ)', () {
    // [height] สูงพอให้เมนูของฝ่ายบัญชี (ยาวที่สุด) ถูกสร้างครบทุกรายการ
    Future<void> start(WidgetTester tester, {double height = 1000}) async {
      tester.view.physicalSize = Size(1400, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      html.window.localStorage.remove(AppConfig.menuPinnedStorageKey);
      await tester.pumpWidget(DpayApp(authProvider: auth));
      await tester.pumpAndSettle();
    }

    Future<void> login(WidgetTester tester, String user, [String? pass]) async {
      await tester.tap(find.widgetWithText(TextButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();
      final dialog = find.byType(LoginDialog);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อผู้ใช้'),
        user,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'รหัสผ่าน'),
        pass ?? _pass(user),
      );
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester) async {
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
    }

    /// รอแถบแจ้งผล (snackbar) หมดเวลา ไม่ให้บังปุ่มหรือค้าง timer
    Future<void> settleSnackBar(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('ยังไม่เข้าสู่ระบบ: เมนูมีแค่หน้าแรก', (tester) async {
      await start(tester);
      await openMenu(tester);

      expect(_inMenu('หน้าแรก'), findsOneWidget);
      expect(_inMenu(AppConfig.systemName), findsOneWidget);
      expect(_inMenu(AppConfig.organizationName), findsOneWidget);
      expect(_inMenu(SidebarMenu.periodGroupTitle), findsNothing);
      expect(_inMenu(SidebarMenu.userGroupTitle), findsNothing);
      expect(_inMenu(SidebarMenu.changePasswordTitle), findsNothing);
      expect(_inMenu(SidebarMenu.prepareSectionTitle), findsNothing);
      expect(_inMenu(SidebarMenu.workSectionTitle), findsNothing);
      expect(_inMenu(SidebarMenu.debtEntryTitle), findsNothing);
      expect(_inMenu(SidebarMenu.reportTitle), findsNothing);
    });

    // บัญชี -> เมนูที่ต้องเห็น (นอกจากหน้าแรกกับเปลี่ยนรหัสผ่านที่ทุกคนเห็น)
    const periodMenus = [
      PeriodScreen.menuTitle,
      'ข้อความแจ้งผู้ใช้งาน',
      'ระยะเวลาแก้ไขข้อมูล',
    ];
    // เมนูเตรียมข้อมูลของฝ่ายบัญชีตามโครงระบบเดิม (หัวข้อ กลุ่ม และรายการที่ยังรอ API)
    final accountUpcoming = [
      SidebarMenu.prepareSectionTitle,
      DpisImportScreen.menuTitle,
      PreparePeriodScreen.menuTitle,
      DivStatusScreen.menuTitle,
      SidebarMenu.masterGroupTitle,
      for (final r in SidebarMenu.masterResources) r.title,
      SidebarMenu.chapanaGroupTitle,
      ChapanaImportScreen.menuTitle,
      SahaImportScreen.menuTitle,
      SidebarMenu.chapanaSlipTitle,
      SidebarMenu.exportGroupTitle,
      LoanCheckScreen.syncMenuTitle,
      LoanCheckScreen.missingMenuTitle,
      CgdFilesScreen.menuTitle,
      BankReportScreen.menuTitle,
      SidebarMenu.bankGroupTitle,
      DeductScreen.menuTitle,
      LoanScreen.menuTitle,
    ];
    final menuCases = <String, (String, List<String>)>{
      FakeBackend.user: ('USER', []),
      FakeBackend.account: ('ACCOUNT', [...periodMenus, ...accountUpcoming]),
      FakeBackend.resetPwd: ('RESETPWD', [UserListScreen.resetTitle]),
      FakeBackend.centerDept: ('CENTER_DEPT', []),
      FakeBackend.allDept: ('ALL_DEPT', []),
      FakeBackend.admin: (
        'ADMIN',
        [UserListScreen.resetTitle, UserListScreen.manageTitle],
      ),
    };
    final roleMenus = [
      ...periodMenus,
      ...accountUpcoming,
      UserListScreen.resetTitle,
      UserListScreen.manageTitle,
    ];

    for (final e in menuCases.entries) {
      testWidgets('เมนูของบทบาท ${e.value.$1} (บัญชี ${e.key})', (
        tester,
      ) async {
        await start(tester, height: 2600);
        await login(tester, e.key);
        await openMenu(tester);

        // ทุกคนที่เข้าสู่ระบบ
        expect(_inMenu('หน้าแรก'), findsOneWidget);
        expect(_inMenu(SidebarMenu.userGroupTitle), findsOneWidget);
        expect(_inMenu(SidebarMenu.changePasswordTitle), findsOneWidget);
        // บันทึกข้อมูล / รายงาน ทุกบทบาทเห็น
        expect(_inMenu(SidebarMenu.workSectionTitle), findsOneWidget);
        expect(_inMenu(SidebarMenu.debtEntryTitle), findsOneWidget);
        expect(_inMenu(SidebarMenu.reportTitle), findsOneWidget);
        // เมนูที่ยกเลิกแล้วต้องไม่มี
        for (final cancelled in SidebarMenu.cancelledMenus) {
          expect(_inMenu(cancelled), findsNothing);
        }
        // กลุ่ม "สร้างไฟล์ส่งกรมบัญชีกลาง" ของระบบเดิมรวมเป็นหน้าดาวน์โหลดหน้าเดียวแล้ว
        expect(_inMenu('ไฟล์รวมจำนวนหนี้ คน'), findsNothing);

        for (final title in roleMenus) {
          expect(
            _inMenu(title),
            e.value.$2.contains(title) ? findsOneWidget : findsNothing,
            reason: 'เมนู "$title" ของบัญชี ${e.key}',
          );
        }
        expect(
          _inMenu(SidebarMenu.periodGroupTitle),
          e.key == FakeBackend.account ? findsOneWidget : findsNothing,
        );
        await settleSnackBar(tester);
      });
    }

    testWidgets(
      'เมนูของฝ่ายบัญชี: ทุกเมนูเปิดหน้าจอจริง เหลือ "รายงานฌาปนกิจ-สลิป" ที่ยังเป็นหน้า "กำลังพัฒนา" กลุ่มหุบ/ขยายได้',
      (tester) async {
        await start(tester, height: 2600);
        await login(tester, FakeBackend.account);
        await settleSnackBar(tester);
        await openMenu(tester);

        // กลุ่มข้อมูลงวดขยายไว้ให้ กลุ่มอื่นหุบไว้ กดหัวกลุ่มแล้วขยาย
        expect(_inMenu(PeriodScreen.menuTitle).hitTestable(), findsOneWidget);
        expect(_inMenu('รหัสหนี้').hitTestable(), findsNothing);
        await tester.tap(_inMenu(SidebarMenu.periodGroupTitle));
        await tester.pumpAndSettle();
        expect(_inMenu(PeriodScreen.menuTitle).hitTestable(), findsNothing);

        /// ขยายกลุ่ม [group] แล้วกดรายการ [item]
        Future<void> openItem(String group, String item) async {
          await openMenu(tester);
          await tester.tap(_inMenu(group));
          await tester.pumpAndSettle();
          await tester.tap(_inMenu(item).hitTestable());
          await tester.pumpAndSettle();
        }

        Future<void> close() async {
          await tester.tap(find.byTooltip('ปิด'));
          await tester.pumpAndSettle();
        }

        // ข้อมูลหลัก: หน้าจอจริง เรียก backend
        await openItem(SidebarMenu.masterGroupTitle, 'รหัสหนี้');
        expect(find.byType(MasterScreen), findsOneWidget);
        expect(backend.calls, contains('GET /api/master/debt-codes'));
        await close();

        // ทะเบียนธนาคาร: หน้าจอจริง
        await openItem(SidebarMenu.bankGroupTitle, LoanScreen.menuTitle);
        expect(find.byType(LoanScreen), findsOneWidget);
        await close();

        // เมนูเดียวที่ยังรอ API: หน้ากำลังพัฒนา ไม่เรียก backend
        backend.clearLog();
        await openItem(
          SidebarMenu.chapanaGroupTitle,
          SidebarMenu.chapanaSlipTitle,
        );
        final soon = tester.widget<ComingSoonScreen>(
          find.byType(ComingSoonScreen),
        );
        expect(soon.title, SidebarMenu.chapanaSlipTitle);
        expect(soon.group, SidebarMenu.chapanaGroupTitle);
        expect(find.text(ComingSoonScreen.heading), findsOneWidget);
        expect(find.text(ComingSoonScreen.message), findsOneWidget);
        expect(backend.calls, isEmpty);
        await close();

        // หน้าจอของระยะที่ 3: เปิดหน้าจอจริงและเรียก backend
        await openItem(
          SidebarMenu.chapanaGroupTitle,
          SahaImportScreen.menuTitle,
        );
        expect(find.byType(SahaImportScreen), findsOneWidget);
        expect(backend.calls, contains('GET /api/saha/summary'));
        await close();
        await openItem(
          SidebarMenu.chapanaGroupTitle,
          ChapanaImportScreen.menuTitle,
        );
        expect(find.byType(ChapanaImportScreen), findsOneWidget);
        expect(backend.calls, contains('GET /api/chapana/summary'));
        await close();
        await openItem(
          SidebarMenu.exportGroupTitle,
          LoanCheckScreen.missingMenuTitle,
        );
        expect(
          tester
              .widget<LoanCheckScreen>(find.byType(LoanCheckScreen))
              .missingFirst,
          isTrue,
        );
        expect(backend.calls, contains('GET /api/loans/missing-accounts'));
        await close();
        await openItem(SidebarMenu.exportGroupTitle, CgdFilesScreen.menuTitle);
        expect(find.byType(CgdFilesScreen), findsOneWidget);
        expect(backend.calls, contains('GET /api/cgd-files'));
        await close();
        await openItem(
          SidebarMenu.exportGroupTitle,
          BankReportScreen.menuTitle,
        );
        expect(find.byType(BankReportScreen), findsOneWidget);
        await close();
        await openMenu(tester);
        await tester.tap(_inMenu(SidebarMenu.reportTitle));
        await tester.pumpAndSettle();
        expect(find.byType(ReportScreen), findsOneWidget);
        expect(find.byType(ComingSoonScreen), findsNothing);
        await close();

        // บันทึกข้อมูล: หน้าจอจริง
        await openMenu(tester);
        await tester.tap(_inMenu(SidebarMenu.debtEntryTitle));
        await tester.pumpAndSettle();
        expect(find.byType(DebtEntryScreen), findsOneWidget);
        expect(backend.calls, contains('GET /api/debts'));
      },
    );

    testWidgets(
      'เมนูผู้ใช้บนแถบบน: ข้อมูลผู้ใช้ (หน่วยงาน บทบาท) และออกจากระบบ',
      (tester) async {
        await start(tester);
        await login(tester, FakeBackend.account);
        await settleSnackBar(tester);

        await tester.tap(find.byIcon(Icons.arrow_drop_down));
        await tester.pumpAndSettle();
        expect(find.text('ข้อมูลส่วนตัว'), findsOneWidget);
        expect(find.text('เปลี่ยนรหัสผ่าน'), findsOneWidget);

        await tester.tap(find.text('ข้อมูลส่วนตัว'));
        await tester.pumpAndSettle();
        expect(find.text('ผู้ใช้งาน: 902'), findsOneWidget);
        expect(find.text('หน่วยงาน: 902 กองบัญชีตัวอย่าง'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('เลือกหน่วยงานได้: ทุกหน่วยงาน'),
          ),
          findsOneWidget,
        );
        expect(find.text('บทบาท: ฝ่ายบัญชี, ทุกหน่วยงาน'), findsOneWidget);
        await tester.tap(find.text('ปิด'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_drop_down));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ออกจากระบบ'));
        await tester.pumpAndSettle();

        expect(auth.isLoggedIn, isFalse);
        expect(find.text('ออกจากระบบเรียบร้อย'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'เข้าสู่ระบบ'), findsOneWidget);
        // ออกจากระบบแล้วการ์ดสถานะหาย ค่าตั้งกลางถูกล้าง
        expect(find.byKey(HomeScreen.periodCardKey), findsNothing);
        expect(settings.period, isNull);
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'ออกจากระบบจากเมนู: เมนูของผู้เข้าสู่ระบบหาย ปุ่มเข้าสู่ระบบกลับมา',
      (tester) async {
        await start(tester);
        await login(tester, FakeBackend.admin);
        await settleSnackBar(tester);
        await openMenu(tester);
        expect(_inMenu(UserListScreen.manageTitle), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(SidebarMenu),
            // เมนูกว้างไม่เกิน 400 จุดใช้หัวเมนูแบบย่อ ปุ่มออกจากระบบเป็นไอคอน
            matching: find.byIcon(Icons.logout),
          ),
        );
        await tester.pumpAndSettle();

        expect(auth.isLoggedIn, isFalse);
        expect(backend.calls, contains('POST /api/auth/logout'));
        expect(await api.storage.readAll(), isEmpty);
        expect(find.widgetWithText(TextButton, 'เข้าสู่ระบบ'), findsOneWidget);
        expect(find.text(HomeScreen.loginPrompt), findsOneWidget);

        await openMenu(tester);
        expect(_inMenu(SidebarMenu.userGroupTitle), findsNothing);
        expect(_inMenu(UserListScreen.manageTitle), findsNothing);
      },
    );

    testWidgets(
      'session หมดอายุระหว่างอยู่ในหน้าจออื่น: ต่ออายุไม่ได้ ถูกออกจากระบบและกลับหน้าแรก',
      (tester) async {
        await start(tester);
        await login(tester, FakeBackend.admin);
        await settleSnackBar(tester);
        await openMenu(tester);
        await tester.tap(_inMenu(UserListScreen.manageTitle));
        await tester.pumpAndSettle();
        expect(find.byType(UserListScreen), findsOneWidget);

        backend.expireAccessTokens();
        backend.revokeRefreshTokens();
        // ค้นหา = ยิง backend -> token ใช้ไม่ได้ -> ต่ออายุไม่ได้
        await tester.enterText(find.widgetWithText(TextField, 'ค้นหา'), '91');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(auth.isLoggedIn, isFalse);
        expect(find.byType(UserListScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'เข้าสู่ระบบ'), findsOneWidget);
        expect(await api.storage.readAll(), isEmpty);
        // ให้ตัวหน่วงการค้นหาหมดเวลา ไม่ค้าง timer
        await settleSnackBar(tester);
      },
    );

    group('บังคับเปลี่ยนรหัสผ่าน', () {
      final dialog = find.byType(ChangePasswordDialog);
      Finder field(String hint) => find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextFormField, hint),
      );

      Future<void> waitForDialog(WidgetTester tester) async {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'login ตอบ must_change_password: เปิดหน้าต่างที่ปิดไม่ได้ กดออกจากระบบ = ออกจากระบบ',
        (tester) async {
          await start(tester);
          await login(tester, FakeBackend.newbie);
          await waitForDialog(tester);

          expect(dialog, findsOneWidget);
          expect(
            find.text(ChangePasswordDialog.forcedSubtitle),
            findsOneWidget,
          );
          // ยังไม่เปลี่ยนรหัสผ่าน: ไม่เรียกเส้นที่ backend จะตอบ 403
          expect(backend.calls, isNot(contains('GET /api/period')));
          expect(backend.calls, isNot(contains('GET /api/edit-window')));

          // กด Esc / แตะนอกหน้าต่าง ไม่ปิด
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(5, 500));
          await tester.pumpAndSettle();
          expect(dialog, findsOneWidget);
          expect(find.widgetWithText(OutlinedButton, 'ยกเลิก'), findsNothing);

          final leave = find.descendant(
            of: dialog,
            matching: find.widgetWithText(OutlinedButton, 'ออกจากระบบ'),
          );
          await tester.ensureVisible(leave);
          await tester.pumpAndSettle();
          await tester.tap(leave);
          await tester.pumpAndSettle();

          expect(auth.isLoggedIn, isFalse);
          expect(backend.calls, contains('POST /api/auth/logout'));
          expect(dialog, findsNothing);
          await settleSnackBar(tester);
        },
      );

      testWidgets(
        'เปลี่ยนรหัสผ่านสำเร็จ: หน้าต่างปิด ใช้งานต่อได้ และโหลดงวด/ระยะเวลาแก้ไขให้',
        (tester) async {
          await start(tester);
          await login(tester, FakeBackend.newbie);
          await waitForDialog(tester);
          expect(find.text(HomeScreen.mustChangeText), findsOneWidget);

          await tester.enterText(
            field(ChangePasswordDialog.oldHint),
            _pass(FakeBackend.newbie),
          );
          await tester.enterText(
            field(ChangePasswordDialog.newHint),
            'Newpass@2569x',
          );
          await tester.enterText(
            field(ChangePasswordDialog.confirmHint),
            'Newpass@2569x',
          );
          final save = find.descendant(
            of: dialog,
            matching: find.widgetWithText(
              ElevatedButton,
              ChangePasswordDialog.title,
            ),
          );
          await tester.ensureVisible(save);
          await tester.pumpAndSettle();
          await tester.tap(save);
          await tester.pumpAndSettle();

          expect(backend.bodyOf('POST /api/auth/changepassword'), {
            'oldPassword': _pass(FakeBackend.newbie),
            'newPassword': 'Newpass@2569x',
          });
          expect(dialog, findsNothing);
          expect(auth.isLoggedIn, isTrue);
          expect(auth.mustChangePassword, isFalse);
          expect(backend.calls, contains('GET /api/period'));
          expect(backend.calls, contains('GET /api/edit-window'));
          expect(find.text(HomeScreen.mustChangeText), findsNothing);
          expect(find.text('กรกฎาคม 2568'), findsOneWidget);
          await settleSnackBar(tester);
        },
      );

      testWidgets(
        'backend ตอบ PASSWORD_CHANGE_REQUIRED ระหว่างใช้งาน: เปิดหน้าต่างบังคับเปลี่ยนเอง',
        (tester) async {
          backend.hideMustChangeInLogin = true;
          await start(tester);
          await login(tester, FakeBackend.newbie);
          await waitForDialog(tester);

          // หน้าแรกโหลดงวด -> 403 PASSWORD_CHANGE_REQUIRED -> หน้าต่างบังคับเปลี่ยน
          expect(backend.calls, contains('GET /api/period'));
          expect(auth.mustChangePassword, isTrue);
          expect(dialog, findsOneWidget);
          expect(
            find.text(ChangePasswordDialog.forcedSubtitle),
            findsOneWidget,
          );
          await settleSnackBar(tester);
        },
      );

      testWidgets('เปิดหน้าเว็บใหม่ระหว่างที่ยังไม่เปลี่ยน: บังคับเปลี่ยนอีก', (
        tester,
      ) async {
        await tester.runAsync(() => signIn(FakeBackend.newbie));
        await start(tester);
        await waitForDialog(tester);

        expect(dialog, findsOneWidget);
      });
    });

    testWidgets(
      'ตรึงเมนู: จำไว้ในเบราว์เซอร์ด้วยคีย์ของระบบนี้ ยุบ/ขยายได้ และหน้าจอเปิดข้างเมนู',
      (tester) async {
        expect(AppConfig.menuPinnedStorageKey, 'dpay_menu_pinned');
        expect(AppConfig.themeStorageKey, 'dpay_theme');
        expect(AppConfig.secureStorageName, 'dpay_secure_storage');
        await start(tester);
        await login(tester, FakeBackend.admin);
        await settleSnackBar(tester);
        await openMenu(tester);
        await tester.tap(find.byTooltip(SidebarMenu.pinTooltip));
        await tester.pumpAndSettle();

        expect(html.window.localStorage[AppConfig.menuPinnedStorageKey], '1');
        // ตรึงแล้วเมนูอยู่ข้างจอแบบย่อเหลือไอคอน ไม่ใช่ drawer
        expect(find.byType(Drawer), findsNothing);
        expect(find.byType(SidebarMenu), findsOneWidget);
        expect(
          tester.getSize(find.byType(SidebarMenu)).width,
          SidebarMenu.railWidth,
        );
        expect(find.byTooltip('ขยายเมนู'), findsOneWidget);
        // ตอนยุบ กลุ่มที่ขยายได้เหลือไอคอนเดียว
        expect(find.byTooltip(SidebarMenu.userGroupTitle), findsOneWidget);
        expect(_inMenu(UserListScreen.manageTitle), findsNothing);

        await tester.tap(find.byTooltip('ขยายเมนู'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(SidebarMenu)).width,
          greaterThan(SidebarMenu.railWidth),
        );

        // เปิดหน้าจอจากเมนูที่ตรึง: เมนูยังอยู่ หน้าจอไปเปิดด้านขวา
        await tester.tap(_inMenu(UserListScreen.manageTitle));
        await tester.pumpAndSettle();
        expect(find.byType(UserListScreen), findsOneWidget);
        expect(find.byType(SidebarMenu), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(UserListScreen)).dx,
          tester.getSize(find.byType(SidebarMenu)).width,
        );

        // เปิดอีกหน้า: แทนหน้าเดิม ไม่ซ้อนกัน แล้วกลับหน้าแรกจากเมนู
        await tester.tap(_inMenu(UserListScreen.resetTitle));
        await tester.pumpAndSettle();
        expect(find.byType(UserListScreen), findsOneWidget);
        expect(
          tester.widget<UserListScreen>(find.byType(UserListScreen)).mode,
          UserListMode.resetPassword,
        );
        await tester.tap(_inMenu('หน้าแรก'));
        await tester.pumpAndSettle();
        expect(find.byType(UserListScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);

        await tester.tap(find.byTooltip(SidebarMenu.unpinTooltip));
        await tester.pumpAndSettle();
        expect(html.window.localStorage[AppConfig.menuPinnedStorageKey], '0');
        expect(find.byType(SidebarMenu), findsNothing);
      },
    );

    testWidgets('จอแคบ: ไม่มีปุ่มตรึงเมนู แม้เคยตรึงไว้ก็เป็นเมนูเลื่อนออก', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      html.window.localStorage[AppConfig.menuPinnedStorageKey] = '1';
      addTearDown(
        () => html.window.localStorage.remove(AppConfig.menuPinnedStorageKey),
      );
      await tester.pumpWidget(DpayApp(authProvider: auth));
      await tester.pumpAndSettle();

      expect(find.byType(SidebarMenu), findsNothing);
      await openMenu(tester);
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byTooltip(SidebarMenu.pinTooltip), findsNothing);
      expect(find.byTooltip(SidebarMenu.unpinTooltip), findsNothing);
    });
  });
}
