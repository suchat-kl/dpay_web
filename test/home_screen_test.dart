// เทสต์หน้าแรก: ข้อความแจ้งผู้ใช้งาน (ไม่ต้องเข้าสู่ระบบ) ปุ่มเข้าสู่ระบบ
// และการ์ดหน่วยงาน / งวดปัจจุบัน / ระยะเวลาแก้ไขข้อมูลหลังเข้าสู่ระบบ

import 'package:flutter/gestures.dart';
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
      'จอแคบกว่า 900 จุด: วิธีเข้าสู่ระบบเป็นแถบบาง ๆ ใต้แถบบน ไม่อยู่ในแถบบน',
      (tester) async {
        await start(tester);
        tester.view.physicalSize = const Size(880, 1000);
        await tester.pumpAndSettle();

        expect(find.byKey(CustomHeader.loginPromptKey), findsNothing);
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
        expect(
          tester.getRect(find.byType(AlertMessageBox)).top,
          greaterThanOrEqualTo(tester.getRect(strip).bottom),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('จอ 900 จุดพอดี: ข้อความอยู่ในแถบบนและไม่ล้น', (tester) async {
      await start(tester);
      tester.view.physicalSize = const Size(900, 1000);
      await tester.pumpAndSettle();

      expect(find.byKey(CustomHeader.loginPromptKey), findsOneWidget);
      expect(find.byKey(HomeScreen.loginStripKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ชื่อระบบ ป้ายช่วงทดสอบ ข้อความแจ้งหลายบรรทัด และปุ่มเข้าสู่ระบบ — เรียกแค่เส้นสาธารณะ',
      (tester) async {
        await start(tester);

        expect(AppConfig.systemName, 'ระบบหักหนี้');
        expect(AppConfig.organizationName, 'กรมทางหลวง');
        // เปิดใช้จริงแล้ว ไม่มีป้ายช่วงทดสอบ
        expect(find.text(TestPhaseBanner.message), findsNothing);
        // แถบบน + ส่วนท้าย (ไม่มีส่วนหัวภาพขนาดใหญ่ในหน้าแรกแล้ว)
        expect(find.text(AppConfig.systemName), findsNWidgets(2));
        expect(find.byType(Image), findsNothing);
        // จอกว้าง: วิธีเข้าสู่ระบบอยู่แถวเดียวกับชื่อระบบในแถบบน ไม่มีแถบแยกใต้แถบบนแล้ว
        final prompt = find.byKey(CustomHeader.loginPromptKey);
        expect(
          find.descendant(of: find.byType(CustomHeader), matching: prompt),
          findsOneWidget,
        );
        expect(find.text(HomeScreen.loginPrompt), findsOneWidget);
        expect(find.byKey(HomeScreen.loginStripKey), findsNothing);
        final promptRect = tester.getRect(prompt);
        final nameRect = tester.getRect(
          find.descendant(
            of: find.byType(CustomHeader),
            matching: find.text(AppConfig.systemName),
          ),
        );
        final loginRect = tester.getRect(
          find.byKey(CustomHeader.loginButtonKey),
        );
        final barRect = tester.getRect(find.byType(CustomHeader));
        expect(promptRect.top, greaterThanOrEqualTo(barRect.top));
        expect(promptRect.bottom, lessThanOrEqualTo(barRect.bottom));
        expect(promptRect.left, greaterThan(nameRect.right));
        expect(promptRect.right, lessThan(loginRect.left));
        expect(tester.takeException(), isNull);
        final boxRect = tester.getRect(find.byType(AlertMessageBox));
        expect(boxRect.top, greaterThanOrEqualTo(barRect.bottom));
        expect(boxRect.top - barRect.bottom, lessThan(40));
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
        // หลังเข้าสู่ระบบ: ไม่แสดงข้อความแจ้งแล้ว การ์ดหน่วยงาน/งวดขึ้นมาอยู่บนสุด
        expect(find.byType(AlertMessageBox), findsNothing);
        expect(find.text(AlertMessageBox.title), findsNothing);
        expect(find.byKey(HomeScreen.divCardKey), findsOneWidget);
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
        // ความคืบหน้าของงวด: ผู้ใช้ทั่วไปเห็นเฉพาะขั้น 5 หน่วยงานบันทึกหนี้ กับขั้น 12 รายงาน (เลขเดียวกับฝ่ายบัญชี)
        // และไม่เรียกเส้นสรุปของฝ่ายบัญชี
        expect(find.byKey(PeriodProgress.cardKey), findsOneWidget);
        for (var n = 1; n <= 12; n++) {
          expect(
            find.byKey(PeriodProgress.stepKey(n)),
            n == 5 || n == 12 ? findsOneWidget : findsNothing,
            reason: 'ขั้น $n',
          );
        }
        expect(find.text(PeriodProgress.entryEditableText), findsOneWidget);
        expect(find.text(PeriodProgress.generalSubtitle), findsOneWidget);
        expect(find.byKey(PeriodProgress.refreshKey), findsNothing);
        // คำขอปกติยังรอได้ 30 วินาทีตามค่าตั้งต้น (ขยายเฉพาะงานยาว)
        expect(backend.connectTimeouts, isNotEmpty);
        expect(
          backend.connectTimeouts,
          everyElement(const Duration(seconds: 30)),
        );
        for (final path in [
          'GET /api/period/dpis-import',
          'GET /api/period/prepare',
          'GET /api/debts/div-status',
          'GET /api/chapana/summary',
          'GET /api/saha/summary',
          'GET /api/loans/check',
        ]) {
          expect(backend.calls, isNot(contains(path)), reason: path);
        }

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
        // หลังเข้าสู่ระบบไม่แสดงข้อความแจ้ง
        expect(find.byType(AlertMessageBox), findsNothing);
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
      // นอกช่วงเวลา: ขั้นหน่วยงานบันทึกหนี้กับรายงานยังอยู่ บอกว่าดูข้อมูลได้อย่างเดียว
      expect(find.byKey(PeriodProgress.stepKey(5)), findsOneWidget);
      expect(find.byKey(PeriodProgress.stepKey(12)), findsOneWidget);
      expect(find.text(PeriodProgress.entryReadOnlyText), findsOneWidget);
      expect(find.text(PeriodProgress.entryEditableText), findsNothing);

      // ชี้เมาส์ที่การ์ด: ลอยขึ้น เงาเข้มขึ้น เอาเมาส์ออกกลับที่เดิม
      double shadowOf(Key k) =>
          ((tester.widget<AnimatedContainer>(find.byKey(k)).decoration!
                      as BoxDecoration)
                  .boxShadow!
                  .single)
              .blurRadius;
      final card = HomeScreen.divCardKey;
      final restTop = tester.getTopLeft(find.byKey(card)).dy;
      expect(shadowOf(card), 10);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(card)));
      await tester.pumpAndSettle();
      expect(shadowOf(card), 18);
      expect(tester.getTopLeft(find.byKey(card)).dy, lessThan(restTop));
      // ขั้นในความคืบหน้าของงวดก็ลอยเหมือนกัน
      await mouse.moveTo(
        tester.getCenter(find.byKey(PeriodProgress.stepKey(12))),
      );
      await tester.pumpAndSettle();
      expect(shadowOf(card), 10);
      expect(tester.getTopLeft(find.byKey(card)).dy, restTop);
      expect(
        tester
            .widget<Material>(find.byKey(PeriodProgress.stepKey(12)))
            .elevation,
        4,
      );
    });

    testWidgets(
      'ฝ่ายบัญชี ช่วงแก้ไขปิด: ป้ายปิด แต่บัญชีนี้แก้ไขได้ (can_edit_now) พร้อมคำอธิบาย',
      (tester) async {
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await start(tester, as: FakeBackend.account);
        // ฝ่ายบัญชี: มีการ์ดความคืบหน้าของงวด 12 ขั้น โหลดสถานะจากเส้นสรุป
        expect(find.byKey(PeriodProgress.cardKey), findsOneWidget);
        // ลำดับบนจอ: การ์ดหน่วยงาน/งวด/ช่วงแก้ไข → ความคืบหน้าของงวด (ไม่มีข้อความแจ้งหลังเข้าสู่ระบบ)
        expect(find.byType(AlertMessageBox), findsNothing);
        expect(
          tester.getRect(find.byKey(HomeScreen.editWindowCardKey)).bottom,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(PeriodProgress.cardKey)).dy,
          ),
        );
        expect(find.text(PeriodProgress.title), findsOneWidget);
        expect(find.byKey(PeriodProgress.stepKey(12)), findsOneWidget);
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
        expect(find.text(HomeScreen.adminAlwaysText), findsNothing);
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

    testWidgets(
      'ผู้ดูแลระบบที่มีสิทธิ์ทั้งหมด ช่วงแก้ไขปิด: บอกว่าเป็นสิทธิ์ของผู้ดูแลระบบ ไม่ใช่ฝ่ายบัญชี',
      (tester) async {
        // บัญชีผู้ดูแลของระบบจริงได้ทุกบทบาท (รวมฝ่ายบัญชี) จึงแก้ไขได้แม้ช่วงปิด
        backend.users[FakeBackend.admin]!.roles = [
          'USER',
          'ACCOUNT',
          'RESETPWD',
          'ADMIN',
        ];
        backend.serverTime = DateTime(2025, 7, 4, 8, 0);
        await start(tester, as: FakeBackend.admin);

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
        expect(find.text(HomeScreen.adminAlwaysText), findsOneWidget);
        expect(find.text(HomeScreen.accountAlwaysText), findsNothing);
        expect(find.byType(AlertMessageBox), findsNothing);
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
