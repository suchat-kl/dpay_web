import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/div_dept.dart';
import '../models/period.dart';
import '../services/api_service.dart';
import '../services/work_api.dart';
import '../utils/file_download.dart';
import '../utils/permission.dart';
import '../widgets/div_selector.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';
import 'loan_check_screen.dart';

/// หนึ่งรายงาน PDF ของหน้า "รายงาน"
class ReportDef {
  /// คีย์ภายในหน้าจอ (ไม่ซ้ำ) และชื่อเส้น `/api/reports/<name>`
  final String key;
  final String name;
  final String title;
  final String description;

  /// ต้องส่งประเภทบุคลากร (G/E)
  final bool needsType;

  /// ธนาคารของรายงานเงินหนี้เปลี่ยน (GHB/GSB/KTB)
  final String? bank;

  /// เฉพาะฝ่ายบัญชี (ทั้งกรม ไม่ส่งหน่วยงาน)
  final bool accountOnly;

  const ReportDef({
    required this.key,
    required this.name,
    required this.title,
    required this.description,
    this.needsType = false,
    this.bank,
    this.accountOnly = false,
  });
}

/// รายงาน (ทุกบทบาท ตามขอบเขตหน่วยงาน) — เลือกงวด ประเภท หน่วยงาน แล้วออกเป็น PDF
///
/// ทุกเส้นเป็น `GET /api/reports/...` ตอบเป็นไฟล์ทันที ดาวน์โหลดผ่าน [FileSaver] แล้วมีปุ่ม "เปิดดู"
/// - ไม่มีข้อมูล = 404 `NOT_FOUND` → แสดง "ไม่มีข้อมูลของงวด/หน่วยงานนี้" ใต้รายงานนั้น
/// - ระหว่างสร้างไฟล์ปุ่มออกรายงานทุกปุ่มกดไม่ได้ (กันกดซ้ำ) และแสดงสถานะกำลังสร้าง
/// - "ทุกหน่วยงาน" มีเฉพาะผู้ที่ขอบเขตหน่วยงานเป็น ALL และใช้กับรายงานเงินหนี้เปลี่ยนเท่านั้น (`div=*`)
/// - รายงานทั้งกรมของฝ่ายบัญชี (สรุปหน่วยงานประจำเดือน, ผู้เกษียณในรายการฌาปนกิจ) แสดงเฉพาะ ACCOUNT
class ReportScreen extends StatefulWidget {
  final ApiService apiService;

  const ReportScreen({super.key, required this.apiService});

  static const String menuTitle = 'รายงาน';
  static const IconData menuIcon = Icons.assessment_outlined;
  static const String groupTitle = 'งานหักหนี้';

  static const Key allDivsKey = ValueKey('report-all-divs');
  static Key typeKey(String type) => ValueKey('report-type-$type');
  static Key runKey(String key) => ValueKey('report-run-$key');
  static Key noteKey(String key) => ValueKey('report-note-$key');

  static const String noDataText = 'ไม่มีข้อมูลของงวด/หน่วยงานนี้';
  static const String allDivsLabel = 'ทุกหน่วยงาน (เฉพาะรายงานเงินหนี้เปลี่ยน)';
  static const String runLabel = 'ออกรายงาน';

