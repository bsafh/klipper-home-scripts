# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A shared sync point ("master") for OrcaSlicer settings across multiple Windows client PCs (office, workshop, etc.). The directory lives on the TrueNAS server (always-on NAS). Each client PC runs a sync daemon (as a Windows scheduled task) that watches for local setting changes in OrcaSlicer, pushes them to the NAS immediately, and periodically pulls changes made on other PCs.

This keeps printer profiles, filament profiles, slicer config, and plugins consistent everywhere without manual file copying.

This is a **data/config repo** — there is no source code to build, test, or lint.

### Architecture

```
┌─────────────────────────────────────────────────────┐
│  TrueNAS Server (always on)                         │
│  ┌──────────────────────────────────────────────┐   │
│  │  /mnt/pool/data/transfer/3D-print/           │   │
│  │    OrcaSlicer-settings/   ← master copy      │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────┬───────────────────────────────┘
                      │ SMB/NFS
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌──────────────┐ ┌──────────┐ ┌──────────┐
│ Office PC    │ │Workshop  │ │ Laptop   │
│ (Windows)    │ │PC (Win)  │ │ (Win)    │
│              │ │          │ │          │
│ OrcaSlicer   │ │OrcaSlicer│ │OrcaSlicer│
│ ←sync-daemon│ │←sync-dmn │ │←sync-dmn │
│   (always on)│ │          │ │          │
│              │ │          │ │          │
│ WSL2/Claude  │ │          │ │          │
│ (optional)   │ │          │ │          │
└──────────────┘ └──────────┘ └──────────┘
```

Key points:
- The **TrueNAS server** is always on — it's the passive storage backend
- Each **client PC** runs its own sync daemon independently — these are what keep data flowing
- **WSL2 / OpenClaude** runs on one of the client PCs but is NOT part of the sync — it's just an admin environment for editing scripts, resolving conflicts, or inspecting configs
- The sync continues working whether or not WSL2 is running

## Sync Scripts

Pre-built sync daemons are in `sync-scripts/`. Install and set up on each Windows client PC.

Installation guides (detailed step-by-step):
- **Windows**: [`sync-scripts/INSTALL-WINDOWS.md`](sync-scripts/INSTALL-WINDOWS.md)
- **Linux**: [`sync-scripts/INSTALL-LINUX.md`](sync-scripts/INSTALL-LINUX.md)

### Installation: Windows

