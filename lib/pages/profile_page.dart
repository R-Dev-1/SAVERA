import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/patient_profile.dart';
import 'monitoring_loading_page.dart';

/// Halaman Profil Pasien (Mendukung mode Setup dan mode Edit)
/// Sesuai spesifikasi 100% dari SAVERA_Semua_Halaman.html (Halaman 2 & 6)
class ProfilePage extends StatefulWidget {
  final bool isSetup; // true: Isi Profil Pasien (Halaman 2), false: Edit Profil Pasien (Halaman 6)

  const ProfilePage({super.key, this.isSetup = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _namaController;
  late TextEditingController _usiaController;
  late TextEditingController _tinggiController;
  late TextEditingController _beratController;
  late TextEditingController _catatanController;

  late String _selectedJk;
  String? _errorMessage;
  bool _savedSuccess = false;
  File? _pickedPhoto;

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3580),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x55FFFFFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Foto Profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0x33FFFFFF)),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1E5FCC),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Kamera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1E5FCC),
                  child: Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Galeri Foto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (source == null) return;
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file != null && mounted) {
        setState(() {
          _pickedPhoto = File(file.path);
          PatientProfile.fotoFile = _pickedPhoto;
        });
      }
    } catch (e) {
      // ignore: user mungkin tolak permission
    }
  }

  // Warna sesuai UI Guidelines SAVERA
  static const Color kNavy = Color(0xFF0B2A6E);
  static const Color kInk = Color(0xFF0F1E3D);
  static const Color kBlue = Color(0xFF1E6FEB);
  static const Color kSky = Color(0xFF0EA5E9);
  static const Color kL2 = Color(0xFFE0F0FE);
  static const Color kLine = Color(0xFFD6E6FB);
  static const Color kInputLine = Color(0xFFBFD8F7);
  static const Color kMuted = Color(0xFF64748B);
  static const Color kBody = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.isSetup ? '' : PatientProfile.nama);
    _usiaController = TextEditingController(text: widget.isSetup ? '' : PatientProfile.usia);
    _tinggiController = TextEditingController(text: widget.isSetup ? '' : PatientProfile.tinggi);
    _beratController = TextEditingController(text: widget.isSetup ? '' : PatientProfile.berat);
    _catatanController = TextEditingController(text: widget.isSetup ? '' : PatientProfile.catatan);
    _selectedJk = widget.isSetup ? 'Laki-laki' : PatientProfile.jk;
    _pickedPhoto = PatientProfile.fotoFile; // load existing photo if any
  }

  @override
  void dispose() {
    _namaController.dispose();
    _usiaController.dispose();
    _tinggiController.dispose();
    _beratController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _save() {
    final nama = _namaController.text.trim();
    final usia = _usiaController.text.trim();

    if (widget.isSetup && (nama.isEmpty || usia.isEmpty)) {
      setState(() {
        _errorMessage = 'Nama dan usia wajib diisi';
        _savedSuccess = false;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _savedSuccess = true;
      PatientProfile.nama = nama.isEmpty ? 'Pak Budi' : nama;
      PatientProfile.usia = usia.isEmpty ? '72' : usia;
      PatientProfile.jk = _selectedJk;
      PatientProfile.tinggi = _tinggiController.text.trim().isEmpty ? '165' : _tinggiController.text.trim();
      PatientProfile.berat = _beratController.text.trim().isEmpty ? '62' : _beratController.text.trim();
      PatientProfile.catatan = _catatanController.text.trim();
    });

    if (widget.isSetup) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MonitoringLoadingPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      });
    } else {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        Navigator.pop(context, true);
      });
    }
  }

  String get _currentInitials {
    final text = _namaController.text.trim();
    if (text.isEmpty) return '';
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2559),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18.0, 14.0, 18.0, 22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                    // --- Card Header Halaman (mode Setup: navy premium, mode Edit: biasa) ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: widget.isSetup
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1E5FCC), // biru premium
                                  Color(0xFF0B2A6E), // navy tua
                                ],
                              )
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE2F0FD),
                                  Color(0xFFEFF7FF),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: widget.isSetup
                              ? const Color(0xFF2D6FDB)
                              : const Color(0xFFC0DCF9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isSetup
                                ? const Color(0x551E6FEB)
                                : const Color(0x0C1E6FEB),
                            blurRadius: widget.isSetup ? 20 : 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isSetup) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF7EB8FF), // biru terang di atas navy
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'PENGATURAN AWAL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: Color(0xFF7EB8FF),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0x33FFFFFF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0x55FFFFFF)),
                                ),
                                child: const Text(
                                  'Langkah 1/1',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xCCFFFFFF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Isi Profil Pasien',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Isi data lansia yang akan dipantau. Data ini bisa diubah nanti lewat tombol profil di Beranda.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.52,
                              fontWeight: FontWeight.w400,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xCCFFFFFF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFC0DCF9)),
                                ),
                                child: const Icon(Icons.person_outline_rounded, size: 18, color: kBlue),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Profil Pasien',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: kNavy,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Perbarui informasi data lansia',
                                    style: TextStyle(fontSize: 12, color: kMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    ),

                    const SizedBox(height: 14),

                  // --- Avatar Besar dengan Badge Kamera (tap untuk upload) ---
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Lingkaran avatar
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.isSetup
                                      ? const Color(0x66FFFFFF)
                                      : const Color(0xFFBAE0FD),
                                  spreadRadius: 3.0,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: _pickedPhoto != null
                                ? CircleAvatar(
                                    radius: 48,
                                    backgroundImage: FileImage(_pickedPhoto!),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [kSky, kBlue],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: _currentInitials.isNotEmpty
                                        ? Text(
                                            _currentInitials,
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const CustomPaint(
                                            size: Size(40, 40),
                                            painter: UserOutlinePainter(color: Colors.white),
                                          ),
                                  ),
                          ),
                          // Badge Kamera
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: kBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: const CustomPaint(
                                size: Size(16, 16),
                                painter: CameraOutlinePainter(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _pickedPhoto != null
                        ? 'Foto terpilih ✓'
                        : (widget.isSetup ? 'Tap untuk tambah foto (opsional)' : 'Tap untuk ubah foto'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _pickedPhoto != null
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF7EB8FF),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- Pesan Sukses / Error ---
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),

                  if (_savedSuccess)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        widget.isSetup ? 'Profil tersimpan. Menuju Beranda...' : 'Profil berhasil disimpan',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                      ),
                    ),

                  // --- Form Card (.card.form) ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kLine),
                      boxShadow: const [
                        BoxShadow(color: Color(0x121E6FEB), blurRadius: 12, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Field Nama
                        Text(
                          widget.isSetup ? 'Nama *' : 'Nama',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBody),
                        ),
                        const SizedBox(height: 6),
                        _buildTextInput(
                          controller: _namaController,
                          placeholder: 'Contoh: Pak Budi',
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 14),

                        // Field Jenis Kelamin (Segmented Button)
                        const Text(
                          'Jenis Kelamin',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBody),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSegButton(
                                label: 'Laki-laki',
                                isSelected: _selectedJk == 'Laki-laki',
                                onTap: () => setState(() => _selectedJk = 'Laki-laki'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildSegButton(
                                label: 'Perempuan',
                                isSelected: _selectedJk == 'Perempuan',
                                onTap: () => setState(() => _selectedJk = 'Perempuan'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // 3 Kolom: Usia, Tinggi, Berat
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.isSetup ? 'Usia (th) *' : 'Usia (th)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBody),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildTextInput(
                                    controller: _usiaController,
                                    placeholder: '72',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tinggi (cm)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBody),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildTextInput(
                                    controller: _tinggiController,
                                    placeholder: '165',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Berat (kg)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBody),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildTextInput(
                                    controller: _beratController,
                                    placeholder: '60',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Catatan Kesehatan
                        const Text(
                          'Catatan Kesehatan (opsional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBody),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kInputLine),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: TextField(
                            controller: _catatanController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kInk),
                            decoration: const InputDecoration(
                              hintText: 'Contoh: riwayat penyakit atau alergi',
                              hintStyle: TextStyle(color: kMuted, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- Card Jam Tangan Pasien (.card.dev) ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kLine),
                      boxShadow: const [
                        BoxShadow(color: Color(0x121E6FEB), blurRadius: 12, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: kL2,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.watch_rounded, size: 20, color: kBlue),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jam Tangan Pasien',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'device_001 • Terhubung',
                              style: TextStyle(fontSize: 12, color: kMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Tombol Simpan (.btn) ---
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kSky, kBlue],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x4D1E6FEB), blurRadius: 24, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _save,
                        child: Center(
                          child: Text(
                            widget.isSetup ? 'Simpan & Mulai Pantau' : 'Simpan Profil',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTextInput({
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInputLine),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kInk),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: kMuted, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSegButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? kL2 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? kBlue : kInputLine),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? kNavy : kBody,
          ),
        ),
      ),
    );
  }
}

/// Painter vector ikon user persis sesuai SVG acuan:
/// `<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.5-6 8-6s8 2 8 6"/>`
class UserOutlinePainter extends CustomPainter {
  final Color color;
  const UserOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scaleX
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Circle head: cx 12, cy 8, r 4
    canvas.drawCircle(const Offset(12, 8), 4, paint);

    // Shoulder curve: M4 21c0-4 3.5-6 8-6s8 2 8 6
    final path = Path();
    path.moveTo(4, 21);
    path.cubicTo(4, 17, 7.5, 15, 12, 15);
    path.cubicTo(16.5, 15, 20, 17, 20, 21);
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter vector ikon kamera persis sesuai SVG acuan:
/// `<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>`
class CameraOutlinePainter extends CustomPainter {
  final Color color;
  const CameraOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scaleX
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Camera body: M4 8h3l2-3h6l2 3h3v11H4z
    final body = Path();
    body.moveTo(4, 8);
    body.lineTo(7, 8);
    body.lineTo(9, 5);
    body.lineTo(15, 5);
    body.lineTo(17, 8);
    body.lineTo(20, 8);
    body.lineTo(20, 19);
    body.lineTo(4, 19);
    body.close();
    canvas.drawPath(body, paint);

    // Camera lens: circle cx 12, cy 13, r 3.5
    canvas.drawCircle(const Offset(12, 13), 3.5, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
