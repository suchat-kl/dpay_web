// lib/widgets/thai_date_range_picker.dart
// ตัวเลือกช่วงวันที่ (วันเริ่ม - วันสิ้นสุด) ในปฏิทินเดียว แสดงปีเป็น พ.ศ. — เขียนเอง ไม่ใช้ package ภายนอก
//
// มาแทน SfDateRangePicker ของระบบเดิม (syncfusion ไม่รองรับปี พ.ศ. และมีเงื่อนไขสัญญาอนุญาต)
// ต่อยอดจากตัวเลือกวันเดี่ยว `thai_date_picker.dart`: หน้าตา ชื่อเดือน/วันไทย และตัวเลือกปี/เดือนแบบเดียวกัน
import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/util.dart';

const String _font = 'NotoSansThai';

/// เปิดปฏิทินเลือกช่วงวันที่แบบ พ.ศ. — คืนช่วงที่เลือก (ค.ศ. ตามปกติ ไม่มีเวลา) หรือ null เมื่อกดยกเลิก / Esc
///
/// - จอกว้างแสดงสองเดือนเคียงกัน จอแคบแสดงเดือนเดียว (เลื่อนเดือนได้)
/// - เลือกได้สองวิธี: แตะวันเริ่มแล้วแตะวันสิ้นสุด หรือกดค้างที่วันเริ่มแล้ว**ลาก**ไปวันสิ้นสุด (เมาส์และนิ้ว)
/// - แตะวันที่อยู่ก่อนวันเริ่ม = เริ่มช่วงใหม่ที่วันนั้น แตะวันเดิมซ้ำ = ช่วงวันเดียว (เริ่ม = สิ้นสุด)
/// - เลือกครบแล้วแตะอีกครั้ง = เริ่มเลือกช่วงใหม่
/// - [initialStart] / [initialEnd] ช่วงที่เลือกไว้ก่อน (ไม่ส่ง = ยังไม่เลือก เปิดที่เดือนของวันนี้)
/// - [firstDate] / [lastDate] ไม่ส่ง = พ.ศ. 2560-2580 วันนอกช่วงกดไม่ได้
/// - [today] วันที่ถือเป็น "วันนี้" ไม่ส่ง = วันที่จริง เทสต์ส่งวันตายตัวมาได้
///
/// ค่าที่ได้ให้แสดงด้วย `Util.formatThaiDate` และส่ง backend ด้วย `Util.formatChristianDate`
///
/// ```dart
/// final range = await showThaiDateRangePicker(
///   context,
///   initialStart: _begin,
///   initialEnd: _end,
/// );
/// if (range == null) return;            // ผู้ใช้กดยกเลิก
/// setState(() { _begin = range.start; _end = range.end; });
/// ```
Future<DateTimeRange?> showThaiDateRangePicker(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
  DateTime? firstDate,
  DateTime? lastDate,
  String helpText = 'เลือกช่วงวันที่',
  DateTime? today,
}) {
  final first = _dateOnly(firstDate ?? DateTime(2017, 1, 1)); // พ.ศ. 2560
  var last = _dateOnly(lastDate ?? DateTime(2037, 12, 31)); // พ.ศ. 2580
  if (last.isBefore(first)) last = first;
  DateTime clamp(DateTime d) {
    final v = _dateOnly(d);
    if (v.isBefore(first)) return first;
    if (v.isAfter(last)) return last;
    return v;
  }

  var start = initialStart == null ? null : clamp(initialStart);
  var end = initialEnd == null ? null : clamp(initialEnd);
  // มีแต่วันสิ้นสุด หรือสลับลำดับมา: จัดให้เป็นช่วงที่ถูกต้อง
  if (start == null && end != null) {
    start = end;
  }
  if (start != null && end != null && end.isBefore(start)) {
    final t = start;
    start = end;
    end = t;
  }

  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => ThaiDateRangePickerDialog(
      initialStart: start,
      initialEnd: end,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
      today: _dateOnly(today ?? DateTime.now()),
    ),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

enum _Mode { day, year, month }

/// หน้าต่างปฏิทินเลือกช่วงวันที่ พ.ศ. — ปกติเปิดผ่าน [showThaiDateRangePicker]
class ThaiDateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;
  final DateTime today;

  const ThaiDateRangePickerDialog({
    super.key,
    this.initialStart,
    this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    required this.today,
    this.helpText = 'เลือกช่วงวันที่',
  });

  /// จอกว้างตั้งแต่เท่านี้แสดงสองเดือนเคียงกัน
  static const double twoMonthMinWidth = 760;

  // ── คีย์ของ widget ใช้หาในเทสต์ ──
  /// ช่วงที่เลือกอยู่ (แถบหัวหน้าต่าง)
  static const Key rangeKey = ValueKey('tdrp-range');

  /// ปุ่มชื่อเดือนและปี พ.ศ. ของเดือนแรกที่แสดง (แตะเพื่อเลือกปี/เดือน)
  static const Key titleKey = ValueKey('tdrp-title');

  /// ชื่อเดือนและปี พ.ศ. ของเดือนที่สอง (มีเฉพาะตอนแสดงสองเดือน)
  static const Key secondTitleKey = ValueKey('tdrp-title-2');
  static const Key prevKey = ValueKey('tdrp-prev');
  static const Key nextKey = ValueKey('tdrp-next');
  static const Key todayKey = ValueKey('tdrp-today');
  static const Key okKey = ValueKey('tdrp-ok');
  static const Key cancelKey = ValueKey('tdrp-cancel');

  /// ช่องของวันที่ [date] (ต้องอยู่ในเดือนที่แสดงอยู่)
  static Key dayKey(DateTime date) =>
      ValueKey('tdrp-day-${Util.formatChristianDate(date)}');

  /// ปี พ.ศ. [buddhistYear] ในตัวเลือกปี
  static Key yearKey(int buddhistYear) => ValueKey('tdrp-year-$buddhistYear');

  /// เดือน 1-12 ในตัวเลือกเดือน
  static Key monthKey(int month) => ValueKey('tdrp-month-$month');

  /// หัวคอลัมน์วันในสัปดาห์ เริ่มวันอาทิตย์
  static const List<String> weekdayLabels = [
    'อา',
    'จ',
    'อ',
    'พ',
    'พฤ',
    'ศ',
    'ส',
  ];

  static const String pickStartText = 'แตะหรือลากเพื่อเลือกวันเริ่มต้น';
  static const String pickEndText = 'เลือกวันสิ้นสุด';

  /// ข้อความของช่วงวันที่ เช่น "21 กันยายน 2569 – 5 ตุลาคม 2569" (วันเดียว = วันนั้นวันเดียว)
  static String rangeLabel(DateTime start, DateTime end) => start == end
      ? Util.formatThaiDate(start)
      : '${Util.formatThaiDate(start)} – ${Util.formatThaiDate(end)}';

  @override
  State<ThaiDateRangePickerDialog> createState() =>
      _ThaiDateRangePickerDialogState();
}

