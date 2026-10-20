import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../services/api_service.dart';
import '../services/debt_api.dart';
import '../utils/dialog.dart';
import '../utils/money.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import 'account_form.dart';
import 'screen_parts.dart';
import 'sheet_table.dart';

/// หนึ่งบัญชีเงินกู้ในตาราง — แก้ไขได้ในแถว [id] ว่าง = แถวใหม่ที่ยังไม่ได้บันทึก
class LoanLine {
  final String id;
  String account;
  String flg;
  String year;
  String seq;
  String subseq;

  /// ข้อความจำนวนเงินตามที่พิมพ์
  String amount;
  bool selected = false;

  /// ค่าตอนโหลด ใช้หาช่องที่ถูกแก้ (แถวใหม่ = ว่าง)
  final Map<String, String> original;

  /// ลำดับภายในหน้าจอ ใช้เป็นคีย์ของช่องกรอก
  final int uid;
  static int _next = 0;

  LoanLine({
    this.id = '',
    this.account = '',
    this.flg = '',
    this.year = '',
    this.seq = '',
    this.subseq = '',
    this.amount = '',
    Map<String, String>? original,
  }) : original = original ?? const {},
       uid = _next++;

  factory LoanLine.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k]?.toString() ?? '';
    final line = LoanLine(
      id: s('id'),
      account: s('ghb_acc'),
      flg: s('flg'),
      year: s('year'),
      seq: s('seq'),
      subseq: s('subseq'),
      amount: Money.input(Money.fromJson(j['amt'])),
    );
    return LoanLine(
      id: line.id,
      account: line.account,
      flg: line.flg,
      year: line.year,
      seq: line.seq,
      subseq: line.subseq,
      amount: line.amount,
      original: line.values,
    );
  }

  /// ค่าปัจจุบันตามชื่อช่องของ backend (จำนวนเงินจัดรูปแล้ว อ่านไม่ได้ = ตามที่พิมพ์)
  Map<String, String> get values {
    final amt = Money.parse(amount);
    return {
      'ghb_acc': account.trim(),
      'flg': flg,
      'year': year.trim(),
      'seq': seq.trim(),
      'subseq': subseq.trim(),
      'amt': amt == null ? amount : Money.toJson(amt),
    };
  }

  Map<String, String> get changes => {
    for (final e in values.entries)
      if (e.value != (original[e.key] ?? '')) e.key: e.value,
  };

  bool get dirty => id.isEmpty || changes.isNotEmpty;
}

/// หนี้เดือนของธนาคารหนึ่งที่ยอดรวมเลขบัญชีต้องเท่ากัน (ใช้ตอนเปิดจากหน้าตรวจยอดเงินกู้)
class LoanTarget {
  final String bankName;

  /// โครงการ (flg) ที่นับเป็นบัญชีของธนาคารนี้
  final List<String> flags;

  /// หนี้รายเดือนของรหัสธนาคารนี้ (สตางค์)
  final int debt;

  const LoanTarget({
    required this.bankName,
    required this.flags,
    required this.debt,
  });
}

/// ตารางเลขที่บัญชีเงินกู้ของบุคคลหนึ่งคน — โหลด แก้ในแถว และบันทึกทั้งชุด
///
/// ใช้ในหน้า "เลขที่บัญชีเงินกู้" (ค้นคนก่อน) และหน้าต่าง [LoanEditorDialog] ที่เปิดจากหน้าตรวจยอดเงินกู้
/// `POST /api/loans/find` → ตาราง (เลขที่บัญชี โครงการ ปี ลำดับ ลำดับย่อย จำนวนเงิน)
/// "บันทึก": ส่งทุกบัญชีของคนนั้นในคำขอเดียว (`PUT /api/loans/set`) ผิดรายการเดียว = ไม่บันทึกอะไรเลย แล้วโหลดใหม่
/// โครงการ (`flg`): 1 = ธอส., 2 = ธอส. โครงการ 2, 3 = ธอส. โครงการ 3, 5 = ออมสิน, 6 = กรุงไทย — **ไม่มี 4 (ยกเลิกแล้ว)**
///
/// มีการแก้ไขค้างอยู่แล้วจะออกจากหน้า/ปิดหน้าต่าง ถามยืนยันก่อนทิ้ง
class LoanEditor extends StatefulWidget {
  final ApiService apiService;
  final String idcard;

  /// หนี้เดือนที่ต้องเทียบ แสดงยอดรวมของบัญชีธนาคารนั้นในตารางให้เห็นขณะแก้ (ว่าง = ไม่แสดง)
  final List<LoanTarget> targets;

  /// เรียกหลังบันทึกสำเร็จ
  final VoidCallback? onSaved;

  /// แจ้งเมื่อเริ่ม/จบการโหลดหรือบันทึก
  final ValueChanged<bool>? onBusyChanged;

