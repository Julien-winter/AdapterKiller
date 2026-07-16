param (
    [switch]$Restore,
    [switch]$ListOnly,
    [switch]$Help
)

$ErrorActionPreference = "Continue"
$backupFile = "$env:USERPROFILE\Desktop\AdapterKiller\adapter_backup.xml"

function Show-Banner {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "         ADAPTER KILLER v3.0               " -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Show-Banner
    Write-Host "  [1] DISABLE all network adapters" -ForegroundColor Yellow
    Write-Host "  [2] UNINSTALL all network adapters (PnP)" -ForegroundColor Red
    Write-Host "  [3] INTERACTIVE - pick what to kill" -ForegroundColor Magenta
    Write-Host "  [4] Restore adapters from backup" -ForegroundColor Green
    Write-Host "  [5] Detailed list (adapters + PnP + BT + printers)" -ForegroundColor Cyan
    Write-Host "  [6] Help" -ForegroundColor Gray
    Write-Host "  [7] Exit" -ForegroundColor Gray
    Write-Host ""
    $choice = Read-Host "Choice (1-7)"
    return $choice
}

function Get-AllAdapters { Get-NetAdapter | Sort-Object Name }
function Get-PnpNet { Get-PnpDevice -Class Net -ErrorAction SilentlyContinue | Sort-Object FriendlyName }
function Get-PnpBluetooth { Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Sort-Object FriendlyName }
function Get-AllPrinters { Get-Printer -ErrorAction SilentlyContinue | Sort-Object Name }

function Backup-Adapters {
    param($Adapters)
    $backup = $Adapters | Select-Object Name, InterfaceDescription, Status, MacAddress
    $backup | Export-Clixml -Path $backupFile -Force
    Write-Host "  Backup saved -> $backupFile" -ForegroundColor Green
}

function Confirm-Destruction {
    param([string]$ActionText)
    Write-Host ""
    Write-Host "!!! WARNING: $ActionText !!!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Are you sure? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Green
        return $false
    }
    return $true
}

function Write-Result {
    param($Ok, $Fail)
    Write-Host ""
    Write-Host "Success: $Ok  |  Failed: $Fail" -ForegroundColor Cyan
    pause
}

function Disable-PnpDeviceById {
    param($InstanceId)
    try {
        & pnputil /remove-device $InstanceId 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return "UNINSTALLED" }
        Disable-PnpDevice -InstanceId $InstanceId -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        return "DISABLED"
    } catch {
        return $null
    }
}

# ====== 1: DISABLE ALL ======
function Action-DisableAll {
    Show-Banner
    Write-Host "== DISABLE ALL ADAPTERS ==" -ForegroundColor Yellow
    Write-Host ""

    $adapters = Get-AllAdapters
    if ($adapters.Count -eq 0) { Write-Host "No adapters found." -ForegroundColor Green; pause; return }

    $adapters | Select-Object Name, InterfaceDescription, Status, LinkSpeed | Format-Table -AutoSize
    Backup-Adapters $adapters

    if (-not (Confirm-Destruction "ALL adapters will be DISABLED - no internet!")) { return }

    $ok = 0; $fail = 0
    foreach ($a in $adapters) {
        Write-Host "  -> $($a.Name) ... " -NoNewline
        try { Disable-NetAdapter -Name $a.Name -Confirm:$false; Write-Host "DISABLED" -ForegroundColor Red; $ok++ }
        catch { Write-Host "FAILED" -ForegroundColor DarkRed; $fail++ }
    }
    Write-Result $ok $fail
}

# ====== 2: UNINSTALL ALL (PnP) ======
function Action-UninstallAll {
    Show-Banner
    Write-Host "== UNINSTALL ALL NETWORK ADAPTERS (PnP) ==" -ForegroundColor Red
    Write-Host ""

    $devices = Get-PnpNet
    if ($devices.Count -eq 0) { Write-Host "No PnP network devices." -ForegroundColor Green; pause; return }

    $devices | Select-Object FriendlyName, Class, Status, InstanceId | Format-Table -AutoSize
    $adapters = Get-AllAdapters; if ($adapters) { Backup-Adapters $adapters }

    if (-not (Confirm-Destruction "ALL network adapters will be UNINSTALLED - drivers gone!")) { return }

    $ok = 0; $fail = 0
    foreach ($dev in $devices) {
        Write-Host "  -> $($dev.FriendlyName) ... " -NoNewline
        $result = Disable-PnpDeviceById $dev.InstanceId
        if ($result) { Write-Host $result -ForegroundColor Red; $ok++ }
        else { Write-Host "FAILED" -ForegroundColor DarkRed; $fail++ }
    }
    Write-Result $ok $fail
}

