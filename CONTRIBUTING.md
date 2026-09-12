# Contributing to Flavenz / Kontribusi ke Flavenz

Thanks for your interest in contributing! / Terima kasih tertarik berkontribusi!

## How to Contribute / Cara Berkontribusi

1. **Open an issue first** — describe the problem or feature before writing code.
   / Buka issue dulu — jelaskan masalah atau fitur sebelum menulis kode.
2. **Fork & branch** — `git checkout -b fix/<short-name>` from `main`.
3. **Test on real hardware** — every change must be verified on your own rooted
   device before submitting. / Setiap perubahan wajib dites di device rooted
   milik sendiri sebelum disubmit.
4. **Keep commits clean** — one logical change per commit, clear message.
   / Satu perubahan logika per commit, pesan jelas.
5. **Open a Pull Request** — reference the issue, describe what changed and
   what you tested. / Referensikan issue, jelaskan yang berubah dan apa yang dites.

## Code Conventions / Konvensi Kode

- Bash (Termux): shebang `#!/data/data/com.termux/files/usr/bin/bash`
- All sysfs writes go through `swrite()` (chmod 644/444 pattern)
- No inline comments; section headers use `#` (not `//`)
- ASCII only — no Unicode box drawing (terminal Android compatibility)
- Dynamic paths via `SCRIPT_DIR` — no hardcoded paths
- INI configs: never include CVars on the Kuro forbidden list
  (deploy auto-filters, but keep sources clean)

## Bug Reports / Laporan Bug

Use the bug issue template. Always include:
/ Gunakan template bug. Selalu sertakan:

- Device model + SoC + GPU (`getprop ro.product.model`, `uname -r`)
- Android version + root solution (KernelSU/Magisk + version)
- Termux version
- Steps to reproduce / langkah reproduksi
- Relevant log output from `logs/ther_t3.log`

## Scope / Ruang Lingkup

In scope: sysfs tuning (CPU/GPU/thermal), Wuthering Waves INI configs,
Termux tooling.
Out of scope: anything requiring unlocked bootloader exploits, ToS-violating
game bypasses, paid/proprietary blobs.

/ Di luar lingkup: bypass ToS game, exploit bootloader, blob proprietary.

## License

By contributing, you agree that your contributions will be licensed under
the Apache License 2.0 that covers this project.
/ Dengan berkontribusi, kontribusimu dilisensikan di bawah Apache License 2.0.
