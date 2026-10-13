import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/period.dart';
import '../services/api_service.dart';
import '../services/work_api.dart';
import '../utils/money.dart';
import '../utils/permission.dart';
import '../widgets/app_pagination.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';
import 'chapana_import_screen.dart';
import 'report_screen.dart';

/// รายงานฌาปนกิจ-สลิป (ACCOUNT) — เทียบรายการหักฌาปนกิจของงวดกับยอดที่หักได้จริงในสลิปเงินเดือน
///
/// - ยอดในรายการฌาปนกิจ = เงินที่**ต้องการหัก** · ยอดในสลิป = เงินที่**หักได้จริง** (มาจากระบบสลิปภาษีผ่านช่องทางระหว่างระบบ)
/// - ผู้ที่หักไม่ได้: เงินไม่พอให้หัก หรือเกษียณ/พ้นจากการเป็นข้าราชการ-ลูกจ้างประจำปัจจุบันแล้ว (ข้อมูลต้นทางฌาปนกิจยังไม่ได้ปรับ)
///
/// เลือกงวด (ย้อนหลังได้) + ประเภท แล้วกด "ตรวจสอบ" (`GET /api/chapana/slip-check` — เรียกข้ามระบบ จึง**ไม่เรียกอัตโนมัติ**)
/// แสดงการ์ดสรุป + ตารางผู้ที่หักไม่ได้ (แบ่งหน้าฝั่งหน้าเว็บ เรียงตามที่ backend ส่ง: สังกัดแล้วชื่อ) และรายงาน PDF
/// (`GET /api/reports/chapana-not-pay`) ข้อผิดพลาดเฉพาะ: 503 `SLIP_API_NOT_CONFIGURED`, 502 `SLIP_API_ERROR`, 502 `DPIS_ERROR`
/// **คำตอบมีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น ไม่ลง log ไม่เก็บลง storage** เลขบัตรแสดงแบบปิดบางส่วน
class ChapanaSlipScreen extends StatefulWidget {
  final ApiService apiService;

  const ChapanaSlipScreen({super.key, required this.apiService});

  static const String menuTitle = 'รายงานฌาปนกิจ-สลิป';
  static const IconData menuIcon = Icons.compare_arrows;
  static const String groupTitle = 'ฌาปนกิจ';

  static const Key runKey = ValueKey('slip-run');
  static const Key summaryKey = ValueKey('slip-summary');
  static const Key tableKey = ValueKey('slip-table');
  static const Key reportKey = ValueKey('slip-report');
  static const Key allPaidKey = ValueKey('slip-all-paid');
  static const Key noChapanaKey = ValueKey('slip-no-chapana');
  static const Key goImportKey = ValueKey('slip-go-import');
  static const Key busyKey = ValueKey('slip-busy');
  static Key typeKey(String type) => ValueKey('slip-type-$type');
  static Key rowKey(int index) => ValueKey('slip-row-$index');

  static const String runLabel = 'ตรวจสอบ';
  static const String busyText =
      'กำลังตรวจสอบกับระบบสลิปภาษี อาจใช้เวลาหลายวินาที กรุณารอ';
  static const String mismatchLabel = 'ยอดไม่ตรง';
  static const String notInSlipLabel = 'ไม่มีในสลิป';
  static const String allPaidText = 'หักเงินฌาปนกิจได้ครบทุกคน ยอดตรงกับสลิป';
  static const String noChapanaText =
      'งวดนี้ยังไม่ได้นำเข้าข้อมูลฌาปนกิจของประเภทนี้ จึงยังเทียบกับสลิปไม่ได้';
  static const String goImportLabel = 'ไปหน้านำเข้าข้อมูลฌาปนกิจ';
  static const String notConfiguredText =
      'ยังไม่ได้ตั้งค่าการเชื่อมต่อระบบสลิปภาษี ติดต่อผู้ดูแลระบบ';
  static const String slipErrorText = 'เรียกระบบสลิปภาษีไม่ได้ ลองใหม่ภายหลัง';
  static const String dpisErrorText =
      'เรียกระบบข้อมูลบุคลากร (DPIS) ไม่ได้ ลองใหม่ภายหลัง';
  static const String retiredLabel = 'เกษียณ/พ้นสภาพ';
  static const String activeLabel = 'ปัจจุบัน';

