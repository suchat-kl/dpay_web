import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/master_data.dart';
import '../services/api_service.dart';
import '../services/debt_api.dart';
import '../utils/dialog.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_pagination.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';

/// หนึ่งแถวของตารางข้อมูลหลัก — แก้ไขได้ในแถว [id] ว่าง = แถวใหม่ที่ยังไม่ได้บันทึก
class MasterLine {
  String id;

  /// ค่าตามที่พิมพ์ (ชื่อช่องของ backend -> ค่า)
  final Map<String, String> values;

  /// ค่าตอนโหลด/บันทึกล่าสุด ใช้หาช่องที่ถูกแก้ (แถวใหม่ = ว่าง)
  Map<String, String> original;
  bool selected = false;

  /// ข้อความผิดพลาดของแถว (ตรวจในหน้าจอหรือ backend ตอบกลับ) และช่องที่ผิด
  String? error;
  Set<String> badFields = const {};

  /// ลำดับภายในหน้าจอ ใช้เป็นคีย์ของช่องกรอก
  final int uid;
  static int _next = 0;

  MasterLine({this.id = '', Map<String, String>? values})
    : values = {...?values},
      original = id.isEmpty ? const {} : {...?values},
      uid = _next++;

  String value(String key) => (values[key] ?? '').trim();

  /// ช่องที่ต่างจากค่าเดิม
  Map<String, String> changes(MasterResource resource) => {
    for (final f in resource.fields)
      if (value(f.key) != (original[f.key] ?? '')) f.key: value(f.key),
  };

  bool isDirty(MasterResource resource) =>
      id.isEmpty || changes(resource).isNotEmpty;
}

/// บันทึกรายการหลัก — ตารางเดียวใช้ได้ทุกชุดข้อมูล (ธนาคาร สาขา รหัสหนี้ หน่วยงาน) เฉพาะ ACCOUNT
///
/// **แก้ไขในแถวของตาราง** (แนวเดียวกับใบแจ้งค่าอาหารของ HTC): ทุกแถวเป็นช่องกรอก ท้ายตารางมี
/// "ลบที่เลือก" "เลือกทั้งหมด" "เพิ่ม" (เพิ่มแถวว่างต่อท้ายหน้าปัจจุบัน) และปุ่ม "บันทึก"
/// ที่ส่งเฉพาะแถวที่แก้/เพิ่ม — แถวที่ backend ปฏิเสธ (`DUPLICATE` / `IN_USE` / `BAD_REQUEST`)
/// แสดงข้อความใต้แถวนั้นและคงค่าที่พิมพ์ไว้ แถวที่บันทึกผ่านแล้วไม่ถูกส่งซ้ำ
/// เปลี่ยนหน้า/ค้นหา/เรียง/เปลี่ยนธนาคารขณะมีการแก้ไขค้าง จะถามก่อนทิ้ง
class MasterScreen extends StatefulWidget {
  final ApiService apiService;
  final MasterResource resource;

  const MasterScreen({
    super.key,
    required this.apiService,
    required this.resource,
  });

  static const String groupTitle = 'บันทึกรายการหลัก';

  static const Key bankFilterKey = ValueKey('master-bank');
  static const Key searchKey = ValueKey('master-search');
  static const Key saveKey = ValueKey('master-save');
  static const Key dirtyKey = ValueKey('master-dirty');

  /// คีย์ของช่อง [field] ช่องติ๊ก และข้อความผิดพลาด ของแถวลำดับที่ [index] (นับจาก 0)
  static Key cellKey(int index, String field) =>
      ValueKey('master-$index-$field');
  static Key checkKey(int index) => ValueKey('master-check-$index');
  static Key errorKey(int index) => ValueKey('master-error-$index');

