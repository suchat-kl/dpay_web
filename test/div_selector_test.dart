// เทสต์ตัวเลือกหน่วยงานกลาง (DivSelector / DivDropdown) ตามขอบเขตของ GET /api/divs
// OWN = แสดงหน่วยงานตัวเองเฉย ๆ, CENTER / ALL = รายการเลือกแบบค้นหาได้

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpay/config/theme.dart';
import 'package:dpay/models/div_dept.dart';
import 'package:dpay/providers/auth_provider.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/widgets/div_selector.dart';

import 'fake_backend.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakeBackend backend;
  late AuthProvider auth;
  final api = ApiService();

  Future<void> signIn(String username) =>
      auth.login(username, FakeBackend.passwordOf(username));

  setUp(() async {
    backend = await installFakeBackend();
    auth = AuthProvider();
  });

  tearDown(() => auth.logout());

  /// วางตัวเลือกบนหน้าเปล่า คืนรายการหน่วยงานที่ตัวเลือกแจ้งกลับตามลำดับ
  Future<List<DivDept>> pump(
    WidgetTester tester, {
    required String as,
    String? initialDiv,
    DivChoices? choices,
    Size size = const Size(900, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => signIn(as));
    backend.clearLog();
    final picked = <DivDept>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: DivSelector(
              apiService: api,
              initialDiv: initialDiv,
              choices: choices,
              onChanged: picked.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picked;
  }

  group('โมเดล', () {
    test('DivScope.parse: ค่าที่ไม่รู้จักถือเป็นของตัวเอง (แคบที่สุด)', () {
      expect(DivScope.parse('OWN'), DivScope.own);
      expect(DivScope.parse('CENTER'), DivScope.center);
      expect(DivScope.parse('ALL'), DivScope.all);
      expect(DivScope.parse('all'), DivScope.all);
      expect(DivScope.parse(null), DivScope.own);
      expect(DivScope.parse('อื่น ๆ'), DivScope.own);
      expect(DivScope.center.code, 'CENTER');
    });

    test('DivChoices: อ่านคำตอบของ /api/divs และทนต่อช่องขาด', () {
      final c = DivChoices.fromJson({
        'scope': 'CENTER',
        'own_div': '904',
        'divs': [
          {'div': '902', 'divname': 'กองบัญชีตัวอย่าง', 'center': true},
          {'div': '904', 'divname': null, 'center': true},
          'ไม่ใช่แถว',
        ],
        'success': true,
      });
      expect(c.scope, DivScope.center);
      expect(c.ownDiv, '904');
      expect(c.divs, hasLength(2));
      expect(c.find('902')!.label, '902 กองบัญชีตัวอย่าง');
      expect(c.find('904')!.label, '904');
      expect(c.find('999'), isNull);
      expect(c.selectable, isTrue);

      final empty = DivChoices.fromJson({});
      expect(empty.scope, DivScope.own);
      expect(empty.divs, isEmpty);
      expect(empty.selectable, isFalse);
    });
  });

  test('GET /api/divs ตามขอบเขตของแต่ละบัญชี', () async {
    await signIn(FakeBackend.user);
    var c = await api.getDivs();
    expect(c.scope, DivScope.own);
    expect(c.ownDiv, '901');
    expect(c.divs.map((d) => d.div), ['901']);
    await auth.logout();

    await signIn(FakeBackend.centerDept);
    c = await api.getDivs();
    expect(c.scope, DivScope.center);
    expect(c.divs.map((d) => d.div), ['902', '903', '904', '905', '909']);
    await auth.logout();

    await signIn(FakeBackend.allDept);
    c = await api.getDivs();
    expect(c.scope, DivScope.all);
    expect(c.divs, hasLength(30));
    // ACCOUNT / ADMIN ไม่ได้ขยายขอบเขตเอง
    await auth.logout();
    await signIn(FakeBackend.admin);
    expect((await api.getDivs()).scope, DivScope.own);
  });

  testWidgets('ขอบเขต OWN: แสดงหน่วยงานของตัวเองเฉย ๆ เลือกไม่ได้', (
    tester,
  ) async {
    final picked = await pump(tester, as: FakeBackend.user);

    expect(backend.calls, ['GET /api/divs']);
    expect(find.byKey(DivSelector.fixedKey), findsOneWidget);
    expect(find.text('901 หน่วยงานตัวอย่างที่ 1'), findsOneWidget);
    expect(find.byType(DropdownMenu<String>), findsNothing);
    expect(find.byType(TextField), findsNothing);
    // แจ้งหน่วยงานของตัวเองหนึ่งครั้ง ให้ผู้เรียกเริ่มโหลดข้อมูลได้
    expect(picked.map((d) => d.div), ['901']);
  });

  testWidgets(
    'ขอบเขต CENTER: รายการหน่วยงานส่วนกลาง เริ่มที่หน่วยงานตัวเอง ค้นหาแล้วเลือกได้',
    (tester) async {
      final picked = await pump(tester, as: FakeBackend.centerDept);

      expect(find.byKey(DivSelector.fixedKey), findsNothing);
      expect(find.byType(DropdownMenu<String>), findsOneWidget);
      expect(picked.map((d) => d.div), ['904']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '904 หน่วยงานตัวอย่างที่ 4',
      );

      // พิมพ์ชื่อบางส่วนเพื่อกรอง แล้วเลือก
      await tester.enterText(find.byType(TextField), 'บัญชี');
      await tester.pumpAndSettle();
      expect(find.text('902 กองบัญชีตัวอย่าง').hitTestable(), findsOneWidget);
      expect(
        find.text('905 หน่วยงานตัวอย่างที่ 5').hitTestable(),
        findsNothing,
      );
      await tester.tap(find.text('902 กองบัญชีตัวอย่าง').last);
      await tester.pumpAndSettle();

      expect(picked.map((d) => d.div), ['904', '902']);
      expect(picked.last.center, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '902 กองบัญชีตัวอย่าง',
      );
      // หน่วยงานนอกส่วนกลางไม่อยู่ในรายการ
      await tester.enterText(find.byType(TextField), '915');
      await tester.pumpAndSettle();
      expect(find.text('915 หน่วยงานตัวอย่างที่ 15'), findsNothing);
    },
  );

  testWidgets(
    'ขอบเขต ALL: เลือกได้ทุกหน่วยงาน ค้นด้วยรหัส และเริ่มที่ initialDiv',
    (tester) async {
      final picked = await pump(
        tester,
        as: FakeBackend.allDept,
        initialDiv: '920',
      );

      expect(picked.map((d) => d.div), ['920']);
      await tester.enterText(find.byType(TextField), '930');
      await tester.pumpAndSettle();
      await tester.tap(find.text('930 หน่วยงานตัวอย่างที่ 30').last);
      await tester.pumpAndSettle();
      expect(picked.map((d) => d.div), ['920', '930']);

      // เลือกซ้ำค่าเดิม: ไม่แจ้งซ้ำ
      await tester.enterText(find.byType(TextField), '930');
      await tester.pumpAndSettle();
      await tester.tap(find.text('930 หน่วยงานตัวอย่างที่ 30').last);
      await tester.pumpAndSettle();
      expect(picked, hasLength(2));
    },
  );

  testWidgets('initialDiv ที่ไม่มีสิทธิ์เลือก: ใช้หน่วยงานของตัวเองแทน', (
    tester,
  ) async {
    final picked = await pump(
      tester,
      as: FakeBackend.centerDept,
      initialDiv: '915',
    );
    expect(picked.map((d) => d.div), ['904']);
  });

  testWidgets('ส่งรายการที่โหลดไว้แล้ว: ไม่เรียก backend ซ้ำ', (tester) async {
    final picked = await pump(
      tester,
      as: FakeBackend.user,
      choices: const DivChoices(
        scope: DivScope.all,
        ownDiv: '901',
        divs: [
          DivDept(div: '901', name: 'หน่วยงานตัวอย่างที่ 1'),
          DivDept(div: '902', name: 'กองบัญชีตัวอย่าง', center: true),
        ],
      ),
    );

    expect(backend.calls, isEmpty);
    expect(find.byType(DropdownMenu<String>), findsOneWidget);
    expect(picked.map((d) => d.div), ['901']);
  });

  testWidgets('โหลดรายชื่อหน่วยงานไม่สำเร็จ: แสดงข้อผิดพลาด ไม่ล้ม', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => signIn(FakeBackend.allDept));
    backend.unreachable = true;
    final picked = <DivDept>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DivSelector(apiService: api, onChanged: picked.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้'),
      findsOneWidget,
    );
    expect(picked, isEmpty);
    backend.unreachable = false;
  });

  testWidgets('จอ 320 จุด: ตัวเลือกทั้งสองแบบไม่ล้นกรอบ', (tester) async {
    await pump(tester, as: FakeBackend.allDept, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(DropdownMenu<String>)).width,
      lessThanOrEqualTo(320 - 24),
    );
    await tester.enterText(find.byType(TextField), 'หน่วยงาน');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('จอ 320 จุด: หน่วยงานของตัวเองชื่อยาวตัดบรรทัด ไม่ล้น', (
    tester,
  ) async {
    backend.divs[0]['divname'] =
        'หน่วยงานตัวอย่างที่มีชื่อยาวมากเป็นพิเศษเพื่อทดสอบการตัดบรรทัดบนจอแคบ';
    await pump(tester, as: FakeBackend.user, size: const Size(320, 640));
    expect(find.byKey(DivSelector.fixedKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
