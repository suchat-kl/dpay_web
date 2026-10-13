import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../models/div_dept.dart';
import '../models/edit_window.dart';
import '../models/period.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/debt_api.dart';
import '../utils/dialog.dart';
import '../utils/money.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/debt_dialogs.dart';
import '../widgets/div_selector.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';

/// บันทึกข้อมูล — แก้ไขยอดหนี้รายคนของงวดปัจจุบัน (ทุกบทบาท ตามขอบเขตหน่วยงาน)
///
/// **หน้านี้ทำได้อย่างเดียวคือแก้ไขยอดหนี้ 5 รหัส** — ไม่มีการเพิ่มคน ปรับรายชื่อ ย้ายหน่วยงาน หรือลบรายการ
/// (รายชื่อของงวดมาจากการเตรียมงวด บุคลากรที่เข้ามาใหม่ระหว่างงวดจะอยู่ในงวดถัดไป) จึงไม่มีช่องติ๊กเลือกแถว
/// และไม่มีปุ่ม "ลบที่เลือก/เลือกทั้งหมด/เพิ่ม"
///
/// แบบเดียวกับ "ใบแจ้งค่าอาหาร" ของ HTC: หัวกระดาษ (หน่วยงาน ประเภท งวด ยอดรวม) + ตารางแก้ไขในแถว
/// - เลือกหน่วยงาน ([DivSelector]) และประเภท G/E → `GET /api/debts` (ค้นชื่อ-สกุลใช้ `POST /api/debts/search`)
/// - หัวตารางตรึงอยู่บนสุดตอนเลื่อน ([SheetPinnedHeader]) ยอดรวมต่อรหัสอยู่ในแถบล่างที่ไม่เลื่อน
///   แถวที่แก้มีเครื่องหมายดินสอ กด Enter/Tab ไปช่องถัดไป
/// - แก้ยอด 5 รหัสในแถว (ไม่มี 40604) ตัวเลขชิดขวา ทศนิยม 2 ตำแหน่ง เก็บเป็นสตางค์
/// - "บันทึก" ส่งเฉพาะแถวและรหัสที่แก้ในคำขอเดียว (`PUT /api/debts`) มีสถานะ "มีการแก้ไขที่ยังไม่ได้บันทึก"
///   และถามยืนยันก่อนออก / เปลี่ยนหน่วยงาน / เปลี่ยนประเภท / เปลี่ยนงวด / เปลี่ยนหน้า / ค้นหา
/// - ไอคอนประวัติท้ายแถว = ประวัติการแก้ไขรายแถว, ป้าย "ไม่อยู่ในรายชื่อ DPIS" เมื่อ `in_roster` เท็จ
/// - **ดูงวดย้อนหลังได้แบบอ่านอย่างเดียว**: ตัวเลือกงวด (เดือน + ปี พ.ศ. ไม่เกินงวดปัจจุบัน) ส่ง `month`/`year`
///   ไปกับรายการ การค้นหา และยอดรวม มีแถบ "กำลังดูงวดย้อนหลัง ..." พร้อมปุ่มกลับไปงวดปัจจุบัน ไม่มีปุ่มบันทึก
/// - **อ่านอย่างเดียว**เมื่อ backend บอกว่าแก้ไม่ได้ (`editable` เท็จ หรือตอบ `EDIT_WINDOW_CLOSED`) พร้อมแถบบอกช่วงที่เปิด
///   งวดที่ยังไม่เตรียม (`PERIOD_NOT_READY`) และไม่ใช่งวดปัจจุบัน (`NOT_CURRENT_PERIOD`) มีข้อความของตัวเอง
class DebtEntryScreen extends StatefulWidget {
  final ApiService apiService;

  /// หน่วยงานที่เปิดไว้ก่อน (เปิดจากหน้า "สถานะการบันทึกของหน่วยงาน") — ไม่อยู่ในขอบเขต = หน่วยงานของตัวเอง
  final String? initialDiv;

  /// งวดย้อนหลังที่เปิดไว้ก่อน (null = งวดปัจจุบัน)
  final Period? initialPeriod;

