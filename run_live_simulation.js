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
  console.log("[HEARTBEAT LOOP] Dimulai: Mengirim Heartbeat + Connection: Online setiap 1 detik.");
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
  console.log("[HEARTBEAT LOOP] Berhenti.");
}

async function runLiveSimulation() {
  console.log("=== SIMULASI LIVE SAVERA VIA MCP FIREBASE DIMULAI ===");
  const transport = new StdioClientTransport({
    command: "node",
    args: ["mcp_firebase.js"],
  });

  const client = new Client(
    { name: "savera-live-simulator", version: "1.0.0" },
    { capabilities: {} }
  );

  await client.connect(transport);
  console.log("MCP Client berhasil terhubung ke mcp_firebase.js!");

  // 1. Mulai Background Heartbeat Loop (setiap 1 detik)
  startHeartbeatLoop(client);

  // Berikan waktu 2 detik untuk memastikan koneksi HP mendeteksi Online
  await sleep(2000);

  // --- SKENARIO 1: Baterai 15% ---
  console.log("\n-------------------------------------------------------------");
  console.log("[1/6] Skenario 1 (Detik ke-0): Mengubah Baterai ke 15% (Low Battery)...");
  currentBattery = 15;
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/FallDetection",
      data: {
        IsFallen: false,
        Active: false,
        StatusText: "Kondisi Normal",
      },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: { Type: "Diam" },
    },
  });
  console.log(">>> SKENARIO 1 AKTIF: Baterai = 15%. Banner Baterai Lemah muncul di layar HP.");
  console.log("Menunggu 10 detik...");
  await sleep(10000);

  // --- SKENARIO 2: Kembalikan Baterai ke 85% ---
  console.log("\n-------------------------------------------------------------");
  console.log("[2/6] Skenario 2 (Detik ke-10): Mengembalikan Baterai ke 85%...");
  currentBattery = 85;
  console.log(">>> SKENARIO 2 AKTIF: Baterai = 85%. Banner Baterai Lemah tertutup otomatis.");
  console.log("Menunggu 10 detik...");
  await sleep(10000);

  // --- SKENARIO 3: BPM Abnormal 135 ---
  console.log("\n-------------------------------------------------------------");
  console.log("[3/6] Skenario 3 (Detik ke-20): Mengubah BPM ke 135 (Abnormal/Kritis)...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/VitalSigns",
      data: {
        HeartRate: 135,
        SpO2: 96,
      },
    },
  });
  console.log(">>> SKENARIO 3 AKTIF: BPM = 135. Grafik BPM auto-scale naik & Card Nadi menunjukkan 135 BPM.");
  console.log("Menunggu 10 detik...");
  await sleep(10000);

  // --- SKENARIO 4: Aktivitas Terjatuh (Darurat) ---
  console.log("\n-------------------------------------------------------------");
  console.log("[4/6] Skenario 4 (Detik ke-30): Mengubah Status Menjadi 'Terjatuh'...");
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
        BA: "3.24g",
        BG: "248°/s",
      },
    },
  });
  console.log(">>> SKENARIO 4 AKTIF: Status = Terjatuh. Banner tengah MERAH MENYALA di HP.");
  console.log("Menunggu 10 detik...");
  await sleep(10000);

  // --- SKENARIO 5: Kembalikan BPM Normal (78) & Aktivitas 'Diam' ---
  console.log("\n-------------------------------------------------------------");
  console.log("[5/6] Skenario 5 (Detik ke-40): Mengembalikan BPM ke 78 & Status ke 'Diam'...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/VitalSigns",
      data: {
        HeartRate: 78,
        SpO2: 98,
      },
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
  console.log(">>> SKENARIO 5 AKTIF: BPM = 78, Status = Diam. Status darurat mati & layar kembali normal.");
  console.log("Menunggu 10 detik...");
  await sleep(10000);

  // --- SKENARIO 6: Tambah Riwayat Baru ---
  console.log("\n-------------------------------------------------------------");
  console.log("[6/6] Skenario 6 (Detik ke-50): Menambahkan Riwayat Kejadian Baru...");
  const pushRes = await client.callTool({
    name: "push_firebase",
    arguments: {
      path: "Devices/Device_01/History",
      data: {
        title: "Pemantauan pasien dimulai",
        timestamp: Date.now(),
        time: getFormattedTime(),
      },
    },
  });
  console.log("Tool Response:", pushRes.content[0].text);
  console.log(">>> SKENARIO 6 AKTIF: 'Pemantauan pasien dimulai' masuk ke timeline Riwayat Kejadian.");

  // Pertahankan heartbeat selama 30 detik tambahan agar pengguna puas melihat hasil akhirnya
  console.log("\nSemua skenario selesai! Mempertahankan Heartbeat selama 30 detik agar layar HP tetap Online...");
  await sleep(30000);

  isRunning = false;
  await sleep(1500);
  await client.close();
  console.log("Simulasi selesai sepenuhnya.");
  process.exit(0);
}

runLiveSimulation().catch((err) => {
  console.error("Error dalam runLiveSimulation:", err);
  process.exit(1);
});