# ====== 3: INTERACTIVE KILL ======
function Action-InteractiveKill {
    Show-Banner
    Write-Host "== INTERACTIVE KILL - pick your targets ==" -ForegroundColor Magenta
    Write-Host ""

    $netAdapters = Get-AllAdapters
    $pnpNet = Get-PnpNet
    $printers = Get-AllPrinters

    $candidates = @()
    $index = 1

    Write-Host "--- NETWORK ADAPTERS (Get-NetAdapter) ---" -ForegroundColor Cyan
    foreach ($a in $netAdapters) {
        if ($a.InterfaceDescription -match "(?i)bluetooth") {
            Write-Host "  $index. [SKIPPED - BLUETOOTH] $($a.Name)" -ForegroundColor DarkGray
        } else {
            Write-Host "  $index. $($a.Name) | $($a.InterfaceDescription) | Status: $($a.Status) | Speed: $($a.LinkSpeed)" -ForegroundColor Yellow
            $candidates += @{ Type="NetAdapter"; Object=$a; Index=$index; Name="$($a.Name) | $($a.InterfaceDescription)" }
        }
        $index++
    }

    Write-Host "--- PNP NETWORK DEVICES (Get-PnpDevice -Class Net) ---" -ForegroundColor Cyan
    foreach ($p in $pnpNet) {
        if ($p.FriendlyName -match "(?i)bluetooth") {
            Write-Host "  $index. [SKIPPED - BLUETOOTH] $($p.FriendlyName)" -ForegroundColor DarkGray
        } else {
            Write-Host "  $index. [PnP] $($p.FriendlyName) | Status: $($p.Status)" -ForegroundColor Yellow
            $candidates += @{ Type="PnpDevice"; Object=$p; Index=$index; Name="$($p.FriendlyName) [PnP]" }
        }
        $index++
    }

    Write-Host "--- PRINTERS (Get-Printer) ---" -ForegroundColor Cyan
    foreach ($pr in $printers) {
        Write-Host "  $index. [PRINTER] $($pr.Name) | Type: $($pr.Type)" -ForegroundColor Yellow
        $candidates += @{ Type="Printer"; Object=$pr; Index=$index; Name="Printer: $($pr.Name)" }
        $index++
    }

    Write-Host ""
    if ($candidates.Count -eq 0) {
        Write-Host "Nothing to kill. System is clean!" -ForegroundColor Green
        pause; return
    }

    Write-Host "Enter numbers to KILL (comma/space separated, e.g. '1,3,5' or '1 3 5')" -ForegroundColor Magenta
    Write-Host "Enter 'ALL' to select everything above" -ForegroundColor Magenta
    $input = Read-Host ">> "

    $selected = @()
    if ($input -eq "ALL") {
        $selected = $candidates
    } else {
        $nums = $input -split '[\s,;]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        foreach ($n in $nums) {
            $match = $candidates | Where-Object { $_.Index -eq $n }
            if ($match) { $selected += $match }
        }
    }

    if ($selected.Count -eq 0) {
        Write-Host "No valid selections. Aborted." -ForegroundColor Yellow
        pause; return
    }

    Write-Host ""
    Write-Host "Selected for destruction ($($selected.Count) items):" -ForegroundColor Red
    $selected | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Red }
    Write-Host ""

    # Backup NetAdapters that will be disabled
    $netToKill = $selected | Where-Object { $_.Type -eq "NetAdapter" } | ForEach-Object { $_.Object }
    if ($netToKill) { Backup-Adapters $netToKill }

    if (-not (Confirm-Destruction "$($selected.Count) items will be destroyed")) { return }

    $ok = 0; $fail = 0
    foreach ($item in $selected) {
        switch ($item.Type) {
            "NetAdapter" {
                $a = $item.Object
                Write-Host "  -> $($a.Name) ($($a.InterfaceDescription)) ... " -NoNewline
                $isVirtual = $a.InterfaceDescription -match "(?i)virtual|hyper.v|wsl|vmware|virtualbox|loopback|vpn|tunnel"
                try {
                    if ($isVirtual) {
                        Remove-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction SilentlyContinue
                        if ($?) { Write-Host "REMOVED" -ForegroundColor Red; $ok++; continue }
                    }
                    Disable-NetAdapter -Name $a.Name -Confirm:$false
                    Write-Host "DISABLED" -ForegroundColor Yellow; $ok++
                } catch { Write-Host "FAILED" -ForegroundColor DarkRed; $fail++ }
            }
            "PnpDevice" {
                $p = $item.Object
                Write-Host "  -> $($p.FriendlyName) ... " -NoNewline
                $result = Disable-PnpDeviceById $p.InstanceId
                if ($result) { Write-Host $result -ForegroundColor Red; $ok++ }
                else { Write-Host "FAILED" -ForegroundColor DarkRed; $fail++ }
            }
            "Printer" {
                $pr = $item.Object
                Write-Host "  -> Printer: $($pr.Name) ... " -NoNewline
                try { Remove-Printer -Name $pr.Name -Confirm:$false; Write-Host "REMOVED" -ForegroundColor Red; $ok++ }
                catch { Write-Host "FAILED" -ForegroundColor DarkRed; $fail++ }
            }
        }
    }

    Write-Result $ok $fail
}

