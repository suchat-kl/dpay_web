// เมนูข้าง: หน้าแรก งานประจำงวดของฝ่ายบัญชี (เรียงตามลำดับที่ทำจริง) งานหักหนี้ และผู้ใช้งาน — แสดงตามบทบาทของผู้ที่เข้าสู่ระบบ
// ใช้ได้สองแบบ: drawer เลื่อนออก (ค่าเริ่มต้น) หรือตรึงไว้ข้างจอ (docked) ที่ยุบเหลือแต่ไอคอนได้
import 'package:flutter/material.dart';
import 'package:dpay/screens/alert_message_screen.dart';
import 'package:dpay/models/master_data.dart';
import 'package:dpay/screens/cgd_files_screen.dart';
import 'package:dpay/screens/chapana_import_screen.dart';
import 'package:dpay/screens/coming_soon_screen.dart';
import 'package:dpay/screens/debt_entry_screen.dart';
import 'package:dpay/screens/deduct_screen.dart';
import 'package:dpay/screens/div_status_screen.dart';
import 'package:dpay/screens/loan_check_screen.dart';
import 'package:dpay/screens/loan_screen.dart';
import 'package:dpay/screens/master_screen.dart';
import 'package:dpay/screens/period_jobs_screen.dart';
import 'package:dpay/screens/edit_window_screen.dart';
import 'package:dpay/screens/period_screen.dart';
import 'package:dpay/screens/report_screen.dart';
import 'package:dpay/screens/saha_import_screen.dart';
import 'package:dpay/screens/user_list_screen.dart';
import 'package:dpay/services/api_service.dart';
import 'package:dpay/utils/permission.dart';
import 'package:dpay/widgets/change_password_dialog.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_dialog.dart';

/// เมนูข้างของแอป — ออกแบบใหม่ ไม่ได้ลอกแท็บของระบบเดิม แต่ชื่อเมนูหลักยังเป็นคำที่ผู้ใช้คุ้น
///
/// เมนูแสดงตามบทบาท (ตารางบทบาทต่อหน้าจออยู่ที่ `Perm` ใน utils/permission.dart)
/// - "เตรียมข้อมูล" (ACCOUNT) กลุ่มเรียงตามลำดับงานประจำงวด:
///   ข้อมูลงวด (กำหนดงวด → ช่วงแก้ไข → นำเข้าบุคลากร → เตรียมงวด) → ฌาปนกิจและสหกรณ์ → บันทึกข้อมูลธนาคาร
///   → ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร (ตรวจยอดเงินกู้ → ไฟล์ส่งกรมบัญชีกลาง → รายงานส่งธนาคาร) → บันทึกรายการหลัก
/// - "งานหักหนี้" (ทุกคน): บันทึกข้อมูล รายงาน
/// - "ผู้ใช้งาน": เปลี่ยนรหัสผ่าน (ทุกคน) กำหนดรหัสผ่านใหม่ให้หน่วยงาน (RESETPWD/ADMIN) จัดการผู้ใช้ (ADMIN)
///
/// กลุ่ม "สร้างไฟล์ส่งกรมบัญชีกลาง (ข้าราชการ/ลูกจ้างประจำ)" 14 รายการของระบบเดิม **ไม่มีแล้ว**: backend สร้างไฟล์ตอนดาวน์โหลด
/// ไม่มีขั้น "สร้างไฟล์" แยก จึงรวมเป็นหน้าเดียว "ดาวน์โหลดไฟล์ข้อความส่งกรมบัญชีกลาง"
/// เมนูที่ backend ยังไม่มี API (เหลือ "รายงานฌาปนกิจ-สลิป") เปิดหน้า "กำลังพัฒนา" (`ComingSoonScreen`)
///
/// เพิ่มเมนูใหม่ใน `_buildResponsiveDrawer` ด้วย `_buildExpandableMenuItem` + `_SubMenuItemData(..., screenCode: ...)`
/// รายการย่อยซ่อนตามบทบาทให้เอง ไม่มีรายการที่ดูได้เลยทั้งกลุ่มก็ไม่แสดง
/// เปิดหน้าจอด้วย `_open` เสมอ (ตอนตรึงเมนู หน้าจอไปเปิดในพื้นที่ด้านขวา เมนูยังเห็นอยู่)
class SidebarMenu extends StatefulWidget {
  final AuthProvider authProvider;

