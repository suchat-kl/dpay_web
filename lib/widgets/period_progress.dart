import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../providers/settings_provider.dart';
import '../screens/cgd_files_screen.dart';
import '../screens/chapana_import_screen.dart';
import '../screens/chapana_slip_screen.dart';
import '../screens/debt_entry_screen.dart';
import '../screens/div_status_screen.dart';
import '../screens/edit_window_screen.dart';
import '../screens/loan_check_screen.dart';
import '../screens/period_jobs_screen.dart';
import '../screens/period_screen.dart';
import '../screens/report_screen.dart';
import '../screens/saha_import_screen.dart';
import '../services/api_service.dart';
import '../services/debt_api.dart';
import '../services/work_api.dart';
import 'screen_parts.dart';
import 'work_parts.dart';

/// สถานะของหนึ่งขั้นในความคืบหน้าของงวด
enum StepState {
  /// ทำแล้ว
  done,

  /// ยังไม่ได้ทำ / ยังไม่ครบ
  todo,

  /// มีปัญหาที่ต้องแก้
  problem,

  /// ไม่มีข้อมูลสถานะ — เป็นทางลัดไปเมนูเฉย ๆ
  none,
}

/// ความคืบหน้าของงวด — หน้าแรกของฝ่ายบัญชี (ACCOUNT)
///
/// งานประจำงวดเรียงตามลำดับที่ทำจริง: กำหนดงวด → ช่วงแก้ไข → นำเข้าบุคลากร → เตรียมงวด → หน่วยงานบันทึกหนี้
/// → นำเข้าฌาปนกิจ → นำเข้าสหกรณ์ → ตรวจยอดเงินกู้ → ไฟล์ส่งกรมบัญชีกลาง → รายงานส่งธนาคาร → รายงานฌาปนกิจ-สลิป → รายงาน
/// แต่ละขั้นแสดงสถานะจากเส้นสรุปที่มี และกดไปเมนูนั้นได้ ขั้นที่ไม่มีเส้นสรุป (หรือโหลดสถานะไม่ได้) เป็นทางลัดเฉย ๆ
/// เส้นที่ใช้: `/api/period/dpis-import`, `/api/period/prepare`, `/api/debts/div-status`, `/api/chapana/summary`, `/api/saha/summary`,
/// `/api/loans/check` — แต่ละเส้นล้มได้โดยไม่กระทบขั้นอื่น
class PeriodProgress extends StatefulWidget {
  final ApiService apiService;

  const PeriodProgress({super.key, required this.apiService});

  static const String title = 'ความคืบหน้าของงวด';
  static const Key cardKey = ValueKey('progress');
  static const Key refreshKey = ValueKey('progress-refresh');
  static Key stepKey(int n) => ValueKey('progress-step-$n');
  static Key statusKey(int n) => ValueKey('progress-status-$n');

  static const String doneLabel = 'ทำแล้ว';
  static const String todoLabel = 'ยังไม่ได้ทำ';
  static const String problemLabel = 'ต้องแก้';

  @override
  State<PeriodProgress> createState() => _PeriodProgressState();
}

class _Step {
  final String title;
  final IconData icon;
  final StepState state;
  final String detail;
  final WidgetBuilder screen;

  const _Step(
    this.title,
    this.icon,
    this.screen, {
    this.state = StepState.none,
    this.detail = '',
  });
}

class _PeriodProgressState extends State<PeriodProgress> {
  final _settings = SettingsProvider();
  Map<String, dynamic>? _dpis;
  Map<String, dynamic>? _prepare;

