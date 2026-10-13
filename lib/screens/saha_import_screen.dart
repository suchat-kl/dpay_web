import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/work_api.dart';
import '../utils/dialog.dart';
import '../utils/file_pick.dart';
import '../utils/money.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/account_form.dart';
import '../widgets/app_pagination.dart';
import '../widgets/person_finder.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';

/// นำเข้าข้อมูลสหกรณ์ (ACCOUNT) — ไฟล์ข้อความความกว้างคงที่ของสหกรณ์ แยกข้าราชการ/ลูกจ้างประจำ
///
/// ทำเป็นขั้น: เลือกประเภทและไฟล์ → **ตรวจไฟล์ก่อน** (`dry_run`) แสดงสรุปและรายการที่มีปัญหาแยกชนิด →
/// ยืนยันนำเข้า (มีข้อมูลของงวด+ประเภทนั้นแล้ว บอกจำนวนที่จะถูกแทนและส่ง `confirm_replace`)
/// ด้านล่างเป็นรายการที่เลขบัตรยังเป็นเลขปลอม (`GET /api/saha/unresolved`) แก้การจับคู่รายคนได้
/// (`PUT /api/saha/mapping` เลือกคนด้วย [PersonFinder]) — **นำเข้าเฉพาะงวดปัจจุบัน** (ผู้ใช้ตัดสิน)
/// backend ตอบ 409 `NOT_CURRENT_PERIOD` เมื่องวดถูกเปลี่ยนระหว่างเปิดหน้าค้าง → บอกให้เปิดหน้าใหม่
/// **รายการที่มีปัญหามีชื่อบุคคล แสดงบนจอเท่านั้น ไม่ลง log**
class SahaImportScreen extends StatefulWidget {
  final ApiService apiService;

  /// ตัวเลือกไฟล์ (เทสต์ส่งตัวจำลองแทนหน้าต่างของเบราว์เซอร์)
  final FilePicker? pickFile;

  const SahaImportScreen({super.key, required this.apiService, this.pickFile});

  static const String menuTitle = 'นำเข้าข้อมูลสหกรณ์';
  static const IconData menuIcon = Icons.upload_file;
  static const String groupTitle = 'ฌาปนกิจและสหกรณ์';

  /// ขนาดไฟล์สูงสุดที่ backend รับ
  static const int maxBytes = 5 * 1024 * 1024;

  static const Key pickKey = ValueKey('saha-pick');
  static const Key checkKey = ValueKey('saha-check');
  static const Key importKey = ValueKey('saha-import');
  static const Key summaryKey = ValueKey('saha-summary');
  static const Key checkResultKey = ValueKey('saha-check-result');
  static const Key unresolvedKey = ValueKey('saha-unresolved');
  static Key typeKey(String type) => ValueKey('saha-type-$type');
  static Key problemKey(String kind) => ValueKey('saha-problem-$kind');
  static Key fixKey(String sahaId) => ValueKey('saha-fix-$sahaId');

  /// ชนิดของปัญหา -> (หัวข้อ, คำอธิบายว่าระบบใช้เลขบัตรอะไรไปก่อน)
  static const Map<String, (String, String)> problemKinds = {
    'MULTIPLE_MATCH': (
      'พบหลายคน',
      'ชื่อตรงกับบุคลากรหลายคน ระบบใช้คนแรกที่พบไปก่อน',
    ),
    'NOT_FOUND': (
      'ไม่พบ',
      'ไม่พบชื่อนี้ในข้อมูลบุคลากร ระบบตั้งเลขบัตรปลอมไว้ก่อน',
    ),
    'FAKE_IDCARD': (
      'เลขบัตรปลอม',
      'สมาชิกนี้เคยถูกจดไว้ด้วยเลขบัตรปลอมและยังไม่ได้แก้',
    ),
    'IDCARD_ALREADY_MAPPED': (
      'เลขบัตรถูกผูกแล้ว',
      'ชื่อตรงกับคนที่ผูกกับเลขสมาชิกอื่นอยู่แล้ว ระบบไม่จดคู่ใหม่',
    ),
  };

  static const String emptySummaryText = 'งวดนี้ยังไม่ได้นำเข้าข้อมูลสหกรณ์';
  static const String tooBigText = 'ไฟล์ใหญ่เกิน 5 MB นำเข้าไม่ได้';
  static const String wrongTypeText = 'เลือกได้เฉพาะไฟล์ .txt หรือ .dat';
  static const String needCheckText = 'กรุณากดตรวจไฟล์ก่อนนำเข้า';
  static const String noProblemText =
      'ไม่พบรายการที่มีปัญหา จับคู่กับบุคลากรได้ครบ';
  static const String noUnresolvedText = 'ไม่มีรายการที่เลขบัตรยังเป็นเลขปลอม';