  const DebtEntryScreen({
    super.key,
    required this.apiService,
    this.initialDiv,
    this.initialPeriod,
  });

  static const String menuTitle = 'บันทึกข้อมูล';
  static const IconData menuIcon = Icons.edit_note;
  static const String groupTitle = 'งานหักหนี้';

  static const Key saveKey = ValueKey('debt-save');
  static const Key dirtyKey = ValueKey('debt-dirty');
  static const Key readOnlyKey = ValueKey('debt-readonly');
  static const Key nameKey = ValueKey('debt-search-name');
  static const Key surnameKey = ValueKey('debt-search-surname');
  static const Key searchKey = ValueKey('debt-search');

  /// บรรทัดประเภทบุคคล/หน่วยงานของแถว (มีเฉพาะผลค้นทุกหน่วยงาน)
  static Key rowDivKey(String id) => ValueKey('debt-row-div-$id');
  static const Key acrossNoticeKey = ValueKey('debt-search-across');

  /// แถบแจ้งเมื่อผลค้นมาจากทุกหน่วยงาน (ผู้ดูแลระบบ/ฝ่ายบัญชี ค้นด้วยชื่อ-นามสกุล)
  static const String acrossText =
      'ผลค้นหาด้วยชื่อ-นามสกุลจากทุกหน่วยงาน ทั้งข้าราชการและลูกจ้างประจำ '
      '(ไม่ขึ้นกับหน่วยงานและประเภทบุคคลที่เลือกไว้) ล้างช่องค้นหาแล้วกดค้นหาเพื่อกลับไปดูรายการของหน่วยงาน';
  static const Key periodKey = PeriodPicker.labelKey;
  static const Key periodButtonKey = PeriodPicker.buttonKey;
  static const Key pastNoticeKey = ValueKey('debt-past');
  static const Key backToCurrentKey = ValueKey('debt-back-current');

  /// คีย์ของปุ่มเลือกประเภท [type] (G / E)
  static Key typeKey(String type) => ValueKey('debt-type-$type');

  /// คีย์ของแถวรายการ [id] ช่องยอดของรหัส [field] ยอดรวมของรหัส และปุ่มในแถว
  static Key rowKey(String id) => ValueKey('debt-row-$id');
  static Key cellKey(String id, String field) => ValueKey('debt-$id-$field');
  static Key summaryKey(String field) => ValueKey('debt-sum-$field');
  static Key auditKey(String id) => ValueKey('debt-audit-$id');

  /// เครื่องหมายของแถวที่แก้แล้วยังไม่บันทึก
  static Key changedKey(String id) => ValueKey('debt-changed-$id');

  static const String dirtyText = 'มีการแก้ไขที่ยังไม่ได้บันทึก';
  static const String discardQuestion =
      'ยังมีการแก้ไขที่ยังไม่ได้บันทึก ต้องการทิ้งการแก้ไขหรือไม่?';
  static const String windowClosedText =
      'อยู่นอกระยะเวลาแก้ไขข้อมูล ดูรายการได้อย่างเดียว';
  static const String notReadyText =
      'งวดนี้ยังเตรียมข้อมูลไม่เสร็จ ยังแก้ไขยอดไม่ได้ กรุณารอฝ่ายบัญชีเตรียมข้อมูลงวด';
  static const String notCurrentText =
      'รายการชุดนี้ไม่ใช่งวดปัจจุบัน ดูได้อย่างเดียว (แก้ไขได้เฉพาะงวดปัจจุบัน)';
  static const String notInRosterText = 'ไม่อยู่ในรายชื่อ DPIS';
  static const String emptyText = 'ไม่มีรายการของหน่วยงานนี้ในงวดนี้';
  static const String rosterNote =
      'รายชื่อของงวดมาจากการเตรียมงวด บุคลากรที่เข้ามาใหม่ระหว่างงวดจะอยู่ในงวดถัดไป';
  static const String backToCurrentLabel = 'กลับไปงวดปัจจุบัน';

