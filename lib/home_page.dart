import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Import package baru

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Membuat referensi (jalur) ke Firebase Realtime Database
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Devices/Device_01");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor pasien"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: _dbRef.onValue, 
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          
          // loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // error handling
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          // baca data
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            
            Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

            final vitalSigns = data['VitalSigns'] ?? {};
            final deviceStatus = data['DeviceStatus'] ?? {};
            final fallDetection = data['FallDetection'] ?? {};

            //ui awal
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("--- KARTU TANDA VITAL ---", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("BPM (Detak Jantung): ${vitalSigns['HeartRate']} bpm"),
                  Text("SpO2 (Oksigen): ${vitalSigns['SpO2']} %"),
                  Text("Suhu Tubuh: ${vitalSigns['Temperature']} °C"),
                  
                  const SizedBox(height: 25),
                  
                  const Text("--- STATUS PERANGKAT ---", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Koneksi Gateway: ${deviceStatus['Connection']}"),
                  Text("Sisa Baterai: ${deviceStatus['Battery']} %"),
                  Text("Terakhir Update: ${deviceStatus['LastUpdated']}"),
                  
                  const SizedBox(height: 25),
                  
                  const Text("--- DETEKSI JATUH (FALL DETECTION) ---", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Status: ${fallDetection['StatusText']}"),
                  Text("Terdeteksi Jatuh: ${fallDetection['IsFallen'] == true ? 'YA' : 'TIDAK'}"),
                ],
              ),
            );
          }

          //jika data kosong
          return const Center(child: Text('Menunggu data dari perangkat...'));
        },
      ),
    );
  }
}