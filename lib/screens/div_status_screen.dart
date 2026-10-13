import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/period.dart';
import '../services/api_service.dart';
import '../services/work_api.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_pagination.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';
import 'debt_entry_screen.dart';
import 'period_jobs_screen.dart';

/// สถานะการบันทึกของหน่วยงาน (ACCOUNT) — ใช้ตามหน่วยงานที่ยังไม่บันทึกหนี้ของงวด
///
/// `GET /api/debts/div-status?month=&year=` → สรุป (`summary`) + รายหน่วยงาน (`items`)
/// - การ์ดสรุปพร้อมแถบความคืบหน้า ตัวกรองสถานะ / ส่วนกลาง-ภูมิภาค / ค้นรหัสหรือชื่อ
/// - ตารางเรียงตามลำดับหน่วยงาน กดหัวคอลัมน์เรียงได้ แบ่งหน้าฝั่งหน้าเว็บ (5/10/15/20)
///   กดแถวไปหน้า "บันทึกข้อมูล" ของหน่วยงานและงวดนั้น
/// - "คัดลอกรายชื่อหน่วยงานที่ยังไม่บันทึก" (รหัส + ชื่อ ลงคลิปบอร์ด — ไม่มีข้อมูลบุคคล)
/// - `audit_available` เท็จ (งวดก่อนมีระบบใหม่ ไม่มีประวัติการแก้ไข): แจ้งว่าบอกสถานะไม่ได้
///   และ**ไม่แสดงป้าย "ยังไม่บันทึก"** ให้เข้าใจผิด
/// - `period_ready` เท็จ: แถบแจ้งพร้อมปุ่มไปหน้าเตรียมงวด · รายการ `div` ว่าง = "ไม่ระบุหน่วยงาน" (กดไม่ได้)
///   `div_order` เป็นข้อความ/null (null เรียงต่อท้าย) · งวดไม่มีรายการ = ตารางว่าง สรุปเป็นศูนย์
/// - backend ยังไม่มีเส้นนี้ (404): แสดงข้อความว่ายังใช้ไม่ได้ ไม่พัง
class DivStatusScreen extends StatefulWidget {
  final ApiService apiService;

  const DivStatusScreen({super.key, required this.apiService});

  static const String menuTitle = 'สถานะการบันทึกของหน่วยงาน';
  static const IconData menuIcon = Icons.fact_check;
  static const String groupTitle = 'ข้อมูลงวด';

  static const Key summaryKey = ValueKey('div-status-summary');
  static const Key progressKey = ValueKey('div-status-progress');
  static const Key searchKey = ValueKey('div-status-search');
  static const Key refreshKey = ValueKey('div-status-refresh');
  static const Key copyKey = ValueKey('div-status-copy');
  static const Key noAuditKey = ValueKey('div-status-no-audit');
  static const Key unavailableKey = ValueKey('div-status-unavailable');
  static Key rowKey(String div) => ValueKey('div-status-row-$div');
  static Key statusKey(String div) => ValueKey('div-status-chip-$div');
  static Key statusFilterKey(String value) =>
      ValueKey('div-status-filter-$value');
  static Key regionFilterKey(String value) =>
      ValueKey('div-status-region-$value');

