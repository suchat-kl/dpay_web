import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/div_dept.dart';
import '../services/api_service.dart';
import 'account_form.dart';

/// ตัวเลือกหน่วยงานแบบค้นหาได้ จากรายการ [divs] ที่ผู้เรียกเตรียมมา
///
/// พิมพ์รหัสหรือชื่อบางส่วนเพื่อกรอง แล้วเลือกจากรายการ กว้างเต็มพื้นที่ที่มี (ใช้ได้ถึงจอ 320 จุด)
/// ใช้ตรง ๆ เมื่อมีรายการอยู่แล้ว (เช่นฟอร์มผู้ใช้ที่ใช้ `/api/admin/divs`)
/// ส่วนหน้าจอข้อมูลหักหนี้ใช้ [DivSelector] ที่โหลดรายการตามขอบเขตของผู้ใช้ให้เอง
class DivDropdown extends StatelessWidget {
  final List<DivDept> divs;

  /// รหัสหน่วยงานที่เลือกอยู่ null = ยังไม่ได้เลือก
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String label;

  /// ข้อความผิดพลาดใต้ช่อง (เช่น "กรุณาเลือกหน่วยงาน")
  final String? errorText;

  const DivDropdown({
    super.key,
    required this.divs,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.label = defaultLabel,
    this.errorText,
  });

  static const String defaultLabel = 'หน่วยงาน';
  static const String hint = 'พิมพ์รหัสหรือชื่อหน่วยงานเพื่อค้นหา';

  /// คีย์ของช่องพิมพ์ค้นหา ใช้หาในเทสต์
  static const Key fieldKey = ValueKey('div-dropdown');

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontFamily: kAccountFont, fontSize: 15);
    return DropdownMenu<String>(
      // เปลี่ยนค่าที่เลือกจากภายนอกหรือรายการเปลี่ยน ให้สร้างช่องใหม่ (ข้อความในช่องตามค่าใหม่)
      key: ValueKey('div-${value ?? ''}-${divs.length}'),
      initialSelection: divs.any((d) => d.div == value) ? value : null,
      enabled: enabled,
      // กว้างเต็มพื้นที่ของผู้ครอบ ไม่ล้นบนจอแคบ
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 320,
      label: Text(label, style: text),
      hintText: hint,
      errorText: errorText,
      textStyle: text.copyWith(color: AppTheme.textPrimary),
      leadingIcon: const Icon(Icons.apartment),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.fieldFillColor,
        hintStyle: text,
        errorStyle: const TextStyle(fontFamily: kAccountFont),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      onSelected: onChanged,
      dropdownMenuEntries: [
        for (final d in divs)
          DropdownMenuEntry<String>(
            value: d.div,
            label: d.label,
            style: MenuItemButton.styleFrom(textStyle: text),
          ),
      ],
    );
  }
}

/// ตัวเลือกหน่วยงานของหน้าจอข้อมูลหักหนี้ — ตามขอบเขตของผู้ที่เข้าสู่ระบบ (`GET /api/divs`)
///
/// - ขอบเขต OWN (หรือเลือกได้แห่งเดียว): แสดงหน่วยงานของตัวเองเฉย ๆ เปลี่ยนไม่ได้
/// - ขอบเขต CENTER / ALL: รายการเลือกแบบค้นหาได้ ค่าเริ่มต้น = [initialDiv] ไม่ส่ง = หน่วยงานของตัวเอง
///
/// โหลดเสร็จแจ้งค่าเริ่มต้นผ่าน [onChanged] หนึ่งครั้ง ผู้เรียกจึงเริ่มโหลดข้อมูลของหน่วยงานนั้นได้เลย
/// หน้าเว็บแค่จำกัดตัวเลือก backend ตรวจสิทธิ์กับหน่วยงานทุกคำขออีกชั้น (403 `DIV_FORBIDDEN`)
///
/// ```dart
/// DivSelector(
///   apiService: ApiService(),
///   onChanged: (div) => setState(() { _div = div; _reload(); }),
/// )
/// ```
class DivSelector extends StatefulWidget {
  final ApiService apiService;

  /// หน่วยงานที่เลือกไว้ก่อน (ไม่อยู่ในรายการที่เลือกได้ = ใช้หน่วยงานของตัวเอง)
  final String? initialDiv;

  /// หน่วยงานที่เลือก (รวมค่าเริ่มต้นหลังโหลดเสร็จ)
  final ValueChanged<DivDept> onChanged;
  final bool enabled;

  /// รายการที่โหลดไว้แล้ว ส่งมา = ไม่เรียก backend ซ้ำ
  final DivChoices? choices;

  const DivSelector({
    super.key,
    required this.apiService,
    required this.onChanged,
    this.initialDiv,
    this.enabled = true,
    this.choices,
  });

  /// คีย์ของกล่องแสดงหน่วยงานแบบเปลี่ยนไม่ได้ (ขอบเขต OWN)
  static const Key fixedKey = ValueKey('div-selector-fixed');
  static const String loadingText = 'กำลังโหลดรายชื่อหน่วยงาน...';

  @override
  State<DivSelector> createState() => _DivSelectorState();
}

class _DivSelectorState extends State<DivSelector> {
  DivChoices? _choices;
  String? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.choices != null) {
      // แจ้งค่าเริ่มต้นหลังเฟรมแรก ผู้เรียกมัก setState ใน onChanged
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _apply(widget.choices!);
      });
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final choices = await widget.apiService.getDivs();
      if (mounted) _apply(choices);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _apply(DivChoices choices) {
    final start =
        choices.find(widget.initialDiv) ??
        choices.find(choices.ownDiv) ??
        (choices.divs.isNotEmpty
            ? choices.divs.first
            // รหัสหน่วยงานของบัญชีไม่อยู่ในตารางหน่วยงาน: ยังใช้รหัสของตัวเองทำงานต่อได้
            : choices.ownDiv.isEmpty
            ? null
            : DivDept(div: choices.ownDiv, name: ''));
    setState(() {
      _choices = choices;
      _selected = start?.div;
    });
    if (start != null) widget.onChanged(start);
  }

  void _select(String? div) {
    final picked = _choices?.find(div);
    if (picked == null || picked.div == _selected) return;
    setState(() => _selected = picked.div);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    if (_error != null) {
      return AccountBanner.error('$_error', onClose: _load);
    }
    if (choices == null) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              DivSelector.loadingText,
              style: TextStyle(fontFamily: kAccountFont, fontSize: 14),
            ),
          ),
        ],
      );
    }
    if (!choices.selectable) {
      final own = choices.find(_selected);
      return _FixedDiv(label: own?.label ?? _selected ?? choices.ownDiv);
    }
    return DivDropdown(
      divs: choices.divs,
      value: _selected,
      enabled: widget.enabled,
      onChanged: _select,
    );
  }
}

/// กล่องแสดงหน่วยงานของตัวเอง (เลือกหน่วยงานอื่นไม่ได้)
class _FixedDiv extends StatelessWidget {
  final String label;

  const _FixedDiv({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: DivSelector.fixedKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.apartment, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DivDropdown.defaultLabel,
                  style: TextStyle(
                    fontFamily: kAccountFont,
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: kAccountFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
