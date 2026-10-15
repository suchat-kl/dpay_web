import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/period.dart';
import '../services/api_service.dart';
import '../services/debt_api.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/account_form.dart';
import '../widgets/screen_parts.dart';

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String _count(Object? v) => Util.formatCount(_int(v));

Widget _fact(String label, String value, {Key? key}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 5,
        child: Text(label, style: screenText(color: AppTheme.textSecondary)),
      ),
      Expanded(
        flex: 4,
        child: Text(
          value,
          key: key,
          textAlign: TextAlign.right,
          style: screenText(weight: FontWeight.w600),
        ),
      ),
    ],
  ),
);

Widget _page(BuildContext context, String group, List<Widget> children) {
  final isDesktop = MediaQuery.of(context).size.width > 1024;
  return Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: screenAppBar(context, group),
    body: ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    ),
  );
}

/// นำเข้าข้อมูลบุคลากรจาก DPIS — เมนู "ข้อมูลงวด" ของฝ่ายบัญชี (ACCOUNT)
///
/// `GET /api/period/dpis-import` แสดงข้อมูลที่นำเข้าไว้ล่าสุด (จำนวนคน เวลา ผู้สั่ง)
/// `POST` แทนที่ทั้งชุด ใช้เวลาหลายวินาทีถึงเป็นนาที ระหว่างรอปุ่มกดซ้ำไม่ได้
/// มีคนสั่งค้างอยู่ = 409 `JOB_RUNNING`, DPIS ล่ม = 502 `DPIS_ERROR` (ข้อมูลเดิมยังอยู่ครบ สั่งใหม่ได้)
class DpisImportScreen extends StatefulWidget {
  final ApiService apiService;

  const DpisImportScreen({super.key, required this.apiService});

  static const String menuTitle = 'นำเข้าข้อมูลบุคลากร';
  static const IconData menuIcon = Icons.cloud_download_outlined;
  static const String groupTitle = 'ข้อมูลงวด';
  static const Key runKey = ValueKey('dpis-run');
  static const Key totalKey = ValueKey('dpis-total');
  static const Key missingKey = ValueKey('dpis-missing');
  static const String jobRunningText =
      'มีการนำเข้าข้อมูลบุคลากรค้างอยู่ กรุณารอให้เสร็จก่อนแล้วกดโหลดสถานะใหม่';
  static const String dpisErrorText =
      'ข้อมูลบุคลากรเดิมยังอยู่ครบ ลองสั่งนำเข้าใหม่ได้ภายหลัง';
  static const String neverText = 'ยังไม่เคยนำเข้า';

  @override
  State<DpisImportScreen> createState() => _DpisImportScreenState();
}