  @override
  State<ChapanaSlipScreen> createState() => _ChapanaSlipScreenState();
}

class _ChapanaSlipScreenState extends State<ChapanaSlipScreen>
    with FileDownloads<ChapanaSlipScreen> {
  Period? _past;
  String _type = EmpType.g;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _items = [];
  bool _checking = false;
  String? _error;
  int _page = 0;
  int _pageSize = 10;

  Map<String, dynamic> get _summary => _data?['summary'] is Map
      ? Map<String, dynamic>.from(_data!['summary'] as Map)
      : const {};

  /// เปลี่ยนงวด/ประเภท: ผลเดิมและไฟล์เดิมไม่ตรงกับตัวเลือกแล้ว ต้องกดตรวจสอบใหม่
  void _changed(VoidCallback apply) {
    clearSaved();
    setState(() {
      _data = null;
      _items = [];
      _error = null;
      downloadError = null;
      _page = 0;
      apply();
    });
  }

  String _describe(ApiException e) => switch (e.code) {
    ErrorCodes.slipApiNotConfigured => ChapanaSlipScreen.notConfiguredText,
    ErrorCodes.slipApiError => ChapanaSlipScreen.slipErrorText,
    ErrorCodes.dpisError => ChapanaSlipScreen.dpisErrorText,
    _ => e.message,
  };

  Future<void> _run() async {
    if (_checking) return;
    clearSaved();
    setState(() {
      _checking = true;
      _error = null;
      downloadError = null;
      _data = null;
      _items = [];
      _page = 0;
    });
    try {
      final data = await widget.apiService.getChapanaSlipCheck(
        type: _type,
        period: _past,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _items = [
          for (final e in data['items'] as List? ?? const [])
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        _checking = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = _describe(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = e.toString();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // หน้าจอ
  // ---------------------------------------------------------------------------

  Widget _summaryCard() {
    final s = _summary;
    final slip = _data?['slip'] is Map
        ? Map<String, dynamic>.from(_data!['slip'] as Map)
        : const <String, dynamic>{};
    final notPaid = intOf(s['not_paid']);
    return StepCard(
      key: ChapanaSlipScreen.summaryKey,
      icon: Icons.summarize_outlined,
      title:
          'ผลการเทียบของ${EmpType.nameOf('${_data?['type'] ?? _type}')} '
          'งวด ${Period.fromJson(_data ?? const {}).label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow(
            'รายการฌาปนกิจทั้งหมด (ยอดที่ต้องการหัก)',
            '${countText(s['chapana_rows'])} คน · ${moneyText(s['chapana_amount'])} บาท',
          ),
          FactRow(
            'หักได้ตรงยอด',
            '${countText(s['matched'])} คน',
            color: AppTheme.successColor,
          ),
          FactRow(
            ChapanaSlipScreen.mismatchLabel,
            '${countText(s['mismatch'])} คน',
            color: intOf(s['mismatch']) > 0 ? AppTheme.warningColor : null,
          ),
          FactRow(
            ChapanaSlipScreen.notInSlipLabel,
            '${countText(s['not_in_slip'])} คน',
            color: intOf(s['not_in_slip']) > 0 ? AppTheme.dangerColor : null,
          ),
          FactRow(
            'รวมที่หักไม่ได้',
            '${countText(notPaid)} คน · ${moneyText(s['not_paid_amount'])} บาท',
            color: notPaid > 0 ? AppTheme.dangerColor : null,
          ),
          const SizedBox(height: 6),
          Text(
            'ระบบสลิปภาษีส่งมา ${countText(slip['count'])} คน · '
            'มีในสลิปแต่ไม่อยู่ในรายการฌาปนกิจของงวด ${countText(slip['not_in_chapana'])} คน (ไม่อยู่ในรายงาน)',
            style: screenText(size: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _text(String text, {int flex = 2, bool right = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: screenText(size: 14),
      ),
    ),
  );

  Widget _row(int index, Map<String, dynamic> r) {
    final mismatch = r['status'] == 'MISMATCH';
    final status = r['retired'] == true
        ? ChapanaSlipScreen.retiredLabel
        : ('${r['per_status'] ?? ''}'.trim() == '1'
              ? ChapanaSlipScreen.activeLabel
              : '-');
    String clean(Object? v) => '${v ?? ''}'.trim().isEmpty ? '-' : '$v'.trim();
    return Row(
      key: ChapanaSlipScreen.rowKey(index),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(clean(r['member_no'])),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clean(r['name']), style: screenText(size: 14.5)),
                Text(
                  IdCard.masked('${r['idcard'] ?? ''}'),
                  style: screenText(size: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        _text(
          [
            clean(r['dept_name']),
            if ('${r['org_code'] ?? ''}'.trim().isNotEmpty)
              'รหัสสังกัด ${'${r['org_code']}'.trim()}',
          ].join('\n'),
          flex: 5,
        ),
        _text(status, flex: 3),
        _text(moneyText(r['amount']), flex: 3, right: true),
        _text(moneyText(r['slip_amount']), flex: 3, right: true),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(
                mismatch
                    ? ChapanaSlipScreen.mismatchLabel
                    : ChapanaSlipScreen.notInSlipLabel,
                mismatch ? AppTheme.warningColor : AppTheme.dangerColor,
              ),
            ),
          ),
        ),
        // จ่ายให้กับ: บรรทัดละคนตามที่ backend ส่ง
        _text(clean(r['pay_for']), flex: 5),
      ],
    );
  }

  Widget _table() {
    final pages = (_items.length / _pageSize).ceil();
    final page = _page >= pages ? pages - 1 : _page;
    final start = page * _pageSize;
    final rows = _items.skip(start).take(_pageSize).toList();
    return StepCard(
      key: ChapanaSlipScreen.tableKey,
      icon: Icons.person_off_outlined,
      title: 'ผู้ที่หักเงินฌาปนกิจไม่ได้',
      subtitle:
          'เงินไม่พอให้หัก หรือเกษียณ/พ้นจากการเป็นข้าราชการ-ลูกจ้างประจำปัจจุบันแล้ว '
          '(ข้อมูลต้นทางฌาปนกิจยังไม่ได้ปรับ)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetScroll(
            minWidth: 1160,
            child: SheetCard(
              header: const Row(
                children: [
                  Expanded(flex: 2, child: SheetHead('เลขสมาชิก')),
                  Expanded(flex: 5, child: SheetHead('ชื่อ')),
                  Expanded(flex: 5, child: SheetHead('สังกัด')),
                  Expanded(flex: 3, child: SheetHead('สถานะบุคคล')),
                  Expanded(
                    flex: 3,
                    child: SheetHead(
                      'ยอดที่ต้องการหัก',
                      align: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: SheetHead('ยอดในสลิป', align: TextAlign.right),
                  ),
                  Expanded(flex: 3, child: SheetHead('สาเหตุ')),
                  Expanded(flex: 5, child: SheetHead('จ่ายให้กับ')),
                ],
              ),
              rows: [
                for (var i = 0; i < rows.length; i++) _row(start + i, rows[i]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppPagination(
            currentPage: page,
            totalPages: pages,
            pageSize: _pageSize,
            summary: 'ทั้งหมด ${countText(_items.length)} คน',
            onPageChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (s) => setState(() {
              _pageSize = s;
              _page = 0;
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _checking || downloading != null;
    final data = _data;
    final rows = intOf(_summary['chapana_rows']);
    final notPaid = intOf(_summary['not_paid']);
    return WorkPage(
      group: ChapanaSlipScreen.groupTitle,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: ChapanaSlipScreen.menuIcon,
          title: ChapanaSlipScreen.menuTitle,
          subtitle:
              'เทียบเงินฌาปนกิจที่ต้องการหัก กับเงินที่หักได้จริงในสลิปเงินเดือน เพื่อหาผู้ที่หักไม่ได้',
          bullets: [
            'ยอดในรายการฌาปนกิจ = เงินที่ต้องการหัก · ยอดในสลิป = เงินที่หักได้จริง (ข้อมูลจากระบบสลิปภาษี)',
            'ยอดต้องเท่ากันพอดีจึงถือว่าหักได้ ผลตรวจคำนวณใหม่ทุกครั้งที่กดตรวจสอบ',
          ],
        ),
        const SizedBox(height: 14),
        PeriodPicker(
          past: _past,
          enabled: !busy,
          onChanged: (p) => _changed(() => _past = p),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final t in EmpType.names.entries)
              ChoiceChip(
                key: ChapanaSlipScreen.typeKey(t.key),
                label: Text(t.value, style: screenText(size: 14)),
                selected: _type == t.key,
                onSelected: busy ? null : (_) => _changed(() => _type = t.key),
              ),
            PrimaryActionButton(
              key: ChapanaSlipScreen.runKey,
              label: _checking ? 'กำลังตรวจสอบ...' : ChapanaSlipScreen.runLabel,
              icon: Icons.fact_check_outlined,
              loading: _checking,
              onPressed: busy ? null : _run,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_checking) ...[
          const NoticeBar(
            key: ChapanaSlipScreen.busyKey,
            type: NoticeType.info,
            text: ChapanaSlipScreen.busyText,
          ),
          const SizedBox(height: 12),
        ],
        for (final e in [_error, downloadError])
          if (e != null) ...[
            NoticeBar(type: NoticeType.error, text: e),
            const SizedBox(height: 12),
          ],
        if (data != null && rows == 0)
          NoticeBar(
            key: ChapanaSlipScreen.noChapanaKey,
            type: NoticeType.warning,
            text: ChapanaSlipScreen.noChapanaText,
            action: TextButton.icon(
              key: ChapanaSlipScreen.goImportKey,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChapanaImportScreen(apiService: widget.apiService),
                ),
              ),
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(
                ChapanaSlipScreen.goImportLabel,
                style: screenText(size: 14, color: AppTheme.primaryColor),
              ),
            ),
          )
        else if (data != null) ...[
          if (notPaid == 0) ...[
            const NoticeBar(
              key: ChapanaSlipScreen.allPaidKey,
              type: NoticeType.success,
              title: 'ครบถ้วน',
              text: ChapanaSlipScreen.allPaidText,
            ),
            const SizedBox(height: 12),
          ],
          _summaryCard(),
          const SizedBox(height: 12),
          DownloadButtons(
            key: ChapanaSlipScreen.reportKey,
            label: 'รายงานผู้ที่ไม่ถูกหักเงินฌาปนกิจ (PDF)',
            icon: Icons.picture_as_pdf_outlined,
            busy: downloading == 'rep9',
            // ไม่มีผู้ที่หักไม่ได้ = ไม่มีรายงานให้ออก
            blocked: busy || notPaid == 0,
            saved: savedOf('rep9'),
            canOpen: true,
            onDownload: () => runDownload(
              'rep9',
              () => widget.apiService.downloadChapanaNotPay(
                type: _type,
                period: _past,
              ),
              onError: (e) {
                downloadError = e.statusCode == 404
                    ? ReportScreen.noDataText
                    : _describe(e);
                return true;
              },
            ),
          ),
          if (notPaid > 0) ...[const SizedBox(height: 12), _table()],
        ],
      ],
    );
  }
}
