import 'dart:async';
import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

/// ไฟล์ที่ผู้ใช้เลือกจากเครื่อง
class PickedFile {
  final String name;

  /// เนื้อไฟล์ ว่างได้เมื่อไฟล์ใหญ่เกินที่ผู้เรียกกำหนด (ไม่อ่านเข้าหน่วยความจำ ดู [size])
  final Uint8List bytes;

  /// ขนาดไฟล์จริง (ไบต์)
  final int size;

  PickedFile(this.name, this.bytes, {int? size}) : size = size ?? bytes.length;
}

/// ตัวเลือกไฟล์ของหน้าจอ คืน null เมื่อไม่ได้ไฟล์ (เทสต์ส่งตัวจำลองแทนหน้าต่างของเบราว์เซอร์)
typedef FilePicker = Future<PickedFile?> Function();

/// เปิดหน้าต่างเลือกไฟล์ข้อความของสหกรณ์ (.txt / .dat) ไฟล์ที่ใหญ่เกิน [maxBytes] ไม่ถูกอ่านเข้าหน่วยความจำ
Future<PickedFile?> pickTextFile({int? maxBytes}) =>
    pickFile(accept: '.txt,.dat,text/plain', maxBytes: maxBytes);

/// เปิดหน้าต่างเลือกไฟล์ของเบราว์เซอร์ แล้วอ่านไฟล์เป็นไบต์ (ใช้ input type=file ตรง ๆ ไม่เพิ่มแพ็กเกจ)
///
/// [maxBytes] ไฟล์ที่ใหญ่กว่านี้ไม่อ่านเข้าหน่วยความจำ คืน [PickedFile] ที่ `bytes` ว่างและ `size` เป็นขนาดจริง
/// ผู้ใช้กดยกเลิก เบราว์เซอร์ไม่แจ้งอะไรกลับมา Future จึงค้างอยู่เฉย ๆ หน้าจอจึงไม่ควรขึ้นตัวหมุนรอก่อนได้ไฟล์
Future<PickedFile?> pickFile({required String accept, int? maxBytes}) {
  final completer = Completer<PickedFile?>();
  final input = html.FileUploadInputElement()..accept = accept;

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    if (maxBytes != null && file.size > maxBytes) {
      completer.complete(PickedFile(file.name, Uint8List(0), size: file.size));
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(PickedFile(file.name, result.asUint8List()));
      } else if (result is Uint8List) {
        completer.complete(PickedFile(file.name, result));
      } else {
        completer.completeError(Exception('อ่านไฟล์ที่เลือกไม่สำเร็จ'));
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('อ่านไฟล์ที่เลือกไม่สำเร็จ'));
      }
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
