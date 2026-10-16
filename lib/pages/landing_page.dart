import 'package:flutter/material.dart';
import 'home_page.dart'; // Mengimpor file halaman dashboard (home)

// --- Variabel Warna Menggunakan Format Kurung Siku [] ---
final Color navy = Colors.blue[900]!;
final Color blue = Colors.blue[700]!;
final Color sky = Colors.lightBlue[400]!;
final Color muted = Colors.grey[600]!;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: blue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(Icons.monitor_heart, size: 60, color: blue),
              ),
              const SizedBox(height: 24),
              // Judul
              Text(
                'SAVERA',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  color: navy,
                ),
              ),
              Text(
                'Senior Safety & Indicator System',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: blue),
              ),
              const SizedBox(height: 24),
              Text(
                'Pantau kondisi lansia dan terima peringatan jatuh secara real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: muted, height: 1.5),
              ),
              const SizedBox(height: 32),
              // Fitur List
              _buildFeatureItem(Icons.favorite, 'Denyut nadi & oksigen (SpO2)'),
              _buildFeatureItem(Icons.shield, 'Deteksi jatuh otomatis'),
              _buildFeatureItem(Icons.phone, 'Peringatan darurat instan'),
              
              const Spacer(),
              
              // Info Perangkat
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: sky, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text('Terhubung: Pak Budi (72 Tahun)', style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tombol Masuk
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  onPressed: () {
                    // Berpindah ke Halaman Dashboard
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Masuk ke Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Tanpa login • v1.0', style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50], // Biru sangat muda untuk background icon
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: blue, size: 20),
          ),
          const SizedBox(width: 16),
          Text(text, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: navy)),
        ],
      ),
    );
  }
}