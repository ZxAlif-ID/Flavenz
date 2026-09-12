# Changelog

All notable changes to this project are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-09-13

### Added
- Ther_T3_Clean V1.13 base: thermal/CPU/GPU/WALT tuning, backup/restore,
  emergency restore, capability scan, live monitor (Poco F6 / SD 8s Gen 3
  / Adreno 735 reference)
- WuWa Config Manager (`lib/wuwa.sh`, menu `[7]`):
  - 4 presets (balanced / gaming / maxvisual / potato), each = Engine.ini +
    DeviceProfiles.ini + Game.ini
  - Kuro ConfigMonitor v3.6 forbidden-CVar auto-filter on deploy (52 CVars)
  - DeviceProfile forcer per model/GPU
  - Game.ini FrameRateLimit generator (45/60/90/120)
  - Vanilla backup + restore
- Apache-2.0 license, community standards files

[1.0.0]: https://github.com/ZxAlif-ID/Flavenz/releases/tag/v1.0.0
