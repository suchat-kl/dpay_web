# dpay — หน้าเว็บระบบหักหนี้ กรมทางหลวง (Flutter Web)

หน้าเว็บของระบบหักหนี้ตัวใหม่ คู่กับ backend Spring Boot ที่ `C:\AI\springboot\dpay` มาแทนหน้าเว็บเดิม (`C:\AI\old\dp_flutter`)
โครงยกมาจากต้นแบบกลาง `C:\AI\template\flutter` (เมนูตรึงได้ ธีม 6 ชุด วันที่ไทย ปฏิทิน พ.ศ. หน้าต่างกลาง เทสต์ + backend จำลอง)

สถานะ: **ระยะที่ 3** — ครบตามสัญญา backend ก้อน ก–ฉ: บัญชีผู้ใช้ ค่าตั้งกลาง ข้อมูลหลัก งานงวด บันทึกรายการหนี้ ทะเบียนธนาคาร/กบข.
เลขบัญชีเงินกู้ นำเข้าฌาปนกิจ/สหกรณ์ ไฟล์ส่งกรมบัญชีกลาง ตรวจยอดเงินกู้ รายงานส่งธนาคาร และรายงาน PDF รายงานฌาปนกิจ-สลิป
**ผู้ใช้ทดสอบกับ backend จริงบนฐานพัฒนา dpc ครบทุกงานแล้ว (15 ต.ค. 2569)** — เทสต์อัตโนมัติยังใช้ backend จำลอง

## สิ่งที่มีในระยะที่ 1

- หน้าแรก: **ข้อความแจ้งผู้ใช้งาน** (ไม่ต้องเข้าสู่ระบบ) + ปุ่มเข้าสู่ระบบ หลังเข้าสู่ระบบแสดงหน่วยงานของผู้ใช้ งวดปัจจุบัน
  (เดือนไทย ปี พ.ศ.) และสถานะระยะเวลาแก้ไขข้อมูล (เปิด/ปิด ตั้งแต่–ถึง เป็นวันที่ไทย + เวลา และบัญชีนี้แก้ไขได้ตอนนี้หรือไม่)
- เข้าสู่ระบบด้วยบัญชีหน่วยงาน (ชื่อผู้ใช้ = รหัสหน่วยงาน 3 หลัก) ออกจากระบบ ต่ออายุ token อัตโนมัติ เปลี่ยนรหัสผ่านของตัวเอง
  ไม่มี ThaID / ลงทะเบียนเอง / ยืนยันสองชั้น
- **บังคับเปลี่ยนรหัสผ่าน**: เมื่อ login ตอบ `must_change_password` หรือ backend ตอบ 403 `PASSWORD_CHANGE_REQUIRED`
  เปิดหน้าต่างเปลี่ยนรหัสผ่านที่ปิดไม่ได้ (ออกจากระบบได้) จนเปลี่ยนสำเร็จ — backend เป็นผู้ตัดสินว่าบัญชีใดต้องเปลี่ยน
  (ตอนนี้เฉพาะบัญชีที่สร้างใหม่และบัญชีที่เพิ่งถูกตั้งรหัสผ่านใหม่ บัญชีเดิมที่ย้ายมาไม่ถูกบังคับ)
- เมนูตามบทบาท (ตารางด้านล่าง) ธีม 6 ชุด เมนูตรึงได้ ป้าย "ระบบงานอยู่ในช่วงทดสอบ"
- หน้า "ระยะเวลาแก้ไขข้อมูล" เลือกวันเริ่ม–วันสิ้นสุดในปฏิทินเดียว (แตะสองครั้งหรือลาก) ด้วย `showThaiDateRangePicker`
  ที่เขียนเอง (มาแทน SfDateRangePicker ของระบบเดิม — ไม่ใช้ syncfusion) + ช่องเวลาเริ่มต้น/สิ้นสุด HH:MM
  ช่องเวลาที่ยังไม่มีค่าจาก backend เติมเวลาตั้งต้นของงวด **06:00 – 16:30** ให้ (แก้ได้) เลือกช่วงวันใหม่**ไม่ตั้งเวลากลับ** —
  backend ตั้งเวลากลับเป็น 06:00–16:30 เองเมื่อฝ่ายบัญชีเปลี่ยนงวด (หน้ากำหนดเดือนปีโหลดระยะเวลาแก้ไขใหม่หลังบันทึก) พร้อมประโยคสรุป
  "แก้ไขได้ตั้งแต่ 21 กันยายน 2569 เวลา 06:00 น. ถึง 5 ตุลาคม 2569 เวลา 16:30 น"
- ตัวช่วยกลางสำหรับระยะถัดไป: ตัวเลือกหน่วยงาน `DivSelector` และ `SettingsProvider` (งวดปัจจุบัน ระยะเวลาแก้ไข `canEditNow`)

## สิ่งที่เพิ่มในระยะที่ 2

สัญญา API: `C:\AI\springboot\dpay\docs\api.md` (ก้อน ก–ค) เมธอดอยู่ที่ `lib/services/debt_api.dart`

- **บันทึกรายการหลัก** (ACCOUNT): ธนาคาร สาขา (เลือกธนาคารก่อน) รหัสหนี้ หน่วยงาน — ค้น แบ่งหน้า กดหัวคอลัมน์เพื่อเรียง
  **แก้ไขในแถวของตาราง** (ทุกแถวเป็นช่องกรอก หน่วยงานส่วนกลางเป็นตัวเลือก) ท้ายตารางมี "ลบที่เลือก / เลือกทั้งหมด / เพิ่ม"
  ("เพิ่ม" = แถวว่างต่อท้ายหน้าปัจจุบัน) ปุ่ม "บันทึก" ส่งเฉพาะแถวที่แก้/เพิ่ม ตรวจในแถวก่อนส่ง (ช่องบังคับ รูปแบบรหัส รหัสซ้ำในหน้า)
  ข้อผิดพลาดจาก backend (`DUPLICATE` / `IN_USE` / `BAD_REQUEST`) แสดงใต้แถวนั้น แถวที่ผ่านแล้วไม่ส่งซ้ำ แถวที่ไม่ผ่านคงค่าที่พิมพ์
  เตือนก่อนทิ้งการแก้ไขเมื่อเปลี่ยนหน้า/ค้นหา/เรียง/เปลี่ยนธนาคาร/ปิดหน้า
  รหัสหนี้ 40604 backend ไม่ส่งมาและหน้าเว็บไม่ให้เพิ่ม
- **นำเข้าข้อมูลบุคลากร** (ACCOUNT): สถานะล่าสุด (จำนวนคน เวลา ผู้สั่ง) ปุ่มกดซ้ำไม่ได้ระหว่างรอ แจ้ง `JOB_RUNNING` / `DPIS_ERROR`
- **เตรียมข้อมูลเดือนที่ผ่านมาเป็นงวดปัจจุบัน** (ACCOUNT): สรุปก่อนทำ งวดมีรายการแล้ว (หรือ backend ตอบ `CONFIRM_REQUIRED`)
  เปิดหน้าต่างยืนยันที่บอกจำนวนรายการที่จะถูกล้าง ต้องติ๊กรับทราบก่อนจึงส่ง `confirm_replace: true`