**Prerequisites:**
- NAS accessible at `\\192.168.80.17\data\transfer\3D-print\Software\OrcaSlicer-settings`
- rclone installed ([rclone.org/downloads](https://rclone.org/downloads/))
  - Download the Windows executable, extract `rclone.exe` to any folder
  - Run `rclone.exe self-upgrade` from an admin prompt, or just add the folder to PATH

**Step-by-step:**

1. Open File Explorer and go to the NAS path:
   ```
   \\192.168.80.17\data\transfer\3D-print\Software\OrcaSlicer-settings
   ```

2. Right-click on `sync-scripts\sync-orcaslicer.ps1` → "Copy", then paste into a local folder (e.g. `C:\Users\you\Documents\`).
   The script needs to run from a local path because the NAS drive letter may not be available at login time.

3. Open **PowerShell as Administrator** in that local folder.

4. Run the setup to create a scheduled task:
   ```powershell
   .\sync-orcaslicer.ps1 -NasPath "\\192.168.80.17\data\transfer\3D-print\Software\OrcaSlicer-settings" -setup
   ```
   (If the NAS is mapped to S:, you can use `-NasPath "S:\transfer\3D-print\Software\OrcaSlicer-settings"` instead.)

5. The script creates a scheduled task named `OrcaSlicerSettingsSync`. It will:
   - Auto-start on every login
   - Run hidden in the background (no window)
   - Watch for OrcaSlicer config changes and sync them
   - Log to `%TEMP%\orcaslicer-sync.log`

6. Start the service immediately without logging out:
   ```powershell
   Start-ScheduledTask -TaskName "OrcaSlicerSettingsSync"
   ```

7. Verify it's running:
   ```powershell
   Get-ScheduledTask -TaskName "OrcaSlicerSettingsSync" | Get-ScheduledTaskInfo
   ```

**Updating the script later:**
Just replace the local copy with the latest from `\\192.168.80.17\data\...\sync-scripts\sync-orcaslicer.ps1` and restart the scheduled task:
```powershell
Restart-ScheduledTask -TaskName "OrcaSlicerSettingsSync"
```

### Installation: Linux (flatpak/native)

Only needed if OrcaSlicer is installed on a Linux machine alongside Windows PCs.

**Prerequisites:**
```bash
sudo apt install rclone inotify-tools
```
The NAS must be mounted at `/srv/truenas/data/transfer/3D-print/Software/OrcaSlicer-settings/` (via SMB3 in `/etc/fstab`).

**Step-by-step:**

1. Copy the script locally:
   ```bash
   mkdir -p ~/.local/bin
   cp /srv/truenas/data/transfer/3D-print/Software/OrcaSlicer-settings/sync-scripts/sync-orcaslicer.sh ~/.local/bin/
   chmod +x ~/.local/bin/sync-orcaslicer.sh
   ```

2. Edit the config section if needed (the defaults should work on WSL2 on this PC):
   ```bash
   nano ~/.local/bin/sync-orcaslicer.sh
   # Check LOCAL_DIR and NAS_DIR are correct
   ```

3. Test the sync:
   ```bash
   ~/.local/bin/sync-orcaslicer.sh --sync-once
   ```

4. Set up auto-start via systemd user service (recommended):
   ```bash
   mkdir -p ~/.config/systemd/user
   cp /srv/truenas/data/transfer/3D-print/Software/OrcaSlicer-settings/sync-scripts/sync-orcaslicer.service ~/.config/systemd/user/
   systemctl --user enable --now sync-orcaslicer.service
   systemctl --user status sync-orcaslicer.service
   ```

5. Check the log:
   ```bash
   journalctl --user -u sync-orcaslicer.service -f
   ```

### How the sync works

- **File watcher** detects local changes (e.g., saving a profile in OrcaSlicer) triggers an immediate bidirectional sync
- **Debouncing** waits for writes to settle (5s by default) before syncing
- **Periodic sync** every 2 minutes catches changes made on other machines
- **Initial sync** runs on daemon start to pick up the latest state
- **Machine-specific files** are excluded from sync (`.orcaslicer_machine_id`, logs, cache, lock files)
- **Conflict files** (`.conflict1`, `.conflict2`) auto-generated by rclone when the same file changes on two machines — resolve manually

### Cross-platform path conversion

`OrcaSlicer.conf` contains OS-specific absolute paths (download paths, recent files, export directories).
Machine JSONs have `bed_custom_texture` paths pointing to image files on the NAS. These paths differ
between Windows (`S:\transfer\...`) and Linux (`/srv/truenas/data/transfer/...`).

The **Linux sync daemon** handles this automatically using `convert-paths.py`:

```
Pre-sync  (Linux → Windows):  /srv/truenas/...  →  S:\...
rclone bisync
Post-sync (Windows → Linux):  S:\...  →  /srv/truenas/...
```

The NAS always stores Windows paths (the native format for the majority of clients).
The converter runs JSON-aware string replacement only on known path fields, preserving
file formatting, line endings, and the MD5 checksum footer.

**Windows machines** never need conversion — they push and pull Windows paths directly.

### NAS Path Configuration

The NAS path varies by access method — edit the script's configuration for your machine:

| Access method | Path |
|---|---|
| Windows (UNC) | `\\192.168.80.17\data\transfer\3D-print\Software\OrcaSlicer-settings` |
| Windows (mapped drive) | `S:\transfer\3D-print\Software\OrcaSlicer-settings` |
| Linux/WSL2 (SMB3 mount) | `/srv/truenas/data/transfer/3D-print/Software/OrcaSlicer-settings` |
| Direct on TrueNAS | `/mnt/tank/alldata/data/transfer/3D-print/Software/OrcaSlicer-settings` |
| rsync/SSH remote path | `truenas:/mnt/tank/alldata/data/transfer/3D-print/Software/OrcaSlicer-settings` |

The sync daemon scripts use the **UNC paths** (Windows) or **SMB3 mount path** (Linux/WSL2). The TrueNAS-local and rsync paths are for direct admin access, manual conflict resolution, or alternative sync setups.

## Repository Structure

```
.
├── OrcaSlicer.conf              # Main OrcaSlicer application config (JSON, 2623 lines)
├── BambuNetworkEngine.conf      # Bambu network engine config (binary/encrypted)
├── .orcaslicer_machine_id       # Machine UUID (f9e28ba5-...)
├── rclone.txt                   # Rclone sync instructions
├── RCLONE_TEST                  # Sync health check file (empty)
├── sync.ffs_db                  # FreeFileSync database
├── Thumbs.db                    # Windows thumbnail cache
│
├── printers/                    # Printer definitions (JSON) + gcode macros
│   ├── version.txt              # Printer profile version (02.00.00.29)
│   ├── BL-P001.json, BL-P002.json, C11.json, etc.
│   ├── filaments_blacklist.json
│   ├── ams_load.gcode / ams_unload.gcode
│
├── system/                      # Vendor system profiles (bundled defaults)
│   ├── BBL/                     # Bambu Lab (filament/machine/process)
│   ├── Custom/                  # Custom/Generic (filament/machine/process + machine JSONs)
│   ├── Geeetech/                # Geeetech (machine/process)
│   ├── Tronxy/                  # Tronxy (machine/process + filament JSONs)
│   ├── Snapmaker/               # Snapmaker (filament/machine/process)
│   ├── Sovol/                   # Sovol (filament/machine/process)
│   ├── Voron/                   # Voron (machine/process)
│   ├── WonderMaker/             # WonderMaker (filament/machine/process)
│   ├── OrcaFilamentLibrary/     # Orca Filament Library (filament + .json index)
│   ├── Custom.json              # Custom vendor index
│   ├── Geeetech.json            # Geeetech vendor index
│   ├── OrcaFilamentLibrary.json # Filament library index
│   └── Tronxy.json              # Tronxy vendor index
│
├── user/                        # User-specific settings
│   ├── 321606540/               # User profile (filament/machine/process/postprocessing/orca-settings-linux)
│   └── default/                 # Default user profile (filament/machine/process)
│
├── user_backup-v2.3.2/          # Backup from OrcaSlicer v2.3.2
│
├── sync-scripts/                 # Sync daemon scripts for Windows and Linux
│   ├── INSTALL-WINDOWS.md        # Windows installation guide
│   ├── INSTALL-LINUX.md          # Linux installation guide
│   ├── sync-orcaslicer.sh        # Linux daemon (inotifywait + rclone bisync)
│   ├── sync-orcaslicer.ps1       # Windows daemon (FileSystemWatcher + rclone bisync)
│   ├── sync-orcaslicer.service   # systemd user service unit for Linux
│   └── convert-paths.py          # Cross-platform path converter (Linux only)
│
├── plugins/                     # Plugin DLLs/SOs for network, RTC, live streaming
│   ├── bambu_networking_*.dll / libbambu_networking.so
│   ├── BambuSource.dll / libBambuSource.so
│   ├── agora_rtc_sdk.dll / libagora-*.dll
│   └── live555.dll / liblive555.so
│
├── cache/                       # OrcaSlicer cache (lock files, fonts.cereal)
├── hms/                         # Printer HMS (Handy Management System) error messages (JSON)
├── log/                         # OrcaSlicer debug logs (text + encrypted network logs)
├── ota/                         # OTA update files (currently empty)
│
├── _sf/                         # FreeFileSync shadow/trash directory
│
├── klipper_geeetech_logo.png/.xcf  # Klipper screen logos
├── klipper_tronxy_logo.png/.xcf
│
└── conflict1 / conflict2 files  # Rclone sync conflict resolution duplicates
```

## Key Notes

- **Conflict files** (`.conflict1`, `.conflict2`) appear when rclone bisync detects changes on both sides. These need manual resolution — compare and merge, then remove the conflict copies.
- **User profile ID `321606540`** is the active user. `default/` is the fallback.
- **`user_backup-v2.3.2/`** is a snapshot from a previous OrcaSlicer version for reference.
- **Debug logs** (`log/debug_*.log.0`) and encrypted network logs (`log/debug_network_*.log.enc`) are ephemeral — fine to clean up.
- **`_sf/`** contains FreeFileSync trash (deleted files from previous syncs).
- **`system/`** vendor index JSON files (e.g., `Tronxy.json`) contain metadata about which profiles belong to which vendor, used for display in OrcaSlicer's configuration UI.
