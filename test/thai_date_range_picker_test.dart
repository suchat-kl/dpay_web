// เทสต์ตัวเลือกช่วงวันที่ พ.ศ. (showThaiDateRangePicker): แตะสองครั้ง ลาก ข้ามเดือน/ปี ขอบ first/last
// สองเดือนบนจอกว้าง เดือนเดียวบนจอแคบ ปุ่มวันนี้ ตัวเลือกปี/เดือน และยกเลิก

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/widgets/thai_date_range_picker.dart';

import 'fake_backend.dart';

typedef _P = ThaiDateRangePickerDialog;

void main() {
  setUpAll(loadAppFonts);

  final today = DateTime(2026, 9, 10);

  /// เปิดปฏิทินจากปุ่มบนหน้าเปล่า คืนตัวเก็บผลที่ปฏิทินคืนตอนปิด (ยังไม่ปิด = ว่าง)
  Future<List<DateTimeRange?>> open(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
    DateTime? start,
    DateTime? end,
    DateTime? first,
    DateTime? last,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <DateTimeRange?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showThaiDateRangePicker(
                  context,
                  initialStart: start,
                  initialEnd: end,
                  firstDate: first,
                  lastDate: last,
                  today: today,
                ),
              ),
              child: const Text('เปิด'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    return results;
  }

  Finder day(int y, int m, int d) => find.byKey(_P.dayKey(DateTime(y, m, d)));

  String header(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(_P.rangeKey)).data!;

  bool okEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(_P.okKey)).onPressed != null;

  Future<void> tapDay(WidgetTester tester, int y, int m, int d) async {
    await tester.tap(day(y, m, d));
    await tester.pumpAndSettle();
  }

  /// กดค้างที่วันแรกแล้วลากผ่านจุดกลางทางไปปล่อยที่วันสุดท้าย
  Future<void> dragDays(
    WidgetTester tester,
    Finder from,
    Finder to, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final a = tester.getCenter(from);
    final b = tester.getCenter(to);
    final gesture = await tester.startGesture(a, kind: kind);
    await tester.pump();
    for (var i = 1; i <= 4; i++) {
      await gesture.moveTo(Offset.lerp(a, b, i / 4)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> ok(WidgetTester tester) async {
    await tester.tap(find.byKey(_P.okKey));
    await tester.pumpAndSettle();
  }

  group('จอกว้าง (สองเดือนเคียงกัน)', () {
    testWidgets(
      'เปิดที่เดือนของวันนี้ หัวเดือนเป็นไทย ปี พ.ศ. สัปดาห์เริ่มวันอาทิตย์ ยังไม่เลือก = ตกลงกดไม่ได้',
      (tester) async {
        final results = await open(tester);

        expect(find.text('กันยายน 2569'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(_P.secondTitleKey)).data,
          'ตุลาคม 2569',
        );
        expect(find.textContaining('2026'), findsNothing);
        // หัวคอลัมน์วันของทั้งสองเดือน เริ่มวันอาทิตย์
        expect(find.text('อา'), findsNWidgets(2));
        expect(
          tester.getCenter(find.text('อา').first).dx,
          lessThan(tester.getCenter(find.text('จ').first).dx),
        );
        // 1 ก.ย. 2569 (ค.ศ. 2026) เป็นวันอังคาร = คอลัมน์ที่สาม
        expect(
          tester.getCenter(day(2026, 9, 1)).dx,
          closeTo(tester.getCenter(find.text('อ').first).dx, 1),
        );
        // เดือนที่สองอยู่ทางขวาของเดือนแรก แถวเดียวกัน
        expect(
          tester.getCenter(day(2026, 10, 1)).dx,
          greaterThan(tester.getCenter(day(2026, 9, 30)).dx),
        );
        expect(header(tester), _P.pickStartText);
        expect(okEnabled(tester), isFalse);
        expect(results, isEmpty);
      },
    );

    testWidgets(
      'แตะวันเริ่มแล้วแตะวันสิ้นสุดข้ามเดือน: แถบหัวเป็นวันที่ไทย กดตกลงคืนช่วง ค.ศ.',
      (tester) async {
        final results = await open(tester);

        await tapDay(tester, 2026, 9, 21);
        expect(header(tester), '21 กันยายน 2569 – ${_P.pickEndText}');
        expect(okEnabled(tester), isFalse);

        await tapDay(tester, 2026, 10, 5);
        expect(header(tester), '21 กันยายน 2569 – 5 ตุลาคม 2569');
        expect(okEnabled(tester), isTrue);

        await ok(tester);
        expect(find.byType(_P), findsNothing);
        expect(results, [
          DateTimeRange(
            start: DateTime(2026, 9, 21),
            end: DateTime(2026, 10, 5),
          ),
        ]);
        // ไม่มีเวลาติดมา
        expect(results.single!.start.hour, 0);
      },
    );

    testWidgets('ช่วงที่เลือกถูกแรเงา ปลายทั้งสองเป็นวงทึบสีธีม', (
      tester,
    ) async {
      await open(tester);
      await tapDay(tester, 2026, 9, 21);
      await tapDay(tester, 2026, 9, 24);

      Color circle(int d) => tester
          .widget<Material>(
            find.descendant(
              of: day(2026, 9, d),
              matching: find.byType(Material),
            ),
          )
          .color!;
      int bands(int d) => tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: day(2026, 9, d),
              matching: find.byType(ColoredBox),
            ),
          )
          .where((b) => b.color != Colors.transparent)
          .length;

      expect(circle(21), AppTheme.primaryColor);
      expect(circle(24), AppTheme.primaryColor);
      expect(circle(22), Colors.transparent);
      // วันระหว่างกลางแรเงาเต็มช่อง ปลายช่วงแรเงาครึ่งช่อง นอกช่วงไม่แรเงา
      expect(bands(22), 2);
      expect(bands(23), 2);
      expect(bands(21), 1);
      expect(bands(24), 1);
      expect(bands(20), 0);
      expect(bands(25), 0);
    });

    testWidgets(
      'แตะวันก่อนวันเริ่ม = เริ่มช่วงใหม่ และเลือกครบแล้วแตะอีก = เริ่มใหม่',
      (tester) async {
        await open(tester);
        await tapDay(tester, 2026, 9, 21);
        await tapDay(tester, 2026, 9, 15);
        expect(header(tester), '15 กันยายน 2569 – ${_P.pickEndText}');
        expect(okEnabled(tester), isFalse);

        await tapDay(tester, 2026, 9, 18);
        expect(header(tester), '15 กันยายน 2569 – 18 กันยายน 2569');

        await tapDay(tester, 2026, 9, 25);
        expect(header(tester), '25 กันยายน 2569 – ${_P.pickEndText}');
        expect(okEnabled(tester), isFalse);
      },
    );

    testWidgets('แตะวันเดิมซ้ำ: ช่วงวันเดียว (เริ่ม = สิ้นสุด)', (
      tester,
    ) async {
      final results = await open(tester);
      await tapDay(tester, 2026, 9, 21);
      await tapDay(tester, 2026, 9, 21);

      expect(header(tester), '21 กันยายน 2569');
      await ok(tester);
      expect(results.single!.start, DateTime(2026, 9, 21));
      expect(results.single!.end, DateTime(2026, 9, 21));
      expect(results.single!.duration, Duration.zero);
    });

    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testWidgets('ลากจากวันเริ่มไปวันสิ้นสุด (${kind.name})', (tester) async {
        final results = await open(tester);
        await dragDays(tester, day(2026, 9, 8), day(2026, 9, 17), kind: kind);

        expect(header(tester), '8 กันยายน 2569 – 17 กันยายน 2569');
        expect(okEnabled(tester), isTrue);
        await ok(tester);
        expect(results, [
          DateTimeRange(
            start: DateTime(2026, 9, 8),
            end: DateTime(2026, 9, 17),
          ),
        ]);
      });
    }

    testWidgets('ลากข้ามจากเดือนแรกไปเดือนที่สอง และลากย้อนกลับ', (
      tester,
    ) async {
      await open(tester);
      await dragDays(tester, day(2026, 9, 28), day(2026, 10, 6));
      expect(header(tester), '28 กันยายน 2569 – 6 ตุลาคม 2569');

      // ลากย้อน: จุดที่กดเป็นวันสิ้นสุด จุดที่ปล่อยเป็นวันเริ่ม
      await dragDays(tester, day(2026, 10, 20), day(2026, 9, 9));
      expect(header(tester), '9 กันยายน 2569 – 20 ตุลาคม 2569');
    });

    testWidgets(
      'ระหว่างลากช่วงเปลี่ยนตามนิ้ว และหลังลากเสร็จแตะต่อได้ตามปกติ',
      (tester) async {
        await open(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(day(2026, 9, 8)),
        );
        await tester.pump();
        // ยังไม่ขยับ = ยังไม่เลือกอะไร
        expect(header(tester), _P.pickStartText);
        await gesture.moveTo(tester.getCenter(day(2026, 9, 10)));
        await tester.pump();
        expect(header(tester), '8 กันยายน 2569 – 10 กันยายน 2569');
        await gesture.moveTo(tester.getCenter(day(2026, 9, 16)));
        await tester.pump();
        expect(header(tester), '8 กันยายน 2569 – 16 กันยายน 2569');
        // ลากกลับมาให้สั้นลงได้
        await gesture.moveTo(tester.getCenter(day(2026, 9, 9)));
        await tester.pump();
        expect(header(tester), '8 กันยายน 2569 – 9 กันยายน 2569');
        await gesture.up();
        await tester.pumpAndSettle();
        expect(header(tester), '8 กันยายน 2569 – 9 กันยายน 2569');

        // แตะหลังลาก = เริ่มช่วงใหม่ตามปกติ
        await tapDay(tester, 2026, 9, 22);
        expect(header(tester), '22 กันยายน 2569 – ${_P.pickEndText}');
      },
    );

    testWidgets('เลื่อนเดือนข้ามปี แล้วเลือกช่วงข้ามปี', (tester) async {
      final results = await open(
        tester,
        start: DateTime(2026, 11, 20),
        end: DateTime(2026, 11, 25),
      );
      expect(find.text('พฤศจิกายน 2569'), findsOneWidget);
      expect(header(tester), '20 พฤศจิกายน 2569 – 25 พฤศจิกายน 2569');

      await tester.tap(find.byKey(_P.nextKey));
      await tester.pumpAndSettle();
      expect(find.text('ธันวาคม 2569'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(_P.secondTitleKey)).data,
        'มกราคม 2570',
      );
      // เลื่อนเดือนไม่เปลี่ยนช่วงที่เลือก
      expect(header(tester), '20 พฤศจิกายน 2569 – 25 พฤศจิกายน 2569');

      await tapDay(tester, 2026, 12, 28);
      await tapDay(tester, 2027, 1, 4);
      expect(header(tester), '28 ธันวาคม 2569 – 4 มกราคม 2570');
      await ok(tester);
      expect(results.single!.start, DateTime(2026, 12, 28));
      expect(results.single!.end, DateTime(2027, 1, 4));

      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_P.prevKey));
      await tester.pumpAndSettle();
      expect(find.text('ตุลาคม 2569'), findsOneWidget);
    });

    testWidgets(
      'เลือกปีและเดือนแบบเร็ว: ปีเป็น พ.ศ. ช่วงที่เลือกไว้ไม่เปลี่ยน',
      (tester) async {
        await open(
          tester,
          start: DateTime(2026, 9, 21),
          end: DateTime(2026, 10, 5),
        );
        await tester.tap(find.byKey(_P.titleKey));
        await tester.pumpAndSettle();
        expect(find.byKey(_P.yearKey(2569)), findsOneWidget);
        expect(find.byKey(_P.yearKey(2026)), findsNothing);
        expect(find.byKey(_P.secondTitleKey), findsNothing);

        await tester.tap(find.byKey(_P.yearKey(2570)));
        await tester.pumpAndSettle();
        expect(find.text('กุมภาพันธ์'), findsOneWidget);
        await tester.tap(find.byKey(_P.monthKey(2)));
        await tester.pumpAndSettle();

        expect(find.text('กุมภาพันธ์ 2570'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(_P.secondTitleKey)).data,
          'มีนาคม 2570',
        );
        // ก.พ. 2570 (ค.ศ. 2027) ไม่ใช่ปีอธิกสุรทิน
        expect(day(2027, 2, 28), findsOneWidget);
        expect(find.byKey(const ValueKey('tdrp-day-2027-02-29')), findsNothing);
        expect(header(tester), '21 กันยายน 2569 – 5 ตุลาคม 2569');

        // แตะหัวซ้ำตอนอยู่ในตัวเลือกปี = กลับตารางวัน
        await tester.tap(find.byKey(_P.titleKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_P.titleKey));
        await tester.pumpAndSettle();
        expect(day(2027, 2, 1), findsOneWidget);
      },
    );

    testWidgets('ปุ่มวันนี้: พาไปเดือนปัจจุบัน ไม่เปลี่ยนช่วงที่เลือก', (
      tester,
    ) async {
      await open(
        tester,
        start: DateTime(2025, 6, 23),
        end: DateTime(2025, 7, 3),
      );
      expect(find.text('มิถุนายน 2568'), findsOneWidget);

      await tester.tap(find.byKey(_P.todayKey));
      await tester.pumpAndSettle();
      expect(find.text('กันยายน 2569'), findsOneWidget);
      expect(day(2026, 9, 10), findsOneWidget);
      expect(header(tester), '23 มิถุนายน 2568 – 3 กรกฎาคม 2568');
      expect(okEnabled(tester), isTrue);

      // ใช้ได้จากตัวเลือกปีด้วย
      await tester.tap(find.byKey(_P.prevKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_P.titleKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_P.todayKey));
      await tester.pumpAndSettle();
      expect(find.text('กันยายน 2569'), findsOneWidget);
    });

    testWidgets(
      'ขอบ first/last: วันนอกช่วงแตะและลากไม่ได้ ปุ่มเลื่อนเดือนหยุดที่ขอบ',
      (tester) async {
        await open(
          tester,
          first: DateTime(2026, 9, 5),
          last: DateTime(2026, 10, 20),
        );

        expect(
          tester.widget<IconButton>(find.byKey(_P.prevKey)).onPressed,
          isNull,
        );
        expect(
          tester.widget<IconButton>(find.byKey(_P.nextKey)).onPressed,
          isNull,
        );

        await tester.tap(day(2026, 9, 4), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(header(tester), _P.pickStartText);

        await tapDay(tester, 2026, 9, 5);
        await tester.tap(day(2026, 10, 21), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(header(tester), '5 กันยายน 2569 – ${_P.pickEndText}');
        await tapDay(tester, 2026, 10, 20);
        expect(header(tester), '5 กันยายน 2569 – 20 ตุลาคม 2569');

        // ลากในแถวเดียวกันเลยขอบ (จันทร์ 19 -> เสาร์ 24): ช่วงหยุดที่วันสุดท้ายที่เลือกได้
        await dragDays(tester, day(2026, 10, 19), day(2026, 10, 24));
        expect(header(tester), '19 ตุลาคม 2569 – 20 ตุลาคม 2569');
        // เริ่มลากจากวันนอกช่วง: ไม่เกิดอะไร
        await dragDays(tester, day(2026, 9, 2), day(2026, 9, 10));
        expect(header(tester), '19 ตุลาคม 2569 – 20 ตุลาคม 2569');
      },
    );

    testWidgets('ช่วงตั้งต้นที่อยู่นอกขอบหรือสลับลำดับ: ปรับให้ถูก ไม่ล้ม', (
      tester,
    ) async {
      await open(
        tester,
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 8, 1),
        first: DateTime(2026, 9, 1),
        last: DateTime(2026, 12, 31),
      );
      expect(header(tester), '1 กันยายน 2569 – 5 ตุลาคม 2569');
      expect(find.text('กันยายน 2569'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ยกเลิก / Esc / แตะนอกหน้าต่าง: คืน null', (tester) async {
      final results = await open(tester);
      await tapDay(tester, 2026, 9, 21);
      await tapDay(tester, 2026, 9, 25);
      await tester.tap(find.byKey(_P.cancelKey));
      await tester.pumpAndSettle();
      expect(results, [null]);

      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(_P), findsNothing);
      expect(results, [null, null]);

      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(results, [null, null, null]);
    });

    testWidgets(
      'คีย์บอร์ด: วันเริ่มได้โฟกัสตอนเปิด กด Enter เลือกได้ แม้เพิ่งลากมา',
      (tester) async {
        await open(
          tester,
          start: DateTime(2026, 9, 21),
          end: DateTime(2026, 9, 25),
        );
        await dragDays(tester, day(2026, 9, 8), day(2026, 9, 10));
        expect(header(tester), '8 กันยายน 2569 – 10 กันยายน 2569');

        // โฟกัสอยู่ที่วันเริ่มของช่วงใหม่ กด Enter = แตะวันนั้น (เริ่มช่วงใหม่)
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(header(tester), endsWith(_P.pickEndText));
      },
    );

    testWidgets('ใช้สีของธีมปัจจุบัน', (tester) async {
      final before = AppTheme.current.id;
      addTearDown(() => AppTheme.select(before));
      AppTheme.select(AppTheme.palettes[3].id);
      await open(tester);
      await tapDay(tester, 2026, 9, 21);

      final circle = tester.widget<Material>(
        find.descendant(of: day(2026, 9, 21), matching: find.byType(Material)),
      );
      expect(circle.color, AppTheme.palettes[3].primary);
    });
  });

  group('จอแคบ 320 จุด (เดือนเดียว)', () {
    const phone = Size(320, 640);

    testWidgets('แสดงเดือนเดียว ทุกมุมมองไม่ล้นกรอบ แตะสองครั้งและลากได้', (
      tester,
    ) async {
      final results = await open(tester, size: phone);

      expect(find.text('กันยายน 2569'), findsOneWidget);
      expect(find.byKey(_P.secondTitleKey), findsNothing);
      expect(day(2026, 10, 1), findsNothing);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(_P));
      expect(rect.width, lessThanOrEqualTo(320));
      for (final key in [_P.todayKey, _P.cancelKey, _P.okKey]) {
        final r = tester.getRect(find.byKey(key));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(320));
      }

      // แตะวันเริ่ม เลื่อนไปเดือนถัดไป แล้วแตะวันสิ้นสุด
      await tapDay(tester, 2026, 9, 21);
      await tester.tap(find.byKey(_P.nextKey));
      await tester.pumpAndSettle();
      expect(find.text('ตุลาคม 2569'), findsOneWidget);
      await tapDay(tester, 2026, 10, 5);
      expect(header(tester), '21 กันยายน 2569 – 5 ตุลาคม 2569');
      expect(tester.takeException(), isNull);

      // ลากในเดือนเดียว
      await dragDays(tester, day(2026, 10, 12), day(2026, 10, 23));
      expect(header(tester), '12 ตุลาคม 2569 – 23 ตุลาคม 2569');

      // ตัวเลือกปี / เดือน
      await tester.tap(find.byKey(_P.titleKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(_P.yearKey(2569)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(_P.monthKey(10)));
      await tester.pumpAndSettle();

      await ok(tester);
      expect(results, [
        DateTimeRange(
          start: DateTime(2026, 10, 12),
          end: DateTime(2026, 10, 23),
        ),
      ]);
    });

    testWidgets(
      'จอเตี้ย 320x400: เลื่อนหน้าต่างได้ ไม่ล้น ปุ่มตกลงกดได้หลังเลื่อน',
      (tester) async {
        final results = await open(
          tester,
          size: const Size(320, 400),
          start: DateTime(2026, 9, 21),
          end: DateTime(2026, 9, 25),
        );
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.byKey(_P.okKey));
        await tester.pumpAndSettle();
        await ok(tester);
        expect(results.single!.end, DateTime(2026, 9, 25));
      },
    );

    testWidgets('จอกว้างปานกลาง 700 จุด: ยังเป็นเดือนเดียว', (tester) async {
      await open(tester, size: const Size(700, 800));
      expect(find.byKey(_P.secondTitleKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
