const { Client } = require("@modelcontextprotocol/sdk/client/index.js");
const { StdioClientTransport } = require("@modelcontextprotocol/sdk/client/stdio.js");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getFormattedTime() {
  const d = new Date();
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes} WIB`;
}

async function runScenarios() {
  console.log("=== MEMULAI SIMULASI MOCK DATA VIA MCP FIREBASE ===");
  console.log("Menghubungkan ke server MCP (mcp_firebase.js)...");

  const transport = new StdioClientTransport({
    command: "node",
    args: ["mcp_firebase.js"],
  });

  const client = new Client(
    { name: "savera-mcp-simulator", version: "1.0.0" },
    { capabilities: {} }
  );

  await client.connect(transport);
  console.log("Terhubung ke MCP Server!");

  // --- SKENARIO 1: Baterai 15% (Peringatan Baterai Lemah) ---
  console.log("\n----------------------------------------------------");
  console.log("[1/5] Menjalankan Skenario 1: Update Baterai ke 15%...");
  
  // Nonaktifkan isFallen terlebih dahulu agar tidak menimpa peringatan baterai
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
  console.log("Hasil MCP Tool:", res1.content[0].text);
  console.log("SKENARIO 1 SELESAI: Nilai baterai smartwatch di-update ke 15%.");
  console.log("Indikator baterai berubah menjadi amber dan Banner Peringatan Baterai Lemah muncul di layar HP.");
  console.log("Memberikan jeda 5 detik agar pengguna dapat mengamati layar HP...");
  await sleep(5000);

  // --- SKENARIO 2: Kembalikan Baterai ke 85% ---
  console.log("\n----------------------------------------------------");
  console.log("[2/5] Menjalankan Skenario 2: Kembalikan Baterai ke 85%...");
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
  console.log("Hasil MCP Tool:", res2.content[0].text);
  console.log("SKENARIO 2 SELESAI: Nilai baterai smartwatch dikembalikan ke 85%.");
  console.log("Banner Peringatan Baterai Lemah tertutup otomatis dan persentase baterai kembali normal.");
  console.log("Memberikan jeda 5 detik...");
  await sleep(5000);

  // --- SKENARIO 3: Detak Jantung Kritis 135 BPM ---
  console.log("\n----------------------------------------------------");
  console.log("[3/5] Menjalankan Skenario 3: Update BPM ke 135 (Kritis)...");
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
  console.log("Hasil MCP Tool:", res3.content[0].text);
  console.log("SKENARIO 3 SELESAI: Detak jantung di-update ke 135 BPM.");
  console.log("Card Tanda Vital menampilkan 135 BPM dan grafik tren denyut nadi auto-scale naik.");
  console.log("Memberikan jeda 5 detik...");
  await sleep(5000);

  // --- SKENARIO 4: Aktivitas Darurat (Terjatuh) ---
  console.log("\n----------------------------------------------------");
  console.log("[4/5] Menjalankan Skenario 4: Update Status Darurat 'Terjatuh'...");
  await client.callTool({
    name: "update_firebase",
    arguments: {
      path: "Devices/Device_01/Activity",
      data: {
        Type: "Terjatuh",
      },
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
  console.log("Hasil MCP Tool:", res4.content[0].text);
  console.log("SKENARIO 4 SELESAI: Status darurat 'Terjatuh' aktif.");
  console.log("Banner tengah berubah merah dengan peringatan bahaya jatuh dan nilai akselerometer/giroskop tinggi.");
  console.log("Memberikan jeda 5 detik...");
  await sleep(5000);

  // --- SKENARIO 5: Tambah Entri Riwayat / Timeline ---
  console.log("\n----------------------------------------------------");
  console.log("[5/5] Menjalankan Skenario 5: Tambah Riwayat 'Uji coba MCP berhasil'...");
  const res5 = await client.callTool({
    name: "push_firebase",
    arguments: {
      path: "Devices/Device_01/History",
      data: {
        title: "Uji coba MCP berhasil",
        timestamp: Date.now(),
        time: getFormattedTime(),
      },
    },
  });
  console.log("Hasil MCP Tool:", res5.content[0].text);
  console.log("SKENARIO 5 SELESAI: Entri riwayat baru berhasil ditambahkan.");
  console.log("Item 'Uji coba MCP berhasil' langsung muncul di daftar Riwayat Kejadian (Hari Ini).");

  console.log("\n=== SELURUH 5 SKENARIO PENGUJIAN MCP TELAH SELESAI DIEKSEKUSI ===");
  await client.close();
  process.exit(0);
}

runScenarios().catch((err) => {
  console.error("Gagal menjalankan skenario MCP:", err);
  process.exit(1);
});

