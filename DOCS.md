# Ther_T3 — Project Documentation

**Version:** V3.0 (Clean) -> V1.13 (current session)
**Device:** Poco F6 (Snapdragon 8s Gen 3 / Adreno 735)
**Root:** KernelSU
**Shell:** Termux bash

---

## Latar Belakang

Project ini bermula dari script thermal management sederhana (V1.1, V1.2) yang proven dan stabil. Versi Pro (V2.0) terlalu ambisius — loncat 3 versi tanpa test per fitur, sehingga banyak command yang tidak bisa dijalankan dan error di device nyata. V3.0 (Clean) adalah rewrite dari scratch: ambil yang esensial dari V1.x, upgrade struktur jadi modular, buang semua fitur yang belum proven.

Sesi September 2026 melanjutkan dari base V3.0 dengan fokus GPU control, WALT CPU tuning, dan restruktur menu.

---

## Struktur Project

```
Flavenz/
├── main.sh              -- entry point, menu utama, init
├── DOCS.md              -- dokumentasi ini
├── backup/              -- dibuat otomatis saat backup pertama
│   ├── cpu_gov.txt
│   ├── cpu_freq.txt
│   ├── gpu_gov.txt
│   ├── gpu_pwrlevel.txt
│   ├── walt.txt
│   ├── zone_modes.txt
│   ├── trip_points.txt
│   ├── sconfig.txt
│   ├── core_ctrl.txt
│   ├── svc_states.txt
│   ├── thermal_prop.txt
│   ├── swappiness.txt
│   ├── adrenoboost.txt
│   └── cap_cache.txt
├── logs/
│   ├── ther_t3.log
│   └── changes.log
├── configs/wuwa/        -- preset config Wuthering Waves (lihat section WuWa)
└── lib/
    ├── config.sh        -- konstanta, warna, path, CAP_* vars, WALT defaults
    ├── utils.sh         -- swrite (dengan chmod 644/444), verify, log, sensor readers
    ├── capability.sh    -- device scan + cache + report (include WALT + pwrlevel)
    ├── actions.sh       -- backup, restore, governor, zones, profiles, WALT, GPU profiles, full kill
    ├── monitor.sh       -- live dashboard
    └── wuwa.sh          -- WuWa Config Manager (Engine.ini / DeviceProfiles.ini / Game.ini)
```

---

## Struktur Menu

```
[M] Live Monitor

[1] Backup state saat ini
[2] Performance Profiles
    [1] Balanced
    [2] Gaming
    [3] Extreme
    [0] Kembali
[3] Set CPU -- Governor & WALT
    [1] Set CPU Governor
        [1] performance
        [2] schedutil
        [3] powersave
        [4] conservative
        [5] Input manual
        [0] Kembali
    [2] WALT CPU Tuning Profiles
        [1] Default
        [2] Balanced
        [3] Gaming
        [4] Extreme
        [0] Kembali
    [0] Kembali
[4] Set GPU -- Governor & Profiles
    [1] Set GPU Governor + adrenoboost + pwrlevel (manual)
    [2] GPU Profiles
        [1] Auto
        [2] Balanced
        [3] Gaming
        [4] Max
        [0] Kembali
    [0] Kembali
[5] Thermal Control
    [1] Disable All  (stop services + disable zones)
    [2] Enable All   (start services + enable zones)
    [3] List thermal zones + suhu
    [0] Kembali
[6] Full Kill Mode
[7] WuWa Config Manager
    [1] Status config
    [2] Preset BALANCED
    [3] Preset GAMING
    [4] Preset MAXVISUAL
    [5] Preset POTATO
    [6] Forcer DeviceProfile
    [7] Game.ini FrameRateLimit
    [R] Restore vanilla
    [0] Kembali

[R] Restore original state
[E] Emergency Restore

[C] Capability Report
[S] Re-scan capability
[L] Lihat log
[Q] Keluar
```

---

## Fitur (current)

