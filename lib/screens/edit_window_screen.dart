import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/edit_window.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/account_form.dart';
import '../widgets/screen_parts.dart';
import '../widgets/thai_date_range_picker.dart';

/// ระยะเวลาแก้ไขข้อมูล — เมนู "ข้อมูลงวด" ของฝ่ายบัญชี (ACCOUNT)
///
/// อ่าน `GET /api/edit-window` บันทึก `PUT /api/edit-window {beginDate, endDate, beginTime, endTime}`
/// (วันที่ ค.ศ. yyyy-MM-dd เวลา HH:mm) เลือกวันเริ่ม-วันสิ้นสุดในครั้งเดียวด้วยปฏิทินช่วงวันที่ พ.ศ.
/// ([showThaiDateRangePicker] แตะสองครั้งหรือลาก — มาแทน SfDateRangePicker ของระบบเดิม) กรอกเวลาเป็น ชั่วโมง:นาที
///
/// ช่วงที่ตั้งเป็น**ช่วงต่อเนื่องช่วงเดียว** จากวันเริ่ม+เวลาเริ่ม ถึงวันสิ้นสุด+เวลาสิ้นสุด
/// ไม่ใช่ช่วงเวลาที่ซ้ำทุกวัน หน้าจอมีคำอธิบายและตัวอย่างบอกผู้ใช้เรื่องนี้ชัด ๆ
/// สถานะเปิด/ปิดมาจาก backend เท่านั้น (ไม่เทียบกับนาฬิกาของเครื่องผู้ใช้)
class EditWindowScreen extends StatefulWidget {
  final ApiService apiService;

  /// ตัวเลือกช่วงวันที่ ไม่ส่ง = ปฏิทินช่วงวันที่ พ.ศ. ของระบบ ([showThaiDateRangePicker])
  /// เทสต์ส่งตัวจำลองมาแทนได้ (รับช่วงที่เลือกอยู่ คืนช่วงใหม่ หรือ null = ยกเลิก)
  final Future<DateTimeRange?> Function(
    BuildContext context,
    DateTimeRange? initial,
  )?
  rangePicker;

  const EditWindowScreen({
    super.key,
    required this.apiService,
    this.rangePicker,
  });

  static const String menuTitle = 'ระยะเวลาแก้ไขข้อมูล';
  static const IconData menuIcon = Icons.timer_outlined;
  static const String groupTitle = 'ข้อมูลงวด';

  /// ช่องช่วงวันที่ (แตะเพื่อเปิดปฏิทินเลือกวันเริ่ม-วันสิ้นสุด)
  static const Key rangeKey = ValueKey('edit-window-range');
  static const Key beginTimeKey = ValueKey('edit-window-begin-time');
  static const Key endTimeKey = ValueKey('edit-window-end-time');
  static const Key saveButtonKey = ValueKey('edit-window-save');
  static const Key statusKey = ValueKey('edit-window-status');
  static const Key summaryKey = ValueKey('edit-window-summary');

  /// เวลาเริ่มต้น/สิ้นสุดที่เติมให้**เฉพาะเมื่อช่องเวลายังไม่มีค่า** (backend ไม่มีเวลามา) ผู้ใช้แก้ได้
  /// เลือกช่วงวันใหม่ไม่ตั้งเวลากลับ — เวลาที่โหลดมาหรือที่ผู้ใช้แก้ไว้คงอยู่
  /// การตั้งกลับเป็นค่านี้ตอนเปลี่ยนงวดเป็นหน้าที่ของ backend (PUT /api/period)
  static const String newBeginTime = EditWindow.defaultBeginTime;
  static const String newEndTime = EditWindow.defaultEndTime;

  static const String savedMessage = 'บันทึกระยะเวลาแก้ไขข้อมูลแล้ว';
  static const String dateRequiredMessage =
      'กรุณาเลือกวันเริ่มต้นและวันสิ้นสุด';
  static const String rangeHelpText = 'ช่วงวันที่เปิดให้แก้ไขข้อมูล';
  static const String timeFormatMessage =
      'กรอกเวลาเป็น ชั่วโมง:นาที เช่น 06:00 (00:00 - 23:59)';
  static const String orderMessage = 'วัน-เวลาสิ้นสุดต้องไม่ก่อนวัน-เวลาเริ่ม';
  static const String continuousNote =
      'เป็นช่วงต่อเนื่องช่วงเดียว นับจากวันเริ่มตามเวลาเริ่ม ไปจนถึงวันสิ้นสุดตามเวลาสิ้นสุด '
      'ระหว่างนั้นหน่วยงานแก้ไขข้อมูลได้ตลอดทั้งวันทั้งคืน ไม่ใช่ช่วงเวลาที่ซ้ำทุกวัน';
  static const String accountNote =
      'ฝ่ายบัญชีและผู้ดูแลระบบแก้ไขข้อมูลได้ตลอด ไม่ขึ้นกับระยะเวลานี้ '
      'ผู้ใช้ทั่วไปแก้ไขได้เฉพาะในระยะเวลานี้ (นอกช่วงยังดูรายการและรายงานได้)';

