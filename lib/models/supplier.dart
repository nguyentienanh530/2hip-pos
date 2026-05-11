class Supplier {
  final String id;
  final String tenNCC;
  final String? maNCC;
  final String? diaChi;
  final String? soDienThoai;
  final String? email;
  final String? website;
  final String? ghiChu;
  final bool isActive;
  final DateTime createdAt;

  const Supplier({
    required this.id,
    required this.tenNCC,
    this.maNCC,
    this.diaChi,
    this.soDienThoai,
    this.email,
    this.website,
    this.ghiChu,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ten_ncc': tenNCC,
        'ma_ncc': maNCC,
        'dia_chi': diaChi,
        'so_dien_thoai': soDienThoai,
        'email': email,
        'website': website,
        'ghi_chu': ghiChu,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as String,
        tenNCC: m['ten_ncc'] as String,
        maNCC: m['ma_ncc'] as String?,
        diaChi: m['dia_chi'] as String?,
        soDienThoai: m['so_dien_thoai'] as String?,
        email: m['email'] as String?,
        website: m['website'] as String?,
        ghiChu: m['ghi_chu'] as String?,
        isActive: (m['is_active'] as int?) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
