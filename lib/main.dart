import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/landing_page.dart'; // Mengimpor file halaman landing

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        // Menggunakan kurung siku [] untuk konsistensi palet Material
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue[700]!), 
        scaffoldBackgroundColor: Colors.blue[50], // Background aplikasi yang lembut
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const WelcomeScreen(), // Memanggil Halaman 1
    );
  }
}