  /// สถานะการบันทึกรายหน่วยงาน (backend ที่ยังไม่มีเส้นนี้ = null ขั้นนั้นใช้ข้อมูลจากการเตรียมงวดแทน)
  Map<String, dynamic>? _divStatus;
  Map<String, dynamic>? _chapana;
  List<Map<String, dynamic>>? _saha;
  Map<String, dynamic>? _loans;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// เส้นสรุปแต่ละเส้นล้มได้: ได้ null แล้วขั้นนั้นเป็นทางลัดเฉย ๆ
  Future<T?> _try<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = widget.apiService;
    final dpis = await _try(api.getDpisImport);
    final prepare = await _try(api.getPrepare);
    final divStatus = await _try(api.getDivStatus);
    final chapana = await _try(api.getChapanaSummary);
    final saha = await _try(api.getSahaSummary);
    final loans = await _try(api.getLoanCheck);
    if (!mounted) return;
    setState(() {
      _dpis = dpis;
      _prepare = prepare;
      _divStatus = divStatus;
      _chapana = chapana;
      _saha = saha;
      _loans = loans;
      _loading = false;
    });
  }

  List<_Step> _steps() {
    final api = widget.apiService;
    final period = _settings.period;
    final window = _settings.editWindow;
    final dpis = _dpis;
    final prepare = _prepare;
    final chapana = _chapana;
    final saha = _saha;
    final loans = _loans;

    final chapanaRows = [
      for (final e in chapana?['items'] as List? ?? const [])
        if (e is Map) intOf(e['count']),
    ].fold<int>(0, (a, b) => a + b);
    int sahaRows(String t) => [
      for (final s in saha ?? const <Map<String, dynamic>>[])
        if (s['type'] == t) intOf(s['rows']),
    ].fold<int>(0, (a, b) => a + b);
    final sahaFake = [
      for (final s in saha ?? const <Map<String, dynamic>>[])
        intOf(s['fake_idcard_rows']),
    ].fold<int>(0, (a, b) => a + b);
    final status =
        _divStatus != null &&
            _divStatus!['audit_available'] != false &&
            _divStatus!['summary'] is Map
        ? Map<String, dynamic>.from(_divStatus!['summary'] as Map)
        : null;
    final divs = intOf(status?['divs']);
    final prepared =
        prepare != null &&
        prepare['ready'] == true &&
        intOf(prepare['existing_rows']) > 0;

    return [
      _Step(
        PeriodScreen.menuTitle,
        PeriodScreen.menuIcon,
        (_) => PeriodScreen(apiService: api),
        state: period != null && period.isValid
            ? StepState.done
            : StepState.todo,
        detail: period != null && period.isValid ? 'งวด ${period.label}' : '',
      ),
      _Step(
        EditWindowScreen.menuTitle,
        EditWindowScreen.menuIcon,
        (_) => EditWindowScreen(apiService: api),
        state: window == null || !window.isSet
            ? StepState.todo
            : StepState.done,
        detail: window == null || !window.isSet
            ? ''
            : '${window.open ? 'เปิดอยู่' : 'ปิดอยู่'} · ${window.rangeLabel}',
      ),
      _Step(
        DpisImportScreen.menuTitle,
        DpisImportScreen.menuIcon,
        (_) => DpisImportScreen(apiService: api),
        state: dpis == null
            ? StepState.none
            : (intOf(dpis['total']) > 0 ? StepState.done : StepState.todo),
        detail: dpis == null || intOf(dpis['total']) == 0
            ? ''
            : '${countText(dpis['total'])} คน · ล่าสุด ${formatServerTime(dpis['last_import_at'])}',
      ),
      _Step(
        'เตรียมข้อมูลงวด',
        PreparePeriodScreen.menuIcon,
        (_) => PreparePeriodScreen(apiService: api),
        state: prepare == null
            ? StepState.none
            : prepare['last_status'] == 'FAILED'
            ? StepState.problem
            : (prepared ? StepState.done : StepState.todo),
        detail: prepare == null
            ? ''
            : prepare['last_status'] == 'FAILED'
            ? 'เตรียมงวดครั้งล่าสุดไม่สำเร็จ ต้องเตรียมใหม่'
            : prepared
            ? '${countText(prepare['existing_rows'])} รายการ · ล่าสุด ${formatServerTime(prepare['last_run_at'])}'
            : '',
      ),
      if (status != null)
        _Step(
          'หน่วยงานบันทึกหนี้',
          DivStatusScreen.menuIcon,
          (_) => DivStatusScreen(apiService: api),
          state: divs > 0 && intOf(status['not_edited']) == 0
              ? StepState.done
              : StepState.todo,
          detail:
              'บันทึกแล้ว ${countText(status['edited'])} จาก ${countText(divs)} หน่วยงาน',
        )
      else
        // backend ยังไม่มีเส้นสถานะรายหน่วยงาน (หรืองวดไม่มีประวัติ): ทางลัดไปหน้าบันทึกข้อมูล + จำนวนจากการเตรียมงวด
        _Step(
          'หน่วยงานบันทึกหนี้',
          DebtEntryScreen.menuIcon,
          (_) => _divStatus == null
              ? DebtEntryScreen(apiService: api)
              : DivStatusScreen(apiService: api),
          detail: prepare == null || !prepared
              ? ''
              : 'มียอดหนี้ ${countText(prepare['rows_with_debt'])} คน · '
                    'แก้ยอดหลังเตรียมงวด ${countText(prepare['edits_since_prepare'])} ครั้ง',
        ),
      _Step(
        ChapanaImportScreen.menuTitle,
        ChapanaImportScreen.menuIcon,
        (_) => ChapanaImportScreen(apiService: api),
        state: chapana == null
            ? StepState.none
            : (chapanaRows > 0 ? StepState.done : StepState.todo),
        detail: chapana == null || chapanaRows == 0
            ? ''
            : '${countText(chapanaRows)} คน · ผู้เกษียณ ${countText(chapana['retired'])} คน',
      ),
      _Step(
        SahaImportScreen.menuTitle,
        SahaImportScreen.menuIcon,
        (_) => SahaImportScreen(apiService: api),
        state: saha == null
            ? StepState.none
            : sahaFake > 0
            ? StepState.problem
            : (sahaRows(EmpType.g) > 0 && sahaRows(EmpType.e) > 0
                  ? StepState.done
                  : StepState.todo),
        detail: saha == null || saha.isEmpty
            ? ''
            : 'ข้าราชการ ${countText(sahaRows(EmpType.g))} แถว · '
                  'ลูกจ้างประจำ ${countText(sahaRows(EmpType.e))} แถว'
                  '${sahaFake > 0 ? ' · เลขบัตรปลอม ${countText(sahaFake)}' : ''}',
      ),
      _Step(
        LoanCheckScreen.menuTitle,
        LoanCheckScreen.menuIcon,
        (_) => LoanCheckScreen(apiService: api),
        state: loans == null
            ? StepState.none
            : (loans['ok'] == true ? StepState.done : StepState.problem),
        detail: loans == null
            ? ''
            : loans['ok'] == true
            ? 'ตรงทุกธนาคาร · ไม่มีเลขบัญชี ${countText(loans['missing_account'])} คน'
            : 'ไม่ตรง ${countText(loans['mismatch_count'])} รายการ · '
                  'ไม่มีเลขบัญชี ${countText(loans['missing_account'])} คน',
      ),
      _Step(
        'ไฟล์ส่งกรมบัญชีกลาง',
        CgdFilesScreen.menuIcon,
        (_) => CgdFilesScreen(apiService: api),
      ),
      _Step(
        BankReportScreen.menuTitle,
        BankReportScreen.menuIcon,
        (_) => BankReportScreen(apiService: api),
      ),
      // เทียบกับสลิปเรียกข้ามระบบ (ระบบสลิปภาษี) จึงไม่เรียกอัตโนมัติ — เป็นทางลัดเฉย ๆ
      _Step(
        ChapanaSlipScreen.menuTitle,
        ChapanaSlipScreen.menuIcon,
        (_) => ChapanaSlipScreen(apiService: api),
      ),
      _Step(
        ReportScreen.menuTitle,
        ReportScreen.menuIcon,
        (_) => ReportScreen(apiService: api),
      ),
    ];
  }

  Widget _tile(int n, _Step s) {
    final (label, color) = switch (s.state) {
      StepState.done => (PeriodProgress.doneLabel, AppTheme.successColor),
      StepState.todo => (PeriodProgress.todoLabel, AppTheme.warningColor),
      StepState.problem => (PeriodProgress.problemLabel, AppTheme.dangerColor),
      StepState.none => ('', AppTheme.neutralColor),
    };
    return Material(
      key: PeriodProgress.stepKey(n),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: s.state == StepState.none
              ? AppTheme.dividerColor
              : color.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: s.screen));
          // กลับมาจากหน้างาน: สถานะอาจเปลี่ยนแล้ว
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: s.state == StepState.done
                    ? AppTheme.successColor
                    : color.withValues(alpha: 0.14),
                child: s.state == StepState.done
                    ? const Icon(Icons.check, size: 17, color: Colors.white)
                    : Text(
                        '$n',
                        style: screenText(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: color,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: screenText(size: 14.5, weight: FontWeight.w600),
                    ),
                    if (s.detail.isNotEmpty)
                      Text(
                        s.detail,
                        style: screenText(
                          size: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    if (label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: StatusChip(
                          label,
                          color,
                          key: PeriodProgress.statusKey(n),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => StepCard(
        key: PeriodProgress.cardKey,
        icon: Icons.checklist_rtl,
        title: PeriodProgress.title,
        subtitle: 'งานประจำงวดเรียงตามลำดับ กดที่ขั้นเพื่อไปทำงานนั้น',
        trailing: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                key: PeriodProgress.refreshKey,
                tooltip: 'โหลดสถานะใหม่',
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
        child: ResponsiveGrid(
          minItemWidth: 300,
          maxColumns: 3,
          spacing: 10,
          children: [
            for (final (i, step) in _steps().indexed) _tile(i + 1, step),
          ],
        ),
      ),
    );
  }
}