  @override
  State<EditWindowScreen> createState() => _EditWindowScreenState();
}

class _EditWindowScreenState extends State<EditWindowScreen> {
  final _settings = SettingsProvider();
  final _formKey = GlobalKey<FormState>();
  final _rangeText = TextEditingController();
  final _beginTime = TextEditingController();
  final _endTime = TextEditingController();

  EditWindow? _current;
  DateTime? _beginDate;
  DateTime? _endDate;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_rangeText, _beginTime, _endTime]) {
      c.dispose();
    }
    super.dispose();
  }

  void _use(EditWindow w) {
    _current = w;
    _beginDate = w.beginDate;
    _endDate = w.endDate;
    _rangeText.text = _rangeLabel();
    // backend ไม่มีเวลามา: โมเดลเติมเวลาตั้งต้นของงวด (06:00 / 16:30) ให้แล้ว
    _beginTime.text = w.beginTime;
    _endTime.text = w.endTime;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await widget.apiService.getEditWindow();
      if (!mounted) return;
      _settings.setEditWindow(w);
      setState(() {
        _use(w);
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

  /// ข้อความในช่องช่วงวันที่ เช่น "21 กันยายน 2569 – 5 ตุลาคม 2569" (ยังไม่ได้เลือก = ว่าง)
  String _rangeLabel() {
    final b = _beginDate;
    final e = _endDate;
    if (b == null || e == null) return '';
    return ThaiDateRangePickerDialog.rangeLabel(b, e);
  }

  /// เปิดปฏิทินเลือกวันเริ่ม-วันสิ้นสุดในครั้งเดียว
  Future<void> _pickRange() async {
    final b = _beginDate;
    final e = _endDate;
    final current = b != null && e != null && !e.isBefore(b)
        ? DateTimeRange(start: b, end: e)
        : null;
    final picked = widget.rangePicker != null
        ? await widget.rangePicker!(context, current)
        : await showThaiDateRangePicker(
            context,
            initialStart: b,
            initialEnd: e,
            helpText: EditWindowScreen.rangeHelpText,
          );
    // null = ผู้ใช้กดยกเลิก คงค่าเดิม
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      _beginDate = picked.start;
      _endDate = picked.end;
      _rangeText.text = _rangeLabel();
      // ไม่แตะช่องเวลา: เวลาที่โหลดมาหรือที่ผู้ใช้แก้ไว้คงอยู่ เติมค่าตั้งต้นเฉพาะช่องที่ว่าง
      if (_beginTime.text.trim().isEmpty) {
        _beginTime.text = EditWindowScreen.newBeginTime;
      }
      if (_endTime.text.trim().isEmpty) {
        _endTime.text = EditWindowScreen.newEndTime;
      }
    });
  }

  /// วัน+เวลาเป็นค่าเดียว ใช้เทียบลำดับเริ่ม/สิ้นสุด (เวลาผิดรูป = null)
  static DateTime? _moment(DateTime? date, String time) {
    final t = EditWindow.normalizeTime(time);
    if (date == null || t == null) return null;
    final p = t.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(p[0]),
      int.parse(p[1]),
    );
  }

  /// ข้อความสรุปช่วงที่กำลังจะบันทึก (ยังกรอกไม่ครบ = null)
  String? get _summary {
    final bt = EditWindow.normalizeTime(_beginTime.text);
    final et = EditWindow.normalizeTime(_endTime.text);
    if (_beginDate == null || _endDate == null || bt == null || et == null) {
      return null;
    }
    return 'แก้ไขได้ตั้งแต่ ${Util.formatThaiDate(_beginDate!)} เวลา $bt น. '
        'ถึง ${Util.formatThaiDate(_endDate!)} เวลา $et น.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final begin = _moment(_beginDate, _beginTime.text)!;
    final end = _moment(_endDate, _endTime.text)!;
    if (end.isBefore(begin)) {
      setState(() => _error = EditWindowScreen.orderMessage);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.apiService.updateEditWindow(
        beginDate: _beginDate!,
        endDate: _endDate!,
        beginTime: EditWindow.normalizeTime(_beginTime.text)!,
        endTime: EditWindow.normalizeTime(_endTime.text)!,
      );
      if (!mounted) return;
      _settings.setEditWindow(saved);
      setState(() {
        _use(saved);
        _saving = false;
      });
      context.showSuccessSnackBar(EditWindowScreen.savedMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  String? _validateTime(String? v) => EditWindow.normalizeTime(v) == null
      ? EditWindowScreen.timeFormatMessage
      : null;

  Widget _rangeField() => AccountField(
    key: EditWindowScreen.rangeKey,
    label: 'วันที่เริ่มต้น – วันที่สิ้นสุด',
    hint: 'แตะเพื่อเลือกช่วงวันที่จากปฏิทิน',
    icon: Icons.date_range,
    controller: _rangeText,
    enabled: !_saving,
    readOnly: true,
    onTap: _pickRange,
    helper:
        'ในปฏิทิน: แตะวันเริ่มต้นแล้วแตะวันสิ้นสุด หรือกดค้างแล้วลากจากวันเริ่มต้นไปวันสิ้นสุด',
    validator: (_) => _beginDate == null || _endDate == null
        ? EditWindowScreen.dateRequiredMessage
        : null,
  );

  Widget _timeField({required bool begin}) => AccountField(
    key: begin ? EditWindowScreen.beginTimeKey : EditWindowScreen.endTimeKey,
    label: begin ? 'เวลาเริ่มต้น (ชั่วโมง:นาที)' : 'เวลาสิ้นสุด (ชั่วโมง:นาที)',
    hint: begin ? EditWindow.defaultBeginTime : EditWindow.defaultEndTime,
    icon: Icons.schedule,
    controller: begin ? _beginTime : _endTime,
    enabled: !_saving,
    keyboardType: TextInputType.datetime,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
      LengthLimitingTextInputFormatter(5),
    ],
    validator: _validateTime,
    onChanged: (_) => setState(() => _error = null),
  );

  Widget _statusCard(EditWindow w) {
    final open = w.open;
    return StepCard(
      icon: open ? Icons.lock_open : Icons.lock_outline,
      title: 'สถานะตอนนี้',
      trailing: StatusChip(
        open ? 'เปิดให้แก้ไข' : 'ปิด',
        open ? AppTheme.successColor : AppTheme.dangerColor,
        key: EditWindowScreen.statusKey,
        solid: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w.rangeLabel, style: screenText(size: 16)),
          if (w.serverTime != null) ...[
            const SizedBox(height: 4),
            Text(
              'เวลาของระบบ ${Util.formatThaiDateTime(w.serverTime!)}',
              style: screenText(size: 13.5, color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            EditWindowScreen.accountNote,
            style: screenText(size: 13.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final summary = _summary;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, EditWindowScreen.groupTitle),
      body: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenHeader(
                    icon: EditWindowScreen.menuIcon,
                    title: EditWindowScreen.menuTitle,
                    subtitle:
                        'กำหนดช่วงวัน-เวลาที่หน่วยงานบันทึกและแก้ไขรายการหักหนี้ได้',
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
                    if (_current != null) ...[
                      _statusCard(_current!),
                      const SizedBox(height: 12),
                    ],
                    StepCard(
                      icon: Icons.edit_calendar,
                      title: 'กำหนดระยะเวลาใหม่',
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const NoticeBar(
                              type: NoticeType.info,
                              title: 'วิธีนับช่วงเวลา',
                              text:
                                  '${EditWindowScreen.continuousNote}\n'
                                  'ตัวอย่าง: เริ่ม 23 มิถุนายน เวลา 06:00 น. สิ้นสุด 3 กรกฎาคม เวลา 11:00 น. '
                                  '= แก้ไขได้ตั้งแต่เช้าวันที่ 23 มิถุนายน ต่อเนื่องถึง 11:00 น. ของวันที่ 3 กรกฎาคม',
                            ),
                            const SizedBox(height: 16),
                            _rangeField(),
                            const SizedBox(height: 14),
                            ResponsiveGrid(
                              minItemWidth: 220,
                              maxColumns: 2,
                              spacing: 14,
                              children: [
                                _timeField(begin: true),
                                _timeField(begin: false),
                              ],
                            ),
                            if (summary != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                summary,
                                key: EditWindowScreen.summaryKey,
                                style: screenText(
                                  size: 15.5,
                                  weight: FontWeight.w600,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: PrimaryActionButton(
                                key: EditWindowScreen.saveButtonKey,
                                label: 'บันทึกระยะเวลา',
                                icon: Icons.save_outlined,
                                loading: _saving,
                                onPressed: _save,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