- **บันทึกข้อมูล** (ทุกบทบาท ตามขอบเขตหน่วยงาน): เลือกหน่วยงาน + ประเภท G/E → ตารางรายคนของงวดปัจจุบัน แก้ยอด 5 รหัสในแถว
  (ไม่มี 40604) ค้นชื่อ-สกุล ยอดรวมต่อรหัส บันทึกเฉพาะแถว/รหัสที่แก้ในคำขอเดียว เตือนก่อนทิ้งการแก้ไข ประวัติการแก้ไขรายแถว
  แถวที่แก้แล้วยังไม่บันทึกมีเครื่องหมายดินสอ กด Enter/Tab ไปช่องถัดไปได้
  **หน้านี้แก้ได้เฉพาะยอดหนี้** — ไม่มีการเพิ่มคน ปรับรายชื่อตาม DPIS ย้ายหน่วยงาน หรือลบรายการ (ทุกบทบาท รวมฝ่ายบัญชี)
  รายชื่อของงวดมาจากการเตรียมงวด บุคลากรที่เข้ามาใหม่ระหว่างงวดจะอยู่ในงวดถัดไป (ผู้ใช้ตัดสิน 13 ต.ค. 2569)
  **ดูงวดย้อนหลังได้แบบอ่านอย่างเดียว**: ปุ่ม "ดูงวดอื่น" เปิดตัวเลือกปี พ.ศ. + เดือน (เลือกเกินงวดปัจจุบันไม่ได้) ส่ง `month`/`year`
  ไปกับรายการ การค้นหา และยอดรวม มีแถบ "กำลังดูงวดย้อนหลัง … — ดูได้อย่างเดียว" พร้อมปุ่ม "กลับไปงวดปัจจุบัน" ไม่มีปุ่มบันทึก
  **อ่านอย่างเดียว**เมื่อช่วงแก้ไขปิด (พร้อมแถบบอกช่วงที่เปิด) งวดยังไม่เตรียม หรือไม่ใช่งวดปัจจุบัน
- **จำนวนแถวต่อหน้า** ของทุกรายการ (ผู้ใช้ รายการหนี้ ข้อมูลหลัก) เลือกได้ 5 / 10 / 15 / 20 ค่าเริ่มต้น 10 (`AppPagination.pageSizeOptions`)
- **บันทึกข้อมูลธนาคาร** (ACCOUNT): "กบข/กสจ. สหกรณ์และภาษี" (ฟอร์มรายคน) และ "เลขที่บัญชีเงินกู้" (หลายบัญชีต่อคน แก้ในแถว
  โครงการ 1/2/3/5/6 ไม่มี 4) ค้นคนด้วยเลขบัตรหรือชื่อ
  ป้ายของช่องทะเบียนใช้คำตามหน้าจอของระบบเดิม: สถานะ (ใช้/ไม่ใช้) การเป็นสมาชิก กบข/กสจ (เป็นสมาชิก/ไม่เป็นสมาชิก) การสะสมเข้า กบข/กสจ (สะสม/ไม่สะสม)
  วันที่เริ่มเป็นสมาชิก อัตราร้อยละการสะสม (+ กรณีสมัครใจ) จัดเป็นกลุ่ม บัญชีธนาคาร / สมาชิกสหกรณ์-ฌาปนกิจ / กบข-กสจ / รายการลดหย่อนภาษี — ค่าที่เก็บยังเป็น "0"/"1"
- **ข้อมูลบุคคล**: เลขบัตรประชาชนและชื่อส่งในตัวคำขอ (POST) เท่านั้น ไม่อยู่ใน URL ไม่ลง log รายการผลค้นแสดงเลขบัตรแบบปิดบางส่วน
- จำนวนเงินเก็บเป็นสตางค์ (`Money` ใน `lib/utils/money.dart`) ตารางกว้างเลื่อนแนวนอนได้บนจอแคบ (`SheetScroll`)

## สิ่งที่เพิ่มในระยะที่ 3

สัญญา API: `C:\AI\springboot\dpay\docs\api.md` (ก้อน ง–ฉ) เมธอดอยู่ที่ `lib/services/work_api.dart`
หน้าจอออกแบบใหม่ตามลำดับงานประจำงวดของฝ่ายบัญชี (ผู้ใช้อนุญาต — ไม่ต้องเหมือนระบบเดิม) ชื่อเมนูหลักยังเป็นคำที่คุ้น

- **หน้าแรก — "ความคืบหน้าของงวด"** (`PeriodProgress`) ฝ่ายบัญชีเห็นทุกขั้น ผู้ใช้ทั่วไปเห็นเฉพาะขั้น 5 หน่วยงานบันทึกหนี้ (แก้ได้เฉพาะในช่วงเวลา) และขั้น 12 รายงาน: ขั้นเรียงตามงานจริง กำหนดเดือนปี → ระยะเวลาแก้ไข → นำเข้าบุคลากร
  → เตรียมงวด → หน่วยงานบันทึกหนี้ → นำเข้าฌาปนกิจ → นำเข้าสหกรณ์ → ตรวจยอดเงินกู้ → ไฟล์ส่งกรมบัญชีกลาง → รายงานส่งธนาคาร → รายงาน
  แต่ละขั้นมีป้าย ทำแล้ว / ยังไม่ได้ทำ / ต้องแก้ จากเส้นสรุป กดแล้วไปเมนูนั้น กลับมาโหลดสถานะใหม่ ขั้นที่ไม่มีเส้นสรุป (หรือเส้นล้ม) เป็นทางลัดเฉย ๆ
- **สถานะการบันทึกของหน่วยงาน** (ACCOUNT เมนูในกลุ่ม "ข้อมูลงวด" ถัดจากเตรียมงวด — ใช้ตามหน่วยงานที่ยังไม่บันทึก): เลือกงวด การ์ดสรุป + แถบความคืบหน้า
  ตัวกรอง ทั้งหมด/บันทึกแล้ว/ยังไม่บันทึก + ส่วนกลาง/ภูมิภาค + ค้นรหัสหรือชื่อ ตารางเรียงตามลำดับหน่วยงาน (กดหัวคอลัมน์เรียง แบ่งหน้าฝั่งหน้าเว็บ)
  กดแถวไปหน้าบันทึกข้อมูลของหน่วยงาน/งวดนั้น ปุ่มโหลดใหม่ และ "คัดลอกรายชื่อหน่วยงานที่ยังไม่บันทึก" (รหัส + ชื่อ ลงคลิปบอร์ด)
  เกณฑ์เดียวคือ "มีการแก้ยอดในงวด" (ไม่มีปุ่มยืนยันว่าตรวจแล้ว) งวดที่ไม่มีประวัติในระบบใหม่ (`audit_available` เท็จ) แจ้งว่าบอกสถานะไม่ได้
  และไม่ขึ้นป้าย "ยังไม่บันทึก" · `period_ready` เท็จมีปุ่มไปหน้าเตรียมงวด · backend ที่ยังไม่มีเส้นนี้ (404) แสดงว่ายังใช้ไม่ได้
  ขั้น "หน่วยงานบันทึกหนี้" ของความคืบหน้าของงวดแสดง "บันทึกแล้ว N จาก M หน่วยงาน" และกดมาหน้านี้