class _ThaiDateRangePickerDialogState extends State<ThaiDateRangePickerDialog> {
  late DateTime? _start = widget.initialStart;
  late DateTime? _end = widget.initialEnd;

  /// เดือนแรกที่ตารางแสดงอยู่ (วันที่ 1 ของเดือนนั้น) ตอนแสดงสองเดือน เดือนที่สอง = เดือนถัดไป
  late DateTime _shown = _monthOf(widget.initialStart ?? _clamp(widget.today));
  _Mode _mode = _Mode.day;

  /// ตารางวันของแต่ละเดือนที่แสดงอยู่ ใช้หาว่าตัวชี้อยู่บนวันไหนตอนลาก
  final List<GlobalKey> _gridKeys = [GlobalKey(), GlobalKey()];

  /// วันที่กดลงตอนเริ่มลาก (null = ไม่ได้กดอยู่บนวันที่เลือกได้)
  DateTime? _dragAnchor;

  /// ลากข้ามไปวันอื่นแล้ว (ไม่ใช่แค่แตะ)
  bool _dragging = false;

  /// เพิ่งลากเสร็จ: การแตะที่ตามมาจากนิ้วเดียวกันไม่นับเป็นการเลือกใหม่
  bool _justDragged = false;

  late ScrollController _yearScroll = _newYearScroll();

