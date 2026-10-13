// เทสต์ตัวเลือกวันที่แบบ พ.ศ. (lib/widgets/thai_date_picker.dart)
//
// "วันนี้" ตรึงเป็น 13 ตุลาคม 2569 (ค.ศ. 2026) ค่าที่คืนเป็น DateTime ค.ศ. ตามปกติ

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/widgets/thai_date_picker.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  final today = DateTime(2026, 10, 13);

  /// เปิดปฏิทินจากปุ่ม แล้วเก็บผลที่ได้ (รายการว่าง = ยังไม่ปิด)
  Future<List<DateTime?>> open(
    WidgetTester tester,
    DateTime? initial, {
    DateTime? firstDate,
    DateTime? lastDate,
    bool startWithYear = false,
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await showThaiDatePicker(
                    context,
                    initial,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    startWithYear: startWithYear,
                    today: today,
                  ),
                );
              },
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

  String title(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ThaiDatePickerDialog.titleKey),
          matching: find.byType(Text),
        ),
      )
      .data!;
  String selected(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(ThaiDatePickerDialog.selectedKey)).data!;
  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  bool dayEnabled(WidgetTester tester, int day) =>
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(ThaiDatePickerDialog.dayKey(day)),
              matching: find.byType(InkWell),
            ),
          )
          .onTap !=
      null;
  bool monthEnabled(WidgetTester tester, int month) =>
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(ThaiDatePickerDialog.monthKey(month)),
              matching: find.byType(InkWell),
            ),
          )
          .onTap !=
      null;
  bool navEnabled(WidgetTester tester, Key key) =>
      tester.widget<IconButton>(find.byKey(key)).onPressed != null;

  testWidgets(
    'หัวปฏิทินและวันที่ที่เลือกเป็น พ.ศ. ชื่อเดือนไทย สัปดาห์เริ่มวันอาทิตย์',
    (tester) async {
      await open(tester, DateTime(2026, 8, 18, 14, 30));

      expect(find.text('เลือกวันที่'), findsOneWidget);
      expect(title(tester), 'สิงหาคม 2569');
      expect(selected(tester), 'อังคาร 18 สิงหาคม 2569');
      // ไม่มีปี ค.ศ. บนจอ
      expect(find.textContaining('2026'), findsNothing);

      // หัวคอลัมน์เรียง อา จ อ พ พฤ ศ ส จากซ้ายไปขวา
      expect(ThaiDatePickerDialog.weekdayLabels.first, 'อา');
      final xs = [
        for (final w in ['อา', 'จ', 'พฤ', 'ส'])
          tester.getCenter(find.text(w)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      // 1 ส.ค. 2569 เป็นวันเสาร์ (คอลัมน์ขวาสุด) 2 ส.ค. เป็นวันอาทิตย์ (ซ้ายสุด แถวถัดไป)
      final d1 = tester.getCenter(find.byKey(ThaiDatePickerDialog.dayKey(1)));
      final d2 = tester.getCenter(find.byKey(ThaiDatePickerDialog.dayKey(2)));
      expect(d1.dx, moreOrLessEquals(tester.getCenter(find.text('ส')).dx));
      expect(d2.dx, moreOrLessEquals(tester.getCenter(find.text('อา')).dx));
      expect(d2.dy, greaterThan(d1.dy));
      // สิงหาคมมี 31 วัน
      expect(find.byKey(ThaiDatePickerDialog.dayKey(31)), findsOneWidget);
      expect(find.byKey(ThaiDatePickerDialog.dayKey(32)), findsNothing);
    },
  );

  testWidgets('เลือกวันแล้วกดตกลง: ได้ DateTime ค.ศ. ไม่มีเวลา', (
    tester,
  ) async {
    final results = await open(tester, DateTime(2026, 8, 18, 14, 30));

    await tapKey(tester, ThaiDatePickerDialog.dayKey(20));
    expect(selected(tester), 'พฤหัสบดี 20 สิงหาคม 2569');
    expect(results, isEmpty, reason: 'แตะวันยังไม่ปิด ต้องกดตกลง');

    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2026, 8, 20)]);
    expect(find.byType(ThaiDatePickerDialog), findsNothing);
  });

  testWidgets('กดตกลงโดยไม่แตะอะไร: ได้วันตั้งต้น', (tester) async {
    final results = await open(tester, DateTime(2026, 8, 18));
    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2026, 8, 18)]);
  });

  testWidgets('ยกเลิก / กด Esc: คืน null', (tester) async {
    final results = await open(tester, DateTime(2026, 8, 18));
    await tapKey(tester, ThaiDatePickerDialog.dayKey(25));
    await tapKey(tester, ThaiDatePickerDialog.cancelKey);
    expect(results, [null]);

    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, [null, null]);
  });

  testWidgets('ไม่ส่งวันตั้งต้น: เปิดที่วันนี้ และวันนี้มีวงเครื่องหมาย', (
    tester,
  ) async {
    final results = await open(tester, null);

    expect(title(tester), 'ตุลาคม 2569');
    expect(selected(tester), 'อังคาร 13 ตุลาคม 2569');

    // เลือกวันอื่น: วันนี้ยังมีเส้นขอบ วันอื่นไม่มี
    await tapKey(tester, ThaiDatePickerDialog.dayKey(20));
    ShapeBorder shapeOf(int day) => tester
        .widget<Material>(
          find.descendant(
            of: find.byKey(ThaiDatePickerDialog.dayKey(day)),
            matching: find.byType(Material),
          ),
        )
        .shape!;
    expect((shapeOf(13) as CircleBorder).side.width, greaterThan(0));
    expect((shapeOf(14) as CircleBorder).side, BorderSide.none);

    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2026, 10, 20)]);
  });

  testWidgets('ปุ่มเลื่อนเดือน: ข้ามปีไปข้างหน้าและย้อนกลับ', (tester) async {
    final results = await open(tester, DateTime(2026, 12, 15));
    expect(title(tester), 'ธันวาคม 2569');

    await tapKey(tester, ThaiDatePickerDialog.nextKey);
    expect(title(tester), 'มกราคม 2570');
    // เลื่อนเดือนเฉย ๆ ยังไม่เปลี่ยนวันที่ที่เลือก
    expect(selected(tester), 'อังคาร 15 ธันวาคม 2569');

    await tapKey(tester, ThaiDatePickerDialog.prevKey);
    await tapKey(tester, ThaiDatePickerDialog.prevKey);
    expect(title(tester), 'พฤศจิกายน 2569');

    await tapKey(tester, ThaiDatePickerDialog.nextKey);
    await tapKey(tester, ThaiDatePickerDialog.nextKey);
    await tapKey(tester, ThaiDatePickerDialog.dayKey(1));
    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2027, 1, 1)]);
  });

  testWidgets(
    'เลือกปีและเดือนแบบเร็ว: ตัวเลือกปีเป็น พ.ศ. แล้วเลือกเดือน แล้วกลับมาที่ตารางวัน',
    (tester) async {
      final results = await open(tester, DateTime(2026, 8, 18));

      await tapKey(tester, ThaiDatePickerDialog.titleKey);
      // ตัวเลือกปี: เห็นปีที่แสดงอยู่ และไม่มีเลข ค.ศ.
      expect(find.byKey(ThaiDatePickerDialog.yearKey(2569)), findsOneWidget);
      expect(find.text('2569'), findsOneWidget);
      expect(find.text('2026'), findsNothing);
      expect(find.byKey(ThaiDatePickerDialog.dayKey(18)), findsNothing);
      // ระหว่างเลือกปี/เดือน ปุ่มเลื่อนเดือนกดไม่ได้
      expect(navEnabled(tester, ThaiDatePickerDialog.nextKey), isFalse);

      await tapKey(tester, ThaiDatePickerDialog.yearKey(2571));
      // ต่อด้วยตัวเลือกเดือน ชื่อเดือนไทยครบ 12 เดือน
      expect(find.text('มกราคม'), findsOneWidget);
      expect(find.text('ธันวาคม'), findsOneWidget);
      await tapKey(tester, ThaiDatePickerDialog.monthKey(3));

      expect(title(tester), 'มีนาคม 2571');
      // วันที่เลือกตามไปเดือน/ปีใหม่ (วันที่เดิม)
      expect(selected(tester), 'เสาร์ 18 มีนาคม 2571');
      await tapKey(tester, ThaiDatePickerDialog.dayKey(5));
      await tapKey(tester, ThaiDatePickerDialog.okKey);
      expect(results, [DateTime(2028, 3, 5)]);
    },
  );

  testWidgets(
    'แตะหัวตารางซ้ำตอนอยู่ในตัวเลือกปี: กลับไปตารางวันโดยไม่เปลี่ยนอะไร',
    (tester) async {
      await open(tester, DateTime(2026, 8, 18));
      await tapKey(tester, ThaiDatePickerDialog.titleKey);
      await tapKey(tester, ThaiDatePickerDialog.titleKey);

      expect(find.byKey(ThaiDatePickerDialog.dayKey(18)), findsOneWidget);
      expect(title(tester), 'สิงหาคม 2569');
      expect(selected(tester), 'อังคาร 18 สิงหาคม 2569');
    },
  );

  testWidgets(
    '29 กุมภาพันธ์: ปีอธิกสุรทินมี 29 วัน ปีปกติมี 28 และเลือก 29 ก.พ. ได้ถูกวัน',
    (tester) async {
      // พ.ศ. 2571 = ค.ศ. 2028 เป็นปีอธิกสุรทิน
      final results = await open(tester, DateTime(2028, 2, 10));
      expect(title(tester), 'กุมภาพันธ์ 2571');
      expect(find.byKey(ThaiDatePickerDialog.dayKey(29)), findsOneWidget);
      expect(find.byKey(ThaiDatePickerDialog.dayKey(30)), findsNothing);

      await tapKey(tester, ThaiDatePickerDialog.dayKey(29));
      expect(selected(tester), 'อังคาร 29 กุมภาพันธ์ 2571');

      // ย้ายไปปีที่ไม่ใช่อธิกสุรทิน: 29 ก.พ. ถูกปรับเป็น 28 ก.พ. ไม่ล้นไปเดือนมีนาคม
      await tapKey(tester, ThaiDatePickerDialog.titleKey);
      await tapKey(tester, ThaiDatePickerDialog.yearKey(2570));
      await tapKey(tester, ThaiDatePickerDialog.monthKey(2));
      expect(title(tester), 'กุมภาพันธ์ 2570');
      expect(find.byKey(ThaiDatePickerDialog.dayKey(28)), findsOneWidget);
      expect(find.byKey(ThaiDatePickerDialog.dayKey(29)), findsNothing);
      expect(selected(tester), 'อาทิตย์ 28 กุมภาพันธ์ 2570');

      // กลับมาปีอธิกสุรทินแล้วเลือก 29 ก.พ.
      await tapKey(tester, ThaiDatePickerDialog.titleKey);
      await tapKey(tester, ThaiDatePickerDialog.yearKey(2571));
      await tapKey(tester, ThaiDatePickerDialog.monthKey(2));
      await tapKey(tester, ThaiDatePickerDialog.dayKey(29));
      await tapKey(tester, ThaiDatePickerDialog.okKey);
      expect(results, [DateTime(2028, 2, 29)]);
    },
  );

  testWidgets('วันที่ 31 ย้ายไปเดือนที่มี 30 วัน: ปรับเป็นวันสุดท้ายของเดือน', (
    tester,
  ) async {
    final results = await open(tester, DateTime(2026, 8, 31));
    await tapKey(tester, ThaiDatePickerDialog.titleKey);
    await tapKey(tester, ThaiDatePickerDialog.yearKey(2569));
    await tapKey(tester, ThaiDatePickerDialog.monthKey(9));

    expect(selected(tester), 'พุธ 30 กันยายน 2569');
    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2026, 9, 30)]);
  });

  testWidgets('ขอบ first/last: วันนอกช่วงกดไม่ได้ ปุ่มเลื่อนเดือนหยุดที่ขอบ', (
    tester,
  ) async {
    final results = await open(
      tester,
      DateTime(2026, 3, 15),
      firstDate: DateTime(2026, 3, 10),
      lastDate: DateTime(2026, 4, 20),
    );

    expect(dayEnabled(tester, 9), isFalse);
    expect(dayEnabled(tester, 10), isTrue);
    expect(dayEnabled(tester, 31), isTrue);
    expect(navEnabled(tester, ThaiDatePickerDialog.prevKey), isFalse);
    expect(navEnabled(tester, ThaiDatePickerDialog.nextKey), isTrue);

    // แตะวันนอกช่วง: ไม่มีผล
    await tester.tap(
      find.byKey(ThaiDatePickerDialog.dayKey(9)),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(selected(tester), 'อาทิตย์ 15 มีนาคม 2569');

    await tapKey(tester, ThaiDatePickerDialog.nextKey);
    expect(title(tester), 'เมษายน 2569');
    expect(dayEnabled(tester, 20), isTrue);
    expect(dayEnabled(tester, 21), isFalse);
    expect(navEnabled(tester, ThaiDatePickerDialog.nextKey), isFalse);

    // วันขอบทั้งสองเลือกได้
    await tapKey(tester, ThaiDatePickerDialog.dayKey(20));
    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2026, 4, 20)]);
  });

  testWidgets(
    'ขอบ first/last ในตัวเลือกปี/เดือน: มีเฉพาะปีในช่วง เดือนนอกช่วงกดไม่ได้ และวันถูกปรับเข้าช่วง',
    (tester) async {
      final results = await open(
        tester,
        DateTime(2026, 6, 25),
        firstDate: DateTime(2025, 11, 20),
        lastDate: DateTime(2027, 2, 10),
      );

      await tapKey(tester, ThaiDatePickerDialog.titleKey);
      expect(find.byKey(ThaiDatePickerDialog.yearKey(2567)), findsNothing);
      expect(find.byKey(ThaiDatePickerDialog.yearKey(2568)), findsOneWidget);
      expect(find.byKey(ThaiDatePickerDialog.yearKey(2570)), findsOneWidget);
      expect(find.byKey(ThaiDatePickerDialog.yearKey(2571)), findsNothing);

      // ปี 2570 มีแค่ ม.ค. - 10 ก.พ.: มิถุนายน (เดือนเดิม) อยู่นอกช่วง วันถูกปรับเป็นวันสุดท้ายของช่วง
      await tapKey(tester, ThaiDatePickerDialog.yearKey(2570));
      expect(selected(tester), 'พุธ 10 กุมภาพันธ์ 2570');
      expect(monthEnabled(tester, 1), isTrue);
      expect(monthEnabled(tester, 2), isTrue);
      expect(monthEnabled(tester, 3), isFalse);
      expect(monthEnabled(tester, 12), isFalse);

      await tapKey(tester, ThaiDatePickerDialog.monthKey(2));
      expect(title(tester), 'กุมภาพันธ์ 2570');
      expect(dayEnabled(tester, 10), isTrue);
      expect(dayEnabled(tester, 11), isFalse);
      await tapKey(tester, ThaiDatePickerDialog.okKey);
      expect(results, [DateTime(2027, 2, 10)]);
    },
  );

  testWidgets('วันตั้งต้นอยู่นอกช่วง: ปรับเข้าช่วงให้ ไม่ล้ม', (tester) async {
    var results = await open(
      tester,
      DateTime(1990, 1, 1),
      firstDate: DateTime(2026, 3, 5),
      lastDate: DateTime(2026, 3, 25),
    );
    expect(selected(tester), 'พฤหัสบดี 5 มีนาคม 2569');
    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2026, 3, 5)]);

    results = await open(
      tester,
      DateTime(2090, 1, 1),
      firstDate: DateTime(2026, 3, 5),
      lastDate: DateTime(2026, 3, 25),
    );
    await tapKey(tester, ThaiDatePickerDialog.okKey);
    expect(results, [DateTime(2026, 3, 25)]);
  });

  testWidgets('ช่วงตั้งต้นคือ พ.ศ. 2560-2580', (tester) async {
    await open(tester, DateTime(2017, 1, 15));
    expect(title(tester), 'มกราคม 2560');
    expect(navEnabled(tester, ThaiDatePickerDialog.prevKey), isFalse);

    await tapKey(tester, ThaiDatePickerDialog.titleKey);
    expect(find.byKey(ThaiDatePickerDialog.yearKey(2560)), findsOneWidget);
    expect(find.byKey(ThaiDatePickerDialog.yearKey(2559)), findsNothing);
    // เลื่อนไปท้ายรายการ: ปีสุดท้ายคือ 2580
    await tester.drag(find.byType(GridView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.byKey(ThaiDatePickerDialog.yearKey(2580)), findsOneWidget);
    expect(find.byKey(ThaiDatePickerDialog.yearKey(2581)), findsNothing);
  });

  testWidgets(
    'startWithYear: เปิดมาที่ตัวเลือกปีก่อน ช่วงย้อนหลังไกลเลื่อนมาเห็นปีตั้งต้น',
    (tester) async {
      final results = await open(
        tester,
        DateTime(1990, 5, 20),
        firstDate: DateTime(1940, 1, 1),
        lastDate: DateTime(2026, 10, 13),
        startWithYear: true,
      );

      // พ.ศ. 2533 = ค.ศ. 1990 ต้องเห็นได้เลยโดยไม่ต้องเลื่อน
      expect(
        find.byKey(ThaiDatePickerDialog.yearKey(2533)).hitTestable(),
        findsOneWidget,
      );
      await tapKey(tester, ThaiDatePickerDialog.yearKey(2535));
      await tapKey(tester, ThaiDatePickerDialog.monthKey(12));
      await tapKey(tester, ThaiDatePickerDialog.dayKey(31));
      await tapKey(tester, ThaiDatePickerDialog.okKey);
      expect(results, [DateTime(1992, 12, 31)]);
    },
  );

  testWidgets('ใช้สีของธีมปัจจุบัน', (tester) async {
    AppTheme.select('mint');
    addTearDown(() => AppTheme.select(null));
    final mint = AppTheme.palettes.firstWhere((p) => p.id == 'mint');
    await open(tester, DateTime(2026, 8, 18));

    final selectedCell = tester.widget<Material>(
      find.descendant(
        of: find.byKey(ThaiDatePickerDialog.dayKey(18)),
        matching: find.byType(Material),
      ),
    );
    expect(selectedCell.color, mint.primary);
    expect(
      tester
          .widget<Text>(find.byKey(ThaiDatePickerDialog.selectedKey))
          .style!
          .fontFamily,
      'NotoSansThai',
    );
  });

  testWidgets(
    'คีย์บอร์ด: วันที่เลือกได้โฟกัสตอนเปิด Tab ไปวันถัดไปแล้วกด Enter เพื่อเลือก',
    (tester) async {
      final results = await open(tester, DateTime(2026, 8, 18));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected(tester), 'พุธ 19 สิงหาคม 2569');

      await tapKey(tester, ThaiDatePickerDialog.okKey);
      expect(results, [DateTime(2026, 8, 19)]);
    },
  );

  group('จอแคบ 320 จุด', () {
    testWidgets('ทั้งสามมุมมองไม่ล้นกรอบ และยังเลือกวันได้', (tester) async {
      final results = await open(
        tester,
        DateTime(2026, 8, 18),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      final dialog = tester.getRect(find.byType(ThaiDatePickerDialog));
      expect(dialog.width, lessThanOrEqualTo(320));
      // ตารางวันอยู่ในจอทั้งหมด
      for (final day in [1, 2, 31]) {
        final r = tester.getRect(find.byKey(ThaiDatePickerDialog.dayKey(day)));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(320));
      }

      await tapKey(tester, ThaiDatePickerDialog.titleKey);
      expect(tester.takeException(), isNull);
      await tapKey(tester, ThaiDatePickerDialog.yearKey(2570));
      expect(tester.takeException(), isNull);
      // ชื่อเดือนยาวสุดยังอยู่ในช่อง
      expect(find.text('กุมภาพันธ์'), findsOneWidget);
      expect(find.text('พฤศจิกายน'), findsOneWidget);
      await tapKey(tester, ThaiDatePickerDialog.monthKey(11));
      expect(tester.takeException(), isNull);
      expect(title(tester), 'พฤศจิกายน 2570');

      await tapKey(tester, ThaiDatePickerDialog.dayKey(30));
      await tapKey(tester, ThaiDatePickerDialog.okKey);
      expect(results, [DateTime(2027, 11, 30)]);
    });

    testWidgets(
      'จอเตี้ย 320x400: เลื่อนหน้าต่างได้ ไม่ล้น ปุ่มตกลงกดได้หลังเลื่อน',
      (tester) async {
        final results = await open(
          tester,
          DateTime(2026, 8, 18),
          size: const Size(320, 400),
        );
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.byKey(ThaiDatePickerDialog.okKey));
        await tester.pumpAndSettle();
        await tapKey(tester, ThaiDatePickerDialog.okKey);
        expect(results, [DateTime(2026, 8, 18)]);
      },
    );
  });
}