class _DpisImportScreenState extends State<DpisImportScreen> {
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await widget.apiService.getDpisImport();
      if (!mounted) return;
      setState(() {
        _status = s;
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

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await widget.apiService.runDpisImport();
      if (!mounted) return;
      setState(() {
        _result = r;
        _running = false;
      });
      context.showSuccessSnackBar('${r['message'] ?? 'นำเข้าสำเร็จ'}');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      final hint = switch (e.code) {
        ErrorCodes.jobRunning => DpisImportScreen.jobRunningText,
        ErrorCodes.dpisError => DpisImportScreen.dpisErrorText,
        _ => null,
      };
      setState(() {
        _running = false;
        _error = hint == null ? e.message : '${e.message}\n$hint';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final r = _result;
    return _page(context, DpisImportScreen.groupTitle, [
      const ScreenHeader(
        icon: DpisImportScreen.menuIcon,
        title: DpisImportScreen.menuTitle,
        subtitle:
            'ดึงรายชื่อข้าราชการและลูกจ้างประจำจากระบบ DPIS มาแทนที่ข้อมูลบุคลากรทั้งชุด '
            'ใช้ก่อนเตรียมข้อมูลงวด',
      ),
      const SizedBox(height: 16),
      if (_error != null) ...[
        NoticeBar(
          type: NoticeType.error,
          text: _error!,
          onClose: () => setState(() => _error = null),
        ),
        const SizedBox(height: 12),
      ],
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        StepCard(
          icon: Icons.groups_outlined,
          title: 'ข้อมูลบุคลากรที่นำเข้าไว้',
          trailing: IconButton(
            tooltip: 'โหลดสถานะใหม่',
            icon: const Icon(Icons.refresh),
            onPressed: _running ? null : _load,
          ),
          child: Column(
            children: [
              _fact(
                'ทั้งหมด',
                '${_count(s?['total'])} คน',
                key: DpisImportScreen.totalKey,
              ),
              _fact('ข้าราชการ', '${_count(s?['g'])} คน'),
              _fact('ลูกจ้างประจำ', '${_count(s?['e'])} คน'),
              _fact(
                'นำเข้าล่าสุด',
                s?['last_import_at'] == null
                    ? DpisImportScreen.neverText
                    : formatServerTime(s!['last_import_at']),
              ),
              _fact('โดย', '${s?['last_import_by'] ?? '-'}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (r != null) ...[
          StepCard(
            icon: Icons.task_alt,
            title: 'ผลการนำเข้าครั้งนี้',
            child: Column(
              children: [
                _fact('นำเข้าได้', '${_count(r['total'])} คน'),
                _fact(
                  'จำนวนเดิมก่อนนำเข้า',
                  '${_count(r['previous_total'])} คน',
                ),
                _fact(
                  'ข้ามเพราะเลขบัตรไม่ถูกต้อง',
                  '${_count(r['skipped_invalid_idcard'])} คน',
                ),
                _fact(
                  'ข้ามเพราะเลขบัตรซ้ำ',
                  '${_count(r['skipped_duplicate_idcard'])} คน',
                ),
                // DPIS นับได้แต่ไม่ส่งรายชื่อมา (ข้อมูลใน DPIS ไม่ครบ เช่น ไม่มีตำแหน่ง/ระดับ)
                _fact(
                  'DPIS ไม่ส่งรายชื่อมา (ข้อมูลใน DPIS ไม่ครบ)',
                  'ข้าราชการ ${_count(r['dpis_missing_g'])} คน '
                      'ลูกจ้างประจำ ${_count(r['dpis_missing_e'])} คน',
                  key: DpisImportScreen.missingKey,
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
                'กำลังนำเข้าข้อมูลจาก DPIS อาจใช้เวลาหลายนาที กรุณาอย่าปิดหน้านี้',
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: PrimaryActionButton(
            key: DpisImportScreen.runKey,
            label: _running ? 'กำลังนำเข้า...' : 'นำเข้าข้อมูลบุคลากรจาก DPIS',
            icon: DpisImportScreen.menuIcon,
            loading: _running,
            onPressed: _run,
          ),
        ),
      ],
    ]);
  }
}

/// เตรียมข้อมูลเดือนที่ผ่านมาเป็นงวดปัจจุบัน — เมนู "ข้อมูลงวด" ของฝ่ายบัญชี (ACCOUNT)
///
/// `GET /api/period/prepare` แสดงสรุปก่อนทำ (งวดปลายทาง/ต้นทาง จำนวนบุคลากร รายการเดิมของงวด)
/// งวดมีรายการแล้ว (`confirm_required` หรือ backend ตอบ 409 `CONFIRM_REQUIRED`) = เปิดหน้าต่างยืนยัน
/// ที่บอกจำนวนรายการที่จะถูกล้าง ต้องติ๊กรับทราบก่อนจึงส่ง `confirm_replace: true`
class PreparePeriodScreen extends StatefulWidget {
  final ApiService apiService;

  const PreparePeriodScreen({super.key, required this.apiService});

  static const String menuTitle = 'เตรียมข้อมูลเดือนที่ผ่านมาเป็นงวดปัจจุบัน';
  static const IconData menuIcon = Icons.playlist_add_check;
  static const String groupTitle = 'ข้อมูลงวด';
  static const Key runKey = ValueKey('prepare-run');
  static const Key confirmCheckKey = ValueKey('prepare-confirm-check');
  static const Key confirmButtonKey = ValueKey('prepare-confirm-ok');
  static const String confirmCheckText =
      'รับทราบว่ารายการของงวดนี้จะถูกล้างและสร้างใหม่ ยอดที่หน่วยงานแก้ไว้จะหายไป';
  static const String noDpisText =
      'ยังไม่มีข้อมูลบุคลากร กรุณานำเข้าข้อมูลบุคลากรก่อน';
  static const String notReadyText =
      'การเตรียมงวดครั้งล่าสุดไม่สำเร็จ หน่วยงานยังแก้ยอดของงวดนี้ไม่ได้จนกว่าจะเตรียมงวดใหม่สำเร็จ';

  @override
  State<PreparePeriodScreen> createState() => _PreparePeriodScreenState();
}

class _PreparePeriodScreenState extends State<PreparePeriodScreen> {
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _period(Object? month, Object? year) =>
      Period.fromJson({'month': month, 'year': year}).label;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await widget.apiService.getPrepare();
      if (!mounted) return;
      setState(() {
        _info = info;
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

  /// หน้าต่างยืนยันก่อนล้างรายการเดิม คืนจริงเมื่อผู้ใช้ติ๊กรับทราบแล้วกดยืนยัน
  Future<bool> _confirm({
    required String period,
    required Object? rows,
    required Object? withDebt,
    required Object? edits,
  }) async {
    var checked = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AccountDialogShell(
          icon: Icons.warning_amber_rounded,
          title: 'ยืนยันการเตรียมงวดใหม่',
          subtitle: 'งวด $period มีรายการอยู่แล้ว',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountBanner.error(
                'การเตรียมงวดใหม่จะล้างรายการของงวด $period ทั้งหมด '
                '${_count(rows)} รายการ แล้วสร้างใหม่จากเดือนก่อน',
              ),
              const SizedBox(height: 12),
              _fact('รายการที่จะถูกล้าง', '${_count(rows)} รายการ'),
              _fact('ในจำนวนนี้มียอดหนี้', '${_count(withDebt)} รายการ'),
              _fact('ถูกแก้ไขหลังเตรียมงวดครั้งก่อน', '${_count(edits)} ครั้ง'),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: PreparePeriodScreen.confirmCheckKey,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: checked,
                onChanged: (v) => setLocal(() => checked = v ?? false),
                title: Text(
                  PreparePeriodScreen.confirmCheckText,
                  style: screenText(size: 14),
                ),
              ),
              const SizedBox(height: 12),
              AccountActionButtons(
                key: PreparePeriodScreen.confirmButtonKey,
                confirmText: 'ล้างและเตรียมใหม่',
                confirmIcon: Icons.delete_sweep_outlined,
                onCancel: () => Navigator.of(context).pop(false),
                onConfirm: checked
                    ? () => Navigator.of(context).pop(true)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _run() async {
    if (_running) return;
    final info = _info ?? const {};
    final period = _period(info['month'], info['year']);
    var confirmed = false;
    if (info['confirm_required'] == true) {
      confirmed = await _confirm(
        period: period,
        rows: info['existing_rows'],
        withDebt: info['rows_with_debt'],
        edits: info['edits_since_prepare'],
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      Map<String, dynamic> r;
      try {
        r = await widget.apiService.runPrepare(confirmReplace: confirmed);
      } on ApiException catch (e) {
        // สรุปที่แสดงอยู่เก่าไปแล้ว (มีคนเตรียมงวดไว้ระหว่างนั้น): ถามยืนยันด้วยจำนวนจาก backend แล้วส่งใหม่
        if (!e.isConfirmRequired || confirmed || !mounted) rethrow;
        final d = e.details ?? const {};
        setState(() => _running = false);
        final ok = await _confirm(
          period: _period(
            d['month'] ?? info['month'],
            d['year'] ?? info['year'],
          ),
          rows: d['rows_to_clear'],
          withDebt: d['rows_with_debt'],
          edits: d['edits_since_prepare'],
        );
        if (!ok || !mounted) {
          if (mounted) _load();
          return;
        }
        setState(() => _running = true);
        r = await widget.apiService.runPrepare(confirmReplace: true);
      }
      if (!mounted) return;
      setState(() {
        _result = r;
        _running = false;
      });
      context.showSuccessSnackBar('${r['message'] ?? 'เตรียมข้อมูลงวดสำเร็จ'}');
      await _load();
    } on ApiException catch (e) {
      // โหลดสรุปใหม่ก่อน แล้วค่อยแสดงข้อผิดพลาด (การโหลดล้างข้อความเดิมตอนเริ่ม)
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.code == ErrorCodes.jobRunning
            ? '${e.message}\nมีการเตรียมงวดค้างอยู่ กรุณารอให้เสร็จก่อน'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _info ?? const <String, dynamic>{};
    final r = _result;
    final noDpis = _int(i['current_dpis']) == 0;
    final status = i['last_status']?.toString();
    return _page(context, PreparePeriodScreen.groupTitle, [
      const ScreenHeader(
        icon: PreparePeriodScreen.menuIcon,
        title: PreparePeriodScreen.menuTitle,
        subtitle:
            'สร้างรายการหนี้ของงวดปัจจุบัน หนึ่งแถวต่อบุคลากรที่นำเข้าไว้ และยกยอด 5 รหัสหนี้มาจากเดือนก่อน',
      ),
      const SizedBox(height: 16),
      if (_error != null) ...[
        NoticeBar(
          type: NoticeType.error,
          text: _error!,
          onClose: () => setState(() => _error = null),
        ),
        const SizedBox(height: 12),
      ],
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        if (status == 'FAILED' || (i['ready'] == false && status != null)) ...[
          const NoticeBar(
            type: NoticeType.warning,
            text: PreparePeriodScreen.notReadyText,
          ),
          const SizedBox(height: 12),
        ],
        StepCard(
          icon: Icons.summarize_outlined,
          title: 'สรุปก่อนเตรียมงวด',
          child: Column(
            children: [
              _fact('งวดปัจจุบัน (ปลายทาง)', _period(i['month'], i['year'])),
              _fact(
                'ยกยอดจากงวด (ต้นทาง)',
                _period(i['from_month'], i['from_year']),
              ),
              _fact('บุคลากรที่นำเข้าไว้', '${_count(i['current_dpis'])} คน'),
              _fact(
                'รายการของงวดก่อน',
                '${_count(i['previous_rows'])} รายการ '
                    '(มียอดหนี้ ${_count(i['previous_rows_with_debt'])})',
              ),
              const Divider(height: 18),
              _fact(
                'รายการของงวดปัจจุบันที่มีอยู่',
                '${_count(i['existing_rows'])} รายการ',
              ),
              _fact(
                'ในจำนวนนี้มียอดหนี้',
                '${_count(i['rows_with_debt'])} รายการ',
              ),
              _fact(
                'ถูกแก้ไขหลังเตรียมงวดครั้งก่อน',
                '${_count(i['edits_since_prepare'])} ครั้ง',
              ),
              _fact(
                'เตรียมงวดครั้งล่าสุด',
                i['last_run_at'] == null
                    ? 'ยังไม่เคยเตรียม'
                    : '${formatServerTime(i['last_run_at'])}'
                          ' โดย ${i['last_run_by'] ?? '-'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (i['confirm_required'] == true) ...[
          NoticeBar(
            type: NoticeType.warning,
            text:
                'งวดนี้มีรายการอยู่แล้ว ${_count(i['existing_rows'])} รายการ '
                'การเตรียมงวดใหม่จะล้างรายการเดิมทั้งหมด ระบบจะถามยืนยันอีกครั้ง',
          ),
          const SizedBox(height: 12),
        ],
        if (noDpis) ...[
          const NoticeBar(
            type: NoticeType.warning,
            text: PreparePeriodScreen.noDpisText,
          ),
          const SizedBox(height: 12),
        ],
        if (r != null) ...[
          StepCard(
            icon: Icons.task_alt,
            title: 'ผลการเตรียมงวดครั้งนี้',
            child: Column(
              children: [
                _fact('สร้างรายการ', '${_count(r['rows'])} รายการ'),
                _fact('ข้าราชการ', '${_count(r['g'])} คน'),
                _fact('ลูกจ้างประจำ', '${_count(r['e'])} คน'),
                _fact('ยกยอดจากเดือนก่อน', '${_count(r['carried_over'])} คน'),
                _fact('หาหน่วยงานไม่พบ', '${_count(r['without_div'])} คน'),
                _fact('ล้างรายการเดิม', '${_count(r['cleared_rows'])} รายการ'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_running) ...[
          const NoticeBar(
            type: NoticeType.info,
            text: 'กำลังเตรียมข้อมูลงวด อาจใช้เวลาสักครู่ กรุณาอย่าปิดหน้านี้',
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: PrimaryActionButton(
            key: PreparePeriodScreen.runKey,
            label: _running
                ? 'กำลังเตรียมข้อมูล...'
                : 'เตรียมข้อมูลงวดปัจจุบัน',
            icon: PreparePeriodScreen.menuIcon,
            loading: _running,
            onPressed: noDpis ? null : _run,
          ),
        ),
      ],
    ]);
  }
}