- นำเข้าสหกรณ์ / แก้การจับคู่ / นำเข้าฌาปนกิจ ทำได้**เฉพาะงวดปัจจุบัน**: backend ตอบ 409 `NOT_CURRENT_PERIOD` (งวดถูกเปลี่ยนระหว่างเปิดหน้าค้าง) หน้าเว็บบอกให้ปิดแล้วเปิดหน้าใหม่
- **หน้าแรก** (ผู้ใช้สั่ง 13 ต.ค. 2569): ไม่มีส่วนหัวภาพขนาดใหญ่และปุ่ม "เข้าสู่ระบบ" สีเหลืองในเนื้อหาแล้ว — ก่อนเข้าสู่ระบบมีแถบบาง ๆ สีธีม
  "เข้าสู่ระบบด้วยรหัสหน่วยงานและรหัสผ่านของหน่วยงาน" แถวบนสุด แล้วตามด้วย**ข้อความแจ้งผู้ใช้งาน**ทันที (เห็นโดยไม่ต้องเลื่อน)
  หลังเข้าสู่ระบบ ข้อความแจ้งอยู่บนสุด ตามด้วยการ์ดหน่วยงาน/งวด/ช่วงแก้ไข และความคืบหน้าของงวด ปุ่มเข้าสู่ระบบมีที่แถบบนของแอปที่เดียว
  ข้อความแจ้งผู้ใช้งานแสดงที่หน้าแรกหน้าเดียวของระบบ (ยกเว้นตัวอย่างในหน้าแก้ไขข้อความของ ACCOUNT) ภาพ `assets/images/banner.jpg` ลบออกแล้ว
- **นำเข้าข้อมูลสหกรณ์** (ACCOUNT): เลือกประเภท G/E + ไฟล์ .txt/.dat (ไม่เกิน 5 MB) → **ตรวจไฟล์ก่อน** (`dry_run`) แสดงจำนวนแถว ยอดรวม
  จำนวนที่จับคู่ได้ และรายการที่มีปัญหาแยกชนิด (พบหลายคน / ไม่พบ / เลขบัตรปลอม / เลขบัตรถูกผูกแล้ว) → ยืนยันนำเข้า
  (มีข้อมูลเดิมบอกจำนวนที่จะถูกแทน ส่ง `confirm_replace`) ไฟล์ผิดรูปแบบบอกบรรทัดที่ผิด ด้านล่างเป็นรายการที่เลขบัตรยังเป็นเลขปลอม
  แก้การจับคู่รายคนได้ (ค้นคนด้วยเลขบัตร/ชื่อ) — นำเข้าได้เฉพาะงวดปัจจุบัน
- **นำเข้าข้อมูลฌาปนกิจ** (ACCOUNT): สรุปงวด ปุ่มดึงจาก DPIS (มีข้อมูลแล้วถามยืนยันแทนที่) รายชื่อผู้เกษียณ/พ้นสภาพในรายการ และปุ่มรายงาน rep10
- **ดาวน์โหลดไฟล์ข้อความส่งกรมบัญชีกลาง** (ACCOUNT): ตาราง 14 ไฟล์ (G/E × 6 รหัส + ไฟล์สรุป) จำนวนคน/ยอดต่อไฟล์ ดาวน์โหลดรายไฟล์
  หรือ zip ทั้งชุด/ต่อประเภท เตือนเมื่อมีอักขระที่ TIS-620 ไม่มี — **กลุ่มเมนู "สร้างไฟล์ส่งกรมบัญชีกลาง" 14 รายการของระบบเดิมไม่มีแล้ว**
  (backend สร้างไฟล์ตอนดาวน์โหลด ไม่มีขั้นสร้างไฟล์แยก)
- **ตรวจยอดเงินกู้กับหนี้เดือน** (ACCOUNT — เมนู "ปรับปรุงหนี้ธนาคาร ดาวน์โหลดหนี้ที่ต้องแก้ไข" และ "รายชื่อบุคคลที่ไม่มีเลขบัญชีธนาคาร"
  เปิดหน้าเดียวกัน): ผลต่อธนาคาร + รายคนที่ไม่ตรง ปุ่ม "ปรับปรุงหนี้ธนาคาร" (ยืนยันก่อน งวดปัจจุบันเท่านั้น) ไฟล์หนี้ที่ต้องแก้ไข
  และรายชื่อคนที่ไม่มีเลขบัญชี (บนจอ + ไฟล์)
- **รายงานส่งธนาคาร** (ACCOUNT): xlsx 4 แบบ ธอส./ออมสิน/กรุงไทย ถ้ายอดยังไม่ตรง (409 `LOAN_AMOUNT_MISMATCH`) แสดงจำนวนจาก `details`
  พร้อมปุ่มไปหน้าตรวจยอดเงินกู้
- **รายงาน** (ทุกบทบาท ตามขอบเขตหน่วยงาน): เลือกงวด (ย้อนหลังได้) ประเภท หน่วยงาน แล้วออก PDF — รายละเอียดการหักเงิน สรุปจำนวนเงินหัก
  ข้อมูลธนาคาร กบข/กสจ ฌาปนกิจ สหกรณ์ รายชื่อบุคคลเพิ่มลด เงินหนี้เปลี่ยน ธอส./ออมสิน/กรุงไทย ("ทุกหน่วยงาน" เฉพาะขอบเขต ALL)
  ฝ่ายบัญชีมีเพิ่ม: สรุปหน่วยงานประจำเดือน และผู้เกษียณในรายการฌาปนกิจ — ดาวน์โหลดแล้วมีปุ่ม "เปิดดู" ไม่มีข้อมูล (404) บอกใต้รายงานนั้น
  ระหว่างสร้างไฟล์ปุ่มกดซ้ำไม่ได้
