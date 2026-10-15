# dpay — หน้าเว็บระบบหักหนี้ กรมทางหลวง (Flutter Web)

หน้าเว็บของระบบหักหนี้ตัวใหม่ ระยะที่ 3: ครบตามสัญญา backend ก้อน ก–ฉ (`C:\AI\springboot\dpay\docs\api.md`) — บัญชีผู้ใช้ ค่าตั้งกลาง ข้อมูลหลัก
งานงวด บันทึกรายการหนี้ ทะเบียนธนาคาร/กบข. เลขบัญชีเงินกู้ นำเข้าฌาปนกิจ/สหกรณ์ ไฟล์ส่งกรมบัญชีกลาง ตรวจยอดเงินกู้ และรายงาน
เหลือ "รายงานฌาปนกิจ-สลิป" (รอ backend ก้อน ช) รายการจุดที่ต้องตั้ง เมนูตามบทบาท และสัญญา API อยู่ใน `README.md`

| ส่วน | path บน Windows |
|---|---|
| Frontend (repo นี้) | `C:\AI\flutter\dpay` |
| Backend (Spring Boot 4 / MongoDB พอร์ต 9005 HTTPS) | `C:\AI\springboot\dpay` — แก้ API ที่นั่น และอ่าน `CLAUDE.md` ของฝั่งนั้น |
| ต้นแบบที่ยกโครงมา | `C:\AI\template\flutter` |
| ระบบเดิมที่มาแทน (อ่านเพื่อเข้าใจเมนู/ถ้อยคำ ห้ามยกโค้ด/ชื่อบุคคล) | `C:\AI\old\dp_flutter`, `C:\AI\old\dpayGE_localHost_springboot` |

## คำสั่งที่ใช้ประจำ

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE=https://suchat-dev.doh.go.th/dpayapi   # dev ชี้ nginx บน WSL
flutter analyze
flutter test                      # ห้ามใส่ --platform chrome
bash tool/check_logging.sh
flutter build web --no-wasm-dry-run --dart-define=API_BASE=<URL ของ API>
```

`API_BASE` ไม่ส่งมา = `https://backupdoh.doh.go.th/dpayapi` (เครื่องจริง — ผู้ใช้กำหนด 13 ต.ค. 2569: backend อยู่ที่ backupdoh เครื่องเดียว หน้าเว็บวางที่ inf/infdoh/dbdoh/backupdoh ผู้ใช้เข้าทาง inf.doh.go.th แบบเดียวกับ HTC และสลิปภาษี) ตอนพัฒนาต้องส่ง `--dart-define=API_BASE=...` เองทุกครั้ง
**ห้าม** build ขึ้นเครื่องจริงด้วย `--debug` / `--profile` และ**ห้าม**ใส่ URL เครื่องจริง รหัสผ่าน token หรือกุญแจลงใน repo
(URL ที่อนุญาตในไฟล์มีแค่ตัวอย่าง dev `https://suchat-dev.doh.go.th/dpayapi` กับ localhost)

## ผังโค้ด (`lib/`)

```
main.dart    โครงแอป: MaterialApp + ป้ายช่วงทดสอบ + แถบบน + เมนูข้าง (ตรึงได้) + บังคับเปลี่ยนรหัสผ่าน
             + สั่ง SettingsProvider โหลด/ล้างตามสถานะเข้าสู่ระบบ + ออกจากระบบแล้วกลับหน้าแรก
config/      app_config.dart (ชื่อระบบ ไอคอน คีย์ของที่เก็บ — จุดเดียว), theme.dart (ธีม 6 ชุด)
models/      debt.dart (DebtCodes, EmpType, DebtRow, DebtPage, DebtSummaryItem, DebtAudit, PersonInfo, PersonHit, เวลาจาก backend),
             master_data.dart (MasterResource, MasterField — นิยามตารางข้อมูลหลัก),
             user_admin.dart, div_dept.dart (DivDept, DivScope, DivChoices, SuccessDept), period.dart, edit_window.dart
providers/   auth_provider.dart (session บทบาท หน่วยงาน displayName), settings_provider.dart (งวด ระยะเวลาแก้ไข canEditNow ข้อความแจ้ง)
services/    debt_api.dart (extension DebtApi on ApiService — เส้นของระยะที่ 2 ทั้งหมด เรียกผ่าน `request()` / `errorOf()`),
             work_api.dart (extension WorkApi — เส้นของระยะที่ 3: สหกรณ์ ฌาปนกิจ ไฟล์ส่งกรมบัญชีกลาง กระทบยอดเงินกู้ รายงาน ดาวน์โหลดไฟล์เป็นไบต์),
             api_service.dart (Dio ทุก endpoint + ที่เก็บ token + ApiException), auth_interceptor.dart (แนบ token / 401 แล้วต่ออายุ)
screens/     home_screen.dart, period_screen.dart, alert_message_screen.dart, edit_window_screen.dart,
             chapana_slip_screen.dart (รายงานฌาปนกิจ-สลิป — เทียบยอดที่ต้องการหักกับยอดที่หักได้จริงในสลิป),
             saha_import_screen.dart (นำเข้าสหกรณ์ + SahaMappingDialog), chapana_import_screen.dart (นำเข้าฌาปนกิจ),
             div_status_screen.dart (สถานะการบันทึกของหน่วยงาน — กดแถวเปิด DebtEntryScreen(initialDiv, initialPeriod)),
             cgd_files_screen.dart (ไฟล์ส่งกรมบัญชีกลาง), loan_check_screen.dart (ตรวจยอดเงินกู้กับหนี้เดือน),
             report_screen.dart (ReportScreen รายงาน PDF, BankReportScreen รายงานส่งธนาคาร),
             master_screen.dart (ข้อมูลหลักทุกตาราง), period_jobs_screen.dart (DpisImportScreen, PreparePeriodScreen),
             debt_entry_screen.dart (บันทึกข้อมูล), deduct_screen.dart (กบข/กสจ. สหกรณ์และภาษี), loan_screen.dart (เลขที่บัญชีเงินกู้),
             user_list_screen.dart (สองโหมด: จัดการผู้ใช้ / กำหนดรหัสผ่านใหม่ให้หน่วยงาน)
widgets/     header, sidebar_menu, footer, test_phase_banner, hover_lift, app_pagination, screen_parts,
             account_form (โครงหน้าต่างฟอร์ม ช่องกรอก PasswordRules PasswordRuleList PasswordField),
             sheet_table (SheetScroll, SheetCard, SheetPinnedHeader, SheetHead, SheetButton, sheetInput — ชิ้นส่วนของตารางแก้ในแถว),
             work_parts (WorkPage, FactRow, PeriodPicker, FileDownloads, DownloadButtons — ชิ้นส่วนของงานประจำงวด), period_progress (ความคืบหน้าของงวด),
             debt_dialogs (DebtAuditDialog), person_finder,
             thai_date_picker (วันเดียว), thai_date_range_picker (ช่วงวันที่ แตะ/ลาก), div_selector (DivSelector, DivDropdown),
             alert_message_box, login_dialog, change_password_dialog, reset_password_dialog, user_dialog
utils/       money.dart (Money = สตางค์, IdCard, BeDate = ddMMyyyy พ.ศ.), logger.dart (AppLogger), util.dart (วันที่ไทย), dialog.dart (AppDialog), snackbar_helper.dart,
             file_download.dart (DownloadedFile, FileSaver, SavedFile — ส่งไฟล์ให้เบราว์เซอร์ผ่าน Blob), file_pick.dart (เลือกไฟล์จากเครื่อง),
             permission.dart (Roles, Perm = บทบาทต่อหน้าจอ, ErrorCodes)
```

