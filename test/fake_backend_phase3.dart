// ส่วนของ backend จำลองสำหรับระยะที่ 3 (ก้อน ง–ฉ ของ docs/api.md ฝั่ง backend) และเส้นใหม่ของก้อน ก/ค:
// นำเข้าสหกรณ์/ฌาปนกิจ ไฟล์ส่งกรมบัญชีกลาง กระทบยอดเลขบัญชีเงินกู้ รายงาน ลบข้อมูลหลักหลายรายการ
// ค้นบุคคล และบันทึกเลขบัญชีเงินกู้ทั้งชุด — ข้อมูลทั้งหมดเป็นค่าสมมุติ
part of 'fake_backend.dart';

/// ข้อมูลและตัวปรับของระยะที่ 3
class FakePhase3 {
  // ── สหกรณ์ ──
  /// จำนวนแถวที่นำเข้าไว้แล้วของงวดปัจจุบัน (ประเภท -> แถว)
  final Map<String, int> sahaRows = {'G': 0, 'E': 0};

  /// ปัญหาที่การตรวจไฟล์รายงาน (ชนิดละหนึ่งรายการ)
  List<Map<String, dynamic>> sahaProblems = [
    {
      'kind': 'MULTIPLE_MATCH',
      'line': 3,
      'saha_id': '000103',
      'name': 'นายสมมุติซ้ำ ตัวอย่าง',
      'idcard_used': fakeIdCard(3),
      'candidates': 2,
      'total_amount': 1200.5,
    },
    {
      'kind': 'NOT_FOUND',
      'line': 7,
      'saha_id': '000107',
      'name': 'นางสมมุติหาย ตัวอย่าง',
      'idcard_used': 'dupIdcard_000107',
      'candidates': 0,
      'total_amount': 800,
    },
    {
      'kind': 'FAKE_IDCARD',
      'line': 9,
      'saha_id': '000109',
      'name': 'นายสมมุติเดิม ตัวอย่าง',
      'idcard_used': 'dupIdcard_000109',
      'candidates': 0,
      'total_amount': 300,
    },
    {
      'kind': 'IDCARD_ALREADY_MAPPED',
      'line': 12,
      'saha_id': '000112',
      'name': 'นายสมมุติผูก ตัวอย่าง',
      'idcard_used': fakeIdCard(12),
      'candidates': 1,
      'total_amount': 450,
    },
    {
      'kind': 'OTHER_TYPE_MAPPING',
      'line': 15,
      'saha_id': '000115',
      'name': 'นายสมมุติข้าม ตัวอย่าง',
      'idcard_used': fakeIdCard(15),
      'total_amount': 650,
      'mapped_type': 'E',
    },
    {
      'kind': 'FUZZY_MATCH',
      'matched_name': 'นายสมมุติใกล้ เคียงชื่อ',
      'line': 18,
      'saha_id': '000115',
      'name': 'นายสมมุติข้าม ตัวอย่าง',
      'idcard_used': fakeIdCard(15),
      'total_amount': 650,
    },
  ];

  /// รายการที่เลขบัตรยังเป็นเลขปลอม
  late final List<Map<String, dynamic>> sahaUnresolved = [
    for (var i = 1; i <= 12; i++)
      {
        'saha_id': '0002${i.toString().padLeft(2, '0')}',
        'name': 'นายสมมุติค้าง${i.toString().padLeft(2, '0')} ตัวอย่าง',
        'type': i <= 10 ? 'G' : 'E',
        'idcard': 'dupIdcard_0002${i.toString().padLeft(2, '0')}',
        'total_amount': 100 * i,
      },
  ];

  /// จำลองคู่เลขสมาชิกเปลี่ยนหลังตรวจไฟล์: ตรวจ (dry_run) ผ่าน แต่นำเข้าจริงตอบ SAHA_TYPE_MISMATCH
  bool sahaMismatchOnImport = false;

  /// จำลองไฟล์ผิดรูปแบบ (400 บอกบรรทัดที่ผิด) / ไฟล์ที่คนส่วนใหญ่เคยจับคู่เป็นอีกประเภท (400 SAHA_TYPE_MISMATCH)
  bool sahaBadFile = false;
  bool sahaOtherTypeFile = false;

  /// การนำเข้าที่ค้างอยู่ที่ server (ของหน้าต่างอื่น) — null = ไม่มี; มีอยู่ = นำเข้าจริงตอบ 409 JOB_RUNNING
  Map<String, dynamic>? sahaJob;

  /// เลขบัตรที่ผูกกับเลขสมาชิกอื่นอยู่แล้ว (PUT mapping ตอบ DUPLICATE)
  final Set<String> sahaMapped = {fakeIdCard(30)};

  // ── ฌาปนกิจ ──
  int chapanaRows = 0;
  bool chapanaDpisEmpty = false;
  late List<Map<String, dynamic>> chapanaRetired = [
    for (var i = 1; i <= 3; i++)
      {
        'type': i == 3 ? 'E' : 'G',
        'idcard': fakeIdCard(200 + i),
        'title': 'นาย',
        'name': 'สมมุติเกษียณ0$i',
        'surname': 'ตัวอย่าง',
        'divname': 'หน่วยงานตัวอย่างที่ $i',
        'success_dept': 'G00090$i',
        'pos_no': '$i',
        'pos_name': 'ตำแหน่งตัวอย่าง',
        'gender': 'M',
        'member_no': '70$i',
        'per_status': 'เกษียณ',
      },
  ];

