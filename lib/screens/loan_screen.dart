import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/loan_editor.dart';
import '../widgets/person_finder.dart';
import '../widgets/screen_parts.dart';

/// บันทึกข้อมูลธนาคาร เลขที่บัญชีเงินกู้ — หลายบัญชีต่อคน แก้ไขในแถว (ACCOUNT)
///
/// ค้นคนด้วยเลขบัตรหรือชื่อ ([PersonFinder]) → ตารางแก้ไขในแถว ([LoanEditor] — ตัวเดียวกับหน้าต่างที่เปิดจากหน้าตรวจยอดเงินกู้)
class LoanScreen extends StatefulWidget {
  final ApiService apiService;

  const LoanScreen({super.key, required this.apiService});

  static const String menuTitle = 'เลขที่บัญชีเงินกู้';
  static const IconData menuIcon = Icons.credit_score_outlined;
  static const String groupTitle = 'บันทึกข้อมูลธนาคาร';

  static const Key saveKey = LoanEditor.saveKey;
  static const Key dirtyKey = LoanEditor.dirtyKey;

  /// คีย์ของช่อง [field] ในแถวลำดับที่ [index] (นับจาก 0) และช่องติ๊กของแถว
  static Key cellKey(int index, String field) =>
      LoanEditor.cellKey(index, field);
  static Key checkKey(int index) => LoanEditor.checkKey(index);

  static const Map<String, String> flgNames = LoanEditor.flgNames;
  static const String dirtyText = LoanEditor.dirtyText;
  static const String emptyText = LoanEditor.emptyText;
  static const String savedMessage = LoanEditor.savedMessage;

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  GlobalKey<LoanEditorState> _editor = GlobalKey();
  String? _idcard;
  bool _busy = false;

  Future<void> _pick(String idcard) async {
    final editor = _editor.currentState;
    if (editor != null && !await editor.confirmDiscard()) return;
    if (!mounted) return;
    // คีย์ใหม่ทุกครั้ง: เลือกคนเดิมซ้ำก็สร้างตารางใหม่และโหลดจาก backend อีกรอบ
    setState(() {
      _editor = GlobalKey();
      _idcard = idcard;
      _busy = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final idcard = _idcard;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, LoanScreen.groupTitle),
      body: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenHeader(
                    icon: LoanScreen.menuIcon,
                    title: LoanScreen.menuTitle,
                    subtitle:
                        'เลขที่บัญชีเงินกู้ของบุคลากร หลายบัญชีต่อคน แก้ในตารางแล้วกดบันทึก',
                  ),
                  const SizedBox(height: 16),
                  PersonFinder(
                    apiService: widget.apiService,
                    enabled: !_busy,
                    onPicked: _pick,
                  ),
                  const SizedBox(height: 12),
                  if (idcard != null)
                    LoanEditor(
                      key: _editor,
                      apiService: widget.apiService,
                      idcard: idcard,
                      onBusyChanged: (b) {
                        if (mounted) setState(() => _busy = b);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
