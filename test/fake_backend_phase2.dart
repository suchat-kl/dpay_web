// ส่วนของ backend จำลองสำหรับระยะที่ 2 (ก้อน ก–ค ของ docs/api.md ฝั่ง backend):
// ข้อมูลหลัก งานงวด รายการหนี้รายเดือน ทะเบียนบุคลากร และเลขบัญชีเงินกู้
// ข้อมูลทั้งหมดเป็นค่าสมมุติ เลขประจำตัวประชาชนสร้างจากสูตร (หลักตรวจสอบถูกต้อง แต่ไม่ใช่ของบุคคลจริง)
part of 'fake_backend.dart';

/// เลขประจำตัวประชาชนสมมุติลำดับที่ [n] (หลักตรวจสอบถูกต้อง)
String fakeIdCard(int n) {
  final base = '19${n.toString().padLeft(10, '0')}';
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(base[i]) * (13 - i);
  }
  return '$base${(11 - sum % 11) % 10}';
}

/// ข้อมูลและตัวปรับของระยะที่ 2
class FakePhase2 {
  int _serial = 0;
  String _newId(String prefix) =>
      '$prefix${(++_serial).toString().padLeft(6, '0')}'.padRight(24, '0');

  // ── ก้อน ก: ข้อมูลหลัก ──
  late final Map<String, List<Map<String, String>>> masters = {
    'banks': [
      for (final b in const [
        ('006', 'ธนาคารตัวอย่างหนึ่ง', 'TB1', '1'),
        ('014', 'ธนาคารตัวอย่างสอง', 'TB2', '2'),
        ('030', 'ธนาคารตัวอย่างสาม', 'TB3', '10'),
      ])
        {
          'id': 'bank${b.$1}',
          'bank_code': b.$1,
          'bank_name': b.$2,
          'shrt': b.$3,
          'shrt_th': '',
          'rec_no': b.$4,
        },
    ],
    'branches': [
      for (final b in const [
        ('006', '0001', 'สาขาตัวอย่างหนึ่ง'),
        ('006', '0002', 'สาขาตัวอย่างสอง'),
        ('014', '0101', 'สาขาตัวอย่างสาม'),
      ])
        {
          'id': 'br${b.$1}${b.$2}',
          'bank_code': b.$1,
          'bank_brch': b.$2,
          'name': b.$3,
        },
    ],
    'debt-codes': [
      for (final c in const [
        ('40302', 'ธ.อาคารสงเคราะห์'),
        ('40303', 'ธ.ออมสิน'),
        ('40315', 'ธ.กรุงไทย'),
        ('40803', 'AIA ประกันชีวิต'),
        ('41100', 'หนี้สินอื่นๆ'),
      ])
        {'id': 'code${c.$1}', 'mcode': c.$1, 'shrt': c.$2},
    ],
    'provinces': [
      for (final p in const [
        ('10', 'จังหวัดตัวอย่างหนึ่ง'),
        ('50', 'จังหวัดตัวอย่างสอง'),
      ])
        {
          'id': 'prov${p.$1}',
          'prov_code': p.$1,
          'prov_name': p.$2,
          'tf_prov': '',
        },
    ],
    'divs': [],
    'div-conv': [],
  };

  static const Map<String, List<String>> masterKeys = {
    'banks': ['bank_code'],
    'branches': ['bank_code', 'bank_brch'],
    'debt-codes': ['mcode'],
    'divs': ['div'],
    'provinces': ['prov_code'],
  };
  static const Map<String, List<String>> masterRequired = {
    'banks': ['bank_code', 'bank_name', 'rec_no'],
    'branches': ['bank_code', 'bank_brch', 'name'],
    'debt-codes': ['mcode', 'shrt'],
    'divs': ['div', 'divname', 'div_order', 'center_dept'],
    'provinces': ['prov_code', 'prov_name'],
  };
  static const Map<String, String> masterDefaultSort = {
    'banks': 'rec_no',
    'branches': 'bank_brch',
    'debt-codes': 'mcode',
    'divs': 'div_order',
    'provinces': 'prov_code',
    'div-conv': 'div',
  };

  // ── ก้อน ข: งานงวด ──
  int dpisG = 30;
  int dpisE = 6;
  String? dpisLastAt = '2025-06-20T02:15:00.000+00:00';
  String? dpisLastBy = FakeBackend.account;

  /// จริง = DPIS ล่ม (502 DPIS_ERROR) / มีงานค้าง (409 JOB_RUNNING)
  bool dpisFails = false;
  bool jobRunning = false;

  /// งวดเตรียมเสร็จแล้ว (เท็จ = แก้ยอดไม่ได้ PERIOD_NOT_READY)
  bool periodReady = true;
  String? prepareStatus = 'DONE';
  int editsSincePrepare = 0;