- **หน้าบันทึกข้อมูล**: หัวตารางตรึงอยู่บนสุดตอนเลื่อน (เลื่อนแนวนอนตามตารางบนจอแคบ) และยอดรวมต่อรหัสย้ายไปอยู่แถบล่างที่ไม่เลื่อน
- **ของเดิมที่เปลี่ยนไปใช้เส้นใหม่**: เลขที่บัญชีเงินกู้บันทึกทั้งชุดในคำขอเดียว (`PUT /api/loans/set` ผิดรายการเดียว = ไม่บันทึกอะไรเลย)
  ข้อมูลหลักลบที่เลือกในคำขอเดียว (`POST /api/master/{resource}/delete` ผลรายรายการใต้แถว) ค้นบุคคลด้วย `POST /api/persons/search`
  ประวัติการแก้ไขแสดงเฉพาะ "แก้ยอด" รายการเก่าชนิดอื่นแสดงเป็น "รายการเดิมของระบบ"
- **ไฟล์ที่ดาวน์โหลดมีข้อมูลบุคคล**: รับเป็นไบต์ ส่งให้เบราว์เซอร์ผ่าน Blob (`lib/utils/file_download.dart`) อยู่ในหน่วยความจำของแท็บจนปิดหน้าจอ
  ไม่เก็บลง localStorage / IndexedDB และไม่ลง log
- **รายงานฌาปนกิจ-สลิป** (ACCOUNT): เทียบเงินฌาปนกิจที่**ต้องการหัก** (รายการของงวด) กับเงินที่**หักได้จริง**ในสลิป (จากระบบสลิปภาษี)
  เลือกงวด (ย้อนหลังได้) + ประเภท แล้วกด "ตรวจสอบ" (ไม่เรียกอัตโนมัติเพราะเรียกข้ามระบบ) → การ์ดสรุป (ทั้งหมด / หักได้ตรงยอด / ยอดไม่ตรง / ไม่มีในสลิป / รวมที่หักไม่ได้)
  + ตารางผู้ที่หักไม่ได้ (เลขสมาชิก ชื่อ สังกัด สถานะบุคคล ยอดที่ต้องการหัก ยอดในสลิป สาเหตุ จ่ายให้กับ) แบ่งหน้า เลขบัตรปิดบางส่วน + รายงาน PDF
  ทุกคนหักได้ครบ = สถานะสำเร็จ; ยังไม่ได้นำเข้าฌาปนกิจของงวด = แจ้งพร้อมลิงก์ไปหน้านำเข้า; ข้อความเฉพาะของ `SLIP_API_NOT_CONFIGURED` (503), `SLIP_API_ERROR`, `DPIS_ERROR` (502)

## เมนูและบทบาท

บทบาทใน API เป็นชื่อสั้น ตารางบทบาทต่อหน้าจออยู่ที่ `Perm` (`lib/utils/permission.dart`) — หน้าเว็บแค่ซ่อนเมนู การกันจริงอยู่ที่ backend

| เมนู | USER | ACCOUNT | RESETPWD | CENTER_DEPT | ALL_DEPT | ADMIN |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| หน้าแรก | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| เตรียมข้อมูล › ข้อมูลงวด › กำหนดเดือนปี | | ✓ | | | | |
| เตรียมข้อมูล › ข้อมูลงวด › ข้อความแจ้งผู้ใช้งาน | | ✓ | | | | |
| เตรียมข้อมูล › ข้อมูลงวด › ระยะเวลาแก้ไขข้อมูล | | ✓ | | | | |
| ผู้ใช้งาน › เปลี่ยนรหัสผ่าน | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| ผู้ใช้งาน › กำหนดรหัสผ่านใหม่ให้หน่วยงาน | | | ✓ | | | ✓ |
| ผู้ใช้งาน › จัดการผู้ใช้ | | | | | | ✓ |
| งานหักหนี้ › บันทึกข้อมูล | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| งานหักหนี้ › รายงาน | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| เตรียมข้อมูล › ข้อมูลงวด › นำเข้าข้อมูลบุคลากร, เตรียมข้อมูลเดือนที่ผ่านมาเป็นงวดปัจจุบัน, สถานะการบันทึกของหน่วยงาน | | ✓ | | | | |
| เตรียมข้อมูล › บันทึกรายการหลัก › รายชื่อธนาคาร, รายชื่อสาขาธนาคาร, รหัสหนี้, รายชื่อหน่วยงาน | | ✓ | | | | |
| เตรียมข้อมูล › ฌาปนกิจและสหกรณ์ › นำเข้าข้อมูลฌาปนกิจ, นำเข้าข้อมูลสหกรณ์, รายงานฌาปนกิจ-สลิป | | ✓ | | | | |
| เตรียมข้อมูล › ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร › ปรับปรุงหนี้ธนาคาร ดาวน์โหลดหนี้ที่ต้องแก้ไข, รายชื่อบุคคลที่ไม่มีเลขบัญชีธนาคาร, ดาวน์โหลดไฟล์ข้อความส่งกรมบัญชีกลาง, รายงานส่งธนาคาร | | ✓ | | | | |
| เตรียมข้อมูล › บันทึกข้อมูลธนาคาร › กบข/กสจ. สหกรณ์และภาษี, เลขที่บัญชีเงินกู้ | | ✓ | | | | |

- `CENTER_DEPT` / `ALL_DEPT` ไม่เพิ่มเมนู แต่กำหนดขอบเขตหน่วยงานที่เลือกได้ (`div_scope` = `OWN` / `CENTER` / `ALL`)
- บัญชีที่ยังต้องเปลี่ยนรหัสผ่านเห็นแค่ หน้าแรก กับ เปลี่ยนรหัสผ่าน
- เมนูของฝ่ายบัญชีเรียงตามลำดับงานประจำงวด (ข้อมูลงวด → ฌาปนกิจและสหกรณ์ → บันทึกข้อมูลธนาคาร → ไฟล์ส่งกรมบัญชีกลางและรายงานธนาคาร → บันทึกรายการหลัก)
  ทุกเมนูเปิดหน้าจอจริงแล้ว ไม่มีหน้า "กำลังพัฒนา" เหลือ (`ComingSoonScreen` ลบออกแล้ว)
- เมนู "สร้างไฟล์ข้อความทั้งหมดส่งธนาคาร" และ "ดาวน์โหลดไฟล์ข้อความส่งธนาคาร" ของระบบเดิม **ยกเลิกแล้ว** (ผู้ใช้สั่ง 13 ต.ค. 2569) ไม่มีในเมนู

## เริ่มใช้งาน

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE=https://suchat-dev.doh.go.th/dpayapi   # dev ชี้ nginx บน WSL
```

ใน VS Code ใช้ Run and Debug > `dpay dev (WSL API)` (พอร์ตหน้าเว็บ 5585) หรือ `dpay dev (API localhost:9005)` (พอร์ต 5586)

- `API_BASE` คือ URL ของ backend (ไม่มี `/` ปิดท้าย) **ไม่ส่งมา = `https://backupdoh.doh.go.th/dpayapi`** (เครื่องจริง แบบเดียวกับ HTC และสลิปภาษี — ผู้ใช้กำหนด 13 ต.ค. 2569) ตอนพัฒนาต้องส่งค่านี้เองทุกครั้ง ไม่งั้นจะชี้ข้อมูลจริง
  build ขึ้นเครื่องจริง: `flutter build web --no-wasm-dry-run` ไม่ต้องใส่ `API_BASE`