# ====== 4: RESTORE ======
function Action-Restore {
    Show-Banner
    Write-Host "== RESTORE ADAPTERS ==" -ForegroundColor Green
    Write-Host ""

    if (-not (Test-Path $backupFile)) {
        Write-Host "No backup found: $backupFile" -ForegroundColor Red
        pause; return
    }

    $backup = Import-Clixml -Path $backupFile
    $ok = 0; $fail = 0

    foreach ($entry in $backup) {
        $existing = Get-NetAdapter -Name $entry.Name -ErrorAction SilentlyContinue
        if (-not $existing) {
            Write-Host "  -> $($entry.Name) (not found, reinstall drivers?)" -ForegroundColor DarkYellow
            continue
        }
        try { Enable-NetAdapter -Name $entry.Name -Confirm:$false; Write-Host "  [OK]  $($entry.Name)" -ForegroundColor Green; $ok++ }
        catch { Write-Host "  [FAIL] $($entry.Name)" -ForegroundColor DarkRed; $fail++ }
    }

    Write-Host ""
    Write-Host "Restored: $ok" -ForegroundColor Green
    if ($fail -gt 0) { Write-Host "Failed: $fail" -ForegroundColor DarkRed }
    if ($ok -eq 0 -and $fail -eq 0) { Write-Host "Nothing to restore (drivers completely missing)." -ForegroundColor Yellow }
    pause
}

# ====== 5: DETAILED LIST ======
function Action-List {
    Show-Banner
    Write-Host "== FULL OVERVIEW ==" -ForegroundColor Cyan

    $net = Get-AllAdapters
    $pnpNet = Get-PnpNet
    $pnpBt = Get-PnpBluetooth
    $printers = Get-AllPrinters

    Write-Host ""
    Write-Host "--- ADAPTERS (Get-NetAdapter) ---" -ForegroundColor Cyan
    if ($net) { $net | Select-Object Name, InterfaceDescription, Status, LinkSpeed | Format-Table -AutoSize }
    else { Write-Host "  (none)" -ForegroundColor Gray }

    Write-Host "--- PNP NETWORK (Get-PnpDevice -Class Net) ---" -ForegroundColor Cyan
    if ($pnpNet) { $pnpNet | Select-Object FriendlyName, Class, Status, InstanceId | Format-Table -AutoSize }
    else { Write-Host "  (none)" -ForegroundColor Gray }

    Write-Host "--- PNP BLUETOOTH (Get-PnpDevice -Class Bluetooth) ---" -ForegroundColor Cyan
    if ($pnpBt) { $pnpBt | Select-Object FriendlyName, Class, Status, InstanceId | Format-Table -AutoSize }
    else { Write-Host "  (none)" -ForegroundColor Gray }

    Write-Host "--- PRINTERS (Get-Printer) ---" -ForegroundColor Cyan
    if ($printers) { $printers | Select-Object Name, PrinterStatus, Type | Format-Table -AutoSize }
    else { Write-Host "  (none)" -ForegroundColor Gray }

    Write-Host ""
    Write-Host "Adapters: $(($net).Count)  |  PnP-Net: $(($pnpNet).Count)  |  PnP-BT: $(($pnpBt).Count)  |  Printers: $(($printers).Count)" -ForegroundColor Cyan
    pause
}

# ====== HELP ======
function Action-Help {
    Show-Banner
    Write-Host "ADAPTER KILLER v3.0" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Disable All" -ForegroundColor Yellow
    Write-Host "    Disables all visible NetAdapters (safe)." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] Uninstall All (PnP)" -ForegroundColor Red
    Write-Host "    Truly uninstalls ALL network PnP devices" -ForegroundColor Gray
    Write-Host "    via pnputil /remove-device. May reappear on reboot." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Interactive Kill" -ForegroundColor Magenta
    Write-Host "    Choose EXACTLY what to destroy from a numbered list." -ForegroundColor Gray
    Write-Host "    Enter numbers (comma/space) or 'ALL'." -ForegroundColor Gray
    Write-Host "    Bluetooth devices are NEVER listed (kept safe)." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] Restore" -ForegroundColor Green
    Write-Host "    Re-enable adapters from backup." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [5] Detailed List" -ForegroundColor Cyan
    Write-Host "    Full overview without changing anything." -ForegroundColor Gray
    Write-Host ""
    Write-Host "ADMIN RIGHTS REQUIRED!" -ForegroundColor Red
    pause
}

# ====== MAIN ======
if ($Help) { Action-Help; exit }
if ($Restore) { Action-Restore; exit }
if ($ListOnly) { Action-List; exit }

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Admin rights required!" -ForegroundColor Red
    pause; exit
}

while ($true) {
    $c = Show-Menu
    switch ($c) {
        "1" { Action-DisableAll }
        "2" { Action-UninstallAll }
        "3" { Action-InteractiveKill }
        "4" { Action-Restore }
        "5" { Action-List }
        "6" { Action-Help }
        "7" { exit }
        default { Write-Host "Invalid!" -ForegroundColor Red; Start-Sleep 1 }
    }
}
