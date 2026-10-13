import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/alert_message_box.dart';
import '../widgets/screen_parts.dart';

/// ข้อความแจ้งผู้ใช้งาน — เมนู "ข้อมูลงวด" ของฝ่ายบัญชี (ACCOUNT)
///
/// อ่าน `GET /api/alert-message` บันทึก `PUT /api/alert-message {msg}` (ไม่เกิน 5,000 ตัวอักษร)
/// ข้อความนี้แสดงที่หน้าแรกให้ทุกคนเห็นก่อนเข้าสู่ระบบ ด้านล่างมีตัวอย่างการแสดงผลที่ใช้กล่องเดียวกับหน้าแรก
/// ([AlertMessageBox]) เปลี่ยนตามที่พิมพ์ทันที บันทึกสำเร็จส่งข้อความให้ [SettingsProvider]
class AlertMessageScreen extends StatefulWidget {
  final ApiService apiService;

  const AlertMessageScreen({super.key, required this.apiService});

  static const String menuTitle = 'ข้อความแจ้งผู้ใช้งาน';
  static const IconData menuIcon = Icons.campaign;
  static const String groupTitle = 'ข้อมูลงวด';

  static const Key fieldKey = ValueKey('alert-field');
  static const Key saveButtonKey = ValueKey('alert-save');
  static const Key previewKey = ValueKey('alert-preview');
  static const String previewTitle = 'ตัวอย่างการแสดงผลที่หน้าแรก';
  static const String savedMessage = 'บันทึกข้อความแจ้งแล้ว';

  @override
  State<AlertMessageScreen> createState() => _AlertMessageScreenState();
}

class _AlertMessageScreenState extends State<AlertMessageScreen> {
  final _settings = SettingsProvider();
  final _text = TextEditingController();

  /// ข้อความที่ backend เก็บอยู่ ใช้เทียบว่ามีการแก้ไขหรือยัง
  String _saved = '';
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
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await widget.apiService.getAlertMessage();
      if (!mounted) return;
      _settings.setAlertMessage(message);
      setState(() {
        _saved = message;
        _text.text = message;
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

  // backend ตัดช่องว่างหัวท้ายก่อนเก็บ จึงเทียบแบบตัดแล้ว
  bool get _changed => _text.text.trim() != _saved.trim();

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final stored = await widget.apiService.updateAlertMessage(_text.text);
      if (!mounted) return;
      _settings.setAlertMessage(stored);
      setState(() {
        _saved = stored;
        _text.text = stored;
        _saving = false;
      });
      context.showSuccessSnackBar(AlertMessageScreen.savedMessage);
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
    const max = ApiService.alertMessageMaxLength;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, AlertMessageScreen.groupTitle),
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
                    icon: AlertMessageScreen.menuIcon,
                    title: AlertMessageScreen.menuTitle,
                    subtitle:
                        'ข้อความนี้แสดงที่หน้าแรกให้ทุกคนเห็นก่อนเข้าสู่ระบบ '
                        'พิมพ์ได้หลายบรรทัด เว้นว่างไว้ = ไม่มีข้อความแจ้ง',
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
                      icon: Icons.edit_note,
                      title: 'แก้ไขข้อความ',
                      subtitle:
                          'ยาวได้ไม่เกิน ${Util.formatCount(max)} ตัวอักษร '
                          'แสดงเป็นข้อความธรรมดา (ไม่รองรับ HTML)',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: AlertMessageScreen.fieldKey,
                            controller: _text,
                            enabled: !_saving,
                            minLines: 6,
                            maxLines: 16,
                            maxLength: max,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            keyboardType: TextInputType.multiline,
                            style: const TextStyle(
                              fontFamily: 'Sarabun',
                              fontSize: 16,
                              height: 1.6,
                              color: AppTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'พิมพ์ข้อความแจ้งผู้ใช้งาน',
                              hintStyle: const TextStyle(fontFamily: 'Sarabun'),
                              counterStyle: const TextStyle(
                                fontFamily: kScreenFont,
                              ),
                              filled: true,
                              fillColor: AppTheme.fieldFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppTheme.dividerColor,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PrimaryActionButton(
                              key: AlertMessageScreen.saveButtonKey,
                              label: 'บันทึกข้อความ',
                              icon: Icons.save_outlined,
                              loading: _saving,
                              onPressed: _changed ? _save : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    StepCard(
                      icon: Icons.visibility_outlined,
                      title: AlertMessageScreen.previewTitle,
                      subtitle: _changed
                          ? 'ยังไม่ได้บันทึก — ผู้ใช้จะเห็นแบบนี้หลังกดบันทึกข้อความ'
                          : 'ผู้ใช้เห็นข้อความแบบนี้อยู่ในขณะนี้',
                      child: KeyedSubtree(
                        key: AlertMessageScreen.previewKey,
                        child: AlertMessageBox(message: _text.text),
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