รูปแบบ: หนึ่ง entity = `models/x.dart` + `screens/x_screen.dart` + `widgets/x_dialog.dart` + เมธอดใน `ApiService`
+ เส้นใน `test/fake_backend.dart` + ไฟล์เทสต์ หน้าค่าตั้งกลางสามหน้า (งวด ข้อความแจ้ง ระยะเวลา) เป็นเอกสารเดียวจึงแก้ในหน้าจอ ไม่มี dialog

## กติกาของโปรเจกต์

**ชื่อระบบและคีย์** อ่านจาก `AppConfig` เท่านั้น ที่เก็บในเบราว์เซอร์ขึ้นต้น `dpay_`: localStorage `dpay_theme`, `dpay_menu_pinned`
และคลัง token `dpay_secure_storage` (ตั้ง `WebOptions` ใน `ApiService` — ห้ามเอาออก ไม่งั้น token ปนกับระบบอื่นบน origin เดียวกัน)

**Logging** ใช้ `AppLogger` เท่านั้น ห้าม `print()` / `debugPrint()` ทุกจุดที่เรียกครอบด้วย `if (AppLogger.on)`
ข้อความที่แพงหรืออ่อนไหวใช้ `AppLogger.lazy(() => ...)` ตัวข้อมูลจาก backend ผ่าน `AppLogger.redact` เสมอ
ห้าม log รหัสผ่าน token ข้อมูลส่วนบุคคล หรือเนื้อข้อความแจ้ง และไม่ใช้ `LogInterceptor` ของ Dio

**ธีม** สีที่เปลี่ยนตามธีม (`AppTheme.primaryColor`, `backgroundColor`, `fieldFillColor` ฯลฯ) เป็น getter
ใช้ในนิพจน์ `const` ไม่ได้ และห้ามเก็บลง `static final`

**ฟอนต์ไทย** ระบุ `fontFamily` ให้ชัดเสมอ (`NotoSansThai`, `Sarabun`, `Kanit` — bundle มาแล้ว)

**วันที่** แสดงด้วย `Util.formatThaiDate` (18 สิงหาคม 2569) ส่ง backend เป็น ค.ศ. `yyyy-MM-dd` (`Util.formatChristianDate`)
งวดแสดงด้วย `Period.label` (กรกฎาคม 2568) ระยะเวลาแก้ไขแสดงด้วย `EditWindow.beginLabel/endLabel/rangeLabel`

**เลือกวันที่** วันเดียวใช้ `showThaiDatePicker` ช่วงวันที่ใช้ `showThaiDateRangePicker` (วิธีใช้ใน `README.md`)
**ห้ามเรียก `showDatePicker` / `showDateRangePicker` ของ Flutter และห้ามเพิ่ม syncfusion** (ไม่รองรับปี พ.ศ. และมีเงื่อนไขสัญญาอนุญาต)
ตัวเลือกช่วงวันที่ใช้ `Listener` (ตัวชี้ดิบ) จับการลาก แยกจากการแตะของแต่ละวัน — แก้แล้วต้องรัน `thai_date_range_picker_test`

**ระยะเวลาแก้ไขข้อมูล** เป็นช่วงต่อเนื่องช่วงเดียว (วันเริ่ม+เวลาเริ่ม ถึง วันสิ้นสุด+เวลาสิ้นสุด) ไม่ใช่ช่วงเวลาซ้ำทุกวัน
หน้าเว็บ**ไม่คำนวณเอง**ว่าเปิดอยู่ไหม (นาฬิกาเครื่องผู้ใช้เชื่อไม่ได้ — จุดอ่อนของระบบเดิม) ใช้ `open` / `can_edit_now` ของ backend
`SettingsProvider().canEditNow` ใช้เปิด/ปิดปุ่มเท่านั้น backend บังคับจริงด้วย 403 `EDIT_WINDOW_CLOSED`
หน้าตั้งค่า: เลือกวันเริ่ม–สิ้นสุดในครั้งเดียวด้วย `showThaiDateRangePicker` เวลาตั้งต้นของงวด = เริ่ม 06:00 สิ้นสุด 16:30
(`EditWindow.defaultBeginTime/defaultEndTime` เติมให้**เฉพาะเมื่อ backend ไม่มีเวลามา** เลือกช่วงวันใหม่ไม่ตั้งเวลากลับ เวลาที่แก้ไว้คงอยู่
backend ตั้งเวลากลับเป็นค่านี้เองเมื่อเปลี่ยนงวดด้วย `PUT /api/period` หน้ากำหนดเดือนปีจึงเรียก `SettingsProvider().load()` หลังบันทึก
และมีข้อความ `PeriodScreen.timeResetNote` บอกผู้ใช้ — ผู้ใช้ตัดสิน 13 ต.ค. 2569)
ประโยคสรุปรูป "แก้ไขได้ตั้งแต่ 21 กันยายน 2569 เวลา 06:00 น. ถึง 5 ตุลาคม 2569 เวลา 16:30 น"

**เมนู** ออกแบบใหม่ ไม่ได้ลอกแท็บของระบบเดิม (ผู้ใช้อนุญาต) แต่ชื่อเมนูหลักยังเป็นคำที่คุ้น: หัวข้อ "เตรียมข้อมูล" (ACCOUNT) กลุ่มเรียงตามลำดับงานประจำงวด
ข้อมูลงวด → ฌาปนกิจและสหกรณ์ → บันทึกข้อมูลธนาคาร → ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร → บันทึกรายการหลัก, "งานหักหนี้" (ทุกคน: บันทึกข้อมูล รายงาน)
และ "ผู้ใช้งาน" ทุกเมนูเปิดหน้าจอจริงแล้ว — ไม่มีหน้า "กำลังพัฒนา" (`ComingSoonScreen` ลบออกแล้ว อย่าสร้างกลับ)
**ยกเลิก ไม่ทำ (คำสั่งผู้ใช้ 13 ต.ค. 2569):** "สร้างไฟล์ข้อความทั้งหมดส่งธนาคาร" และ "ดาวน์โหลดไฟล์ข้อความส่งธนาคาร" — ห้ามใส่กลับในเมนู
เมนูธนาคารที่ยังอยู่: รายชื่อบุคคลที่ไม่มีเลขบัญชีธนาคาร, ปรับปรุงหนี้ธนาคาร ดาวน์โหลดหนี้ที่ต้องแก้ไข, รายงานส่งธนาคาร (xlsx),
บันทึกข้อมูลธนาคาร กบข/กสจ. สหกรณ์และภาษี, บันทึกข้อมูลธนาคาร เลขที่บัญชีเงินกู้

