import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/period.dart';
import '../services/api_service.dart';
import '../services/work_api.dart';
import '../utils/file_download.dart';
import '../utils/permission.dart';
import '../widgets/loan_gate.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';

/// ไฟล์ส่งกรมบัญชีกลาง (ACCOUNT) — 14 ไฟล์ต่องวด (ข้าราชการ/ลูกจ้างประจำ × 6 รหัส + ไฟล์สรุป)
///
/// `GET /api/cgd-files` แสดงจำนวนคน/ยอดต่อไฟล์ ดาวน์โหลดรายไฟล์ (`/api/cgd-files/{type}/{code}`)
/// หรือ zip ทั้งชุด/ต่อประเภท (`/api/cgd-files/zip`) ไฟล์สร้างตอนเรียก ไม่มีขั้น "สร้างไฟล์" แยกเหมือนระบบเดิม
/// **รับเป็นไบต์แล้วส่งต่อให้เบราว์เซอร์เท่าเดิมทุกไบต์** (TIS-620) ไม่แปลงเป็นข้อความ
///
/// งวดปัจจุบันต้องผ่านข้อ 8 ก่อน ([LoanGate]) ไม่ผ่าน = ดูตารางได้แต่ดาวน์โหลดไม่ได้
class CgdFilesScreen extends StatefulWidget {
  final ApiService apiService;

  const CgdFilesScreen({super.key, required this.apiService});

  static const String menuTitle = 'ดาวน์โหลดไฟล์ข้อความส่งกรมบัญชีกลาง';
  static const IconData menuIcon = Icons.account_balance;
  static const String groupTitle = 'ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร';

  static const Key zipAllKey = ValueKey('cgd-zip-all');
  static Key zipKey(String type) => ValueKey('cgd-zip-$type');
  static Key fileKey(String type, String code) => ValueKey('cgd-$type-$code');
  static Key rowKey(String type, String code) =>
      ValueKey('cgd-row-$type-$code');

  /// ชื่อของไฟล์ตามรหัส (ชื่อที่ผู้ใช้คุ้นจากเมนูของระบบเดิม)
  static const Map<String, String> codeNames = {
    '40302': 'ธ.อาคารสงเคราะห์',
    '40303': 'ธ.ออมสิน',
    '40803': 'AIA ประกันชีวิต',
    '40315': 'ธ.กรุงไทย',
    '41100': 'หนี้สินอื่นๆ',
    '41101': 'ฌาปนกิจ',
    'Sum': 'ไฟล์รวมจำนวนหนี้ คน',
  };

  static const String gateAction = 'ดาวน์โหลดไฟล์ส่งกรมบัญชีกลาง';

  static const String emptyFileText = 'ไฟล์ว่าง (ไม่มีผู้มียอดของรหัสนี้)';
  static String unmappableText(int n) =>
      'มีอักขระ $n ตัวที่รหัส TIS-620 ไม่มี ในไฟล์จะเป็น "?" — ตรวจชื่อของบุคคลก่อนส่ง';

  @override
  State<CgdFilesScreen> createState() => _CgdFilesScreenState();
}

