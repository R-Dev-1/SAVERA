// portal_html.h - halaman web pairing Wi-Fi (disajikan jam lewat AP sementara; dibuka dari HP setelah scan QR)
#pragma once
#include <pgmspace.h>

static const char PORTAL_HTML[] PROGMEM = R"HTML(<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SAVERA Smartwatch</title>
<style>
:root{color-scheme:light dark;--bg:#0b0f14;--card:#151b23;--tx:#e8eef5;--mu:#7d8a99;--ac:#2d7ff9;--ok:#3ddc84;--bad:#ff5252}
@media(prefers-color-scheme:light){:root{--bg:#f2f5f9;--card:#fff;--tx:#14202b;--mu:#5d6b7a}}
*{box-sizing:border-box}body{margin:0;font:16px system-ui,sans-serif;background:var(--bg);color:var(--tx);padding:16px;max-width:480px;margin:auto}
h1{font-size:20px;margin:4px 0 12px}.card{background:var(--card);border-radius:14px;padding:14px;margin-bottom:12px}
.note{font-size:13px;color:var(--mu);line-height:1.4}.warn{border-left:4px solid #ffb84d;padding-left:10px}
.net{display:flex;justify-content:space-between;align-items:center;padding:12px 8px;border-bottom:1px solid #8883;cursor:pointer;border-radius:8px}
.net:last-child{border:0}.net.sel{background:#2d7ff922;outline:2px solid var(--ac)}.sig{font-size:12px;color:var(--mu)}
input{width:100%;padding:12px;font-size:16px;border-radius:10px;border:1px solid #8886;background:transparent;color:var(--tx);margin:6px 0}
button{width:100%;padding:13px;font-size:16px;border:0;border-radius:12px;background:var(--ac);color:#fff;margin-top:8px}
button.sec{background:#8883;color:var(--tx)}button:disabled{opacity:.5}
#st{font-size:15px;min-height:22px}.ok{color:var(--ok)}.bad{color:var(--bad)}
</style></head><body>
<h1>Hubungkan jam ke Wi-Fi</h1>
<div class="card warn note"><b>Hanya Wi-Fi 2.4&nbsp;GHz.</b> Chip jam (ESP32-C6) tidak mendukung 5&nbsp;GHz. Jika router Anda punya dua pita, pilih nama jaringan 2.4&nbsp;GHz (atau yang namanya sama dengan pita 5&nbsp;GHz bila router memakai satu nama).</div>
<div class="card"><div style="display:flex;justify-content:space-between;align-items:center"><b>Pilih jaringan</b><a href="#" id="rs" style="color:var(--ac);font-size:14px">Pindai</a></div>
<div id="list" class="note" style="margin-top:8px">Memindai…</div>
<a href="#" id="man" style="color:var(--ac);font-size:14px;display:block;margin-top:8px">Nama jaringan tersembunyi? Ketik manual</a></div>
<div class="card"><input id="ssid" placeholder="Nama Wi-Fi (SSID)" autocapitalize="none" autocomplete="off">
<input id="pass" type="password" placeholder="Kata sandi Wi-Fi" autocomplete="off">
<label class="note"><input type="checkbox" id="sp" style="width:auto;margin-right:6px">Tampilkan sandi</label>
<button id="go">Hubungkan</button><div id="st" class="note" style="margin-top:10px"></div></div>
<div class="note">Setelah Anda menekan Hubungkan, jam menyimpan data, restart, lalu terhubung ke Wi-Fi tersebut.</div>
<script>
const $=i=>document.getElementById(i);let tm=null;
function bars(r){return r>-55?'▂▄▆█':r>-67?'▂▄▆':r>-78?'▂▄':'▂'}
async function scan(re){try{const r=await fetch('/prov/scan'+(re?'?rescan=1':''));const j=await r.json();
 if(j.scanning&&!j.nets.length){$('list').textContent='Memindai…';setTimeout(()=>scan(false),1500);return}
 const l=$('list');l.textContent='';if(!j.nets.length){l.textContent='Tidak ada jaringan 2.4 GHz terdeteksi. Coba pindai ulang.';return}
 j.nets.forEach(n=>{const d=document.createElement('div');d.className='net';
  const a=document.createElement('span');a.textContent=(n.sec?'🔒 ':'')+n.ssid;const b=document.createElement('span');b.className='sig';b.textContent=bars(n.rssi)+' '+n.rssi+' dBm';
  d.append(a,b);d.onclick=()=>{document.querySelectorAll('.net').forEach(x=>x.classList.remove('sel'));d.classList.add('sel');$('ssid').value=n.ssid;$('pass').focus()};l.append(d)})}catch(e){setTimeout(()=>scan(false),2000)}}
$('rs').onclick=e=>{e.preventDefault();$('list').textContent='Memindai…';scan(true)};
$('man').onclick=e=>{e.preventDefault();$('ssid').focus()};
$('sp').onchange=e=>{$('pass').type=e.target.checked?'text':'password'};
function msg(t,c){const s=$('st');s.textContent=t;s.className='note '+(c||'')}
function done(ssid){document.querySelector('h1').textContent='Data diterima';
 document.querySelectorAll('.card').forEach(c=>c.style.display='none');
 const d=document.createElement('div');d.className='card';
 d.innerHTML='<b>Jam akan restart lalu terhubung ke “'+ssid.replace(/[<>&]/g,'')+'”.</b><p class="note">Halaman ini ditutup otomatis. Sambungkan HP Anda kembali ke Wi-Fi rumah. Hasil koneksi tampil di layar jam. Jika gagal (sandi salah), ulangi pairing dari layar jam.</p>';
 document.body.insertBefore(d,document.querySelector('.note:last-of-type'))}
$('go').onclick=async()=>{const ssid=$('ssid').value.trim();if(!ssid){msg('Isi nama Wi-Fi dulu','bad');return}
 $('go').disabled=true;msg('Mengirim…');
 try{const b=new URLSearchParams({ssid:ssid,pass:$('pass').value});const r=await fetch('/prov/connect',{method:'POST',body:b});
  if(!r.ok){const j=await r.json().catch(()=>({}));msg('Gagal: '+(j.error||r.status),'bad');$('go').disabled=false;return}
  done(ssid)}catch(e){msg('Gagal mengirim. Coba lagi.','bad');$('go').disabled=false}};
scan(false);
</script></body></html>)HTML";
