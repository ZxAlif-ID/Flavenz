# Security Policy / Kebijakan Keamanan

## Supported Versions / Versi yang Didukung

| Version | Supported |
| ------- | --------- |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x: |

## Reporting a Vulnerability / Melaporkan Kerentanan

- Use GitHub **Private vulnerability reporting** (Security tab → Report a
  vulnerability) — do not open a public issue.
  / Gunakan Private vulnerability reporting di tab Security — jangan buka issue publik.
- Include: affected version, device (model/SoC), reproduction steps, impact.
- Expected response time: 7 days / estimasi respon: 7 hari.

## Scope / Ruang Lingkup

In scope: privilege escalation or destructive behavior in `main.sh`/`lib/*`
(anything writing outside declared sysfs nodes or the game config directory),
injection via INI parsing, unsafe `su` usage.

/ Di dalam lingkup: eskalasi privilese, penulisan di luar node sysfs yang
dideklarasikan, injeksi via parsing INI, penggunaan `su` yang tidak aman.

Out of scope: game anti-cheat/ConfigMonitor bypass research, attacks against
Kuro Games servers, device bricking via user-modified presets applied beyond
documented values.

/ Di luar lingkup: bypass ConfigMonitor/anti-cheat, serangan ke server Kuro,
kerusakan device akibat preset yang dimodifikasi di luar nilai terdokumentasi.

## Safety Notes for Users / Catatan Keamanan Pengguna

- This tool writes to kernel sysfs nodes as root — always run `[1] Backup`
  before first use, and keep the `backup/` directory intact.
  / Tool ini menulis ke node sysfs kernel sebagai root — selalu jalankan
  `[1] Backup` sebelum pemakaian pertama, dan jaga folder `backup/`.
- Restores: menu `[R]` (full) or `[E]` (emergency).