  // ── ไฟล์ส่งกรมบัญชีกลาง ──
  static const List<String> cgdCodes = [
    '40302',
    '40303',
    '40803',
    '40315',
    '41100',
    '41101',
    'Sum',
  ];

  /// ไฟล์ที่มีอักขระที่ TIS-620 ไม่มี (ชื่อ "type-code" -> จำนวน)
  final Map<String, int> cgdUnmappable = {'E-41100': 2};

  // ── กระทบยอดเงินกู้ ──
  late List<Map<String, dynamic>> loanMismatches = [
    {
      'bank': 'GHB',
      'div': '901',
      'type': 'G',
      'idcard': fakeIdCard(1),
      'title': 'นาย',
      'name': 'สมมุติ01',
      'surname': 'ตัวอย่าง',
      'accounts': 1,
      'debt': 1500.5,
      'loan_total': 5000,
    },
    {
      'bank': 'GHB',
      'div': '902',
      'type': 'G',
      'idcard': fakeIdCard(29),
      'title': 'นาย',
      'name': 'สมมุติ29',
      'surname': 'ตัวอย่าง',
      'accounts': 2,
      'debt': 3000,
      'loan_total': 2500,
    },
    {
      'bank': 'KTB',
      'div': '901',
      'type': 'E',
      'idcard': fakeIdCard(26),
      'title': 'นาง',
      'name': 'สมมุติ26',
      'surname': 'ตัวอย่าง',
      'accounts': 1,
      'debt': 700,
      'loan_total': 650,
    },
  ];

  late List<Map<String, dynamic>> missingAccounts = [
    {
      'div': '902',
      'type': 'G',
      'idcard': fakeIdCard(30),
      'title': 'นาง',
      'name': 'สมมุติ30',
      'surname': 'ทดสอบ',
      'c40302': 0,
      'c40303': 1000,
      'c40315': 0,
      'missing_banks': ['GSB'],
    },
  ];

  // ── สถานะการบันทึกรายหน่วยงาน ──
  /// จริง = backend ยังไม่มีเส้น /api/debts/div-status (ตอบ 404)
  bool divStatusMissing = false;

  /// เท็จ = งวดนั้นไม่มีประวัติการแก้ไขในระบบใหม่ (งวดย้อนหลังเป็นเท็จเสมอ)
  bool auditAvailable = true;

  /// จริง = มีหน่วยงานที่ไม่มีในข้อมูลหลัก (div_order null) และแถวที่ไม่มีหน่วยงาน (div ว่าง) ต่อท้าย
  bool divStatusOddRows = false;

  // ── เทียบฌาปนกิจกับสลิป ──
  /// ข้อผิดพลาดของการเทียบ: null = ปกติ, 'SLIP_API_NOT_CONFIGURED' (503), 'SLIP_API_ERROR' / 'DPIS_ERROR' (502)
  String? slipError;

  /// ผู้ที่หักไม่ได้ของข้าราชการ (12 คน: 3 ยอดไม่ตรง 9 ไม่มีในสลิป) — ลูกจ้างประจำหักได้ครบ
  late List<Map<String, dynamic>> slipNotPaid = [
    for (var i = 1; i <= 12; i++)
      {
        'idcard': fakeIdCard(300 + i),
        'name': 'นายสมมุติหัก${i.toString().padLeft(2, '0')} ตัวอย่าง',
        'member_no': '8${i.toString().padLeft(4, '0')}',
        'dept_name': 'หน่วยงานตัวอย่างที่ ${(i + 2) ~/ 3}',
        'org_code': 'G00090${(i + 2) ~/ 3}',
        'per_status': i == 12 ? ' ' : (i % 4 == 0 ? 2 : 1),
        'retired': i != 12 && i % 4 == 0,
        'amount': 120,
        'slip_amount': i <= 3 ? 100 : 0,
        'status': i <= 3 ? 'MISMATCH' : 'NOT_IN_SLIP',
        'pay_for': i == 1
            ? '80001 นายสมมุติหัก01 ตัวอย่าง\n80991 นางสมมุติคู่สมรส ตัวอย่าง'
            : '8${i.toString().padLeft(4, '0')} นายสมมุติหัก${i.toString().padLeft(2, '0')} ตัวอย่าง',
      },
  ];

  // ── รายงาน ──
  /// รายงานที่ไม่มีข้อมูล (ชื่อรายงาน เช่น rep1 / bank-AIA) ตอบ 404
  final Set<String> reportMissing = {};

  static const String reportMissingMessage = 'ไม่มีข้อมูลของรายงานนี้';
  static const String mismatchMessage =
      'ยอดเลขบัญชีเงินกู้ยังไม่ตรงกับหนี้รายเดือน';
  static const String chapanaExistsMessage = 'งวดนี้มีข้อมูลฌาปนกิจแล้ว';
  static const String sahaExistsMessage =
      'งวดนี้มีข้อมูลสหกรณ์ของประเภทนี้แล้ว';
  static const String sahaBadFileMessage = 'ไฟล์ผิดรูปแบบ';