  /// ตรึงเมนูไว้ข้างซ้ายของหน้าจอ (ไม่ใช่ drawer ที่เลื่อนออกมาแล้วปิด)
  final bool docked;

  /// ตอนตรึง: true = แสดงเฉพาะไอคอน, false = ขยายเห็นทั้งไอคอนและชื่อ
  final bool collapsed;

  /// จอกว้างพอให้ตรึงเมนูได้ (แสดงปุ่มตรึง)
  final bool canPin;

  /// สลับแสดงเฉพาะไอคอน / ขยาย (ตอนตรึง)
  final VoidCallback? onToggleCollapsed;

  /// ตรึง / เลิกตรึงเมนู
  final VoidCallback? onTogglePinned;

  /// ตอนตรึง หน้าจอที่เปิดจากเมนูไปแสดงใน navigator ด้านขวาของเมนู เมนูจึงยังเห็นอยู่
  final GlobalKey<NavigatorState>? contentNavigator;

  const SidebarMenu({
    super.key,
    required this.authProvider,
    this.docked = false,
    this.collapsed = false,
    this.canPin = false,
    this.onToggleCollapsed,
    this.onTogglePinned,
    this.contentNavigator,
  });

  /// ความกว้างของเมนูตอนแสดงเฉพาะไอคอน
  static const double railWidth = 72;

  /// ชื่อกลุ่มเมนูของฝ่ายบัญชี (กลุ่มแบบขยายได้)
  static const String periodGroupTitle = 'ข้อมูลงวด';

  /// ชื่อกลุ่มเมนูบัญชีผู้ใช้ (กลุ่มแบบขยายได้)
  static const String userGroupTitle = 'ผู้ใช้งาน';

  static const String changePasswordTitle = 'เปลี่ยนรหัสผ่าน';

  /// หัวข้อของกลุ่มเมนูฝ่ายบัญชี (คำที่ผู้ใช้คุ้นจากระบบเดิม)
  static const String prepareSectionTitle = 'เตรียมข้อมูล';

  /// หัวข้อและรายการของงานที่ทุกหน่วยงานใช้ (แท็บ "บันทึกข้อมูล" และ "รายงาน" ของระบบเดิม)
  static const String workSectionTitle = 'งานหักหนี้';
  static const String debtEntryTitle = 'บันทึกข้อมูล';
  static const String reportTitle = 'รายงาน';

  /// ชื่อกลุ่มข้อมูลหลัก และกลุ่มทะเบียนธนาคาร (กลุ่มแบบขยายได้ ของฝ่ายบัญชี)
  static const String masterGroupTitle = MasterScreen.groupTitle;
  static const String bankGroupTitle = DeductScreen.groupTitle;

  /// ตารางข้อมูลหลักตามลำดับในเมนู
  static const List<MasterResource> masterResources = [
    MasterResource.banks,
    MasterResource.branches,
    MasterResource.debtCodes,
    MasterResource.divs,
  ];

  /// กลุ่มนำเข้าฌาปนกิจ/สหกรณ์ และกลุ่มตรวจ-ส่งออก (กลุ่มแบบขยายได้ ของฝ่ายบัญชี)
  static const String chapanaGroupTitle = ChapanaImportScreen.groupTitle;
  static const String exportGroupTitle = CgdFilesScreen.groupTitle;

  /// เมนูเดียวที่ยังรอ API (เทียบฌาปนกิจกับสลิป — backend ก้อน ช)
  static const String chapanaSlipTitle = 'รายงานฌาปนกิจ-สลิป';

  /// "สร้างไฟล์ข้อความทั้งหมดส่งธนาคาร" และ "ดาวน์โหลดไฟล์ข้อความส่งธนาคาร" ของระบบเดิมยกเลิก ไม่ทำ
  /// (คำสั่งผู้ใช้ 13 ต.ค. 2569) — ห้ามเพิ่มกลับ
  static const List<String> cancelledMenus = [
    'สร้างไฟล์ข้อความทั้งหมดส่งธนาคาร',
    'ดาวน์โหลดไฟล์ข้อความส่งธนาคาร',
  ];