  /// จริง = PUT /api/debts ตอบ 409 NOT_CURRENT_PERIOD (จำลองงวดถูกเปลี่ยนระหว่างที่หน้าจอเปิดอยู่)
  bool notCurrentPeriod = false;

  /// จริง = รายการหนี้มีช่อง in_roster (backend รุ่นใหม่) เท็จ = ไม่มีช่องนี้
  bool sendInRoster = false;

  /// รายการหนี้ของงวดปัจจุบัน
  late final List<Map<String, dynamic>> debts = [
    // หน่วยงาน 901 ข้าราชการ 25 คน (แบ่งหน้าได้) คนแรกมียอดหนี้
    for (var i = 1; i <= 25; i++)
      _debt(
        i,
        'G',
        '901',
        amounts: i == 1 ? {'c40302': 1500.5, 'c41100': 200} : null,
      ),
    for (var i = 26; i <= 28; i++) _debt(i, 'E', '901'),
    for (var i = 29; i <= 30; i++)
      _debt(i, 'G', '902', amounts: {'c40303': 1000}),
    _debt(31, 'G', '904'),
    _debt(32, 'G', '915'),
  ];

  /// รายการหนี้ของงวดก่อนหน้า (06/2568) — ดูย้อนหลังได้อย่างเดียว ไม่มีช่อง in_roster
  late final List<Map<String, dynamic>> pastDebts = [
    for (var i = 1; i <= 12; i++)
      _debt(
          i,
          'G',
          '901',
          month: '06',
          amounts: i == 1 ? {'c40302': 900, 'c41100': 100} : null,
        )
        ..['id'] = 'past${i.toString().padLeft(4, '0')}'.padRight(24, '0')
        ..remove('in_roster'),
  ];

  /// บุคคลที่ DPIS รู้จักแต่ยังไม่มีรายการในงวด (เลขบัตร -> (ชื่อ, นามสกุล, ประเภท))
  late final Map<String, (String, String, String)> people = {
    fakeIdCard(101): ('สมมุติใหม่', 'ตัวอย่าง', 'G'),
    fakeIdCard(102): ('สมมุติเพิ่ม', 'ตัวอย่าง', 'E'),
  };

  final List<Map<String, dynamic>> audits = [];

  /// เพิ่มรายการหนึ่งคนให้ทุกหน่วยงานที่ยังไม่มีรายการในงวด (ใช้กับเทสต์สถานะรายหน่วยงานที่ต้องมีหลายหน่วยงาน)
  void seedAllDivs() {
    for (var div = 901; div <= 930; div++) {
      if (!debts.any((d) => d['div'] == '$div')) {
        debts.add(_debt(500 + div, 'G', '$div'));
      }
    }
  }

  Map<String, dynamic> _debt(
    int n,
    String type,
    String div, {
    String month = '07',
    Map<String, num>? amounts,
  }) => {
    'id': 'debt${n.toString().padLeft(4, '0')}'.padRight(24, '0'),
    'type': type,
    'month': month,
    'year': '2568',
    'div': div,
    'idcard': fakeIdCard(n),
    'title': n.isEven ? 'นาง' : 'นาย',
    'name': 'สมมุติ${n.toString().padLeft(2, '0')}',
    'surname': n % 5 == 0 ? 'ทดสอบ' : 'ตัวอย่าง',
    'gender': n.isEven ? 'F' : 'M',
    'divname': 'หน่วยงานตัวอย่างที่ ${int.parse(div) - 900}',
    'success_dept': '${type}000$div',
    'pos_no': '$n',
    'pos_name': 'ตำแหน่งตัวอย่าง',
    for (final c in codes) c: amounts?[c] ?? 0,
    'in_roster': n != 3,
  };

  static const List<String> codes = [
    'c40302',
    'c40303',
    'c40315',
    'c40803',
    'c41100',
  ];
  static const Map<String, String> codeNames = {
    'c40302': 'ธ.อาคารสงเคราะห์',
    'c40303': 'ธ.ออมสิน',
    'c40315': 'ธ.กรุงไทย',
    'c40803': 'AIA ประกันชีวิต',
    'c41100': 'หนี้สินอื่นๆ',
  };

  // ── ก้อน ค: ทะเบียนและเงินกู้ ──
  late final List<Map<String, dynamic>> deducts = [
    {
      'id': 'deduct1'.padRight(24, '0'),
      'id_card': fakeIdCard(1),
      'emp_type': 'G',
      'bank_code': '006',
      'bank_brch': '0001',
      'bank_acc': '1234567890',
      'bank_prov': 'จังหวัดตัวอย่างหนึ่ง',
      'prov_code': '10',
      'saha_id': '123',
      'chap_id': '',
      'kbk_flg': '1',
      'kbk_type': '0',
      'kbk_pct': '3',
      'kbk_pct2': '',
      'kbk_dmy': '01102550',
      'kbk_dmy2': '',
      'rec_flg': '0',
      'donate_amt': 0,
      'insr_amt': 12000,
      'int_amt': 0,
      'rmf_amt': 0,
      'ltf_amt': 0,
      'upd_dmy': '15062568',
      'saha_code': 'S01',
    },
  ];