  /// ข้อความของ 400 SAHA_TYPE_MISMATCH (ตั้ง sahaOtherTypeFile)
  static String sahaTypeMismatchMessage(String type) =>
      'ไฟล์นี้น่าจะเป็นของ${type == 'G' ? 'ลูกจ้างประจำ' : 'ข้าราชการ'} ไม่ใช่ประเภทที่เลือก: '
      'เคยจับคู่ไว้เป็นอีกประเภท 8 ราย ตรงประเภทเพียง 1 ราย จึงไม่ได้นำเข้า';
}

extension _FakePhase3Routes on FakeBackend {
  ResponseBody _file(List<int> bytes, String name, String type) =>
      ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: [type],
          'content-disposition': ['attachment; filename="$name"'],
          'cache-control': ['no-store'],
        },
      );

  /// เส้นของระยะที่ 3 — ไม่ใช่เส้นของส่วนนี้คืน null
  ResponseBody? phase3(
    RequestOptions options,
    Map<String, dynamic>? body,
    FakeUser me,
  ) {
    final path = options.path;
    final method = options.method;
    final q = options.queryParameters;
    // ผู้ดูแลระบบถือว่ามีทุกบทบาท (แบบ User.hasRole ของ backend)
    bool has(String role) =>
        me.roles.contains(role) || me.roles.contains('ADMIN');
    ResponseBody conflict(String code, String message, [Map? details]) => _json(
      409,
      {'code': code, 'message': message, 'details': ?details, 'success': false},
    );
    ResponseBody divForbidden() =>
        _error(403, 'DIV_FORBIDDEN', FakeBackend.divForbiddenMessage);
    final month = '${q['month'] ?? body?['month'] ?? periodMonth}';
    final year = '${q['year'] ?? body?['year'] ?? periodYear}';
    final current = month == periodMonth && year == periodYear;
    final period = {'month': month, 'year': year};

    // ── ลบข้อมูลหลักหลายรายการ ──
    final many = RegExp(r'^/api/master/([a-z-]+)/delete$').firstMatch(path);
    if (many != null && method == 'POST') {
      if (!has('ACCOUNT')) return _forbidden();
      final res = many.group(1)!;
      final list = p2.masters[res];
      if (list == null) {
        return _error(404, 'NOT_FOUND', 'ไม่พบข้อมูลหลักที่ระบุ');
      }
      final results = <Map<String, dynamic>>[];
      for (final id in (body?['ids'] as List? ?? const [])) {
        final i = list.indexWhere((e) => e['id'] == id);
        if (i < 0) {
          results.add({
            'id': id,
            'deleted': false,
            'code': 'NOT_FOUND',
            'message': 'ไม่พบรายการที่ระบุ',
          });
          continue;
        }
        final e = list[i];
        final inUse = switch (res) {
          'banks' => p2.masters['branches']!.any(
            (b) => b['bank_code'] == e['bank_code'],
          ),
          'branches' => p2.deducts.any(
            (d) =>
                d['bank_code'] == e['bank_code'] &&
                d['bank_brch'] == e['bank_brch'],
          ),
          'divs' => users.values.any((u) => u.div == e['div']),
          _ => false,
        };
        if (inUse) {
          results.add({
            'id': id,
            'deleted': false,
            'code': 'IN_USE',
            'message': FakeBackend.masterInUseMessage,
          });
        } else {
          list.removeAt(i);
          results.add({
            'id': id,
            'deleted': true,
            'code': null,
            'message': 'ลบข้อมูลสำเร็จ',
          });
        }
      }
      final deleted = results.where((r) => r['deleted'] == true).length;
      return _json(200, {
        'results': results,
        'deleted': deleted,
        'failed': results.length - deleted,
        'success': true,
      });
    }

    // ── ค้นบุคคลทุกหน่วยงาน ──
    if (path == '/api/persons/search' && method == 'POST') {
      if (!has('ACCOUNT')) return _forbidden();
      final name = '${body?['name'] ?? ''}'.trim();
      final surname = '${body?['surname'] ?? ''}'.trim();
      if (name.isEmpty && surname.isEmpty) {
        return _bad('กรุณาระบุชื่อหรือนามสกุล');
      }
      final hits =
          p2.debts
              .where(
                (d) =>
                    (name.isEmpty || '${d['name']}'.contains(name)) &&
                    (surname.isEmpty || '${d['surname']}'.contains(surname)) &&
                    (body?['type'] == null || d['type'] == body!['type']),
              )
              .toList()
            ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      final limit = personSearchLimit;
      return _json(200, {
        'items': [
          for (final d in hits.take(limit))
            {
              for (final k in const [
                'idcard',
                'type',
                'title',
                'name',
                'surname',
                'div',
                'divname',
                'pos_name',
              ])
                k: d[k],
            },
        ],
        'totalItems': hits.length,
        'truncated': hits.length > limit,
        'success': true,
      });
    }

    // ── บันทึกเลขบัญชีเงินกู้ทั้งชุด ──
    if (path == '/api/loans/set' && method == 'PUT') {
      if (!has('ACCOUNT')) return _forbidden();
      final idcard = '${body?['id_card'] ?? ''}';
      if (!_FakePhase2Routes._validIdCard(idcard)) {
        return _bad('เลขประจำตัวประชาชนไม่ถูกต้อง');
      }
      final items = [
        for (final e in body?['items'] as List? ?? const [])
          if (e is Map) Map<String, dynamic>.from(e),
      ];
      final seen = <String>{};
      for (var i = 0; i < items.length; i++) {
        final l = items[i];
        final no = i + 1;
        if (!RegExp(r'^\d{10,15}$').hasMatch('${l['ghb_acc'] ?? ''}')) {
          return _bad('รายการที่ $no เลขที่บัญชีต้องเป็นตัวเลข 10-15 หลัก');
        }
        if (!const ['1', '2', '3', '5', '6'].contains('${l['flg']}')) {
          return _bad('รายการที่ $no โครงการเงินกู้ไม่ถูกต้อง');
        }
        if (!const ['G', 'E'].contains(l['emp_type'])) {
          return _bad('รายการที่ $no กรุณาระบุประเภทบุคลากร (G หรือ E)');
        }
        if (l['amt'] != null && _FakePhase2Routes._amount(l['amt']) == null) {
          return _bad('รายการที่ $no จำนวนเงินไม่ถูกต้อง');
        }
        if (!seen.add('${l['ghb_acc']}')) {
          return conflict('DUPLICATE', FakeBackend.loanDuplicateMessage);
        }
      }
      final before = p2.loans.where((l) => l['id_card'] == idcard).length;
      p2.loans.removeWhere((l) => l['id_card'] == idcard);
      final saved = [
        for (final l in items)
          {
            ...l,
            'id_card': idcard,
            'amt': _FakePhase2Routes._amount(l['amt'] ?? 0),
            'id': p2._newId('loan'),
          },
      ];
      p2.loans.addAll(saved);
      return _json(200, {
        'found': saved.isNotEmpty,
        'items': saved,
        'saved': saved.length,
        'removed_previous': before,
        'message': FakeBackend.savedMessage,
        'success': true,
      });
    }

    // ── สถานะการบันทึกหนี้รายหน่วยงาน ──
    if (path == '/api/debts/div-status' && method == 'GET') {
      if (p3.divStatusMissing) {
        return _error(404, 'NOT_FOUND', 'ไม่พบหน้าที่ร้องขอ');
      }
      if (!has('ACCOUNT')) return _forbidden();
      final audit = current && p3.auditAvailable;
      final source = current ? p2.debts : p2.pastDebts;
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < divs.length; i++) {
        final div = '${divs[i]['div']}';
        final rows = source.where(
          (d) =>
              d['div'] == div &&
              (current || (d['month'] == month && d['year'] == year)),
        );
        // หนึ่งรายการต่อหน่วยงานที่มีรายการในงวด
        if (rows.isEmpty) continue;
        final edits = audit
            ? p2.audits
                  .where((a) => a['div'] == div && a['action'] == 'UPDATE')
                  .toList()
            : const <Map<String, dynamic>>[];
        items.add({
          'div': div,
          'divname': divs[i]['divname'],
          'div_order': '${i + 1}',
          'center': divs[i]['center'] == true,
          'g': rows.where((d) => d['type'] == 'G').length,
          'e': rows.where((d) => d['type'] == 'E').length,
          'rows': rows.length,
          'rows_with_debt': rows
              .where((d) => FakePhase2.codes.any((c) => (d[c] as num) > 0))
              .length,
          'edited': edits.isNotEmpty,
          'edits': edits.length,
          'last_edit_at': edits.isEmpty ? null : edits.first['at'],
          'last_edit_by': edits.isEmpty ? null : edits.first['by'],
        });
      }
      if (p3.divStatusOddRows && items.isNotEmpty) {
        Map<String, dynamic> odd(String div, String? name) => {
          'div': div,
          'divname': name,
          'div_order': null,
          'center': false,
          'g': 1,
          'e': 0,
          'rows': 1,
          'rows_with_debt': 0,
          'edited': false,
          'edits': 0,
          'last_edit_at': null,
          'last_edit_by': null,
        };
        items
          ..add(odd('999', 'หน่วยงานนอกข้อมูลหลัก'))
          ..add(odd('', null));
      }
      final edited = items.where((i) => i['edited'] == true).length;
      return _json(200, {
        ...period,
        'is_current_period': current,
        'period_ready': p2.periodReady,
        'prepared_at': audit ? '2025-06-22T08:15:00+07:00' : null,
        'audit_available': audit,
        'summary': {
          'divs': items.length,
          'edited': edited,
          'not_edited': items.length - edited,
          'rows': items.fold<int>(0, (s, i) => s + (i['rows'] as int)),
          'rows_with_debt': items.fold<int>(
            0,
            (s, i) => s + (i['rows_with_debt'] as int),
          ),
        },
        'items': items,
        'success': true,
      });
    }

    final isPhase3 =
        path.startsWith('/api/saha') ||
        path.startsWith('/api/chapana') ||
        path.startsWith('/api/cgd-files') ||
        path.startsWith('/api/reports') ||
        const [
          '/api/loans/check',
          '/api/loans/sync-amounts',
          '/api/loans/mismatch-file',
          '/api/loans/missing-accounts',
          '/api/loans/missing-accounts-file',
        ].contains(path);
    if (!isPhase3) return null;

    // ============ ก้อน ช: เทียบฌาปนกิจกับสลิป (ACCOUNT) ============
    if (path == '/api/chapana/slip-check' ||
        path == '/api/reports/chapana-not-pay') {
      if (method != 'GET') {
        return _error(405, 'METHOD_NOT_ALLOWED', 'ไม่รองรับวิธีเรียกนี้');
      }
      if (!has('ACCOUNT')) return _forbidden();
      final type = '${q['type'] ?? ''}';
      if (!const ['G', 'E'].contains(type)) {
        return _bad('กรุณาระบุประเภทบุคลากร (G หรือ E)');
      }
      if (p3.slipError != null) {
        return _error(
          p3.slipError == 'SLIP_API_NOT_CONFIGURED' ? 503 : 502,
          p3.slipError!,
          'ข้อความจาก backend ของ ${p3.slipError}',
        );
      }
      final imported = current && p3.chapanaRows > 0;
      final g = p2.debts.where((d) => d['type'] == 'G').length;
      final rows = !imported ? 0 : (type == 'G' ? g : p3.chapanaRows - g);
      final items = imported && type == 'G'
          ? p3.slipNotPaid
          : <Map<String, dynamic>>[];
      if (path == '/api/reports/chapana-not-pay') {
        if (items.isEmpty) {
          return _error(404, 'NOT_FOUND', FakePhase3.reportMissingMessage);
        }
        return _file(
          const [37, 80, 68, 70, 45],
          'rep9-$month$year-$type.pdf',
          'application/pdf',
        );
      }
      final mismatch = items.where((i) => i['status'] == 'MISMATCH').length;
      return _json(200, {
        ...period,
        'type': type,
        'summary': {
          'chapana_rows': rows,
          'matched': rows - items.length,
          'mismatch': mismatch,
          'not_in_slip': items.length - mismatch,
          'not_paid': items.length,
          'chapana_amount': rows * 120.0,
          'not_paid_amount': items.fold<num>(
            0,
            (s, i) => s + (i['amount'] as num),
          ),
        },
        'slip': {
          'count': rows - items.length + mismatch + 2,
          'not_in_chapana': 2,
        },
        'items': items,
        'success': true,
      });
    }

    // ============ ก้อน ฉ: รายงาน (บางเส้นทุกบทบาท) ============
    final report = RegExp(
      r'^/api/reports/(bank/)?([A-Za-z0-9-]+)$',
    ).firstMatch(path);
    if (report != null && method == 'GET') {
      final isBank = report.group(1) != null;
      final name = report.group(2)!;
      final accountOnly = isBank || name == 'rep2-all-dept' || name == 'rep10';
      // สรุปหน่วยงานประจำเดือน: ฝ่ายบัญชี หรือขอบเขตส่วนกลาง/ทุกหน่วยงาน (ตามระบบเดิม)
      final wideScope = name == 'rep2-all-dept' && _scope(me) != 'OWN';
      if (accountOnly && !has('ACCOUNT') && !wideScope) return _forbidden();
      if (isBank) {
        if (!const ['AIA', 'GHB', 'GSB', 'KTB'].contains(name)) {
          return _bad('ไม่รู้จักธนาคาร $name');
        }
        final wrong = p3.loanMismatches.where((m) => m['bank'] == name).length;
        if (wrong > 0) {
          return conflict('LOAN_AMOUNT_MISMATCH', FakePhase3.mismatchMessage, {
            ...period,
            'mismatch_count': wrong,
            'banks': [
              {'bank': name, 'mismatch_count': wrong},
            ],
          });
        }
        if (p3.reportMissing.contains('bank-$name')) {
          return _error(404, 'NOT_FOUND', FakePhase3.reportMissingMessage);
        }
        return _file(
          const [80, 75, 3, 4],
          'rep-$month$year-$name.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
      const perDiv = ['rep1', 'rep2', 'rep3', 'rep4', 'debt-change'];
      if (!perDiv.contains(name) && !accountOnly) {
        return _error(404, 'NOT_FOUND', 'ไม่พบรายงานที่ระบุ');
      }
      var div = '${q['div'] ?? me.div}';
      if (perDiv.contains(name)) {
        if (div == '*') {
          if (name != 'debt-change') return _bad('ต้องระบุหน่วยงาน');
          if (_scope(me) != 'ALL') return divForbidden();
          div = 'all';
        } else if (!_canAccessDiv(me, div)) {
          return divForbidden();
        }
        if (const ['rep1', 'rep3', 'rep4'].contains(name) &&
            !const ['G', 'E'].contains(q['type'])) {
          return _bad('กรุณาระบุประเภทบุคลากร (G หรือ E)');
        }
        if (name == 'debt-change' &&
            !const ['GHB', 'GSB', 'KTB'].contains(q['bank'])) {
          return _bad('กรุณาระบุธนาคาร');
        }
      }
      if (name == 'rep4' && p2.dpisFails) {
        return _error(502, 'DPIS_ERROR', FakeBackend.dpisErrorMessage);
      }
      if (p3.reportMissing.contains(name)) {
        return _error(404, 'NOT_FOUND', FakePhase3.reportMissingMessage);
      }
      final fileName = switch (name) {
        'rep2' => 'rep2-$div-GE.pdf',
        'debt-change' => 'debtChange-$div-${q['bank']}.pdf',
        'rep2-all-dept' => 'rep2AllDept-GE.pdf',
        'rep10' => 'rep10-$month$year.pdf',
        _ => '$name-$div-${q['type']}.pdf',
      };
      return _file(const [37, 80, 68, 70, 45], fileName, 'application/pdf');
    }

    // เส้นที่เหลือของระยะที่ 3 เป็นของ ACCOUNT ทั้งหมด
    if (!has('ACCOUNT')) return _forbidden();

    // ============ ก้อน ง: สหกรณ์ ============
    if (path == '/api/saha/import-status' && method == 'GET') {
      return _json(200, {
        ...(p3.sahaJob == null
            ? {'running': false}
            : {'running': true, ...p3.sahaJob!}),
        'success': true,
      });
    }
    if (path == '/api/saha/import' &&
        method == 'POST' &&
        p3.sahaJob != null &&
        body?['dry_run'] != 'true') {
      return conflict('JOB_RUNNING', 'งานนี้กำลังทำอยู่ กรุณารอให้เสร็จก่อน');
    }
    if (path == '/api/saha/import' && method == 'POST') {
      if (p2.notCurrentPeriod) {
        return conflict(
          'NOT_CURRENT_PERIOD',
          FakeBackend.notCurrentPeriodMessage,
        );
      }
      final type = '${body?['type'] ?? ''}';
      if (!const ['G', 'E'].contains(type)) {
        return _bad('กรุณาระบุประเภทบุคลากร (G หรือ E)');
      }
      final fileName = '${body?['file'] ?? ''}';
      final size = body?['file_size'] as int? ?? 0;
      if (fileName.isEmpty) return _bad('กรุณาแนบไฟล์');
      // ชื่อไฟล์ต้องเป็น coopG.dat / coopE.dat ตรงกับประเภท (แบบ SahaService.checkFileName)
      final named = RegExp(r'^coop([GE])\.(dat|DAT)$').firstMatch(fileName);
      if (named == null) {
        return _json(400, {
          'code': 'SAHA_FILE_NAME_INVALID',
          'message':
              'ชื่อไฟล์ต้องเป็น coopG.dat (ข้าราชการ) หรือ coopE.dat (ลูกจ้างประจำ)',
          'success': false,
        });
      }
      if (named.group(1) != type) {
        return _json(400, {
          'code': 'SAHA_FILE_NAME_MISMATCH',
          'message': 'ชื่อไฟล์เป็นของอีกประเภท ไม่ตรงกับประเภทที่เลือก',
          'success': false,
        });
      }
      if (p3.sahaBadFile) {
        return _json(400, {
          'code': 'BAD_REQUEST',
          'message': FakePhase3.sahaBadFileMessage,
          'details': {
            'bad_line_count': 2,
            'bad_lines': [4, 9],
            'expected_length': 104,
          },
          'success': false,
        });
      }
      // จริง = เลขสมาชิกที่เคยจับคู่ไว้ส่วนใหญ่เป็นอีกประเภท ตรวจก่อน CONFIRM_REQUIRED ทั้ง dry_run และนำเข้าจริง
      if (p3.sahaOtherTypeFile ||
          (p3.sahaMismatchOnImport && body?['dry_run'] != 'true')) {
        return _json(400, {
          'code': 'SAHA_TYPE_MISMATCH',
          'message': FakePhase3.sahaTypeMismatchMessage(type),
          'details': {
            'type': type,
            'likely_type': type == 'G' ? 'E' : 'G',
            'members_in_file': 10,
            'mapped_same_type': 1,
            'mapped_other_type': 8,
          },
          'success': false,
        });
      }
      final rows = (size / 106).ceil();
      final dry = body?['dry_run'] == 'true';
      final existing = p3.sahaRows[type] ?? 0;
      if (!dry && existing > 0 && body?['confirm_replace'] != 'true') {
        return conflict('CONFIRM_REQUIRED', FakePhase3.sahaExistsMessage, {
          ...period,
          'type': type,
          'rows_to_clear': existing,
          'rows_in_file': rows,
        });
      }
      if (!dry) p3.sahaRows[type] = rows;
      final counts = <String, int>{};
      for (final p in p3.sahaProblems) {
        counts['${p['kind']}'] = (counts['${p['kind']}'] ?? 0) + 1;
      }
      return _json(200, {
        'dry_run': dry,
        ...period,
        'type': type,
        'rows': rows,
        // หนึ่งรายการต่อเลขบัตร: จำลองคนหนึ่งมีสองเลขสมาชิก
        'stored_rows': rows > 1 ? rows - 1 : rows,
        'merged_people': rows > 1 ? 1 : 0,
        'total_amount': rows * 1000.25,
        'existing_rows': existing,
        'replaced_rows': dry ? 0 : existing,
        'matched_by_mapping': rows > 4 ? rows - 4 : 0,
        'matched_by_history': 3,
        'matched_by_name': 2,
        'matched_by_debt': 1,
        'matched_by_similar': 1,
        'new_mappings': dry ? 0 : 2,
        'problem_count': p3.sahaProblems.length,
        'problem_counts': counts,
        'problems': p3.sahaProblems,
        'problems_truncated': false,
        'message': dry
            ? 'ตรวจไฟล์แล้ว ยังไม่ได้บันทึก'
            : 'นำเข้าข้อมูลสหกรณ์เรียบร้อยแล้ว',
        'success': true,
      });
    }
    if (path == '/api/saha/summary' && method == 'GET') {
      return _json(200, {
        ...period,
        'items': [
          if (current)
            for (final t in const ['G', 'E'])
              if ((p3.sahaRows[t] ?? 0) > 0)
                {
                  'type': t,
                  'rows': p3.sahaRows[t],
                  'total_amount': p3.sahaRows[t]! * 1000.25,
                  'fake_idcard_rows': p3.sahaUnresolved
                      .where((u) => u['type'] == t)
                      .length,
                },
        ],
        'success': true,
      });
    }
    if (path == '/api/saha/unresolved' && method == 'GET') {
      final rows = current
          ? p3.sahaUnresolved
                .where((u) => q['type'] == null || u['type'] == q['type'])
                .toList()
          : <Map<String, dynamic>>[];
      int intOf(Object? v, int f) => v is int ? v : int.tryParse('$v') ?? f;
      return _json(
        200,
        _paged(rows, intOf(q['page'], 0), intOf(q['size'], 10)),
      );
    }
    if (path == '/api/saha/mapping' && method == 'PUT') {
      if (p2.notCurrentPeriod) {
        return conflict(
          'NOT_CURRENT_PERIOD',
          FakeBackend.notCurrentPeriodMessage,
        );
      }
      final idcard = '${body?['idcard'] ?? ''}';
      if (!_FakePhase2Routes._validIdCard(idcard)) {
        return _bad('เลขประจำตัวประชาชนไม่ถูกต้อง');
      }
      if (p3.sahaMapped.contains(idcard)) {
        return conflict(
          'DUPLICATE',
          'เลขประจำตัวประชาชนนี้ผูกกับเลขสมาชิกอื่นอยู่แล้ว',
        );
      }
      final before = p3.sahaUnresolved.length;
      p3.sahaUnresolved.removeWhere((u) => u['saha_id'] == body?['saha_id']);
      p3.sahaMapped.add(idcard);
      return _json(200, {
        'saha_id': body?['saha_id'],
        'idcard': idcard,
        'updated_rows': before - p3.sahaUnresolved.length,
        ...period,
        'message': FakeBackend.savedMessage,
        'success': true,
      });
    }

    // ============ ก้อน ง: ฌาปนกิจ ============
    if (path == '/api/chapana/import' && method == 'POST') {
      if (p2.notCurrentPeriod) {
        return conflict(
          'NOT_CURRENT_PERIOD',
          FakeBackend.notCurrentPeriodMessage,
        );
      }
      if (!p2.periodReady) {
        return conflict('PERIOD_NOT_READY', FakeBackend.periodNotReadyMessage);
      }
      if (p2.dpisFails) {
        return _error(502, 'DPIS_ERROR', FakeBackend.dpisErrorMessage);
      }
      if (p3.chapanaDpisEmpty) return _bad('DPIS ไม่มีข้อมูลฌาปนกิจของงวดนี้');
      if (p3.chapanaRows > 0 && body?['confirm_replace'] != true) {
        return conflict('CONFIRM_REQUIRED', FakePhase3.chapanaExistsMessage, {
          ...period,
          'rows_to_clear': p3.chapanaRows,
        });
      }
      final replaced = p3.chapanaRows;
      p3.chapanaRows = p2.debts.length;
      final g = p2.debts.where((d) => d['type'] == 'G').length;
      return _json(200, {
        ...period,
        'from_dpis': p3.chapanaRows + p3.chapanaRetired.length,
        'rows': p3.chapanaRows,
        'g': g,
        'e': p3.chapanaRows - g,
        'retired': p3.chapanaRetired.length,
        'retired_with_detail': p3.chapanaRetired.length,
        'skipped_invalid': 0,
        'replaced_rows': replaced,
        'message': 'นำเข้าข้อมูลฌาปนกิจเรียบร้อยแล้ว',
        'success': true,
      });
    }
    if (path == '/api/chapana/summary' && method == 'GET') {
      final has = current && p3.chapanaRows > 0;
      final g = p2.debts.where((d) => d['type'] == 'G').length;
      return _json(200, {
        ...period,
        'items': [
          if (has) ...[
            {'type': 'G', 'count': g, 'amount': g * 50},
            {
              'type': 'E',
              'count': p3.chapanaRows - g,
              'amount': (p3.chapanaRows - g) * 50,
            },
          ],
        ],
        'retired': has ? p3.chapanaRetired.length : 0,
        'success': true,
      });
    }
    if (path == '/api/chapana/retired' && method == 'GET') {
      return _json(200, {
        ...period,
        'items': current && p3.chapanaRows > 0 ? p3.chapanaRetired : [],
        'success': true,
      });
    }

    // ============ ก้อน จ: ไฟล์ส่งกรมบัญชีกลาง ============
    if (path == '/api/cgd-files' && method == 'GET') {
      return _json(200, {
        ...period,
        'items': [
          for (final t in const ['G', 'E'])
            for (final c in FakePhase3.cgdCodes)
              {
                'name': '$t-$c-$year-$month.txt',
                'type': t,
                'code': c,
                'count': c == 'Sum' ? null : (c == '40803' ? 0 : 3),
                'amount': c == 'Sum' ? null : (c == '40803' ? 0 : 4500.5),
                'size': c == '40803' ? 0 : 120,
                'unmappable_chars': p3.cgdUnmappable['$t-$c'] ?? 0,
              },
        ],
        'success': true,
      });
    }
    if (path == '/api/cgd-files/zip' && method == 'GET') {
      final t = q['type'];
      return _file(
        const [80, 75, 5, 6],
        t == null ? 'CGD-$year-$month.zip' : 'CGD-$t-$year-$month.zip',
        'application/zip',
      );
    }
    final cgd = RegExp(
      r'^/api/cgd-files/([GE])/([A-Za-z0-9]+)$',
    ).firstMatch(path);
    if (cgd != null && method == 'GET') {
      if (!FakePhase3.cgdCodes.contains(cgd.group(2))) {
        return _error(404, 'NOT_FOUND', 'ไม่พบไฟล์ที่ระบุ');
      }
      return _file(
        // ไบต์ TIS-620 ของ "กข" ตามด้วย CRLF — หน้าเว็บต้องส่งต่อเท่าเดิมทุกไบต์
        const [0xA1, 0xA2, 13, 10],
        '${cgd.group(1)}-${cgd.group(2)}-$year-$month.txt',
        'text/plain;charset=TIS-620',
      );
    }

    // ============ ก้อน จ: กระทบยอดเลขบัญชีเงินกู้ ============
    Map<String, dynamic> bankView(String bank, String code, List<int> flags) {
      final wrong = p3.loanMismatches.where((m) => m['bank'] == bank).toList();
      final missing = p3.missingAccounts
          .where((m) => (m['missing_banks'] as List).contains(bank))
          .length;
      return {
        'bank': bank,
        'code': code,
        'flags': flags,
        'checked': 10,
        'mismatch_count': wrong.length,
        'missing_account': missing,
        'mismatches': wrong,
      };
    }

    if (path == '/api/loans/check' && method == 'GET') {
      final banks = [
        bankView('GHB', '40302', const [1, 2, 3]),
        bankView('GSB', '40303', const [5]),
        bankView('KTB', '40315', const [6]),
      ];
      return _json(200, {
        ...period,
        'ok': p3.loanMismatches.isEmpty,
        'mismatch_count': p3.loanMismatches.length,
        'missing_account': p3.missingAccounts.length,
        'banks': banks,
        'success': true,
      });
    }
    if (path == '/api/loans/sync-amounts' && method == 'POST') {
      final fixed = p3.loanMismatches.where((m) => m['accounts'] == 1).toList();
      p3.loanMismatches.removeWhere((m) => m['accounts'] == 1);
      return _json(200, {
        ...period,
        'updated': fixed.length,
        'banks': [
          for (final b in const [
            ('GHB', '40302'),
            ('GSB', '40303'),
            ('KTB', '40315'),
          ])
            {
              'bank': b.$1,
              'code': b.$2,
              'updated': fixed.where((m) => m['bank'] == b.$1).length,
              'manual_count': p3.loanMismatches
                  .where((m) => m['bank'] == b.$1)
                  .length,
              'manual': p3.loanMismatches
                  .where((m) => m['bank'] == b.$1)
                  .toList(),
            },
        ],
        'message': 'ปรับปรุงหนี้ธนาคารเรียบร้อยแล้ว',
        'success': true,
      });
    }
    if (path == '/api/loans/mismatch-file' && method == 'GET') {
      return _file(
        const [0xA1, 13, 10],
        'Bank-$year-$month.txt',
        'text/plain;charset=TIS-620',
      );
    }
    if (path == '/api/loans/missing-accounts' && method == 'GET') {
      return _json(200, {
        ...period,
        'count': p3.missingAccounts.length,
        'items': p3.missingAccounts,
        'success': true,
      });
    }
    if (path == '/api/loans/missing-accounts-file' && method == 'GET') {
      return _file(
        const [0xA2, 13, 10],
        'Acc-$year-$month.txt',
        'text/plain;charset=TIS-620',
      );
    }

    return _error(404, 'NOT_FOUND', 'ไม่พบหน้าที่ร้องขอ');
  }
}
