const { Client } = require("@modelcontextprotocol/sdk/client/index.js");
const { StdioClientTransport } = require("@modelcontextprotocol/sdk/client/stdio.js");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getFormattedTime() {
  const d = new Date();
  const hours = String(d.getHours()).padStart(2, "0");
  const minutes = String(d.getMinutes()).padStart(2, "0");
  return `${hours}:${minutes} WIB`;
}

let isRunning = true;
let currentBattery = 85;
let currentIsWorn = true;

async function startHeartbeatLoop(client) {
  console.log("[HEARTBEAT LOOP] Aktif: Mengirim Heartbeat + Connection: Online setiap 1 detik.");
  while (isRunning) {
    try {
      await client.callTool({
        name: "update_firebase",
        arguments: {
          path: "Devices/Device_01/DeviceStatus",
          data: {
            Heartbeat: Date.now(),
            Connection: "Online",
            IsWorn: currentIsWorn,
            Battery: currentBattery,
            Charging: false,
          },
        },
      });
    } catch (e) {
      console.error("[HEARTBEAT ERROR]:", e.message);
    }
    await sleep(1000);
  }
  console.log("[HEARTBEAT LOOP] Selesai.");
}

async function addHistoryEvent(client, title) {
  try {
    const timestamp = Date.now();
    const time = getFormattedTime();
    console.log(`[HISTORY ENTRY] Menambahkan ke Riwayat: "${title}" (${time})`);
    await client.callTool({
      name: "push_firebase",
      arguments: {
        path: "Devices/Device_01/History",
        data: {
          title: title,
          timestamp: timestamp,
          time: time,
        },
      },
    });
  } catch (e) {
    console.error("[HISTORY ERROR]:", e.message);
  }
}

