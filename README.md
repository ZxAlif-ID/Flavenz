# Flavenz — Performance Suite (Termux + Root)

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

## License

Apache-2.0 (mengikuti referensi AZenith)
