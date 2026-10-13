import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/period.dart';
import '../services/api_service.dart';
import '../services/work_api.dart';
import '../utils/dialog.dart';
import '../utils/money.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';

/// ตรวจยอดเงินกู้กับหนี้เดือน (ACCOUNT) — รวมเมนู "ปรับปรุงหนี้ธนาคาร ดาวน์โหลดหนี้ที่ต้องแก้ไข"
/// และ "รายชื่อบุคคลที่ไม่มีเลขบัญชีธนาคาร" ของระบบเดิมไว้หน้าเดียว (งานเดียวกัน ทำต่อเนื่องกัน)
///
/// - `GET /api/loans/check` ผลต่อธนาคาร + รายคนที่ยอดรวมเลขบัญชีไม่เท่าหนี้รายเดือน
/// - "ปรับปรุงหนี้ธนาคาร" (`POST /api/loans/sync-amounts` งวดปัจจุบันเท่านั้น ถามยืนยันก่อน):
///   ตั้งยอดของคนที่มีบัญชีเดียวให้เท่าหนี้เดือน คนที่มีหลายบัญชีต้องแก้เองที่หน้าเลขที่บัญชีเงินกู้
/// - ดาวน์โหลดไฟล์หนี้ที่ต้องแก้ไข (`mismatch-file`) และรายชื่อบุคคลที่ไม่มีเลขบัญชี (`missing-accounts` + ไฟล์)
class LoanCheckScreen extends StatefulWidget {
  final ApiService apiService;

  /// เปิดจากเมนู "รายชื่อบุคคลที่ไม่มีเลขบัญชีธนาคาร": แสดงส่วนนั้นก่อน
  final bool missingFirst;

  const LoanCheckScreen({
    super.key,
    required this.apiService,
    this.missingFirst = false,
  });

  static const String menuTitle = 'ตรวจยอดเงินกู้กับหนี้เดือน';
  static const String syncMenuTitle =
      'ปรับปรุงหนี้ธนาคาร ดาวน์โหลดหนี้ที่ต้องแก้ไข';
  static const String missingMenuTitle = 'รายชื่อบุคคลที่ไม่มีเลขบัญชีธนาคาร';
  static const IconData menuIcon = Icons.fact_check_outlined;
  static const String groupTitle = 'ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร';

  static const Key statusKey = ValueKey('loan-check-status');
  static const Key syncKey = ValueKey('loan-check-sync');
  static const Key mismatchFileKey = ValueKey('loan-check-file');
  static const Key missingFileKey = ValueKey('loan-missing-file');
  static const Key missingKey = ValueKey('loan-missing');
  static const Key syncResultKey = ValueKey('loan-sync-result');
  static Key bankKey(String bank) => ValueKey('loan-check-$bank');

  static const Map<String, String> bankNames = {
    'GHB': 'ธ.อาคารสงเคราะห์ (40302)',
    'GSB': 'ธ.ออมสิน (40303)',
    'KTB': 'ธ.กรุงไทย (40315)',
  };

  static const String okText = 'ยอดเลขบัญชีเงินกู้ตรงกับหนี้รายเดือนทุกธนาคาร';
  static const String syncLabel = 'ปรับปรุงหนี้ธนาคาร';
  static const String syncQuestion =
      'ปรับปรุงหนี้ธนาคารของงวดปัจจุบันใช่หรือไม่\n'
      'ระบบจะตั้งยอดของคนที่มีเลขบัญชีเดียวในธนาคารนั้นให้เท่ากับหนี้รายเดือน\n'
      'คนที่มีหลายบัญชีแล้วยอดรวมไม่ตรงจะไม่ถูกแก้ ต้องแก้เองที่หน้าเลขที่บัญชีเงินกู้';
  static const String pastSyncText =
      'ปรับปรุงหนี้ธนาคารได้เฉพาะงวดปัจจุบัน งวดย้อนหลังดูผลตรวจได้อย่างเดียว';
  static const String noMissingText =
      'ทุกคนที่มีหนี้ธนาคารมีเลขที่บัญชีครบแล้ว';

  @override
  State<LoanCheckScreen> createState() => _LoanCheckScreenState();
}