  static const List<ReportDef> reports = [
    ReportDef(
      key: 'rep1',
      name: 'rep1',
      title: 'รายละเอียดการหักเงิน',
      description: 'เงินหักประจำเดือนรายคนของหน่วยงาน ตามประเภทที่เลือก',
      needsType: true,
    ),
    ReportDef(
      key: 'rep2',
      name: 'rep2',
      title: 'สรุปจำนวนเงินหัก',
      description: 'สรุปเงินหักของหน่วยงาน รวมข้าราชการและลูกจ้างประจำ',
    ),
    ReportDef(
      key: 'rep3',
      name: 'rep3',
      title: 'รายละเอียดข้อมูลธนาคาร กบข/กสจ ฌาปนกิจ สหกรณ์',
      description: 'ข้อมูลทะเบียนของบุคลากรในหน่วยงาน ตามประเภทที่เลือก',
      needsType: true,
    ),
    ReportDef(
      key: 'rep4',
      name: 'rep4',
      title: 'รายชื่อบุคคลเพิ่มลดประจำเดือน',
      description: 'เทียบกับเดือนก่อน รายละเอียดถามจากระบบบุคลากร (DPIS)',
      needsType: true,
    ),
    ReportDef(
      key: 'debt-change-GHB',
      name: 'debt-change',
      title: 'เงินหนี้เปลี่ยน ธอส.',
      description:
          'รายชื่อบุคคลเพิ่ม/ลด/เงินเปลี่ยนแปลงของธนาคารอาคารสงเคราะห์',
      bank: 'GHB',
    ),
    ReportDef(
      key: 'debt-change-GSB',
      name: 'debt-change',
      title: 'เงินหนี้เปลี่ยน ออมสิน',
      description: 'รายชื่อบุคคลเพิ่ม/ลด/เงินเปลี่ยนแปลงของธนาคารออมสิน',
      bank: 'GSB',
    ),
    ReportDef(
      key: 'debt-change-KTB',
      name: 'debt-change',
      title: 'เงินหนี้เปลี่ยน กรุงไทย',
      description: 'รายชื่อบุคคลเพิ่ม/ลด/เงินเปลี่ยนแปลงของธนาคารกรุงไทย',
      bank: 'KTB',
    ),
    ReportDef(
      key: 'rep2-all-dept',
      name: 'rep2-all-dept',
      title: 'รายละเอียดหักเงินสรุปหน่วยงานประจำเดือน',
      description: 'สรุปเงินหักทุกหน่วยงานทั้งกรม (ฝ่ายบัญชี)',
      accountOnly: true,
    ),
    ReportDef(
      key: 'rep10',
      name: 'rep10',
      title: 'ผู้เกษียณในรายการฌาปนกิจ',
      description:
          'ผู้เกษียณ/พ้นสภาพที่ยังมีรายการหักฌาปนกิจของงวด (ฝ่ายบัญชี)',
      accountOnly: true,
    ),
  ];

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with FileDownloads<ReportScreen> {
  Period? _past;
  String _type = EmpType.g;
  DivDept? _div;
  bool _allDivs = false;

  /// ข้อความใต้รายงาน (คีย์รายงาน -> ข้อความ) เช่น ไม่มีข้อมูล
  final Map<String, String> _notes = {};

  bool get _isAccount => widget.apiService.hasRole(Roles.account);
  bool get _canAllDivs => widget.apiService.divScope == DivScope.all;

  /// เปลี่ยนตัวเลือก: ไฟล์และข้อความเดิมไม่ตรงกับตัวเลือกใหม่แล้ว
  void _changed(VoidCallback apply) {
    clearSaved();
    setState(() {
      _notes.clear();
      downloadError = null;
      apply();
    });
  }

  Future<void> _run(ReportDef r) async {
    setState(() => _notes.remove(r.key));
    final div = r.accountOnly
        ? null
        : (r.bank != null && _allDivs ? '*' : _div?.div);
    await runDownload(
      r.key,
      () => widget.apiService.downloadReport(
        r.name,
        period: _past,
        type: r.needsType ? _type : null,
        div: div,
        bank: r.bank,
      ),
      onError: (e) {
        // ไม่มีข้อมูลของรายงาน: บอกใต้รายงานนั้น (ไม่ใช่ข้อผิดพลาดของระบบ)
        if (e.statusCode == 404) {
          _notes[r.key] = ReportScreen.noDataText;
          return true;
        }
        _notes[r.key] = e.code == ErrorCodes.dpisError
            ? '${e.message}\nลองออกรายงานใหม่ภายหลัง'
            : e.message;
        return true;
      },
    );
  }

  Widget _card(ReportDef r) {
    final note = _notes[r.key];
    final missing = note == ReportScreen.noDataText;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(r.title, style: screenText(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            r.description,
            style: screenText(size: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          DownloadButtons(
            key: ReportScreen.runKey(r.key),
            label: ReportScreen.runLabel,
            icon: Icons.picture_as_pdf_outlined,
            busy: downloading == r.key,
            blocked: downloading != null || (!r.accountOnly && _div == null),
            saved: savedOf(r.key),
            canOpen: true,
            onDownload: () => _run(r),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            NoticeBar(
              key: ReportScreen.noteKey(r.key),
              type: missing ? NoticeType.info : NoticeType.error,
              text: note,
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, String subtitle, List<ReportDef> items) =>
      StepCard(
        icon: Icons.description_outlined,
        title: title,
        subtitle: subtitle,
        child: ResponsiveGrid(
          minItemWidth: 280,
          maxColumns: 2,
          spacing: 10,
          children: [for (final r in items) _card(r)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final busy = downloading != null;
    final perDiv = ReportScreen.reports.where((r) => !r.accountOnly);
    final scope = _allDivs
        ? 'ทุกหน่วยงาน'
        : (_div == null ? '-' : 'หน่วยงาน ${_div!.label}');
    return WorkPage(
      group: ReportScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: ReportScreen.menuIcon,
          title: ReportScreen.menuTitle,
          subtitle:
              'เลือกงวด ประเภทบุคลากร และหน่วยงาน แล้วกดออกรายงาน (ไฟล์ PDF)',
        ),
        const SizedBox(height: 14),
        PeriodPicker(
          past: _past,
          enabled: !busy,
          onChanged: (p) => _changed(() => _past = p),
        ),
        const SizedBox(height: 12),
        DivSelector(
          apiService: widget.apiService,
          enabled: !busy,
          onChanged: (d) => _changed(() => _div = d),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final t in [EmpType.g, EmpType.e])
                  ButtonSegment(
                    value: t,
                    label: Text(
                      EmpType.nameOf(t),
                      key: ReportScreen.typeKey(t),
                      style: screenText(size: 14.5),
                    ),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: busy
                  ? null
                  : (s) => _changed(() => _type = s.first),
            ),
            if (_canAllDivs)
              FilterChip(
                key: ReportScreen.allDivsKey,
                label: Text(
                  ReportScreen.allDivsLabel,
                  style: screenText(size: 13.5),
                ),
                selected: _allDivs,
                onSelected: busy ? null : (v) => _changed(() => _allDivs = v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (downloadError != null) ...[
          NoticeBar(type: NoticeType.error, text: downloadError!),
          const SizedBox(height: 12),
        ],
        _section(
          'รายงานของหน่วยงาน',
          'หน่วยงาน ${_div?.label ?? '-'} · ${EmpType.nameOf(_type)}',
          [
            for (final r in perDiv)
              if (r.bank == null) r,
          ],
        ),
        const SizedBox(height: 12),
        _section('เงินหนี้เปลี่ยนของธนาคาร', scope, [
          for (final r in perDiv)
            if (r.bank != null) r,
        ]),
        if (_isAccount) ...[
          const SizedBox(height: 12),
          _section('รายงานทั้งกรม (ฝ่ายบัญชี)', 'ไม่ขึ้นกับหน่วยงานที่เลือก', [
            for (final r in ReportScreen.reports)
              if (r.accountOnly) r,
          ]),
        ],
      ],
    );
  }
}

/// รายงานส่งธนาคาร (ACCOUNT) — ไฟล์ Excel 4 แบบ: AIA, ธอส., ออมสิน, กรุงไทย
///
/// `GET /api/reports/bank/{bank}` — ธอส./ออมสิน/กรุงไทย ตรวจยอดเลขบัญชีเงินกู้ก่อนออก ยังไม่ตรง = 409
/// `LOAN_AMOUNT_MISMATCH` → แสดงจำนวนที่ไม่ตรงจาก `details` พร้อมปุ่มไปหน้า "ตรวจยอดเงินกู้กับหนี้เดือน"
class BankReportScreen extends StatefulWidget {
  final ApiService apiService;

  const BankReportScreen({super.key, required this.apiService});

  static const String menuTitle = 'รายงานส่งธนาคาร';
  static const IconData menuIcon = Icons.table_view_outlined;
  static const String groupTitle = 'ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร';

  static Key runKey(String bank) => ValueKey('bank-report-$bank');
  static const Key mismatchKey = ValueKey('bank-report-mismatch');
  static const Key goCheckKey = ValueKey('bank-report-go-check');

  static const Map<String, String> banks = {
    'AIA': 'AIA ประกันชีวิต',
    'GHB': 'ธนาคารอาคารสงเคราะห์',
    'GSB': 'ธนาคารออมสิน',
    'KTB': 'ธนาคารกรุงไทย',
  };

  static const String goCheckLabel = 'ไปหน้าตรวจยอดเงินกู้';

  @override
  State<BankReportScreen> createState() => _BankReportScreenState();
}

class _BankReportScreenState extends State<BankReportScreen>
    with FileDownloads<BankReportScreen> {
  Period? _past;

  /// ข้อความของ 409 LOAN_AMOUNT_MISMATCH ล่าสุด
  String? _mismatch;
  final Map<String, String> _notes = {};

  Future<void> _run(String bank) async {
    setState(() {
      _mismatch = null;
      _notes.remove(bank);
    });
    await runDownload(
      bank,
      () => widget.apiService.downloadBankReport(bank, period: _past),
      onError: (e) {
        if (e.code == ErrorCodes.loanAmountMismatch) {
          final banks = [
            for (final b in e.details?['banks'] as List? ?? const [])
              if (b is Map)
                '${BankReportScreen.banks[b['bank']] ?? b['bank']} '
                    '${countText(b['mismatch_count'])} รายการ',
          ];
          _mismatch =
              '${e.message}\n'
              'ไม่ตรง ${countText(e.details?['mismatch_count'])} รายการ'
              '${banks.isEmpty ? '' : ' (${banks.join(', ')})'}\n'
              'แก้ที่หน้า "${LoanCheckScreen.menuTitle}" แล้วออกรายงานใหม่';
          return true;
        }
        if (e.statusCode == 404) {
          _notes[bank] = ReportScreen.noDataText;
          return true;
        }
        return false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkPage(
      group: BankReportScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: BankReportScreen.menuIcon,
          title: BankReportScreen.menuTitle,
          subtitle: 'ไฟล์ Excel ส่งธนาคารของงวด หนึ่งแถวต่อหนึ่งเลขที่บัญชี',
          bullets: [
            'ธอส. ออมสิน และกรุงไทย ต้องผ่านการตรวจยอดเงินกู้กับหนี้เดือนก่อนจึงออกได้',
            'คนที่มีหนี้แต่ไม่มีเลขที่บัญชีจะไม่อยู่ในไฟล์',
          ],
        ),
        const SizedBox(height: 14),
        PeriodPicker(
          past: _past,
          enabled: downloading == null,
          onChanged: (p) {
            clearSaved();
            setState(() {
              _past = p;
              _mismatch = null;
              _notes.clear();
              downloadError = null;
            });
          },
        ),
        const SizedBox(height: 12),
        if (downloadError != null) ...[
          NoticeBar(type: NoticeType.error, text: downloadError!),
          const SizedBox(height: 12),
        ],
        if (_mismatch != null) ...[
          NoticeBar(
            key: BankReportScreen.mismatchKey,
            type: NoticeType.warning,
            title: 'ยังออกรายงานไม่ได้',
            text: _mismatch!,
            action: ElevatedButton.icon(
              key: BankReportScreen.goCheckKey,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      LoanCheckScreen(apiService: widget.apiService),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(
                BankReportScreen.goCheckLabel,
                style: screenText(size: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ResponsiveGrid(
          minItemWidth: 280,
          maxColumns: 2,
          spacing: 10,
          children: [
            for (final b in BankReportScreen.banks.entries)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      b.value,
                      style: screenText(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DownloadButtons(
                      key: BankReportScreen.runKey(b.key),
                      label: 'ออกรายงาน (xlsx)',
                      icon: Icons.table_view_outlined,
                      busy: downloading == b.key,
                      blocked: downloading != null,
                      saved: savedOf(b.key),
                      onDownload: () => _run(b.key),
                    ),
                    if (_notes[b.key] != null) ...[
                      const SizedBox(height: 8),
                      NoticeBar(type: NoticeType.info, text: _notes[b.key]!),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