  /// คำอธิบายของปุ่มตรึง / เลิกตรึงเมนู
  static const String pinTooltip = 'ตรึงเมนูไว้ข้างจอ';
  static const String unpinTooltip = 'เลิกตรึงเมนู';

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  /// กลุ่มเมนูที่กำลังขยายอยู่ (คีย์ของ `_buildExpandableMenuItem`)
  /// ทั้งสองกลุ่มขยายไว้ให้ตั้งแต่เปิดเมนู ผู้ใช้เห็นรายการได้เลย
  final Set<String> _expandedMenus = {_periodMenuKey, _userMenuKey};

  static const String _periodMenuKey = 'period';
  static const String _userMenuKey = 'user';

  /// แสดงเฉพาะไอคอน (ตรึงอยู่และยุบ)
  bool get _rail => widget.docked && widget.collapsed;

  /// ปิด drawer หลังเลือกเมนู ตอนตรึงไม่มี drawer ให้ปิด
  /// (เดิมทุกเมนูเรียก Navigator.pop ตรง ๆ ถ้าตรึงอยู่จะไปปิดหน้าหลักทิ้งแทน)
  void _closeMenu(BuildContext context) {
    if (widget.docked) return;
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) Navigator.pop(context);
  }

  /// เปิดหน้าจอจากเมนู ตอนตรึงเปิดในพื้นที่ด้านขวาแทนหน้าที่เปิดอยู่ (ไม่ซ้อนกันไปเรื่อย ๆ)
  /// ไม่ตรึงเปิดเต็มจอแบบเดิม
  Future<T?> _open<T extends Object?>(BuildContext context, Route<T> route) {
    final nav = widget.docked ? widget.contentNavigator?.currentState : null;
    if (nav != null) return nav.pushAndRemoveUntil<T>(route, (r) => r.isFirst);
    return Navigator.of(context).push<T>(route);
  }

  /// กลับหน้าหลัก ตอนตรึงปิดหน้าที่เปิดค้างในพื้นที่ด้านขวา
  void _goHome(BuildContext context) {
    final nav = widget.docked ? widget.contentNavigator?.currentState : null;
    if (nav != null) {
      nav.popUntil((r) => r.isFirst);
    } else {
      _closeMenu(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (widget.docked) {
      // ตรึงอยู่: เป็นแถบข้างซ้ายของหน้าจอ ยุบ = กว้างพอสำหรับไอคอน ขยาย = กว้างเท่า drawer
      return Material(
        color: Colors.white,
        elevation: 2,
        child: SizedBox(
          width: widget.collapsed
              ? SidebarMenu.railWidth
              : _getDrawerWidth(screenWidth),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _buildResponsiveDrawer(context, constraints),
          ),
        ),
      );
    }

    return Drawer(
      width: _getDrawerWidth(screenWidth),
      child: Container(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _buildResponsiveDrawer(context, constraints);
          },
        ),
      ),
    );
  }

  /// เนื้อหาของเมนู ใช้ร่วมกันทั้งแบบ drawer และแบบตรึง
  Widget _buildResponsiveDrawer(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final isWide = constraints.maxWidth > 400;

    return Column(
      children: [
        _buildPinBar(context),
        // ส่วนหัว: โปรไฟล์ผู้ใช้ หรือปุ่มเข้าสู่ระบบ (ตอนยุบเหลือแค่ไอคอน ไม่มีที่ให้แสดง)
        if (_rail)
          const SizedBox.shrink()
        else if (widget.authProvider.isLoggedIn)
          isWide
              ? _buildUserProfileHeader(context)
              : _buildCompactUserHeader(context)
        else
          _buildLoginPrompt(context, compact: !isWide),

        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: isWide ? 8 : 4),
            children: [
              if (isWide)
                _buildMenuSection(
                  context,
                  title: 'เมนูหลัก',
                  items: [
                    _MenuItemData(
                      Icons.home,
                      'หน้าแรก',
                      () => _goHome(context),
                    ),
                  ],
                )
              else ...[
                _buildMenuItem(
                  context,
                  icon: Icons.home,
                  title: 'หน้าแรก',
                  onTap: () => _goHome(context),
                  compact: true,
                ),
              ],
              // เตรียมข้อมูล — ฝ่ายบัญชี (ACCOUNT) ตามโครงเมนูของระบบเดิม
              // รายการย่อยซ่อนเองตามบทบาท ไม่มีรายการที่ดูได้ทั้งกลุ่มก็ไม่แสดง
              if (widget.authProvider.canView(Perm.prepare)) ...[
                const Divider(indent: 16, endIndent: 16),
                if (!_rail) _sectionTitle(SidebarMenu.prepareSectionTitle),
              ],
              _buildExpandableMenuItem(
                context,
                icon: Icons.event_note,
                title: SidebarMenu.periodGroupTitle,
                menuKey: _periodMenuKey,
                children: [
                  _SubMenuItemData(
                    PeriodScreen.menuIcon,
                    PeriodScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => PeriodScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.period,
                  ),
                  _SubMenuItemData(
                    AlertMessageScreen.menuIcon,
                    AlertMessageScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => AlertMessageScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.alertMessage,
                  ),
                  _SubMenuItemData(
                    EditWindowScreen.menuIcon,
                    EditWindowScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => EditWindowScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.editWindow,
                  ),
                  _SubMenuItemData(
                    DpisImportScreen.menuIcon,
                    DpisImportScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => DpisImportScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    PreparePeriodScreen.menuIcon,
                    PreparePeriodScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => PreparePeriodScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    DivStatusScreen.menuIcon,
                    DivStatusScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => DivStatusScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                ],
              ),
              _buildExpandableMenuItem(
                context,
                icon: ChapanaImportScreen.menuIcon,
                title: SidebarMenu.chapanaGroupTitle,
                menuKey: 'chapana',
                children: [
                  _SubMenuItemData(
                    ChapanaImportScreen.menuIcon,
                    ChapanaImportScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => ChapanaImportScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    SahaImportScreen.menuIcon,
                    SahaImportScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => SahaImportScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    Icons.article_outlined,
                    SidebarMenu.chapanaSlipTitle,
                    () => _openComingSoon(
                      context,
                      SidebarMenu.chapanaSlipTitle,
                      SidebarMenu.chapanaGroupTitle,
                    ),
                    screenCode: Perm.prepare,
                  ),
                ],
              ),
              _buildExpandableMenuItem(
                context,
                icon: DeductScreen.menuIcon,
                title: SidebarMenu.bankGroupTitle,
                menuKey: 'bank',
                children: [
                  _SubMenuItemData(
                    DeductScreen.menuIcon,
                    DeductScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => DeductScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    LoanScreen.menuIcon,
                    LoanScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => LoanScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                ],
              ),
              _buildExpandableMenuItem(
                context,
                icon: CgdFilesScreen.menuIcon,
                title: SidebarMenu.exportGroupTitle,
                menuKey: 'export',
                children: [
                  _SubMenuItemData(
                    LoanCheckScreen.menuIcon,
                    LoanCheckScreen.syncMenuTitle,
                    () => _openScreen(
                      context,
                      (_) => LoanCheckScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    Icons.person_off_outlined,
                    LoanCheckScreen.missingMenuTitle,
                    () => _openScreen(
                      context,
                      (_) => LoanCheckScreen(
                        apiService: ApiService(),
                        missingFirst: true,
                      ),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    CgdFilesScreen.menuIcon,
                    CgdFilesScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => CgdFilesScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                  _SubMenuItemData(
                    BankReportScreen.menuIcon,
                    BankReportScreen.menuTitle,
                    () => _openScreen(
                      context,
                      (_) => BankReportScreen(apiService: ApiService()),
                    ),
                    screenCode: Perm.prepare,
                  ),
                ],
              ),
              // ข้อมูลอ้างอิง (แก้ไม่บ่อย) อยู่ท้ายกลุ่มงานของฝ่ายบัญชี
              _buildExpandableMenuItem(
                context,
                icon: Icons.list_alt,
                title: SidebarMenu.masterGroupTitle,
                menuKey: 'master',
                children: [
                  for (final r in SidebarMenu.masterResources)
                    _SubMenuItemData(
                      r.icon,
                      r.title,
                      () => _openScreen(
                        context,
                        (_) =>
                            MasterScreen(apiService: ApiService(), resource: r),
                      ),
                      screenCode: Perm.prepare,
                    ),
                ],
              ),
              // บันทึกข้อมูล / รายงาน — ทุกบัญชีที่เข้าสู่ระบบและใช้งานได้
              if (widget.authProvider.canView(Perm.debtEntry)) ...[
                const Divider(indent: 16, endIndent: 16),
                _buildMenuSection(
                  context,
                  title: SidebarMenu.workSectionTitle,
                  items: [
                    _MenuItemData(
                      Icons.edit_note,
                      SidebarMenu.debtEntryTitle,
                      () => _openScreen(
                        context,
                        (_) => DebtEntryScreen(apiService: ApiService()),
                      ),
                    ),
                    _MenuItemData(
                      Icons.assessment_outlined,
                      SidebarMenu.reportTitle,
                      () => _openScreen(
                        context,
                        (_) => ReportScreen(apiService: ApiService()),
                      ),
                    ),
                  ],
                ),
              ],
              // ผู้ใช้งาน — เปลี่ยนรหัสผ่านเห็นทุกคนที่เข้าสู่ระบบ ที่เหลือตามบทบาท
              if (widget.authProvider.isLoggedIn)
                _buildExpandableMenuItem(
                  context,
                  icon: Icons.group,
                  title: SidebarMenu.userGroupTitle,
                  menuKey: _userMenuKey,
                  divider: true,
                  children: [
                    _SubMenuItemData(
                      Icons.lock_reset,
                      SidebarMenu.changePasswordTitle,
                      () {
                        _closeMenu(context);
                        _showChangePasswordDialog(context);
                      },
                    ),
                    _SubMenuItemData(
                      UserListScreen.resetIcon,
                      UserListScreen.resetTitle,
                      () => _openScreen(
                        context,
                        (_) => UserListScreen(
                          apiService: ApiService(),
                          mode: UserListMode.resetPassword,
                        ),
                      ),
                      screenCode: Perm.userResetPassword,
                    ),
                    _SubMenuItemData(
                      UserListScreen.manageIcon,
                      UserListScreen.manageTitle,
                      () => _openScreen(
                        context,
                        (_) => UserListScreen(
                          apiService: ApiService(),
                          mode: UserListMode.manage,
                        ),
                      ),
                      screenCode: Perm.userManage,
                    ),
                  ],
                ),

              // เลขเวอร์ชัน (ตอนยุบเหลือแต่ไอคอน แถบแคบเกินไป ข้อความจะตัดบรรทัดเละ)
              if (!_rail)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'เวอร์ชัน ${AppConfig.version}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// แถบบนสุดของเมนู: ปุ่มยุบ/ขยาย และปุ่มตรึง/เลิกตรึง
  /// ไม่ตรึง (drawer) แสดงปุ่มตรึงเฉพาะจอที่กว้างพอ
  Widget _buildPinBar(BuildContext context) {
    if (!widget.docked && !widget.canPin) return const SizedBox.shrink();

    final toggle = IconButton(
      tooltip: _rail ? 'ขยายเมนู' : 'ย่อเมนูเหลือแต่ไอคอน',
      icon: Icon(
        _rail ? Icons.menu : Icons.menu_open,
        color: AppTheme.primaryColor,
      ),
      onPressed: widget.onToggleCollapsed,
    );
    final pin = IconButton(
      tooltip: widget.docked
          ? SidebarMenu.unpinTooltip
          : SidebarMenu.pinTooltip,
      icon: Icon(
        widget.docked ? Icons.push_pin : Icons.push_pin_outlined,
        color: AppTheme.primaryColor,
      ),
      onPressed: () {
        _closeMenu(context);
        widget.onTogglePinned?.call();
      },
    );

    if (_rail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(child: toggle),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(children: [if (widget.docked) toggle, const Spacer(), pin]),
    );
  }

  double _getDrawerWidth(double screenWidth) {
    if (screenWidth > 1200) {
      return 360;
    } else if (screenWidth > 800) {
      return 320;
    } else if (screenWidth > 600) {
      return 300;
    } else {
      return screenWidth * 0.85;
    }
  }

  /// ไอคอนเมนูตอนยุบ ชี้แล้วขึ้นชื่อเมนู
  Widget _railIcon({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: title,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ขยาย / หุบกลุ่มเมนู
  void _toggleSubmenu(String menuKey) {
    setState(() {
      if (_expandedMenus.contains(menuKey)) {
        _expandedMenus.remove(menuKey);
      } else {
        _expandedMenus.add(menuKey);
      }
    });
  }

  /// ปิด drawer แล้วเปิดหน้าจอจากเมนู
  void _openScreen(BuildContext context, WidgetBuilder builder) {
    _closeMenu(context);
    _open(context, MaterialPageRoute(builder: builder));
  }

  /// เปิดหน้า "กำลังพัฒนา" ของเมนูที่ยังรอ API
  void _openComingSoon(
    BuildContext context,
    String title,
    String group, [
    IconData icon = Icons.construction,
  ]) => _openScreen(
    context,
    (_) => ComingSoonScreen(title: title, group: group, icon: icon),
  );

  /// หัวข้อของกลุ่มเมนู (ตัวเล็กสีเทา)
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangePasswordDialog(
        username: widget.authProvider.username ?? '',
        apiService: ApiService(),
      ),
    );
    if (!context.mounted) return;

    // แถบแจ้งผลสำเร็จแสดงจากในหน้าต่างเองแล้ว
    if (result == true) _showLogoutConfirmation(context);
  }

  /// หลังเปลี่ยนรหัสผ่านของตัวเอง: แนะนำให้ออกจากระบบแล้วเข้าใหม่ด้วยรหัสใหม่
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('คำแนะนำด้านความปลอดภัย'),
        content: const Text(
          'เพื่อความปลอดภัย แนะนำให้ออกจากระบบและเข้าสู่ระบบใหม่ด้วยรหัสผ่านใหม่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ภายหลัง'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.authProvider.logout();
            },
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  /// ส่วนหัวของเมนูแบบกว้าง: รูปวงกลม ชื่อ ชื่อผู้ใช้ บทบาท และปุ่มออกจากระบบ
  Widget _buildUserProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            child: Text(
              widget.authProvider.initials,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.authProvider.displayName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (widget.authProvider.username != null)
            Text(
              widget.authProvider.username!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.authProvider.highestRole,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                _closeMenu(context);
                await widget.authProvider.logout();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('ออกจากระบบ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ส่วนหัวของเมนูแบบแคบ (จอเล็ก)
  Widget _buildCompactUserHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              widget.authProvider.initials,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.authProvider.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.authProvider.highestRole,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              _closeMenu(context);
              await widget.authProvider.logout();
            },
            icon: Icon(
              Icons.logout,
              color: Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// ส่วนหัวของเมนูเมื่อยังไม่เข้าสู่ระบบ: ชื่อระบบและปุ่มเข้าสู่ระบบ
  Widget _buildLoginPrompt(BuildContext context, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: compact ? 48 : 64,
            height: compact ? 48 : 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 10 : 14),
            ),
            child: Icon(
              AppConfig.systemIcon,
              color: AppTheme.primaryColor,
              size: compact ? 30 : 40,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            AppConfig.systemName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            AppConfig.organizationName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 12 : 14,
            ),
          ),
          SizedBox(height: compact ? 14 : 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _closeMenu(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) =>
                      LoginDialog(authProvider: widget.authProvider),
                );
              },
              icon: Icon(Icons.login, size: compact ? 18 : 20),
              label: Text(
                'เข้าสู่ระบบ',
                style: TextStyle(fontSize: compact ? 14 : 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: AppTheme.onSecondaryColor,
                padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compact ? 8 : 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// กลุ่มเมนูแบบมีหัวข้อ รายการเรียงต่อกัน (ไม่ขยาย/หุบ)
  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required List<_MenuItemData> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_rail)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ...items.map(
          (item) => _buildMenuItem(
            context,
            icon: item.icon,
            title: item.title,
            onTap: item.onTap,
          ),
        ),
      ],
    );
  }

  /// เมนูหนึ่งรายการ ตอนยุบเหลือแต่ไอคอน
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    if (_rail) {
      return _railIcon(icon: icon, title: title, onTap: onTap);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 2 : 4,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 36 : 40,
                height: compact ? 36 : 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(compact ? 8 : 10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: compact ? 20 : 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: compact ? 18 : 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// เมนูย่อยที่ผู้ใช้คนนี้เปิดได้ตามบทบาท
  ///
  /// เมนูที่ไม่ได้ระบุรหัสหน้าจอถือว่าเปิดให้ทุกคนที่เห็นกลุ่มนั้น (เช่นเปลี่ยนรหัสผ่าน)
  List<_SubMenuItemData> _allowed(List<_SubMenuItemData> items) {
    return items
        .where(
          (e) =>
              e.screenCode == null ||
              widget.authProvider.canView(e.screenCode!),
        )
        .toList();
  }

  /// กลุ่มเมนูที่ขยาย/หุบได้ พร้อมรายการย่อย
  Widget _buildExpandableMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String menuKey,
    required List<_SubMenuItemData> children,
    bool compact = false,
    bool divider = false,
  }) {
    // ไม่มีเมนูย่อยที่ดูได้เลย ก็ไม่ต้องแสดงหัวข้อกลุ่มนี้
    // เส้นคั่นต้องอยู่ในนี้ด้วย ไม่ใช่วางไว้ข้างนอก ไม่งั้นกลุ่มที่ซ่อนไป
    // จะทิ้งเส้นคั่นค้างเป็นบรรทัดว่างในเมนู
    children = _allowed(children);
    if (children.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedMenus.contains(menuKey);

    if (_rail) {
      // เมนูย่อยต้องเห็นชื่อจึงเลือกได้ กดไอคอนกลุ่มแล้วขยายเมนูพร้อมเปิดกลุ่มนั้นให้
      return Column(
        children: [
          if (divider) const Divider(indent: 12, endIndent: 12),
          _railIcon(
            icon: icon,
            title: title,
            onTap: () {
              setState(() => _expandedMenus.add(menuKey));
              widget.onToggleCollapsed?.call();
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        if (divider) const Divider(indent: 16, endIndent: 16),
        // หัวกลุ่ม
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleSubmenu(menuKey),
            borderRadius: BorderRadius.circular(compact ? 6 : 8),
            hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
            splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 20,
                vertical: compact ? 2 : 4,
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 36 : 40,
                    height: compact ? 36 : 40,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(compact ? 8 : 10),
                    ),
                    child: Icon(
                      icon,
                      color: isExpanded
                          ? AppTheme.secondaryColor
                          : AppTheme.primaryColor,
                      size: compact ? 20 : 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        fontWeight: isExpanded
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isExpanded
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: compact ? 18 : 20,
                      color: isExpanded
                          ? AppTheme.primaryColor
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // รายการย่อย (ค่อย ๆ ปรากฏ)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: EdgeInsets.only(
              left: compact ? 56 : 64,
              right: compact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(compact ? 6 : 8),
              border: Border(
                left: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: children.map((subItem) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: subItem.onTap,
                    borderRadius: BorderRadius.circular(compact ? 4 : 6),
                    hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
                    splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 16,
                        vertical: compact ? 8 : 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            subItem.icon,
                            size: compact ? 16 : 18,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subItem.title,
                              style: TextStyle(
                                fontSize: compact ? 13 : 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: compact ? 12 : 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// หนึ่งรายการของกลุ่มเมนูแบบมีหัวข้อ
class _MenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _MenuItemData(this.icon, this.title, this.onTap);
}

/// หนึ่งเมนูย่อย
///
/// [screenCode] คือรหัสหน้าจอ (ดู `Perm`) ใส่ไว้เพื่อให้ซ่อนเมนูอัตโนมัติ
/// เมื่อบทบาทของผู้ใช้เปิดหน้าจอนั้นไม่ได้ เมนูที่ไม่ใส่รหัสจะแสดงกับทุกคน
class _SubMenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? screenCode;

  _SubMenuItemData(this.icon, this.title, this.onTap, {this.screenCode});
}
