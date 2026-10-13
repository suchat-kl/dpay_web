import 'package:dio/dio.dart';

import '../models/debt.dart';
import '../models/period.dart';
import 'api_service.dart';

/// เส้นของระยะที่ 2: ข้อมูลหลัก งานงวด รายการหนี้รายเดือน ทะเบียนบุคลากร และเลขบัญชีเงินกู้
///
/// สัญญาอยู่ที่ `C:\AI\springboot\dpay\docs\api.md` (ก้อน ก–ค)
/// **เลขบัตรประชาชนและชื่อบุคคลส่งในตัวคำขอ (POST) เท่านั้น ไม่อยู่ใน URL และไม่ลง log**
extension DebtApi on ApiService {
  static Map<String, dynamic> _map(Response<dynamic> r, String fallback) {
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data as Map);
    }
    throw ApiService.errorOf(r, fallback);
  }

  /// งานที่ backend ทำนาน (ดึง DPIS ครั้งละ 300 คน / เตรียมงวดทั้งกรม)
  static const Duration _longJob = Duration(minutes: 15);

  // ============ ก้อน ก — ข้อมูลหลัก (ACCOUNT) ============

  /// รายการข้อมูลหลักแบบแบ่งหน้า [resource] = banks / branches / debt-codes / divs / provinces
  /// คืน `{items, currentPage, totalItems, totalPages, pageSize}`
  Future<Map<String, dynamic>> listMaster(
    String resource, {
    String? keyword,
    int page = 0,
    int size = 10,
    String? sort,
    bool descending = false,
    Map<String, String> filters = const {},
  }) async => _map(
    await request(
      'GET',
      '/api/master/$resource',
      query: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'page': page,
        'size': size,
        if (sort != null) ...{'sort': sort, 'dir': descending ? 'desc' : 'asc'},
        ...filters,
      },
    ),
    'โหลดข้อมูลไม่สำเร็จ',
  );

  /// ทุกรายการของข้อมูลหลัก สำหรับทำตัวเลือก (size=2000)
  Future<List<Map<String, String>>> allMaster(
    String resource, {
    Map<String, String> filters = const {},
  }) async {
    final body = await listMaster(resource, size: 2000, filters: filters);
    return [
      for (final e in body['items'] as List? ?? const [])
        if (e is Map) e.map((k, v) => MapEntry('$k', v == null ? '' : '$v')),
    ];
  }

  Future<Map<String, dynamic>> createMaster(
    String resource,
    Map<String, String> fields,
  ) async => _map(
    await request('POST', '/api/master/$resource', data: fields),
    'เพิ่มข้อมูลไม่สำเร็จ',
  );

  Future<Map<String, dynamic>> updateMaster(
    String resource,
    String id,
    Map<String, String> fields,
  ) async => _map(
    await request(
      'PUT',
      '/api/master/$resource/${Uri.encodeComponent(id)}',
      data: fields,
    ),
    'บันทึกข้อมูลไม่สำเร็จ',
  );

  /// ลบหลายรายการในคำขอเดียว (`POST /api/master/{resource}/delete`) ตอบ 200 เสมอเมื่อคำขอถูกรูป
  /// คืนผลรายรายการ `[{id, deleted, code, message}]` — รายการที่ลบไม่ได้ (`IN_USE`, `NOT_FOUND`) มี `deleted: false`
  Future<List<Map<String, dynamic>>> deleteMasterMany(
    String resource,
    List<String> ids,
  ) async {
    final body = _map(
      await request('POST', '/api/master/$resource/delete', data: {'ids': ids}),
      'ลบข้อมูลไม่สำเร็จ',
    );
    return [
      for (final e in body['results'] as List? ?? const [])
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  // ============ ก้อน ข — งานงวด (ACCOUNT) ============

  /// ข้อมูลบุคลากรที่นำเข้าไว้ `{g, e, total, last_import_at, last_import_by}`
  Future<Map<String, dynamic>> getDpisImport() async => _map(
    await request('GET', '/api/period/dpis-import'),
    'โหลดสถานะการนำเข้าไม่สำเร็จ',
  );

  /// สั่งนำเข้าบุคลากรจาก DPIS (แทนที่ทั้งชุด) สั่งซ้อน = 409 JOB_RUNNING, DPIS ล่ม = 502 DPIS_ERROR
  Future<Map<String, dynamic>> runDpisImport() async => _map(
    await request('POST', '/api/period/dpis-import', receiveTimeout: _longJob),
    'นำเข้าข้อมูลบุคลากรไม่สำเร็จ',
  );

  /// สรุปก่อนเตรียมงวด (จำนวนรายการเดิม จำนวนที่มีหนี้ จำนวนที่ถูกแก้ ต้องยืนยันไหม)
  Future<Map<String, dynamic>> getPrepare() async => _map(
    await request('GET', '/api/period/prepare'),
    'โหลดสรุปการเตรียมงวดไม่สำเร็จ',
  );

  /// สั่งเตรียมงวดปัจจุบันจากเดือนก่อน งวดมีรายการแล้วแต่ไม่ยืนยัน = 409 CONFIRM_REQUIRED (มี details)
  Future<Map<String, dynamic>> runPrepare({
    bool confirmReplace = false,
  }) async => _map(
    await request(
      'POST',
      '/api/period/prepare',
      data: {if (confirmReplace) 'confirm_replace': true},
      receiveTimeout: _longJob,
    ),
    'เตรียมข้อมูลงวดไม่สำเร็จ',
  );

  // ============ ก้อน ข — รายการหนี้รายเดือน ============

  /// รายการหนี้ของหน่วยงาน [div] ประเภท [type] — ไม่ส่ง [period] = งวดปัจจุบัน
  /// (ส่งงวดย้อนหลัง = ดูได้อย่างเดียว backend ตอบ `is_current_period` เท็จ)
  /// มี [name] หรือ [surname] = ค้นด้วย `POST /api/debts/search` (ชื่อไม่อยู่ใน URL)
  /// ค้นทุกหน่วยงานทุกประเภท (เฉพาะผู้ที่เลือกได้ทุกหน่วยงาน): [div] = `*` ไม่ส่ง [type] และต้องมีชื่อหรือนามสกุล
  Future<DebtPage> getDebts({
    required String div,
    String? type,
    Period? period,
    String? name,
    String? surname,
    int page = 0,
    int size = 10,
  }) async {
    final n = (name ?? '').trim();
    final s = (surname ?? '').trim();
    final Response<dynamic> r;
    if (n.isEmpty && s.isEmpty) {
      r = await request(
        'GET',
        '/api/debts',
        query: {
          'type': ?type,
          'div': div,
          ...?period?.toJson(),
          'page': page,
          'size': size,
        },
      );
    } else {
      r = await request(
        'POST',
        '/api/debts/search',
        data: {
          'type': ?type,
          'div': div,
          ...?period?.toJson(),
          if (n.isNotEmpty) 'name': n,
          if (s.isNotEmpty) 'surname': s,
          'page': page,
          'size': size,
        },
      );
    }
    return DebtPage.fromJson(_map(r, 'โหลดรายการหนี้ไม่สำเร็จ'));
  }

  /// ค้นบุคคลด้วยชื่อ-สกุลทุกหน่วยงานของงวดปัจจุบัน (ACCOUNT — `POST /api/persons/search` ชื่อไม่อยู่ใน URL)
  /// คืนสูงสุด 50 คน `truncated` จริง = ยังมีอีก ให้พิมพ์ให้เจาะจงขึ้น
  Future<(List<PersonHit>, bool)> searchPersons({
    String? name,
    String? surname,
  }) async {
    final body = _map(
      await request(
        'POST',
        '/api/persons/search',
        data: {
          if ((name ?? '').trim().isNotEmpty) 'name': name!.trim(),
          if ((surname ?? '').trim().isNotEmpty) 'surname': surname!.trim(),
        },
      ),
      'ค้นหาบุคคลไม่สำเร็จ',
    );
    return (
      [
        for (final e in body['items'] as List? ?? const [])
          if (e is Map) PersonHit.fromJson(Map<String, dynamic>.from(e)),
      ],
      body['truncated'] == true,
    );
  }

  /// ยอดรวมต่อรหัสหนี้และจำนวนคนของหน่วยงาน/ประเภท — ไม่ส่ง [period] = งวดปัจจุบัน
  Future<List<DebtSummaryItem>> getDebtSummary({
    required String div,
    required String type,
    Period? period,
  }) async {
    final body = _map(
      await request(
        'GET',
        '/api/debts/summary',
        query: {'type': type, 'div': div, ...?period?.toJson()},
      ),
      'โหลดยอดรวมไม่สำเร็จ',
    );
    return [
      for (final e in body['items'] as List? ?? const [])
        if (e is Map) DebtSummaryItem.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// บันทึกยอดหลายแถวในคำขอเดียว (เฉพาะแถว/รหัสที่แก้) backend ตรวจทุกรายการก่อน ไม่ผ่าน = ไม่บันทึกเลย
  /// คืน `{updated, unchanged, message}`
  Future<Map<String, dynamic>> saveDebts(List<DebtRow> rows) async => _map(
    await request(
      'PUT',
      '/api/debts',
      data: {
        'items': [for (final r in rows) r.toUpdateJson()],
      },
    ),
    'บันทึกรายการหนี้ไม่สำเร็จ',
  );

  /// ประวัติการแก้ไขของรายการหนึ่ง (ใหม่สุดก่อน)
  Future<List<DebtAudit>> getDebtAudit(String id) async {
    final body = _map(
      await request('GET', '/api/debts/${Uri.encodeComponent(id)}/audit'),
      'โหลดประวัติการแก้ไขไม่สำเร็จ',
    );
    return [
      for (final e in body['items'] as List? ?? const [])
        if (e is Map) DebtAudit.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  // ============ ก้อน ค — ทะเบียนบุคลากรและเลขบัญชีเงินกู้ (ACCOUNT) ============

  /// ถามข้อมูลบุคคลด้วยเลขบัตร (งวดปัจจุบัน → ข้อมูลที่นำเข้า → DPIS)
  Future<PersonInfo> lookupPerson(String idcard) async => PersonInfo.fromJson(
    _map(
      await request('POST', '/api/persons/lookup', data: {'idcard': idcard}),
      'ค้นหาบุคคลไม่สำเร็จ',
    ),
  );

  /// ทะเบียนธนาคาร/กบข./สหกรณ์/ลดหย่อนภาษีของคนหนึ่ง คืน `{found, item, duplicates}`
  Future<Map<String, dynamic>> findDeduct(String idcard) async => _map(
    await request('POST', '/api/deducts/find', data: {'idcard': idcard}),
    'โหลดทะเบียนไม่สำเร็จ',
  );

  /// บันทึกทะเบียน: [id] ว่าง = สร้างใหม่ (ต้องมี id_card, emp_type) ไม่ว่าง = แก้ไข (ไม่ส่ง id_card)
  Future<Map<String, dynamic>> saveDeduct(
    String id,
    Map<String, String> fields,
  ) async => _map(
    id.isEmpty
        ? await request('POST', '/api/deducts', data: fields)
        : await request(
            'PUT',
            '/api/deducts/${Uri.encodeComponent(id)}',
            data: fields,
          ),
    'บันทึกทะเบียนไม่สำเร็จ',
  );

  Future<void> deleteDeduct(String id) async {
    _map(
      await request('DELETE', '/api/deducts/${Uri.encodeComponent(id)}'),
      'ลบทะเบียนไม่สำเร็จ',
    );
  }

  /// เลขบัญชีเงินกู้ทั้งหมดของคนหนึ่ง เรียงตาม seq, subseq
  Future<List<Map<String, dynamic>>> findLoans(String idcard) async {
    final body = _map(
      await request('POST', '/api/loans/find', data: {'idcard': idcard}),
      'โหลดเลขบัญชีเงินกู้ไม่สำเร็จ',
    );
    return [
      for (final e in body['items'] as List? ?? const [])
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  /// บันทึกเลขบัญชีเงินกู้ทั้งชุดของหนึ่งคน (`PUT /api/loans/set`) — [items] คือทุกบัญชีของคนนั้นหลังบันทึก
  /// (`[]` = ลบทั้งหมด) backend ตรวจทุกรายการก่อน รายการใดผิด (400) หรือซ้ำ (409) จะไม่บันทึกอะไรเลย
  Future<Map<String, dynamic>> setLoans(
    String idcard,
    List<Map<String, String>> items,
  ) async => _map(
    await request(
      'PUT',
      '/api/loans/set',
      data: {'id_card': idcard, 'items': items},
    ),
    'บันทึกเลขบัญชีเงินกู้ไม่สำเร็จ',
  );
}
