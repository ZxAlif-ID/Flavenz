---
name: Bug report / Laporan bug
about: Tuning action failure, config rejection, or unexpected behavior / Kegagalan aksi tuning, config ditolak, atau perilaku tak terduga
title: "[bug] "
labels:
  - bug
---

**Device / ROM**
- Device: (e.g. POCO F6)
- SoC / GPU: (e.g. Snapdragon 8s Gen 3 / Adreno 735)
- Android version + root solution: (e.g. HyperOS Android 14 + KernelSU-Next 3.3.0)
- Termux version:

**Flavenz area affected**
- Flavor: Performance Profiles / CPU / WALT / GPU / Thermal / WuWa Config Manager / Monitor / Backup-Restore
- Version: (e.g. 1.0.0, commit sha)

**What happened?**
A clear description of the failure (write rejected, config not applied, wrong
values shown, script crash, ...).
/ Deskripsi jelas kegagalannya (write ditolak, config tidak nempel, nilai salah
tampil, script crash, ...).

**Steps to reproduce**
1. ...
2. ...

**Logs**
- Paste relevant lines from `logs/ther_t3.log` / `logs/changes.log` as text.
- For WuWa config issues: state which preset and whether the game rejected the
  config (check in-game or Client.log).

**Checklist**
- [ ] Backup (`[1]`) was run before first use / Backup sudah dijalankan sebelum pemakaian
- [ ] Verified on real hardware, not emulator / Dites di device nyata, bukan emulator
