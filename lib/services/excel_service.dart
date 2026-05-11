import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/supplier.dart';
import '../models/customer.dart';
import 'database_service.dart';

class ExcelService {
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  static const _colId = 0;
  static const _colTime = 1;
  static const _colTotal = 5;
  static const _colPaid = 7;
  static const _colStatus = 8;

  static const _headers = [
    'Mã hóa đơn', 'Thời gian', 'Mã trả hàng', 'Mã KH', 'Khách hàng',
    'Tổng tiền hàng', 'Giảm giá', 'Khách đã trả', 'Trạng thái HĐĐT',
  ];

  // ── Export (dùng excel package — hoạt động tốt) ──────────────────────────

  static Future<String?> exportOrders(List<Order> orders) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel hóa đơn',
      fileName: 'don_hang_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (savePath == null) return null;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Hóa đơn');
    final sheet = excel['Hóa đơn'];

    sheet.appendRow(_headers.map((h) => TextCellValue(h)).toList());

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF1565C0'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    for (var c = 0; c < _headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    for (final order in orders) {
      sheet.appendRow([
        TextCellValue(_displayId(order.id)),
        TextCellValue(_dtFmt.format(order.ngayTao)),
        TextCellValue(''), TextCellValue(''), TextCellValue('Khách lẻ'),
        IntCellValue(order.tongTien),
        const IntCellValue(0),
        IntCellValue(order.khachDua),
        TextCellValue(_statusLabel(order.trangThai)),
      ]);
    }

    const widths = [16.0, 22.0, 14.0, 10.0, 14.0, 18.0, 12.0, 18.0, 20.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;
    final outPath = savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx';
    await File(outPath).writeAsBytes(bytes);
    return outPath;
  }

  // ── Import (custom reader — không dùng excel package để tránh bugs) ───────

  static Future<({int imported, int skipped, String? error})> importOrders() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Chọn file Excel hóa đơn',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return (imported: 0, skipped: 0, error: null);
    }

    final pickedFile = picked.files.first;
    List<int> fileBytes;
    if (pickedFile.bytes != null) {
      fileBytes = pickedFile.bytes!;
    } else if (pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    } else {
      return (imported: 0, skipped: 0, error: 'Không thể đọc file');
    }

    List<List<String?>> rows;
    try {
      rows = _readXlsxRows(fileBytes);
    } catch (e) {
      return (imported: 0, skipped: 0, error: 'Không đọc được file: $e');
    }

    if (rows.length < 2) {
      return (imported: 0, skipped: 0, error: 'File không có dữ liệu');
    }

    final db = DatabaseService();
    int imported = 0, skipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rawId = _str(row, _colId);
      if (rawId.isEmpty) continue;

      if (await db.orderExists(rawId)) { skipped++; continue; }

      final id = rawId.length > 36 ? rawId.substring(0, 36) : rawId;
      final ngayTao = _tryParseDateTime(_str(row, _colTime)) ?? DateTime.now();
      final tongTien = _parseInt(row, _colTotal);
      final khachDua = _parseInt(row, _colPaid, fallback: tongTien);
      final trangThai = _parseStatus(_str(row, _colStatus));

      await db.insertOrder(id, ngayTao, tongTien, khachDua,
          (khachDua - tongTien).clamp(0, 999999999), '', [],
          trangThai: trangThai);
      imported++;
    }

    return (imported: imported, skipped: skipped, error: null);
  }

  // ── Custom minimal xlsx reader ────────────────────────────────────────────

  /// Reads first sheet of an xlsx file and returns rows as List<List<String?>>.
  /// Row 0 = header. Each inner list is a row; index = column index.
  /// Cells not present in the file are null.
  static List<List<String?>> readXlsxRows(List<int> bytes) =>
      _readXlsxRows(bytes);

  static List<List<String?>> _readXlsxRows(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Build shared-strings table
    final shared = <String>[];
    final ssFile = _archiveFile(archive, 'xl/sharedStrings.xml');
    if (ssFile != null) {
      final doc = XmlDocument.parse(utf8.decode(ssFile.content as List<int>));
      for (final si in doc.findAllElements('si')) {
        final text = si.findAllElements('t').map((t) => t.innerText).join();
        shared.add(text);
      }
    }

    // 2. Find first worksheet
    final sheetFile = archive.files.firstWhere(
      (f) => f.isFile &&
          RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name),
      orElse: () => throw Exception('Không tìm thấy sheet trong file'),
    );

    final doc = XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
    final result = <List<String?>>[];

    for (final rowEl in doc.findAllElements('row')) {
      final rowIdx = (int.tryParse(rowEl.getAttribute('r') ?? '') ?? 0) - 1;

      // Fill missing rows with empty lists
      while (result.length <= rowIdx) { result.add([]); }
      final cells = result[rowIdx];

      for (final c in rowEl.findElements('c')) {
        final ref = c.getAttribute('r') ?? '';
        final colIdx = _colLetterToIndex(ref);
        if (colIdx < 0) continue;

        while (cells.length <= colIdx) { cells.add(null); }

        final type = c.getAttribute('t') ?? '';
        final rawV = c.findElements('v').firstOrNull?.innerText ?? '';

        String? val;
        if (type == 's') {
          // Shared string index
          final idx = int.tryParse(rawV);
          val = (idx != null && idx < shared.length) ? shared[idx] : '';
        } else if (type == 'inlineStr') {
          val = c.findElements('is').firstOrNull
              ?.findElements('t').firstOrNull?.innerText;
        } else if (type == 'b') {
          val = rawV == '1' ? 'TRUE' : 'FALSE';
        } else {
          val = rawV.isEmpty ? null : rawV;
        }

        cells[colIdx] = val;
      }
    }

    return result;
  }

  static ArchiveFile? _archiveFile(Archive archive, String name) {
    try {
      return archive.files.firstWhere((f) => f.isFile && f.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Converts column letters like "A", "B", "AA" to 0-based index.
  static int _colLetterToIndex(String cellRef) {
    final letters = cellRef.replaceAll(RegExp(r'[0-9]'), '');
    if (letters.isEmpty) return -1;
    int idx = 0;
    for (final ch in letters.codeUnits) {
      idx = idx * 26 + (ch - 65 + 1); // 'A' = 65
    }
    return idx - 1;
  }

  // ── Vietnamese accent removal ─────────────────────────────────────────────

  static String _removeAccents(String s) {
    const map = {
      'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
      'đ': 'd',
    };
    return s.toLowerCase().split('').map((c) => map[c] ?? c).join();
  }

  // ── Row accessors ─────────────────────────────────────────────────────────

  static String _str(List<String?> row, int col) =>
      (col < row.length ? row[col] : null)?.trim() ?? '';

  static int _parseInt(List<String?> row, int col, {int fallback = 0}) {
    final s = _str(row, col).replaceAll(RegExp(r'[\s₫đ]'), '');
    if (s.isEmpty) return fallback;
    // Vietnamese/common thousand-separator: "42.000", "1.500.000", "42,000"
    if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) {
      return int.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? fallback;
    }
    // Raw numeric string: "42000", "42000.0", "42000.0000", "4.2E+4"
    final d = double.tryParse(s);
    if (d != null) return d.round();
    // Last resort: strip all non-digits
    return int.tryParse(s.replaceAll(RegExp(r'[^\d]'), '')) ?? fallback;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _displayId(String uuid) =>
      'HD${uuid.substring(0, 8).toUpperCase()}';

  static String _statusLabel(String s) => switch (s) {
        'hoan_thanh' => 'Đã thanh toán',
        'huy' => 'Đã hủy',
        _ => s,
      };

  static String _parseStatus(String s) {
    final l = s.toLowerCase();
    if (l.contains('hủy') || l.contains('huy') || l.contains('cancel')) {
      return 'huy';
    }
    return 'hoan_thanh';
  }

  static DateTime? _tryParseDateTime(String s) {
    if (s.isEmpty) return null;
    // Try text formats
    for (final fmt in [
      'dd/MM/yyyy HH:mm:ss', 'dd/MM/yyyy HH:mm', 'dd/MM/yyyy',
      'HH:mm:ss dd/MM/yyyy', 'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd',
    ]) {
      try { return DateFormat(fmt).parse(s); } catch (_) {}
    }
    // Try Excel date serial number (stored as numeric string e.g. "46143.668")
    final serial = double.tryParse(s);
    if (serial != null && serial > 1000 && serial < 150000) {
      final ms = ((serial - 25569.0) * 86400000).round();
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    return null;
  }

  // ── Product Export ────────────────────────────────────────────────────────

  static const _productHeaders = [
    'Mã hàng', 'Mã vạch', 'Tên hàng', 'Thương hiệu',
    'Giá bán', 'Giá vốn', 'Tồn kho',
    'Nhóm hàng(3 Cấp)', 'Loại hàng',
    'Hình ảnh (url1,url2...)', 'Mô tả',
  ];

  static Future<String?> exportProducts(List<dynamic> products) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel sản phẩm',
      fileName:
          'san_pham_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (savePath == null) return null;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Sản phẩm');
    final sheet = excel['Sản phẩm'];

    sheet.appendRow(_productHeaders.map((h) => TextCellValue(h)).toList());

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF1565C0'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    for (var c = 0; c < _productHeaders.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    for (final p in products) {
      sheet.appendRow([
        TextCellValue(p.maHang),
        TextCellValue(p.maVach),
        TextCellValue(p.tenHang),
        TextCellValue(p.thuongHieu),
        IntCellValue(p.giaBan),
        IntCellValue(p.giaVon),
        IntCellValue(p.tonKho),
        TextCellValue(p.nhomHang),
        TextCellValue(p.loaiHang),
        TextCellValue(p.hinhAnh),
        TextCellValue(p.moTa),
      ]);
    }

    const widths = [
      14.0, 16.0, 36.0, 18.0,
      14.0, 14.0, 10.0,
      24.0, 14.0,
      28.0, 30.0,
    ];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;
    final outPath = savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx';
    await File(outPath).writeAsBytes(bytes);
    return outPath;
  }

  // ── Supplier Export ───────────────────────────────────────────────────────

  static const _supplierHeaders = [
    'Mã nhà cung cấp', 'Tên nhà cung cấp', 'Email', 'Điện thoại',
    'Địa chỉ', 'Khu vực', 'Phường', 'Tổng mua', 'Nợ cần thanh toán',
    'Mã số thuế', 'Ghi chú', 'Nhóm nhà cung cấp', 'Trạng thái',
    'Tổng mua (tổng)', 'Công ty', 'Người liên hệ', 'Ngày tạo',
  ];

  static Future<String?> exportSuppliers(List<Supplier> suppliers) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel nhà cung cấp',
      fileName: 'nha_cung_cap_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (savePath == null) return null;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Nhà cung cấp');
    final sheet = excel['Nhà cung cấp'];

    sheet.appendRow(_supplierHeaders.map((h) => TextCellValue(h)).toList());

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF1565C0'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    for (var c = 0; c < _supplierHeaders.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    for (final s in suppliers) {
      sheet.appendRow([
        TextCellValue(s.maNCC ?? ''),
        TextCellValue(s.tenNCC),
        TextCellValue(s.email ?? ''),
        TextCellValue(s.soDienThoai ?? ''),
        TextCellValue(s.diaChi ?? ''),
        TextCellValue(''), TextCellValue(''),         // Khu vực, Phường
        const IntCellValue(0), const IntCellValue(0), // Tổng mua, Nợ
        TextCellValue(''),                             // Mã số thuế
        TextCellValue(s.ghiChu ?? ''),
        TextCellValue(''),                             // Nhóm
        IntCellValue(s.isActive ? 1 : 0),
        const IntCellValue(0), TextCellValue(''), TextCellValue(''),
        TextCellValue(DateFormat('dd/MM/yyyy HH:mm:ss').format(s.createdAt)),
      ]);
    }

    const widths = [
      18.0, 30.0, 25.0, 14.0, 25.0, 12.0, 12.0, 14.0, 18.0,
      14.0, 20.0, 18.0, 12.0, 14.0, 16.0, 16.0, 20.0,
    ];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;
    final outPath = savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx';
    await File(outPath).writeAsBytes(bytes);
    return outPath;
  }

  // ── Supplier Import ───────────────────────────────────────────────────────

  static Future<({int imported, int skipped, String? error})> importSuppliers() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Chọn file Excel nhà cung cấp',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return (imported: 0, skipped: 0, error: null);
    }

    final pickedFile = picked.files.first;
    List<int> fileBytes;
    if (pickedFile.bytes != null) {
      fileBytes = pickedFile.bytes!;
    } else if (pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    } else {
      return (imported: 0, skipped: 0, error: 'Không thể đọc file');
    }

    List<List<String?>> rows;
    try {
      rows = _readXlsxRows(fileBytes);
    } catch (e) {
      return (imported: 0, skipped: 0, error: 'Không đọc được file: $e');
    }

    if (rows.length < 2) {
      return (imported: 0, skipped: 0, error: 'File không có dữ liệu');
    }

    final db = DatabaseService();
    int imported = 0, skipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final tenNCC = _str(row, 1);
      if (tenNCC.isEmpty) continue;

      final maNCC = _str(row, 0).isEmpty ? null : _str(row, 0);

      // Skip if supplier code already exists
      if (maNCC != null && await db.supplierCodeExists(maNCC)) {
        skipped++;
        continue;
      }

      final email     = _str(row, 2).isEmpty ? null : _str(row, 2);
      final phone     = _str(row, 3).isEmpty ? null : _str(row, 3);
      final address   = _str(row, 4).isEmpty ? null : _str(row, 4);
      final ghiChu    = _str(row, 10).isEmpty ? null : _str(row, 10);
      final isActive  = _str(row, 12) != '0';
      final createdAt = _tryParseDateTime(_str(row, 16)) ?? DateTime.now();

      await db.insertSupplier(Supplier(
        id: const Uuid().v4(),
        tenNCC: tenNCC,
        maNCC: maNCC,
        email: email,
        soDienThoai: phone,
        diaChi: address,
        ghiChu: ghiChu,
        isActive: isActive,
        createdAt: createdAt,
      ));
      imported++;
    }

    return (imported: imported, skipped: skipped, error: null);
  }

  // ── Customer Export ───────────────────────────────────────────────────────

  static const _customerHeaders = [
    'Loại khách', 'Chi nhánh tạo', 'Mã khách hàng', 'Tên khách hàng',
    'Điện thoại', 'Địa chỉ', 'Khu vực giao hàng', 'Phường/Xã',
    'Công ty', 'Mã số thuế', 'Số CMND/CCCD', 'Ngày sinh', 'Giới tính',
    'Email', 'Facebook', 'Nhóm khách hàng', 'Ghi chú',
    'Người tạo', 'Ngày tạo', 'Trạng thái',
  ];

  static Future<String?> exportCustomers(List<Customer> customers) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu file Excel khách hàng',
      fileName:
          'khach_hang_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (savePath == null) return null;

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Khách hàng');
    final sheet = excel['Khách hàng'];

    sheet.appendRow(_customerHeaders.map((h) => TextCellValue(h)).toList());

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('FF1565C0'),
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    for (var c = 0; c < _customerHeaders.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    for (final c in customers) {
      sheet.appendRow([
        TextCellValue(c.loaiKhachLabel),
        TextCellValue('Chi nhánh trung tâm'),
        TextCellValue(c.maKhachHang),
        TextCellValue(c.tenKhachHang),
        TextCellValue(c.dienThoai),
        TextCellValue(c.diaChi),
        TextCellValue(c.khuVuc),
        TextCellValue(c.phuongXa),
        TextCellValue(c.congTy),
        TextCellValue(c.maSoThue),
        TextCellValue(c.soCMND),
        TextCellValue(c.ngaySinh),
        TextCellValue(c.gioiTinh),
        TextCellValue(c.email),
        TextCellValue(c.facebook),
        TextCellValue(c.nhomKhachHang),
        TextCellValue(c.ghiChu),
        TextCellValue(c.nguoiTao),
        TextCellValue(
            DateFormat('yyyy-MM-dd HH:mm:ss').format(c.ngayTao)),
        IntCellValue(c.isActive ? 1 : 0),
      ]);
    }

    const widths = [
      12.0, 20.0, 14.0, 28.0,
      14.0, 28.0, 18.0, 16.0,
      24.0, 16.0, 16.0, 14.0, 10.0,
      24.0, 20.0, 18.0, 28.0,
      14.0, 22.0, 10.0,
    ];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;
    final outPath = savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx';
    await File(outPath).writeAsBytes(bytes);
    return outPath;
  }

  // ── Customer Import ───────────────────────────────────────────────────────

  static Future<({List<Customer> customers, int skipped, String? error})>
      importCustomers() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Chọn file Excel khách hàng',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return (customers: <Customer>[], skipped: 0, error: null);
    }

    final pickedFile = picked.files.first;
    List<int> fileBytes;
    if (pickedFile.bytes != null) {
      fileBytes = pickedFile.bytes!;
    } else if (pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    } else {
      return (customers: <Customer>[], skipped: 0, error: 'Không thể đọc file');
    }

    List<List<String?>> rows;
    try {
      rows = _readXlsxRows(fileBytes);
    } catch (e) {
      return (customers: <Customer>[], skipped: 0, error: 'Không đọc được file: $e');
    }

    if (rows.length < 2) {
      return (customers: <Customer>[], skipped: 0, error: 'File không có dữ liệu');
    }

    // Build header → column index map (normalize: lowercase, no spaces)
    final headerRow = rows.first;
    int col(String keyword) {
      for (int i = 0; i < headerRow.length; i++) {
        final h = _removeAccents(headerRow[i] ?? '')
            .replaceAll(RegExp(r'[\s/\-_]+'), '');
        if (h.contains(keyword)) return i;
      }
      return -1;
    }

    final colLoai   = col('loaikhach');
    final colMa     = col('makhachhang');
    final colTen    = col('tenkhachhang');
    final colDt     = col('dienthoai');
    final colDc     = col('diachi');
    final colKhuVuc = col('khuvuc');
    final colPhuong = col('phuong');
    final colCty    = col('congty');
    final colMst    = col('masothue');
    final colCmnd   = col('cmnd');
    final colNs     = col('ngaysinh');
    final colGt     = col('gioitinh');
    final colEmail  = col('email');
    final colFb     = col('facebook');
    final colNhom   = col('nhomkhach');
    final colGc     = col('ghichu');
    final colNt     = col('nguoitao');
    final colDate   = col('ngaytao');
    final colStatus = col('trangthai');

    String s(List<String?> row, int c) =>
        c >= 0 && c < row.length ? (row[c] ?? '').trim() : '';

    final db = DatabaseService();
    final results = <Customer>[];
    int skipped = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final ten = s(row, colTen);
      if (ten.isEmpty) continue;

      String maKH = s(row, colMa);
      if (maKH.isEmpty) {
        maKH = await db.getNextCustomerCode();
      } else if (await db.customerCodeExists(maKH)) {
        skipped++;
        continue;
      }

      final loaiRaw = s(row, colLoai).toLowerCase();
      final loai = loaiRaw.contains('công ty') || loaiRaw.contains('cong ty')
          ? 'cong_ty'
          : 'ca_nhan';

      final ngayTaoStr = s(row, colDate);
      final ngayTao = _tryParseDateTime(ngayTaoStr) ?? DateTime.now();

      final statusRaw = s(row, colStatus);
      final isActive = statusRaw != '0';

      results.add(Customer(
        id: const Uuid().v4(),
        maKhachHang: maKH,
        tenKhachHang: ten,
        loaiKhach: loai,
        dienThoai: s(row, colDt),
        diaChi: s(row, colDc),
        khuVuc: s(row, colKhuVuc),
        phuongXa: s(row, colPhuong),
        congTy: s(row, colCty),
        maSoThue: s(row, colMst),
        soCMND: s(row, colCmnd),
        ngaySinh: s(row, colNs),
        gioiTinh: s(row, colGt),
        email: s(row, colEmail),
        facebook: s(row, colFb),
        nhomKhachHang: s(row, colNhom),
        ghiChu: s(row, colGc),
        nguoiTao: s(row, colNt),
        ngayTao: ngayTao,
        isActive: isActive,
      ));
    }

    return (customers: results, skipped: skipped, error: null);
  }
}