  static const String dirtyText = 'มีการแก้ไขที่ยังไม่ได้บันทึก';
  static const String discardQuestion =
      'ยังมีการแก้ไขที่ยังไม่ได้บันทึก ต้องการทิ้งการแก้ไขหรือไม่?';
  static const String pickBankText = 'กรุณาเลือกธนาคารก่อน';
  static const String nothingSelected = 'ยังไม่ได้เลือกรายการที่จะลบ';
  static const String savedMessage = 'บันทึกข้อมูลแล้ว';
  static const String fixRowsMessage =
      'ยังบันทึกไม่ได้ กรุณาแก้แถวที่มีข้อความสีแดง';
  static const String duplicateInPage = 'รหัสซ้ำกับแถวอื่นในหน้านี้';
  static const String duplicateHint = 'รหัสนี้มีอยู่แล้ว';
  static const String inUseHint =
      'มีข้อมูลอื่นใช้รายการนี้อยู่ จึงแก้รหัสหรือลบไม่ได้';
  static const String cancelledCodeMessage =
      'รหัสหนี้ ${MasterResource.cancelledDebtCode} ยกเลิกแล้ว เพิ่มไม่ได้';

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<MasterLine> _lines = [];
  List<Map<String, String>> _banks = [];
  String? _bankCode;
  String _keyword = '';
  String? _sort;
  bool _descending = false;
  int _page = 0;
  int _pageSize = 10;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  MasterResource get _res => widget.resource;
  bool get _dirty => _lines.any((l) => l.isDirty(_res));
  bool get _waitingBank => _res.needsBank && _bankCode == null;
  bool get _busy => _loading || _saving;

  /// ช่องที่ประกอบเป็นรหัสของรายการ (ช่องแรกของตาราง)
  String get _codeField => _res.fields.first.key;

