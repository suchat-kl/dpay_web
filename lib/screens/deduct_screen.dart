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
import '../utils/util.dart';
import '../widgets/person_finder.dart';
import '../widgets/screen_parts.dart';
import '../widgets/thai_date_picker.dart';

/// บันทึกข้อมูลธนาคาร กบข/กสจ. สหกรณ์และภาษี — ทะเบียนหนึ่งรายการต่อคน (ACCOUNT)
///
/// ค้นคนด้วยเลขบัตรหรือชื่อ ([PersonFinder]) → `POST /api/persons/lookup` + `POST /api/deducts/find`
/// พบทะเบียนเดิม = แก้ไข (`PUT` ส่งเฉพาะช่องที่เปลี่ยน ข้อความว่าง = ล้างช่อง) ไม่พบ = สร้างใหม่ (`POST`)
/// ธนาคาร/สาขา/จังหวัดเลือกจากข้อมูลหลัก วันที่เลือกด้วยปฏิทิน พ.ศ. แล้วส่งเป็น `ddMMyyyy` ปี พ.ศ.
/// ค่าเริ่มต้นตาม backend: สถานะ = ใช้ (`rec_flg` 0) ประเภทบุคลากรตามผลค้นบุคคล
/// `duplicates` > 0 = ข้อมูลเดิมมีเลขบัตรนี้ซ้ำหลายรายการ แจ้งให้ฝ่ายบัญชีลบตัวที่เกิน
class DeductScreen extends StatefulWidget {
  final ApiService apiService;

  /// ตัวเลือกวันที่ ไม่ส่ง = ปฏิทิน พ.ศ. ของระบบ เทสต์ส่งตัวจำลองมาแทนได้
  final Future<DateTime?> Function(BuildContext context, DateTime? initial)?
  datePicker;

  const DeductScreen({super.key, required this.apiService, this.datePicker});

  static const String menuTitle = 'กบข/กสจ. สหกรณ์และภาษี';
  static const IconData menuIcon = Icons.savings_outlined;
  static const String groupTitle = 'บันทึกข้อมูลธนาคาร';

  static const Key saveKey = ValueKey('deduct-save');
  static const Key deleteKey = ValueKey('deduct-delete');
  static const Key personKey = ValueKey('deduct-person');
  static const Key duplicatesKey = ValueKey('deduct-duplicates');

  /// คีย์ของช่อง [name] (ชื่อช่องของ backend เช่น bank_acc)
  static Key fieldKey(String name) => ValueKey('deduct-$name');

  static const String newText =
      'ยังไม่มีทะเบียนของบุคคลนี้ กรอกแล้วกดบันทึกเพื่อสร้างใหม่';
  static const String notFoundText =
      'ไม่พบบุคคลนี้ในข้อมูลบุคลากร (DPIS) ตรวจเลขประจำตัวประชาชนอีกครั้ง';
  static const String savedMessage = 'บันทึกทะเบียนแล้ว';

  /// ช่องจำนวนเงินลดหย่อน (ชื่อช่อง -> ป้าย)
  static const Map<String, String> amountFields = {
    'donate_amt': 'เงินบริจาค',
    'insr_amt': 'เบี้ยประกันชีวิต',
    'int_amt': 'ดอกเบี้ยเงินกู้เพื่อที่อยู่อาศัย',
    'rmf_amt': 'ค่าซื้อหน่วยลงทุนในกองทุนรวมเพื่อการเลี้ยงชีพ (RMF)',
    'ltf_amt': 'ค่าซื้อหน่วยลงทุนในกองทุนระยะยาว (LTF)',
  };

  /// ป้ายของช่อง กบข/กสจ ตามหน้าจอของระบบเดิม — ค่าที่เก็บยังเป็น "0"/"1" ตามสัญญา
  static const String kbkMemberLabel = 'การเป็นสมาชิก กบข/กสจ';
  static const Map<String, String> kbkMemberChoices = {
    '0': 'ไม่เป็นสมาชิก',
    '1': 'เป็นสมาชิก',
  };
  static const String kbkSavingLabel = 'การสะสมเข้า กบข/กสจ';
  static const Map<String, String> kbkSavingChoices = {
    '0': 'ไม่สะสม',
    '1': 'สะสม',
  };
  static const String kbkStartLabel = 'วันที่เริ่มเป็นสมาชิก';
  static const String kbkExtraDateLabel = 'วันที่สะสมเพิ่มกรณีสมัครใจ';
  static const String statusLabel = 'สถานะ';
  static const Map<String, String> statusChoices = {'0': 'ใช้', '1': 'ไม่ใช้'};
  static const String notMemberNote =
      'ไม่เป็นสมาชิก กบข/กสจ — ช่องที่เหลือของกลุ่มนี้ปิดไว้ (ค่าเดิมยังอยู่ ไม่ถูกล้าง)';