**บังคับเปลี่ยนรหัสผ่าน** หน้าเว็บทำตามที่ backend บอกเท่านั้น (`must_change_password` ตอน login / `GET /api/auth/me` หรือ 403
`PASSWORD_CHANGE_REQUIRED`) ไม่ตัดสินเอง ตอนนี้ backend บังคับเฉพาะบัญชีที่สร้างใหม่และบัญชีที่เพิ่งถูกตั้งรหัสผ่านใหม่
(บัญชีเดิมที่ย้ายมาไม่ถูกบังคับตอนเข้าครั้งแรก) ข้อความบนจอ/เอกสารอย่าเขียนว่าทุกบัญชีต้องเปลี่ยน

**สิทธิ์** backend กันตามบทบาท (ไม่มีตารางสิทธิ์รายหน้าจอ) เมนูและปุ่มดูจาก `authProvider.canView(Perm.x)` / `Perm.view(Perm.x)`
ตารางบทบาทต่อหน้าจออยู่ที่ `Perm._allowedRoles` จุดเดียว ชื่อบทบาทใน API เป็นชื่อสั้น (`Roles`) หน้าเว็บแค่ซ่อน การกันจริงอยู่ที่ backend
บัญชีที่ยังต้องเปลี่ยนรหัสผ่าน `canView` คืนเท็จทุกหน้าจอ **ห้ามฝังชื่อผู้ใช้ (เช่น 030 / 999) ในโค้ด**

**หน่วยงาน** ห้ามให้ผู้ใช้พิมพ์รหัสหน่วยงานเอง ใช้ `DivSelector` (ตามขอบเขต `GET /api/divs`) หรือ `DivDropdown` (มีรายการอยู่แล้ว)
backend ตรวจสิทธิ์กับหน่วยงานซ้ำทุกคำขอ (403 `DIV_FORBIDDEN`)

**รหัสผ่าน** กติกาอยู่ที่ `PasswordRules` (8–72 ตัว พิมพ์ใหญ่ พิมพ์เล็ก ตัวเลข อักขระพิเศษ = ตัวใดก็ได้ที่ไม่ใช่ A-Z a-z 0-9)
ต้องตรงกับ `PasswordPolicy.java` ของ backend หน้าต่างที่ตั้งรหัสผ่านทุกตัวใช้ `PasswordField` + `PasswordRuleList`

**เรียก API** เมธอดใหม่ใน `ApiService` ใช้ `_authedRequest` แล้วโยน `_apiError` เมื่อไม่ใช่ 200
หน้าจอแสดง `e.toString()` ได้เลย แยกกรณีด้วย `ApiException.code` เทียบ `ErrorCodes` ห้ามจับคำในข้อความ
ได้ **401**: interceptor ต่ออายุ token แล้วยิงซ้ำครั้งเดียว (refresh token ใช้ได้ครั้งเดียว เก็บตัวใหม่ทันที) ต่ออายุไม่ได้ = ออกจากระบบ
ได้ **403**: ไม่ต่ออายุ (เป็นเรื่องสิทธิ์/ช่วงเวลา/ต้องเปลี่ยนรหัสผ่าน) `PASSWORD_CHANGE_REQUIRED` ทำให้เปิดหน้าต่างบังคับเปลี่ยนรหัสผ่านเอง
เส้นสาธารณะ (`GET /api/alert-message`) ใช้ `publicDio`

**ข้อมูลบุคคล** เลขประจำตัวประชาชนและชื่อ-สกุล: ส่งในตัวคำขอ `POST` เท่านั้น **ห้ามอยู่ใน URL/query และห้ามลง log**
(ไม่เรียก `AppLogger` ด้วยตัวข้อมูลของเส้น debts/persons/deducts/loans) ตรวจเลขบัตรด้วย `IdCard.isValid` ก่อนส่ง
รายการที่ไม่จำเป็นต้องเห็นทั้งเลขใช้ `IdCard.masked` ข้อมูลในเทสต์ใช้ `fakeIdCard(n)` เท่านั้น

**จำนวนเงิน** เก็บเป็นสตางค์ (int) ผ่าน `Money` ทั้งหน้าเว็บ: `Money.fromJson` อ่านจาก backend, `Money.parse` อ่านที่ผู้ใช้พิมพ์
(null = ผิดรูป), `Money.format` แสดง `1,500.50`, `Money.toJson` ส่ง `"1500.50"` ห้ามบวก/เทียบ double ตรง ๆ
รหัสหนี้มี 5 รหัส (`DebtCodes.fields`) **ไม่มี 40604** และโครงการเงินกู้ไม่มี `flg` 4 — ห้ามเพิ่มกลับในช่องบันทึก

**ตารางแก้ในแถว** ใช้ชิ้นส่วนจาก `widgets/sheet_table.dart`: ครอบ `SheetScroll(minWidth:)` (จอแคบเลื่อนแนวนอน ไม่บีบคอลัมน์)
+ `SheetCard(header:, rows:)` คอลัมน์จัดด้วย `Expanded(flex)` ชุดเดียวกันทั้งหัวและแถว ปุ่มท้ายตาราง `SheetButton.delete / selectAll / add`
ช่องในแถวใช้ `sheetInput()` ช่องติ๊กหัวตาราง `SheetHeaderCheckbox` หน้าที่มีการแก้ค้างต้องมีข้อความ "มีการแก้ไขที่ยังไม่ได้บันทึก"
และถามก่อนทิ้ง (`PopScope` + `AppDialog.showConfirm`) วงหมุนโหลดต้องหยุดก่อนเปิดหน้าต่างแจ้งผล (ไม่งั้นเทสต์ `pumpAndSettle` ค้าง)

**สิทธิ์แก้ยอด** ตารางหนี้เปิดให้แก้เมื่อ `DebtPage.editable` (backend ตัดสิน: งวดปัจจุบัน + งวดพร้อม + ช่วงแก้ไขหรือ ACCOUNT)
ไม่คำนวณเองจากนาฬิกา backend ตอบ `EDIT_WINDOW_CLOSED` ตอนบันทึก = เปลี่ยนเป็นอ่านอย่างเดียวและเรียก `SettingsProvider().load()`

**แจ้งผล** `context.showSuccessSnackBar / showErrorSnackBar / showInfoSnackBar`, `AppDialog.showConfirm / showSuccess / showError`
**แบ่งหน้า** ใช้ `AppPagination` ทุกจุด **ภาษา** ข้อความบนจอและคอมเมนต์เป็นภาษาไทยทั้งหมด
**ป้ายช่วงทดสอบ** `TestPhaseBanner` ใน `MaterialApp.builder` ของ `main.dart` เปิดใช้จริงแล้วให้เอาออก
**ไม่เพิ่ม package โดยไม่จำเป็น** (ตอนนี้มี dio, flutter_secure_storage, intl, universal_html)