  /// ข้อความแถบแจ้งเมื่อดูงวดย้อนหลัง [label] เช่น "มิถุนายน 2568"
  static String pastText(String label) =>
      'กำลังดูงวดย้อนหลัง $label — ดูได้อย่างเดียว';

  @override
  State<DebtEntryScreen> createState() => _DebtEntryScreenState();
}

class _DebtEntryScreenState extends State<DebtEntryScreen> {
  final _settings = SettingsProvider();
  final _name = TextEditingController();
  final _surname = TextEditingController();

  /// ตัวเลื่อนแนวนอนของตาราง หัวตารางที่ตรึงไว้เลื่อนตามตัวนี้
  final _tableScroll = ScrollController();

  DivChoices? _choices;
  DivDept? _div;
  String _type = EmpType.g;

  /// เปลี่ยนค่าเพื่อสร้างตัวเลือกหน่วยงานใหม่ (ใช้ตอนผู้ใช้ยกเลิกการเปลี่ยนหน่วยงาน)
  int _selectorVersion = 0;

  DebtPage? _data;
  List<DebtSummaryItem> _summary = [];
  int _page = 0;
  int _pageSize = 10;

  /// งวดย้อนหลังที่กำลังดู — null = งวดปัจจุบัน (ไม่ส่ง month/year ให้ backend ใช้งวดปัจจุบันเอง)
  Period? _past;

  /// เปลี่ยนทุกครั้งที่โหลด ช่องกรอกจะถูกสร้างใหม่ด้วยค่าที่โหลดมา
  int _version = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// ข้อความของงวดที่ยังไม่พร้อม (backend ตอบ PERIOD_NOT_READY ตอนโหลด)
  String? _blocked;

  /// backend ตอบ EDIT_WINDOW_CLOSED ตอนบันทึก: ปิดการแก้ไขจนกว่าจะโหลดใหม่
  bool _forcedClosed = false;

  /// รายการที่แสดงอยู่เป็นผลค้นทุกหน่วยงานทุกประเภท (ดู [_wantsAcross])
  bool _across = false;

  /// ผู้ที่เลือกได้ทุกหน่วยงาน (ผู้ดูแลระบบ/ฝ่ายบัญชี) ค้นด้วยชื่อ-นามสกุล = ใช้เงื่อนไขชื่อ-นามสกุลอย่างเดียว
  /// ได้ทุกหน่วยงานทั้งข้าราชการและลูกจ้างประจำ — ผู้ใช้ทั่วไปค้นในหน่วยงานของตัวเองตามประเภทที่เลือกเหมือนเดิม
  /// (ผู้ใช้สั่ง 13 ต.ค. 2569; backend กันสิทธิ์ซ้ำที่ `div: "*"`)
  bool get _wantsAcross =>
      widget.apiService.divScope == DivScope.all &&
      (_name.text.trim().isNotEmpty || _surname.text.trim().isNotEmpty);

  List<DebtRow> get _rows => _data?.items ?? const [];
  bool get _dirty => _rows.any((r) => r.dirty);
  bool get _editable =>
      _past == null && (_data?.editable ?? false) && !_forcedClosed;

  @override
  void initState() {
    super.initState();
    _past = widget.initialPeriod;
    _loadDivs();
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  Future<void> _loadDivs() async {
    try {
      final choices = await widget.apiService.getDivs();
      if (mounted) setState(() => _choices = choices);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// มีการแก้ไขค้าง: ถามก่อนทิ้ง คืนจริง = ทำต่อได้
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await AppDialog.showConfirm(
      context,
      DebtEntryScreen.discardQuestion,
      confirmText: 'ทิ้งการแก้ไข',
    );
    return ok == true;
  }

  Future<void> _onDivChanged(DivDept div) async {
    if (div.div == _div?.div) return;
    if (_div != null && !await _confirmDiscard()) {
      // ยกเลิก: สร้างตัวเลือกใหม่ให้กลับไปแสดงหน่วยงานเดิม
      if (mounted) setState(() => _selectorVersion++);
      return;
    }
    if (!mounted) return;
    setState(() {
      _div = div;
      _page = 0;
    });
    _load();
  }

  Future<void> _onTypeChanged(String type) async {
    if (type == _type || !await _confirmDiscard() || !mounted) return;
    setState(() {
      _type = type;
      _page = 0;
    });
    _load();
  }

  /// เปลี่ยนงวดที่ดู ([next] null = งวดปัจจุบัน กลับไปโหมดแก้ไข) — ถามก่อนถ้ามีการแก้ไขค้าง
  Future<void> _onPeriodChanged(Period? next) async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() {
      _past = next;
      _page = 0;
    });
    _load();
  }