| Fitur | Status | Keterangan |
|---|---|---|
| Live Monitor | OK | Temp bar CPU/GPU/BAT, freq, load, sconfig, profile |
| Backup | OK | Include GPU pwrlevel + WALT params per cluster |
| Restore | OK | Per-step: governor, zones, trip, sconfig, pwrlevel, WALT |
| Emergency Restore | OK | Silent, include pwrlevel + WALT restore |
| Thermal Control | OK | Disable/Enable All (service + zones sekaligus), List zones |
| Set CPU Governor | OK | Sub-menu di [3] |
| WALT CPU Tuning | OK | Sub-menu di [3] — Default / Balanced / Gaming / Extreme |
| Set GPU Governor + adrenoboost | OK | Sub-menu di [4] — manual |
| GPU Profiles | OK | Sub-menu di [4] — Auto / Balanced / Gaming / Max via pwrlevel |
| Performance Profiles | OK | [2] — Balanced / Gaming / Extreme — include WALT + GPU profile |
| Full Kill Mode | OK | [6] — semua proteksi off, WALT extreme, GPU max |
| Capability Scan + Cache | OK | Include WALT nodes, GPU pwrlevel |
| Capability Report | OK | CPU/WALT/GPU pwrlevel/thermal nodes |
| Log Viewer | OK | ther_t3.log + changes.log |
| WuWa Config Manager | OK | [7] — 4 preset + forbidden filter + forcer + Game.ini |

---

## Perubahan Sesi September 2026

### V1.5 -> V1.6: swrite permission fix
**Problem:** `swrite` gagal di beberapa KGSL nodes — permission bit node bukan writable meski sebagai root.
**Root cause:** Kernel Snapdragon beberapa node GPU defaultnya read-only bahkan untuk root.
**Fix:** Pola diambil dari AZenith module (`write_val` function) — `chmod 644` sebelum write, `chmod 444` setelah write (lock node). Diterapkan di `swrite()` di `utils.sh`.

```bash
swrite() {
    chmod 644 "$node" 2>/dev/null
    echo "$val" > "$node" 2>/dev/null
    chmod 444 "$node" 2>/dev/null
}
```

---

### V1.6 -> V1.9: GPU pwrlevel control

**Problem:** GPU governor `performance` tidak tersedia di Adreno 735 — `available_governors` hanya ada `msm-adreno-tz`. Tidak ada jalur untuk control GPU performance via governor string.

**Temuan dari device:**
```
/sys/class/kgsl/kgsl-3d0/devfreq/available_governors: msm-adreno-tz
/sys/class/kgsl/kgsl-3d0/num_pwrlevels: 11
/sys/class/kgsl/kgsl-3d0/min_pwrlevel: 10 (default, paling hemat)
/sys/class/kgsl/kgsl-3d0/max_pwrlevel: 0 (max performance)
```

**Solusi:** Kontrol GPU via `min_pwrlevel` / `max_pwrlevel`. Angka kecil = performa tinggi, angka besar = hemat daya. Kernel hardcap GPU di 900MHz (bukan 1100MHz max spec) — `msm-adreno-tz` tetap mengontrol scaling di dalam range yang diset pwrlevel.

**Urutan write yang benar (penting):**
1. Set `min_pwrlevel` ke nilai safest (num_levels - 1) dulu
2. Set `max_pwrlevel` ke target
3. Baru set `min_pwrlevel` ke target

Kalau urutan salah, kernel reject write karena min < max secara logika.

**Functions yang ditambah:**
- `action_set_gpu_pwrlevel(min, max)` — dengan urutan write yang benar
- `action_set_gpu_profile(profile)` — wrapper untuk 4 preset
- Backup: `gpu_pwrlevel.txt` — snapshot min/max
- Restore + emergency restore include pwrlevel

**GPU Profiles:**
| Profile | min_pwrlevel | max_pwrlevel | Use case |
|---|---|---|---|
| Auto | 10 | 0 | Default, biarkan msm-adreno-tz bebas |
| Balanced | 7 | 3 | Hemat daya, performa sedang |
| Gaming | 5 | 0 | Gaming normal |
| Max | 0 | 0 | Full unlock, butuh cooler |

---

### V1.9 -> V1.11: Capability scan + report update

Sebelumnya capability report tampilkan "GPU Performance: Not Supported" merah — menyesatkan karena GPU bisa dikontrol via pwrlevel.

**Yang diupdate:**
- `run_capability_scan` — tambah deteksi `min_pwrlevel`, `max_pwrlevel`, `num_pwrlevels`
- `_apply_cap_vars` — tambah `CAP_GPU_PWRLEVEL`, `CAP_GPU_NUM_LEVELS`
- `load_capability_cache` — load variable baru dari cache
- `show_capability_report` — tampilkan pwrlevel info: available, jumlah level, current min/max, active profile
- `config.sh` — init `CAP_GPU_PWRLEVEL`, `CAP_GPU_NUM_LEVELS`, `ACTIVE_GPU_PROFILE`
- `full_kill` capability check — update tampilkan status pwrlevel