## เทสต์ (`test/`)

`fake_backend.dart` = backend จำลอง (HttpClientAdapter) ตามสัญญาจริงของ backend ต่อกับ `ApiService` ด้วย `installFakeBackend()`
บัญชีจำลอง (รหัสผ่าน = `FakeBackend.passwordOf(ชื่อผู้ใช้)`): `901` USER, `902` ACCOUNT+ALL_DEPT, `903` RESETPWD, `904` CENTER_DEPT,
`905` ALL_DEPT, `906` ต้องเปลี่ยนรหัสผ่าน, `907` ถูกล็อก, `908` ถูกระงับ, `909` ADMIN+RESETPWD, `910`–`926` USER (รวม 26 บัญชี)
ตัวปรับ: `expireAccessTokens()`, `revokeRefreshTokens()`, `unreachable`, `serverTime` (ตัดสินช่วงแก้ไขเปิด/ปิด), `alertStatus`,
`rolesStatus`, `hideMustChangeInLogin` ส่วนระยะที่ 2 อยู่ที่ `fake_backend_phase2.dart` (`backend.p2`): ข้อมูลหลัก รายการหนี้ 32 คน
(901: G 25 + E 3, 902: G 2, 904, 915) ทะเบียน เงินกู้ ตัวปรับ `dpisFails`, `jobRunning`, `periodReady`, `notCurrentPeriod`, `sendInRoster`,
`deductDuplicates`, `editsSincePrepare` เลขบัตรสมมุติ `fakeIdCard(n)` แก้สัญญาฝั่ง backend แล้วต้องแก้ไฟล์นี้ให้ตรงก่อนเสมอ

| ไฟล์ | ครอบคลุม |
|---|---|
| `session_flow_test` | เข้าสู่ระบบ บทบาททั้ง 6 เมนูตามบทบาท (กลุ่มเมนูตามลำดับงานประจำงวด เมนูที่ยกเลิกต้องไม่มี ทุกเมนูเปิดหน้าจอจริง) ต่ออายุ token ออกจากระบบ ตรึงเมนู |
| `div_status_test` | สถานะการบันทึกของหน่วยงาน: สรุป/แถบความคืบหน้า ตัวกรอง เรียง แบ่งหน้า กดแถว คัดลอกรายชื่อ `audit_available` เท็จ `period_ready` เท็จ div_order null / div ว่าง งวดไม่มีรายการ 404 และขั้น "หน่วยงานบันทึกหนี้" ของความคืบหน้าของงวด |
| `alert_message_placement_test` | ข้อความแจ้งผู้ใช้งานมีที่หน้าแรกกล่องเดียว หน้าอื่น 18 หน้า หน้าต่างเข้าสู่ระบบ และเมนู ไม่มี |
| `chapana_slip_test` | รายงานฌาปนกิจ-สลิป: ไม่เรียกเองตอนเปิด สรุป ตารางผู้ที่หักไม่ได้ (แบ่งหน้า เลขบัตรปิดบางส่วน จ่ายให้กับหลายบรรทัด) PDF หักได้ครบ ยังไม่ได้นำเข้า ข้อผิดพลาด 503/502 สิทธิ์ |
| `phase3_test` | ตัวช่วยดาวน์โหลด (ชื่อไฟล์ ไบต์เท่าเดิม 404 เป็น JSON สิทธิ์) ไฟล์ส่งกรมบัญชีกลาง ตรวจยอดเงินกู้ รายงานส่งธนาคาร (`LOAN_AMOUNT_MISMATCH`) รายงาน PDF นำเข้าฌาปนกิจ/สหกรณ์ (dry run ปัญหา 4 ชนิด ยืนยันแทนที่ แก้การจับคู่) ความคืบหน้าของงวด ค้นบุคคล `truncated` ประวัติรายการเก่า |
| `home_screen_test` | หน้าแรกก่อน/หลังเข้าสู่ระบบ ข้อความแจ้ง (ยาว ว่าง ผิดพลาด) การ์ดหน่วยงาน งวด ระยะเวลาแก้ไข |
| `settings_screens_test` | กำหนดเดือนปี ข้อความแจ้ง (ตัวอย่างการแสดงผล) ระยะเวลาแก้ไข โมเดล Period / EditWindow สิทธิ์ ACCOUNT |
| `thai_date_range_picker_test` | ตัวเลือกช่วงวันที่: แตะสองครั้ง ลาก (นิ้ว/เมาส์) ข้ามเดือน/ปี ขอบ first/last สองเดือน/เดือนเดียว วันนี้ ยกเลิก คีย์บอร์ด |
| `debt_entry_test` | บันทึกข้อมูล: แก้ในแถว บันทึกเฉพาะที่แก้ ค้นชื่อ (POST) ยอดรวม ประวัติ ขอบเขตหน่วยงาน ช่วงแก้ไขปิด งวดไม่พร้อม แถว 5/10/15/20 ดูงวดย้อนหลังอ่านอย่างเดียว (month/year, ห้ามงวดอนาคต, งวดว่าง, ถามก่อนทิ้ง) และยืนยันว่าไม่มีเพิ่มคน/ปรับรายชื่อ/ย้าย/ลบ แม้เป็น ACCOUNT |
| `master_data_test` | ข้อมูลหลัก 4 ตาราง แก้ในแถว: แก้หลายแถวบันทึกครั้งเดียว เพิ่มแถว ลบที่เลือก เลือกทั้งหมด ข้อผิดพลาดรายแถว (`DUPLICATE` / `IN_USE` / `BAD_REQUEST`) เตือนก่อนทิ้ง (เรียง/ค้น/เปลี่ยนหน้า/เปลี่ยนธนาคาร) สาขาตามธนาคาร รหัส 40604 สิทธิ์ ACCOUNT |
| `period_jobs_test` | นำเข้า DPIS (`JOB_RUNNING`, `DPIS_ERROR`) เตรียมงวด (สรุป ยืนยันก่อนล้าง `CONFIRM_REQUIRED` + details) |
| `deduct_loan_test` | ตัวค้นหาบุคคล ทะเบียน กบข/สหกรณ์/ภาษี (สร้าง แก้เฉพาะช่องที่เปลี่ยน ลบ duplicates) เลขที่บัญชีเงินกู้ (แก้ในแถว ลำดับการบันทึก ไม่มี flg 4) |
| `money_test` | Money, IdCard, BeDate, โมเดลรายการหนี้ เวลาจาก backend |
| `user_admin_test` | เส้น /api/admin รายการผู้ใช้ กำหนดรหัสผ่านใหม่ เพิ่ม/แก้ไข/ระงับ/ปลดล็อก |
| `div_selector_test` | ตัวเลือกหน่วยงานตามขอบเขต OWN / CENTER / ALL |
| `change_password_test`, `login_dialog_test`, `password_rules_test` | หน้าต่างเปลี่ยนรหัสผ่าน หน้าต่างเข้าสู่ระบบ กติการหัสผ่าน |
| `narrow_screen_test` | จอ 320 จุด: ทุกหน้าจอและหน้าต่างไม่ล้นกรอบ |
| `theme_test`, `common_widgets_test`, `thai_date_picker_test`, `util_test`, `logger_test` | ส่วนกลางจากต้นแบบ |