async function runFullSimulation() {
  console.log("=== SIMULASI MENYELURUH FITUR SAVERA & RIWAYAT (MCP FIREBASE) ===");
  const transport = new StdioClientTransport({
    command: "node",
    args: ["mcp_firebase.js"],
  });

  const client = new Client(
    { name: "savera-live-simulator", version: "1.0.0" },
    { capabilities: {} }
  );

  await client.connect(transport);
  console.log("Terhubung ke MCP Firebase Server.");

  // Mulai Background Heartbeat Loop setiap 1 detik
  startHeartbeatLoop(client);
  await sleep(2000);

  // --------------------------------------------------------------------------
  // TAHAP 1: NORMAL & BATERAI LEMAH
  // --------------------------------------------------------------------------
  console.log("\n[TAHAP 1/6] Inisialisasi Normal: BPM 78, Diam, Baterai 85%, IsFallen: false");
  currentBattery = 85;
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/VitalSigns",
      data: { HeartRate: 78, SpO2: 98 },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: { Type: "Diam" },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/FallDetection",
      data: {
        IsFallen: false,
        Active: false,
        StatusText: "Kondisi Normal",
        BA: "1.02g",
        BG: "12°/s",
      },
    },
  });
  console.log("Kondisi normal awal terpasang. Jeda 3 detik...");
  await sleep(3000);

  console.log("Mengubah Baterai ke 15% (memicu banner kuning di UI)...");
  currentBattery = 15;
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/DeviceStatus",
      data: { Battery: 15, Heartbeat: Date.now(), Connection: "Online", IsWorn: true },
    },
  });
  await addHistoryEvent(client, "Peringatan baterai perangkat lemah (15%)");
  console.log("Baterai 15% aktif. Jeda 5 detik...");
  await sleep(5000);

  console.log("Mengembalikan Baterai ke 85% (menutup banner kuning)...");
  currentBattery = 85;
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/DeviceStatus",
      data: { Battery: 85, Heartbeat: Date.now(), Connection: "Online", IsWorn: true },
    },
  });
  console.log("Tahap 1 selesai.");
  await sleep(2000);

  // --------------------------------------------------------------------------
  // TAHAP 2: BPM ABNORMAL
  // --------------------------------------------------------------------------
  console.log("\n[TAHAP 2/6] Mengubah BPM ke 135 (grafik naik drastis)...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/VitalSigns",
      data: { HeartRate: 135, SpO2: 95 },
    },
  });
  await addHistoryEvent(client, "Lonjakan BPM abnormal terdeteksi");
  console.log("BPM 135 aktif. Jeda 5 detik...");
  await sleep(5000);

  console.log("Mengembalikan BPM ke 78 (normal)...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/VitalSigns",
      data: { HeartRate: 78, SpO2: 98 },
    },
  });
  console.log("Tahap 2 selesai.");
  await sleep(2000);

  // --------------------------------------------------------------------------
  // TAHAP 3: DARURAT (LAYAR AKTIF / FOREGROUND)
  // --------------------------------------------------------------------------
  console.log("\n[TAHAP 3/6] Mengaktifkan Peringatan Darurat Jatuh (Layar Aktif)...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: { Type: "Terjatuh" },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/FallDetection",
      data: {
        IsFallen: true,
        Active: true,
        StatusText: "PERINGATAN LANSIA TERDETEKSI JATUH",
        BA: "3.45g",
        BG: "260°/s",
      },
    },
  });
  await addHistoryEvent(client, "Peringatan: Terdeteksi jatuh (Simulasi Layar Aktif)");
  console.log("STATUS TERJATUH AKTIF! Dialog merah & sirine loop berbunyi di HP.");
  console.log("Jeda 15 detik agar pengguna dapat menekan tombol 'Matikan Alarm & Paham'...");
  await sleep(15000);
  console.log("Tahap 3 selesai.");

  // --------------------------------------------------------------------------
  // TAHAP 4: PEMULIHAN SEMENTARA
  // --------------------------------------------------------------------------
  console.log("\n[TAHAP 4/6] Pemulihan sementara: IsFallen: false, Aktivitas: Diam...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: { Type: "Diam" },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/FallDetection",
      data: {
        IsFallen: false,
        Active: false,
        StatusText: "Kondisi Normal",
        BA: "1.01g",
        BG: "14°/s",
      },
    },
  });
  console.log("Kondisi normal dipulihkan. Jeda 5 detik...");
  await sleep(5000);
  console.log("Tahap 4 selesai.");

  // --------------------------------------------------------------------------
  // TAHAP 5: HITUNG MUNDUR & DARURAT BACKGROUND / LAYAR MATI
  // --------------------------------------------------------------------------
  console.log("\n[TAHAP 5/6] HITUNG MUNDUR 5 DETIK UNTUK MEMATIKAN LAYAR HP:");
  for (let c = 5; c >= 1; c--) {
    console.log(`[HITUNG MUNDUR] ${c} DETIK... Segera matikan/kunci layar HP Anda!`);
    await sleep(1000);
  }
  console.log("Waktu habis! Memicu status TERJATUH di Background / Layar Mati...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: { Type: "Terjatuh" },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/FallDetection",
      data: {
        IsFallen: true,
        Active: true,
        StatusText: "PERINGATAN LANSIA TERDETEKSI JATUH",
        BA: "3.52g",
        BG: "275°/s",
      },
    },
  });
  await addHistoryEvent(client, "Peringatan: Terdeteksi jatuh (Simulasi Layar Mati)");
  console.log("STATUS TERJATUH DI BACKGROUND AKTIF!");
  console.log("Menunggu 15 detik untuk memantau notifikasi heads-up & layar menyala...");
  await sleep(15000);
  console.log("Tahap 5 selesai.");

  // --------------------------------------------------------------------------
  // TAHAP 6: SELESAI & RIWAYAT FINAL
  // --------------------------------------------------------------------------
  console.log("\n[TAHAP 6/6] Mengembalikan semua data ke kondisi Normal...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: { Type: "Diam" },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/FallDetection",
      data: {
        IsFallen: false,
        Active: false,
        StatusText: "Kondisi Normal",
        BA: "1.02g",
        BG: "12°/s",
      },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/VitalSigns",
      data: { HeartRate: 78, SpO2: 98 },
    },
  });

  await addHistoryEvent(client, "Sistem: Pengujian simulasi darurat selesai dilakukan");
  console.log("Riwayat final berhasil ditambahkan!");

  console.log("\nSemua 6 tahap simulasi telah berhasil dijalankan!");
  console.log("Mempertahankan loop Heartbeat selama 60 detik tambahan agar koneksi di HP tetap Online...");
  await sleep(60000);

  isRunning = false;
  await sleep(1500);
  await client.close();
  console.log("Simulasi dan Heartbeat selesai sepenuhnya.");
  process.exit(0);
}

runFullSimulation().catch((err) => {
  console.error("Error dalam runFullSimulation:", err);
  process.exit(1);
});
