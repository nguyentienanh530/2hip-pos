class Product {
  final String id;
  String maHang;
  String maVach;
  String tenHang;
  String thuongHieu;
  int giaBan;
  int giaVon;
  int tonKho;
  String nhomHang;
  String loaiHang;
  String hinhAnh;
  String moTa;
  bool dangKinhDoanh;

  Product({
    required this.id,
    required this.maHang,
    this.maVach = '',
    required this.tenHang,
    this.thuongHieu = '',
    required this.giaBan,
    this.giaVon = 0,
    this.tonKho = 0,
    this.nhomHang = '',
    this.loaiHang = 'Hàng hóa',
    this.hinhAnh = '',
    this.moTa = '',
    this.dangKinhDoanh = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? json['ma_hang'] ?? '',
      maHang: json['ma_hang'] ?? '',
      maVach: json['ma_vach']?.toString() ?? '',
      tenHang: json['ten_hang'] ?? '',
      thuongHieu: json['thuong_hieu']?.toString() ?? '',
      giaBan: _parseInt(json['gia_ban']),
      giaVon: _parseInt(json['gia_von']),
      tonKho: _parseInt(json['ton_kho']),
      nhomHang: json['nhom_hang']?.toString() ?? '',
      loaiHang: json['loai_hang']?.toString() ?? 'Hàng hóa',
      hinhAnh: json['hinh_anh']?.toString() ?? '',
      moTa: json['mo_ta']?.toString() ?? '',
      dangKinhDoanh: json['dang_kinh_doanh'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ma_hang': maHang,
      'ma_vach': maVach,
      'ten_hang': tenHang,
      'thuong_hieu': thuongHieu,
      'gia_ban': giaBan,
      'gia_von': giaVon,
      'ton_kho': tonKho,
      'nhom_hang': nhomHang,
      'loai_hang': loaiHang,
      'hinh_anh': hinhAnh,
      'mo_ta': moTa,
      'dang_kinh_doanh': dangKinhDoanh ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      maHang: map['ma_hang'] ?? '',
      maVach: map['ma_vach'] ?? '',
      tenHang: map['ten_hang'] ?? '',
      thuongHieu: map['thuong_hieu'] ?? '',
      giaBan: _parseInt(map['gia_ban']),
      giaVon: _parseInt(map['gia_von']),
      tonKho: _parseInt(map['ton_kho']),
      nhomHang: map['nhom_hang'] ?? '',
      loaiHang: map['loai_hang'] ?? 'Hàng hóa',
      hinhAnh: map['hinh_anh'] ?? '',
      moTa: map['mo_ta'] ?? '',
      dangKinhDoanh: (map['dang_kinh_doanh'] ?? 1) == 1,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Product copyWith({
    String? maHang,
    String? maVach,
    String? tenHang,
    String? thuongHieu,
    int? giaBan,
    int? giaVon,
    int? tonKho,
    String? nhomHang,
    String? loaiHang,
    String? hinhAnh,
    String? moTa,
    bool? dangKinhDoanh,
  }) {
    return Product(
      id: this.id,
      maHang: maHang ?? this.maHang,
      maVach: maVach ?? this.maVach,
      tenHang: tenHang ?? this.tenHang,
      thuongHieu: thuongHieu ?? this.thuongHieu,
      giaBan: giaBan ?? this.giaBan,
      giaVon: giaVon ?? this.giaVon,
      tonKho: tonKho ?? this.tonKho,
      nhomHang: nhomHang ?? this.nhomHang,
      loaiHang: loaiHang ?? this.loaiHang,
      hinhAnh: hinhAnh ?? this.hinhAnh,
      moTa: moTa ?? this.moTa,
      dangKinhDoanh: dangKinhDoanh ?? this.dangKinhDoanh,
    );
  }

  double get loiNhuan => giaBan - giaVon.toDouble();
  double get tyLeLoiNhuan => giaVon > 0 ? (loiNhuan / giaVon) * 100 : 0;
}
