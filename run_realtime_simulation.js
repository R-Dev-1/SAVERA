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

async function runSimulation() {
  console.log("=== MEMULAI SIMULASI REAL-TIME SAVERA (JEDA 7 DETIK TIAP SKENARIO) ===");
  const transport = new StdioClientTransport({
    command: "node",
    args: ["mcp_firebase.js"],
  });

  const client = new Client(
    { name: "savera-realtime-simulator", version: "1.0.0" },
    { capabilities: {} }
  );

  await client.connect(transport);
  console.log("Terhubung ke MCP Server (mcp_firebase.js)!\n");

  // --- SKENARIO 1: Ubah persentase baterai menjadi 15% ---
  console.log("----------------------------------------------------------------------");
  console.log("[1/6] Skenario 1: Mengubah nilai baterai menjadi 15%...");
  // Pastikan status darurat non-aktif terlebih dahulu agar peringatan baterai terlihat jelas
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
  const res1 = await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/DeviceStatus",
      data: {
        Battery: 15,
        Heartbeat: Date.now(),
        IsWorn: true,
        Connection: "Online",
        Charging: false,
      },
    },
  });
  console.log("Tool Response:", res1.content[0].text);
  console.log("STATUS: Skenario 1 Selesai dieksekusi!");
  console.log("Layar HP: Indikator baterai menjadi amber & Banner Peringatan Baterai Lemah muncul.");
  console.log("Menunggu jeda 7 detik untuk observasi layar HP...");
  await sleep(7000);

  // --- SKENARIO 2: Kembalikan nilai baterai menjadi 85% ---
  console.log("\n----------------------------------------------------------------------");
  console.log("[2/6] Skenario 2: Mengembalikan nilai baterai menjadi 85%...");
  const res2 = await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/DeviceStatus",
      data: {
        Battery: 85,
        Heartbeat: Date.now(),
      },
    },
  });
  console.log("Tool Response:", res2.content[0].text);
  console.log("STATUS: Skenario 2 Selesai dieksekusi!");
  console.log("Layar HP: Banner Peringatan Baterai Lemah tertutup otomatis & baterai kembali 85%.");
  console.log("Menunggu jeda 7 detik untuk observasi layar HP...");
  await sleep(7000);

  // --- SKENARIO 3: Ubah BPM ke angka abnormal (135 BPM) ---
  console.log("\n----------------------------------------------------------------------");
  console.log("[3/6] Skenario 3: Mengubah BPM (detak jantung) ke 135 BPM (Abnormal)...");
  const res3 = await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/VitalSigns",
      data: {
        HeartRate: 135,
        SpO2: 96,
      },
    },
  });
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/DeviceStatus",
      data: { Heartbeat: Date.now() },
    },
  });
  console.log("Tool Response:", res3.content[0].text);
  console.log("STATUS: Skenario 3 Selesai dieksekusi!");
  console.log("Layar HP: Card Denyut Nadi menampilkan 135 BPM & Grafik BPM auto-scale naik ke 145.");
  console.log("Menunggu jeda 7 detik untuk observasi layar HP...");
  await sleep(7000);

  // --- SKENARIO 4: Ubah status sensor aktivitas menjadi 'Terjatuh' ---
  console.log("\n----------------------------------------------------------------------");
  console.log("[4/6] Skenario 4: Mengubah status sensor aktivitas menjadi 'Terjatuh'...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: { Type: "Terjatuh" },
    },
  });
  const res4 = await client.callTool({
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
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/DeviceStatus",
      data: { Heartbeat: Date.now() },
    },
  });
  console.log("Tool Response:", res4.content[0].text);
  console.log("STATUS: Skenario 4 Selesai dieksekusi!");
  console.log("Layar HP: Banner tengah berubah menjadi MERAH DARURAT dengan indikator jatuh aktif.");
  console.log("Menunggu jeda 7 detik untuk observasi layar HP...");
  await sleep(7000);

  // --- SKENARIO 5: Kembalikan BPM ke normal (78) & aktivitas 'Diam' ---
  console.log("\n----------------------------------------------------------------------");
  console.log("[5/6] Skenario 5: Mengembalikan BPM ke 78 & status aktivitas ke 'Diam'...");
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
  const res5 = await client.callTool({
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
      path: "Devices/Device_01/DeviceStatus",
      data: { Heartbeat: Date.now() },
    },
  });
  console.log("Tool Response:", res5.content[0].text);
  console.log("STATUS: Skenario 5 Selesai dieksekusi!");
  console.log("Layar HP: Status darurat hilang, banner kembali hijau/biru tenang, BPM kembali 78.");
  console.log("Menunggu jeda 7 detik untuk observasi layar HP...");
  await sleep(7000);

  // --- SKENARIO 6: Tambah riwayat 'Pemantauan pasien dimulai' ---
  console.log("\n----------------------------------------------------------------------");
  console.log("[6/6] Skenario 6: Menambahkan riwayat 'Pemantauan pasien dimulai'...");
  const res6 = await client.callTool({
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
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/DeviceStatus",
      data: { Heartbeat: Date.now() },
    },
  });
  console.log("Tool Response:", res6.content[0].text);
  console.log("STATUS: Skenario 6 Selesai dieksekusi!");
  console.log("Layar HP: Entri 'Pemantauan pasien dimulai' langsung muncul di Riwayat Kejadian (Hari Ini).");

  console.log("\n======================================================================");
  console.log("SEMUA 6 SKENARIO SIMULASI TELAH BERHASIL DIEKSEKUSI SECARA REAL-TIME!");
  console.log("======================================================================");

  await client.close();
  process.exit(0);
}

runSimulation().catch((err) => {
  console.error("Error menjalankan simulasi:", err);
  process.exit(1);
});

