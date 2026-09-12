# Flavenz — Performance Suite (Termux + Root)

[![CI](https://github.com/ZxAlif-ID/Flavenz/actions/workflows/ci.yml/badge.svg)](https://github.com/ZxAlif-ID/Flavenz/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/License-Apache%202.0-orange)
![Platform](https://img.shields.io/badge/Platform-Android%2011%2B%20%7C%20Termux-blue)

Modul tweaking performa Android via Termux, design & referensi arsitektur dari
[AZenith](https://github.com/Liliya2727/AZenith) (Apache-2.0), dibangun di atas basis
thermal manager Ther_T3_Clean V3.0.

**Device referensi:** Poco F6 / Snapdragon 8s Gen 3 / Adreno 735 / KernelSU-Next

## Struktur

```
Flavenz/
├── main.sh                 -- entry point + menu utama
├── DOCS.md                 -- dokumen teknis basis Ther_T3
├── lib/
│   ├── config.sh           -- konstanta, warna, path, CAP_* vars, WALT defaults
│   ├── utils.sh            -- swrite (chmod 644/444), verify, log, sensor readers
│   ├── capability.sh       -- device scan + cache + report (WALT + pwrlevel)
│   ├── actions.sh          -- backup, restore, governor, zones, profiles, WALT, GPU
│   ├── monitor.sh          -- live dashboard
│   └── wuwa.sh             -- WuWa Config Manager (Engine.ini / DeviceProfiles.ini / Game.ini)
├── configs/wuwa/           -- 4 preset config Wuthering Waves (forbidden-cleaned v3.6)
│   ├── balanced_*          -- 45-60fps stabil, visual standar+
│   ├── gaming_*            -- floor 45fps battle, visual medium
│   ├── maxvisual_*         -- visual penuh (wajib cooler)
│   └── potato_*            -- survival, fps maksimal
└── module/                 -- (reserved) packaging Magisk/KernelSU module
```

## Fitur

### Thermal & CPU/GPU (basis Ther_T3 V1.13)
- Live monitor: temp bar CPU/GPU/BAT, freq, load, sconfig
- Backup/Restore/Emergency Restore state sysfs
- Performance Profiles: Balanced / Gaming / Extreme (CPU + WALT + GPU)
- CPU Governor + WALT tuning (hispeed_load, rate limits, rtg_boost)
- GPU control via pwrlevel (Adreno 735: governor hanya msm-adreno-tz)
- Thermal Control: disable/enable all (services + zones)
- Full Kill Mode + Capability Report

### WuWa Config Manager (`lib/wuwa.sh`)
- Deploy preset Engine.ini + DeviceProfiles.ini + Game.ini ke
  `Android/data/com.kurogame.wutheringwaves.global/files/UE4Game/Client/Client/Saved/Config/Android/`
- **Forbidden CVar filter** — 52 cvar yang di-track/reject Kuro ConfigMonitor v3.6
  dihapus otomatis saat deploy (sumber: Arglax forbidden_cvars.txt)
- Forcer DeviceProfile per model/GPU (section append, match paksa)
- Game.ini generator: FrameRateLimit 45/60/90/120 manual
- Backup config asli sekali (`backup/wuwa/*.orig`) + restore vanilla
- Deteksi otomatis paket global / CN

## Preset WuWa

| Preset | sg.Res | Shadow | Target | Cooler |
|---|---|---|---|---|
| BALANCED | 0.85 | 6 cascade cached | 45-60 stabil | opsional |
| GAMING | 0.75 | 4 cascade + URO 3 | floor 45 battle | opsional |
| MAXVISUAL | 1.00 | 8 cascade + SSR + capsule | max visual | **wajib** |
| POTATO | 0.65 | 1 cascade | fps absolut | tidak perlu |

## Cara Jalankan

```bash
cd ~/Flavenz
./main.sh
```

Script auto-request root via `su`. Menu `[7]` = WuWa Config Manager.

## Alur kerja yang disarankan (device referensi)

1. `[1]` Backup state sysfs saat ini (sekali di awal)
2. WuWa `[7]` → deploy **GAMING** → mainkan uji battle → cek floor fps
3. Kalau tembus >55: naik ke **BALANCED**; kalau drop <45: turun **POTATO**
4. Sesi main panjang pakai cooler: **MAXVISUAL** + Full Kill/Extreme profile
5. Selesai uji: `[R]` restore sysfs; WuWa `[R]` restore vanilla bila perlu

## Sumber & Referensi

- [AZenith](https://github.com/Liliya2727/AZenith) — arsitektur module, swrite pattern (write_val), auto-profile concept
- [Arglax/Mobile-WuWa-Config](https://github.com/Arglax/Mobile-WuWa-Config) — base config v3.6 + forbidden cvars list
- [B3rr7/WuWa-Config-Android](https://github.com/B3rr7/WuWa-Config-Android) — preset matrix referensi (SmartBrain scoring)
- [Shxvi/wuwa-configs](https://github.com/Shxvi/wuwa-configs) — DeviceProfile per-model/GPU pattern
- [Epic UE4 CVar Reference](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-console-variables-reference)

## ⚠️ Disclaimer

> [!IMPORTANT]
> **This is a personal, non-commercial project.** It is provided **AS-IS**, with **no warranty of any kind**, express or implied.
> / **Proyek pribadi, non-komersial.** Disediakan **SEBAGAIMANA ADANYA**, **tanpa jaminan apapun**.

- **You are fully responsible for anything you do with these scripts and configs.** Any mistakes, errors, malfunctions, data loss, battery degradation, overheating, or **damage to your device/system** (bootloop, hard brick, security incident, reduced hardware lifespan, etc.) are **entirely at your own risk and responsibility**.
  / **Kamu sepenuhnya bertanggung jawab atas apapun yang kamu lakukan dengan script dan config ini.** Kesalahan, kerusakan sistem, kehilangan data, degradasi baterai, overheat, atau **kerusakan device** (bootloop, hard brick, insiden keamanan, umur hardware berkurang, dll.) adalah **risiko dan tanggung jawabmu sepenuhnya**.
- **Performance tuning affects hardware behavior.** CPU/GPU frequency locking, thermal protection disabling, and WALT changes can increase heat and power draw and may **shorten hardware lifespan**. Hardware limits (e.g. GPU frequency hardcap) are device-specific — values proven on one device may not be safe or effective on yours.
  / **Tuning performa memengaruhi perilaku hardware.** Locking frekuensi CPU/GPU, mematikan proteksi thermal, dan perubahan WALT bisa menaikkan panas dan konsumsi daya serta dapat **memperpendek umur hardware**. Limit hardware (mis. hardcap frekuensi GPU) spesifik per device — nilai yang proven di satu device belum tentu aman di device-mu.
- **Game configs may violate the game's Terms of Service.** Wuthering Waves config modification is a gray area; modified configs can be detected, rejected, or acted upon by Kuro Games. Use at your own discretion — no liability for account actions.
  / **Config game berpotensi melanggar ToS game.** Modifikasi config Wuthering Waves adalah area abu-abu; config modifikasi bisa terdeteksi, ditolak, atau ditindak oleh Kuro Games. Gunakan dengan kesadaran sendiri — tidak ada tanggung jawab atas tindakan akun.
- **Always run the built-in backup (`[1]`) before first use** and keep the `backup/` directory intact. Restores: `[R]` (full) or `[E]` (emergency). WuWa config restores via menu `[7] > [R]`.
  / **Selalu jalankan backup bawaan (`[1]`) sebelum pemakaian pertama** dan jaga folder `backup/`. Restore: `[R]` (penuh) atau `[E]` (darurat). Restore config WuWa via menu `[7] > [R]`.
- By downloading, running, or deploying any part of this repository, you acknowledge and accept full responsibility for the outcome.
  / Dengan mengunduh, menjalankan, atau men-deploy bagian manapun dari repo ini, kamu mengakui dan menerima penuh tanggung jawab atas hasilnya.

---

## 📄 License

Distributed under the **Apache License 2.0** — see [LICENSE](LICENSE).