  @override
  void initState() {
    super.initState();
    if (_res.needsBank) {
      _loadBanks();
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() => _loading = true);
    try {
      final banks = await widget.apiService.allMaster(
        MasterResource.banks.path,
      );
      if (!mounted) return;
      setState(() {
        _banks = banks;
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

  Future<void> _load() async {
    if (_waitingBank) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await widget.apiService.listMaster(
        _res.path,
        keyword: _keyword,
        page: _page,
        size: _pageSize,
        sort: _sort,
        descending: _descending,
        filters: {if (_res.needsBank) 'bank_code': _bankCode!},
      );
      if (!mounted) return;
      setState(() {
        _lines = [
          for (final e in body['items'] as List? ?? const [])
            if (e is Map)
              MasterLine(
                id: '${e['id'] ?? ''}',
                values: {
                  for (final f in _res.fields)
                    f.key: e[f.key] == null ? '' : '${e[f.key]}',
                },
              ),
        ];
        _totalPages = (body['totalPages'] as num?)?.toInt() ?? 1;
        _totalItems = (body['totalItems'] as num?)?.toInt() ?? _lines.length;
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

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await AppDialog.showConfirm(
      context,
      MasterScreen.discardQuestion,
      confirmText: 'ทิ้งการแก้ไข',
    );
    return ok == true;
  }

  /// เปลี่ยนมุมมอง (หน้า ค้นหา เรียง ธนาคาร) — ถามก่อนถ้ามีการแก้ไขค้าง คืน false = ไม่เปลี่ยน
  Future<bool> _changeView(VoidCallback apply) async {
    if (_busy) return false;
    if (!await _confirmDiscard() || !mounted) return false;
    setState(() {
      _lines = [];
      apply();
    });
    await _load();
    return true;
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    _debounce?.cancel();
    final text = _search.text.trim();
    if (text == _keyword) return;
    final changed = await _changeView(() {
      _keyword = text;
      _page = 0;
    });
    // ไม่ทิ้งการแก้ไข: คืนคำค้นเดิมให้ตรงกับตารางที่เห็น
    if (!changed && mounted) _search.text = _keyword;
  }

  void _sortBy(String key) => _changeView(() {
    if (_sort == key) {
      _descending = !_descending;
    } else {
      _sort = key;
      _descending = false;
    }
    _page = 0;
  });

  void _add() {
    setState(() {
      _lines.add(
        MasterLine(
          values: {
            // ช่องตัวเลือก: ตั้งค่าตัวเลือกสุดท้าย (ไม่ใช่ส่วนกลาง) ไว้ก่อน
            for (final f in _res.fields)
              if (f.choices != null) f.key: f.choices!.keys.last,
          },
        ),
      );
    });
  }

  void _selectAll() {
    final all = _lines.isNotEmpty && _lines.every((l) => l.selected);
    setState(() {
      for (final l in _lines) {
        l.selected = !all;
      }
    });
  }

  String _hinted(ApiException e) => switch (e.code) {
    ErrorCodes.duplicate => '${e.message} — ${MasterScreen.duplicateHint}',
    ErrorCodes.inUse => '${e.message} — ${MasterScreen.inUseHint}',
    _ => e.message,
  };

  /// ลบแถวที่เลือก: แถวใหม่ที่ยังไม่บันทึกเอาออกจากหน้าจอ แถวที่บันทึกแล้วลบทั้งชุดในคำขอเดียว
  /// แถวที่ลบไม่ได้ (เช่น `IN_USE`) ยังอยู่และแสดงเหตุผลใต้แถว
  Future<void> _deleteSelected() async {
    final picked = _lines.where((l) => l.selected).toList();
    if (picked.isEmpty) {
      context.showInfoSnackBar(MasterScreen.nothingSelected);
      return;
    }
    final ok = await AppDialog.showConfirm(
      context,
      'ต้องการลบ${_res.itemName} ${picked.length} รายการที่เลือกหรือไม่?',
      confirmText: 'ลบ',
    );
    if (ok != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    var deleted = 0;
    var failed = 0;
    // แถวใหม่ที่ยังไม่บันทึก: เอาออกจากหน้าจอเฉย ๆ
    for (final l in picked.where((l) => l.id.isEmpty)) {
      _lines.remove(l);
      deleted++;
    }
    final saved = picked.where((l) => l.id.isNotEmpty).toList();
    if (saved.isNotEmpty) {
      try {
        // ลบทั้งชุดในคำขอเดียว ผลรายรายการกลับมาใน results
        final results = await widget.apiService.deleteMasterMany(_res.path, [
          for (final l in saved) l.id,
        ]);
        final byId = {for (final r in results) '${r['id']}': r};
        for (final l in saved) {
          final r = byId[l.id];
          if (r != null && r['deleted'] == true) {
            _lines.remove(l);
            deleted++;
          } else {
            final hint = r?['code'] == ErrorCodes.inUse
                ? ' — ${MasterScreen.inUseHint}'
                : '';
            l.error = 'ลบไม่ได้: ${r?['message'] ?? 'ไม่ทราบผล'}$hint';
            l.badFields = const {};
            failed++;
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = e.toString();
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (failed == 0) {
      context.showSuccessSnackBar('ลบแล้ว $deleted รายการ');
    } else {
      setState(() => _error = 'ลบแล้ว $deleted รายการ ลบไม่ได้ $failed รายการ');
    }
    // ไม่มีการแก้ไขค้างและไม่มีแถวที่ต้องแจ้ง: โหลดใหม่ให้ตรงของจริง
    if (!_dirty && failed == 0) await _load();
  }

  /// ตรวจแถวที่แก้/เพิ่มทั้งหมด ใส่ข้อความไว้ที่แถว คืนจำนวนแถวที่ยังไม่ผ่าน
  int _validate() {
    var bad = 0;
    final codes = <String, int>{};
    for (final l in _lines) {
      final code = l.value(_codeField);
      if (code.isNotEmpty) codes[code] = (codes[code] ?? 0) + 1;
    }
    for (final l in _lines) {
      if (!l.isDirty(_res)) continue;
      final messages = <String>[];
      final fields = <String>{};
      for (final f in _res.fields) {
        final problem = f.validate(l.value(f.key));
        if (problem != null) {
          messages.add(problem);
          fields.add(f.key);
        }
      }
      final code = l.value(_codeField);
      if (_res.path == MasterResource.debtCodes.path &&
          code == MasterResource.cancelledDebtCode) {
        messages.add(MasterScreen.cancelledCodeMessage);
        fields.add(_codeField);
      }
      if ((codes[code] ?? 0) > 1) {
        messages.add(MasterScreen.duplicateInPage);
        fields.add(_codeField);
      }
      l.error = messages.isEmpty ? null : messages.join(' · ');
      l.badFields = fields;
      if (messages.isNotEmpty) bad++;
    }
    return bad;
  }

  /// บันทึกเฉพาะแถวที่แก้/เพิ่ม ทีละแถว — แถวที่ผ่านถือเป็นค่าเดิมทันที (ไม่ส่งซ้ำ)
  /// แถวที่ไม่ผ่านคงค่าที่พิมพ์ไว้พร้อมข้อความใต้แถว
  Future<void> _save() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final invalid = _validate();
    if (invalid > 0) {
      setState(() => _error = MasterScreen.fixRowsMessage);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = widget.apiService;
    var saved = 0;
    var failed = 0;
    for (final l in _lines.where((l) => l.isDirty(_res)).toList()) {
      try {
        final Map<String, dynamic> body;
        if (l.id.isEmpty) {
          body = await api.createMaster(_res.path, {
            if (_res.needsBank) 'bank_code': _bankCode!,
            for (final f in _res.fields)
              if (l.value(f.key).isNotEmpty) f.key: l.value(f.key),
          });
          final item = body['item'];
          l.id = item is Map ? '${item['id'] ?? ''}' : '';
        } else {
          await api.updateMaster(_res.path, l.id, l.changes(_res));
        }
        l.original = {for (final f in _res.fields) f.key: l.value(f.key)};
        l.error = null;
        l.badFields = const {};
        saved++;
      } on ApiException catch (e) {
        l.error = _hinted(e);
        l.badFields =
            e.code == ErrorCodes.duplicate || e.code == ErrorCodes.inUse
            ? {_codeField}
            : const {};
        failed++;
      } catch (e) {
        l.error = e.toString();
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (failed == 0) {
      context.showSuccessSnackBar(MasterScreen.savedMessage);
      await _load();
    } else {
      setState(
        () => _error =
            'บันทึกแล้ว $saved แถว บันทึกไม่สำเร็จ $failed แถว (ดูข้อความใต้แถว)',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // หน้าจอ
  // ---------------------------------------------------------------------------

  Widget _cell(int index, MasterLine line, MasterField f) {
    final bad = line.badFields.contains(f.key);
    final choices = f.choices;
    return Padding(
      key: MasterScreen.cellKey(index, f.key),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: choices != null
          ? DropdownButtonFormField<String>(
              key: ValueKey('master-${line.uid}-${f.key}'),
              initialValue: choices.containsKey(line.values[f.key])
                  ? line.values[f.key]
                  : null,
              isExpanded: true,
              decoration: sheetInput(error: bad),
              items: [
                for (final c in choices.entries)
                  DropdownMenuItem(
                    value: c.key,
                    child: Text(
                      c.value,
                      overflow: TextOverflow.ellipsis,
                      style: screenText(size: 14.5),
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => line.values[f.key] = v ?? ''),
            )
          : TextFormField(
              key: ValueKey('master-${line.uid}-${f.key}'),
              initialValue: line.values[f.key] ?? '',
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              keyboardType: f.digits
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: [
                if (f.digits) FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(f.maxLength),
              ],
              style: screenText(size: 14.5),
              decoration: sheetInput(
                hint: line.id.isEmpty ? f.label : null,
                error: bad,
              ),
              onChanged: (v) => setState(() => line.values[f.key] = v),
            ),
    );
  }

  Widget _row(int i) {
    final l = _lines[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                key: MasterScreen.checkKey(i),
                value: l.selected,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => l.selected = v ?? false),
              ),
            ),
            for (final f in _res.fields)
              Expanded(flex: f.flex, child: _cell(i, l, f)),
          ],
        ),
        if (l.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 2, 4, 4),
            child: Text(
              l.error!,
              key: MasterScreen.errorKey(i),
              style: screenText(size: 13, color: AppTheme.dangerColor),
            ),
          ),
      ],
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_res.needsBank)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'ธนาคาร',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: MasterScreen.bankFilterKey,
                  value: _bankCode,
                  isExpanded: true,
                  hint: Text('เลือกธนาคาร', style: screenText(size: 14.5)),
                  items: [
                    for (final b in _banks)
                      DropdownMenuItem(
                        value: b['bank_code'],
                        child: Text(
                          '${b['bank_code']} ${b['bank_name']}',
                          overflow: TextOverflow.ellipsis,
                          style: screenText(size: 14.5),
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) async {
                          if (v == null || v == _bankCode) return;
                          if (!await _confirmDiscard() || !mounted) return;
                          setState(() {
                            _lines = [];
                            _bankCode = v;
                            _page = 0;
                          });
                          await _load();
                        },
                ),
              ),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            key: MasterScreen.searchKey,
            controller: _search,
            enabled: !_waitingBank,
            style: screenText(size: 14.5),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              hintText: 'ค้นหา${_res.itemName}',
              hintStyle: screenText(size: 14.5, color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _runSearch(),
          ),
        ),
      ],
    );
  }

  Widget _table() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetScroll(
          minWidth: 180.0 * _res.fields.length < 640
              ? 640
              : 150.0 * _res.fields.length,
          child: SheetCard(
            emptyText: 'ไม่มีรายการ กดปุ่มเพิ่มเพื่อสร้างรายการ',
            header: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: SheetHeaderCheckbox(
                    selected: _lines.where((l) => l.selected).length,
                    total: _lines.length,
                    onToggle: _saving ? null : _selectAll,
                  ),
                ),
                for (final f in _res.fields)
                  Expanded(
                    flex: f.flex,
                    child: SheetHead(
                      f.required ? '${f.label} *' : f.label,
                      onTap: () => _sortBy(f.key),
                      sorted: _sort == f.key ? _descending : null,
                    ),
                  ),
              ],
            ),
            rows: [for (var i = 0; i < _lines.length; i++) _row(i)],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            SheetButton.delete(onPressed: _saving ? null : _deleteSelected),
            SheetButton.selectAll(
              onPressed: _lines.isEmpty || _saving ? null : _selectAll,
            ),
            SheetButton.add(onPressed: _saving ? null : _add),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_dirty)
              Text(
                MasterScreen.dirtyText,
                key: MasterScreen.dirtyKey,
                style: screenText(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: AppTheme.warningColor,
                ),
              ),
            PrimaryActionButton(
              key: MasterScreen.saveKey,
              label: 'บันทึก',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: _dirty ? _save : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppPagination(
          currentPage: _page,
          totalPages: _totalPages,
          pageSize: _pageSize,
          summary: 'ทั้งหมด $_totalItems รายการ',
          onPageChanged: (p) => _changeView(() => _page = p),
          onPageSizeChanged: (s) => _changeView(() {
            _pageSize = s;
            _page = 0;
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          setState(() => _lines = []);
          WidgetsBinding.instance.addPostFrameCallback((_) => nav.maybePop());
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: screenAppBar(context, MasterScreen.groupTitle),
        body: ListView(
          padding: EdgeInsets.all(isDesktop ? 24 : 12),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      icon: _res.icon,
                      title: _res.title,
                      subtitle:
                          'แก้ในตารางได้เลย แล้วกดบันทึก — ช่องที่มี * ต้องกรอก',
                    ),
                    const SizedBox(height: 16),
                    _filters(),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      NoticeBar(
                        type: NoticeType.error,
                        text: _error!,
                        onClose: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_waitingBank && !_loading)
                      const NoticeBar(
                        type: NoticeType.info,
                        text: MasterScreen.pickBankText,
                      )
                    else if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      _table(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