  @override
  State<SahaImportScreen> createState() => _SahaImportScreenState();
}

class _SahaImportScreenState extends State<SahaImportScreen> {
  String _type = EmpType.g;
  PickedFile? _file;

  /// ผลตรวจไฟล์ (dry run) ของไฟล์+ประเภทที่เลือกอยู่
  Map<String, dynamic>? _check;
  Map<String, dynamic>? _imported;
  List<Map<String, dynamic>> _summary = [];
  Map<String, dynamic>? _unresolved;
  int _page = 0;
  int _pageSize = 10;
  bool _loading = true;
  bool _working = false;
  String? _error;

  String get _periodLabel => SettingsProvider().period?.label ?? '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  static List<Map<String, dynamic>> _maps(Object? v) => [
    for (final e in v as List? ?? const [])
      if (e is Map) Map<String, dynamic>.from(e),
  ];

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await widget.apiService.getSahaSummary();
      final unresolved = await widget.apiService.getSahaUnresolved(
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _unresolved = unresolved;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pick() async {
    final picker =
        widget.pickFile ??
        () => pickTextFile(maxBytes: SahaImportScreen.maxBytes);
    final PickedFile? f;
    try {
      f = await picker();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    }
    if (f == null || !mounted) return;
    final name = f.name.toLowerCase();
    final String? problem = !(name.endsWith('.txt') || name.endsWith('.dat'))
        ? SahaImportScreen.wrongTypeText
        : f.size > SahaImportScreen.maxBytes
        ? SahaImportScreen.tooBigText
        : (f.size == 0 ? 'ไฟล์ว่าง ไม่มีข้อมูลให้นำเข้า' : null);
    setState(() {
      _error = problem;
      _file = problem == null ? f : null;
      _check = null;
      _imported = null;
    });
  }

  /// ข้อความของ 400 ไฟล์ผิดรูปแบบ (มี details บอกบรรทัดที่ผิด)
  String _describe(ApiException e) {
    if (e.code == ErrorCodes.notCurrentPeriod) return periodChangedMessage(e);
    final d = e.details;
    if (d == null || d['bad_line_count'] == null) return e.message;
    final lines = (d['bad_lines'] as List? ?? const []).join(', ');
    return '${e.message}\n'
        'มี ${countText(d['bad_line_count'])} บรรทัดที่ผิดรูปแบบ '
        '(แต่ละบรรทัดต้องยาวอย่างน้อย ${d['expected_length'] ?? 104} ตัวอักษร)'
        '${lines.isEmpty ? '' : '\nบรรทัดที่: $lines'}\n'
        'ไฟล์นี้ยังไม่ถูกบันทึก';
  }

  Future<void> _runCheck() async {
    final f = _file;
    if (f == null || _working) return;
    setState(() {
      _working = true;
      _error = null;
      _check = null;
      _imported = null;
    });
    try {
      final r = await widget.apiService.importSaha(
        bytes: f.bytes,
        fileName: f.name,
        type: _type,
        dryRun: true,
      );
      if (!mounted) return;
      setState(() {
        _working = false;
        _check = r;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _describe(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.toString();
      });
    }
  }

  Future<bool> _confirmReplace(Object? rows) async {
    final ok = await AppDialog.showConfirm(
      context,
      'งวด $_periodLabel มีข้อมูลสหกรณ์ของ${EmpType.nameOf(_type)}แล้ว '
      '${countText(rows)} รายการ\n'
      'นำเข้าไฟล์นี้จะแทนที่ข้อมูลเดิมทั้งหมดของประเภทนี้ ต้องการทำต่อหรือไม่',
      confirmText: 'แทนที่ข้อมูลเดิม',
    );
    return ok == true;
  }

  Future<void> _runImport({bool confirmed = false}) async {
    final f = _file;
    final check = _check;
    if (f == null || _working) return;
    if (check == null) {
      setState(() => _error = SahaImportScreen.needCheckText);
      return;
    }
    var replace = confirmed;
    if (!replace && intOf(check['existing_rows']) > 0) {
      if (!await _confirmReplace(check['existing_rows']) || !mounted) return;
      replace = true;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final r = await widget.apiService.importSaha(
        bytes: f.bytes,
        fileName: f.name,
        type: _type,
        confirmReplace: replace,
      );
      if (!mounted) return;
      setState(() {
        _working = false;
        _imported = r;
        _check = null;
        _file = null;
        _page = 0;
      });
      context.showSuccessSnackBar(
        '${r['message'] ?? 'นำเข้าข้อมูลสหกรณ์เรียบร้อยแล้ว'}',
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      // มีข้อมูลแล้วแต่ผลตรวจยังไม่รู้ (มีคนนำเข้าระหว่างนั้น): ถามแล้วส่งใหม่พร้อมคำยืนยัน
      if (e.isConfirmRequired && !replace) {
        if (await _confirmReplace(e.details?['rows_to_clear']) && mounted) {
          await _runImport(confirmed: true);
        }
        return;
      }
      setState(() => _error = _describe(e));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fix(Map<String, dynamic> row) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SahaMappingDialog(apiService: widget.apiService, row: row),
    );
    if (done != true || !mounted) return;
    context.showSuccessSnackBar('บันทึกการจับคู่แล้ว');
    await _load();
  }

  // ---------------------------------------------------------------------------
  // หน้าจอ
  // ---------------------------------------------------------------------------

  Widget _resultFacts(Map<String, dynamic> r) => Column(
    children: [
      FactRow('จำนวนแถวในไฟล์', '${countText(r['rows'])} แถว'),
      FactRow('ยอดรวม', '${moneyText(r['total_amount'])} บาท'),
      FactRow(
        'จับคู่ได้จากที่เคยจดไว้',
        '${countText(r['matched_by_mapping'])} คน',
      ),
      FactRow('จับคู่ได้จากชื่อ', '${countText(r['matched_by_name'])} คน'),
      FactRow(
        'ข้อมูลเดิมของงวดและประเภทนี้',
        '${countText(r['existing_rows'])} รายการ',
        color: intOf(r['existing_rows']) > 0 ? AppTheme.warningColor : null,
      ),
      FactRow(
        'รายการที่มีปัญหา',
        '${countText(r['problem_count'])} รายการ',
        color: intOf(r['problem_count']) > 0 ? AppTheme.dangerColor : null,
      ),
    ],
  );

  Widget _problems(Map<String, dynamic> r) {
    final all = _maps(r['problems']);
    if (intOf(r['problem_count']) == 0) {
      return const NoticeBar(
        type: NoticeType.success,
        text: SahaImportScreen.noProblemText,
      );
    }
    final counts = r['problem_counts'] is Map
        ? Map<String, dynamic>.from(r['problem_counts'] as Map)
        : const <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r['problems_truncated'] == true) ...[
          const NoticeBar(
            type: NoticeType.info,
            text: 'รายการที่มีปัญหามีมาก แสดงเฉพาะ 500 รายการแรก',
          ),
          const SizedBox(height: 8),
        ],
        for (final kind in SahaImportScreen.problemKinds.entries)
          if (all.any((p) => p['kind'] == kind.key) ||
              intOf(counts[kind.key]) > 0) ...[
            Container(
              key: SahaImportScreen.problemKey(kind.key),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        kind.value.$1,
                        style: screenText(size: 15, weight: FontWeight.w700),
                      ),
                      StatusChip(
                        '${countText(counts[kind.key] ?? all.where((p) => p['kind'] == kind.key).length)} รายการ',
                        AppTheme.warningColor,
                      ),
                    ],
                  ),
                  Text(
                    kind.value.$2,
                    style: screenText(size: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  for (final p in all.where((p) => p['kind'] == kind.key))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'บรรทัด ${p['line'] ?? '-'} · สมาชิก ${p['saha_id'] ?? '-'} · '
                        '${p['name'] ?? ''} · ${moneyText(p['total_amount'])} บาท'
                        '${kind.key == 'MULTIPLE_MATCH' ? ' · พบ ${countText(p['candidates'])} คน' : ''}',
                        style: screenText(size: 13.5),
                      ),
                    ),
                ],
              ),
            ),
          ],
      ],
    );
  }

  Widget _unresolvedCard() {
    final u = _unresolved;
    final rows = _maps(u?['items']);
    final total = intOf(u?['totalItems']);
    return StepCard(
      key: SahaImportScreen.unresolvedKey,
      icon: Icons.link_off,
      title: 'รายการที่ยังไม่ได้แก้การจับคู่',
      subtitle:
          '${countText(total)} รายการที่เลขบัตรยังเป็นเลขปลอม — กดแก้การจับคู่เพื่อระบุบุคคลที่ถูกต้อง',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetScroll(
            minWidth: 640,
            child: SheetCard(
              emptyText: SahaImportScreen.noUnresolvedText,
              header: const Row(
                children: [
                  Expanded(flex: 2, child: SheetHead('เลขสมาชิก')),
                  Expanded(flex: 6, child: SheetHead('ชื่อในไฟล์สหกรณ์')),
                  Expanded(flex: 2, child: SheetHead('ประเภท')),
                  Expanded(
                    flex: 3,
                    child: SheetHead('ยอดรวม', align: TextAlign.right),
                  ),
                  SizedBox(width: 140),
                ],
              ),
              rows: [
                for (final r in rows)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${r['saha_id'] ?? ''}',
                            style: screenText(size: 14.5),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: Text(
                            '${r['name'] ?? ''}',
                            style: screenText(size: 14.5),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            EmpType.nameOf('${r['type']}'),
                            style: screenText(size: 14),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            moneyText(r['total_amount']),
                            textAlign: TextAlign.right,
                            style: screenText(size: 14.5),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SheetButton(
                            'แก้การจับคู่',
                            key: SahaImportScreen.fixKey('${r['saha_id']}'),
                            icon: Icons.link,
                            color: AppTheme.editColor,
                            onPressed: _working ? null : () => _fix(r),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppPagination(
            currentPage: _page,
            totalPages: intOf(u?['totalPages']),
            pageSize: _pageSize,
            summary: 'ทั้งหมด ${countText(total)} รายการ',
            onPageChanged: (p) {
              setState(() => _page = p);
              _load();
            },
            onPageSizeChanged: (s) {
              setState(() {
                _pageSize = s;
                _page = 0;
              });
              _load();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    final check = _check;
    final imported = _imported;
    return WorkPage(
      group: SahaImportScreen.groupTitle,
      children: [
        ScreenHeader(
          icon: SahaImportScreen.menuIcon,
          title: SahaImportScreen.menuTitle,
          subtitle:
              'นำเข้าไฟล์หักเงินสหกรณ์ของงวด $_periodLabel แยกข้าราชการและลูกจ้างประจำ',
          bullets: const [
            'ไฟล์ .txt / .dat ความกว้างคงที่ของสหกรณ์ ไม่เกิน 5 MB',
            'ตรวจไฟล์ก่อนทุกครั้ง การตรวจไม่บันทึกอะไร',
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null) ...[
          NoticeBar(
            type: NoticeType.error,
            text: _error!,
            onClose: () => setState(() => _error = null),
          ),
          const SizedBox(height: 12),
        ],
        StepCard(
          key: SahaImportScreen.summaryKey,
          icon: Icons.summarize_outlined,
          title: 'สรุปข้อมูลสหกรณ์ของงวด $_periodLabel',
          child: _summary.isEmpty
              ? Text(
                  _loading ? 'กำลังโหลด...' : SahaImportScreen.emptySummaryText,
                  style: screenText(color: AppTheme.textSecondary),
                )
              : Column(
                  children: [
                    for (final s in _summary)
                      FactRow(
                        EmpType.nameOf('${s['type']}'),
                        '${countText(s['rows'])} แถว · ${moneyText(s['total_amount'])} บาท · '
                        'เลขบัตรปลอม ${countText(s['fake_idcard_rows'])}',
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        StepCard(
          step: 1,
          title: 'เลือกประเภทและไฟล์',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in EmpType.names.entries)
                    ChoiceChip(
                      key: SahaImportScreen.typeKey(t.key),
                      label: Text(t.value, style: screenText(size: 14)),
                      selected: _type == t.key,
                      onSelected: _working
                          ? null
                          : (_) => setState(() {
                              _type = t.key;
                              // เปลี่ยนประเภท: ผลตรวจเดิมใช้ไม่ได้แล้ว
                              _check = null;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SheetButton(
                    f == null ? 'เลือกไฟล์' : 'เปลี่ยนไฟล์',
                    key: SahaImportScreen.pickKey,
                    icon: Icons.attach_file,
                    onPressed: _working ? null : _pick,
                  ),
                  Text(
                    f == null
                        ? 'ยังไม่ได้เลือกไฟล์'
                        : '${f.name} (${Util.formatCount(f.size)} ไบต์)',
                    style: screenText(
                      size: 14,
                      color: f == null
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StepCard(
          step: 2,
          title: 'ตรวจไฟล์ก่อนนำเข้า',
          subtitle: 'ยังไม่บันทึกอะไร — ดูสรุปและรายการที่มีปัญหาก่อน',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PrimaryActionButton(
                  key: SahaImportScreen.checkKey,
                  label: 'ตรวจไฟล์',
                  icon: Icons.rule,
                  loading: _working && check == null && imported == null,
                  onPressed: f == null || _working ? null : _runCheck,
                ),
              ),
              if (check != null) ...[
                const SizedBox(height: 10),
                KeyedSubtree(
                  key: SahaImportScreen.checkResultKey,
                  child: _resultFacts(check),
                ),
                const SizedBox(height: 10),
                _problems(check),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        StepCard(
          step: 3,
          title: 'ยืนยันนำเข้า',
          subtitle: check == null
              ? 'ตรวจไฟล์ให้ผ่านก่อน'
              : (intOf(check['existing_rows']) > 0
                    ? 'จะแทนที่ข้อมูลเดิม ${countText(check['existing_rows'])} รายการของ${EmpType.nameOf(_type)}'
                    : 'ยังไม่มีข้อมูลเดิมของ${EmpType.nameOf(_type)}ในงวดนี้'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PrimaryActionButton(
                  key: SahaImportScreen.importKey,
                  label: 'นำเข้าข้อมูลสหกรณ์',
                  icon: Icons.cloud_upload_outlined,
                  loading: _working && check != null,
                  color: AppTheme.addColor,
                  onPressed: check == null || _working ? null : _runImport,
                ),
              ),
              if (imported != null) ...[
                const SizedBox(height: 10),
                NoticeBar(
                  type: NoticeType.success,
                  title: 'นำเข้าแล้ว',
                  text:
                      '${EmpType.nameOf('${imported['type']}')} ${countText(imported['rows'])} แถว '
                      'ยอดรวม ${moneyText(imported['total_amount'])} บาท\n'
                      'แทนที่ข้อมูลเดิม ${countText(imported['replaced_rows'])} รายการ · '
                      'จดคู่ใหม่ ${countText(imported['new_mappings'])} คน · '
                      'มีปัญหา ${countText(imported['problem_count'])} รายการ',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_unresolved != null) _unresolvedCard(),
      ],
    );
  }
}

/// หน้าต่างแก้การจับคู่ของสมาชิกสหกรณ์หนึ่งคน: เลือกบุคคลด้วยเลขบัตรหรือชื่อ ([PersonFinder]) แล้วบันทึก
/// (`PUT /api/saha/mapping` — เลขบัตรอยู่ในตัวคำขอ) สำเร็จ = ปิดพร้อมคืนจริง
class SahaMappingDialog extends StatefulWidget {
  final ApiService apiService;

  /// แถวของ `/api/saha/unresolved`
  final Map<String, dynamic> row;

  const SahaMappingDialog({
    super.key,
    required this.apiService,
    required this.row,
  });

  static const Key saveKey = ValueKey('saha-mapping-save');
  static const String duplicateHint =
      'บุคคลนี้ผูกกับเลขสมาชิกสหกรณ์อื่นอยู่แล้ว เลือกบุคคลอื่น';

  @override
  State<SahaMappingDialog> createState() => _SahaMappingDialogState();
}

class _SahaMappingDialogState extends State<SahaMappingDialog> {
  String? _idcard;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final id = _idcard;
    if (id == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.setSahaMapping(
        sahaId: '${widget.row['saha_id']}',
        idcard: id,
        type: '${widget.row['type']}',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (e.code) {
          ErrorCodes.duplicate =>
            '${e.message}\n${SahaMappingDialog.duplicateHint}',
          ErrorCodes.notCurrentPeriod => periodChangedMessage(e),
          _ => e.message,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return AccountDialogShell(
      icon: Icons.link,
      title: 'แก้การจับคู่สมาชิกสหกรณ์',
      subtitle: 'เลขสมาชิก ${r['saha_id']} · ${r['name'] ?? ''}',
      onClose: _saving ? null : () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AccountBanner.error(_error!),
            const SizedBox(height: 10),
          ],
          PersonFinder(
            apiService: widget.apiService,
            enabled: !_saving,
            onPicked: (id) => setState(() {
              _idcard = id;
              _error = null;
            }),
          ),
          const SizedBox(height: 10),
          NoticeBar(
            type: _idcard == null ? NoticeType.info : NoticeType.success,
            text: _idcard == null
                ? 'ค้นและเลือกบุคคลที่เป็นเจ้าของเลขสมาชิกนี้'
                : 'เลือกแล้ว: เลขประจำตัวประชาชน ${IdCard.masked(_idcard)}',
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryActionButton(
              key: SahaMappingDialog.saveKey,
              label: 'บันทึกการจับคู่',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: _idcard == null ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
