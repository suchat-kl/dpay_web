import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/period.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/work_api.dart';
import '../utils/dialog.dart';
import '../utils/money.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';
import 'report_screen.dart';

/// นำเข้าข้อมูลฌาปนกิจ (ACCOUNT) — ดึงรายการหักฌาปนกิจของงวดจาก DPIS
///
/// - สรุปงวด (`GET /api/chapana/summary`): จำนวนคน/ยอดต่อประเภท และจำนวนผู้เกษียณ
/// - "ดึงข้อมูลจาก DPIS" (`POST /api/chapana/import`): มีข้อมูลงวดนั้นแล้วถามยืนยันก่อนแทนที่ (`confirm_replace`)
///   ต้องเตรียมงวดก่อน (409 `PERIOD_NOT_READY`) DPIS ล่ม = 502 `DPIS_ERROR` ข้อมูลเดิมอยู่ครบ
/// - รายชื่อผู้เกษียณ/พ้นสภาพที่ยังอยู่ในรายการฌาปนกิจ (`GET /api/chapana/retired`) + ปุ่มรายงาน (rep10)
class ChapanaImportScreen extends StatefulWidget {
  final ApiService apiService;

  const ChapanaImportScreen({super.key, required this.apiService});

  static const String menuTitle = 'นำเข้าข้อมูลฌาปนกิจ';
  static const IconData menuIcon = Icons.volunteer_activism_outlined;
  static const String groupTitle = 'ฌาปนกิจและสหกรณ์';

  static const Key runKey = ValueKey('chapana-run');
  static const Key summaryKey = ValueKey('chapana-summary');
  static const Key resultKey = ValueKey('chapana-result');
  static const Key retiredKey = ValueKey('chapana-retired');
  static const Key reportKey = ValueKey('chapana-rep10');

  static const String emptyText = 'งวดนี้ยังไม่ได้นำเข้าข้อมูลฌาปนกิจ';
  static const String runLabel = 'ดึงข้อมูลฌาปนกิจจาก DPIS';
  static const String notReadyHint =
      'ต้องเตรียมข้อมูลงวดให้เสร็จก่อน จึงนำเข้าฌาปนกิจได้';
  static const String dpisErrorHint =
      'ข้อมูลฌาปนกิจเดิมของงวดยังอยู่ครบ ลองดึงใหม่ได้ภายหลัง';
  static const String noRetiredText =
      'ไม่มีผู้เกษียณ/พ้นสภาพในรายการฌาปนกิจของงวดนี้';

  @override
  State<ChapanaImportScreen> createState() => _ChapanaImportScreenState();
}