ใน `testWidgets` อย่า `await` คำขอ Dio ตรง ๆ (ค้าง) ให้เข้าสู่ระบบด้วย `tester.runAsync` แล้วทำต่อด้วยการกดปุ่ม + `pumpAndSettle`
หลัง `ensureVisible` ต้อง `pumpAndSettle` ก่อนแตะ รายการท้าย ListView ยังไม่ถูกสร้างจนกว่าจะเลื่อนถึง (ใช้ `scrollUntilVisible`)
เทสต์ที่วัดขนาดให้ `setUpAll(loadAppFonts)` และใช้ `theme: AppTheme.lightTheme`
ข้อมูลในเทสต์เป็นค่าสมมุติทั้งหมด (รหัสหน่วยงาน 9xx) ห้ามใช้ชื่อบุคคลจริง เลขประจำตัว รหัสผ่านหรือ token จริง

## แผนระยะถัดไป

ก้อน ก–ฉ ของ `C:\AI\springboot\dpay\docs\api.md` ทำครบแล้ว ที่เหลือ:

1. ทุกก้อนของสัญญา backend (ก–ช) มีหน้าจอครบแล้ว รวมรายงานฌาปนกิจ-สลิป (`chapana_slip_screen.dart`)
2. ทดสอบกับ backend จริง (ทุกอย่างของระยะที่ 2–3 ตรวจกับ backend จำลองเท่านั้น)
3. ก่อนเปิดใช้จริง: เอา `TestPhaseBanner` ออก เปลี่ยนไอคอนเว็บ

ทุกหน้าจอของข้อมูลหักหนี้: เลือกหน่วยงานด้วย `DivSelector` อ่านงวดจาก `SettingsProvider().period`
และรับ 403 `EDIT_WINDOW_CLOSED` / `DIV_FORBIDDEN` จาก backend

### ข้อตัดสินของผู้ใช้เรื่องหน้าตาราง (13 ต.ค. 2569) — อย่าย้อนกลับ

- **ข้อมูลหลักทั้ง 4 ตารางแก้ในแถวของตาราง** (`master_screen.dart` + `MasterLine`) ไม่มีหน้าต่างเพิ่ม/แก้ไข (`master_dialog.dart` ลบแล้ว)
  บันทึกเฉพาะแถวที่แก้/เพิ่ม ทีละแถว ข้อผิดพลาดของ backend อยู่ใต้แถวนั้น (`MasterLine.error` / `badFields`) แถวที่ผ่านแล้วไม่ส่งซ้ำ
  บันทึกไม่ครบ = ไม่โหลดใหม่ (ค่าที่พิมพ์ต้องอยู่) ลบที่เลือกใช้เส้นลบหลายรายการในคำขอเดียว (`deleteMasterMany`) ผลรายรายการอยู่ใต้แถว
- **หน้า "บันทึกข้อมูล" ทำได้อย่างเดียวคือแก้ไขยอดหนี้ 5 รหัส** — ห้ามใส่ปุ่มเพิ่มคน ปรับรายชื่อตาม DPIS ย้ายหน่วยงาน ลบรายการ
  หรือช่องติ๊กเลือกแถวกลับมา (ทุกบทบาท รวม ACCOUNT) คนที่เข้ามาใหม่ระหว่างงวดจะอยู่ในงวดถัดไปตอนเตรียมงวด
  เมธอด/หน้าต่าง/เส้นใน fake backend ของสี่อย่างนี้ลบออกแล้ว ป้าย `in_roster` เท็จและประวัติการแก้ไขรายแถวยังอยู่
  ปุ่ม "ลบที่เลือก / เลือกทั้งหมด / เพิ่ม" มีเฉพาะหน้าข้อมูลหลักและเลขที่บัญชีเงินกู้
- **งวดย้อนหลังดูได้อย่างเดียว**: `_past` ใน `debt_entry_screen.dart` (null = งวดปัจจุบัน ไม่ส่ง `month`/`year`) เลือกเกินงวดปัจจุบันไม่ได้
  (`YearStepper.max` + `MonthPicker.lastMonth`) ไม่มีปุ่มบันทึก มีแถบ `pastNoticeKey` + ปุ่ม "กลับไปงวดปัจจุบัน"
- **แถวต่อหน้า 5 / 10 / 15 / 20 ค่าเริ่มต้น 10 ทั้งระบบ** (`AppPagination.pageSizeOptions`) ไม่มี 50/100
  ส่วนที่ดึงตัวเลือกด้วย size ใหญ่ (`allMaster` size=2000, ค้นคน size=50) ไม่เกี่ยว คงเดิม
- **สถานะการบันทึกของหน่วยงานใช้เกณฑ์เดียว: มีการแก้ยอดในงวด** (`edited` จาก `GET /api/debts/div-status`) — **ไม่ต้องมีปุ่ม "ยืนยันว่าตรวจแล้ว"** ของหน่วยงาน
  ใต้การ์ดสรุปมีข้อความ `DivStatusScreen.criteriaText` ("ยังไม่บันทึก หมายถึงยังไม่มีการแก้ยอดในงวดนี้ รวมหน่วยงานที่ไม่มีรายการต้องแก้")
  `audit_available` เท็จ = ห้ามขึ้นป้าย "ยังไม่บันทึก" (แสดงแถบ "งวดนี้ไม่มีประวัติการแก้ไขในระบบใหม่…" แทน)
- **แถบยอดรวมของหน้าบันทึกข้อมูลคงไว้ตามเดิม** (อยู่แถบล่างที่ไม่เลื่อน) — ไม่ต้องทำปุ่มย่อ/ซ่อนบนจอเล็ก
- **นำเข้าสหกรณ์เฉพาะงวดปัจจุบัน** (ไม่มีตัวเลือกงวดในหน้านั้น) — backend ตอบ 409 `NOT_CURRENT_PERIOD` เมื่อไม่ใช่งวดปัจจุบัน
  หน้านำเข้าสหกรณ์ หน้าต่างแก้การจับคู่ และนำเข้าฌาปนกิจ แสดงข้อความ `periodChangedHint` (`widgets/work_parts.dart`) ให้ปิดแล้วเปิดหน้าใหม่
