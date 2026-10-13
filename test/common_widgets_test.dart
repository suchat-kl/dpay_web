// เทสต์ส่วนประกอบร่วม: AppDialog, แถบแจ้งผล (snackbar), ตัวแบ่งหน้า, ส่วนประกอบของหน้าจอ และสิทธิ์เปิดหน้าจอตามบทบาท

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/app_config.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/utils/dialog.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/utils/snackbar_helper.dart';
import 'package:dpay/widgets/app_pagination.dart';
import 'package:dpay/widgets/footer.dart';
import 'package:dpay/widgets/screen_parts.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  /// หน้าเปล่าที่มีปุ่มเดียว กดแล้วเรียก [onPressed] ด้วย context ของหน้านั้น
  Future<void> pumpButton(
    WidgetTester tester,
    void Function(BuildContext context) onPressed,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onPressed(context),
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
  }

  group('AppDialog', () {
    testWidgets(
      'showConfirm: ยืนยันได้ true ยกเลิกได้ false ใช้ป้ายปุ่มที่ส่งมา',
      (tester) async {
        final results = <bool?>[];
        await pumpButton(tester, (context) async {
          results.add(
            await AppDialog.showConfirm(
              context,
              'ลบรายการนี้?',
              confirmText: 'ลบเลย',
              cancelText: 'ไม่ลบ',
            ),
          );
        });
        expect(find.text('ลบรายการนี้?'), findsOneWidget);
        await tester.tap(find.text('ลบเลย'));
        await tester.pumpAndSettle();
        expect(results, [true]);

        await tester.tap(find.text('เปิด'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ไม่ลบ'));
        await tester.pumpAndSettle();
        expect(results, [true, false]);
      },
    );

    testWidgets(
      'showSuccess / showError / showInfo / showWarning: แสดงข้อความและปิดด้วยปุ่มตกลง',
      (tester) async {
        final shows = <Future<void> Function(BuildContext, String)>[
          AppDialog.showSuccess,
          AppDialog.showError,
          AppDialog.showInfo,
          AppDialog.showWarning,
        ];
        var i = 0;
        await pumpButton(
          tester,
          (context) => shows[i](context, 'ข้อความที่ $i'),
        );
        for (i = 0; i < shows.length; i++) {
          if (i > 0) {
            await tester.tap(find.text('เปิด'));
            await tester.pumpAndSettle();
          }
          expect(find.text('ข้อความที่ $i'), findsOneWidget);
          await tester.tap(find.text('ตกลง'));
          await tester.pumpAndSettle();
          expect(find.text('ข้อความที่ $i'), findsNothing);
        }
      },
    );
  });

  group('แถบแจ้งผล', () {
    testWidgets(
      'สำเร็จ / ผิดพลาด / ข้อมูล: แสดงข้อความ แล้วหายเองเมื่อครบเวลา',
      (tester) async {
        var kind = 0;
        await pumpButton(tester, (context) {
          switch (kind) {
            case 0:
              context.showSuccessSnackBar('บันทึกแล้ว');
            case 1:
              context.showErrorSnackBar('บันทึกไม่สำเร็จ');
            default:
              context.showInfoSnackBar('แจ้งเพื่อทราบ');
          }
        });
        expect(find.text('บันทึกแล้ว'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('บันทึกแล้ว'), findsNothing);

        kind = 1;
        await tester.tap(find.text('เปิด'));
        await tester.pumpAndSettle();
        expect(find.text('บันทึกไม่สำเร็จ'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        kind = 2;
        await tester.tap(find.text('เปิด'));
        await tester.pumpAndSettle();
        expect(find.text('แจ้งเพื่อทราบ'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('showOverlayMessage: ลอยเหนือ dialog แตะแล้วปิดก่อนเวลาได้', (
      tester,
    ) async {
      await pumpButton(tester, (context) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: TextButton(
              onPressed: () =>
                  dialogContext.showOverlayMessage('เห็นแม้มีหน้าต่าง'),
              child: const Text('แจ้ง'),
            ),
          ),
        );
      });
      await tester.tap(find.text('แจ้ง'));
      await tester.pumpAndSettle();
      expect(find.text('เห็นแม้มีหน้าต่าง'), findsOneWidget);

      await tester.tap(find.text('เห็นแม้มีหน้าต่าง'));
      await tester.pumpAndSettle();
      expect(find.text('เห็นแม้มีหน้าต่าง'), findsNothing);

      // ไม่แตะ: หายเองเมื่อครบ 3 วินาที
      await tester.tap(find.text('แจ้ง'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('เห็นแม้มีหน้าต่าง'), findsNothing);
    });
  });

  group('AppPagination', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      required int currentPage,
      required int totalPages,
    }) async {
      tester.view.physicalSize = const Size(1400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPagination(
              currentPage: currentPage,
              totalPages: totalPages,
              pageSize: 10,
              onPageChanged: (p) => events.add('page:$p'),
              onPageSizeChanged: (s) => events.add('size:$s'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return events;
    }

    testWidgets('หน้าต่างเลขหน้า 5 ปุ่ม: ต้น กลาง ท้าย', (tester) async {
      await pump(tester, currentPage: 0, totalPages: 12);
      expect(find.text('หน้า 1 จาก 12'), findsOneWidget);
      for (final n in ['1', '2', '3', '4', '5']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('6'), findsNothing);

      await pump(tester, currentPage: 6, totalPages: 12);
      for (final n in ['5', '6', '7', '8', '9']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('4'), findsNothing);

      await pump(tester, currentPage: 11, totalPages: 12);
      for (final n in ['8', '9', '10', '11', '12']) {
        expect(find.text(n), findsOneWidget);
      }
    });

    testWidgets('ปุ่มหน้าแรก/ก่อนหน้า/ถัดไป/สุดท้าย และกดเลขหน้า', (
      tester,
    ) async {
      final events = await pump(tester, currentPage: 4, totalPages: 12);

      await tester.tap(find.byIcon(Icons.first_page));
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.last_page));
      await tester.tap(find.text('7'));
      expect(events, ['page:0', 'page:3', 'page:5', 'page:11', 'page:6']);
    });

    testWidgets(
      'หน้าแรกกดย้อนไม่ได้ หน้าสุดท้ายกดถัดไปไม่ได้ ไม่มีข้อมูลแสดงเป็นหน้า 1 จาก 1',
      (tester) async {
        var events = await pump(tester, currentPage: 0, totalPages: 3);
        await tester.tap(find.byIcon(Icons.first_page));
        await tester.tap(find.byIcon(Icons.chevron_left));
        expect(events, isEmpty);

        events = await pump(tester, currentPage: 2, totalPages: 3);
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.tap(find.byIcon(Icons.last_page));
        expect(events, isEmpty);

        events = await pump(tester, currentPage: 0, totalPages: 0);
        expect(find.text('หน้า 1 จาก 1'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.chevron_right));
        expect(events, isEmpty);
      },
    );

    testWidgets('เลือกจำนวนแถวต่อหน้า', (tester) async {
      final events = await pump(tester, currentPage: 0, totalPages: 3);
      expect(AppPagination.pageSizeOptions, [5, 10, 15, 20]);

      await tester.tap(find.text('10 แถว'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 แถว').last);
      await tester.pumpAndSettle();
      expect(events, ['size:15']);
    });
  });

  group('ส่วนประกอบของหน้าจอ', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('YearStepper: เลื่อนปีได้ในช่วง สุดช่วงแล้วปุ่มกดไม่ได้', (
      tester,
    ) async {
      var year = 2569;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => YearStepper(
            year: year,
            min: 2568,
            max: 2570,
            onChanged: (y) => setState(() => year = y),
          ),
        ),
      );
      await tester.tap(find.byTooltip('ปีถัดไป'));
      await tester.pumpAndSettle();
      expect(find.text('2570'), findsOneWidget);
      // สุดช่วงบนแล้ว กดอีกไม่ขยับ
      await tester.tap(find.byTooltip('ปีถัดไป'));
      await tester.pumpAndSettle();
      expect(year, 2570);

      await tester.tap(find.byTooltip('ปีก่อนหน้า'));
      await tester.tap(find.byTooltip('ปีก่อนหน้า'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('ปีก่อนหน้า'));
      await tester.pumpAndSettle();
      expect(year, 2568);
    });

    testWidgets(
      'MonthPicker: 12 เดือนชื่อไทย เดือนที่มีข้อมูลมีเครื่องหมาย เลือกแล้วแจ้งค่า',
      (tester) async {
        final picked = <int>[];
        await pump(
          tester,
          MonthPicker(
            selected: 3,
            available: const {3, 10},
            onSelected: picked.add,
          ),
        );
        expect(find.text('มกราคม'), findsOneWidget);
        expect(find.text('ธันวาคม'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

        await tester.tap(find.byKey(const ValueKey('month-10')));
        await tester.tap(find.text('กุมภาพันธ์'));
        expect(picked, [10, 2]);
      },
    );

    testWidgets(
      'ChoiceCard: เลือกได้ ตัวที่ปิดไว้ (onTap เป็น null) กดไม่ได้และมีป้าย',
      (tester) async {
        final taps = <String>[];
        await pump(
          tester,
          ResponsiveGrid(
            minItemWidth: 200,
            children: [
              ChoiceCard(
                icon: Icons.list,
                title: 'ตัวเลือกแรก',
                subtitle: 'คำอธิบาย',
                selected: true,
                onTap: () => taps.add('a'),
              ),
              const ChoiceCard(
                icon: Icons.lock,
                title: 'ยังไม่เปิด',
                selected: false,
                badge: ChoiceCard.comingSoon,
              ),
            ],
          ),
        );
        expect(find.text(ChoiceCard.comingSoon), findsOneWidget);
        await tester.tap(find.text('ตัวเลือกแรก'));
        await tester.tap(find.text('ยังไม่เปิด'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(taps, ['a']);
      },
    );

    testWidgets(
      'NoticeBar / StatusChip / PrimaryActionButton / ScreenHeader / StepCard',
      (tester) async {
        var closed = 0;
        var pressed = 0;
        await pump(
          tester,
          Column(
            children: [
              const ScreenHeader(
                icon: Icons.checklist,
                title: 'หัวหน้าจอ',
                subtitle: 'คำอธิบายหน้าจอ',
                bullets: ['ข้อแรก', 'ข้อสอง'],
              ),
              NoticeBar(
                type: NoticeType.warning,
                title: 'หัวข้อเตือน',
                text: 'เนื้อความเตือน',
                onClose: () => closed++,
              ),
              StepCard(
                step: 2,
                title: 'ขั้นที่สอง',
                subtitle: 'คำอธิบายขั้น',
                trailing: const StatusChip('ป้าย', Colors.green, solid: true),
                child: PrimaryActionButton(
                  label: 'ทำงาน',
                  icon: Icons.play_arrow,
                  onPressed: () => pressed++,
                ),
              ),
            ],
          ),
        );
        for (final t in [
          'หัวหน้าจอ',
          'คำอธิบายหน้าจอ',
          'ข้อแรก',
          'ข้อสอง',
          'หัวข้อเตือน',
          'เนื้อความเตือน',
          '2',
          'ขั้นที่สอง',
          'คำอธิบายขั้น',
          'ป้าย',
        ]) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        await tester.tap(find.byTooltip('ปิดข้อความ'));
        await tester.tap(find.text('ทำงาน'));
        expect(closed, 1);
        expect(pressed, 1);
      },
    );

    testWidgets('PrimaryActionButton ระหว่าง loading: แสดงวงหมุนและกดไม่ได้', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryActionButton(
              label: 'กำลังทำ',
              icon: Icons.play_arrow,
              loading: true,
              onPressed: () => pressed++,
            ),
          ),
        ),
      );
      // วงหมุนขยับไม่หยุด ใช้ pump เฉย ๆ (pumpAndSettle จะรอไม่จบ)
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('กำลังทำ'), warnIfMissed: false);
      await tester.pump();
      expect(pressed, 0);
    });

    testWidgets('ส่วนท้าย: ชื่อระบบ หน่วยงาน และปี พ.ศ. ปัจจุบัน', (
      tester,
    ) async {
      await pump(tester, const CustomFooter());
      expect(find.text(AppConfig.systemName), findsOneWidget);
      expect(find.text(AppConfig.organizationName), findsOneWidget);
      expect(find.text(AppConfig.systemTagline), findsOneWidget);
      expect(
        find.text(
          '© พ.ศ. ${DateTime.now().year + 543} ${AppConfig.organizationName}',
        ),
        findsOneWidget,
      );
    });
  });

  group('สิทธิ์เปิดหน้าจอตามบทบาท', () {
    test('Perm.allows: ตารางบทบาทต่อหน้าจอ', () {
      for (final code in [Perm.period, Perm.alertMessage, Perm.editWindow]) {
        expect(Perm.allows(code, [Roles.account]), isTrue, reason: code);
        expect(Perm.allows(code, [Roles.admin]), isFalse, reason: code);
        expect(Perm.allows(code, [Roles.user]), isFalse, reason: code);
      }
      expect(Perm.allows(Perm.userResetPassword, [Roles.resetPwd]), isTrue);
      expect(Perm.allows(Perm.userResetPassword, [Roles.admin]), isTrue);
      expect(Perm.allows(Perm.userResetPassword, [Roles.account]), isFalse);
      expect(Perm.allows(Perm.userManage, [Roles.admin]), isTrue);
      expect(Perm.allows(Perm.userManage, [Roles.resetPwd]), isFalse);
      // ถือหลายบทบาท: ได้ตามบทบาทใดบทบาทหนึ่ง
      expect(
        Perm.allows(Perm.userManage, [Roles.user, Roles.allDept, Roles.admin]),
        isTrue,
      );
      // บทบาทบอกขอบเขตหน่วยงานไม่เปิดหน้าจอใดเพิ่ม
      for (final code in [
        Perm.period,
        Perm.alertMessage,
        Perm.editWindow,
        Perm.userResetPassword,
        Perm.userManage,
      ]) {
        expect(
          Perm.allows(code, [Roles.centerDept, Roles.allDept]),
          isFalse,
          reason: code,
        );
      }
      expect(Perm.allows('ไม่มีหน้าจอนี้', Roles.order), isFalse);
      expect(Perm.allows(Perm.period, const []), isFalse);
    });

    test('Roles: ชื่อไทยครบทุกบทบาท ไม่รู้จักคืนรหัสเดิม', () {
      expect(Roles.order, [
        'USER',
        'ACCOUNT',
        'RESETPWD',
        'CENTER_DEPT',
        'ALL_DEPT',
        'ADMIN',
      ]);
      for (final r in Roles.order) {
        expect(Roles.nameOf(r), isNot(r), reason: r);
      }
      expect(Roles.nameOf('OTHER'), 'OTHER');
    });

    test(
      'Perm.view: ยังไม่เข้าสู่ระบบเปิดไม่ได้ทุกหน้าจอ เข้าแล้วตอบตามบทบาท',
      () async {
        await installFakeBackend();
        final auth = AuthProvider();
        addTearDown(auth.logout);

        expect(Perm.view(Perm.userManage), isFalse);
        expect(Perm.isAdmin, isFalse);

        await auth.login(
          FakeBackend.account,
          FakeBackend.passwordOf(FakeBackend.account),
        );
        expect(Perm.view(Perm.period), isTrue);
        expect(Perm.view(Perm.userManage), isFalse);
        expect(Perm.isAccount, isTrue);
        expect(Perm.isAdmin, isFalse);

        await auth.logout();
        await auth.login(
          FakeBackend.admin,
          FakeBackend.passwordOf(FakeBackend.admin),
        );
        expect(Perm.isAdmin, isTrue);
        expect(Perm.view(Perm.userManage), isTrue);
        expect(Perm.view(Perm.userResetPassword), isTrue);
        expect(Perm.view(Perm.period), isFalse);
      },
    );
  });
}
