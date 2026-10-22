import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'pages/landing_page.dart'; // Mengimpor file halaman landing

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Menjalankan fungsi uji coba membaca data real-time dari Firebase
  testFirebaseRealtimeQuery();

  runApp(const MyApp());
}

/// Fungsi uji coba (test query) sederhana untuk membaca data real-time dari Firebase
void testFirebaseRealtimeQuery() {
  final DatabaseReference testRef = FirebaseDatabase.instance.ref('test_connection');

  debugPrint('🚀 [Firebase RTDB] Mengaktifkan listener real-time pada node /test_connection...');

  // 1. Membaca data secara real-time via stream listener
  testRef.onValue.listen(
    (DatabaseEvent event) {
      if (event.snapshot.exists) {
        debugPrint('🔔 [Firebase RTDB Realtime Update]: ${event.snapshot.value}');
      } else {
        debugPrint('ℹ️ [Firebase RTDB]: Node /test_connection belum memiliki data. Mencoba membuat data uji...');
      }
    },
    onError: (Object error) {
      debugPrint('❌ [Firebase RTDB Stream Error]: $error');
    },
  );

  // 2. Mengirim data uji awal (ping) untuk memverifikasi write & trigger listener
  testRef.update({
    'status': 'online',
    'app': 'SAVERA',
    'last_ping': DateTime.now().toIso8601String(),
    'message': 'Koneksi real-time SAVERA berhasil!',
  }).then((_) {
    debugPrint('✅ [Firebase RTDB]: Berhasil menulis ping data ke node /test_connection!');
  }).catchError((Object error) {
    debugPrint('⚠️ [Firebase RTDB Write Error]: $error (Pastikan rules RTDB diizinkan)');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAVERA App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6FEB)), 
        scaffoldBackgroundColor: const Color(0xFFF0F7FF), // Palet --l1 #F0F7FF
        useMaterial3: true,
      ),
      home: const WelcomeScreen(), // Memanggil Halaman 1
    );
  }
}