  static const String editedLabel = 'บันทึกแล้ว';
  static const String notEditedLabel = 'ยังไม่บันทึก';
  static const String copyLabel = 'คัดลอกรายชื่อหน่วยงานที่ยังไม่บันทึก';
  static const String noAuditText =
      'งวดนี้ไม่มีประวัติการแก้ไขในระบบใหม่ จึงบอกไม่ได้ว่าหน่วยงานใดบันทึกแล้ว';
  static const String unavailableText =
      'ระบบยังไม่เปิดใช้ข้อมูลสถานะการบันทึกของหน่วยงาน (backend ยังไม่มีเส้นนี้) กรุณาลองใหม่ภายหลัง';
  static const String emptyText = 'ไม่มีหน่วยงานตามเงื่อนไขที่เลือก';
  static const String noRowsText = 'งวดนี้ไม่มีรายการหนี้';
  static const String noDivName = 'ไม่ระบุหน่วยงาน';
  static const String criteriaText =
      'ยังไม่บันทึก หมายถึงยังไม่มีการแก้ยอดในงวดนี้ รวมหน่วยงานที่ไม่มีรายการต้องแก้';
  static const String notReadyText =
      'การเตรียมข้อมูลงวดยังไม่เสร็จหรือไม่สำเร็จ รายการที่เห็นอาจไม่ครบ และหน่วยงานยังแก้ยอดไม่ได้จนกว่าจะเตรียมงวดใหม่สำเร็จ';
  static const String goPrepareLabel = 'ไปหน้าเตรียมข้อมูลงวด';
  static const Key notReadyKey = ValueKey('div-status-not-ready');
  static const Key goPrepareKey = ValueKey('div-status-go-prepare');
  static const Key criteriaKey = ValueKey('div-status-criteria');
  static const String allDoneText =
      'ทุกหน่วยงานบันทึกแล้ว ไม่มีรายชื่อให้คัดลอก';

  /// ตัวกรองสถานะ / ภูมิภาค (ค่า -> ป้าย)
  static const Map<String, String> statusFilters = {
    'all': 'ทั้งหมด',
    'edited': editedLabel,
    'not': notEditedLabel,
  };
  static const Map<String, String> regionFilters = {
    'all': 'ทุกหน่วยงาน',
    'center': 'ส่วนกลาง',
    'region': 'ภูมิภาค',
  };

  @override
  State<DivStatusScreen> createState() => _DivStatusScreenState();
}

class _DivStatusScreenState extends State<DivStatusScreen> {
  final _search = TextEditingController();
  Period? _past;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _unavailable = false;
  String? _error;

  String _status = 'all';
  String _region = 'all';
  String _sort = 'div_order';
  bool _descending = false;
  int _page = 0;
  int _pageSize = 10;

  bool get _audit => _data?['audit_available'] != false;

  /// ลำดับของหน่วยงาน: `div_order` เป็นข้อความตัวเลข หน่วยงานที่ไม่มีในข้อมูลหลัก (null) อยู่ถัดไป
  /// และรายการ "ไม่ระบุหน่วยงาน" (`div` ว่าง) อยู่ท้ายสุด
  static int _order(Map<String, dynamic> r) {
    if ('${r['div'] ?? ''}'.isEmpty) return 1 << 31;
    return int.tryParse('${r['div_order'] ?? ''}') ?? (1 << 30);
  }

