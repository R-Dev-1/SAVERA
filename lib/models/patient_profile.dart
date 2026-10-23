import 'dart:typed_data';

/// Model data pasien SAVERA
class PatientProfile {
  static String nama = 'Pak Budi';
  static String usia = '72';
  static String jk = 'Laki-laki';
  static String tinggi = '165';
  static String berat = '62';
  static String lokasi = 'Rumah - Jl. Merdeka No. 12, Bandung';
  static String catatan = '';
  static Uint8List? fotoBytes; // Byte data foto yang kompatibel 100% di Web, Mobile, dan Desktop

  static String get initials {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'P';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
