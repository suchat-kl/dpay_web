import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/period.dart';
import '../utils/file_download.dart';
import 'api_service.dart';

/// เส้นของระยะที่ 3: นำเข้าสหกรณ์/ฌาปนกิจ ไฟล์ส่งกรมบัญชีกลาง กระทบยอดเลขบัญชีเงินกู้ และรายงาน
///
/// สัญญาอยู่ที่ `C:\AI\springboot\dpay\docs\api.md` (ก้อน ง–ฉ) ทุกเส้นรับงวด (ไม่ส่ง = งวดปัจจุบัน)
/// **เลขบัตรและชื่อบุคคลไม่อยู่ใน URL ไม่ลง log** — ไฟล์ที่ดาวน์โหลดรับเป็นไบต์ ไม่แปลงรหัสอักขระ และไม่เก็บลง storage
extension WorkApi on ApiService {
  static Map<String, dynamic> _map(Response<dynamic> r, String fallback) {
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data as Map);
    }
    throw ApiService.errorOf(r, fallback);
  }

  static List<Map<String, dynamic>> _list(Object? v) => [
    for (final e in v as List? ?? const [])
      if (e is Map) Map<String, dynamic>.from(e),
  ];

  static Map<String, dynamic> _period(Period? p) => {...?p?.toJson()};

  /// งานที่ backend ทำนาน (ดึง DPIS / นำเข้าไฟล์ / รายงานทั้งกรม)
  static const Duration _longJob = Duration(minutes: 15);

  /// ชื่อไฟล์จาก header `Content-Disposition` (รองรับ `filename*=UTF-8''...`) ไม่มี = [fallback]
  static String fileNameOf(String? disposition, String fallback) {
    if (disposition == null) return fallback;
    final star = RegExp(
      r"filename\*=(?:UTF-8'')?([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (star != null) {
      try {
        return Uri.decodeComponent(star.group(1)!.trim().replaceAll('"', ''));
      } catch (_) {}
    }
    final plain = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    return plain?.group(1)?.trim() ?? fallback;
  }

  /// ดาวน์โหลดไฟล์เป็นไบต์ — คำตอบที่ไม่ใช่ 200 เป็น JSON ข้อผิดพลาด (เช่น 404 ไม่มีข้อมูลของรายงาน) โยน [ApiException]
  Future<DownloadedFile> downloadFile(
    String path, {
    Map<String, dynamic>? query,
    required String fallbackName,
    String failMessage = 'ดาวน์โหลดไฟล์ไม่สำเร็จ',
  }) async {
    final r = await request(
      'GET',
      path,
      query: query,
      bytes: true,
      receiveTimeout: _longJob,
    );
    final data = r.data;
    if (r.statusCode != 200 || data is! List<int>) {
      throw ApiService.errorOf(r, failMessage);
    }
    return DownloadedFile(
      bytes: data is Uint8List ? data : Uint8List.fromList(data),
      fileName: fileNameOf(
        r.headers.value('content-disposition'),
        fallbackName,
      ),
      mime: (r.headers.value('content-type') ?? 'application/octet-stream')
          .split(';')
          .first
          .trim(),
    );
  }

  // ============ สถานะการบันทึกหนี้รายหน่วยงาน (ACCOUNT) ============

  /// สถานะการบันทึกหนี้ของทุกหน่วยงานในงวด (`GET /api/debts/div-status`)
  /// `{is_current_period, prepared_at, audit_available, summary:{divs, edited, not_edited, rows, rows_with_debt},
  /// items:[{div, divname, div_order, center, g, e, rows, rows_with_debt, edited, edits, last_edit_at, last_edit_by}]}`
  /// `audit_available` เท็จ = งวดนั้นไม่มีประวัติการแก้ไขในระบบใหม่ บอกไม่ได้ว่าใครบันทึกแล้ว
  /// backend ที่ยังไม่มีเส้นนี้ตอบ 404 (โยน [ApiException] ให้หน้าจอแสดงว่ายังใช้ไม่ได้)
  Future<Map<String, dynamic>> getDivStatus({Period? period}) async => _map(
    await request('GET', '/api/debts/div-status', query: _period(period)),
    'โหลดสถานะการบันทึกของหน่วยงานไม่สำเร็จ',
  );

  // ============ ก้อน ง — สหกรณ์ ============

  /// อัปโหลดไฟล์สหกรณ์ (multipart) [dryRun] = ตรวจอย่างเดียวไม่บันทึก
  /// คืน `{dry_run, rows, total_amount, existing_rows, replaced_rows, matched_by_mapping, matched_by_name,
  /// new_mappings, problem_count, problem_counts, problems[], problems_truncated, message}`
  Future<Map<String, dynamic>> importSaha({
    required Uint8List bytes,
    required String fileName,
    required String type,
    Period? period,
    bool dryRun = false,
    bool confirmReplace = false,
  }) async => _map(
    await request(
      'POST',
      '/api/saha/import',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        'type': type,
        ..._period(period),
        'dry_run': '$dryRun',
        'confirm_replace': '$confirmReplace',
      }),
      receiveTimeout: _longJob,
    ),
    'นำเข้าข้อมูลสหกรณ์ไม่สำเร็จ',
  );

  /// การนำเข้าสหกรณ์ที่กำลังทำอยู่ของใครก็ได้ `{running, owner, started_at, expires_at, detail: {type, month, year}}`
  /// (งานที่ server ทำต่อจนเสร็จแม้ผู้สั่งปิดหน้าเว็บ) ไม่มีงาน = `running` เป็นเท็จ
  Future<Map<String, dynamic>> getSahaImportStatus() async => _map(
    await request('GET', '/api/saha/import-status'),
    'โหลดสถานะการนำเข้าสหกรณ์ไม่สำเร็จ',
  );

  /// สรุปข้อมูลสหกรณ์ของงวด `items[]: {type, rows, total_amount, fake_idcard_rows}`
  Future<List<Map<String, dynamic>>> getSahaSummary({Period? period}) async =>
      _list(
        _map(
          await request('GET', '/api/saha/summary', query: _period(period)),
          'โหลดสรุปข้อมูลสหกรณ์ไม่สำเร็จ',
        )['items'],
      );

  /// รายการที่เลขบัตรยังเป็นเลขปลอม (แบบแบ่งหน้า) `items[]: {saha_id, name, type, idcard, total_amount}`
  Future<Map<String, dynamic>> getSahaUnresolved({
    Period? period,
    String? type,
    int page = 0,
    int size = 10,
  }) async => _map(
    await request(
      'GET',
      '/api/saha/unresolved',
      query: {..._period(period), 'type': ?type, 'page': page, 'size': size},
    ),
    'โหลดรายการที่ยังไม่ได้แก้ไม่สำเร็จ',
  );

  /// แก้การจับคู่ของสมาชิกสหกรณ์หนึ่งคน (เลขบัตรอยู่ในตัวคำขอ) คืน `{updated_rows, message}`
  Future<Map<String, dynamic>> setSahaMapping({
    required String sahaId,
    required String idcard,
    required String type,
    Period? period,
  }) async => _map(
    await request(
      'PUT',
      '/api/saha/mapping',
      data: {
        'saha_id': sahaId,
        'idcard': idcard,
        'type': type,
        ..._period(period),
      },
    ),
    'บันทึกการจับคู่ไม่สำเร็จ',
  );

  // ============ ก้อน ง — ฌาปนกิจ ============

  /// ดึงข้อมูลฌาปนกิจของงวดจาก DPIS — มีข้อมูลแล้วต้องส่ง [confirmReplace] (ไม่ส่ง = 409 `CONFIRM_REQUIRED`)
  Future<Map<String, dynamic>> importChapana({
    Period? period,
    bool confirmReplace = false,
  }) async => _map(
    await request(
      'POST',
      '/api/chapana/import',
      data: {..._period(period), 'confirm_replace': confirmReplace},
      receiveTimeout: _longJob,
    ),
    'นำเข้าข้อมูลฌาปนกิจไม่สำเร็จ',
  );

  /// สรุปฌาปนกิจของงวด `{items:[{type, count, amount}], retired}`
  Future<Map<String, dynamic>> getChapanaSummary({Period? period}) async =>
      _map(
        await request('GET', '/api/chapana/summary', query: _period(period)),
        'โหลดสรุปข้อมูลฌาปนกิจไม่สำเร็จ',
      );

  /// ผู้เกษียณ/พ้นสภาพที่ยังอยู่ในรายการฌาปนกิจของงวด
  Future<List<Map<String, dynamic>>> getChapanaRetired({
    Period? period,
  }) async => _list(
    _map(
      await request('GET', '/api/chapana/retired', query: _period(period)),
      'โหลดรายชื่อผู้เกษียณไม่สำเร็จ',
    )['items'],
  );

  // ============ ก้อน ช — เทียบฌาปนกิจกับสลิป ============

  /// เทียบรายการหักฌาปนกิจของงวดกับยอดที่หักได้จริงในสลิป (คำนวณสด เรียกระบบสลิปภาษีและ DPIS — ใช้เวลาหลายวินาที)
  /// `{summary:{chapana_rows, matched, mismatch, not_in_slip, not_paid, chapana_amount, not_paid_amount},
  /// slip:{count, not_in_chapana}, items:[ผู้ที่หักไม่ได้]}` — 503 `SLIP_API_NOT_CONFIGURED`, 502 `SLIP_API_ERROR` / `DPIS_ERROR`
  /// **คำตอบมีเลขบัตรและชื่อ ห้ามลง log / เก็บลง storage**
  Future<Map<String, dynamic>> getChapanaSlipCheck({
    required String type,
    Period? period,
  }) async => _map(
    await request(
      'GET',
      '/api/chapana/slip-check',
      query: {'type': type, ..._period(period)},
      receiveTimeout: _longJob,
    ),
    'เทียบฌาปนกิจกับสลิปไม่สำเร็จ',
  );

  /// รายงาน PDF "รายชื่อบุคคลที่ไม่ถูกหักเงินฌาปนกิจประจำเดือน" — ไม่มีผู้ไม่ถูกหัก = 404
  Future<DownloadedFile> downloadChapanaNotPay({
    required String type,
    Period? period,
  }) => downloadFile(
    '/api/reports/chapana-not-pay',
    query: {'type': type, ..._period(period)},
    fallbackName: 'rep9-$type.pdf',
    failMessage: 'ออกรายงานไม่สำเร็จ',
  );

  // ============ ก้อน จ — ไฟล์ส่งกรมบัญชีกลาง ============

  /// 14 ไฟล์ของงวด `items[]: {name, type, code, count, amount, size, unmappable_chars}`
  Future<List<Map<String, dynamic>>> getCgdFiles({Period? period}) async =>
      _list(
        _map(
          await request('GET', '/api/cgd-files', query: _period(period)),
          'โหลดรายการไฟล์ส่งกรมบัญชีกลางไม่สำเร็จ',
        )['items'],
      );

  Future<DownloadedFile> downloadCgdFile(
    String type,
    String code, {
    required String name,
    Period? period,
  }) => downloadFile(
    '/api/cgd-files/$type/$code',
    query: _period(period),
    fallbackName: name,
  );

  /// zip ทั้งชุด ([type] null = 14 ไฟล์, G/E = 7 ไฟล์)
  Future<DownloadedFile> downloadCgdZip({String? type, Period? period}) =>
      downloadFile(
        '/api/cgd-files/zip',
        query: {..._period(period), 'type': ?type},
        fallbackName: type == null ? 'CGD.zip' : 'CGD-$type.zip',
      );

  // ============ ก้อน จ — กระทบยอดเลขบัญชีเงินกู้ ============

  /// ตรวจยอดเลขบัญชีเงินกู้กับหนี้รายเดือน `{ok, mismatch_count, missing_account, banks[]}`
  Future<Map<String, dynamic>> getLoanCheck({Period? period}) async => _map(
    await request('GET', '/api/loans/check', query: _period(period)),
    'ตรวจยอดเลขบัญชีเงินกู้ไม่สำเร็จ',
  );

  /// ปรับปรุงหนี้ธนาคาร (งวดปัจจุบันเท่านั้น) `{updated, banks:[{bank, updated, manual_count, manual[]}], message}`
  Future<Map<String, dynamic>> syncLoanAmounts() async => _map(
    await request('POST', '/api/loans/sync-amounts', receiveTimeout: _longJob),
    'ปรับปรุงหนี้ธนาคารไม่สำเร็จ',
  );

  Future<DownloadedFile> downloadLoanMismatchFile({Period? period}) =>
      downloadFile(
        '/api/loans/mismatch-file',
        query: _period(period),
        fallbackName: 'Bank.txt',
      );

  /// คนที่มีหนี้ธนาคารแต่ไม่มีเลขบัญชี `{count, items[]}`
  Future<Map<String, dynamic>> getMissingAccounts({Period? period}) async =>
      _map(
        await request(
          'GET',
          '/api/loans/missing-accounts',
          query: _period(period),
        ),
        'โหลดรายชื่อบุคคลที่ไม่มีเลขบัญชีไม่สำเร็จ',
      );

  Future<DownloadedFile> downloadMissingAccountsFile({Period? period}) =>
      downloadFile(
        '/api/loans/missing-accounts-file',
        query: _period(period),
        fallbackName: 'Acc.txt',
      );

  // ============ ก้อน ฉ — รายงาน ============

  /// รายงาน PDF [name] = rep1 / rep2 / rep3 / rep4 / debt-change / rep2-all-dept / rep10
  /// ไม่มีข้อมูล = 404 `NOT_FOUND` (โยน [ApiException] พร้อมข้อความของ backend)
  Future<DownloadedFile> downloadReport(
    String name, {
    Period? period,
    String? type,
    String? div,
    String? bank,
  }) => downloadFile(
    '/api/reports/$name',
    query: {..._period(period), 'type': ?type, 'div': ?div, 'bank': ?bank},
    fallbackName: '$name.pdf',
    failMessage: 'ออกรายงานไม่สำเร็จ',
  );

  /// รายงานส่งธนาคาร (xlsx) [bank] = AIA / GHB / GSB / KTB — ยอดเลขบัญชียังไม่ตรง = 409 `LOAN_AMOUNT_MISMATCH`
  Future<DownloadedFile> downloadBankReport(String bank, {Period? period}) =>
      downloadFile(
        '/api/reports/bank/$bank',
        query: _period(period),
        fallbackName: 'rep-$bank.xlsx',
        failMessage: 'ออกรายงานส่งธนาคารไม่สำเร็จ',
      );
}