  static String _nameOf(Map<String, dynamic> r) => '${r['div'] ?? ''}'.isEmpty
      ? DivStatusScreen.noDivName
      : '${r['divname'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _unavailable = false;
    });
    try {
      final data = await widget.apiService.getDivStatus(period: _past);
      if (!mounted) return;
      setState(() {
        _data = data;
        _items = [
          for (final e in data['items'] as List? ?? const [])
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        // ไม่มีประวัติ: ตัวกรองสถานะใช้ไม่ได้
        if (data['audit_available'] == false) _status = 'all';
        _page = 0;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _items = [];
        _loading = false;
        // backend ยังไม่มีเส้นนี้
        if (e.statusCode == 404 || e.statusCode == 405) {
          _unavailable = true;
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _items = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// รายการหลังกรองและเรียง (ก่อนแบ่งหน้า)
  List<Map<String, dynamic>> get _filtered {
    final keyword = _search.text.trim().toLowerCase();
    final rows = _items.where((r) {
      if (_status == 'edited' && r['edited'] != true) return false;
      if (_status == 'not' && r['edited'] == true) return false;
      if (_region == 'center' && r['center'] != true) return false;
      if (_region == 'region' && r['center'] == true) return false;
      return keyword.isEmpty ||
          '${r['div']}'.toLowerCase().contains(keyword) ||
          _nameOf(r).toLowerCase().contains(keyword);
    }).toList();
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      if (_sort == 'div_order') return _order(a).compareTo(_order(b));
      final x = a[_sort];
      final y = b[_sort];
      if (x is bool || y is bool) {
        return (x == true ? 1 : 0).compareTo(y == true ? 1 : 0);
      }
      final nx = x is num ? x : num.tryParse('${x ?? ''}');
      final ny = y is num ? y : num.tryParse('${y ?? ''}');
      if (nx != null && ny != null) return nx.compareTo(ny);
      return '${x ?? ''}'.compareTo('${y ?? ''}');
    }

    rows.sort((a, b) {
      final c = _descending ? cmp(b, a) : cmp(a, b);
      // ค่าเท่ากัน: คงลำดับหน่วยงาน
      if (c != 0) return c;
      final o = _order(a).compareTo(_order(b));
      return o != 0 ? o : '${a['div']}'.compareTo('${b['div']}');
    });
    return rows;
  }

  void _sortBy(String key) => setState(() {
    if (_sort == key) {
      _descending = !_descending;
    } else {
      _sort = key;
      _descending = false;
    }
    _page = 0;
  });

  Future<void> _copyNotEdited() async {
    // รายการ "ไม่ระบุหน่วยงาน" ไม่ใช่หน่วยงานให้ตาม จึงไม่อยู่ในรายชื่อ
    final rows =
        _items
            .where((r) => r['edited'] != true && '${r['div'] ?? ''}'.isNotEmpty)
            .toList()
          ..sort((a, b) => _order(a).compareTo(_order(b)));
    if (rows.isEmpty) {
      context.showInfoSnackBar(DivStatusScreen.allDoneText);
      return;
    }
    final label = (_past ?? Period.fromJson(_data ?? const {})).label;
    await Clipboard.setData(
      ClipboardData(
        text:
            'หน่วยงานที่ยังไม่บันทึกหนี้ งวด $label (${rows.length} หน่วยงาน)\n'
            '${rows.map((r) => '${r['div']} ${r['divname'] ?? ''}'.trim()).join('\n')}',
      ),
    );
    if (!mounted) return;
    context.showSuccessSnackBar('คัดลอกแล้ว ${rows.length} หน่วยงาน');
  }

  void _openDiv(Map<String, dynamic> r) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DebtEntryScreen(
          apiService: widget.apiService,
          initialDiv: '${r['div']}',
          initialPeriod: _past,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // หน้าจอ
  // ---------------------------------------------------------------------------

  Widget _summaryCard() {
    final s = _data?['summary'] is Map
        ? Map<String, dynamic>.from(_data!['summary'] as Map)
        : const <String, dynamic>{};
    final divs = intOf(s['divs']);
    final edited = intOf(s['edited']);
    return StepCard(
      key: DivStatusScreen.summaryKey,
      icon: Icons.summarize_outlined,
      title: 'สรุปการบันทึกหนี้ของงวด',
      // prepared_at มีเฉพาะงวดที่เตรียมด้วยระบบใหม่ครั้งล่าสุด งวดอื่นเป็น null (นับการแก้ทั้งงวด)
      subtitle: _data?['prepared_at'] == null
          ? null
          : 'นับการแก้ยอดหลังเตรียมงวดเมื่อ ${formatServerTime(_data!['prepared_at'])}',
      trailing: IconButton(
        key: DivStatusScreen.refreshKey,
        tooltip: 'โหลดใหม่',
        icon: const Icon(Icons.refresh),
        onPressed: _loading ? null : _load,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_audit && divs > 0) ...[
            Text(
              'บันทึกแล้ว ${countText(edited)} จาก ${countText(divs)} หน่วยงาน',
              style: screenText(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                key: DivStatusScreen.progressKey,
                value: divs == 0 ? 0 : edited / divs,
                minHeight: 10,
                backgroundColor: AppTheme.dividerColor,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
          FactRow('จำนวนหน่วยงาน', '${countText(divs)} หน่วยงาน'),
          if (_audit) ...[
            FactRow(
              DivStatusScreen.editedLabel,
              '${countText(edited)} หน่วยงาน',
              color: AppTheme.successColor,
            ),
            FactRow(
              DivStatusScreen.notEditedLabel,
              '${countText(s['not_edited'])} หน่วยงาน',
              color: intOf(s['not_edited']) > 0 ? AppTheme.warningColor : null,
            ),
          ],
          FactRow('จำนวนคน', '${countText(s['rows'])} คน'),
          FactRow(
            'จำนวนคนที่มียอดหนี้',
            '${countText(s['rows_with_debt'])} คน',
          ),
          if (_audit) ...[
            const SizedBox(height: 6),
            Text(
              DivStatusScreen.criteriaText,
              key: DivStatusScreen.criteriaKey,
              style: screenText(size: 13, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_audit)
            for (final f in DivStatusScreen.statusFilters.entries)
              ChoiceChip(
                key: DivStatusScreen.statusFilterKey(f.key),
                label: Text(f.value, style: screenText(size: 13.5)),
                selected: _status == f.key,
                onSelected: (_) => setState(() {
                  _status = f.key;
                  _page = 0;
                }),
              ),
          for (final f in DivStatusScreen.regionFilters.entries)
            ChoiceChip(
              key: DivStatusScreen.regionFilterKey(f.key),
              label: Text(f.value, style: screenText(size: 13.5)),
              selected: _region == f.key,
              onSelected: (_) => setState(() {
                _region = f.key;
                _page = 0;
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: TextField(
              key: DivStatusScreen.searchKey,
              controller: _search,
              style: screenText(size: 14.5),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: 'ค้นรหัสหรือชื่อหน่วยงาน',
                hintStyle: screenText(
                  size: 14.5,
                  color: AppTheme.textSecondary,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() => _page = 0),
            ),
          ),
          if (_audit)
            SheetButton(
              DivStatusScreen.copyLabel,
              key: DivStatusScreen.copyKey,
              icon: Icons.copy,
              color: AppTheme.primaryColor,
              onPressed: _copyNotEdited,
            ),
        ],
      ),
    ],
  );

  Widget _head(String text, String key, {int flex = 2, bool right = false}) =>
      Expanded(
        flex: flex,
        child: SheetHead(
          text,
          align: right ? TextAlign.right : TextAlign.left,
          onTap: () => _sortBy(key),
          sorted: _sort == key ? _descending : null,
        ),
      );

  Widget _cell(String text, {int flex = 2, bool right = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: screenText(size: 14.5),
      ),
    ),
  );

  Widget _row(Map<String, dynamic> r) {
    final div = '${r['div'] ?? ''}';
    final edited = r['edited'] == true;
    return InkWell(
      key: DivStatusScreen.rowKey(div),
      // แถว "ไม่ระบุหน่วยงาน" ไม่มีหน้าบันทึกข้อมูลให้ไป
      onTap: div.isEmpty ? null : () => _openDiv(r),
      child: Row(
        children: [
          _cell(div.isEmpty ? '-' : div),
          _cell(_nameOf(r), flex: 6),
          _cell(countText(r['g']), right: true),
          _cell(countText(r['e']), right: true),
          _cell(countText(r['rows_with_debt']), right: true),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                // ไม่มีประวัติการแก้ไข: ไม่บอกสถานะ (ไม่ขึ้น "ยังไม่บันทึก" ให้เข้าใจผิด)
                child: !_audit
                    ? Text(
                        '-',
                        style: screenText(color: AppTheme.textSecondary),
                      )
                    : StatusChip(
                        edited
                            ? DivStatusScreen.editedLabel
                            : DivStatusScreen.notEditedLabel,
                        edited ? AppTheme.successColor : AppTheme.warningColor,
                        key: DivStatusScreen.statusKey(div),
                      ),
              ),
            ),
          ),
          _cell(_audit ? countText(r['edits']) : '-', right: true),
          _cell(
            r['last_edit_at'] == null
                ? '-'
                : formatServerTime(r['last_edit_at']),
            flex: 5,
          ),
          _cell('${r['last_edit_by'] ?? '-'}'),
          SizedBox(
            width: 28,
            child: div.isEmpty
                ? null
                : const Icon(Icons.chevron_right, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _table() {
    final all = _filtered;
    final pages = all.isEmpty ? 1 : (all.length / _pageSize).ceil();
    final page = _page >= pages ? pages - 1 : _page;
    final rows = all.skip(page * _pageSize).take(_pageSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetScroll(
          minWidth: 1020,
          child: SheetCard(
            emptyText: _items.isEmpty
                ? DivStatusScreen.noRowsText
                : DivStatusScreen.emptyText,
            header: Row(
              children: [
                _head('รหัส', 'div'),
                _head('ชื่อหน่วยงาน', 'divname', flex: 6),
                _head('ข้าราชการ', 'g', right: true),
                _head('ลูกจ้างประจำ', 'e', right: true),
                _head('มียอดหนี้', 'rows_with_debt', right: true),
                _head('สถานะ', 'edited', flex: 3),
                _head('แก้ (ครั้ง)', 'edits', right: true),
                _head('แก้ล่าสุดเมื่อ', 'last_edit_at', flex: 5),
                _head('โดยบัญชี', 'last_edit_by'),
                const SizedBox(width: 28),
              ],
            ),
            rows: [for (final r in rows) _row(r)],
          ),
        ),
        const SizedBox(height: 10),
        AppPagination(
          currentPage: page,
          totalPages: pages,
          pageSize: _pageSize,
          summary:
              'แสดง ${countText(all.length)} จาก ${countText(_items.length)} หน่วยงาน',
          onPageChanged: (p) => setState(() => _page = p),
          onPageSizeChanged: (s) => setState(() {
            _pageSize = s;
            _page = 0;
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkPage(
      group: DivStatusScreen.groupTitle,
      maxWidth: 1180,
      children: [
        const ScreenHeader(
          icon: DivStatusScreen.menuIcon,
          title: DivStatusScreen.menuTitle,
          subtitle:
              'ดูว่าหน่วยงานใดบันทึกหนี้ของงวดแล้ว เพื่อตามหน่วยงานที่ยังไม่บันทึก',
          bullets: [
            '"บันทึกแล้ว" = มีการแก้ยอดหนี้ของหน่วยงานนั้นในงวดอย่างน้อยหนึ่งครั้ง (เกณฑ์เดียว ไม่มีการกดยืนยันว่าตรวจแล้ว)',
            'กดที่แถวเพื่อไปหน้าบันทึกข้อมูลของหน่วยงานนั้น',
          ],
        ),
        const SizedBox(height: 14),
        PeriodPicker(
          past: _past,
          enabled: !_loading,
          onChanged: (p) {
            setState(() => _past = p);
            _load();
          },
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          NoticeBar(
            type: NoticeType.error,
            text: _error!,
            action: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('ลองใหม่', style: screenText(size: 14)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_unavailable) ...[
          NoticeBar(
            key: DivStatusScreen.unavailableKey,
            type: NoticeType.info,
            title: 'ยังใช้ไม่ได้',
            text: DivStatusScreen.unavailableText,
            action: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('ลองใหม่', style: screenText(size: 14)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_data != null) ...[
          if (_data!['period_ready'] == false) ...[
            NoticeBar(
              key: DivStatusScreen.notReadyKey,
              type: NoticeType.warning,
              title: 'งวดยังไม่พร้อม',
              text: DivStatusScreen.notReadyText,
              action: TextButton.icon(
                key: DivStatusScreen.goPrepareKey,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PreparePeriodScreen(apiService: widget.apiService),
                  ),
                ),
                icon: const Icon(Icons.playlist_add_check, size: 18),
                label: Text(
                  DivStatusScreen.goPrepareLabel,
                  style: screenText(size: 14, color: AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!_audit) ...[
            const NoticeBar(
              key: DivStatusScreen.noAuditKey,
              type: NoticeType.warning,
              text: DivStatusScreen.noAuditText,
            ),
            const SizedBox(height: 12),
          ],
          _summaryCard(),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 12),
          _table(),
        ],
      ],
    );
  }
}