- backend ฟัง **HTTPS** พอร์ต 9005 เป็นค่าเริ่มต้น (`DPAY_SSL_ENABLED=true`) จะใช้ `http://localhost:9005` ได้ต้องรัน backend แบบปิด SSL
  ปกติตอนพัฒนาให้เรียกผ่าน nginx (`https://suchat-dev.doh.go.th/dpayapi` ต้องมี `127.0.0.1 suchat-dev.doh.go.th` ใน hosts ของ Windows)
- backend ต้องอนุญาต origin ของหน้าเว็บ (CORS — `CORS_EXTRA_ORIGINS` ใน env.conf) เช่น `http://localhost:5585`

## คำสั่งที่ใช้ประจำ

```bash
flutter analyze                 # ต้องไม่มีปัญหา
flutter test                    # เทสต์ทั้งหมด ใช้ backend จำลอง ไม่ต้องมี backend จริง (ห้ามใส่ --platform chrome)
bash tool/check_logging.sh      # ไม่มี print/debugPrint, AppLogger ถูกครอบด้วย if (AppLogger.on), ไม่มี showDatePicker
flutter build web --no-wasm-dry-run --dart-define=API_BASE=<URL ของ API>     # ได้ build/web
```

- **ห้าม** build ขึ้นเครื่องจริงด้วย `--debug` หรือ `--profile` ต้องเป็น release เท่านั้น ไม่งั้น log ไม่ถูกตัดออกจากไฟล์ที่ส่งให้เบราว์เซอร์
- วางหน้าเว็บใต้ path ย่อย (ไม่ใช่ราก) ให้เพิ่ม `--base-href /<path>/` และรันจาก PowerShell
  (Git Bash แปลงค่าที่ขึ้นต้นด้วย `/` เป็น path ของ Windows)
- ติดปัญหา dependency: `flutter clean` แล้ว `flutter pub get`

## จุดที่ต้องตั้ง / ต้องเปลี่ยน

| สิ่งที่ตั้ง | อยู่ที่ไหน |
|---|---|
| ชื่อระบบ "ระบบหักหนี้" ชื่อหน่วยงาน "กรมทางหลวง" คำอธิบาย ไอคอน เลขเวอร์ชัน | `lib/config/app_config.dart` (`AppConfig`) — จุดเดียว ทุกหน้าจออ่านจากที่นี่ |
| คำนำหน้าคีย์ของที่เก็บในเบราว์เซอร์ | `AppConfig.storagePrefix` = `dpay_` (`dpay_theme`, `dpay_menu_pinned`, คลัง token `dpay_secure_storage`) |
| URL ของ API | `--dart-define=API_BASE=...` ตอน run/build และ `.vscode/launch.json` (ค่าตั้งต้นใน `ApiService.baseUrl`) |
| ป้าย "ระบบงานอยู่ในช่วงทดสอบ" | `TestPhaseBanner` ใน `MaterialApp.builder` ของ `lib/main.dart` — **เปิดใช้จริงแล้วเอาออก** |
| ชื่อบนแท็บเบราว์เซอร์ | `web/index.html` และ `web/manifest.json` |
| ไอคอนเว็บ | `web/favicon.png`, `web/icons/*.png` — ตอนนี้เป็นไอคอนกลาง ๆ จากต้นแบบ ยังไม่ใช่ตราของระบบ |
| บทบาทต่อเมนู | `Perm` และ `Roles` ใน `lib/utils/permission.dart` |

## สัญญา API ที่หน้าเว็บใช้

ยึดตามโค้ดจริงของ backend (`controller/*`, `dto/*`, `exception/ErrorCodes.java`) ทุกเส้นยกเว้นที่ระบุว่า "สาธารณะ"
แนบ `Authorization: Bearer <access_token>` access token ต้องเป็น JWT ที่มี `exp` (หน้าเว็บอ่านเพื่อต่ออายุล่วงหน้า 60 วินาที)
ช่องที่ไม่อยู่ในตารางหน้าเว็บไม่อ่าน

| เส้น | ใครเรียก | ส่ง | ช่องที่หน้าเว็บอ่าน |
|---|---|---|---|
| `POST /api/auth/login` (สาธารณะ) | หน้าต่างเข้าสู่ระบบ | `{username, password}` | `access_token` (ต้องมี), `refresh_token`, `username`, `full_name`, `div`, `div_name`, `roles[]`, `div_scope`, `must_change_password` |
| `POST /api/auth/refresh-token` (สาธารณะ) | อัตโนมัติ | `{refresh_token}` | `access_token` (ต้องมี), `refresh_token` (ใช้ได้ครั้งเดียว เก็บตัวใหม่ทันที) |
| `POST /api/auth/logout` | ออกจากระบบ | `{refresh_token}` + header | ไม่อ่าน (ไม่สำเร็จก็ออกจากระบบฝั่งหน้าเว็บต่อ) |
| `GET /api/auth/me` | ตอนกู้ session หลังโหลดหน้าใหม่ | – | ช่องเดียวกับ login + `can_edit_now` |
| `POST /api/auth/changepassword` | เปลี่ยนรหัสผ่าน | `{oldPassword, newPassword}` | `success`, `message` |
| `GET /api/alert-message` (สาธารณะ) | หน้าแรก หน้าแก้ข้อความ | – | `msg` (ข้อความล้วน แสดงแบบไม่ตีความ HTML) |
| `PUT /api/alert-message` | ACCOUNT | `{msg}` (≤ 5,000 ตัว) | `msg` |
| `GET /api/period` | หลังเข้าสู่ระบบ | – | `month` ("07"), `year` ("2568") |
| `PUT /api/period` | ACCOUNT | `{month, year}` | `month`, `year` |
| `GET /api/edit-window` | หลังเข้าสู่ระบบ | – | `beginDate`, `endDate` (ค.ศ. yyyy-MM-dd), `beginTime`, `endTime` (HH:mm), `open`, `can_edit_now`, `server_time` |
| `PUT /api/edit-window` | ACCOUNT | `{beginDate, endDate, beginTime, endTime}` | เหมือน GET |
| `GET /api/divs` | `DivSelector` | – | `scope`, `own_div`, `divs[]: {div, divname, center}` |
| `GET /api/divs/{div}/success-dept` | (ระยะถัดไป มีเมธอดแล้ว) | – | `div`, `g`, `e`, `success_depts[]` |
| `GET /api/admin/users` | ADMIN, RESETPWD | query `keyword?`, `page`, `size` | `users[]`, `totalPages`, `totalItems` |
| `GET /api/admin/users/{id}` | ADMIN (ก่อนเปิดแก้ไข) | – | `id, username, fullName, email, div, divName, roles[], active, locked, mustChangePassword, lastLogin` |
| `POST /api/admin/users` | ADMIN | `{username, password, fullName, email, div, roles[]}` | ผู้ใช้ (รูปเดียวกับ GET) |
| `PUT /api/admin/users/{id}` | ADMIN | `{fullName, email, div, roles[], active, locked}` | ผู้ใช้ |
| `POST /api/admin/users/{id}/reset-password` | ADMIN, RESETPWD | `{newPassword}` | `message` |
| `GET /api/admin/roles` | ADMIN | – | `[{name, description}]` |
| `GET /api/admin/divs` | ADMIN | – | `[{div, divname, center}]` |

