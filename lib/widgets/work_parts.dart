// ชิ้นส่วนร่วมของหน้าจองานประจำงวด (ระยะที่ 3): โครงหน้า แถวข้อมูล ตัวเลือกงวด และตัวช่วยดาวน์โหลดไฟล์
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/period.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../utils/file_download.dart';
import '../utils/money.dart';
import '../utils/util.dart';
import 'screen_parts.dart';

int intOf(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// จำนวนนับมีจุลภาค (null = "-")
String countText(Object? v) => v == null ? '-' : Util.formatCount(intOf(v));

/// จำนวนเงินมีจุลภาค ทศนิยม 2 ตำแหน่ง (null = "-")
String moneyText(Object? v) =>
    v == null ? '-' : Money.format(Money.fromJson(v));

/// ข้อความของ 409 `NOT_CURRENT_PERIOD` ในงานนำเข้า (งวดปัจจุบันถูกเปลี่ยนระหว่างที่เปิดหน้าค้างไว้)
const String periodChangedHint =
    'งานนี้ทำได้เฉพาะงวดปัจจุบัน และงวดปัจจุบันถูกเปลี่ยนระหว่างที่เปิดหน้านี้อยู่\n'
    'ยังไม่มีอะไรถูกบันทึก กรุณาปิดหน้านี้แล้วเปิดใหม่เพื่อทำงานกับงวดปัจจุบัน';

/// ข้อความที่แสดงเมื่องานนำเข้าถูกปฏิเสธเพราะไม่ใช่งวดปัจจุบัน และสั่งโหลดงวดใหม่ให้หน้าจออื่นเห็นด้วย
String periodChangedMessage(ApiException e) {
  SettingsProvider().load();
  return '${e.message}\n$periodChangedHint';
}

/// โครงหน้าของงานประจำงวด: แถบบนชื่อกลุ่ม + เนื้อหากว้างไม่เกิน [maxWidth]
class WorkPage extends StatelessWidget {
  final String group;
  final double maxWidth;
  final List<Widget> children;

  const WorkPage({
    super.key,
    required this.group,
    required this.children,
    this.maxWidth = 980,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, group),
      body: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แถว "ป้าย ........ ค่า" ของการ์ดสรุป
class FactRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const FactRow(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(label, style: screenText(color: AppTheme.textSecondary)),
        ),
        Expanded(
          flex: 4,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: screenText(
              weight: FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// ตัวเลือกงวด: บรรทัดสรุป + ปุ่มเปิดแผงเลือกปี/เดือน — เลือกเกินงวดปัจจุบันไม่ได้
///
/// [past] = งวดย้อนหลังที่เลือกอยู่ (null = งวดปัจจุบัน) เลือกงวดปัจจุบัน = แจ้ง [onChanged] ด้วย null
/// ผู้เรียกเป็นผู้ตั้งค่า (เช่น ถามก่อนทิ้งการแก้ไข) ตัวเลือกนี้ไม่เก็บงวดเอง
class PeriodPicker extends StatefulWidget {
  final Period? past;
  final ValueChanged<Period?> onChanged;
  final bool enabled;

  const PeriodPicker({
    super.key,
    required this.past,
    required this.onChanged,
    this.enabled = true,
  });

  static const Key labelKey = ValueKey('period-label');
  static const Key buttonKey = ValueKey('period-change');

  /// ปีแรกสุดที่ย้อนดูได้ (พ.ศ.)
  static const int minYear = 2550;

  @override
  State<PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<PeriodPicker> {
  bool _open = false;

  void _pick(int month, int year) {
    final current = SettingsProvider().period;
    if (current == null || !current.isValid) return;
    final cm = current.monthNumber!;
    final cy = current.yearNumber!;
    if (year > cy) year = cy;
    if (year == cy && month > cm) month = cm;
    final next = year == cy && month == cm ? null : Period.of(month, year);
    if (next?.month == widget.past?.month && next?.year == widget.past?.year) {
      return;
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final current = SettingsProvider().period;
    final shown = widget.past ?? current;
    if (current == null || !current.isValid || shown == null) {
      return const SizedBox.shrink();
    }
    final cy = current.yearNumber!;
    final year = shown.yearNumber!;
    final month = shown.monthNumber!;
    final isPast = widget.past != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'งวด ${shown.label}',
                key: PeriodPicker.labelKey,
                style: screenText(size: 15, weight: FontWeight.w700),
              ),
              StatusChip(
                isPast ? 'งวดย้อนหลัง' : 'งวดปัจจุบัน',
                isPast ? AppTheme.infoColor : AppTheme.successColor,
              ),
              TextButton.icon(
                key: PeriodPicker.buttonKey,
                onPressed: () => setState(() => _open = !_open),
                icon: Icon(
                  _open ? Icons.expand_less : Icons.event_note,
                  size: 18,
                ),
                label: Text(
                  _open ? 'ซ่อนตัวเลือกงวด' : 'ดูงวดอื่น',
                  style: screenText(size: 14, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: YearStepper(
                year: year,
                min: PeriodPicker.minYear < cy ? PeriodPicker.minYear : cy,
                max: cy,
                enabled: widget.enabled,
                onChanged: (y) => _pick(month, y),
              ),
            ),
            const SizedBox(height: 10),
            MonthPicker(
              selected: month,
              enabled: widget.enabled,
              // ปีเดียวกับงวดปัจจุบัน: เลือกได้ไม่เกินเดือนของงวดปัจจุบัน
              lastMonth: year == cy ? current.monthNumber : null,
              onSelected: (m) => _pick(m, year),
            ),
          ],
        ],
      ),
    );
  }
}

/// ตัวช่วยดาวน์โหลดไฟล์ของหน้าจอ: กันกดซ้ำ ส่งไฟล์ให้เบราว์เซอร์ผ่าน [FileSaver] และเก็บตัวจับไว้ให้ "เปิดดู"
///
/// ไฟล์มีข้อมูลบุคคล — อยู่ในหน่วยความจำของแท็บจนปิดหน้าจอ ([dispose] คืนหน่วยความจำ) ไม่เก็บลง storage
mixin FileDownloads<T extends StatefulWidget> on State<T> {
  final Map<String, SavedFile> _saved = {};

  /// คีย์ของไฟล์ที่กำลังสร้าง/ดาวน์โหลด (null = ว่าง) ระหว่างนี้ปุ่มดาวน์โหลดทุกปุ่มกดไม่ได้
  String? downloading;

  /// ข้อความผิดพลาดของการดาวน์โหลดล่าสุด
  String? downloadError;

  SavedFile? savedOf(String key) => _saved[key];

  /// ทิ้งไฟล์ที่ดาวน์โหลดไว้ทั้งหมด (เช่น เปลี่ยนงวด/หน่วยงานแล้วไฟล์เดิมไม่ตรงกับตัวเลือก)
  void clearSaved() {
    for (final f in _saved.values) {
      f.dispose();
    }
    _saved.clear();
  }

  /// ดาวน์โหลดไฟล์ของ [key] — คืนจริงเมื่อสำเร็จ
  /// [onError] คืนจริง = ผู้เรียกจัดการข้อผิดพลาดเองแล้ว (ไม่ตั้ง [downloadError])
  Future<bool> runDownload(
    String key,
    Future<DownloadedFile> Function() fetch, {
    bool Function(ApiException e)? onError,
  }) async {
    if (downloading != null) return false;
    setState(() {
      downloading = key;
      downloadError = null;
    });
    try {
      final file = await fetch();
      if (!mounted) return false;
      _saved.remove(key)?.dispose();
      final saved = FileSaver.instance.save(file);
      setState(() {
        _saved[key] = saved;
        downloading = null;
      });
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      final handled = onError?.call(e) ?? false;
      setState(() {
        downloading = null;
        if (!handled) downloadError = e.message;
      });
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        downloading = null;
        downloadError = e.toString();
      });
    }
    return false;
  }

  @override
  void dispose() {
    clearSaved();
    super.dispose();
  }
}

/// ปุ่มดาวน์โหลดของ [FileDownloads]: ระหว่างสร้างไฟล์แสดงวงหมุน เสร็จแล้วมีปุ่ม "เปิดดู" (เฉพาะไฟล์ที่เปิดในเบราว์เซอร์ได้)
class DownloadButtons extends StatelessWidget {
  final String label;
  final IconData icon;

  /// กำลังสร้างไฟล์นี้อยู่
  final bool busy;

  /// มีไฟล์อื่นกำลังสร้างอยู่ (กดไม่ได้)
  final bool blocked;
  final VoidCallback onDownload;

  /// ไฟล์ที่ดาวน์โหลดแล้ว (มี = แสดงปุ่มเปิดดูเมื่อ [canOpen])
  final SavedFile? saved;
  final bool canOpen;
  final Color? color;

  const DownloadButtons({
    super.key,
    required this.label,
    required this.onDownload,
    this.icon = Icons.download,
    this.busy = false,
    this.blocked = false,
    this.saved,
    this.canOpen = false,
    this.color,
  });

  static const String openLabel = 'เปิดดู';
  static const String busyLabel = 'กำลังสร้างไฟล์...';

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.primaryColor;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: busy || blocked ? null : onDownload,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18),
          label: Text(
            busy ? busyLabel : label,
            style: screenText(size: 14, color: Colors.white),
          ),
        ),
        if (saved != null && canOpen)
          OutlinedButton.icon(
            onPressed: saved!.open,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(openLabel, style: screenText(size: 14)),
          ),
        if (saved != null)
          Text(
            'ดาวน์โหลดแล้ว: ${saved!.fileName}',
            style: screenText(size: 12.5, color: AppTheme.successColor),
          ),
      ],
    );
  }
}