  const LoanEditor({
    super.key,
    required this.apiService,
    required this.idcard,
    this.targets = const [],
    this.onSaved,
    this.onBusyChanged,
  });

  static const Key saveKey = ValueKey('loan-save');
  static const Key dirtyKey = ValueKey('loan-dirty');
  static Key targetKey(String bankName) => ValueKey('loan-target-$bankName');

  /// คีย์ของช่อง [field] ในแถวลำดับที่ [index] (นับจาก 0) และช่องติ๊กของแถว
  static Key cellKey(int index, String field) => ValueKey('loan-$index-$field');
  static Key checkKey(int index) => ValueKey('loan-check-$index');

  /// ป้ายของโครงการเงินกู้ (ค่า flg -> ข้อความ) ไม่มี 4
  static const Map<String, String> flgNames = {
    '1': 'ธอส.',
    '2': 'ธอส. โครงการ 2',
    '3': 'ธอส. โครงการ 3',
    '5': 'ออมสิน',
    '6': 'กรุงไทย',
  };

  static const String dirtyText = 'มีการแก้ไขที่ยังไม่ได้บันทึก';
  static const String emptyText =
      'ยังไม่มีเลขที่บัญชีเงินกู้ กดปุ่มเพิ่มเพื่อสร้างรายการ';
  static const String savedMessage = 'บันทึกเลขที่บัญชีเงินกู้แล้ว';
  static const String discardQuestion =
      'ยังมีการแก้ไขที่ยังไม่ได้บันทึก ต้องการทิ้งการแก้ไขหรือไม่?';

  @override
  State<LoanEditor> createState() => LoanEditorState();
}

class LoanEditorState extends State<LoanEditor> {
  PersonInfo? _person;
  String _empType = '';
  List<LoanLine> _lines = [];
  List<String> _originalIds = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// ผู้ใช้ยืนยันทิ้งการแก้ไขแล้ว ปล่อยให้ออกได้
  bool _discarded = false;

  bool get dirty =>
      !_discarded &&
      (_lines.any((l) => l.dirty) ||
          _originalIds.any((id) => !_lines.any((l) => l.id == id)));

  bool get busy => _loading || _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// ถามก่อนทิ้งการแก้ไขที่ยังไม่ได้บันทึก (ไม่มี = ผ่านเลย)
  Future<bool> confirmDiscard() async {
    if (!dirty) return true;
    final ok = await AppDialog.showConfirm(
      context,
      LoanEditor.discardQuestion,
      confirmText: 'ทิ้งการแก้ไข',
    );
    return ok == true;
  }

  void _setBusy(void Function() change) {
    final before = busy;
    setState(change);
    if (before != busy) widget.onBusyChanged?.call(busy);
  }