- **หน้าแรกไม่มีส่วนหัวภาพขนาดใหญ่และปุ่มเข้าสู่ระบบในเนื้อหา**: ก่อนเข้าสู่ระบบ = แถบบาง ๆ `HomeScreen.loginStripKey` (ข้อความ `loginPrompt` บรรทัดเดียว) แล้วตามด้วย
  กล่องข้อความแจ้งทันที; หลังเข้าสู่ระบบ = ข้อความแจ้ง → การ์ดหน่วยงาน/งวด/ช่วงแก้ไข → ความคืบหน้าของงวด ปุ่มเข้าสู่ระบบมีที่แถบบน (`CustomHeader.loginButtonKey`) ที่เดียว
  ห้ามใส่แบนเนอร์/ภาพหัวกลับมา (ลบ `assets/images/banner.jpg` และรายการ assets ใน pubspec แล้ว)
- **"ข้อความแจ้งผู้ใช้งาน" แสดงที่หน้าแรกหน้าเดียว** (`AlertMessageBox` ใน `home_screen.dart` กล่องเดียว ทั้งก่อนและหลังเข้าสู่ระบบ) — ห้ามใส่ในหน้าอื่น
  หน้าต่างเข้าสู่ระบบ เมนู หรือการ์ดความคืบหน้าของงวด ยกเว้นตัวอย่างการแสดงผลในหน้าแก้ไขข้อความของ ACCOUNT (`alert_message_placement_test` คุมไว้)
- **หน้าจอออกแบบใหม่ได้ ไม่ต้องเหมือนระบบเดิม** — จัดให้ใช้ง่ายตามมาตรฐาน template/sliptax (การ์ด แถบสรุป สถานะชัดเจน)
  ลำดับงานประจำงวดของฝ่ายบัญชี: กำหนดงวด → ช่วงแก้ไข → นำเข้าบุคลากร → เตรียมงวด → หน่วยงานบันทึกหนี้ → นำเข้าฌาปนกิจ/สหกรณ์
  → ตรวจ/ไฟล์ส่งกรมบัญชีกลาง → รายงาน แต่ต้องคงข้อตัดสินข้างบนทั้งหมด และชื่อเมนูหลักที่ผู้ใช้คุ้นต้องยังค้นเจอ
  ทำแล้วในหน้าบันทึกข้อมูล: เครื่องหมายแถวที่แก้ (`changedKey`) และ Enter/Tab ไปช่องถัดไป
  ทำแล้วในระยะที่ 3: หัวตารางตรึง (`SheetPinnedHeader`) ยอดรวมในแถบล่าง "ความคืบหน้าของงวด" บนหน้าแรกของ ACCOUNT (`PeriodProgress`)
  และเมนูข้างเรียงตามลำดับงานประจำงวด

### แบบของหน้า "บันทึกข้อมูล" (บันทึกรายการหนี้): ทำตาม "ใบแจ้งค่าอาหาร" ของ HTC (ผู้ใช้สั่ง)

ต้นแบบ: `C:\AI\flutter\htc\lib\screens\food_invoice_screen.dart` (อ่านอย่างเดียว) — เอกสารหนึ่งใบ = หัวกระดาษแบบตาราง + ตารางแก้ไขในแถว
บันทึกทีเดียวทั้งใบ — ระยะที่ 2 ทำแล้วที่ `debt_entry_screen.dart` / `loan_screen.dart` ด้วยชิ้นส่วนกลาง `widgets/sheet_table.dart`

**โครง widget**

- `Scaffold` + `AppBar` (ปุ่มปิด `Icons.close` + ชื่อเอกสาร) ครอบด้วย `PopScope(canPop: false)` ถามยืนยันเมื่อมีการแก้ไขค้าง
- เนื้อหา: `LayoutBuilder` → `SingleChildScrollView` (แนวตั้ง) → `SingleChildScrollView` (แนวนอน) → `SizedBox(width:)`
  ตารางกว้างอย่างน้อย 1,200 จุด (`_minTableWidth`) จอแคบกว่านั้นเลื่อนแนวนอน ไม่บีบคอลัมน์
- ตัวเอกสารเป็น `Container` พื้นขาวมีเส้นขอบสีธีมจาง (`primaryColor` alpha 0.45) ข้างในเป็น `Column` ของแถว
- แถวหัวกระดาษสร้างด้วยตัวช่วย `_row([_cell(flex, child, align:)])`: `Row` ของ `Expanded(flex)` มีเส้นคั่นขวา/ล่าง สูงอย่างน้อย 40
  แถวหลายช่องครอบ `IntrinsicHeight` ให้ช่องสูงเท่ากัน แถวช่องเดียวไม่ครอบ (IntrinsicHeight คำนวณความสูงปุ่ม/ช่องกรอกเพี้ยน)
- ลำดับแถว: ชื่อเอกสาร (กลาง ตัวหนา) → ป้าย+ค่า (ชื่อ, ช่วงวันที่ไทย) → ยอดรวม (ชิดขวา) → **กล่องตารางแก้ไข** → รวมเงินทั้งหมด (ชิดขวา ตัวหนา)
  → หมายเหตุ (TextField แถวเดียว) → ผู้บันทึก + วันที่ไทย (มุมขวาล่าง) → แถบปุ่มท้ายเอกสาร

**ตารางแก้ไขในแถว** (`_linesBox`)

- กล่องพื้นเทาอ่อนมุมมน ข้างในเป็นการ์ดขาวมีเส้นขอบ: แถวหัวคอลัมน์ (ตัวหนาสีธีม) ตามด้วยหนึ่ง `Row` ต่อหนึ่งรายการ
- คอลัมน์จัดด้วย `Expanded(flex)` ชุดเดียวกันทั้งหัวและแถว ต้นแบบใช้ ช่องติ๊ก `SizedBox(width: 34)` แล้ว flex 6 / 2 / 2 / 2 / 4 / 4 / 2
  = รายการ (dropdown) / ราคา (ข้อความชิดขวา) / ตัวเลข / ตัวเลข / วันที่เริ่ม / วันที่สิ้นสุด / จำนวนเงิน (คำนวณ ชิดขวา)
- ช่องติ๊กหัวคอลัมน์เป็น `Checkbox(tristate: true)`: เลือกบางแถว = ขีดกลาง กดแล้วเลือก/ยกเลิกทั้งหมด
- รายการ: `DropdownButtonFormField` (`isExpanded`, `InputDecoration` แบบ `isDense` พื้นขาว ขอบมน 6) แสดงเฉพาะรายการที่ยังใช้งาน
  **ยกเว้นรายการที่แถวนั้นใช้อยู่** (ไม่งั้นค่าเดิมหาย) เลือกแล้วค่าที่ผูกกับรายการ (เช่นราคา) ถูกล็อกตาม
- ตัวเลข: `TextFormField` `textAlign: right` + `FilteringTextInputFormatter.digitsOnly` ค่าผิดไม่กันตอนพิมพ์ ไปเตือนตอนบันทึก
- วันที่: `InkWell` + `InputDecorator` มี `suffixIcon` ปฏิทินเล็ก แสดง `Util.formatThaiDate` ("เลือกวันที่" สีเทาเมื่อว่าง)
  แตะแล้วเปิดปฏิทิน พ.ศ. (ในโปรเจกต์นี้ใช้ `showThaiDatePicker`)