class _CgdFilesScreenState extends State<CgdFilesScreen>
    with FileDownloads<CgdFilesScreen> {
  Period? _past;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  /// ข้อความของด่านข้อ 8 — null = ผ่าน (หรือเป็นงวดย้อนหลัง)
  String? _gate;

  /// ดาวน์โหลดไม่ได้: มีไฟล์อื่นกำลังโหลดอยู่ หรือยังไม่ผ่านข้อ 8
  bool get _blocked => downloading != null || _gate != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    clearSaved();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.apiService.getCgdFiles(period: _past);
      final gate = await _checkGate();
      if (!mounted) return;
      setState(() {
        _items = items;
        _gate = gate;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// ตรวจข้อ 8 ของงวดปัจจุบัน — ตรวจไม่สำเร็จถือว่ายังไม่ผ่าน
  Future<String?> _checkGate() async {
    if (_past != null) return null;
    try {
      final check = await widget.apiService.getLoanCheck();
      return LoanGate.passed(check)
          ? null
          : LoanGate.message(check, CgdFilesScreen.gateAction);
    } catch (e) {
      return LoanGate.failedText('$e');
    }
  }

  /// ดาวน์โหลด [key] — backend ตอบ 409 LOAN_CHECK_REQUIRED (ผลตรวจเปลี่ยนระหว่างเปิดหน้า) = ล็อกหน้าด้วยแถบเตือน
  Future<void> _download(String key, Future<DownloadedFile> Function() fetch) =>
      runDownload(
        key,
        fetch,
        onError: (e) {
          if (e.code != ErrorCodes.loanCheckRequired) return false;
          _gate = LoanGate.fromError(e, CgdFilesScreen.gateAction);
          return true;
        },
      );

  Widget _row(Map<String, dynamic> f) {
    final type = '${f['type']}';
    final code = '${f['code']}';
    final key = '$type-$code';
    final bad = intOf(f['unmappable_chars']);
    final empty = code != 'Sum' && intOf(f['size']) == 0;
    return Column(
      key: CgdFilesScreen.rowKey(type, code),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CgdFilesScreen.codeNames[code] ?? code,
                      style: screenText(size: 14.5, weight: FontWeight.w600),
                    ),
                    Text(
                      '${f['name'] ?? ''}',
                      style: screenText(
                        size: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                countText(f['count']),
                textAlign: TextAlign.right,
                style: screenText(size: 14.5),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  moneyText(f['amount']),
                  textAlign: TextAlign.right,
                  style: screenText(size: 14.5),
                ),
              ),
            ),
            SizedBox(
              width: 132,
              child: Align(
                alignment: Alignment.centerRight,
                child: SheetButton(
                  downloading == key ? 'กำลังโหลด' : 'ดาวน์โหลด',
                  key: CgdFilesScreen.fileKey(type, code),
                  icon: savedOf(key) != null ? Icons.check : Icons.download,
                  color: AppTheme.primaryColor,
                  onPressed: _blocked
                      ? null
                      : () => _download(
                          key,
                          () => widget.apiService.downloadCgdFile(
                            type,
                            code,
                            name: '${f['name'] ?? '$key.txt'}',
                            period: _past,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        if (empty)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: Text(
              CgdFilesScreen.emptyFileText,
              style: screenText(size: 12.5, color: AppTheme.textSecondary),
            ),
          ),
        if (bad > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Text(
              CgdFilesScreen.unmappableText(bad),
              style: screenText(size: 13, color: AppTheme.warningColor),
            ),
          ),
      ],
    );
  }

  Widget _group(String type) {
    final rows = _items.where((f) => f['type'] == type).toList();
    return StepCard(
      icon: type == EmpType.g
          ? Icons.account_balance
          : Icons.account_balance_outlined,
      title: EmpType.nameOf(type),
      subtitle: '${rows.length} ไฟล์',
      trailing: SheetButton(
        'zip ${EmpType.nameOf(type)}',
        key: CgdFilesScreen.zipKey(type),
        icon: Icons.folder_zip_outlined,
        onPressed: _blocked || rows.isEmpty
            ? null
            : () => _download(
                'zip-$type',
                () =>
                    widget.apiService.downloadCgdZip(type: type, period: _past),
              ),
      ),
      child: SheetScroll(
        minWidth: 560,
        child: SheetCard(
          emptyText: 'ไม่มีไฟล์ของงวดนี้',
          header: const Row(
            children: [
              Expanded(flex: 6, child: SheetHead('ไฟล์')),
              Expanded(
                flex: 2,
                child: SheetHead('จำนวนคน', align: TextAlign.right),
              ),
              Expanded(
                flex: 3,
                child: SheetHead('ยอดรวม', align: TextAlign.right),
              ),
              SizedBox(width: 132),
            ],
          ),
          rows: [for (final f in rows) _row(f)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zipDone = savedOf('zip');
    return WorkPage(
      group: CgdFilesScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: CgdFilesScreen.menuIcon,
          title: CgdFilesScreen.menuTitle,
          subtitle:
              'ไฟล์ข้อความส่งกรมบัญชีกลางของงวด 14 ไฟล์ สร้างจากยอดล่าสุดทุกครั้งที่ดาวน์โหลด',
          bullets: [
            'งวดปัจจุบันต้องผ่าน "ตรวจยอดเงินกู้กับหนี้เดือน" ก่อน (ยอดตรงทุกธนาคารและไม่มีคนที่ไม่มีเลขบัญชี) จึงดาวน์โหลดได้',
            'นำเข้าฌาปนกิจ/สหกรณ์ให้เรียบร้อยก่อนส่งไฟล์',
            'ไฟล์มีข้อมูลบุคคล เก็บและส่งต่อด้วยความระมัดระวัง',
          ],
        ),
        const SizedBox(height: 14),
        PeriodPicker(
          past: _past,
          enabled: !_loading && downloading == null,
          onChanged: (p) {
            setState(() => _past = p);
            _load();
          },
        ),
        const SizedBox(height: 12),
        for (final e in [_error, downloadError])
          if (e != null) ...[
            NoticeBar(type: NoticeType.error, text: e),
            const SizedBox(height: 12),
          ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error == null) ...[
          if (_gate != null) ...[
            LoanGateNotice(
              apiService: widget.apiService,
              text: _gate!,
              onReturn: () {
                if (mounted) _load();
              },
            ),
            const SizedBox(height: 12),
          ],
          DownloadButtons(
            key: CgdFilesScreen.zipAllKey,
            label: 'ดาวน์โหลดทั้งชุด (zip 14 ไฟล์)',
            icon: Icons.folder_zip,
            busy: downloading == 'zip',
            blocked: _blocked || _items.isEmpty,
            saved: zipDone,
            onDownload: () => _download(
              'zip',
              () => widget.apiService.downloadCgdZip(period: _past),
            ),
          ),
          const SizedBox(height: 12),
          _group(EmpType.g),
          const SizedBox(height: 12),
          _group(EmpType.e),
        ],
      ],
    );
  }
}