**ข้อผิดพลาด** ทุกกรณีเป็น `{code, message, success:false}` หน้าเว็บแสดง `message` และเก็บ `code` ไว้ที่ `ApiException.code`
(ค่าคงที่ใน `ErrorCodes`) แยกกรณีด้วย code เท่านั้น ห้ามจับคำในข้อความ

- **401** จากเส้นที่ต้องเข้าสู่ระบบ = ต่ออายุ token แล้วยิงซ้ำหนึ่งครั้ง ต่ออายุไม่ได้ = ออกจากระบบและกลับหน้าแรก
- **403** ไม่ต่ออายุ token (backend บอกเหตุด้วย code: `FORBIDDEN`, `DIV_FORBIDDEN`, `EDIT_WINDOW_CLOSED`, `PASSWORD_CHANGE_REQUIRED`)
- `PASSWORD_CHANGE_REQUIRED` = ตั้งสถานะบังคับเปลี่ยนรหัสผ่าน แล้วเปิดหน้าต่างที่ปิดไม่ได้
- กติการหัสผ่าน (ตรงกับ `PasswordPolicy.java`): 8–72 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก ตัวเลข และอักขระพิเศษ (ตัวใดก็ได้ที่ไม่ใช่ A-Z a-z 0-9)
  อยู่ที่ `PasswordRules` ใน `lib/widgets/account_form.dart` จุดเดียว

**ระยะเวลาแก้ไขข้อมูล** เป็นช่วงต่อเนื่องช่วงเดียวจาก วันเริ่ม+เวลาเริ่ม ถึง วันสิ้นสุด+เวลาสิ้นสุด (ไม่ใช่ช่วงเวลาซ้ำทุกวัน)
หน้าเว็บไม่คำนวณเองว่าเปิดอยู่ไหม ใช้ `open` / `can_edit_now` ของ backend เท่านั้น

### เส้นของระยะที่ 2 (ก้อน ก–ค)

| เส้น | ใครเรียก | ช่องที่หน้าเว็บใช้ |
|---|---|---|
| `GET /api/master/{banks\|branches\|debt-codes\|divs\|provinces}` | ACCOUNT | query `keyword, page, size, sort, dir, bank_code` → `items[], totalPages, totalItems` (ตัวเลือกใช้ `size=2000`) |
| `POST/PUT /api/master/{resource}[/{id}]` | ACCOUNT | ส่งช่องของตาราง (แก้ไขส่งเฉพาะช่องที่เปลี่ยน) — ลบใช้เส้นลบหลายรายการ (ดูระยะที่ 3) |
| `GET/POST /api/period/dpis-import` | ACCOUNT | `g, e, total, last_import_at, last_import_by` / `total, previous_total, skipped_invalid_idcard, skipped_duplicate_idcard, message` |
| `GET/POST /api/period/prepare` | ACCOUNT | สรุป: `month, year, from_month, from_year, current_dpis, existing_rows, rows_with_debt, edits_since_prepare, previous_rows, previous_rows_with_debt, confirm_required, ready, last_status, last_run_at, last_run_by` / ส่ง `{confirm_replace}` ผล: `rows, g, e, carried_over, without_div, cleared_rows, message` / 409 `details: rows_to_clear, rows_with_debt, edits_since_prepare` |
| `GET /api/debts`, `POST /api/debts/search` | ทุกบทบาท | `type, div, page, size` (+ `month, year` เมื่อดูงวดย้อนหลัง, `name, surname` ทาง POST) → `items[], totalPages, totalItems, is_current_period, period_ready, editable` รายการ: `id, type, div, divname, idcard, title, name, surname, pos_name, c40302…c41100, in_roster?` |
| `GET /api/debts/summary` | ทุกบทบาท | `type, div` (+ `month, year` เมื่อดูงวดย้อนหลัง) → `items[]: field, name, count, amount` |
| `PUT /api/debts` | ทุกบทบาท (ช่วงแก้ไข) | ส่ง `{items:[{id, <รหัสที่แก้>}]}` อ่าน `updated, message` |
| `GET /api/debts/{id}/audit` | ทุกบทบาท | `items[]: action, by, at, note, changes{field:{from,to}}` |
| `POST /api/persons/lookup` | ACCOUNT | `{idcard}` → `found, type, in_current_period, div, title, name, surname, full_name, birth_date, start_date` |
| `POST /api/deducts/find`, `POST /api/deducts`, `PUT/DELETE /api/deducts/{id}` | ACCOUNT | `{idcard}` → `found, item, duplicates` ช่องของทะเบียนตาม api.md |
| `POST /api/loans/find` | ACCOUNT | `{idcard}` → `items[]`: `id, ghb_acc, flg, emp_type, year, seq, subseq, amt` — บันทึกใช้ `PUT /api/loans/set` (ดูระยะที่ 3) |

code เพิ่ม: `DUPLICATE`, `IN_USE`, `CONFIRM_REQUIRED` (มี `details`), `JOB_RUNNING`, `PERIOD_NOT_READY`, `NOT_CURRENT_PERIOD`,
`PERSON_NOT_FOUND`, `DPIS_ERROR` (502 — หน้าเว็บรับข้อความของ backend มาแสดง) วันเวลาจาก backend (`last_import_at`, `at` ฯลฯ)
อ่านได้ทั้งข้อความ ISO และเลขมิลลิวินาที แสดงเป็นเวลาไทย

### เส้นของระยะที่ 3 (ก้อน ง–ฉ และเส้นใหม่ของ ก/ค)

ทุกเส้นรับ `month`/`year` (ไม่ส่ง = งวดปัจจุบัน) ไฟล์รับเป็นไบต์ ชื่อไฟล์จาก `Content-Disposition`