- ยอดคำนวณต่อแถวและยอดรวมจัดรูป `#,##0.00` ชิดขวา คำนวณใหม่ทุก `setState`
- ไม่มีรายการ = ข้อความสีเทา "ยังไม่มีรายการ กดปุ่มเพิ่มเพื่อสร้างรายการ"
- ปุ่มท้ายตารางชิดขวา สูงคงที่ 44 (`tapTargetSize: shrinkWrap` กันแถวล้น): **"ลบที่เลือก"** (แดง `AppTheme.deleteColor`)
  **"เลือกทั้งหมด"** (เทา `AppTheme.neutralColor`) **"เพิ่ม"** (เขียว `AppTheme.addColor`)
- แถบปุ่มท้ายเอกสารชิดขวา: ข้อความ "มีการแก้ไขที่ยังไม่ได้บันทึก" (สีเตือน เมื่อมีการแก้ไขค้าง) + พิมพ์ (`printColor`) + บันทึก (`saveColor`) + กลับ (`neutralColor`)
  ปุ่มปิดตามสิทธิ์และระหว่างทำงาน

**สถานะและการบันทึก**

- โมเดลแถวแก้ไขได้ (mutable) มี `id` (null = แถวใหม่ยังไม่อยู่ในฐาน) `selected` และ getter `signature` (ต่อค่าทุกช่องเป็นข้อความ)
- ตอนโหลดเก็บ `_originalSignatures` กับ `_originalIds` → `_dirty` = signature ปัจจุบันต่างจากตอนโหลด (หรือจำนวนแถวต่าง / หมายเหตุต่าง)
- "เพิ่ม" = ต่อแถวใหม่ท้ายตารางด้วยค่าตั้งต้น (ลำดับถัดไป) "ลบที่เลือก" = เอาออกจากหน้าจอเท่านั้น แล้วแจ้ง "กดบันทึกเพื่อยืนยัน"
- "บันทึก": `_validate()` ไล่ทีละแถวแล้วคืนข้อความแรกที่ผิด ("แถวที่ N ...") รวมกันรายการซ้ำ → ลบ id ที่หายไปจากหน้าจอ → สร้างแถวที่ไม่มี id
  → อัปเดตแถวที่มี id → โหลดใหม่ทั้งใบ (ได้ id ของแถวใหม่ และล้างสถานะแก้ไขค้าง) ผิดพลาดกลางทางก็โหลดใหม่ให้ตรงของจริง
- ออกจากหน้า/พิมพ์ทั้งที่ยังแก้ไขค้าง → `AppDialog.showConfirm`

**ปรับใช้กับบันทึกรายการหนี้**

- หัวกระดาษ: หน่วยงาน (`DivSelector`) ประเภท G/E งวดปัจจุบัน (`Period.label`) ยอดรวมหนี้ของหน่วยงาน สถานะช่วงแก้ไข
- ตาราง: หนึ่งแถวต่อคน คอลัมน์ ช่องติ๊ก / บุคลากร (ค้นหาได้) / จำนวนเงินของ 5 รหัสหนี้ (ตัวเลขชิดขวา) / รวม (คำนวณ ชิดขวา)
  ถ้ารายการหนี้ต่อคนมีวันที่หรือเลือกเจ้าหนี้ ให้ใช้ช่องวันที่ไทยและ dropdown แบบเดียวกับต้นแบบ
- ปุ่มท้ายตารางชุดเดียวกัน (ลบที่เลือก / เลือกทั้งหมด / เพิ่ม) ปิดทั้งชุดและปุ่มบันทึกเมื่อ `!SettingsProvider().canEditNow`
- **ควรขอ endpoint บันทึกทั้งชุดในคำขอเดียวจาก backend** (ต้นแบบ HTC ยิงลบ/สร้าง/อัปเดตทีละแถว ล้มกลางทางแล้วข้อมูลค้างครึ่งเดียว
  และ MongoDB ของระบบนี้ไม่ใช้ transaction) หน้าเว็บส่งรายการทั้งหมดของหน่วยงาน+ประเภท+งวด แล้ว backend เทียบและเขียนเอง
- จำนวนเงินเป็นทศนิยม: เก็บเป็นสตางค์ (int) หรือใช้ตัวจัดรูปเดียวกันทั้งหน้า อย่าบวก double ตรง ๆ แล้วเทียบเท่ากัน

## ระยะที่ 3: งานประจำงวด ไฟล์ และรายงาน

- **เส้น**: `lib/services/work_api.dart` (`extension WorkApi on ApiService`) — ทุกเมธอดรับ `Period? period` (null = งวดปัจจุบัน ไม่ส่ง month/year)
  ดาวน์โหลดไฟล์ใช้ `downloadFile` (ขอเป็นไบต์ด้วย `request(..., bytes: true)`; คำตอบที่ไม่ใช่ 200 ถูกแปลงกลับเป็น JSON ให้อ่าน `code`/`message` ได้)
  อัปโหลดใช้ `FormData` ผ่าน `request(data:)` — **ห้ามแปลงไฟล์เป็นข้อความ** (ไฟล์ส่งกรมบัญชีกลางเป็น TIS-620 ต้องเท่าเดิมทุกไบต์)
- **ดาวน์โหลด**: `lib/utils/file_download.dart` — `FileSaver.instance.save(DownloadedFile)` คืน `SavedFile` (เปิดดู / dispose)
  ของจริงใช้ Blob + object URL เทสต์ตั้ง `FileSaver.instance` เป็นตัวจำลอง (ดู `FakeSaver` ใน `test/phase3_test.dart`)
  หน้าจอใช้ mixin `FileDownloads` + `DownloadButtons` (`lib/widgets/work_parts.dart`): กันกดซ้ำ เก็บไฟล์ไว้ให้เปิดดู คืนหน่วยความจำตอนปิดหน้า
  **ไฟล์มีข้อมูลบุคคล — ห้ามเก็บลง localStorage/IndexedDB ห้ามลง log**
- **เลือกไฟล์**: `lib/utils/file_pick.dart` (`pickTextFile`, typedef `FilePicker` ให้หน้าจอรับตัวจำลองในเทสต์) ไม่ใช้แพ็กเกจ file_picker
- **ตัวเลือกงวดกลาง**: `PeriodPicker` (`work_parts.dart`) ใช้ทุกหน้าที่ดูงวดย้อนหลังได้ รวมหน้าบันทึกข้อมูล — เลือกเกินงวดปัจจุบันไม่ได้
- **ความคืบหน้าของงวด**: `lib/widgets/period_progress.dart` — เพิ่ม/เรียงขั้นใน `_steps()` สถานะมาจากเส้นสรุป 5 เส้น แต่ละเส้นล้มได้ (ขั้นนั้นกลายเป็นทางลัด)
  ขั้น "หน่วยงานบันทึกหนี้" ใช้ `/api/debts/div-status` ("บันทึกแล้ว N จาก M หน่วยงาน" กดไป `DivStatusScreen`) — เส้นนี้ใช้ไม่ได้ (404) หรือ `audit_available` เท็จ
  = ไม่มีป้ายสถานะ แสดงจำนวนจาก `/api/period/prepare` ประกอบ
  ผู้ใช้ทั่วไป (ไม่ใช่ฝ่ายบัญชี) เห็นเฉพาะขั้นที่ `_Step.general` = ขั้น 5 หน่วยงานบันทึกหนี้ (ไป `DebtEntryScreen` บอกว่าแก้ได้/ดูอย่างเดียวตาม `canEditNow`)
  กับขั้น 12 รายงาน — เลขขั้นคงเดิม และไม่เรียกเส้นสรุปของฝ่ายบัญชี (ผู้ใช้สั่ง 15 ต.ค. 2569)
  fake: `backend.p2.seedAllDivs()` ให้ทุกหน่วยงานมีรายการ, `backend.p3.divStatusMissing / auditAvailable / divStatusOddRows`