  /// ช่องข้อความตัวเลข (ชื่อช่อง -> ป้าย, ความยาวต่ำสุด, สูงสุด)
  static const Map<String, (String, int, int)> digitFields = {
    'bank_acc': ('เลขที่บัญชีธนาคาร (10-15 หลัก)', 10, 15),
    'saha_id': ('เลขสมาชิกสหกรณ์', 1, 6),
    'chap_id': ('เลขสมาชิกฌาปนกิจ', 1, 6),
    'kbk_pct': ('อัตราร้อยละการสะสม', 1, 2),
    'kbk_pct2': ('อัตราร้อยละการสะสมกรณีสมัครใจ', 1, 2),
  };

  @override
  State<DeductScreen> createState() => _DeductScreenState();
}

class _DeductScreenState extends State<DeductScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, String>> _banks = [];
  List<Map<String, String>> _branches = [];
  List<Map<String, String>> _provinces = [];

  String? _idcard;
  PersonInfo? _person;

  /// ทะเบียนที่โหลดมา (ว่าง = ยังไม่มี กำลังสร้างใหม่)
  Map<String, String> _loaded = {};
  int _duplicates = 0;

  /// ค่าที่แก้อยู่บนจอ (ชื่อช่อง -> ข้อความ)
  final Map<String, String> _v = {};

  /// เปลี่ยนทุกครั้งที่โหลด ช่องกรอกถูกสร้างใหม่ด้วยค่าที่โหลดมา
  int _version = 0;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  String get _id => _loaded['id'] ?? '';
  bool get _isNew => _id.isEmpty;

  static const List<String> _editable = [
    'emp_type',
    'bank_code',
    'bank_brch',
    'bank_acc',
    'bank_prov',
    'prov_code',
    'saha_id',
    'chap_id',
    'kbk_flg',
    'kbk_type',
    'kbk_pct',
    'kbk_pct2',
    'kbk_dmy',
    'kbk_dmy2',
    'rec_flg',
    'donate_amt',
    'insr_amt',
    'int_amt',
    'rmf_amt',
    'ltf_amt',
  ];

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final banks = await widget.apiService.allMaster('banks');
      final provinces = await widget.apiService.allMaster('provinces');
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _provinces = provinces;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadBranches(String? bankCode) async {
    if ((bankCode ?? '').isEmpty) {
      setState(() => _branches = []);
      return;
    }
    try {
      final list = await widget.apiService.allMaster(
        'branches',
        filters: {'bank_code': bankCode!},
      );
      if (mounted && _v['bank_code'] == bankCode) {
        setState(() => _branches = list);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// ค่าของช่องจำนวนเงินจาก backend (ตัวเลข) เป็นข้อความในช่องกรอก
  static String _amountText(String? raw) =>
      Money.input(Money.fromJson((raw ?? '').isEmpty ? null : raw));

  Future<void> _pick(String idcard) async {
    setState(() {
      _loading = true;
      _error = null;
      _idcard = idcard;
      _person = null;
    });
    try {
      final person = await widget.apiService.lookupPerson(idcard);
      final found = await widget.apiService.findDeduct(idcard);
      if (!mounted) return;
      final item = found['item'];
      final loaded = item is Map
          ? item.map((k, v) => MapEntry('$k', v == null ? '' : '$v'))
          : <String, String>{};
      setState(() {
        _person = person;
        _loaded = loaded;
        _duplicates = (found['duplicates'] as num?)?.toInt() ?? 0;
        _v
          ..clear()
          ..addAll({
            for (final f in _editable)
              f: DeductScreen.amountFields.containsKey(f)
                  ? _amountText(loaded[f])
                  : (loaded[f] ?? ''),
          });
        // ค่าเริ่มต้นของทะเบียนใหม่: ประเภทตามผลค้นบุคคล สถานะ = ใช้
        if (loaded.isEmpty) {
          _v['emp_type'] = person.type;
          _v['rec_flg'] = '0';
          // ค่าเริ่มต้นเดียวกับ backend: เป็นสมาชิก และสะสม
          _v['kbk_flg'] = '1';
          _v['kbk_type'] = '1';
        }
        if ((_v['rec_flg'] ?? '').isEmpty) _v['rec_flg'] = '0';
        _branches = [];
        _version++;
        _loading = false;
      });
      _loadBranches(_v['bank_code']);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _idcard = null;
        _error = e.toString();
      });
    }
  }

  /// ค่าที่จะเทียบ/ส่ง backend ของช่อง [f] (จำนวนเงินจัดรูปเป็น "1500.50" ว่าง = ข้อความว่าง)
  String _out(String f) {
    final text = (_v[f] ?? '').trim();
    if (!DeductScreen.amountFields.containsKey(f) || text.isEmpty) return text;
    return Money.toJson(Money.parse(text) ?? 0);
  }

  String _loadedOut(String f) {
    final raw = _loaded[f] ?? '';
    if (!DeductScreen.amountFields.containsKey(f) || raw.isEmpty) return raw;
    return Money.toJson(Money.fromJson(raw));
  }

  Map<String, String> get _changes => {
    for (final f in _editable)
      if (_out(f) != _loadedOut(f) &&
          // จำนวนเงิน 0 กับช่องว่างถือว่าเท่ากัน
          !(DeductScreen.amountFields.containsKey(f) &&
              Money.fromJson(_out(f)) == Money.fromJson(_loadedOut(f))))
        f: _out(f),
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_v['emp_type'] ?? '').isEmpty) {
      setState(() => _error = 'กรุณาเลือกประเภทบุคลากร');
      return;
    }
    final Map<String, String> body;
    if (_isNew) {
      body = {
        'id_card': _idcard!,
        for (final f in _editable)
          if (_out(f).isNotEmpty) f: _out(f),
      };
    } else {
      body = _changes;
      if (body.isEmpty) {
        context.showInfoSnackBar('ไม่มีการแก้ไข');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.saveDeduct(_id, body);
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSuccessSnackBar(DeductScreen.savedMessage);
      await _pick(_idcard!);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.code == ErrorCodes.duplicate
            ? '${e.message}\nบุคคลนี้มีทะเบียนอยู่แล้ว กดค้นหาใหม่เพื่อแก้ไขรายการเดิม'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _delete() async {
    final ok = await AppDialog.showConfirm(
      context,
      'ลบทะเบียนของ ${_person?.fullName ?? 'บุคคลนี้'} ใช่หรือไม่',
      confirmText: 'ลบ',
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.apiService.deleteDeduct(_id);
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSuccessSnackBar('ลบทะเบียนแล้ว');
      await _pick(_idcard!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDate(String f) async {
    final current = BeDate.parse(_v[f]);
    final picked = widget.datePicker != null
        ? await widget.datePicker!(context, current)
        : await showThaiDatePicker(
            context,
            current,
            firstDate: DateTime(1957, 1, 1),
            lastDate: DateTime(DateTime.now().year + 1, 12, 31),
            startWithYear: current == null,
          );
    if (picked == null || !mounted) return;
    setState(() => _v[f] = BeDate.format(picked));
  }

  // ---------------------------------------------------------------------------
  // ชิ้นส่วนของฟอร์ม
  // ---------------------------------------------------------------------------

  InputDecoration _deco(String label, {Widget? suffix}) => InputDecoration(
    labelText: label,
    labelStyle: screenText(color: AppTheme.textSecondary),
    errorMaxLines: 3,
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.dividerColor),
    ),
  );

  /// ไม่เป็นสมาชิก กบข/กสจ (`kbk_flg` = 0): ช่องอื่นของกลุ่มปิดไว้
  bool get _kbkOff => _v['kbk_flg'] == '0';

  Widget _digits(String f, {bool enabled = true}) {
    final (label, min, max) = DeductScreen.digitFields[f]!;
    return TextFormField(
      key: ValueKey('deduct-$f-$_version'),
      initialValue: _v[f],
      enabled: enabled && !_saving,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(max),
      ],
      style: screenText(),
      decoration: _deco(label),
      validator: (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        return t.length < min ? '$label: ต้องมีอย่างน้อย $min หลัก' : null;
      },
      onChanged: (v) => _v[f] = v,
    );
  }

  Widget _amount(String f) => TextFormField(
    key: ValueKey('deduct-$f-$_version'),
    initialValue: _v[f],
    enabled: !_saving,
    textAlign: TextAlign.right,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    style: screenText(),
    decoration: _deco(DeductScreen.amountFields[f]!),
    validator: (v) => Money.parse(v) == null ? Money.invalidMessage : null,
    onChanged: (v) => _v[f] = v,
  );

  Widget _date(String f, String label, {bool enabled = true}) {
    final date = BeDate.parse(_v[f]);
    final active = enabled && !_saving;
    return InkWell(
      key: DeductScreen.fieldKey(f),
      onTap: active ? () => _pickDate(f) : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _deco(
          label,
          suffix: (_v[f] ?? '').isEmpty
              ? const Icon(Icons.calendar_today, size: 18)
              : IconButton(
                  tooltip: 'ล้างวันที่',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: active ? () => setState(() => _v[f] = '') : null,
                ),
        ),
        child: Text(
          date != null
              ? Util.formatThaiDate(date)
              : ((_v[f] ?? '').isEmpty ? 'เลือกวันที่' : _v[f]!),
          style: screenText(
            color: date == null || !enabled
                ? AppTheme.textSecondary
                : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  /// ตัวเลือกจากข้อมูลหลัก ค่าเดิมที่ไม่อยู่ในรายการ (ข้อมูลเก่า) ยังแสดงให้เห็นและคงไว้ได้
  Widget _dropdown(
    String f,
    String label,
    List<Map<String, String>> items,
    String codeKey,
    String nameKey,
    ValueChanged<String?> onChanged,
  ) {
    final value = (_v[f] ?? '').isEmpty ? null : _v[f];
    final known = items.any((e) => e[codeKey] == value);
    return DropdownButtonFormField<String>(
      key: ValueKey('deduct-$f-$_version-${items.length}-${_v[f]}'),
      initialValue: value,
      isExpanded: true,
      decoration: _deco(label),
      items: [
        const DropdownMenuItem(value: null, child: Text('-')),
        if (value != null && !known)
          DropdownMenuItem(
            value: value,
            child: Text('$value (ไม่อยู่ในข้อมูลหลัก)', style: screenText()),
          ),
        for (final e in items)
          DropdownMenuItem(
            value: e[codeKey],
            child: Text(
              '${e[codeKey]} ${e[nameKey]}',
              overflow: TextOverflow.ellipsis,
              style: screenText(),
            ),
          ),
      ],
      onChanged: _saving ? null : onChanged,
    );
  }

  Widget _flag(
    String f,
    String label,
    Map<String, String> choices, {
    bool enabled = true,
  }) => InputDecorator(
    decoration: _deco(label),
    child: Wrap(
      spacing: 8,
      children: [
        for (final c in choices.entries)
          ChoiceChip(
            key: ValueKey('deduct-$f-${c.key}'),
            label: Text(c.value, style: screenText(size: 13.5)),
            selected: _v[f] == c.key,
            onSelected: _saving || !enabled
                ? null
                : (on) => setState(() => _v[f] = on ? c.key : ''),
          ),
      ],
    ),
  );

  Widget _grid(List<Widget> children) => ResponsiveGrid(
    minItemWidth: 250,
    maxColumns: 3,
    spacing: 12,
    children: children,
  );

  Widget _form() {
    final person = _person;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepCard(
            icon: Icons.person_outline,
            title: person != null && person.fullName.isNotEmpty
                ? person.fullName
                : IdCard.masked(_idcard),
            subtitle: [
              'เลขประจำตัวประชาชน ${IdCard.masked(_idcard)}',
              if (person?.startDate != null)
                'วันบรรจุ ${Util.formatThaiDate(person!.startDate!)}',
              if ((_loaded['upd_dmy'] ?? '').isNotEmpty)
                'วันที่ปรับปรุง ${Util.formatThaiDateStr(BeDate.parse(_loaded['upd_dmy'])?.toIso8601String())}',
            ].join(' · '),
            child: Column(
              key: DeductScreen.personKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (person != null && !person.found) ...[
                  const NoticeBar(
                    type: NoticeType.warning,
                    text: DeductScreen.notFoundText,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_isNew) ...[
                  const NoticeBar(
                    type: NoticeType.info,
                    text: DeductScreen.newText,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_duplicates > 0) ...[
                  NoticeBar(
                    key: DeductScreen.duplicatesKey,
                    type: NoticeType.warning,
                    text:
                        'ข้อมูลเดิมมีเลขประจำตัวประชาชนนี้ซ้ำ $_duplicates รายการ '
                        'หน้านี้แสดงรายการแรก กรุณาลบรายการที่เกินออก',
                  ),
                  const SizedBox(height: 10),
                ],
                _grid([
                  _flag('emp_type', 'ประเภทบุคลากร *', EmpType.names),
                  _flag(
                    'rec_flg',
                    DeductScreen.statusLabel,
                    DeductScreen.statusChoices,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StepCard(
            icon: Icons.account_balance,
            title: 'บัญชีธนาคาร',
            child: _grid([
              _dropdown(
                'bank_code',
                'ธนาคาร',
                _banks,
                'bank_code',
                'bank_name',
                (v) {
                  // เปลี่ยนธนาคาร: สาขาเดิมใช้ไม่ได้แล้ว
                  setState(() {
                    _v['bank_code'] = v ?? '';
                    _v['bank_brch'] = '';
                    _branches = [];
                  });
                  _loadBranches(v);
                },
              ),
              _dropdown(
                'bank_brch',
                'สาขาธนาคาร',
                _branches,
                'bank_brch',
                'name',
                (v) => setState(() => _v['bank_brch'] = v ?? ''),
              ),
              _digits('bank_acc'),
              _dropdown(
                'prov_code',
                'จังหวัด',
                _provinces,
                'prov_code',
                'prov_name',
                (v) => setState(() {
                  _v['prov_code'] = v ?? '';
                  // ชื่อจังหวัดเก็บคู่กับรหัส
                  _v['bank_prov'] =
                      _provinces
                          .where((p) => p['prov_code'] == v)
                          .map((p) => p['prov_name'] ?? '')
                          .firstOrNull ??
                      '';
                }),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          StepCard(
            icon: Icons.groups_2_outlined,
            title: 'สมาชิกสหกรณ์ / ฌาปนกิจ',
            subtitle: (_loaded['saha_code'] ?? '').isEmpty
                ? null
                : 'รหัสสหกรณ์ ${_loaded['saha_code']}',
            child: _grid([_digits('saha_id'), _digits('chap_id')]),
          ),
          const SizedBox(height: 12),
          StepCard(
            icon: Icons.savings_outlined,
            title: 'กบข / กสจ',
            subtitle: _kbkOff ? DeductScreen.notMemberNote : null,
            child: _grid([
              _flag(
                'kbk_flg',
                DeductScreen.kbkMemberLabel,
                DeductScreen.kbkMemberChoices,
              ),
              _date('kbk_dmy', DeductScreen.kbkStartLabel, enabled: !_kbkOff),
              _flag(
                'kbk_type',
                DeductScreen.kbkSavingLabel,
                DeductScreen.kbkSavingChoices,
                enabled: !_kbkOff,
              ),
              _digits('kbk_pct', enabled: !_kbkOff),
              _date(
                'kbk_dmy2',
                DeductScreen.kbkExtraDateLabel,
                enabled: !_kbkOff,
              ),
              _digits('kbk_pct2', enabled: !_kbkOff),
            ]),
          ),
          const SizedBox(height: 12),
          StepCard(
            icon: Icons.receipt_long_outlined,
            title: 'รายการลดหย่อนภาษี',
            child: _grid([
              for (final f in DeductScreen.amountFields.keys) _amount(f),
            ]),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PrimaryActionButton(
                key: DeductScreen.saveKey,
                label: 'บันทึก',
                icon: Icons.save_outlined,
                loading: _saving,
                onPressed: _save,
              ),
              if (!_isNew)
                PrimaryActionButton(
                  key: DeductScreen.deleteKey,
                  label: 'ลบทะเบียน',
                  icon: Icons.delete_outline,
                  color: AppTheme.deleteColor,
                  onPressed: _saving ? null : _delete,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, DeductScreen.groupTitle),
      body: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenHeader(
                    icon: DeductScreen.menuIcon,
                    title: DeductScreen.menuTitle,
                    subtitle:
                        'ทะเบียนบัญชีธนาคาร กบข/กสจ. สหกรณ์ ฌาปนกิจ และลดหย่อนภาษีของบุคลากร หนึ่งรายการต่อคน',
                  ),
                  const SizedBox(height: 16),
                  PersonFinder(
                    apiService: widget.apiService,
                    enabled: !_loading && !_saving,
                    onPicked: _pick,
                  ),
                  const SizedBox(height: 12),
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
                  else if (_idcard != null && _person != null)
                    _form(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
