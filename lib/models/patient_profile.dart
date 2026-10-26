import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class PatientProfile {
  static String nama = '';
  static String usia = '';
  static String jk = 'Laki-laki';
  static String tinggi = '';
  static String berat = '';
  static String lokasi = '';
  static String catatan = '';
  static Uint8List? fotoBytes;

  // Memuat data dari memori HP
  static Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    nama = prefs.getString('profile_nama') ?? '';
    usia = prefs.getString('profile_usia') ?? '';
    jk = prefs.getString('profile_jk') ?? 'Laki-laki';
    tinggi = prefs.getString('profile_tinggi') ?? '';
    berat = prefs.getString('profile_berat') ?? '';
    lokasi = prefs.getString('profile_lokasi') ?? '';
    catatan = prefs.getString('profile_catatan') ?? '';
    
    String? fotoBase64 = prefs.getString('profile_foto');
    if (fotoBase64 != null && fotoBase64.isNotEmpty) {
      fotoBytes = base64Decode(fotoBase64);
    }
  }

  // Menyimpan data ke memori HP
  static Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('profile_nama', nama);
    await prefs.setString('profile_usia', usia);
    await prefs.setString('profile_jk', jk);
    await prefs.setString('profile_tinggi', tinggi);
    await prefs.setString('profile_berat', berat);
    await prefs.setString('profile_lokasi', lokasi);
    await prefs.setString('profile_catatan', catatan);
    
    if (fotoBytes != null) {
      await prefs.setString('profile_foto', base64Encode(fotoBytes!));
    }
  }
}