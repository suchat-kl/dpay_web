import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/period.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/screen_parts.dart';

/// กำหนดเดือนปี (งวดปัจจุบัน) — เมนู "ข้อมูลงวด" ของฝ่ายบัญชี (ACCOUNT)
///
/// อ่าน `GET /api/period` บันทึก `PUT /api/period {month, year}` (เดือน 2 หลัก ปี พ.ศ. 4 หลัก)
/// งวดปัจจุบันเป็นค่ากลางของทั้งระบบ ทุกหน่วยงานทำงานกับงวดนี้ จึงถามยืนยันก่อนบันทึก
/// บันทึกสำเร็จส่งค่าให้ [SettingsProvider] หน้าแรกและหน้าจออื่นเห็นงวดใหม่ทันที
class PeriodScreen extends StatefulWidget {
  final ApiService apiService;

  const PeriodScreen({super.key, required this.apiService});

  static const String menuTitle = 'กำหนดเดือนปี';
  static const IconData menuIcon = Icons.calendar_month;

  /// ชื่อกลุ่มเมนู (แสดงที่แถบบนของหน้าจอ)
  static const String groupTitle = 'ข้อมูลงวด';

  static const Key saveButtonKey = ValueKey('period-save');
  static const Key currentKey = ValueKey('period-current');
  static const Key selectedKey = ValueKey('period-selected');
  static const String savedMessage = 'บันทึกงวดปัจจุบันแล้ว';
  static const String timeResetNote =
      'เมื่อเปลี่ยนงวด เวลาของระยะเวลาแก้ไขข้อมูลจะกลับเป็น 06:00–16:30 น. '
      'โปรดกำหนดช่วงวันที่ของงวดใหม่';

  /// ช่วงปี พ.ศ. ที่เลือกได้ (backend รับปี 25xx)
  static const int minYear = 2550;
  static const int maxYear = 2599;

  @override
  State<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends State<PeriodScreen> {
  final _settings = SettingsProvider();

  Period? _current;
  late int _month;
  late int _year;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = (now.year + 543).clamp(PeriodScreen.minYear, PeriodScreen.maxYear);
    _load();
  }

  void _use(Period p) {
    _current = p;
    if (p.isValid) {
      _month = p.monthNumber!;
      _year = p.yearNumber!.clamp(PeriodScreen.minYear, PeriodScreen.maxYear);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final period = await widget.apiService.getPeriod();
      if (!mounted) return;
      _settings.setPeriod(period);
      setState(() {
        _use(period);
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

  Period get _selected => Period.of(_month, _year);

  bool get _changed =>
      _current == null ||
      _current!.monthNumber != _month ||
      _current!.yearNumber != _year;

  Future<void> _save() async {
    final target = _selected;
    final ok = await AppDialog.showConfirm(
      context,
      'กำหนดงวดปัจจุบันเป็น ${target.label} ใช่หรือไม่\n'
      'ทุกหน่วยงานจะทำงานกับงวดนี้ทันที',
      confirmText: 'บันทึก',
    );
    if (ok != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.apiService.updatePeriod(target);
      if (!mounted) return;
      _settings.setPeriod(saved);
      setState(() {
        _use(saved);
        _saving = false;
      });
      context.showSuccessSnackBar(PeriodScreen.savedMessage);
      // เปลี่ยนงวดแล้ว backend ตั้งเวลาของระยะเวลาแก้ไขกลับเป็นค่าตั้งต้น โหลดใหม่ให้ทุกหน้าจอเห็นค่าล่าสุด
      await _settings.load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, PeriodScreen.groupTitle),
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
                    icon: PeriodScreen.menuIcon,
                    title: PeriodScreen.menuTitle,
                    subtitle:
                        'เลือกเดือนและปี พ.ศ. ของงวดที่กำลังทำงาน ทุกหน่วยงานใช้งวดนี้ร่วมกัน',
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
                      icon: Icons.event_available,
                      title: 'งวดปัจจุบัน',
                      child: Text(
                        _current?.label ?? Period.notSetLabel,
                        key: PeriodScreen.currentKey,
                        style: screenText(
                          size: 22,
                          weight: FontWeight.w700,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StepCard(
                      icon: Icons.edit_calendar,
                      title: 'เลือกงวดใหม่',
                      subtitle: 'เลือกปี พ.ศ. แล้วเลือกเดือน',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          YearStepper(
                            year: _year,
                            min: PeriodScreen.minYear,
                            max: PeriodScreen.maxYear,
                            enabled: !_saving,
                            onChanged: (y) => setState(() => _year = y),
                          ),
                          const SizedBox(height: 14),
                          MonthPicker(
                            selected: _month,
                            enabled: !_saving,
                            onSelected: (m) => setState(() => _month = m),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'งวดที่เลือก: ${_selected.label}',
                            key: PeriodScreen.selectedKey,
                            style: screenText(
                              size: 16,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const NoticeBar(
                            type: NoticeType.info,
                            text: PeriodScreen.timeResetNote,
                          ),
                          const SizedBox(height: 14),
                          PrimaryActionButton(
                            key: PeriodScreen.saveButtonKey,
                            label: 'บันทึกงวดปัจจุบัน',
                            icon: Icons.save_outlined,
                            loading: _saving,
                            onPressed: _changed ? _save : null,
                          ),
                        ],
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
