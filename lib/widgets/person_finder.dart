import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../services/api_service.dart';
import '../services/debt_api.dart';
import '../utils/money.dart';
import 'screen_parts.dart';
import 'sheet_table.dart';

/// ช่องค้นหาบุคคลของหน้าทะเบียนฝ่ายบัญชี: พิมพ์เลขประจำตัวประชาชน หรือค้นด้วยชื่อ-สกุลแล้วเลือกจากรายการ
///
/// - เลขบัตร: ตรวจ 13 หลักและหลักตรวจสอบก่อนแจ้ง [onPicked]
/// - ชื่อ-สกุล: `POST /api/persons/search` ทุกหน่วยงานของงวดปัจจุบัน (ต้องมีขอบเขตทุกหน่วยงาน) เลือกแล้วแจ้ง [onPicked]
///
/// เลขบัตรและชื่อส่งในตัวคำขอเท่านั้น ไม่อยู่ใน URL และไม่ลง log รายการผลค้นแสดงเลขบัตรแบบปิดบางส่วน
class PersonFinder extends StatefulWidget {
  final ApiService apiService;

  /// เลขประจำตัวประชาชน 13 หลักของคนที่เลือก
  final ValueChanged<String> onPicked;
  final bool enabled;

  const PersonFinder({
    super.key,
    required this.apiService,
    required this.onPicked,
    this.enabled = true,
  });

  static const Key idcardKey = ValueKey('finder-idcard');
  static const Key idcardButtonKey = ValueKey('finder-idcard-go');
  static const Key nameKey = ValueKey('finder-name');
  static const Key surnameKey = ValueKey('finder-surname');
  static const Key nameButtonKey = ValueKey('finder-name-go');
  static const String nameRequired =
      'กรุณากรอกชื่อหรือนามสกุลอย่างน้อยหนึ่งช่อง';
  static const String noResult = 'ไม่พบบุคคลตามชื่อที่ค้นในงวดปัจจุบัน';

  static const String truncatedText =
      'พบมากกว่า 50 คน แสดง 50 คนแรก กรุณาพิมพ์ชื่อหรือนามสกุลให้เจาะจงขึ้น';

  /// คีย์ของผลค้นลำดับที่ [index]
  static Key resultKey(int index) => ValueKey('finder-result-$index');

  @override
  State<PersonFinder> createState() => _PersonFinderState();
}

class _PersonFinderState extends State<PersonFinder> {
  final _idcard = TextEditingController();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  List<PersonHit>? _results;

  /// ผลค้นถูกตัดที่ 50 คน (ยังมีอีก)
  bool _truncated = false;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _idcard.dispose();
    _name.dispose();
    _surname.dispose();
    super.dispose();
  }

  void _byIdcard() {
    final id = IdCard.clean(_idcard.text);
    if (!IdCard.isValid(id)) {
      setState(() => _error = IdCard.invalidMessage);
      return;
    }
    setState(() {
      _error = null;
      _results = null;
    });
    widget.onPicked(id);
  }

  Future<void> _byName() async {
    if (_name.text.trim().isEmpty && _surname.text.trim().isEmpty) {
      setState(() => _error = PersonFinder.nameRequired);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    try {
      final (items, truncated) = await widget.apiService.searchPersons(
        name: _name.text,
        surname: _surname.text,
      );
      if (!mounted) return;
      setState(() {
        _results = items;
        _truncated = truncated;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

  void _pick(PersonHit row) {
    setState(() {
      _idcard.text = row.idcard;
      _results = null;
      _error = null;
    });
    widget.onPicked(row.idcard);
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    labelStyle: screenText(color: AppTheme.textSecondary),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.dividerColor),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final enabled = widget.enabled && !_searching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                key: PersonFinder.idcardKey,
                controller: _idcard,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                style: screenText(),
                decoration: _deco('เลขประจำตัวประชาชน 13 หลัก'),
                onSubmitted: (_) => _byIdcard(),
              ),
            ),
            SheetButton(
              'ค้นด้วยเลขบัตร',
              key: PersonFinder.idcardButtonKey,
              icon: Icons.search,
              color: AppTheme.searchColor,
              onPressed: enabled ? _byIdcard : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: TextField(
                key: PersonFinder.nameKey,
                controller: _name,
                enabled: enabled,
                style: screenText(),
                decoration: _deco('ชื่อ'),
                onSubmitted: (_) => _byName(),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                key: PersonFinder.surnameKey,
                controller: _surname,
                enabled: enabled,
                style: screenText(),
                decoration: _deco('นามสกุล'),
                onSubmitted: (_) => _byName(),
              ),
            ),
            SheetButton(
              'ค้นด้วยชื่อ',
              key: PersonFinder.nameButtonKey,
              icon: Icons.person_search,
              onPressed: enabled ? _byName : null,
            ),
          ],
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          NoticeBar(
            type: NoticeType.error,
            text: _error!,
            onClose: () => setState(() => _error = null),
          ),
        ],
        if (results != null) ...[
          const SizedBox(height: 10),
          if (results.isEmpty)
            const NoticeBar(type: NoticeType.info, text: PersonFinder.noResult)
          else ...[
            if (_truncated) ...[
              const NoticeBar(
                type: NoticeType.warning,
                text: PersonFinder.truncatedText,
              ),
              const SizedBox(height: 8),
            ],
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: AppTheme.dividerColor),
                  itemBuilder: (context, i) {
                    final r = results[i];
                    return ListTile(
                      key: PersonFinder.resultKey(i),
                      dense: true,
                      title: Text(r.fullName, style: screenText(size: 14.5)),
                      subtitle: Text(
                        '${EmpType.nameOf(r.type)} · หน่วยงาน ${r.div} ${r.divName} · '
                        '${IdCard.masked(r.idcard)}',
                        style: screenText(
                          size: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pick(r),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