| เส้น | สิทธิ์ | ช่องที่หน้าเว็บส่ง / อ่าน |
|---|---|---|
| `GET /api/debts/div-status` | ACCOUNT | → `is_current_period, period_ready, prepared_at, audit_available, summary{divs, edited, not_edited, rows, rows_with_debt}, items[]: div, divname, div_order, center, g, e, rows, rows_with_debt, edited, edits, last_edit_at, last_edit_by` |
| `GET /api/chapana/slip-check`, `GET /api/reports/chapana-not-pay` | ACCOUNT | `type` (+ `month, year`) → `summary{chapana_rows, matched, mismatch, not_in_slip, not_paid, chapana_amount, not_paid_amount}, slip{count, not_in_chapana}, items[]: idcard, name, member_no, dept_name, org_code, per_status, retired, amount, slip_amount, status, pay_for` / PDF (404 = ไม่มีผู้ไม่ถูกหัก) |
| `POST /api/master/{resource}/delete` | ACCOUNT | `{ids[]}` → `results[]: id, deleted, code, message` |
| `POST /api/persons/search` | ACCOUNT | `{name, surname}` → `items[]: idcard, type, title, name, surname, div, divname, pos_name`, `truncated` |
| `PUT /api/loans/set` | ACCOUNT | `{id_card, items[]: ghb_acc, flg, emp_type, year, seq, subseq, amt}` |
| `POST /api/saha/import` (multipart) | ACCOUNT | `file, type, dry_run, confirm_replace` → `rows, total_amount, existing_rows, replaced_rows, matched_by_mapping, matched_by_name, new_mappings, problem_count, problem_counts, problems[], problems_truncated` / 400 `details: bad_line_count, bad_lines, expected_length` / 409 `details: rows_to_clear` |
| `GET /api/saha/summary`, `GET /api/saha/unresolved` | ACCOUNT | `items[]: type, rows, total_amount, fake_idcard_rows` / แบ่งหน้า `saha_id, name, type, idcard, total_amount` |
| `PUT /api/saha/mapping` | ACCOUNT | `{saha_id, idcard, type}` |
| `POST /api/chapana/import`, `GET /api/chapana/summary`, `GET /api/chapana/retired` | ACCOUNT | `{confirm_replace}` → `from_dpis, rows, g, e, retired, retired_with_detail, skipped_invalid, replaced_rows` / `items[]: type, count, amount`, `retired` / รายชื่อผู้เกษียณ |
| `GET /api/cgd-files`, `/api/cgd-files/{type}/{code}`, `/api/cgd-files/zip?type=` | ACCOUNT | `items[]: name, type, code, count, amount, size, unmappable_chars` / ไฟล์ |
| `GET /api/loans/check`, `POST /api/loans/sync-amounts` | ACCOUNT | `ok, mismatch_count, missing_account, banks[]: bank, checked, mismatch_count, missing_account, mismatches[]` / `updated, banks[]: manual_count` |
| `GET /api/loans/mismatch-file`, `/missing-accounts`, `/missing-accounts-file` | ACCOUNT | ไฟล์ / `items[]: div, type, idcard, title, name, surname, c40302, c40303, c40315, missing_banks[]` |
| `GET /api/reports/{rep1\|rep2\|rep3\|rep4\|debt-change}` | ทุกบทบาท (ตามหน่วยงาน) | `type` (rep1/3/4), `div` (`*` เฉพาะ debt-change ของขอบเขต ALL), `bank` (debt-change) → PDF / 404 ไม่มีข้อมูล |
| `GET /api/reports/{rep2-all-dept\|rep10}`, `GET /api/reports/bank/{AIA\|GHB\|GSB\|KTB}` | ACCOUNT | PDF / xlsx — 409 `LOAN_AMOUNT_MISMATCH` `details: mismatch_count, banks[]` |

## เลือกวันที่ (ปี พ.ศ.)

ห้ามเรียก `showDatePicker` / `showDateRangePicker` ของ Flutter ตรง ๆ (แสดงปีเป็น ค.ศ.) และ**ห้ามเพิ่ม syncfusion**
ใช้ตัวเลือกของโปรเจกต์สองตัวนี้ ทั้งคู่คืนวันที่ ค.ศ. ไม่มีเวลา แสดงผลด้วย `Util.formatThaiDate` ส่ง backend ด้วย `Util.formatChristianDate`

```dart
// วันเดียว — lib/widgets/thai_date_picker.dart
final day = await showThaiDatePicker(context, _date, firstDate: ..., lastDate: ...);   // DateTime? (null = ยกเลิก)

// ช่วงวันที่ — lib/widgets/thai_date_range_picker.dart
final range = await showThaiDateRangePicker(
  context,
  initialStart: _begin,              // ไม่ส่ง = ยังไม่เลือก เปิดที่เดือนของวันนี้
  initialEnd: _end,
  firstDate: DateTime(2020, 1, 1),   // ไม่ส่ง = พ.ศ. 2560
  lastDate: DateTime(2030, 12, 31),  // ไม่ส่ง = พ.ศ. 2580
  helpText: 'ช่วงวันที่เปิดให้แก้ไขข้อมูล',
);
if (range == null) return;           // ยกเลิก / Esc / แตะนอกหน้าต่าง
setState(() { _begin = range.start; _end = range.end; });   // DateTimeRange (วันเดียว: start == end)
```

พฤติกรรมของตัวเลือกช่วงวันที่

- จอกว้างตั้งแต่ 760 จุดแสดงสองเดือนเคียงกัน จอแคบกว่านั้นแสดงเดือนเดียว (เลื่อนเดือนด้วยลูกศร) ไม่ล้นที่จอ 320 จุด
- หัวเดือนเป็น "กันยายน 2569" ชื่อวันไทย สัปดาห์เริ่มวันอาทิตย์ แถบหัวแสดงช่วงที่เลือกเป็นวันที่ไทย
- เลือกได้สองวิธี: แตะวันเริ่มแล้วแตะวันสิ้นสุด หรือกดค้างแล้ว**ลาก**จากวันเริ่มไปวันสิ้นสุด (เมาส์และนิ้ว ข้ามเดือนได้ตอนแสดงสองเดือน ลากย้อนก็ได้)
- แตะวันก่อนวันเริ่ม = เริ่มช่วงใหม่ แตะวันเดิมซ้ำ = ช่วงวันเดียว เลือกครบแล้วแตะอีก = เริ่มเลือกใหม่
- ช่วงที่เลือกแรเงา ปลายทั้งสองเป็นวงทึบสีธีม วันนอก `firstDate`–`lastDate` แตะ/ลากไม่ได้
- ปุ่ม "วันนี้" พาไปเดือนปัจจุบัน (ไม่เปลี่ยนช่วงที่เลือก) แตะชื่อเดือนเพื่อเลือกปี พ.ศ. แล้วเลือกเดือน
- ปุ่ม "ตกลง" กดได้เมื่อเลือกครบทั้งวันเริ่มและวันสิ้นสุด เทสต์ส่ง `today:` เพื่อตรึง "วันนี้" ได้

## ตัวช่วยกลางสำหรับระยะถัดไป