---

### V1.11 -> V1.12: WALT CPU tuning + GPU profile menu terpisah

**WALT (Window Assisted Load Tracking)** — scheduler modern Qualcomm yang ada di kernel Snapdragon. Bukan governor terpisah, tapi parameter tuning di atas `schedutil`/`walt` governor.

**Nodes yang tersedia di device** (`/sys/devices/system/cpu/cpuX/cpufreq/walt/`):
- `hispeed_load` — threshold load untuk trigger boost ke hispeed_freq
- `hispeed_freq` — target freq saat load tinggi
- `up_rate_limit_us` — delay sebelum naik freq (microseconds)
- `down_rate_limit_us` — delay sebelum turun freq
- `rtg_boost_freq` — freq minimum untuk RT/game tasks
- `target_loads`, `pl`, `boost`, dll

**Default values per cluster:**
| Param | cpu0 (LITTLE) | cpu4 (big) | cpu7 (prime) |
|---|---|---|---|
| hispeed_load | 90 | 85 | 85 |
| hispeed_freq | 1113600 | 1190400 | 1459200 |
| up_rate_limit_us | 0 | 0 | 0 |
| down_rate_limit_us | 0 | 0 | 0 |
| rtg_boost_freq | 595200 | 768000 | 0 |

**WALT Profiles:**
| Profile | hispeed_load | up_rate | down_rate | rtg_boost |
|---|---|---|---|---|
| Default | 90/85/85 | 0 | 0 | kernel default |
| Balanced | 90/85/85 | 2ms | 12ms | default |
| Gaming | 75/70/70 | 0.5ms | 20ms | 768/1075/1459 MHz |
| Extreme | 60/55/55 | 0 | 0 | max tiap cluster |

**Functions yang ditambah:**
- `action_set_walt_profile(profile)` — set per-cluster
- `action_save_walt_backup()` — dump semua param ke `walt.txt`
- `action_restore_walt()` — restore dari backup

**Integrasi:**
- Profiles (balanced/gaming/extreme) pakai WALT + GPU profile sekaligus
- Full Kill: WALT extreme + GPU max
- Backup/restore/emergency restore include WALT
- Capability scan, cache, report include WALT node detection

---

### V1.12 -> V1.13: Restruktur menu + monitor fix

**Menu:**
- [2]-[6] lama (disable/enable thermal services/zones, list zones, set CPU governor, set GPU governor, GPU profiles, WALT profiles) digabung dan distruktur ulang jadi parent menu
- [3] Set CPU — Governor & WALT: sub-menu governor + WALT profiles
- [4] Set GPU — Governor & Profiles: sub-menu governor/adrenoboost/pwrlevel + GPU profiles
- [5] Thermal Control: Disable All (service + zones sekaligus), Enable All, List zones
- [W] dan [9] dihapus dari main menu, masuk ke parent masing-masing
- [2] jadi Performance Profiles (sebelumnya [P])
- [6] jadi Full Kill Mode (sebelumnya [K])
- Main menu akhir: [M][1-6][R][E][C][S][L][Q]

**Monitor:**
- `clear` diganti `printf '\033[H\033[J'` — render in-place, tidak flicker
- Interval 2 detik -> 3 detik

**Bug fix:**
- Section header `//` di shell Android dibaca sebagai directory path — diganti `#`

---

## WuWa Config Manager (Flavenz addition)

Referensi design: AZenith module (game config + sysfs tuning satu paket).
Riset lengkap config Wuthering Waves: lihat README.md section Sumber & Referensi.

### Menu [7]

```
[1] Status config
[2] Preset BALANCED  (45-60fps stabil, visual standar+, cooler opsional)
[3] Preset GAMING    (floor 45fps battle, visual medium)
[4] Preset MAXVISUAL (visual penuh, WAJIB cooler)
[5] Preset POTATO    (survival, fps maksimal)
[6] Forcer DeviceProfile per GPU/model
[7] Game.ini FrameRateLimit (45/60/90/120)
[R] Restore vanilla
```

### Preset matrix

| Preset | sg.Res | Shadow | Target | Cooler |
|---|---|---|---|---|
| balanced | 0.85 | 6 cascade cached | 45-60 stabil | opsional |
| gaming | 0.75 | 4 cascade + URO 3 | floor 45 battle | opsional |
| maxvisual | 1.00 | 8 cascade + SSR + capsule | thermal-bound | wajib |
| potato | 0.65 | 1 cascade | max fps | tidak perlu |

### Forbidden CVar filter

