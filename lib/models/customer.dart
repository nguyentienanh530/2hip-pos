class Customer {
  final String id;
  String maKhachHang;
  String tenKhachHang;
  String loaiKhach; // 'ca_nhan' | 'cong_ty'
  String dienThoai;
  String email;
  String diaChi;
  String khuVuc;
  String phuongXa;
  String congTy;
  String maSoThue;
  String soCMND;
  String ngaySinh;
  String gioiTinh; // 'Nam' | 'Nữ' | ''
  String facebook;
  String nhomKhachHang;
  String ghiChu;
  String nguoiTao;
  DateTime ngayTao;
  bool isActive;

  Customer({
    required this.id,
    required this.maKhachHang,
    required this.tenKhachHang,
    this.loaiKhach = 'ca_nhan',
    this.dienThoai = '',
    this.email = '',
    this.diaChi = '',
    this.khuVuc = '',
    this.phuongXa = '',
    this.congTy = '',
    this.maSoThue = '',
    this.soCMND = '',
    this.ngaySinh = '',
    this.gioiTinh = '',
    this.facebook = '',
    this.nhomKhachHang = '',
    this.ghiChu = '',
    this.nguoiTao = '',
    required this.ngayTao,
    this.isActive = true,
  });

  String get loaiKhachLabel =>
      loaiKhach == 'cong_ty' ? 'Công ty' : 'Cá nhân';

  Map<String, dynamic> toMap() => {
        'id': id,
        'ma_khach_hang': maKhachHang,
        'ten_khach_hang': tenKhachHang,
        'loai_khach': loaiKhach,
        'dien_thoai': dienThoai,
        'email': email,
        'dia_chi': diaChi,
        'khu_vuc': khuVuc,
        'phuong_xa': phuongXa,
        'cong_ty': congTy,
        'ma_so_thue': maSoThue,
        'so_cmnd': soCMND,
        'ngay_sinh': ngaySinh,
        'gioi_tinh': gioiTinh,
        'facebook': facebook,
        'nhom_khach_hang': nhomKhachHang,
        'ghi_chu': ghiChu,
        'nguoi_tao': nguoiTao,
        'ngay_tao': ngayTao.toIso8601String(),
        'is_active': isActive ? 1 : 0,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] ?? '',
        maKhachHang: m['ma_khach_hang'] ?? '',
        tenKhachHang: m['ten_khach_hang'] ?? '',
        loaiKhach: m['loai_khach'] ?? 'ca_nhan',
        dienThoai: m['dien_thoai'] ?? '',
        email: m['email'] ?? '',
        diaChi: m['dia_chi'] ?? '',
        khuVuc: m['khu_vuc'] ?? '',
        phuongXa: m['phuong_xa'] ?? '',
        congTy: m['cong_ty'] ?? '',
        maSoThue: m['ma_so_thue'] ?? '',
        soCMND: m['so_cmnd'] ?? '',
        ngaySinh: m['ngay_sinh'] ?? '',
        gioiTinh: m['gioi_tinh'] ?? '',
        facebook: m['facebook'] ?? '',
        nhomKhachHang: m['nhom_khach_hang'] ?? '',
        ghiChu: m['ghi_chu'] ?? '',
        nguoiTao: m['nguoi_tao'] ?? '',
        ngayTao: DateTime.tryParse(m['ngay_tao'] ?? '') ?? DateTime.now(),
        isActive: (m['is_active'] ?? 1) == 1,
      );
}