  static const double _bodyHeight = 288;
  static const double _weekdayHeight = 32;
  static const double _yearRowHeight = 48;
  static const int _yearColumns = 3;

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  DateTime _clamp(DateTime d) {
    if (d.isBefore(widget.firstDate)) return widget.firstDate;
    if (d.isAfter(widget.lastDate)) return widget.lastDate;
    return d;
  }

  ScrollController _newYearScroll() {
    final row = (_shown.year - widget.firstDate.year) ~/ _yearColumns;
    final offset = row * _yearRowHeight - _bodyHeight / 2 + _yearRowHeight / 2;
    return ScrollController(initialScrollOffset: offset < 0 ? 0 : offset);
  }

  void _openYears() {
    _yearScroll.dispose();
    setState(() {
      _yearScroll = _newYearScroll();
      _mode = _Mode.year;
    });
  }

  @override
  void dispose() {
    _yearScroll.dispose();
    super.dispose();
  }

  bool _inRange(DateTime d) =>
      !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);

  /// เดือนนี้มีวันที่เลือกได้อย่างน้อยหนึ่งวัน
  bool _monthInRange(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month, _daysInMonth(year, month));
    return !end.isBefore(widget.firstDate) && !start.isAfter(widget.lastDate);
  }

  bool get _canPrev {
    final p = DateTime(_shown.year, _shown.month - 1);
    return _monthInRange(p.year, p.month);
  }

  bool _canNext(int months) {
    // เลื่อนต่อได้ถ้าเดือนที่จะโผล่มาใหม่ทางขวายังมีวันที่เลือกได้
    final n = DateTime(_shown.year, _shown.month + months);
    return _monthInRange(n.year, n.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _shown = DateTime(_shown.year, _shown.month + delta));

  /// ไปเดือน [month] ของปี [year] (ปรับเข้าช่วง first/last) ช่วงที่เลือกไว้ไม่เปลี่ยน
  void _showMonth(int year, int month) {
    var d = DateTime(year, month);
    if (!_monthInRange(d.year, d.month)) {
      d = d.isBefore(widget.firstDate)
          ? _monthOf(widget.firstDate)
          : _monthOf(widget.lastDate);
    }
    _shown = d;
  }

  void _pickYear(int year) => setState(() {
    _showMonth(year, _shown.month);
    _mode = _Mode.month;
  });

  void _pickMonth(int month) => setState(() {
    _showMonth(_shown.year, month);
    _mode = _Mode.day;
  });

  /// ปุ่ม "วันนี้": พาไปเดือนปัจจุบัน (ไม่เปลี่ยนช่วงที่เลือก)
  void _goToday() => setState(() {
    final t = _clamp(widget.today);
    _showMonth(t.year, t.month);
    _mode = _Mode.day;
  });

  /// แตะวัน (หรือกด Enter บนวันที่โฟกัสอยู่)
  void _tapDay(DateTime date) {
    if (_justDragged) {
      _justDragged = false;
      return;
    }
    setState(() {
      final start = _start;
      if (start == null || _end != null || date.isBefore(start)) {
        // ยังไม่เริ่ม / เลือกครบแล้ว / แตะวันก่อนวันเริ่ม = เริ่มช่วงใหม่ที่วันนี้
        _start = date;
        _end = null;
      } else {
        _end = date;
      }
    });
  }

  // ── ลากเลือกช่วง ──

  /// วันที่ใต้ตำแหน่ง [global] ของจอ (ไม่อยู่บนวันที่เลือกได้ = null)
  DateTime? _dateAt(Offset global) {
    for (var i = 0; i < _gridKeys.length; i++) {
      final box = _gridKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final p = box.globalToLocal(global);
      final size = box.size;
      if (p.dx < 0 || p.dy < _weekdayHeight) continue;
      if (p.dx >= size.width || p.dy >= size.height) continue;
      final col = (p.dx / (size.width / 7)).floor();
      final row =
          ((p.dy - _weekdayHeight) / ((size.height - _weekdayHeight) / 6))
              .floor();
      final month = DateTime(_shown.year, _shown.month + i);
      final day =
          row * 7 + col - DateTime(month.year, month.month).weekday % 7 + 1;
      if (day < 1 || day > _daysInMonth(month.year, month.month)) return null;
      final date = DateTime(month.year, month.month, day);
      return _inRange(date) ? date : null;
    }
    return null;
  }

  void _pointerDown(PointerDownEvent e) {
    _justDragged = false;
    _dragging = false;
    _dragAnchor = _mode == _Mode.day ? _dateAt(e.position) : null;
  }

  void _pointerMove(PointerMoveEvent e) {
    final anchor = _dragAnchor;
    if (anchor == null) return;
    final date = _dateAt(e.position);
    if (date == null) return;
    // ยังอยู่บนวันที่กดลง = อาจเป็นแค่การแตะ ยังไม่ถือว่าลาก
    if (!_dragging && date == anchor) return;
    final start = date.isBefore(anchor) ? date : anchor;
    final end = date.isBefore(anchor) ? anchor : date;
    if (_dragging && start == _start && end == _end) return;
    setState(() {
      _dragging = true;
      _start = start;
      _end = end;
    });
  }

  void _pointerEnd(PointerEvent e) {
    if (_dragging) {
      // การแตะที่อาจตามมาจากการปล่อยนิ้วครั้งนี้ถูกเรียกในรอบเหตุการณ์เดียวกัน จบรอบแล้วเลิกกัน
      // (ไม่งั้นการกด Enter ครั้งถัดไปจะถูกมองข้าม)
      _justDragged = true;
      scheduleMicrotask(() => _justDragged = false);
    }
    _dragging = false;
    _dragAnchor = null;
  }

  String _monthTitle(DateTime month) =>
      '${Util.thaiMonthName(month.month)} ${Util.buddhistYear(month)}';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final twoMonths = width >= ThaiDateRangePickerDialog.twoMonthMinWidth;
    final months = twoMonths ? 2 : 1;
    return Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 400 ? 12 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: twoMonths ? 700 : 360),
        // จอเตี้ยเลื่อนทั้งหน้าต่างได้ ไม่ล้นกรอบ
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildNavBar(months),
              SizedBox(
                height: _bodyHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: switch (_mode) {
                    _Mode.day => _buildDayArea(months),
                    _Mode.year => _buildYears(),
                    _Mode.month => _buildMonths(),
                  },
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  /// แถบหัว: คำอธิบาย + ช่วงที่เลือกอยู่เป็นวันที่ไทย
  Widget _buildHeader() {
    final start = _start;
    final end = _end;
    final text = start == null
        ? ThaiDateRangePickerDialog.pickStartText
        : end == null
        ? '${Util.formatThaiDate(start)} – ${ThaiDateRangePickerDialog.pickEndText}'
        : ThaiDateRangePickerDialog.rangeLabel(start, end);
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.helpText,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            key: ThaiDateRangePickerDialog.rangeKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// แถวเลื่อนเดือน: ◀ ชื่อเดือน + ปี พ.ศ. (แตะเพื่อเลือกปี/เดือน) [ชื่อเดือนที่สอง] ▶
  Widget _buildNavBar(int months) {
    final dayMode = _mode == _Mode.day;
    const titleStyle = TextStyle(
      fontFamily: _font,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          IconButton(
            key: ThaiDateRangePickerDialog.prevKey,
            tooltip: 'เดือนก่อนหน้า',
            icon: const Icon(Icons.chevron_left),
            color: AppTheme.primaryColor,
            onPressed: dayMode && _canPrev ? () => _shiftMonth(-1) : null,
          ),
          Expanded(
            child: Center(
              child: TextButton(
                key: ThaiDateRangePickerDialog.titleKey,
                // แตะซ้ำตอนอยู่ในตัวเลือกปี/เดือน = กลับไปตารางวัน
                onPressed: dayMode
                    ? _openYears
                    : () => setState(() => _mode = _Mode.day),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _monthTitle(_shown),
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    Icon(
                      dayMode ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (months == 2 && dayMode)
            Expanded(
              child: Center(
                child: Text(
                  _monthTitle(DateTime(_shown.year, _shown.month + 1)),
                  key: ThaiDateRangePickerDialog.secondTitleKey,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle.copyWith(color: AppTheme.primaryDark),
                ),
              ),
            ),
          IconButton(
            key: ThaiDateRangePickerDialog.nextKey,
            tooltip: 'เดือนถัดไป',
            icon: const Icon(Icons.chevron_right),
            color: AppTheme.primaryColor,
            onPressed: dayMode && _canNext(months)
                ? () => _shiftMonth(1)
                : null,
          ),
        ],
      ),
    );
  }

  /// ตารางวันหนึ่งหรือสองเดือน ครอบด้วยตัวฟังตัวชี้ดิบสำหรับการลากเลือกช่วง
  /// (ใช้ Listener ไม่เข้าแข่งกับการแตะของแต่ละวัน: แตะ = เลือกทีละปลาย, ลากข้ามวัน = เลือกทั้งช่วง)
  Widget _buildDayArea(int months) {
    return Listener(
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerEnd,
      onPointerCancel: _pointerEnd,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < months; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(
              child: KeyedSubtree(
                key: _gridKeys[i],
                child: _buildDays(DateTime(_shown.year, _shown.month + i)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ตารางวันของเดือน [month] สัปดาห์เริ่มวันอาทิตย์
  Widget _buildDays(DateTime month) {
    final days = _daysInMonth(month.year, month.month);
    // DateTime.weekday: จันทร์ = 1 ... อาทิตย์ = 7 → คอลัมน์ของวันที่ 1 (อาทิตย์ = 0)
    final offset = month.weekday % 7;
    final start = _start;
    final end = _end;

    Widget cell(int index) {
      final day = index - offset + 1;
      if (day < 1 || day > days) return const SizedBox.shrink();
      final date = DateTime(month.year, month.month, day);
      final isStart = date == start;
      final isEnd = date == end;
      final hasRange = start != null && end != null && start != end;
      final between = hasRange && date.isAfter(start) && date.isBefore(end);
      return _RangeDayCell(
        key: ThaiDateRangePickerDialog.dayKey(date),
        day: day,
        label: Util.formatThaiDateWithWeekday(date),
        edge: isStart || isEnd,
        between: between,
        // แถบแรเงาครึ่งช่องที่ปลายช่วง ให้ต่อเนื่องกับวันข้างเคียง (ไม่ข้ามขอบสัปดาห์)
        bandRight: hasRange && isStart && index % 7 != 6,
        bandLeft: hasRange && isEnd && index % 7 != 0,
        today: date == widget.today,
        enabled: _inRange(date),
        autofocus: isStart,
        onTap: () => _tapDay(date),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: _weekdayHeight,
          child: Row(
            children: [
              for (final w in ThaiDateRangePickerDialog.weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var row = 0; row < 6; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: cell(row * 7 + col)),
              ],
            ),
          ),
      ],
    );
  }

  /// ตัวเลือกปี พ.ศ. ทุกปีในช่วง first-last เลื่อนได้ เปิดมาเห็นปีที่แสดงอยู่
  Widget _buildYears() {
    final firstYear = widget.firstDate.year;
    final count = widget.lastDate.year - firstYear + 1;
    return GridView.builder(
      controller: _yearScroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _yearColumns,
        mainAxisExtent: _yearRowHeight,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final year = firstYear + i;
        return _ChoiceCell(
          key: ThaiDateRangePickerDialog.yearKey(year + 543),
          text: '${year + 543}',
          selected: year == _shown.year,
          marked: year == widget.today.year,
          onTap: () => _pickYear(year),
        );
      },
    );
  }

  /// ตัวเลือกเดือน 12 เดือนของปีที่เลือก เดือนที่อยู่นอกช่วงกดไม่ได้
  Widget _buildMonths() {
    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final month = row * 3 + col + 1;
                        return _ChoiceCell(
                          key: ThaiDateRangePickerDialog.monthKey(month),
                          text: Util.thaiMonthName(month),
                          selected: month == _shown.month,
                          marked:
                              _shown.year == widget.today.year &&
                              month == widget.today.month,
                          onTap: _monthInRange(_shown.year, month)
                              ? () => _pickMonth(month)
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// ปุ่มท้ายหน้าต่าง: วันนี้ (ซ้าย) ยกเลิก / ตกลง (ขวา) ตกลงกดได้เมื่อเลือกครบทั้งวันเริ่มและวันสิ้นสุด
  Widget _buildActions() {
    final start = _start;
    final end = _end;
    const text = TextStyle(fontFamily: _font, fontSize: 15);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 10),
      child: Row(
        children: [
          TextButton(
            key: ThaiDateRangePickerDialog.todayKey,
            onPressed: _goToday,
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryDark),
            child: const Text('วันนี้', style: text),
          ),
          const Spacer(),
          TextButton(
            key: ThaiDateRangePickerDialog.cancelKey,
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AppTheme.cancelColor),
            child: const Text('ยกเลิก', style: text),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: ThaiDateRangePickerDialog.okKey,
            onPressed: start == null || end == null
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(DateTimeRange(start: start, end: end)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'ตกลง',
              style: text.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// หนึ่งวันในตารางช่วงวันที่: วงกลมทึบ = ปลายช่วง แถบสีอ่อน = อยู่ในช่วง วงเส้นขอบ = วันนี้ สีจาง = นอกช่วง
class _RangeDayCell extends StatelessWidget {
  final int day;

  /// วันที่เต็มสำหรับโปรแกรมอ่านหน้าจอ เช่น "ศุกร์ 16 มกราคม 2569"
  final String label;

  /// เป็นวันเริ่มหรือวันสิ้นสุดของช่วง
  final bool edge;

  /// อยู่ระหว่างวันเริ่มกับวันสิ้นสุด
  final bool between;
  final bool bandLeft;
  final bool bandRight;
  final bool today;
  final bool enabled;
  final bool autofocus;
  final VoidCallback onTap;

  const _RangeDayCell({
    super.key,
    required this.day,
    required this.label,
    required this.edge,
    required this.between,
    required this.bandLeft,
    required this.bandRight,
    required this.today,
    required this.enabled,
    required this.autofocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    final band = primary.withValues(alpha: 0.16);
    final color = !enabled
        ? Colors.grey.shade400
        : edge
        ? Colors.white
        : today
        ? primary
        : AppTheme.textPrimary;
    return Stack(
      alignment: Alignment.center,
      children: [
        // แถบแรเงาของช่วงที่เลือก สูงเท่าวงกลม เต็มความกว้างช่อง (หรือครึ่งช่องที่ปลายช่วง)
        if (between || bandLeft || bandRight)
          Positioned.fill(
            child: Center(
              child: SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: between || bandLeft ? band : Colors.transparent,
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: between || bandRight ? band : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Semantics(
          button: true,
          enabled: enabled,
          selected: edge || between,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: edge ? primary : Colors.transparent,
            shape: CircleBorder(
              side: today && !edge
                  ? BorderSide(color: primary, width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              autofocus: autofocus,
              onTap: enabled ? onTap : null,
              focusColor: primary.withValues(alpha: 0.18),
              hoverColor: primary.withValues(alpha: 0.08),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 14.5,
                      fontWeight: edge || today
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// หนึ่งช่องของตัวเลือกปี/เดือน: พื้นทึบ = ค่าที่แสดงอยู่ เส้นขอบ = ปี/เดือนปัจจุบัน
/// [onTap] เป็น null = นอกช่วง กดไม่ได้
class _ChoiceCell extends StatelessWidget {
  final String text;
  final bool selected;
  final bool marked;
  final VoidCallback? onTap;

  const _ChoiceCell({
    super.key,
    required this.text,
    required this.selected,
    required this.marked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: selected ? primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: marked && !selected
              ? BorderSide(color: primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: selected,
          onTap: onTap,
          focusColor: primary.withValues(alpha: 0.18),
          hoverColor: primary.withValues(alpha: 0.08),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: !enabled
                        ? Colors.grey.shade400
                        : selected
                        ? Colors.white
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
