// เทสต์การเปลี่ยนธีม: ชุดสี 6 ธีม ปุ่มจานสีที่แถบบน และการจำค่าในเบราว์เซอร์

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/main.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/widgets/header.dart';
import 'package:dpay/widgets/login_dialog.dart';
import 'package:universal_html/html.dart' as html;

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late AuthProvider auth;

  setUp(() async {
    await installFakeBackend();
    auth = AuthProvider();
    html.window.localStorage.remove(AppTheme.storageKey);
    AppTheme.select(null);
  });

  tearDown(() async {
    await auth.logout();
    // คืนธีมตั้งต้น ไม่ให้ค้างไปเทสต์อื่น (สีของ AppTheme เป็นค่า static)
    AppTheme.select(null);
    html.window.localStorage.remove(AppTheme.storageKey);
  });

  group('AppTheme (ไม่ผ่านหน้าจอ)', () {
    test('มี 6 ธีม รหัสไม่ซ้ำ ธีมแรกเป็นค่าตั้งต้น', () {
      expect(AppTheme.palettes.length, 6);
      expect(AppTheme.palettes.map((p) => p.id).toSet().length, 6);
      expect(AppTheme.current.id, AppTheme.palettes.first.id);
      expect(AppTheme.storageKey, 'dpay_theme');
      expect(AppTheme.storageKey, AppConfig.themeStorageKey);
    });

    test('select เปลี่ยนสีหลักและแจ้งผู้ฟัง รหัสที่ไม่รู้จักกลับไปธีมแรก', () {
      final first = AppTheme.palettes.first;
      final mint = AppTheme.palettes.firstWhere((p) => p.id == 'mint');
      var notified = 0;
      void listener() => notified++;
      AppTheme.themeId.addListener(listener);
      addTearDown(() => AppTheme.themeId.removeListener(listener));

      AppTheme.select('mint');
      expect(AppTheme.current.id, 'mint');
      expect(AppTheme.primaryColor, mint.primary);
      expect(AppTheme.backgroundColor, mint.background);
      expect(AppTheme.lightTheme.colorScheme.primary, mint.primary);
      expect(notified, 1);

      AppTheme.select('ไม่มีธีมนี้');
      expect(AppTheme.current.id, first.id);
      expect(AppTheme.primaryColor, first.primary);
      expect(notified, 2);
    });
  });

  group('ปุ่มจานสีที่แถบบน', () {
    Future<void> start(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(DpayApp(authProvider: auth));
      await tester.pumpAndSettle();
    }

    Color appBarColor(WidgetTester tester) =>
        tester.widget<AppBar>(find.byType(AppBar).first).backgroundColor!;

    testWidgets('เลือกธีม: สีแถบบนเปลี่ยนทันที และจำลง localStorage', (
      tester,
    ) async {
      await start(tester);
      final first = AppTheme.palettes.first;
      final rose = AppTheme.palettes.firstWhere((p) => p.id == 'rose');
      expect(appBarColor(tester), first.primary);

      await tester.tap(find.byTooltip(CustomHeader.themeButtonTooltip));
      await tester.pumpAndSettle();
      // รายการครบทุกธีม ธีมที่ใช้อยู่มีเครื่องหมายถูก
      for (final p in AppTheme.palettes) {
        expect(find.text(p.name), findsOneWidget);
      }
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text(rose.name));
      await tester.pumpAndSettle();

      expect(AppTheme.current.id, 'rose');
      expect(appBarColor(tester), rose.primary);
      expect(html.window.localStorage[AppTheme.storageKey], 'rose');
      expect(
        Theme.of(
          tester.element(find.byType(Scaffold).first),
        ).colorScheme.primary,
        rose.primary,
      );
    });

    testWidgets('ธีมที่เลือกไว้คงอยู่หลังเข้าสู่ระบบและออกจากระบบ', (
      tester,
    ) async {
      await start(tester);
      await tester.tap(find.byTooltip(CustomHeader.themeButtonTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppTheme.palettes[2].name));
      await tester.pumpAndSettle();
      final chosen = AppTheme.palettes[2];

      await tester.tap(find.widgetWithText(TextButton, 'เข้าสู่ระบบ'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อผู้ใช้'),
        FakeBackend.user,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'รหัสผ่าน'),
        FakeBackend.passwordOf(FakeBackend.user),
      );
      // หน้าแรกก็มีปุ่มเข้าสู่ระบบ จึงเจาะจงปุ่มในหน้าต่าง
      await tester.tap(
        find.descendant(
          of: find.byType(LoginDialog),
          matching: find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'),
        ),
      );
      await tester.pumpAndSettle();
      expect(auth.isLoggedIn, isTrue);
      expect(appBarColor(tester), chosen.primary);

      await tester.runAsync(auth.logout);
      await tester.pumpAndSettle();
      expect(appBarColor(tester), chosen.primary);
      expect(html.window.localStorage[AppTheme.storageKey], chosen.id);
    });
  });
}