  /// จำนวนรายการซ้ำที่ /api/deducts/find รายงาน (เลขบัตร -> จำนวน)
  final Map<String, int> deductDuplicates = {};

  late final List<Map<String, dynamic>> loans = [
    {
      'id': 'loan1'.padRight(24, '0'),
      'id_card': fakeIdCard(1),
      'ghb_acc': '1111111111',
      'flg': '1',
      'emp_type': 'G',
      'year': '2565',
      'seq': '1',
      'subseq': '1',
      'amt': 5000,
    },
    {
      'id': 'loan2'.padRight(24, '0'),
      'id_card': fakeIdCard(1),
      'ghb_acc': '2222222222',
      'flg': '5',
      'emp_type': 'G',
      'year': '2566',
      'seq': '2',
      'subseq': '1',
      'amt': 1200.75,
    },
  ];
}

extension _FakePhase2Routes on FakeBackend {
  static final RegExp _idcardPattern = RegExp(r'^\d{13}$');

  static bool _validIdCard(String id) {
    if (!_idcardPattern.hasMatch(id)) return false;
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(id[i]) * (13 - i);
    }
    return (11 - sum % 11) % 10 == int.parse(id[12]);
  }

  /// จำนวนเงินจากคำขอ (ตัวเลขหรือข้อความ) ผิดรูป = null
  static num? _amount(Object? v) {
    if (v is num) return v < 0 || v > 9999999.99 ? null : v;
    final t = '${v ?? ''}'.replaceAll(',', '').trim();
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(t)) return null;
    return num.parse(t);
  }

  Map<String, dynamic> _debtView(Map<String, dynamic> d) => {
    for (final e in d.entries)
      if (e.key != 'in_roster' || p2.sendInRoster) e.key: e.value,
  };

  Map<String, dynamic> _paged(List<Object?> all, int page, int size) => {
    'items': all.skip(page * size).take(size).toList(),
    'currentPage': page,
    'totalItems': all.length,
    'totalPages': (all.length / size).ceil(),
    'pageSize': size,
    'success': true,
  };

  /// เส้นของระยะที่ 2 — ไม่ใช่เส้นของส่วนนี้คืน null
  ResponseBody? phase2(
    RequestOptions options,
    Map<String, dynamic>? body,
    FakeUser me,
  ) {
    final path = options.path;
    final method = options.method;
    final q = options.queryParameters;
    bool has(String role) => me.roles.contains(role);
    ResponseBody conflict(String code, String message, [Map? details]) => _json(
      409,
      {'code': code, 'message': message, 'details': ?details, 'success': false},
    );
    int intOf(Object? v, int fallback) =>
        v is int ? v : int.tryParse('${v ?? ''}') ?? fallback;

    // ============ ก้อน ก: ข้อมูลหลัก ============
    final master = RegExp(
      r'^/api/master/([a-z-]+)(?:/([^/]+))?$',
    ).firstMatch(path);
    if (master != null) {
      if (!has('ACCOUNT')) return _forbidden();
      final res = master.group(1)!;
      final id = master.group(2) == null
          ? null
          : Uri.decodeComponent(master.group(2)!);
      final list = p2.masters[res];
      if (list == null) {
        return _error(404, 'NOT_FOUND', 'ไม่พบข้อมูลหลักที่ระบุ');
      }
      if (res == 'divs' && list.isEmpty) {
        // ตารางหน่วยงานของข้อมูลหลัก = ชุดเดียวกับหน่วยงานของระยะที่ 1
        list.addAll([
          for (var i = 0; i < divs.length; i++)
            {
              'id': 'div${divs[i]['div']}',
              'div': '${divs[i]['div']}',
              'divname': '${divs[i]['divname']}',
              'div_order': '${i + 1}',
              'center_dept': divs[i]['center'] == true ? 't' : 'f',
            },
        ]);
      }
      final keys = FakePhase2.masterKeys[res];
      bool clash(Map<String, String> item, String? exceptId) => list.any(
        (e) => e['id'] != exceptId && keys!.every((k) => e[k] == item[k]),
      );

      if (method == 'GET' && id == null) {
        final keyword = '${q['keyword'] ?? ''}'.trim().toLowerCase();
        final sort = '${q['sort'] ?? FakePhase2.masterDefaultSort[res]}';
        if (list.isNotEmpty && !list.first.containsKey(sort)) {
          return _bad('เรียงด้วยช่อง $sort ไม่ได้');
        }
        final desc = q['dir'] == 'desc';
        final rows = list.where((e) {
          // ตัวกรองของแต่ละตาราง: สาขาตามธนาคาร หน่วยงานตามส่วนกลาง
          for (final f in const ['bank_code', 'center_dept']) {
            if (q[f] != null && e.containsKey(f) && e[f] != '${q[f]}') {
              return false;
            }
          }
          return keyword.isEmpty ||
              e.entries.any(
                (x) => x.key != 'id' && x.value.toLowerCase().contains(keyword),
              );
        }).toList();
        int cmp(Map<String, String> a, Map<String, String> b) {
          final x = a[sort] ?? '';
          final y = b[sort] ?? '';
          final nx = int.tryParse(x);
          final ny = int.tryParse(y);
          return nx != null && ny != null ? nx.compareTo(ny) : x.compareTo(y);
        }

        rows.sort((a, b) => desc ? cmp(b, a) : cmp(a, b));
        return _json(
          200,
          _paged(rows, intOf(q['page'], 0), intOf(q['size'], 10)),
        );
      }
      if (keys == null) {
        return _error(405, 'METHOD_NOT_ALLOWED', 'ไม่รองรับวิธีเรียกนี้');
      }
      Map<String, String> fields() => {
        for (final e in (body ?? const {}).entries)
          e.key: '${e.value ?? ''}'.trim(),
      };
      String? problem(Map<String, String> item) {
        for (final f in FakePhase2.masterRequired[res]!) {
          if ((item[f] ?? '').isEmpty) return 'กรุณาระบุ $f';
        }
        if (res == 'debt-codes' && item['mcode'] == '40604') {
          return 'รหัสหนี้ 40604 ยกเลิกแล้ว เพิ่มไม่ได้';
        }
        if (res == 'branches' &&
            !p2.masters['banks']!.any(
              (b) => b['bank_code'] == item['bank_code'],
            )) {
          return 'ไม่พบธนาคารรหัส ${item['bank_code']}';
        }
        return null;
      }

      if (method == 'POST' && id == null) {
        final item = fields();
        final bad = problem(item);
        if (bad != null) return _bad(bad);
        if (clash(item, null)) {
          return conflict('DUPLICATE', FakeBackend.masterDuplicateMessage);
        }
        item['id'] = p2._newId(res.substring(0, 2));
        list.add(item);
        return _json(200, {
          'item': item,
          'message': FakeBackend.savedMessage,
          'success': true,
        });
      }
      final i = list.indexWhere((e) => e['id'] == id);
      if (i < 0) return _error(404, 'NOT_FOUND', 'ไม่พบรายการที่ระบุ');
      if (method == 'GET') return _json(200, list[i]);

      /// มีข้อมูลอื่นอ้างถึงรายการนี้ไหม
      bool inUse(Map<String, String> e) => switch (res) {
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
      if (method == 'PUT') {
        final merged = {...list[i], ...fields()};
        final bad = problem(merged);
        if (bad != null) return _bad(bad);
        final codeChanged = keys.any((k) => merged[k] != list[i][k]);
        if (codeChanged && inUse(list[i])) {
          return conflict('IN_USE', FakeBackend.masterInUseMessage);
        }
        if (clash(merged, id)) {
          return conflict('DUPLICATE', FakeBackend.masterDuplicateMessage);
        }
        list[i] = merged;
        return _json(200, {
          'item': merged,
          'message': FakeBackend.savedMessage,
          'success': true,
        });
      }
      if (method == 'DELETE') {
        if (inUse(list[i])) {
          return conflict('IN_USE', FakeBackend.masterInUseMessage);
        }
        list.removeAt(i);
        return _json(200, {'message': 'ลบข้อมูลสำเร็จ', 'success': true});
      }
    }

    // ============ ก้อน ข: งานงวด (ACCOUNT) ============
    if (path == '/api/period/dpis-import') {
      if (!has('ACCOUNT')) return _forbidden();
      if (method == 'GET') {
        return _json(200, {
          'g': p2.dpisG,
          'e': p2.dpisE,
          'total': p2.dpisG + p2.dpisE,
          'last_import_at': p2.dpisLastAt,
          'last_import_by': p2.dpisLastBy,
          'success': true,
        });
      }
      if (method == 'POST') {
        if (p2.jobRunning) {
          return conflict('JOB_RUNNING', FakeBackend.jobRunningMessage);
        }
        if (p2.dpisFails) {
          return _error(502, 'DPIS_ERROR', FakeBackend.dpisErrorMessage);
        }
        final previous = p2.dpisG + p2.dpisE;
        p2
          ..dpisG = 31
          ..dpisE = 7
          ..dpisLastAt = '2025-06-25T02:30:00.000+00:00'
          ..dpisLastBy = me.username;
        return _json(200, {
          'g': 31,
          'e': 7,
          'total': 38,
          'previous_total': previous,
          'skipped_invalid_idcard': 1,
          'skipped_duplicate_idcard': 0,
          'message': 'นำเข้าข้อมูลบุคลากรจาก DPIS สำเร็จ',
          'success': true,
        });
      }
    }

    if (path == '/api/period/prepare') {
      if (!has('ACCOUNT')) return _forbidden();
      final existing = p2.debts.length;
      final withDebt = p2.debts
          .where((d) => FakePhase2.codes.any((c) => (d[c] as num) > 0))
          .length;
      final prevMonth = periodMonth == '01'
          ? '12'
          : (int.parse(periodMonth) - 1).toString().padLeft(2, '0');
      final prevYear = periodMonth == '01'
          ? '${int.parse(periodYear) - 1}'
          : periodYear;
      if (method == 'GET') {
        return _json(200, {
          'month': periodMonth,
          'year': periodYear,
          'from_month': prevMonth,
          'from_year': prevYear,
          'current_dpis': p2.dpisG + p2.dpisE,
          'existing_rows': existing,
          'rows_with_debt': withDebt,
          'edits_since_prepare': p2.editsSincePrepare,
          'previous_rows': 30,
          'previous_rows_with_debt': 4,
          'confirm_required': existing > 0,
          'ready': p2.periodReady,
          'last_status': p2.prepareStatus,
          'last_run_at': p2.prepareStatus == null
              ? null
              : '2025-06-21T03:00:00.000+00:00',
          'last_run_by': p2.prepareStatus == null ? null : FakeBackend.account,
          'success': true,
        });
      }
      if (method == 'POST') {
        if (p2.jobRunning) {
          return conflict('JOB_RUNNING', FakeBackend.jobRunningMessage);
        }
        if (p2.dpisG + p2.dpisE == 0) {
          return _bad('ยังไม่มีข้อมูลบุคลากร กรุณานำเข้าข้อมูลบุคลากรก่อน');
        }
        if (existing > 0 && body?['confirm_replace'] != true) {
          return conflict(
            'CONFIRM_REQUIRED',
            'งวดนี้มีรายการอยู่แล้ว $existing รายการ การเตรียมงวดใหม่จะล้างรายการเดิม',
            {
              'month': periodMonth,
              'year': periodYear,
              'rows_to_clear': existing,
              'rows_with_debt': withDebt,
              'edits_since_prepare': p2.editsSincePrepare,
            },
          );
        }
        // ล้างแล้วสร้างใหม่: ยอดของงวดกลับเป็นค่าที่ยกมา (จำลองเป็น 0) และงวดพร้อมใช้
        for (final d in p2.debts) {
          for (final c in FakePhase2.codes) {
            d[c] = 0;
          }
        }
        p2
          ..periodReady = true
          ..prepareStatus = 'DONE'
          ..editsSincePrepare = 0;
        final g = p2.debts.where((d) => d['type'] == 'G').length;
        return _json(200, {
          'month': periodMonth,
          'year': periodYear,
          'from_month': prevMonth,
          'from_year': prevYear,
          'rows': existing,
          'g': g,
          'e': existing - g,
          'carried_over': 4,
          'without_div': 0,
          'cleared_rows': existing,
          'message': 'เตรียมข้อมูลงวดเรียบร้อยแล้ว',
          'success': true,
        });
      }
    }

    // ============ ก้อน ข: รายการหนี้รายเดือน ============
    ResponseBody divForbidden() =>
        _error(403, 'DIV_FORBIDDEN', FakeBackend.divForbiddenMessage);
    ResponseBody? cannotEdit() {
      if (p2.notCurrentPeriod) {
        return conflict(
          'NOT_CURRENT_PERIOD',
          FakeBackend.notCurrentPeriodMessage,
        );
      }
      if (!p2.periodReady) {
        return conflict('PERIOD_NOT_READY', FakeBackend.periodNotReadyMessage);
      }
      if (!_canEditNow(me)) {
        return _error(
          403,
          'EDIT_WINDOW_CLOSED',
          FakeBackend.editWindowClosedMessage,
        );
      }
      return null;
    }

    Map<String, dynamic> listBody(Map<String, dynamic> src) {
      final div = '${src['div'] ?? me.div}';
      final type = src['type']?.toString();
      final name = '${src['name'] ?? ''}'.trim();
      final surname = '${src['surname'] ?? ''}'.trim();
      final month = '${src['month'] ?? periodMonth}';
      final year = '${src['year'] ?? periodYear}';
      final current = month == periodMonth && year == periodYear;
      final rows =
          (current ? p2.debts : p2.pastDebts).where((d) {
            if (!current && (d['month'] != month || d['year'] != year)) {
              return false;
            }
            if (div != '*' && d['div'] != div) return false;
            if (type != null && type.isNotEmpty && d['type'] != type) {
              return false;
            }
            if (name.isNotEmpty && !'${d['name']}'.contains(name)) return false;
            if (surname.isNotEmpty && !'${d['surname']}'.contains(surname)) {
              return false;
            }
            return true;
          }).toList()..sort((a, b) {
            final g = '${b['gender']}'.compareTo('${a['gender']}');
            return g != 0 ? g : '${a['name']}'.compareTo('${b['name']}');
          });
      return {
        ..._paged(
          rows.map(_debtView).toList(),
          intOf(src['page'], 0),
          intOf(src['size'], div == '*' ? 50 : 10),
        ),
        'month': month,
        'year': year,
        'div': div,
        'is_current_period': current,
        'period_ready': p2.periodReady,
        'editable': current && p2.periodReady && _canEditNow(me),
      };
    }

    if (path == '/api/debts' && method == 'GET') {
      if (q.containsKey('name') || q.containsKey('surname')) {
        return _bad('ค้นด้วยชื่อ-สกุลให้ใช้ POST /api/debts/search');
      }
      if (!_canAccessDiv(me, '${q['div'] ?? me.div}')) return divForbidden();
      return _json(200, listBody(Map<String, dynamic>.from(q)));
    }
    if (path == '/api/debts/search' && method == 'POST') {
      final src = body ?? const <String, dynamic>{};
      final div = '${src['div'] ?? me.div}';
      if (div == '*') {
        if (_scope(me) != 'ALL') return divForbidden();
        if ('${src['name'] ?? ''}${src['surname'] ?? ''}'.trim().isEmpty) {
          return _bad('ค้นทุกหน่วยงานต้องระบุชื่อหรือนามสกุล');
        }
      } else if (!_canAccessDiv(me, div)) {
        return divForbidden();
      }
      return _json(200, listBody(src));
    }
    if (path == '/api/debts/summary' && method == 'GET') {
      final div = '${q['div'] ?? me.div}';
      if (!_canAccessDiv(me, div)) return divForbidden();
      final month = '${q['month'] ?? periodMonth}';
      final year = '${q['year'] ?? periodYear}';
      final current = month == periodMonth && year == periodYear;
      final rows = (current ? p2.debts : p2.pastDebts).where(
        (d) =>
            d['div'] == div &&
            (current || (d['month'] == month && d['year'] == year)) &&
            (q['type'] == null || d['type'] == q['type']),
      );
      return _json(200, {
        'month': month,
        'year': year,
        'div': div,
        'type': q['type'],
        'items': [
          for (final c in FakePhase2.codes)
            {
              'code': c.substring(1),
              'field': c,
              'name': FakePhase2.codeNames[c],
              'count': rows.where((d) => (d[c] as num) > 0).length,
              'amount': rows.fold<num>(0, (s, d) => s + (d[c] as num)),
            },
          // หนี้ฌาปนกิจฯ เป็นรายการสุดท้าย ไม่มีช่องให้แก้ (field null)
          {
            'code': '41101',
            'field': null,
            'name': 'หนี้ฌาปนกิจฯ',
            'count': current && p3.chapanaRows > 0 ? rows.length : 0,
            'amount': current && p3.chapanaRows > 0 ? rows.length * 50 : 0,
          },
        ],
        'success': true,
      });
    }
    if (path == '/api/debts' && method == 'PUT') {
      final blocked = cannotEdit();
      if (blocked != null) return blocked;
      final items = (body?['items'] as List? ?? const []).whereType<Map>();
      // ตรวจทุกรายการก่อน มีรายการใดไม่ผ่านจะไม่บันทึกรายการใดเลย
      final plan = <(Map<String, dynamic>, Map<String, num>)>[];
      for (final item in items) {
        final row = p2.debts.where((d) => d['id'] == item['id']).firstOrNull;
        if (row == null) return _error(404, 'NOT_FOUND', 'ไม่พบรายการที่ระบุ');
        if (!_canAccessDiv(me, '${row['div']}')) return divForbidden();
        final changes = <String, num>{};
        for (final e in item.entries) {
          if (e.key == 'id') continue;
          if (!FakePhase2.codes.contains(e.key)) {
            return _bad('แก้ไขช่อง ${e.key} ไม่ได้');
          }
          final v = _amount(e.value);
          if (v == null) return _bad('จำนวนเงินของ ${e.key} ไม่ถูกต้อง');
          changes['${e.key}'] = v;
        }
        plan.add((row, changes));
      }
      var updated = 0;
      for (final (row, changes) in plan) {
        final real = {
          for (final e in changes.entries)
            if (e.value != row[e.key])
              e.key: {'from': row[e.key], 'to': e.value},
        };
        if (real.isEmpty) continue;
        updated++;
        p2.editsSincePrepare++;
        for (final e in changes.entries) {
          row[e.key] = e.value;
        }
        p2.audits.insert(0, {
          'xtion_id': row['id'],
          'action': 'UPDATE',
          'month': periodMonth,
          'year': periodYear,
          'div': row['div'],
          'type': row['type'],
          'idcard': row['idcard'],
          'by': me.username,
          'at': '2025-06-25T09:30:00+07:00',
          'changes': real,
        });
      }
      return _json(200, {
        'items': [for (final (row, _) in plan) _debtView(row)],
        'updated': updated,
        'unchanged': plan.length - updated,
        'message': FakeBackend.savedMessage,
        'success': true,
      });
    }
    final debtOne = RegExp(r'^/api/debts/([^/]+)/audit$').firstMatch(path);
    if (debtOne != null) {
      final row = [...p2.debts, ...p2.pastDebts]
          .where((d) => d['id'] == Uri.decodeComponent(debtOne.group(1)!))
          .firstOrNull;
      if (row == null) return _error(404, 'NOT_FOUND', 'ไม่พบรายการที่ระบุ');
      if (method == 'GET') {
        if (!_canAccessDiv(me, '${row['div']}')) return divForbidden();
        return _json(200, {
          'items': p2.audits.where((a) => a['xtion_id'] == row['id']).toList(),
          'success': true,
        });
      }
    }

    // ============ ก้อน ค: ทะเบียนและเงินกู้ (ACCOUNT) ============
    if (path.startsWith('/api/persons/') ||
        path.startsWith('/api/deducts') ||
        path.startsWith('/api/loans')) {
      if (!has('ACCOUNT')) return _forbidden();
      final idcard = '${body?['idcard'] ?? ''}';

      if (path == '/api/persons/lookup' && method == 'POST') {
        if (!_validIdCard(idcard)) return _bad('เลขประจำตัวประชาชนไม่ถูกต้อง');
        final row = p2.debts.where((d) => d['idcard'] == idcard).firstOrNull;
        final person = p2.people[idcard];
        final found = row != null || person != null;
        return _json(200, {
          'found': found,
          'type': row?['type'] ?? person?.$3 ?? '',
          'in_current_period': row != null,
          'div': row?['div'] ?? '',
          if (found) ...{
            'title': row?['title'] ?? 'นาย',
            'name': row?['name'] ?? person!.$1,
            'surname': row?['surname'] ?? person!.$2,
            'full_name':
                '${row?['title'] ?? 'นาย'}${row?['name'] ?? person!.$1} '
                '${row?['surname'] ?? person!.$2}',
            'birth_date': '05031520',
            'start_date': '01102545',
          },
          'success': true,
        });
      }

      if (path == '/api/deducts/find' && method == 'POST') {
        final item = p2.deducts
            .where((d) => d['id_card'] == idcard)
            .firstOrNull;
        return _json(200, {
          'found': item != null,
          'item': item,
          'duplicates': p2.deductDuplicates[idcard] ?? 0,
          'success': true,
        });
      }
      String? deductProblem(Map<String, dynamic> d) {
        final bank = '${d['bank_code'] ?? ''}';
        final brch = '${d['bank_brch'] ?? ''}';
        if (bank.isNotEmpty &&
            !p2.masters['banks']!.any((b) => b['bank_code'] == bank)) {
          return 'ไม่พบธนาคารรหัส $bank';
        }
        if (brch.isNotEmpty &&
            !p2.masters['branches']!.any(
              (b) => b['bank_code'] == bank && b['bank_brch'] == brch,
            )) {
          return 'ไม่พบสาขา $brch ของธนาคาร $bank';
        }
        final acc = '${d['bank_acc'] ?? ''}';
        if (acc.isNotEmpty && !RegExp(r'^\d{10,15}$').hasMatch(acc)) {
          return 'เลขที่บัญชีธนาคารต้องเป็นตัวเลข 10-15 หลัก';
        }
        for (final f in const ['kbk_dmy', 'kbk_dmy2']) {
          final v = '${d[f] ?? ''}';
          if (v.isNotEmpty && !RegExp(r'^\d{8}$').hasMatch(v)) {
            return 'วันที่ต้องเป็น ddMMyyyy ปี พ.ศ.';
          }
        }
        return null;
      }

      if (path == '/api/deducts' && method == 'POST') {
        final idCard = '${body?['id_card'] ?? ''}';
        if (!_validIdCard(idCard)) return _bad('เลขประจำตัวประชาชนไม่ถูกต้อง');
        if (!const ['G', 'E'].contains(body?['emp_type'])) {
          return _bad('กรุณาระบุประเภทบุคลากร (G หรือ E)');
        }
        if (p2.deducts.any((d) => d['id_card'] == idCard)) {
          return conflict('DUPLICATE', FakeBackend.deductDuplicateMessage);
        }
        final bad = deductProblem(body!);
        if (bad != null) return _bad(bad);
        final item = {
          'rec_flg': '0',
          ...body,
          'id': p2._newId('deduct'),
          'upd_dmy': '25062568',
          'saha_code': '',
        };
        p2.deducts.add(item);
        return _json(200, {
          'item': item,
          'message': FakeBackend.savedMessage,
          'success': true,
        });
      }
      final deductOne = RegExp(r'^/api/deducts/([^/]+)$').firstMatch(path);
      if (deductOne != null && deductOne.group(1) != 'find') {
        final i = p2.deducts.indexWhere(
          (d) => d['id'] == Uri.decodeComponent(deductOne.group(1)!),
        );
        if (i < 0) return _error(404, 'NOT_FOUND', 'ไม่พบรายการที่ระบุ');
        if (method == 'PUT') {
          if (body?.containsKey('id_card') ?? false) {
            return _bad('แก้เลขประจำตัวประชาชนไม่ได้');
          }
          final merged = {...p2.deducts[i], ...?body, 'upd_dmy': '25062568'};
          final bad = deductProblem(merged);
          if (bad != null) return _bad(bad);
          p2.deducts[i] = merged;
          return _json(200, {
            'item': merged,
            'message': FakeBackend.savedMessage,
            'success': true,
          });
        }
        if (method == 'DELETE') {
          p2.deducts.removeAt(i);
          return _json(200, {'message': 'ลบข้อมูลสำเร็จ', 'success': true});
        }
      }

      if (path == '/api/loans/find' && method == 'POST') {
        final items = p2.loans.where((l) => l['id_card'] == idcard).toList()
          ..sort(
            (a, b) => '${a['seq']}${a['subseq']}'.compareTo(
              '${b['seq']}${b['subseq']}',
            ),
          );
        return _json(200, {
          'found': items.isNotEmpty,
          'items': items,
          'success': true,
        });
      }
      String? loanProblem(Map<String, dynamic> l, String? exceptId) {
        if (!RegExp(r'^\d{10,15}$').hasMatch('${l['ghb_acc'] ?? ''}')) {
          return 'เลขที่บัญชีต้องเป็นตัวเลข 10-15 หลัก';
        }
        if (!const ['1', '2', '3', '5', '6'].contains('${l['flg']}')) {
          return 'โครงการเงินกู้ไม่ถูกต้อง';
        }
        if (l['amt'] != null && _amount(l['amt']) == null) {
          return 'จำนวนเงินไม่ถูกต้อง';
        }
        return null;
      }

      bool loanClash(Map<String, dynamic> l, String? exceptId) => p2.loans.any(
        (o) =>
            o['id'] != exceptId &&
            o['id_card'] == l['id_card'] &&
            o['ghb_acc'] == l['ghb_acc'],
      );
      if (path == '/api/loans' && method == 'POST') {
        if (!_validIdCard('${body?['id_card'] ?? ''}')) {
          return _bad('เลขประจำตัวประชาชนไม่ถูกต้อง');
        }
        if (!const ['G', 'E'].contains(body?['emp_type'])) {
          return _bad('กรุณาระบุประเภทบุคลากร (G หรือ E)');
        }
        final bad = loanProblem(body!, null);
        if (bad != null) return _bad(bad);
        if (loanClash(body, null)) {
          return conflict('DUPLICATE', FakeBackend.loanDuplicateMessage);
        }
        final item = {
          ...body,
          'amt': _amount(body['amt'] ?? 0),
          'id': p2._newId('loan'),
        };
        p2.loans.add(item);
        return _json(200, {
          'item': item,
          'message': FakeBackend.savedMessage,
          'success': true,
        });
      }
      final loanOne = RegExp(r'^/api/loans/([^/]+)$').firstMatch(path);
      if (loanOne != null && loanOne.group(1) != 'find') {
        final id = Uri.decodeComponent(loanOne.group(1)!);
        final i = p2.loans.indexWhere((l) => l['id'] == id);
        if (i < 0) return _error(404, 'NOT_FOUND', 'ไม่พบรายการที่ระบุ');
        if (method == 'PUT') {
          final merged = {...p2.loans[i], ...?body};
          if (body?.containsKey('amt') ?? false) {
            merged['amt'] = _amount(body!['amt']) ?? body['amt'];
          }
          final bad = loanProblem(merged, id);
          if (bad != null) return _bad(bad);
          if (loanClash(merged, id)) {
            return conflict('DUPLICATE', FakeBackend.loanDuplicateMessage);
          }
          p2.loans[i] = merged;
          return _json(200, {
            'item': merged,
            'message': FakeBackend.savedMessage,
            'success': true,
          });
        }
        if (method == 'DELETE') {
          p2.loans.removeAt(i);
          return _json(200, {'message': 'ลบข้อมูลสำเร็จ', 'success': true});
        }
      }
    }

    return null;
  }
}