class _LoanCheckScreenState extends State<LoanCheckScreen>
    with FileDownloads<LoanCheckScreen> {
  Period? _past;
  Map<String, dynamic>? _check;
  List<Map<String, dynamic>> _missing = [];
  Map<String, dynamic>? _syncResult;
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  bool get _busy => _loading || _syncing || downloading != null;

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
    clearSaved();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final check = await widget.apiService.getLoanCheck(period: _past);
      final missing = await widget.apiService.getMissingAccounts(period: _past);
      if (!mounted) return;
      setState(() {
        _check = check;
        _missing = _maps(missing['items']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _check = null;
        _missing = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _sync() async {
    final ok = await AppDialog.showConfirm(
      context,
      LoanCheckScreen.syncQuestion,
      confirmText: LoanCheckScreen.syncLabel,
    );
    if (ok != true || !mounted) return;
    setState(() {
      _syncing = true;
      _error = null;
      _syncResult = null;
    });
    try {
      final r = await widget.apiService.syncLoanAmounts();
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncResult = r;
      });
      context.showSuccessSnackBar(
        '${r['message'] ?? 'ปรับปรุงหนี้ธนาคารเรียบร้อยแล้ว'} (${countText(r['updated'])} รายการ)',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = e.toString();
      });
    }
  }

  String _name(Map<String, dynamic> m) =>
      '${m['title'] ?? ''}${m['name'] ?? ''} ${m['surname'] ?? ''}'.trim();

  Widget _personCell(Map<String, dynamic> m) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_name(m), style: screenText(size: 14.5)),
        Text(
          '${EmpType.nameOf('${m['type']}')} · หน่วยงาน ${m['div'] ?? '-'} · '
          '${IdCard.masked('${m['idcard'] ?? ''}')}',
          style: screenText(size: 12.5, color: AppTheme.textSecondary),
        ),
      ],
    ),
  );

  Widget _num(String text, {Color? color, int flex = 3}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: screenText(size: 14.5, color: color ?? AppTheme.textPrimary),
      ),
    ),
  );

  Widget _mismatchTable(List<Map<String, dynamic>> rows) => SheetScroll(
    minWidth: 640,
    child: SheetCard(
      header: const Row(
        children: [
          Expanded(flex: 7, child: SheetHead('ชื่อ-สกุล')),
          Expanded(flex: 2, child: SheetHead('บัญชี', align: TextAlign.right)),
          Expanded(
            flex: 3,
            child: SheetHead('หนี้เดือน', align: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: SheetHead('ยอดเลขบัญชี', align: TextAlign.right),
          ),
        ],
      ),
      rows: [
        for (final m in rows)
          Row(
            children: [
              Expanded(flex: 7, child: _personCell(m)),
              _num(countText(m['accounts']), flex: 2),
              _num(moneyText(m['debt'])),
              _num(moneyText(m['loan_total']), color: AppTheme.dangerColor),
            ],
          ),
      ],
    ),
  );

  Widget _bankCard(Map<String, dynamic> b) {
    final bank = '${b['bank']}';
    final wrong = intOf(b['mismatch_count']);
    return StepCard(
      key: LoanCheckScreen.bankKey(bank),
      icon: wrong == 0 ? Icons.check_circle_outline : Icons.error_outline,
      title: LoanCheckScreen.bankNames[bank] ?? bank,
      subtitle:
          'ตรวจ ${countText(b['checked'])} คน · ไม่ตรง ${countText(wrong)} คน · '
          'ไม่มีเลขบัญชี ${countText(b['missing_account'])} คน',
      trailing: StatusChip(
        wrong == 0 ? 'ตรง' : 'ไม่ตรง $wrong',
        wrong == 0 ? AppTheme.successColor : AppTheme.dangerColor,
      ),
      child: wrong == 0
          ? Text(
              'ไม่มีรายการที่ต้องแก้',
              style: screenText(size: 14, color: AppTheme.textSecondary),
            )
          : _mismatchTable(_maps(b['mismatches'])),
    );
  }

  Widget _checkSection() {
    final check = _check!;
    final ok = check['ok'] == true;
    final result = _syncResult;
    final manual = result == null
        ? 0
        : _maps(
            result['banks'],
          ).fold<int>(0, (s, b) => s + intOf(b['manual_count']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeBar(
          key: LoanCheckScreen.statusKey,
          type: ok ? NoticeType.success : NoticeType.warning,
          title: ok ? 'ผ่าน' : 'ยังไม่ตรง',
          text: ok
              ? LoanCheckScreen.okText
              : 'มี ${countText(check['mismatch_count'])} รายการที่ยอดรวมเลขบัญชีไม่เท่าหนี้รายเดือน '
                    '— รายงานส่งธนาคารจะออกไม่ได้จนกว่าจะแก้',
        ),
        const SizedBox(height: 10),
        if (result != null) ...[
          NoticeBar(
            key: LoanCheckScreen.syncResultKey,
            type: manual == 0 ? NoticeType.success : NoticeType.info,
            title: 'ผลการปรับปรุงหนี้ธนาคาร',
            text:
                'ตั้งยอดให้เท่าหนี้เดือนแล้ว ${countText(result['updated'])} รายการ'
                '${manual > 0 ? '\nเหลือ ${countText(manual)} รายการที่มีหลายบัญชี ต้องแก้เองที่หน้า "เลขที่บัญชีเงินกู้"' : ''}',
            onClose: () => setState(() => _syncResult = null),
          ),
          const SizedBox(height: 10),
        ],
        if (_past != null) ...[
          const NoticeBar(
            type: NoticeType.info,
            text: LoanCheckScreen.pastSyncText,
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_past == null)
              PrimaryActionButton(
                key: LoanCheckScreen.syncKey,
                label: LoanCheckScreen.syncLabel,
                icon: Icons.sync_alt,
                loading: _syncing,
                onPressed: _busy || ok ? null : _sync,
              ),
            DownloadButtons(
              key: LoanCheckScreen.mismatchFileKey,
              label: 'ดาวน์โหลดหนี้ที่ต้องแก้ไข',
              color: AppTheme.neutralColor,
              busy: downloading == 'mismatch',
              blocked: _busy,
              saved: savedOf('mismatch'),
              onDownload: () => runDownload(
                'mismatch',
                () => widget.apiService.downloadLoanMismatchFile(period: _past),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final b in _maps(check['banks'])) ...[
          _bankCard(b),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _missingSection() => StepCard(
    key: LoanCheckScreen.missingKey,
    icon: Icons.person_off_outlined,
    title: LoanCheckScreen.missingMenuTitle,
    subtitle:
        '${countText(_missing.length)} คน — มีหนี้ธนาคารในงวดแต่ยังไม่มีเลขที่บัญชีของธนาคารนั้น '
        '(ไม่อยู่ในรายงานส่งธนาคาร)',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_missing.isEmpty)
          Text(
            LoanCheckScreen.noMissingText,
            style: screenText(size: 14, color: AppTheme.textSecondary),
          )
        else ...[
          SheetScroll(
            minWidth: 720,
            child: SheetCard(
              header: const Row(
                children: [
                  Expanded(flex: 7, child: SheetHead('ชื่อ-สกุล')),
                  Expanded(
                    flex: 3,
                    child: SheetHead('ธอส.', align: TextAlign.right),
                  ),
                  Expanded(
                    flex: 3,
                    child: SheetHead('ออมสิน', align: TextAlign.right),
                  ),
                  Expanded(
                    flex: 3,
                    child: SheetHead('กรุงไทย', align: TextAlign.right),
                  ),
                  Expanded(flex: 3, child: SheetHead('ขาดบัญชีของ')),
                ],
              ),
              rows: [
                for (final m in _missing)
                  Row(
                    children: [
                      Expanded(flex: 7, child: _personCell(m)),
                      _num(moneyText(m['c40302'])),
                      _num(moneyText(m['c40303'])),
                      _num(moneyText(m['c40315'])),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            (m['missing_banks'] as List? ?? const []).join(
                              ', ',
                            ),
                            style: screenText(
                              size: 14,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        DownloadButtons(
          key: LoanCheckScreen.missingFileKey,
          label: 'ดาวน์โหลดรายชื่อ (ไฟล์ข้อความ)',
          color: AppTheme.neutralColor,
          busy: downloading == 'missing',
          blocked: _busy,
          saved: savedOf('missing'),
          onDownload: () => runDownload(
            'missing',
            () => widget.apiService.downloadMissingAccountsFile(period: _past),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (_check != null) _checkSection(),
      if (_check != null) _missingSection(),
    ];
    return WorkPage(
      group: LoanCheckScreen.groupTitle,
      children: [
        ScreenHeader(
          icon: LoanCheckScreen.menuIcon,
          title: widget.missingFirst
              ? LoanCheckScreen.missingMenuTitle
              : LoanCheckScreen.menuTitle,
          subtitle:
              'เทียบยอดผ่อนของเลขที่บัญชีเงินกู้กับหนี้รายเดือนของ ธอส. ออมสิน และกรุงไทย ก่อนออกรายงานส่งธนาคาร',
        ),
        const SizedBox(height: 14),
        PeriodPicker(
          past: _past,
          enabled: !_busy,
          onChanged: (p) {
            setState(() {
              _past = p;
              _syncResult = null;
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
        else
          for (final s
              in widget.missingFirst ? sections.reversed : sections) ...[
            s,
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