```dart
// หน่วยงานตามขอบเขตของผู้ใช้: OWN = แสดงเฉย ๆ, CENTER/ALL = รายการเลือกแบบค้นหาได้
DivSelector(
  apiService: ApiService(),
  onChanged: (div) => setState(() { _div = div.div; _reload(); }),   // เรียกหนึ่งครั้งหลังโหลด และทุกครั้งที่เลือกใหม่
)

// งวดปัจจุบัน ระยะเวลาแก้ไข และสิทธิ์แก้ไขตอนนี้ — ตัวเดียวทั้งแอป
final settings = SettingsProvider();
settings.period;        // Period? (label = "กรกฎาคม 2568")
settings.editWindow;    // EditWindow?
settings.canEditNow;    // ใช้เปิด/ปิดปุ่มบันทึก-ลบ (การบังคับจริงอยู่ที่ backend: 403 EDIT_WINDOW_CLOSED)
ListenableBuilder(listenable: settings, builder: ...)   // วาดใหม่เมื่อค่าเปลี่ยน
```

เมื่อ backend ตอบ `EDIT_WINDOW_CLOSED` (`ApiException.isEditWindowClosed`) ให้แสดงข้อความแล้วเรียก `settings.load()` เพื่อปิดปุ่ม
ได้ `DIV_FORBIDDEN` (`isDivForbidden`) = หน่วยงานที่เลือกไม่อยู่ในสิทธิ์ของบัญชีแล้ว

## เพิ่มหน้าจอใหม่

1. `lib/models/x.dart` — โมเดล `fromJson` ต้องทนต่อช่องที่ขาด วันที่รับ/ส่งเป็น ค.ศ. `yyyy-MM-dd`
2. `lib/screens/x_screen.dart` — ใช้ส่วนประกอบจาก `widgets/screen_parts.dart` และ `AppPagination`
3. `lib/widgets/x_dialog.dart` — หน้าต่างเพิ่ม/แก้ไข ใช้ส่วนประกอบจาก `widgets/account_form.dart`
4. เมธอดใน `ApiService` เรียกผ่าน `_authedRequest` แล้วโยน `_apiError` เมื่อไม่ใช่ 200
5. รหัสหน้าจอ + บทบาทใน `Perm` แล้วเพิ่มรายการในเมนูข้าง (`_SubMenuItemData` ใน `lib/widgets/sidebar_menu.dart`) ตามลำดับงานประจำงวด
6. เส้นใหม่ใน `test/fake_backend.dart` (ตามโค้ด backend จริง) และไฟล์เทสต์ของหน้าจอนั้น

## แผนระยะถัดไป

ก้อน ก–ฉ ทำแล้วทั้งหมด ที่เหลือ:

1. ทุกก้อนของสัญญา backend (ก–ช) มีหน้าจอครบแล้ว
2. ทดสอบทุกหน้าจอกับ backend จริง (รอบนี้ตรวจกับ backend จำลองในเทสต์เท่านั้น) โดยเฉพาะอัปโหลดไฟล์สหกรณ์และการดาวน์โหลดไฟล์บนเบราว์เซอร์จริง
3. ก่อนเปิดใช้จริง: เอา `TestPhaseBanner` ออก เปลี่ยนไอคอนเว็บ

## ข้อจำกัดที่รู้

- ข้อมูลหลักบันทึกทีละแถว (`POST`/`PUT` ต่อแถว — ยังไม่มีเส้นบันทึกทั้งชุด) บันทึกสลับรหัสระหว่างสองแถวในครั้งเดียวจึงชน `DUPLICATE`
  (แก้ทีละแถวได้) ตรวจรหัสซ้ำฝั่งหน้าเว็บได้เฉพาะแถวในหน้าที่เห็น ที่เหลือ backend เป็นผู้ตรวจ
- เส้น `POST /api/debts`, `POST /api/debts/sync-roster`, `PUT /api/debts/{id}/div`, `DELETE /api/debts/{id}` ของ backend หน้าเว็บ**ไม่เรียกแล้ว**
- อัปโหลดไฟล์สหกรณ์ (multipart): ถ้า access token หมดอายุพอดีตอนส่ง การยิงซ้ำอัตโนมัติหลังต่ออายุ token อาจใช้ไม่ได้กับคำขอแบบไฟล์ — กดตรวจ/นำเข้าใหม่อีกครั้ง (ยังไม่ได้ลองกับ backend จริง)
- หน้า "บันทึกข้อมูล": ยอดรวมมาจาก `/summary` คือยอดที่บันทึกแล้ว และตัวเลือกงวดไม่รู้ว่างวดใดมีข้อมูล (เลือกงวดที่ไม่มีข้อมูลได้ จะเห็นตารางว่าง)
  แถบล่างของหน้านี้ (ยอดรวม + บันทึก + ตัวแบ่งหน้า) กินพื้นที่บนจอเตี้ย ตารางจึงเห็นได้น้อยแถวบนโทรศัพท์
- หน้าทะเบียน กบข/กสจ: เมื่อเลือก "ไม่เป็นสมาชิก" (`kbk_flg` 0) ช่องอื่นของกลุ่มถูกปิดฝั่งหน้าเว็บ (ค่าเดิมไม่ถูกล้างและไม่ถูกส่ง) — สัญญา API ไม่ได้กำหนดกติกานี้ backend ไม่ได้บังคับ
- เทสต์อัตโนมัติทั้งหมดใช้ backend จำลอง (`test/fake_backend.dart`) — การทดสอบกับ backend จริงทำด้วยมือบนฐาน dpc
- การลากเลือกช่วงวันที่ทดสอบด้วยตัวชี้จำลอง (นิ้วและเมาส์) ใน `flutter test` ยังไม่ได้ลองบนจอสัมผัสจริง
  บนจอที่เตี้ยจนหน้าต่างปฏิทินต้องเลื่อน การลากแนวตั้งอาจเลื่อนหน้าต่างไปพร้อมกัน (ยังแตะสองครั้งได้ตามปกติ)
- backend ไม่มีเส้นลบผู้ใช้ หน้าจัดการผู้ใช้จึงไม่มีปุ่มลบ (ใช้ระงับการใช้งาน)
- ชื่อผู้ใช้ตอนสร้างบัญชี: เลือกหน่วยงานแล้วเติมด้วยรหัสหน่วยงานให้ (แก้ได้สำหรับบัญชีพิเศษ) รับเฉพาะตัวเลข 3–10 หลัก — backend ต้องปรับกติกาให้ตรงกัน
- รายการผู้ใช้กรองตามสถานะ (ใช้งาน/ระงับ) ไม่ได้ เพราะ `GET /api/admin/users` รับแค่ `keyword`
- รายการที่ต้องประสานฝั่ง backend อยู่ท้ายไฟล์ `CLAUDE.md`

## สัญญาอนุญาตของฟอนต์

ฟอนต์ Sarabun, Noto Sans Thai และ Kanit ใน `assets/fonts/` เผยแพร่ภายใต้ SIL Open Font License
ไฟล์ `assets/fonts/OFL.txt` ที่แนบมาเป็นฉบับของ Noto Sans Thai เท่านั้น ก่อนเผยแพร่ระบบให้แนบไฟล์สัญญาอนุญาตของ Sarabun และ Kanit ด้วย