class _ChapanaImportScreenState extends State<ChapanaImportScreen>
    with FileDownloads<ChapanaImportScreen> {
  Period? _past;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _retired = [];
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _running = false;
  String? _error;

  bool get _busy => _loading || _running || downloading != null;

  List<Map<String, dynamic>> get _items => [
    for (final e in _summary?['items'] as List? ?? const [])
      if (e is Map) Map<String, dynamic>.from(e),
  ];

  int get _rows => _items.fold<int>(0, (s, e) => s + intOf(e['count']));

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
      final summary = await widget.apiService.getChapanaSummary(period: _past);
      final retired = await widget.apiService.getChapanaRetired(period: _past);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _retired = retired;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _retired = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<bool> _confirmReplace(Object? rows) async {
    final label = (_past ?? SettingsProvider().period)?.label ?? '-';
    final ok = await AppDialog.showConfirm(
      context,
      'งวด $label มีข้อมูลฌาปนกิจแล้ว ${countText(rows)} รายการ\n'
      'ต้องการดึงจาก DPIS ใหม่และแทนที่ข้อมูลเดิมทั้งหมดของงวดนี้หรือไม่',
      confirmText: 'แทนที่ข้อมูลเดิม',
    );
    return ok == true;
  }

  Future<void> _run({bool confirmed = false}) async {
    if (_running) return;
    var replace = confirmed;
    if (!replace && _rows > 0) {
      if (!await _confirmReplace(_rows) || !mounted) return;
      replace = true;
    }
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await widget.apiService.importChapana(
        period: _past,
        confirmReplace: replace,
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = r;
      });
      context.showSuccessSnackBar(
        '${r['message'] ?? 'นำเข้าข้อมูลฌาปนกิจเรียบร้อยแล้ว'}',
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _running = false);
      // มีข้อมูลแล้วแต่หน้าจอยังไม่รู้ (มีคนนำเข้าระหว่างที่เปิดหน้าอยู่): ถามแล้วส่งใหม่พร้อมคำยืนยัน
      if (e.isConfirmRequired && !replace) {
        if (await _confirmReplace(e.details?['rows_to_clear']) && mounted) {
          await _run(confirmed: true);
        }
        return;
      }
      setState(() {
        _error = switch (e.code) {
          ErrorCodes.periodNotReady =>
            '${e.message}\n${ChapanaImportScreen.notReadyHint}',
          ErrorCodes.dpisError =>
            '${e.message}\n${ChapanaImportScreen.dpisErrorHint}',
          ErrorCodes.notCurrentPeriod => periodChangedMessage(e),
          _ => e.message,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.toString();
      });
    }
  }

  Widget _retiredTable() => SheetScroll(
    minWidth: 720,
    child: SheetCard(
      emptyText: ChapanaImportScreen.noRetiredText,
      header: const Row(
        children: [
          Expanded(flex: 6, child: SheetHead('ชื่อ-สกุล')),
          Expanded(flex: 5, child: SheetHead('หน่วยงาน / ตำแหน่ง')),
          Expanded(flex: 2, child: SheetHead('เลขสมาชิก')),
          Expanded(flex: 3, child: SheetHead('สถานะ')),
        ],
      ),
      rows: [
        for (final r in _retired)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['title'] ?? ''}${r['name'] ?? ''} ${r['surname'] ?? ''}'
                              .trim(),
                          style: screenText(size: 14.5),
                        ),
                        Text(
                          '${EmpType.nameOf('${r['type']}')} · '
                          '${IdCard.masked('${r['idcard'] ?? ''}')}',
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
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      [
                        '${r['divname'] ?? ''}',
                        '${r['pos_name'] ?? ''}',
                      ].where((s) => s.isNotEmpty).join('\n'),
                      style: screenText(size: 13.5),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${r['member_no'] ?? '-'}',
                      style: screenText(size: 14),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${r['per_status'] ?? '-'}',
                      style: screenText(size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final items = _items;
    return WorkPage(
      group: ChapanaImportScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: ChapanaImportScreen.menuIcon,
          title: ChapanaImportScreen.menuTitle,
          subtitle: 'ดึงรายการหักฌาปนกิจของงวดจากระบบบุคลากร (DPIS) มาไว้ในงวด',
          bullets: [
            'ทำหลังจากเตรียมข้อมูลงวดแล้ว',
            'คนที่ DPIS ส่งมาแต่ไม่มีรายการหนี้ในงวด ถือเป็นผู้เกษียณ/พ้นสภาพ เก็บเป็นรายชื่อแยก',
          ],
        ),
        const SizedBox(height: 14),
        PeriodPicker(
          past: _past,
          enabled: !_busy,
          onChanged: (p) {
            setState(() {
              _past = p;
              _result = null;
            });
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
        else if (_summary != null) ...[
          StepCard(
            key: ChapanaImportScreen.summaryKey,
            icon: Icons.summarize_outlined,
            title: 'สรุปข้อมูลฌาปนกิจของงวด',
            trailing: StatusChip(
              items.isEmpty ? 'ยังไม่ได้นำเข้า' : 'นำเข้าแล้ว',
              items.isEmpty ? AppTheme.warningColor : AppTheme.successColor,
            ),
            child: items.isEmpty
                ? Text(
                    ChapanaImportScreen.emptyText,
                    style: screenText(color: AppTheme.textSecondary),
                  )
                : Column(
                    children: [
                      for (final i in items)
                        FactRow(
                          EmpType.nameOf('${i['type']}'),
                          '${countText(i['count'])} คน · ${moneyText(i['amount'])} บาท',
                        ),
                      FactRow(
                        'ผู้เกษียณ/พ้นสภาพในรายการ',
                        '${countText(_summary!['retired'])} คน',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          if (r != null) ...[
            StepCard(
              key: ChapanaImportScreen.resultKey,
              icon: Icons.task_alt,
              title: 'ผลการนำเข้าครั้งนี้',
              child: Column(
                children: [
                  FactRow('ได้จาก DPIS', '${countText(r['from_dpis'])} รายการ'),
                  FactRow('เข้ารายการหักของงวด', '${countText(r['rows'])} คน'),
                  FactRow('ข้าราชการ', '${countText(r['g'])} คน'),
                  FactRow('ลูกจ้างประจำ', '${countText(r['e'])} คน'),
                  FactRow(
                    'ผู้เกษียณ/พ้นสภาพ',
                    '${countText(r['retired'])} คน '
                        '(มีรายละเอียด ${countText(r['retired_with_detail'])})',
                  ),
                  FactRow(
                    'ข้ามเพราะข้อมูลไม่ถูกต้อง',
                    '${countText(r['skipped_invalid'])} รายการ',
                  ),
                  FactRow(
                    'แทนที่ข้อมูลเดิม',
                    '${countText(r['replaced_rows'])} รายการ',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_running) ...[
            const NoticeBar(
              type: NoticeType.info,
              text:
                  'กำลังดึงข้อมูลฌาปนกิจจาก DPIS อาจใช้เวลาหลายนาที กรุณาอย่าปิดหน้านี้',
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryActionButton(
              key: ChapanaImportScreen.runKey,
              label: _running
                  ? 'กำลังดึงข้อมูล...'
                  : ChapanaImportScreen.runLabel,
              icon: Icons.cloud_download_outlined,
              loading: _running,
              onPressed: _busy ? null : _run,
            ),
          ),
          const SizedBox(height: 14),
          StepCard(
            key: ChapanaImportScreen.retiredKey,
            icon: Icons.elderly,
            title: 'ผู้เกษียณ/พ้นสภาพในรายการฌาปนกิจ',
            subtitle:
                '${countText(_retired.length)} คน (ข้อมูลของรายงานแบบที่ 10)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _retiredTable(),
                const SizedBox(height: 10),
                DownloadButtons(
                  key: ChapanaImportScreen.reportKey,
                  label: 'รายงานผู้เกษียณในรายการฌาปนกิจ (PDF)',
                  icon: Icons.picture_as_pdf_outlined,
                  busy: downloading == 'rep10',
                  blocked: _busy,
                  saved: savedOf('rep10'),
                  canOpen: true,
                  onDownload: () => runDownload(
                    'rep10',
                    () => widget.apiService.downloadReport(
                      'rep10',
                      period: _past,
                    ),
                    onError: (e) {
                      if (e.statusCode != 404) return false;
                      downloadError = ReportScreen.noDataText;
                      return true;
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
