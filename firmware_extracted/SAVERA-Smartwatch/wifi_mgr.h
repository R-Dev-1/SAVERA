// wifi_mgr.h - manajer WiFi: simpan kredensial (NVS), auto-connect, scan, "Kunci IP", mDNS, NTP,
//              + PAIRING lewat HP (AP sementara + QR + halaman web)
#pragma once
#include <Arduino.h>

struct WifiScanItem { char ssid[33]; int8_t rssi; bool secure; };

void wifi_init();                                     // mulai task jaringan (WiFi + HTTP server)
void wifi_connect(const char* ssid, const char* pass);// dari UI/API: simpan & sambungkan
void wifi_forget();
bool wifi_has_saved();                                // ada jaringan tersimpan (kredensial di NVS)
void wifi_ntp_resync();                               // minta sinkron NTP segera (mis. setelah mode otomatis diaktifkan)                                   // hapus jaringan tersimpan
void wifi_scan_request();
bool wifi_scan_busy();
int  wifi_scan_get(WifiScanItem* out, int maxn, uint32_t* seq);
void wifi_scan_json(char* buf, size_t n);             // {"scanning":bool,"nets":[{ssid,rssi,sec}]}
void wifi_set_ip_lock(bool on);
bool wifi_get_ip_lock();

// ---- Pairing lewat HP ----
enum ProvState : uint8_t { PROV_OFF = 0, PROV_WAIT_CLIENT, PROV_CLIENT_JOINED, PROV_REBOOTING, PROV_FAILED };
struct ProvInfo {
  ProvState st;
  char ap_ssid[33];     // nama AP sementara
  char pin[12];         // sandi AP sementara (acak tiap sesi)
  char target[33];      // SSID yang sedang dicoba
  char msg[72];         // pesan hasil/kesalahan
  char ip[16];          // IP setelah sukses
  uint8_t clients;      // jumlah HP yang tersambung ke AP
  uint32_t remain_s;    // sisa waktu sesi
};
void wifi_prov_start();
void wifi_prov_stop();
bool wifi_prov_active();
ProvInfo wifi_prov_info();
bool wifi_prov_submit(const char* ssid, const char* pass, char* err, size_t en);   // dipanggil halaman web
void wifi_prov_status_json(char* buf, size_t n);
