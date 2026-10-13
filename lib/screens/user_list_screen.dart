import 'dart:async';

import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_admin.dart';
import '../services/api_service.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/reset_password_dialog.dart';
import '../widgets/screen_parts.dart';
import '../widgets/user_dialog.dart';

/// หน้าที่ของหน้ารายการผู้ใช้
enum UserListMode {
  /// จัดการผู้ใช้ (ADMIN): เพิ่ม แก้ไข ระงับ ปลดล็อก บทบาท หน่วยงาน
  manage,

  /// กำหนดรหัสผ่านใหม่ให้หน่วยงาน (RESETPWD / ADMIN)
  resetPassword,
}

/// รายการผู้ใช้ (`GET /api/admin/users`) ค้นหาได้ แบ่งหน้าฝั่ง backend — ใช้สองเมนู ต่างกันที่ปุ่มท้ายแถว
///
/// - [UserListMode.manage] "จัดการผู้ใช้": ปุ่มแก้ไขท้ายแถว และปุ่มเพิ่มผู้ใช้ที่แถบบน
/// - [UserListMode.resetPassword] "กำหนดรหัสผ่านใหม่ให้หน่วยงาน": ปุ่มกำหนดรหัสผ่านท้ายแถว
///   กดไม่ได้กับบัญชีของตัวเอง (ใช้เมนูเปลี่ยนรหัสผ่าน) และผู้ที่ไม่ใช่ ADMIN กดไม่ได้กับบัญชีที่ถือ
///   ADMIN / ACCOUNT / RESETPWD (กติกาเดียวกับ backend ซึ่งเป็นผู้กันจริง)
///
/// ไม่มีปุ่มลบ: backend ไม่มีเส้นลบผู้ใช้ ให้ระงับการใช้งานแทน
class UserListScreen extends StatefulWidget {
  final ApiService apiService;
  final UserListMode mode;

  const UserListScreen({
    super.key,
    required this.apiService,
    required this.mode,
  });

  static const String manageTitle = 'จัดการผู้ใช้';
  static const String resetTitle = 'กำหนดรหัสผ่านใหม่ให้หน่วยงาน';
  static const IconData manageIcon = Icons.manage_accounts;
  static const IconData resetIcon = Icons.lock_person;

  /// ชื่อกลุ่มเมนูของสองหน้านี้ (แสดงที่แถบบนของหน้าจอ)
  static const String groupTitle = 'ผู้ใช้งาน';

  static const String ownAccountTooltip =
      'บัญชีของตัวเอง ใช้เมนูเปลี่ยนรหัสผ่าน';
  static const String privilegedTooltip =
      'บัญชีนี้ต้องให้ผู้ดูแลระบบกำหนดรหัสผ่าน';
  static const String emptyText = 'ไม่พบผู้ใช้';

  /// คีย์ของแถวบัญชี [id] ในรายการ ใช้หาในเทสต์
  static Key rowKey(String id) => ValueKey('user-row-$id');

  /// คีย์ของปุ่มท้ายแถวบัญชี [id]
  static Key actionKey(String id) => ValueKey('user-action-$id');

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<UserAdmin> _users = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalItems = 0;
  int _pageSize = 10;
  String? _keyword;

  final TextEditingController _searchController = TextEditingController();

  /// หน่วงการค้นหาระหว่างพิมพ์ ไม่ยิง backend ทุกตัวอักษร (กด Enter = ค้นทันที)
  Timer? _debounce;

  bool get _manage => widget.mode == UserListMode.manage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.searchAdminUsers(
        keyword: _keyword,
        page: _currentPage,
        size: _pageSize,
      );
      if (!mounted) return;
      final list = (result['users'] as List?) ?? const [];
      setState(() {
        _users = [
          for (final j in list.whereType<Map>())
            UserAdmin.fromJson(Map<String, dynamic>.from(j)),
        ];
        _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
        _totalItems = (result['totalItems'] as num?)?.toInt() ?? _users.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _onKeywordChanged(String _) {
    setState(() {}); // ปุ่มล้างคำค้นขึ้น/หายตามข้อความ
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  void _runSearch() {
    _debounce?.cancel();
    final k = _searchController.text.trim();
    // คำค้นเดิม (เช่นกด Enter ซ้ำ หรือครบเวลาหน่วงหลังค้นไปแล้ว) ไม่ต้องยิงซ้ำ
    if ((k.isEmpty ? null : k) == _keyword) return;
    setState(() {
      _keyword = k.isEmpty ? null : k;
      _currentPage = 0;
    });
    _loadData();
  }

  void _clearSearch() {
    _debounce?.cancel();
    setState(() {
      _searchController.clear();
      _keyword = null;
      _currentPage = 0;
    });
    _loadData();
  }

  /// เปิดหน้าต่างแก้ไข โหลดข้อมูลล่าสุดของบัญชีก่อน
  Future<void> _edit(UserAdmin u) async {
    try {
      final full = await widget.apiService.getAdminUser(u.id);
      if (!mounted) return;
      final saved = await showDialog<UserAdmin>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UserDialog(user: full, apiService: widget.apiService),
      );
      if (saved == null || !mounted) return;
      context.showSuccessSnackBar('บันทึกข้อมูลผู้ใช้ ${saved.username} แล้ว');
      _loadData();
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _add() async {
    final created = await showDialog<UserAdmin>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserDialog(apiService: widget.apiService),
    );
    if (created == null || !mounted) return;
    context.showSuccessSnackBar('เพิ่มผู้ใช้ ${created.username} แล้ว');
    _loadData();
  }

  Future<void> _resetPassword(UserAdmin u) async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ResetPasswordDialog(user: u, apiService: widget.apiService),
    );
    if (message == null || !mounted) return;
    context.showSuccessSnackBar(message);
    _loadData();
  }

  /// เหตุที่กำหนดรหัสผ่านให้บัญชีนี้ไม่ได้ (null = กำหนดได้)
  String? _resetBlockedReason(UserAdmin u) {
    if (u.username == widget.apiService.username) {
      return UserListScreen.ownAccountTooltip;
    }
    if (!widget.apiService.hasRole(Roles.admin) &&
        u.roles.any(Roles.privileged.contains)) {
      return UserListScreen.privilegedTooltip;
    }
    return null;
  }

  static const String _font = 'NotoSansThai';

  Widget _actionButton(UserAdmin u, {required bool compact}) {
    final blocked = _manage ? null : _resetBlockedReason(u);
    final icon = _manage ? Icons.edit_rounded : Icons.lock_reset;
    final label = _manage ? 'แก้ไข' : 'กำหนดรหัสผ่าน';
    final onPressed = blocked != null
        ? null
        : () => _manage ? _edit(u) : _resetPassword(u);
    final style = FilledButton.styleFrom(
      backgroundColor: AppTheme.primaryPale,
      foregroundColor: AppTheme.primaryDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
    final button = compact
        ? IconButton.filledTonal(
            key: UserListScreen.actionKey(u.id),
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 20),
          )
        : FilledButton.tonalIcon(
            key: UserListScreen.actionKey(u.id),
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 18),
            label: Text(label, style: const TextStyle(fontFamily: _font)),
          );
    return Tooltip(message: blocked ?? label, child: button);
  }