- **ฌาปนกิจ-สลิป** (ก้อน ช): `getChapanaSlipCheck` / `downloadChapanaNotPay` ใน `work_api.dart` — เรียกข้ามระบบ (ระบบสลิปภาษี + DPIS) จึง**กดปุ่มจึงเรียก**
  ห้ามเรียกอัตโนมัติจากหน้าแรก (ขั้นในความคืบหน้าของงวดเป็นทางลัดเฉย ๆ) `_authedRequest` รับสถานะ 503 กลับมาเหมือน 4xx เพื่ออ่าน `code`
  ความหมายที่ผู้ใช้ให้: ยอดในรายการฌาปนกิจ = เงินที่ต้องการหัก, ยอดในสลิป = เงินที่หักได้จริง, ผู้ที่ขาด = เงินไม่พอให้หักหรือเกษียณ/พ้นสภาพแล้ว
  คำตอบมีเลขบัตรและชื่อ — ห้ามลง log / storage; fake: `backend.p3.slipError`, `slipNotPaid`
- **เมนูข้าง**: กลุ่มของฝ่ายบัญชีเรียงตามลำดับงาน ข้อมูลงวด → ฌาปนกิจและสหกรณ์ → บันทึกข้อมูลธนาคาร → ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร → บันทึกรายการหลัก
  กลุ่ม "สร้างไฟล์ส่งกรมบัญชีกลาง (ข้าราชการ/ลูกจ้างประจำ)" ของระบบเดิมไม่มีแล้ว (ไม่มีขั้นสร้างไฟล์) `SidebarMenu.cancelledMenus` คือเมนูที่ผู้ใช้สั่งยกเลิก ห้ามเพิ่มกลับ
- **หัวตารางตรึง**: `SheetPinnedHeader` (sliver) + `SheetScroll(controller:)` ตัวเดียวกัน หัวตารางเลื่อนแนวนอนตามตาราง — หน้าที่ใช้ต้องเป็น `CustomScrollView`
- **backend จำลอง**: `test/fake_backend_phase3.dart` (`backend.p3`: `sahaRows, sahaProblems, sahaUnresolved, sahaMapped, chapanaRows, chapanaRetired,
  cgdUnmappable, loanMismatches, missingAccounts, reportMissing`) ไฟล์ชื่อมีคำว่า `bad` = 400 ผิดรูปแบบ; ช่องของ multipart ถูกบันทึกใน `backend.bodyOf(...)`
  พร้อม `file` (ชื่อ) และ `file_size`

## เรื่องที่ต้องประสานฝั่ง backend

- `GET /api/admin/users` ไม่มีตัวกรองสถานะ (ใช้งาน/ระงับ/ล็อก/รอเปลี่ยนรหัสผ่าน) หน้าเว็บจึงตัดตัวกรองสถานะของต้นแบบออก
- ไม่มีเส้นลบผู้ใช้ (ตั้งใจ — ใช้ระงับ) ชื่อผู้ใช้ตอนสร้างบัญชี = รหัสหน่วยงาน (เติมให้เมื่อเลือกหน่วยงาน แก้ได้สำหรับบัญชีพิเศษ) กติกา: ตัวเลขล้วน 3–10 หลัก
  (ผู้ใช้ตัดสิน 13 ต.ค. 2569 — backend ต้องปรับ `POST /api/admin/users` จากเดิม 3–20 ตัว a-z A-Z 0-9 . _ - ให้ตรงกัน)
- `lastLogin` ใน `UserAdminDTO` เป็น `LocalDateTime` — หน้าเว็บอ่านเป็นข้อความ ISO ถ้า Jackson ส่งเป็น array หน้าเว็บจะไม่แสดงเวลา (ไม่ล้ม) ยังไม่ได้ตรวจกับ backend จริง
- CORS: ต้องเพิ่ม origin ตอนพัฒนา (`http://localhost:5585`, `http://localhost:5586`) ใน `CORS_EXTRA_ORIGINS`
- (ได้แล้ว) บันทึกรายการหนี้ทั้งชุดในคำขอเดียว `PUT /api/debts`
- `in_roster` ยังไม่มีในรายการของ `GET /api/debts` (หน้าเว็บรองรับแล้ว ไม่มีก็ไม่ทำเครื่องหมาย)
- (ได้แล้ว) บันทึกเลขบัญชีเงินกู้ทั้งชุด `PUT /api/loans/set` และลบข้อมูลหลักหลายรายการ `POST /api/master/{resource}/delete`
- ยังไม่มีเส้นบันทึกข้อมูลหลักหลายแถวในคำขอเดียว (หน้าเว็บยิง `POST`/`PUT` ทีละแถว) และตารางหน่วยงานของข้อมูลหลักเรียกได้เฉพาะ ACCOUNT
- รูปของวันเวลา (`last_import_at`, `last_run_at`, `at`) ไม่ได้ระบุในสัญญา หน้าเว็บรับทั้งข้อความ ISO และเลขมิลลิวินาที
- (ได้แล้ว) ความหมายของ `rec_flg` / `kbk_flg` / `kbk_type` ตามหน้าจอระบบเดิม — ป้ายอยู่ที่ค่าคงที่ของ `DeductScreen` (`statusChoices`, `kbkMemberChoices`, `kbkSavingChoices`)
  ทะเบียนใหม่ตั้ง `kbk_flg` = 1, `kbk_type` = 1 เหมือน backend; `kbk_flg` = 0 ปิดช่อง กบข. ที่เหลือฝั่งหน้าเว็บเท่านั้น (สัญญาไม่ได้กำหนด)
- ค้นคนด้วยชื่อ (`div: "*"`) ต้องมีขอบเขต ALL — บัญชี ACCOUNT ที่ไม่ถือ ALL_DEPT จะค้นด้วยชื่อในหน้าทะเบียนไม่ได้ (ต้องใช้เลขบัตร)
- `GET /api/debts` ตอนงวดไม่พร้อม: หน้าเว็บรองรับทั้งแบบตอบรายการพร้อม `period_ready: false` และแบบตอบ 409 `PERIOD_NOT_READY`