  Future<void> _search() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _page = 0);
    _load();
  }

  Future<void> _load() async {
    final div = _div;
    if (div == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _blocked = null;
    });
    final across = _wantsAcross;
    try {
      final page = await widget.apiService.getDebts(
        div: across ? '*' : div.div,
        type: across ? null : _type,
        period: _past,
        name: _name.text,
        surname: _surname.text,
        page: _page,
        size: _pageSize,
      );
      // ยอดรวมโหลดไม่ได้ไม่ทำให้ตารางใช้ไม่ได้
      // ผลค้นทุกหน่วยงานไม่แสดงยอดรวม (ยอดรวมเป็นของหน่วยงาน/ประเภทที่เลือก ไม่ใช่ของผลค้น)
      List<DebtSummaryItem> summary = const [];
      if (!across) {
        try {
          summary = await widget.apiService.getDebtSummary(
            div: div.div,
            type: _type,
            period: _past,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _data = page;
        _across = across;
        _summary = summary;
        _version++;
        _forcedClosed = false;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _summary = [];
        _loading = false;
        if (e.code == ErrorCodes.periodNotReady) {
          _blocked = e.message;
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onCellChanged(DebtRow row, String field, String text) {
    final value = Money.parse(text);
    setState(() {
      if (value == null) {
        row.invalid[field] = text;
      } else {
        row.invalid.remove(field);
        row.amounts[field] = value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final changed = _rows.where((r) => r.dirty).toList();
    for (final r in changed) {
      if (r.invalid.isNotEmpty) {
        setState(() {
          _error =
              'แถวที่ ${_rows.indexOf(r) + 1 + _page * _pageSize} (${r.fullName}) '
              '${DebtCodes.nameOf(r.invalid.keys.first)}: ${Money.invalidMessage}';
        });
        return;
      }
    }
    if (changed.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = await widget.apiService.saveDebts(changed);
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSuccessSnackBar(
        '${body['message'] ?? 'บันทึกข้อมูลสำเร็จ'} '
        '(${body['updated'] ?? changed.length} รายการ)',
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (e.code) {
          ErrorCodes.editWindowClosed =>
            '${e.message}\nการแก้ไขครั้งนี้ไม่ถูกบันทึก',
          ErrorCodes.notCurrentPeriod =>
            '${e.message}\nงวดปัจจุบันถูกเปลี่ยนแล้ว กรุณาโหลดรายการใหม่',
          ErrorCodes.periodNotReady =>
            '${e.message}\n${DebtEntryScreen.notReadyText}',
          _ => e.message,
        };
        if (e.isEditWindowClosed) _forcedClosed = true;
      });
      // ช่วงแก้ไข/งวดเปลี่ยนไปแล้ว ให้หน้าจออื่นเห็นสถานะล่าสุดด้วย
      if (e.isEditWindowClosed || e.code == ErrorCodes.notCurrentPeriod) {
        _settings.load();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  void _showAudit(DebtRow row) {
    showDialog<void>(
      context: context,
      builder: (_) => DebtAuditDialog(apiService: widget.apiService, row: row),
    );
  }

  // ---------------------------------------------------------------------------
  // หน้าจอ
  // ---------------------------------------------------------------------------

  static const double _noWidth = 44;

  /// ความกว้างต่ำสุดของตาราง (จอแคบกว่านี้เลื่อนแนวนอน หัวตารางเลื่อนตาม)
  static const double _tableWidth = 1180;

  /// ความกว้างของคอลัมน์ปุ่มท้ายแถว (ประวัติการแก้ไข)
  static const double _actionWidth = 52;

  Widget _tableHeader() => Row(
    children: [
      const SizedBox(
        width: _noWidth,
        child: SheetHead('ที่', align: TextAlign.center),
      ),
      const Expanded(flex: 6, child: SheetHead('ชื่อ-สกุล')),
      for (final f in DebtCodes.fields)
        Expanded(
          flex: 3,
          child: SheetHead(
            '${DebtCodes.nameOf(f)}\n${DebtCodes.codeOf(f)}',
            align: TextAlign.right,
          ),
        ),
      const Expanded(flex: 3, child: SheetHead('รวม', align: TextAlign.right)),
      const SizedBox(width: _actionWidth),
    ],
  );

  Widget _amountCell(DebtRow row, String field) {
    final bad = row.invalid.containsKey(field);
    final changed = row.amounts[field] != row.original[field];
    return Padding(
      key: DebtEntryScreen.cellKey(row.id, field),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        // โหลดใหม่แล้วสร้างช่องใหม่ด้วยค่าที่โหลดมา
        key: ValueKey(_version),
        initialValue: Money.input(row.original[field] ?? 0),
        enabled: _editable && !_saving,
        textAlign: TextAlign.right,
        // Enter = ไปช่องถัดไป (เหมือน Tab) กรอกต่อเนื่องได้โดยไม่ต้องจับเมาส์
        textInputAction: TextInputAction.next,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          LengthLimitingTextInputFormatter(13),
        ],
        style: screenText(
          size: 14.5,
          weight: changed ? FontWeight.w700 : FontWeight.w400,
          color: bad ? AppTheme.dangerColor : AppTheme.textPrimary,
        ),
        decoration: sheetInput(hint: '0.00', error: bad),
        onChanged: (v) => _onCellChanged(row, field, v),
      ),
    );
  }

  Widget _tableRow(DebtRow row, int index) => Row(
    key: DebtEntryScreen.rowKey(row.id),
    children: [
      SizedBox(
        width: _noWidth,
        // แถวที่แก้แล้วยังไม่บันทึก: มีเครื่องหมายดินสอใต้เลขลำดับ
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${index + 1 + _page * _pageSize}',
              textAlign: TextAlign.center,
              style: screenText(size: 13.5, color: AppTheme.textSecondary),
            ),
            if (row.dirty)
              Icon(
                Icons.edit,
                key: DebtEntryScreen.changedKey(row.id),
                size: 14,
                color: AppTheme.warningColor,
                semanticLabel: 'แก้ไขแล้วยังไม่บันทึก',
              ),
          ],
        ),
      ),
      Expanded(
        flex: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.fullName, style: screenText(size: 14.5)),
              // ผลค้นทุกหน่วยงาน: บอกประเภทบุคคลและหน่วยงานของแต่ละคน
              if (_across)
                Text(
                  '${EmpType.nameOf(row.type)} · หน่วยงาน ${row.div} ${row.divName}'
                      .trim(),
                  key: DebtEntryScreen.rowDivKey(row.id),
                  style: screenText(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              if (row.posName.isNotEmpty)
                Text(
                  row.posName,
                  style: screenText(size: 12.5, color: AppTheme.textSecondary),
                ),
              if (row.inRoster == false)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: StatusChip(
                    DebtEntryScreen.notInRosterText,
                    AppTheme.warningColor,
                  ),
                ),
            ],
          ),
        ),
      ),
      for (final f in DebtCodes.fields)
        Expanded(flex: 3, child: _amountCell(row, f)),
      Expanded(
        flex: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            Money.format(row.total),
            textAlign: TextAlign.right,
            style: screenText(size: 14.5, weight: FontWeight.w600),
          ),
        ),
      ),
      SizedBox(
        width: _actionWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              key: DebtEntryScreen.auditKey(row.id),
              tooltip: 'ประวัติการแก้ไข',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 44, height: 40),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.history, size: 20),
              onPressed: () => _showAudit(row),
            ),
          ],
        ),
      ),
    ],
  );

  /// แถบแจ้งเหตุที่ตารางอ่านอย่างเดียว (null = แก้ไขได้)
  Widget? _readOnlyNotice() {
    final data = _data;
    if (data == null || _editable) return null;
    if (_past != null) {
      return NoticeBar(
        key: DebtEntryScreen.pastNoticeKey,
        type: NoticeType.info,
        title: 'อ่านอย่างเดียว',
        text: DebtEntryScreen.pastText(_past!.label),
        action: SheetButton(
          DebtEntryScreen.backToCurrentLabel,
          key: DebtEntryScreen.backToCurrentKey,
          icon: Icons.undo,
          color: AppTheme.primaryColor,
          onPressed: () => _onPeriodChanged(null),
        ),
      );
    }
    String text;
    if (!data.periodReady) {
      text = DebtEntryScreen.notReadyText;
    } else if (!data.isCurrentPeriod) {
      text = DebtEntryScreen.notCurrentText;
    } else {
      final EditWindow? w = _settings.editWindow;
      text =
          '${DebtEntryScreen.windowClosedText}\n'
          'ช่วงที่เปิดให้แก้ไข: ${w == null ? '-' : w.rangeLabel}';
    }
    return NoticeBar(
      key: DebtEntryScreen.readOnlyKey,
      type: NoticeType.warning,
      title: 'อ่านอย่างเดียว',
      text: text,
    );
  }

  /// แถบยอดรวมต่อรหัสของหน่วยงาน/ประเภท (จาก `/summary`) — อยู่ในแถบล่างที่ไม่เลื่อน เห็นตลอดเวลา
  Widget _summaryStrip() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            'ยอดรวม',
            style: screenText(size: 13.5, weight: FontWeight.w700),
          ),
        ),
        for (final s in _summary)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s.name} · ${Util.formatCount(s.count)} คน',
                  style: screenText(size: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  Money.format(s.amount),
                  key: DebtEntryScreen.summaryKey(s.field),
                  style: screenText(size: 14.5, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _searchBox() {
    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: screenText(color: AppTheme.textSecondary),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.dividerColor),
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: TextField(
            key: DebtEntryScreen.nameKey,
            controller: _name,
            style: screenText(),
            decoration: deco('ชื่อ'),
            onSubmitted: (_) => _search(),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            key: DebtEntryScreen.surnameKey,
            controller: _surname,
            style: screenText(),
            decoration: deco('นามสกุล'),
            onSubmitted: (_) => _search(),
          ),
        ),
        SheetButton(
          'ค้นหา',
          key: DebtEntryScreen.searchKey,
          icon: Icons.search,
          color: AppTheme.searchColor,
          onPressed: _search,
        ),
        // ปุ่มบันทึกอยู่ต่อท้ายปุ่มค้นหา (ผู้ใช้สั่ง 13 ต.ค. 2569) — งวดย้อนหลังดูได้อย่างเดียว ไม่มีปุ่มบันทึก
        if (_past == null)
          PrimaryActionButton(
            key: DebtEntryScreen.saveKey,
            label: 'บันทึก',
            icon: Icons.save_outlined,
            loading: _saving,
            onPressed: _editable && _dirty ? _save : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final choices = _choices;
    final data = _data;
    final notice = _readOnlyNotice();
    final pad = isDesktop ? 24.0 : 12.0;

    return PopScope(
      // ปิดหน้าทั้งที่ยังแก้ไขค้าง (ปุ่มปิด หรือปุ่มย้อนกลับของเบราว์เซอร์) ต้องถามก่อน
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          setState(() => _data = null);
          WidgetsBinding.instance.addPostFrameCallback((_) => nav.maybePop());
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: screenAppBar(context, DebtEntryScreen.groupTitle),
        body: Column(
          children: [
            Expanded(
              // หัวตารางตรึงอยู่บนสุดตอนเลื่อน (sliver) ส่วนยอดรวมอยู่ในแถบล่างที่ไม่เลื่อน
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                    sliver: SliverList.list(
                      children: [
                        ScreenHeader(
                          icon: DebtEntryScreen.menuIcon,
                          title: DebtEntryScreen.menuTitle,
                          subtitle:
                              'แก้ไขยอดหนี้รายคนของงวดปัจจุบัน แก้ยอดในตารางแล้วกดบันทึก',
                          bullets: const [DebtEntryScreen.rosterNote],
                        ),
                        const SizedBox(height: 14),
                        PeriodPicker(
                          past: _past,
                          enabled: !_loading && !_saving,
                          onChanged: _onPeriodChanged,
                        ),
                        const SizedBox(height: 12),
                        if (choices != null)
                          DivSelector(
                            key: ValueKey('debt-div-$_selectorVersion'),
                            apiService: widget.apiService,
                            choices: choices,
                            initialDiv: _div?.div ?? widget.initialDiv,
                            onChanged: _onDivChanged,
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SegmentedButton<String>(
                              showSelectedIcon: false,
                              segments: [
                                for (final t in [EmpType.g, EmpType.e])
                                  ButtonSegment(
                                    value: t,
                                    label: Text(
                                      EmpType.nameOf(t),
                                      key: DebtEntryScreen.typeKey(t),
                                      style: screenText(size: 14.5),
                                    ),
                                  ),
                              ],
                              selected: {_type},
                              onSelectionChanged: (s) =>
                                  _onTypeChanged(s.first),
                            ),
                            _searchBox(),
                          ],
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
                        if (_blocked != null) ...[
                          NoticeBar(
                            type: NoticeType.warning,
                            title: 'งวดยังไม่พร้อม',
                            text: '$_blocked\n${DebtEntryScreen.notReadyText}',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (data != null) ...[
                          if (_across) ...[
                            const NoticeBar(
                              key: DebtEntryScreen.acrossNoticeKey,
                              type: NoticeType.info,
                              text: DebtEntryScreen.acrossText,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (notice != null) ...[
                            notice,
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (!_loading && data != null) ...[
                    SheetPinnedHeader(
                      header: _tableHeader(),
                      minWidth: _tableWidth,
                      sidePadding: pad,
                      scroll: _tableScroll,
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                      sliver: SliverToBoxAdapter(
                        child: SheetScroll(
                          minWidth: _tableWidth,
                          controller: _tableScroll,
                          child: SheetCard(
                            header: null,
                            emptyText: DebtEntryScreen.emptyText,
                            rows: [
                              for (var i = 0; i < _rows.length; i++)
                                _tableRow(_rows[i], i),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // แถบล่าง: ยอดรวม + สถานะแก้ไขค้าง + ตัวแบ่งหน้า
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: width < 520 ? 8 : 24,
                vertical: 10,
              ),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_loading && data != null && _summary.isNotEmpty) ...[
                    _summaryStrip(),
                    const SizedBox(height: 8),
                  ],
                  // ปุ่มบันทึกย้ายไปอยู่ต่อท้ายปุ่มค้นหาด้านบนแล้ว แถบล่างเหลือข้อความเตือนว่ามีการแก้ไขค้าง
                  if (_dirty)
                    Text(
                      DebtEntryScreen.dirtyText,
                      key: DebtEntryScreen.dirtyKey,
                      style: screenText(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  if (data != null) ...[
                    const SizedBox(height: 8),
                    AppPagination(
                      currentPage: _page,
                      totalPages: data.totalPages,
                      pageSize: _pageSize,
                      summary:
                          'ทั้งหมด ${Util.formatCount(data.totalItems)} คน',
                      onPageChanged: (p) async {
                        if (!await _confirmDiscard() || !mounted) return;
                        setState(() => _page = p);
                        _load();
                      },
                      onPageSizeChanged: (s) async {
                        if (!await _confirmDiscard() || !mounted) return;
                        setState(() {
                          _pageSize = s;
                          _page = 0;
                        });
                        _load();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
