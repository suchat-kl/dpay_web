// เทสต์หน้าแรก: ข้อความแจ้งผู้ใช้งาน (ไม่ต้องเข้าสู่ระบบ) ปุ่มเข้าสู่ระบบ
// และการ์ดหน่วยงาน / งวดปัจจุบัน / ระยะเวลาแก้ไขข้อมูลหลังเข้าสู่ระบบ

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/main.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/screens/home_screen.dart';
import 'package:dpay/widgets/alert_message_box.dart';
import 'package:dpay/widgets/header.dart';
import 'package:dpay/widgets/login_dialog.dart';
import 'package:dpay/widgets/test_phase_banner.dart';
import 'package:universal_html/html.dart' as html;

import 'package:dpay/widgets/period_progress.dart';
import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
  });

  tearDown(() => auth.logout());

  Future<void> start(WidgetTester tester, {String? as}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    html.window.localStorage.remove(AppConfig.menuPinnedStorageKey);
    if (as != null) {
      await tester.runAsync(() => auth.login(as, FakeBackend.passwordOf(as)));
      backend.clearLog();
    }
    await tester.pumpWidget(DpayApp(authProvider: auth));
    await tester.pumpAndSettle();
  }

  String shownMessage(WidgetTester tester) =>
      tester.widget<SelectableText>(find.byKey(AlertMessageBox.textKey)).data!;

  Finder inCard(Key card, Finder f) =>
      find.descendant(of: find.byKey(card), matching: f);

  group('ก่อนเข้าสู่ระบบ', () {
    testWidgets(
      'ชื่อระบบ ป้ายช่วงทดสอบ ข้อความแจ้งหลายบรรทัด และปุ่มเข้าสู่ระบบ — เรียกแค่เส้นสาธารณะ',
      (tester) async {
        await start(tester);

        expect(AppConfig.systemName, 'ระบบหักหนี้');
        expect(AppConfig.organizationName, 'กรมทางหลวง');
        expect(find.text(TestPhaseBanner.message), findsOneWidget);
        // แถบบน + ส่วนท้าย (ไม่มีส่วนหัวภาพขนาดใหญ่ในหน้าแรกแล้ว)
        expect(find.text(AppConfig.systemName), findsNWidgets(2));
        expect(find.byType(Image), findsNothing);
        // แถบข้อความบาง ๆ แถวบนสุดของเนื้อหา แล้วตามด้วยกล่องข้อความแจ้งทันที
        final strip = find.byKey(HomeScreen.loginStripKey);
        expect(
          find.descendant(
            of: strip,
            matching: find.text(HomeScreen.loginPrompt),
          ),
          findsOneWidget,
        );
        expect(find.text(HomeScreen.loginPrompt), findsOneWidget);
        expect(tester.getSize(strip).height, lessThan(48));
        expect(tester.getSize(strip).width, 1400);
        final stripRect = tester.getRect(strip);
        final boxRect = tester.getRect(find.byType(AlertMessageBox));
        expect(boxRect.top, greaterThanOrEqualTo(stripRect.bottom));
        expect(boxRect.top - stripRect.bottom, lessThan(40));
        // ไม่ต้องเลื่อนจอจึงเห็นข้อความแจ้ง
        expect(boxRect.top, lessThan(260));
        expect(find.textContaining('สงวนลิขสิทธิ์'), findsOneWidget);

        expect(find.text(AlertMessageBox.title), findsOneWidget);
        expect(shownMessage(tester), backend.alertMessage);
        expect(shownMessage(tester).split('\n'), hasLength(3));

        // ปุ่มเข้าสู่ระบบมีที่แถบบนของแอปที่เดียว ไม่มีปุ่มสีเหลืองในเนื้อหาหน้าแรก
        expect(find.byKey(CustomHeader.loginButtonKey), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'เข้าสู่ระบบ'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(ElevatedButton),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(HomeScreen),
            matching: find.text('เข้าสู่ระบบ'),
          ),
          findsNothing,
        );
        // ยังไม่เข้าสู่ระบบ: ไม่มีการ์ดสถานะ และไม่เรียกเส้นที่ต้องเข้าสู่ระบบ
        expect(find.byKey(HomeScreen.divCardKey), findsNothing);
        expect(find.byKey(HomeScreen.periodCardKey), findsNothing);
        expect(find.byKey(HomeScreen.editWindowCardKey), findsNothing);
        expect(backend.calls, ['GET /api/alert-message']);
        expect(backend.authHeaders.single, isNull);
      },
    );

    testWidgets(
      'ปุ่มเข้าสู่ระบบที่แถบบนเปิดหน้าต่างเข้าสู่ระบบ แล้วเข้าได้ แถบข้อความหายไป ข้อความแจ้งยังอยู่บนสุด',
      (tester) async {
        await start(tester);
        await tester.tap(find.byKey(CustomHeader.loginButtonKey));
        await tester.pumpAndSettle();
        final dialog = find.byType(LoginDialog);
        expect(dialog, findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'ชื่อผู้ใช้'),
          FakeBackend.user,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'รหัสผ่าน'),
          FakeBackend.passwordOf(FakeBackend.user),
        );
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ'),
          ),
        );
        await tester.pumpAndSettle();

        expect(auth.isLoggedIn, isTrue);
        expect(dialog, findsNothing);
        expect(find.byKey(CustomHeader.loginButtonKey), findsNothing);
        expect(find.byKey(HomeScreen.loginStripKey), findsNothing);
        expect(find.text(HomeScreen.loginPrompt), findsNothing);
        expect(find.byKey(HomeScreen.periodCardKey), findsOneWidget);
        // หลังเข้าสู่ระบบ: ข้อความแจ้งอยู่บนสุด เหนือการ์ดหน่วยงาน/งวด
        expect(find.byType(AlertMessageBox), findsOneWidget);
        expect(
          tester.getRect(find.byType(AlertMessageBox)).bottom,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(HomeScreen.divCardKey)).dy,
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'ข้อความยาวเกือบพันตัวอักษรหลายบรรทัด: แสดงครบ ไม่ตัด และไม่ตีความเป็น HTML',
      (tester) async {
        final lines = [
          'ประกาศถึงหน่วยงานทุกแห่ง <b>สำคัญ</b>',
          for (var i = 1; i <= 12; i++)
            'ข้อ $i ${'รายละเอียดการส่งข้อมูลหักหนี้ของงวดนี้ ' * 2}'.trim(),
          '',
          'ติดต่อสอบถามได้ที่กองบัญชีตัวอย่าง <script>alert(1)</script>',
        ];
        backend.alertMessage = lines.join('\n');
        expect(backend.alertMessage.length, greaterThan(900));
        await start(tester);

        expect(shownMessage(tester), backend.alertMessage);
        // แท็กเห็นเป็นตัวอักษร
        expect(shownMessage(tester), contains('<b>สำคัญ</b>'));
        expect(shownMessage(tester), contains('<script>'));
        // กล่องสูงตามเนื้อหา อยู่ในความกว้างของจอ ไม่ล้น
        final box = tester.getRect(find.byType(AlertMessageBox));
        expect(box.height, greaterThan(300));
        expect(box.right, lessThanOrEqualTo(1400));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('ไม่มีข้อความแจ้ง: บอกว่าไม่มี', (tester) async {
      backend.alertMessage = '';
      await start(tester);

      expect(find.text(AlertMessageBox.emptyText), findsOneWidget);
      expect(find.byKey(AlertMessageBox.textKey), findsNothing);
    });

    testWidgets('โหลดข้อความแจ้งไม่สำเร็จ: แสดงข้อผิดพลาด กดลองใหม่แล้วได้', (
      tester,
    ) async {
      backend.alertStatus = 500;
      await start(tester);

      expect(find.textContaining('เกิดข้อผิดพลาด'), findsOneWidget);
      expect(find.byKey(AlertMessageBox.textKey), findsNothing);
      // หน้าแรกส่วนอื่นยังใช้ได้
      expect(find.byKey(CustomHeader.loginButtonKey), findsOneWidget);

      backend.alertStatus = null;
      await tester.tap(find.text('ลองใหม่'));
      await tester.pumpAndSettle();
      expect(shownMessage(tester), backend.alertMessage);
    });
  });

  group('หลังเข้าสู่ระบบ', () {
    testWidgets(
      'หน่วยงานทั่วไป ช่วงแก้ไขเปิด: หน่วยงาน งวดเป็นเดือนไทย ปี พ.ศ. ช่วงเป็นวันที่ไทย + เวลา และแก้ไขได้',
      (tester) async {
        await start(tester, as: FakeBackend.user);
        // ความคืบหน้าของงวดเป็นของฝ่ายบัญชีเท่านั้น: บทบาทอื่นไม่เห็นและไม่เรียกเส้นสรุป
        expect(find.byType(PeriodProgress), findsNothing);
        expect(backend.calls, isNot(contains('GET /api/period/prepare')));

        expect(
          backend.calls,
          containsAll([
            'GET /api/alert-message',
            'GET /api/period',
            'GET /api/edit-window',
          ]),
        );
        expect(find.byKey(CustomHeader.loginButtonKey), findsNothing);
        expect(find.text(HomeScreen.loginPrompt), findsNothing);

        expect(
          inCard(HomeScreen.divCardKey, find.text(HomeScreen.divCardTitle)),
          findsOneWidget,
        );
        expect(
          inCard(HomeScreen.divCardKey, find.text('901 หน่วยงานตัวอย่างที่ 1')),
          findsOneWidget,
        );
        expect(
          inCard(
            HomeScreen.divCardKey,
            find.text('เลือกหน่วยงานได้: เฉพาะหน่วยงานของตัวเอง'),
          ),
          findsOneWidget,
        );

        expect(
          inCard(HomeScreen.periodCardKey, find.text('กรกฎาคม 2568')),
          findsOneWidget,
        );

        expect(
          tester.widget<Text>(
            inCard(
              HomeScreen.editWindowCardKey,
              find.text(HomeScreen.openLabel),
            ),
          ),
          isNotNull,
        );
        expect(
          find.text('ตั้งแต่ 23 มิถุนายน 2568 เวลา 06:00 น.'),
          findsOneWidget,
        );
        expect(find.text('ถึง 3 กรกฎาคม 2568 เวลา 11:00 น.'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(HomeScreen.canEditKey)).data,
          HomeScreen.canEditText,
        );
        // ข้อความแจ้งยังอยู่หลังเข้าสู่ระบบ
        expect(shownMessage(tester), backend.alertMessage);
      },
    );

    testWidgets('หน่วยงานทั่วไป ช่วงแก้ไขปิด: ป้ายปิด และบอกว่าแก้ไขไม่ได้', (
      tester,
    ) async {
      backend.serverTime = DateTime(2025, 7, 4, 8, 0);
      await start(tester, as: FakeBackend.user);

      expect(
        inCard(HomeScreen.editWindowCardKey, find.text(HomeScreen.closedLabel)),
        findsOneWidget,
      );
      expect(
        inCard(HomeScreen.editWindowCardKey, find.text(HomeScreen.openLabel)),
        findsNothing,
      );
      expect(
        tester.widget<Text>(find.byKey(HomeScreen.canEditKey)).data,
        HomeScreen.cannotEditText,
      );
      expect(find.text(HomeScreen.accountAlwaysText), findsNothing);
    });

    testWidgets(
      'ฝ่ายบัญชี ช่วงแก้ไขปิด: ป้ายปิด แต่บัญชีนี้แก้ไขได้ (can_edit_now) พร้อมคำอธิบาย',
      (tester) async {
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await start(tester, as: FakeBackend.account);
        // ฝ่ายบัญชี: มีการ์ดความคืบหน้าของงวด 11 ขั้น โหลดสถานะจากเส้นสรุป
        expect(find.byKey(PeriodProgress.cardKey), findsOneWidget);
        // ลำดับบนจอ: ข้อความแจ้ง → การ์ดหน่วยงาน/งวด/ช่วงแก้ไข → ความคืบหน้าของงวด
        final alertBottom = tester.getRect(find.byType(AlertMessageBox)).bottom;
        final cardsTop = tester
            .getTopLeft(find.byKey(HomeScreen.divCardKey))
            .dy;
        expect(alertBottom, lessThanOrEqualTo(cardsTop));
        expect(
          tester.getRect(find.byKey(HomeScreen.editWindowCardKey)).bottom,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(PeriodProgress.cardKey)).dy,
          ),
        );
        expect(find.text(PeriodProgress.title), findsOneWidget);
        expect(find.byKey(PeriodProgress.stepKey(11)), findsOneWidget);
        expect(
          backend.calls,
          containsAll([
            'GET /api/period/dpis-import',
            'GET /api/period/prepare',
            'GET /api/chapana/summary',
            'GET /api/saha/summary',
            'GET /api/loans/check',
          ]),
        );

        expect(
          inCard(
            HomeScreen.editWindowCardKey,
            find.text(HomeScreen.closedLabel),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.byKey(HomeScreen.canEditKey)).data,
          HomeScreen.canEditText,
        );
        expect(find.text(HomeScreen.accountAlwaysText), findsOneWidget);
        expect(
          inCard(HomeScreen.divCardKey, find.text('902 กองบัญชีตัวอย่าง')),
          findsOneWidget,
        );
        expect(
          inCard(
            HomeScreen.divCardKey,
            find.text('เลือกหน่วยงานได้: ทุกหน่วยงาน'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('ยังไม่ได้กำหนดงวดและระยะเวลา: บอกว่ายังไม่ได้กำหนด ไม่ล้ม', (
      tester,
    ) async {
      backend
        ..periodMonth = ''
        ..periodYear = ''
        ..beginDate = null
        ..endDate = null;
      await start(tester, as: FakeBackend.user);

      expect(
        inCard(HomeScreen.periodCardKey, find.text('ยังไม่ได้กำหนด')),
        findsOneWidget,
      );
      expect(find.text('ยังไม่ได้กำหนดระยะเวลาแก้ไขข้อมูล'), findsOneWidget);
      expect(
        inCard(HomeScreen.editWindowCardKey, find.text(HomeScreen.closedLabel)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('โหลดงวด/ระยะเวลาไม่สำเร็จ: แจ้งข้อผิดพลาด กดลองใหม่แล้วได้', (
      tester,
    ) async {
      await tester.runAsync(
        () => auth.login(
          FakeBackend.user,
          FakeBackend.passwordOf(FakeBackend.user),
        ),
      );
      backend.unreachable = true;
      await start(tester);

      expect(
        find.text('โหลดงวดปัจจุบันและระยะเวลาแก้ไขข้อมูลไม่สำเร็จ'),
        findsOneWidget,
      );
      // หน่วยงานของผู้ใช้มาจากผล login ยังแสดงได้
      expect(find.text('901 หน่วยงานตัวอย่างที่ 1'), findsOneWidget);

      backend.unreachable = false;
      // ปุ่มลองใหม่ของงวด/ระยะเวลา (กล่องข้อความแจ้งที่อยู่เหนือขึ้นไปมีปุ่มลองใหม่ของตัวเองด้วย)
      await tester.tap(find.widgetWithText(TextButton, 'ลองใหม่').last);
      await tester.pumpAndSettle();
      expect(
        find.text('โหลดงวดปัจจุบันและระยะเวลาแก้ไขข้อมูลไม่สำเร็จ'),
        findsNothing,
      );
      expect(find.text('กรกฎาคม 2568'), findsOneWidget);
    });
  });
}
