// เทสต์เมนู "ข้อมูลงวด" ของฝ่ายบัญชี: กำหนดเดือนปี ข้อความแจ้งผู้ใช้งาน ระยะเวลาแก้ไขข้อมูล
// และโมเดล Period / EditWindow

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/models/edit_window.dart';
import 'package:dpay/models/period.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/providers/settings_provider.dart';
import 'package:dpay/screens/alert_message_screen.dart';
import 'package:dpay/screens/edit_window_screen.dart';
import 'package:dpay/screens/period_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/alert_message_box.dart';
import 'package:dpay/widgets/screen_parts.dart';
import 'package:dpay/widgets/thai_date_range_picker.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();
  final settings = SettingsProvider();

  Future<void> signIn(String username) =>
      auth.login(username, FakeBackend.passwordOf(username));

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
  });

  tearDown(() => auth.logout());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: screen),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Finder fieldOf(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );

  group('โมเดล', () {
    test('Period: ข้อความเดือนไทย ปี พ.ศ. และค่าที่ส่ง backend', () {
      final p = Period.fromJson({'month': '07', 'year': '2568'});
      expect(p.label, 'กรกฎาคม 2568');
      expect(p.monthNumber, 7);
      expect(p.yearNumber, 2568);
      expect(Period.of(3, 2569).toJson(), {'month': '03', 'year': '2569'});
      expect(Period.of(12, 2569).label, 'ธันวาคม 2569');
      // ฐานที่ยังไม่เคยตั้งงวด / ค่าผิดรูป
      expect(Period.fromJson({}).isValid, isFalse);
      expect(Period.fromJson({}).label, Period.notSetLabel);
      expect(Period.fromJson({'month': '13', 'year': '2568'}).isValid, isFalse);
      expect(Period.fromJson({'month': 7, 'year': 2568}).label, 'กรกฎาคม 2568');
    });

    test('EditWindow: อ่าน JSON วันที่ไทย + เวลา และค่าที่ส่ง backend', () {
      final w = EditWindow.fromJson({
        'beginDate': '2025-06-23',
        'endDate': '2025-07-03',
        'beginTime': '6:00',
        'endTime': '11:00',
        'open': true,
        'can_edit_now': true,
        'server_time': '2025-06-25T09:30:00',
      });
      expect(w.isSet, isTrue);
      expect(w.beginTime, '06:00');
      expect(w.beginLabel, '23 มิถุนายน 2568 เวลา 06:00 น.');
      expect(w.endLabel, '3 กรกฎาคม 2568 เวลา 11:00 น.');
      expect(
        w.rangeLabel,
        'ตั้งแต่ 23 มิถุนายน 2568 เวลา 06:00 น. ถึง 3 กรกฎาคม 2568 เวลา 11:00 น.',
      );
      expect(w.open, isTrue);
      expect(w.canEditNow, isTrue);
      expect(w.serverTime, DateTime(2025, 6, 25, 9, 30));

      expect(
        EditWindow.requestJson(
          beginDate: DateTime(2025, 6, 23),
          endDate: DateTime(2025, 7, 3),
          beginTime: '06:00',
          endTime: '11:00',
        ),
        {
          'beginDate': '2025-06-23',
          'endDate': '2025-07-03',
          'beginTime': '06:00',
          'endTime': '11:00',
        },
      );
    });

    test('EditWindow: ค่าขาด/ผิดรูปไม่ล้ม ถือว่ายังไม่ได้ตั้งและปิด', () {
      final w = EditWindow.fromJson({'beginDate': 'ไม่ใช่วันที่'});
      expect(w.isSet, isFalse);
      expect(w.open, isFalse);
      expect(w.canEditNow, isFalse);
      expect(w.beginTime, EditWindow.defaultBeginTime);
      expect(w.endTime, EditWindow.defaultEndTime);
      expect(w.rangeLabel, EditWindow.notSetLabel);
      expect(w.beginLabel, '-');
    });

    test('EditWindow.normalizeTime: รับ HH:mm ในช่วง 00:00-23:59', () {
      expect(EditWindow.normalizeTime('06:00'), '06:00');
      expect(EditWindow.normalizeTime('6:05'), '06:05');
      expect(EditWindow.normalizeTime(' 23:59 '), '23:59');
      expect(EditWindow.normalizeTime('00:00'), '00:00');
      for (final bad in [
        '24:00',
        '12:60',
        '6',
        '6:5',
        '0600',
        'ab:cd',
        '',
        null,
      ]) {
        expect(EditWindow.normalizeTime(bad), isNull, reason: '$bad');
      }
    });
  });

  group('กำหนดเดือนปี', () {
    testWidgets('แสดงงวดปัจจุบัน เลือกปีและเดือนใหม่ ยืนยัน แล้วบันทึก', (
      tester,
    ) async {
      await tester.runAsync(() => signIn(FakeBackend.account));
      await pump(tester, PeriodScreen(apiService: api));

      expect(find.text(PeriodScreen.menuTitle), findsOneWidget);
      expect(find.text(PeriodScreen.timeResetNote), findsOneWidget);
      expect(
        PeriodScreen.timeResetNote,
        'เมื่อเปลี่ยนงวด เวลาของระยะเวลาแก้ไขข้อมูลจะกลับเป็น 06:00–16:30 น. '
        'โปรดกำหนดช่วงวันที่ของงวดใหม่',
      );
      expect(
        tester.widget<Text>(find.byKey(PeriodScreen.currentKey)).data,
        'กรกฎาคม 2568',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('year-value'))).data,
        '2568',
      );
      // ยังไม่เปลี่ยนอะไร ปุ่มบันทึกกดไม่ได้
      expect(
        tester
            .widget<PrimaryActionButton>(find.byKey(PeriodScreen.saveButtonKey))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('ปีถัดไป'));
      await tester.tap(find.byKey(const ValueKey('month-10')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(PeriodScreen.selectedKey)).data,
        'งวดที่เลือก: ตุลาคม 2569',
      );

      // กดบันทึก -> ถามยืนยัน -> ยกเลิก = ไม่เรียก backend
      backend.clearLog();
      await tester.tap(find.byKey(PeriodScreen.saveButtonKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('ตุลาคม 2569 ใช่หรือไม่'), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);

      await tester.tap(find.byKey(PeriodScreen.saveButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();

      expect(backend.bodyOf('PUT /api/period'), {
        'month': '10',
        'year': '2569',
      });
      expect(backend.periodMonth, '10');
      expect(backend.periodYear, '2569');
      expect(
        tester.widget<Text>(find.byKey(PeriodScreen.currentKey)).data,
        'ตุลาคม 2569',
      );
      expect(find.text(PeriodScreen.savedMessage), findsOneWidget);
      // หน้าจออื่นเห็นงวดใหม่ทันทีผ่าน SettingsProvider
      expect(settings.period!.label, 'ตุลาคม 2569');
      // เปลี่ยนงวด: backend ตั้งเวลากลับเป็น 06:00 / 16:30 หน้าเว็บโหลดระยะเวลาแก้ไขใหม่ให้
      expect(backend.calls, contains('GET /api/edit-window'));
      expect(settings.editWindow!.beginTime, '06:00');
      expect(settings.editWindow!.endTime, '16:30');
      expect(settings.editWindow!.endLabel, '3 กรกฎาคม 2568 เวลา 16:30 น.');
      await settleSnackBar(tester);
    });

    testWidgets(
      'ยังไม่เคยกำหนดงวด: บอกว่ายังไม่ได้กำหนด และบันทึกครั้งแรกได้',
      (tester) async {
        backend
          ..periodMonth = ''
          ..periodYear = '';
        await tester.runAsync(() => signIn(FakeBackend.account));
        await pump(tester, PeriodScreen(apiService: api));

        expect(
          tester.widget<Text>(find.byKey(PeriodScreen.currentKey)).data,
          Period.notSetLabel,
        );
        await tester.tap(find.byKey(const ValueKey('month-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(PeriodScreen.saveButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('บันทึก'));
        await tester.pumpAndSettle();

        expect(backend.periodMonth, '01');
        expect(backend.periodYear, matches(r'^25\d{2}$'));
        await settleSnackBar(tester);
      },
    );

    testWidgets('บัญชีที่ไม่ใช่ฝ่ายบัญชีบันทึก: แสดงข้อความ 403 ของ backend', (
      tester,
    ) async {
      await tester.runAsync(() => signIn(FakeBackend.user));
      await pump(tester, PeriodScreen(apiService: api));

      await tester.tap(find.byKey(const ValueKey('month-8')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PeriodScreen.saveButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();

      expect(find.text(FakeBackend.forbiddenMessage), findsOneWidget);
      expect(backend.periodMonth, '07');
      expect(
        tester.widget<Text>(find.byKey(PeriodScreen.currentKey)).data,
        'กรกฎาคม 2568',
      );
      expect(auth.isLoggedIn, isTrue);
    });
  });

  group('ข้อความแจ้งผู้ใช้งาน', () {
    final field = find.byKey(AlertMessageScreen.fieldKey);
    final save = find.byKey(AlertMessageScreen.saveButtonKey);
    String preview(WidgetTester tester) {
      final text = find.descendant(
        of: find.byKey(AlertMessageScreen.previewKey),
        matching: find.byKey(AlertMessageBox.textKey),
      );
      return tester.widget<SelectableText>(text).data!;
    }

    testWidgets(
      'โหลดข้อความเดิม ตัวอย่างเปลี่ยนตามที่พิมพ์ บันทึกแล้ว backend และ SettingsProvider ได้ข้อความใหม่',
      (tester) async {
        await tester.runAsync(() => signIn(FakeBackend.account));
        await pump(tester, AlertMessageScreen(apiService: api));

        expect(find.text(AlertMessageScreen.menuTitle), findsWidgets);
        expect(find.text(AlertMessageScreen.previewTitle), findsOneWidget);
        expect(
          tester.widget<TextField>(field).controller!.text,
          backend.alertMessage,
        );
        expect(preview(tester), backend.alertMessage);
        expect(tester.widget<PrimaryActionButton>(save).onPressed, isNull);

        const edited = 'ปิดรับข้อมูลงวดนี้วันที่ 3 กรกฎาคม 2568\nเวลา 11:00 น.';
        await tester.enterText(field, '  $edited \n');
        await tester.pumpAndSettle();
        // ตัวอย่างแสดงผลเปลี่ยนทันที ก่อนบันทึก
        expect(preview(tester), edited);
        expect(find.textContaining('ยังไม่ได้บันทึก'), findsOneWidget);
        expect(backend.alertMessage, isNot(edited));

        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(backend.bodyOf('PUT /api/alert-message'), {
          'msg': '  $edited \n',
        });
        // backend ตัดช่องว่างหัวท้าย หน้าจอใช้ข้อความที่ backend ตอบ
        expect(backend.alertMessage, edited);
        expect(tester.widget<TextField>(field).controller!.text, edited);
        expect(settings.alertMessage, edited);
        expect(find.text(AlertMessageScreen.savedMessage), findsOneWidget);
        expect(tester.widget<PrimaryActionButton>(save).onPressed, isNull);
        await settleSnackBar(tester);
      },
    );

    testWidgets('ลบข้อความทั้งหมดแล้วบันทึก: ตัวอย่างบอกว่าไม่มีข้อความแจ้ง', (
      tester,
    ) async {
      await tester.runAsync(() => signIn(FakeBackend.account));
      await pump(tester, AlertMessageScreen(apiService: api));

      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(AlertMessageScreen.previewKey),
          matching: find.text(AlertMessageBox.emptyText),
        ),
        findsOneWidget,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(backend.alertMessage, '');
      expect(settings.alertMessage, '');
      await settleSnackBar(tester);
    });

    testWidgets('ช่องกรอกจำกัด 5,000 ตัวอักษรตาม backend', (tester) async {
      await tester.runAsync(() => signIn(FakeBackend.account));
      await pump(tester, AlertMessageScreen(apiService: api));

      expect(tester.widget<TextField>(field).maxLength, 5000);
      expect(ApiService.alertMessageMaxLength, 5000);
      await tester.enterText(field, 'ก' * 5200);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text.length, 5000);
    });

    testWidgets(
      'บัญชีที่ไม่ใช่ฝ่ายบัญชีบันทึก: แสดงข้อความ 403 ข้อความเดิมไม่เปลี่ยน',
      (tester) async {
        final original = backend.alertMessage;
        await tester.runAsync(() => signIn(FakeBackend.admin));
        await pump(tester, AlertMessageScreen(apiService: api));

        await tester.enterText(field, 'ลองแก้');
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(find.text(FakeBackend.forbiddenMessage), findsOneWidget);
        expect(backend.alertMessage, original);
      },
    );
  });

  group('ระยะเวลาแก้ไขข้อมูล', () {
    final save = find.byKey(EditWindowScreen.saveButtonKey);
    final rangeField = fieldOf(EditWindowScreen.rangeKey);

    /// ตัวเลือกช่วงวันที่จำลอง: คืนช่วงตามลำดับที่เตรียมไว้ และจำช่วงตั้งต้นที่หน้าจอส่งมา
    Future<DateTimeRange?> Function(BuildContext, DateTimeRange?) picker(
      List<DateTimeRange?> answers,
      List<DateTimeRange?> seen,
    ) {
      var i = 0;
      return (context, initial) async {
        seen.add(initial);
        return answers[i++];
      };
    }

    String rangeText(WidgetTester tester) =>
        tester.widget<TextFormField>(rangeField).controller!.text;

    testWidgets(
      'แสดงค่าปัจจุบันเป็นวันที่ไทย สถานะเปิด และคำอธิบายว่าเป็นช่วงต่อเนื่องช่วงเดียว',
      (tester) async {
        await tester.runAsync(() => signIn(FakeBackend.account));
        await pump(tester, EditWindowScreen(apiService: api));

        expect(find.text(EditWindowScreen.menuTitle), findsOneWidget);
        expect(rangeText(tester), '23 มิถุนายน 2568 – 3 กรกฎาคม 2568');
        expect(
          tester
              .widget<TextFormField>(fieldOf(EditWindowScreen.beginTimeKey))
              .controller!
              .text,
          '06:00',
        );
        expect(
          tester
              .widget<TextFormField>(fieldOf(EditWindowScreen.endTimeKey))
              .controller!
              .text,
          '11:00',
        );
        expect(
          find.descendant(
            of: find.byKey(EditWindowScreen.statusKey),
            matching: find.text('เปิดให้แก้ไข'),
          ),
          findsOneWidget,
        );
        expect(
          find.text('เวลาของระบบ 25 มิถุนายน 2568 เวลา 09:30:00 น.'),
          findsOneWidget,
        );
        // คำอธิบายช่วงต่อเนื่อง + ตัวอย่าง + ข้อความสรุปของค่าที่กรอกอยู่
        expect(
          find.textContaining(EditWindowScreen.continuousNote),
          findsOneWidget,
        );
        expect(
          find.textContaining('ไม่ใช่ช่วงเวลาที่ซ้ำทุกวัน'),
          findsOneWidget,
        );
        expect(find.text(EditWindowScreen.accountNote), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(EditWindowScreen.summaryKey)).data,
          'แก้ไขได้ตั้งแต่ 23 มิถุนายน 2568 เวลา 06:00 น. '
          'ถึง 3 กรกฎาคม 2568 เวลา 11:00 น.',
        );
      },
    );

    testWidgets(
      'เลือกวันเริ่ม-สิ้นสุดในครั้งเดียว กรอกเวลา HH:MM แล้วบันทึก: ส่งวันที่ ค.ศ. และสถานะเปลี่ยนตาม backend',
      (tester) async {
        final seen = <DateTimeRange?>[];
        await tester.runAsync(() => signIn(FakeBackend.account));
        await pump(
          tester,
          EditWindowScreen(
            apiService: api,
            rangePicker: picker([
              null, // กดยกเลิกครั้งแรก
              DateTimeRange(
                start: DateTime(2026, 9, 21),
                end: DateTime(2026, 10, 5),
              ),
              DateTimeRange(
                start: DateTime(2026, 9, 21),
                end: DateTime(2026, 10, 5),
              ),
            ], seen),
          ),
        );

        // ยกเลิก: ค่าเดิมคงอยู่
        await tester.tap(rangeField);
        await tester.pumpAndSettle();
        expect(rangeText(tester), '23 มิถุนายน 2568 – 3 กรกฎาคม 2568');
        await tester.tap(rangeField);
        await tester.pumpAndSettle();
        // ปฏิทินเปิดที่ช่วงเดิมทั้งสองครั้ง
        final original = DateTimeRange(
          start: DateTime(2025, 6, 23),
          end: DateTime(2025, 7, 3),
        );
        expect(seen, [original, original]);
        expect(rangeText(tester), '21 กันยายน 2569 – 5 ตุลาคม 2569');
        // เลือกช่วงวันใหม่: เวลาที่โหลดมาจาก backend (06:00 / 11:00) คงอยู่ ไม่ถูกตั้งกลับ
        String time(Key key) =>
            tester.widget<TextFormField>(fieldOf(key)).controller!.text;
        expect(time(EditWindowScreen.beginTimeKey), '06:00');
        expect(time(EditWindowScreen.endTimeKey), '11:00');

        // ผู้ใช้แก้เวลา แล้วเลือกช่วงวันอีกรอบ: เวลาที่แก้ไว้ยังอยู่
        await tester.enterText(fieldOf(EditWindowScreen.beginTimeKey), '6:00');
        await tester.enterText(fieldOf(EditWindowScreen.endTimeKey), '16:30');
        await tester.pumpAndSettle();
        await tester.tap(rangeField);
        await tester.pumpAndSettle();
        expect(rangeText(tester), '21 กันยายน 2569 – 5 ตุลาคม 2569');
        expect(time(EditWindowScreen.beginTimeKey), '6:00');
        expect(time(EditWindowScreen.endTimeKey), '16:30');
        expect(
          tester.widget<Text>(find.byKey(EditWindowScreen.summaryKey)).data,
          'แก้ไขได้ตั้งแต่ 21 กันยายน 2569 เวลา 06:00 น. '
          'ถึง 5 ตุลาคม 2569 เวลา 16:30 น.',
        );

        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(backend.bodyOf('PUT /api/edit-window'), {
          'beginDate': '2026-09-21',
          'endDate': '2026-10-05',
          'beginTime': '06:00',
          'endTime': '16:30',
        });
        expect(find.text(EditWindowScreen.savedMessage), findsOneWidget);
        // เวลาของ backend จำลองคือ 25 มิ.ย. 2568 จึงอยู่นอกช่วงใหม่ = ปิด
        expect(
          find.descendant(
            of: find.byKey(EditWindowScreen.statusKey),
            matching: find.text('ปิด'),
          ),
          findsOneWidget,
        );
        expect(settings.editWindow!.open, isFalse);
        // ฝ่ายบัญชียังแก้ไขได้
        expect(settings.canEditNow, isTrue);
        expect(
          settings.editWindow!.beginLabel,
          '21 กันยายน 2569 เวลา 06:00 น.',
        );
        await settleSnackBar(tester);
      },
    );

    testWidgets('เวลาผิดรูป: เตือนใต้ช่อง ไม่เรียก backend', (tester) async {
      await tester.runAsync(() => signIn(FakeBackend.account));
      await pump(tester, EditWindowScreen(apiService: api));
      backend.clearLog();

      await tester.enterText(fieldOf(EditWindowScreen.beginTimeKey), '25:00');
      await tester.enterText(fieldOf(EditWindowScreen.endTimeKey), '1100');
      await tester.pumpAndSettle();
      // กรอกไม่ครบรูป: ไม่มีข้อความสรุป
      expect(find.byKey(EditWindowScreen.summaryKey), findsNothing);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text(EditWindowScreen.timeFormatMessage), findsNWidgets(2));
      expect(backend.calls, isEmpty);
    });

    testWidgets('วัน-เวลาสิ้นสุดก่อนวัน-เวลาเริ่ม: เตือน ไม่เรียก backend', (
      tester,
    ) async {
      await tester.runAsync(() => signIn(FakeBackend.account));
      final oneDay = DateTimeRange(
        start: DateTime(2025, 6, 23),
        end: DateTime(2025, 6, 23),
      );
      await pump(
        tester,
        EditWindowScreen(apiService: api, rangePicker: picker([oneDay], [])),
      );
      backend.clearLog();

      // ช่วงวันเดียว เวลาเริ่ม 06:00 เวลาสิ้นสุด 05:59
      await tester.tap(rangeField);
      await tester.pumpAndSettle();
      expect(rangeText(tester), '23 มิถุนายน 2568');
      await tester.enterText(fieldOf(EditWindowScreen.endTimeKey), '05:59');
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text(EditWindowScreen.orderMessage), findsOneWidget);
      expect(backend.calls, isEmpty);

      // วันเดียวกัน เวลาเท่ากัน = ช่วงหนึ่งนาที บันทึกได้
      await tester.enterText(fieldOf(EditWindowScreen.endTimeKey), '06:00');
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(backend.endDate, '2025-06-23');
      expect(backend.endTime, '06:00');
      await settleSnackBar(tester);
    });

    testWidgets('ยังไม่เคยตั้งระยะเวลา: ต้องเลือกช่วงวันที่ก่อนบันทึก', (
      tester,
    ) async {
      // backend ยังไม่มีทั้งวันที่และเวลา
      backend
        ..beginDate = null
        ..endDate = null
        ..beginTime = ''
        ..endTime = '';
      final seen = <DateTimeRange?>[];
      await tester.runAsync(() => signIn(FakeBackend.account));
      await pump(
        tester,
        EditWindowScreen(apiService: api, rangePicker: picker([null], seen)),
      );
      backend.clearLog();

      expect(find.text(EditWindow.notSetLabel), findsOneWidget);
      expect(rangeText(tester), '');
      // ช่องเวลายังไม่มีค่าจาก backend: เติมเวลาตั้งต้น 06:00 / 16:30
      expect(
        tester
            .widget<TextFormField>(fieldOf(EditWindowScreen.beginTimeKey))
            .controller!
            .text,
        EditWindowScreen.newBeginTime,
      );
      expect(
        tester
            .widget<TextFormField>(fieldOf(EditWindowScreen.endTimeKey))
            .controller!
            .text,
        '16:30',
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text(EditWindowScreen.dateRequiredMessage), findsOneWidget);
      expect(backend.calls, isEmpty);
      // ยังไม่มีช่วงเดิม: ปฏิทินเปิดแบบยังไม่เลือก
      await tester.ensureVisible(rangeField);
      await tester.pumpAndSettle();
      await tester.tap(rangeField);
      await tester.pumpAndSettle();
      expect(seen, [null]);
    });

    testWidgets(
      'ไม่ส่งตัวเลือกมา: เปิดปฏิทินช่วงวันที่ พ.ศ. ของระบบ เลือกช่วงใหม่ด้วยการแตะสองครั้งแล้วบันทึก',
      (tester) async {
        await tester.runAsync(() => signIn(FakeBackend.account));
        await pump(tester, EditWindowScreen(apiService: api));

        await tester.tap(rangeField);
        await tester.pumpAndSettle();
        expect(find.byType(ThaiDateRangePickerDialog), findsOneWidget);
        expect(find.text(EditWindowScreen.rangeHelpText), findsOneWidget);
        // จอกว้าง: สองเดือนเคียงกัน เปิดที่เดือนของวันเริ่มเดิม ปีเป็น พ.ศ.
        expect(find.text('มิถุนายน 2568'), findsOneWidget);
        expect(find.text('กรกฎาคม 2568'), findsOneWidget);
        expect(find.textContaining('2025'), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(ThaiDateRangePickerDialog.rangeKey))
              .data,
          '23 มิถุนายน 2568 – 3 กรกฎาคม 2568',
        );

        await tester.tap(
          find.byKey(ThaiDateRangePickerDialog.dayKey(DateTime(2025, 6, 30))),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ThaiDateRangePickerDialog.dayKey(DateTime(2025, 7, 15))),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ThaiDateRangePickerDialog.okKey));
        await tester.pumpAndSettle();

        expect(find.byType(ThaiDateRangePickerDialog), findsNothing);
        expect(rangeText(tester), '30 มิถุนายน 2568 – 15 กรกฎาคม 2568');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(backend.beginDate, '2025-06-30');
        expect(backend.endDate, '2025-07-15');
        await settleSnackBar(tester);
      },
    );

    testWidgets(
      'บัญชีที่ไม่ใช่ฝ่ายบัญชีบันทึก: แสดงข้อความ 403 ค่าเดิมไม่เปลี่ยน',
      (tester) async {
        await tester.runAsync(() => signIn(FakeBackend.user));
        await pump(tester, EditWindowScreen(apiService: api));

        await tester.enterText(fieldOf(EditWindowScreen.endTimeKey), '12:00');
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(find.text(FakeBackend.forbiddenMessage), findsOneWidget);
        expect(backend.endTime, '11:00');
      },
    );
  });

  test('API ค่าตั้งกลาง: ทุกบัญชีอ่านได้ แก้ได้เฉพาะ ACCOUNT', () async {
    for (final u in [
      FakeBackend.user,
      FakeBackend.resetPwd,
      FakeBackend.centerDept,
      FakeBackend.allDept,
      FakeBackend.admin,
    ]) {
      await signIn(u);
      expect((await api.getPeriod()).label, 'กรกฎาคม 2568', reason: u);
      expect((await api.getEditWindow()).isSet, isTrue, reason: u);
      for (final write in [
        () => api.updatePeriod(Period.of(1, 2569)),
        () => api.updateAlertMessage('x'),
        () => api.updateEditWindow(
          beginDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 1, 2),
          beginTime: '06:00',
          endTime: '11:00',
        ),
      ]) {
        await expectLater(
          write(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ErrorCodes.forbidden,
            ),
          ),
          reason: u,
        );
      }
      await auth.logout();
    }
    expect(backend.periodMonth, '07');

    await signIn(FakeBackend.account);
    expect((await api.updatePeriod(Period.of(1, 2569))).label, 'มกราคม 2569');
    await expectLater(
      api.updateEditWindow(
        beginDate: DateTime(2025, 1, 2),
        endDate: DateTime(2025, 1, 1),
        beginTime: '06:00',
        endTime: '11:00',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ErrorCodes.badRequest)
            .having(
              (e) => e.toString(),
              'message',
              FakeBackend.windowOrderMessage,
            ),
      ),
    );
  });
}
