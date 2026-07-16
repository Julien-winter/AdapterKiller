# Adapter Killer v3.0

> A Windows PowerShell tool to disable, uninstall, and eject network adapters, USB drives, printers, and more.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-informational?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

## Preview

```
==========================================
         ADAPTER KILLER v3.0
==========================================

  [1] DISABLE all network adapters
  [2] UNINSTALL all network adapters (PnP)
  [3] INTERACTIVE - pick what to kill
  [4] Restore adapters from backup
  [5] Detailed list
  [6] Help
  [7] Exit

Choice (1-7):
```

## Features

| # | Action | Description |
|---|--------|-------------|
| 1 | **Disable All** | Disables every visible network adapter (safe, reversible) |
| 2 | **Uninstall All (PnP)** | Truly uninstalls all network PnP devices via `pnputil /remove-device` |
| 3 | **Interactive Kill** | Shows a numbered list of all targets – you pick exactly what to destroy |
| 4 | **Restore** | Re-enables adapters from a saved backup XML |
| 5 | **Detailed List** | Full overview of NetAdapters, PnP devices, Bluetooth, and printers |

## Interactive Kill (Menu 3)

The interactive mode scans multiple sources and lets you choose:

```
--- NETWORK ADAPTERS (Get-NetAdapter) ---
  1. Ethernet | Realtek ... | Disconnected
  2. WLAN | RZ616 ... | Up
--- PNP NETWORK DEVICES (Get-PnpDevice -Class Net) ---
  3. Microsoft Wi-Fi Direct Virtual Adapter #3
  4. Remote NDIS Compatible Device
--- USB STORAGE (Get-Disk -BusType USB) ---
  5. USB: SanDisk Extreme (120.00 GB)
--- PRINTERS (Get-Printer) ---
  6. Microsoft Print to PDF
```

Enter numbers (comma/space separated) or `ALL` to select everything.

> Bluetooth devices are always skipped and kept safe.

## How backups work

- Backups are created automatically when using [1] or [3] (only for NetAdapters being disabled)
- Stored as `adapter_backup.xml` in the same folder as the script
- Use [4] Restore to re-enable all adapters from the last backup

## Requirements

- Windows 10 / 11 (or Windows Server 2016+)
- **Administrator rights** (required for all operations)
- PowerShell 5.1 or later

## Usage

1. **Double-click** `AdapterKiller.cmd` (auto-elevates to admin)
2. Or run directly in an **admin PowerShell**:
   ```powershell
   .\AdapterKiller.ps1
   ```

## Installation

```powershell
# Clone the repo
git clone https://github.com/Julien-winter/AdapterKiller.git
cd AdapterKiller

# Or just download the two files:
# - AdapterKiller.cmd
# - AdapterKiller.ps1
```

Put them anywhere – desktop, USB stick, doesn't matter.

## Notes

- **Physical adapters** are disabled (not removed) – safe and reversible
- **Virtual adapters** (Hyper-V, WSL, VPN, etc.) are removed via `Remove-NetAdapter`
- **PnP devices** are uninstalled via `pnputil /remove-device`
- **USB drives** are ejected (dismounted + set offline)
- **Printers** are removed via `Remove-Printer`
- On reboot, Windows may reinstall some drivers automatically
