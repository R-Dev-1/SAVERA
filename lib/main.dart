import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
import 'pages/landing_page.dart'; // Mengimpor file halaman landing

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // BYPASS FIREBASE: Komentar pada inisialisasi Firebase agar web dapat berjalan tanpa blank white screen
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAVERA App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6FEB)), 
        scaffoldBackgroundColor: const Color(0xFFF0F7FF), // Palet --l1 #F0F7FF
        useMaterial3: true,
      ),
      home: const WelcomeScreen(), // Memanggil Halaman 1
    );
  }
}