  Future<void> _load() async {
    _setBusy(() {
      _loading = true;
      _error = null;
    });
    try {
      final person = await widget.apiService.lookupPerson(widget.idcard);
      final items = await widget.apiService.findLoans(widget.idcard);
      if (!mounted) return;
      _setBusy(() {
        _person = person;
        _lines = [for (final j in items) LoanLine.fromJson(j)];
        _originalIds = [for (final l in _lines) l.id];
        final existing = items.isEmpty
            ? ''
            : '${items.first['emp_type'] ?? ''}';
        _empType = existing.isNotEmpty ? existing : person.type;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _setBusy(() {
        _loading = false;
        _person = null;
        _lines = [];
        _originalIds = [];
        _error = e.toString();
      });
    }
  }

  void _add() {
    final maxSeq = _lines.fold<int>(
      0,
      (m, l) => (int.tryParse(l.seq) ?? 0) > m ? int.parse(l.seq) : m,
    );
    setState(() {
      _lines.add(
        LoanLine(
          seq: '${maxSeq + 1}',
          subseq: '1',
          year: '${DateTime.now().year + 543}',
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

  /// เอาออกจากหน้าจอ บัญชีที่เคยบันทึกไว้จะถูกลบจริงตอนกดบันทึก
  void _deleteSelected() {
    final count = _lines.where((l) => l.selected).length;
    if (count == 0) {
      context.showInfoSnackBar('ยังไม่ได้เลือกรายการที่จะลบ');
      return;
    }
    setState(() => _lines.removeWhere((l) => l.selected));
    context.showInfoSnackBar(
      'ลบ $count รายการออกจากหน้าจอแล้ว กดบันทึกเพื่อยืนยัน',
    );
  }

  /// ข้อความแจ้งเมื่อยังบันทึกไม่ได้ (null = ผ่าน)
  String? _validate() {
    if (_empType.isEmpty) return 'กรุณาเลือกประเภทบุคลากร';
    final seen = <String, int>{};
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final no = i + 1;
      if (!RegExp(r'^\d{10,15}$').hasMatch(l.account.trim())) {
        return 'แถวที่ $no เลขที่บัญชีต้องเป็นตัวเลข 10-15 หลัก';
      }
      if (!LoanEditor.flgNames.containsKey(l.flg)) {
        return 'แถวที่ $no ยังไม่ได้เลือกโครงการ';
      }
      if (l.year.trim().isNotEmpty &&
          !RegExp(r'^25\d{2}$').hasMatch(l.year.trim())) {
        return 'แถวที่ $no ปีต้องเป็นปี พ.ศ. 4 หลัก';
      }
      if (Money.parse(l.amount) == null) {
        return 'แถวที่ $no ${Money.invalidMessage}';
      }
      final acc = l.account.trim();
      if (seen.containsKey(acc)) {
        return 'เลขที่บัญชี $acc ซ้ำกัน (แถวที่ ${seen[acc]! + 1} และ $no)';
      }
      seen[acc] = i;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    _setBusy(() {
      _saving = true;
      _error = null;
    });
    try {
      // บันทึกทั้งชุดในคำขอเดียว: backend ตรวจทุกรายการก่อน ไม่ผ่าน = ไม่บันทึกอะไรเลย
      await widget.apiService.setLoans(widget.idcard, [
        for (final l in _lines)
          {
            'emp_type': _empType,
            for (final e in l.values.entries)
              if (e.value.isNotEmpty) e.key: e.value,
          },
      ]);
      if (!mounted) return;
      _setBusy(() => _saving = false);
      context.showSuccessSnackBar(LoanEditor.savedMessage);
      widget.onSaved?.call();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = e.code == ErrorCodes.duplicate
          ? '${e.message}\nบุคคลนี้มีเลขที่บัญชีนี้อยู่แล้ว'
          : e.message;
      // ไม่มีอะไรถูกบันทึก: คงค่าที่พิมพ์ไว้ให้แก้ต่อ
      _setBusy(() {
        _saving = false;
        _error = 'บันทึกไม่สำเร็จ (ยังไม่มีรายการใดถูกบันทึก): $message';
      });
    } catch (e) {
      if (!mounted) return;
      _setBusy(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // หน้าจอ
  // ---------------------------------------------------------------------------

  Widget _text(
    int index,
    String field,
    LoanLine line,
    String value,
    ValueChanged<String> onChanged, {
    int maxLength = 15,
    bool money = false,
  }) => Padding(
    key: LoanEditor.cellKey(index, field),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: TextFormField(
      key: ValueKey('loan-${line.uid}-$field'),
      initialValue: value,
      enabled: !_saving,
      textAlign: money ? TextAlign.right : TextAlign.left,
      keyboardType: money
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        money
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            : FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: screenText(size: 14.5),
      decoration: sheetInput(hint: money ? '0.00' : null),
      onChanged: (v) => setState(() => onChanged(v)),
    ),
  );

  Widget _row(int i) {
    final l = _lines[i];
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Checkbox(
            key: LoanEditor.checkKey(i),
            value: l.selected,
            onChanged: (v) => setState(() => l.selected = v ?? false),
          ),
        ),
        Expanded(
          flex: 5,
          child: _text(i, 'ghb_acc', l, l.account, (v) => l.account = v),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            key: LoanEditor.cellKey(i, 'flg'),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonFormField<String>(
              key: ValueKey('loan-${l.uid}-flg'),
              initialValue: LoanEditor.flgNames.containsKey(l.flg)
                  ? l.flg
                  : null,
              isExpanded: true,
              decoration: sheetInput(),
              hint: Text('เลือกโครงการ', style: screenText(size: 14)),
              items: [
                for (final e in LoanEditor.flgNames.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      overflow: TextOverflow.ellipsis,
                      style: screenText(size: 14.5),
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => l.flg = v ?? ''),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _text(i, 'year', l, l.year, (v) => l.year = v, maxLength: 4),
        ),
        Expanded(
          flex: 2,
          child: _text(i, 'seq', l, l.seq, (v) => l.seq = v, maxLength: 4),
        ),
        Expanded(
          flex: 2,
          child: _text(
            i,
            'subseq',
            l,
            l.subseq,
            (v) => l.subseq = v,
            maxLength: 4,
          ),
        ),
        Expanded(
          flex: 3,
          child: _text(
            i,
            'amt',
            l,
            l.amount,
            (v) => l.amount = v,
            maxLength: 13,
            money: true,
          ),
        ),
      ],
    );
  }

  /// ยอดรวมในตารางของบัญชีธนาคารนั้นเทียบหนี้เดือน (นับตามค่าที่พิมพ์ ช่องที่อ่านไม่ได้ = 0)
  Widget _targetBar(LoanTarget t) {
    final total = _lines
        .where((l) => t.flags.contains(l.flg))
        .fold<int>(0, (s, l) => s + (Money.parse(l.amount) ?? 0));
    final diff = t.debt - total;
    final same = diff == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NoticeBar(
        key: LoanEditor.targetKey(t.bankName),
        type: same ? NoticeType.success : NoticeType.warning,
        title: t.bankName,
        text:
            'หนี้เดือน ${Money.format(t.debt)} · ยอดรวมบัญชีธนาคารนี้ในตาราง ${Money.format(total)}'
            '${same ? ' — ตรงกันแล้ว' : ' — ${diff > 0 ? 'ขาด' : 'เกิน'} ${Money.format(diff.abs())}'}',
      ),
    );
  }

  Widget _table() {
    final person = _person;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepCard(
          icon: Icons.person_outline,
          title: person != null && person.fullName.isNotEmpty
              ? person.fullName
              : IdCard.masked(widget.idcard),
          subtitle: 'เลขประจำตัวประชาชน ${IdCard.masked(widget.idcard)}',
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('ประเภทบุคลากร', style: screenText(size: 14)),
              for (final t in EmpType.names.entries)
                ChoiceChip(
                  key: ValueKey('loan-type-${t.key}'),
                  label: Text(t.value, style: screenText(size: 13.5)),
                  selected: _empType == t.key,
                  // บัญชีที่บันทึกแล้วมีประเภทติดอยู่ เปลี่ยนได้เฉพาะตอนยังไม่มีรายการเดิม
                  onSelected: _saving || _originalIds.isNotEmpty
                      ? null
                      : (on) => setState(() => _empType = on ? t.key : ''),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final t in widget.targets) _targetBar(t),
        SheetScroll(
          minWidth: 860,
          child: SheetCard(
            emptyText: LoanEditor.emptyText,
            header: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: SheetHeaderCheckbox(
                    selected: _lines.where((l) => l.selected).length,
                    total: _lines.length,
                    onToggle: _selectAll,
                  ),
                ),
                const Expanded(flex: 5, child: SheetHead('เลขที่บัญชี')),
                const Expanded(flex: 5, child: SheetHead('โครงการ')),
                const Expanded(flex: 2, child: SheetHead('ปี พ.ศ.')),
                const Expanded(flex: 2, child: SheetHead('ลำดับ')),
                const Expanded(flex: 2, child: SheetHead('ลำดับย่อย')),
                const Expanded(
                  flex: 3,
                  child: SheetHead('จำนวนเงิน', align: TextAlign.right),
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
            if (dirty)
              Text(
                LoanEditor.dirtyText,
                key: LoanEditor.dirtyKey,
                style: screenText(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: AppTheme.warningColor,
                ),
              ),
            PrimaryActionButton(
              key: LoanEditor.saveKey,
              label: 'บันทึก',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: dirty ? _save : null,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await confirmDiscard() && mounted) {
          setState(() => _discarded = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => nav.maybePop());
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          else if (_person != null)
            _table(),
        ],
      ),
    );
  }
}

/// หน้าต่างแก้เลขที่บัญชีเงินกู้ของคนหนึ่ง เปิดทับหน้าตรวจยอดเงินกู้ (ไม่ต้องไปหน้าเลขที่บัญชีเงินกู้)
///
/// [show] คืน true เมื่อบันทึกไปอย่างน้อยหนึ่งครั้ง (หน้าที่เปิดควรตรวจยอดใหม่)
class LoanEditorDialog extends StatelessWidget {
  final ApiService apiService;
  final String idcard;
  final String name;
  final List<LoanTarget> targets;
  final VoidCallback? onSaved;

  const LoanEditorDialog({
    super.key,
    required this.apiService,
    required this.idcard,
    required this.name,
    this.targets = const [],
    this.onSaved,
  });

  static const Key closeKey = ValueKey('loan-dialog-close');
  static const String title = 'เลขที่บัญชีเงินกู้';

  static Future<bool> show(
    BuildContext context, {
    required ApiService apiService,
    required String idcard,
    required String name,
    List<LoanTarget> targets = const [],
  }) async {
    var saved = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LoanEditorDialog(
        apiService: apiService,
        idcard: idcard,
        name: name,
        targets: targets,
        onSaved: () => saved = true,
      ),
    );
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    return AccountDialogShell(
      icon: Icons.credit_score_outlined,
      title: title,
      subtitle: name,
      maxWidth: 1000,
      // maybePop ผ่าน PopScope ของตาราง: มีการแก้ไขค้างจะถามก่อนปิด
      onClose: () => Navigator.of(context).maybePop(),
      closeKey: closeKey,
      child: LoanEditor(
        apiService: apiService,
        idcard: idcard,
        targets: targets,
        onSaved: onSaved,
      ),
    );
  }
}