52 cvar Kuro ConfigMonitor v3.6 (Arglax forbidden_cvars.txt) hardcode di
`lib/wuwa.sh`. Deploy preset = filter otomatis (baris forbidden dikomentari,
tidak terdeploy). Alasan: cvar forbidden di-reject ConfigMonitor dan bisa
memicu hash mismatch -> config ditolak.

### Perilaku deploy

1. Deteksi dir config (global/CN otomatis)
2. Backup `.orig` sekali ke `backup/wuwa/`
3. Filter + tulis Engine.ini, DeviceProfiles.ini, Game.ini
4. Preset aktif dicatat ke `backup/wuwa_applied.txt`
5. Restart game; recompile shader 1x setelah config baru (normal)

---

## Konvensi Kode

- No inline comments, no line-level comments
- Section header sebagai group separator: `# BACKUP`, `# RESTORE`, dll — pakai `#`, bukan `//`
- No Unicode — semua ASCII
- No `\x1b` di sed — pakai `tr -d '\033' | sed 's/\[[0-9;]*m//g'`
- Shebang: `#!/data/data/com.termux/files/usr/bin/bash`
- Path dinamis via `SCRIPT_DIR` — tidak ada hardcode path
- `swrite()` untuk semua write ke sysfs — dengan `chmod 644/444` dan error handling
- `verify_node()` untuk konfirmasi setelah write
- `result_badge()` untuk display PASS/FAIL/N/A/SKIP

---

## Cara Jalankan

```bash
cd ~/Flavenz
./main.sh
```

Script auto-request root via `su`. Tidak perlu `su -c bash main.sh`.

---

## Lessons Learned

1. **`//` di shell Android** — dibaca sebagai directory path, bukan comment. Pakai `#`.

2. **`bash` tidak tersedia via `su`** — `su -c "bash script.sh"` gagal. Fix: `exec su -c "exec '$0'"`.

3. **`\x1b` di sed** — Android sed tidak support. Fix: `tr -d '\033' | sed 's/\[[0-9;]*m//g'`.

4. **Unicode box drawing** — tidak render di semua terminal Android. Pakai ASCII.

5. **`BASH_SOURCE` kosong via `su`** — pakai fallback: `${BASH_SOURCE[0]:-$0}`.

6. **KGSL node permission** — GPU nodes bisa read-only bahkan untuk root. Wajib `chmod 644` sebelum write.

7. **GPU governor terbatas** — Adreno 735 di kernel Poco F6 hanya punya `msm-adreno-tz`. Control GPU via pwrlevel, bukan governor string.

8. **Urutan write pwrlevel** — kernel reject kalau min_pwrlevel > max_pwrlevel. Widen ke safest dulu sebelum set target.

9. **GPU hardcap** — Device ini hardcap GPU di 900MHz regardless pwrlevel 0. Pwrlevel masih berpengaruh ke stabilitas freq dan lower bound.

10. **`clear` di monitor** — bikin flicker karena hapus layar sepenuhnya sebelum redraw. Ganti ke `printf '\033[H\033[J'` untuk render in-place.

---

## Fitur yang Dibuang dari Pro (V2.0)

Sengaja tidak dibawa — belum proven di device nyata:

- Benchmark engine (930+ baris)
- Preset manager system (711 baris)
- PSI monitor
- WALT audit
- Stability test
- Profile auto-rank

---

## Rencana Pengembangan

- [ ] Trip point editor interaktif (per zone, bukan bulk)
- [ ] adrenoboost schedule (otomatis naik waktu layar aktif)
- [ ] Suhu alert (notif atau beep kalau CPU > threshold)
- [ ] Auto-backup saat pertama kali script dijalankan
- [ ] Per-cluster CPU governor (LITTLE / big / prime terpisah)
- [ ] WALT parameter manual editor (per node, per cluster)
- [ ] Packaging KernelSU module (module/ + service.sh ala AZenith)
- [ ] Auto profile switch saat game terdeteksi (AZenith pattern)

---

## Aturan Pengembangan (WAJIB DIBACA)

> **Jangan loncat versi. Test dulu satu fitur sebelum tambah fitur berikutnya.**
>
> Flow yang benar:
> 1. Tambah satu fitur
> 2. Test di device nyata
> 3. Confirm working
> 4. Baru tambah fitur berikutnya

---

*Dokumentasi ini diupdate: September 2026*
*Base stable: Ther_T3_Clean V3.0 -> current V1.13 + Flavenz WuWa layer*