  /// หนึ่งแถวของรายการ: "ชื่อผู้ใช้ · ชื่อที่แสดง", หน่วยงาน, ป้ายบทบาทและสถานะ, ปุ่มท้ายแถว
  Widget _row(UserAdmin u, {required bool compact}) {
    final div = [u.div, u.divName].where((s) => s.isNotEmpty).join(' ');
    return Padding(
      key: UserListScreen.rowKey(u.id),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          if (!compact) ...[
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryPale,
              child: Icon(Icons.apartment, color: AppTheme.primaryDark),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${u.username}  ·  ${u.fullName}',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (div.isNotEmpty && div != '${u.username} ${u.fullName}') ...[
                  const SizedBox(height: 2),
                  Text(
                    'หน่วยงาน $div',
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 13.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (_manage && u.lastLogin != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'เข้าใช้ล่าสุด ${Util.formatThaiDateTime(u.lastLogin!)}',
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final r in u.roles)
                      StatusChip(Roles.nameOf(r), AppTheme.primaryDark),
                    if (!u.active)
                      const StatusChip('ระงับ', AppTheme.dangerColor),
                    if (u.locked)
                      const StatusChip('ล็อก', AppTheme.warningColor),
                    if (u.mustChangePassword)
                      const StatusChip('รอเปลี่ยนรหัสผ่าน', AppTheme.infoColor),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(u, compact: compact),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final compact = width < 520;
    final title = _manage
        ? UserListScreen.manageTitle
        : UserListScreen.resetTitle;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, UserListScreen.groupTitle),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(isDesktop ? 24 : 12),
              children: [
                ScreenHeader(
                  icon: _manage
                      ? UserListScreen.manageIcon
                      : UserListScreen.resetIcon,
                  title: title,
                  subtitle: _manage
                      ? 'ค้นหาผู้ใช้แล้วกดปุ่มแก้ไขท้ายแถว เพื่อแก้ชื่อ หน่วยงาน บทบาท ระงับ หรือปลดล็อก'
                      : 'ค้นหาหน่วยงานแล้วกดปุ่มกำหนดรหัสผ่านท้ายแถว '
                            'หน่วยงานนั้นต้องเปลี่ยนรหัสผ่านเองตอนเข้าสู่ระบบครั้งถัดไป',
                ),
                const SizedBox(height: 16),
                if (_manage)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PrimaryActionButton(
                        label: 'เพิ่มผู้ใช้',
                        icon: Icons.person_add,
                        color: AppTheme.addColor,
                        onPressed: _add,
                      ),
                    ),
                  ),
                // ช่องค้นหาเต็มความกว้าง ค้นฝั่ง server
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontFamily: _font, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'ค้นหา',
                    hintStyle: const TextStyle(fontFamily: _font),
                    helperText: 'ค้นด้วยรหัสหน่วยงานหรือชื่อ',
                    helperStyle: const TextStyle(fontFamily: _font),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'ล้างคำค้น',
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                  onChanged: _onKeywordChanged,
                  onSubmitted: (_) => _runSearch(),
                ),
                const SizedBox(height: 16),
                // รายการเป็นการ์ดเดียว แบ่งแถวด้วยเส้นคั่น
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _users.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              UserListScreen.emptyText,
                              style: TextStyle(
                                fontFamily: _font,
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < _users.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: AppTheme.dividerColor,
                                ),
                              _row(_users[i], compact: compact),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          // แถบแบ่งหน้ามาตรฐาน
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 24,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: AppPagination(
              currentPage: _currentPage,
              totalPages: _totalPages,
              pageSize: _pageSize,
              summary: 'ทั้งหมด ${Util.formatCount(_totalItems)} บัญชี',
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _loadData();
              },
              onPageSizeChanged: (size) {
                setState(() {
                  _pageSize = size;
                  _currentPage = 0;
                });
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }
}
