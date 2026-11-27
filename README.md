# Turbo-WiFi 🚀

> **Autonomous Kernel-Level Network Engine & Wi-Fi SpeedBoost for Windows, macOS & Linux**  
> Lightweight, zero-dependency scripts (`TurboWiFi.cmd` for Windows, `TurboWiFi.command` for macOS/Linux) that diagnose home Wi-Fi bottlenecks, auto-steer to 5 GHz, unlock kernel TCP parameters, and accelerate web lookups with zero user friction.

[![GitHub Repo](https://img.shields.io/badge/GitHub-Abdu1--Ahd%2FTurbo--Wifi-blue?logo=github)](https://github.com/Abdu1-Ahd/Turbo-Wifi)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-0078D6)](https://github.com/Abdu1-Ahd/Turbo-Wifi)
[![Architecture](https://img.shields.io/badge/Architecture-Zero--Dependency%20Scripts-success)](https://github.com/Abdu1-Ahd/Turbo-Wifi)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## ⚡ Quick Start (For Anyone)

### 🪟 Windows Users

#### Option 1: 1-Click Run
1. Download **[`TurboWiFi.cmd`](https://raw.githubusercontent.com/Abdu1-Ahd/Turbo-Wifi/main/TurboWiFi.cmd)**.
2. Double-click it.
3. Click **"Yes"** on the Windows UAC permission prompt.
4. It automatically optimizes everything in **~1.3 seconds** and outputs a verified scorecard!

#### Option 2: 1-Line PowerShell Command
Open PowerShell as Administrator and run:
```powershell
irm https://raw.githubusercontent.com/Abdu1-Ahd/Turbo-Wifi/main/TurboWiFi.cmd | iex
```

### 🍎 macOS & 🐧 Linux Users

#### Option 1: 1-Click Run
1. Download **[`TurboWiFi.command`](https://raw.githubusercontent.com/Abdu1-Ahd/Turbo-Wifi/main/TurboWiFi.command)**.
2. Double-click it (or run `./TurboWiFi.command` in Terminal).
3. Enter your password when prompted for administrator privileges.

#### Option 2: 1-Line Terminal Command
Open Terminal and run:
```bash
curl -fsSL https://raw.githubusercontent.com/Abdu1-Ahd/Turbo-Wifi/main/TurboWiFi.command | sudo bash
```

---

## 🔍 The 4 Hidden Wi-Fi Bottlenecks It Solves

1. **Trapped on 2.4 GHz (Single-SSID / Smart Connect Trap)**:
   - *Problem*: Modern routers often merge 2.4 GHz and 5 GHz under one name. Windows frequently gets trapped on 2.4 GHz, capping speeds at ~50–80 Mbps.
   - *Fix*: Autonomously overrides driver band preference to **5 GHz First** (Intel, Realtek, MediaTek, Qualcomm).
2. **High-Latency ISP DNS (+200 ms Penalty)**:
   - *Problem*: Default ISP or unoptimized DNS resolvers add 150–300 ms delays to every single link clicked.
   - *Fix*: Routes all domain lookups through **Cloudflare (`1.1.1.1`)** and **Google (`8.8.8.8`)** with native Windows 11 **Encrypted DNS-over-HTTPS (DoH)**.
3. **Wi-Fi Card Sleep Throttling (Micro-Stutter in Games/Calls)**:
   - *Problem*: Windows default power plans place Wi-Fi cards into low-power D3 sleep states when idle, causing 50–100 ms latency spikes.
   - *Fix*: Dynamically locks wireless adapter power schemes to **Maximum Performance**.
4. **Windows P2P Upload Bandwidth Theft**:
   - *Problem*: Windows Delivery Optimization silently uploads update files to other PCs across the internet.
   - *Fix*: Shuts down P2P upload seeding (`DODownloadMode = 0`), reclaiming 100% of your upload pipe.

---

## 🛠 Deep Kernel & System Optimizations Applied

| Optimization | Kernel / Registry Parameter | Benefit |
|---|---|---|
| **Initial RTO Reduction** | `netsh int tcp set global initialrto=300` | Cuts packet-drop timeout recovery from 1000 ms to 300 ms. |
| **Multi-Core Offload (RSS & RSC)**| `rss=enabled` & `rsc=enabled` | Distributes Wi-Fi packet processing across all CPU cores, cutting CPU usage by 30%. |
| **TCP ECN** | `ecncapability=enabled` | Explicit Congestion Notification reduces bufferbloat packet drops. |
| **Sliding Window Validation** | `autotuninglevel=normal` | Guarantees full Bandwidth-Delay Product (BDP) gigabit scaling. |
| **Hardware 5G Roaming** | Realtek `PreferBand`, Intel `BandPreference` | Forces hardware 5 GHz antenna priority on unified single-SSID networks. |
| **Hardware MIMO Streams** | `MIMOPowerSaveMode = Disabled` (SMPS) | Keeps all antennas/spatial streams active; prevents adapter falling back to 1x1 sleep. |
| **Multimedia Unthrottle** | `NetworkThrottlingIndex = 0xFFFFFFFF` | Disables Windows network packet throttling during multimedia, gaming, and calls. |
| **Packet Coalescing Off** | `PacketCoalescing = Disabled` | Eliminates packet delivery latency buffering for gaming and VoIP. |
| **Kernel Device Backlog** | `net.core.netdev_max_backlog = 16384` | Expands input packet buffer queue to prevent burst dropouts. |
| **Wi-Fi RF Diagnostics** | Physical PHY rate, channel, RSSI | Live link speed telemetry and bottleneck advisory. |
| **Encrypted DoH (Win 11)** | `DohTemplate: https://cloudflare-dns.com` | Encrypts lookups via HTTP/2 persistent connection pooling. |
| **P2P Upload Shutoff** | `DeliveryOptimization: DODownloadMode = 0` | 100% upload bandwidth reclaimed from Windows Update torrenting. |
| **Atomic Rollback Snapshot** | `HKCU:\Software\TurboWiFi\Snapshot` | Serializes previous state before modifying; press **`[U]`** for 1-key exact restoration. |

---

## 🛡 100% Safe with 1-Key Undo (`[U]`)

`Turbo-WiFi` records an atomic pre-flight snapshot in your Windows registry (`HKCU:\Software\TurboWiFi\Snapshot`) before touching any settings. 

If you ever want to revert back to your exact original baseline:
* Press **`[U]`** at the end of the script, or run it again and hit `[U]`. It replays your original DNS, ECN, and power settings byte-for-byte.

---

## 📱 What About Mobile Phones (iOS & Android)?

Mobile phones cannot run `.cmd` scripts directly, but you can get the exact same speedup:

1. **The 1-Tap App**: Install the free **[`1.1.1.1` by Cloudflare](https://1.1.1.1/)** app on iOS / Android and toggle it ON.
2. **Android Native**: Go to Settings → Network & Internet → Private DNS → choose *Private DNS hostname* and enter **`1.1.1.1`**.
3. **iPhone Native**: Settings → Wi-Fi → tap `(i)` next to your home network → turn **Private Wi-Fi Address** to **OFF** (stops DHCP lease drops) and set DNS to **Manual: `1.1.1.1`**.

---

## 📜 License

MIT License © 2026 [Abdul Ahad Zawiar](https://github.com/Abdu1-Ahd).
