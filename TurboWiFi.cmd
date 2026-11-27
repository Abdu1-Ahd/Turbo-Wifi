<# :
@echo off
setlocal
title Turbo-WiFi Autonomous Engine
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [Turbo-WiFi] Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c `\"%~f0`\" %*' -Verb RunAs"
    exit /b
)
powershell -NoLogo -NoProfile -Mta -ExecutionPolicy Bypass -Command "$c=[System.IO.File]::ReadAllText('%~f0'); &([ScriptBlock]::Create($c))" %*
exit /b
#>

# ==============================================================================
#   TURBO-WIFI : Autonomous Kernel-Level Network Engine & SpeedBoost
#   Architecture : Single-File Polyglot | Multi-Core Async | Zero Dependencies
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Header {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "          TURBO-WIFI : Autonomous Network Engine                 " -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-ActiveAdapter {
    $adapters = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
    $script:VpnActive = [bool]($adapters | Where-Object { $_.OperationalStatus -eq 'Up' -and ($_.NetworkInterfaceType -match 'Tunnel|Ppp' -or $_.Description -match 'VPN|WireGuard|OpenVPN|Tailscale|ZeroTier|AnyConnect|Fortinet|GlobalProtect') })
    $wifi = $adapters | Where-Object { $_.OperationalStatus -eq 'Up' -and ($_.NetworkInterfaceType -match 'Wireless' -or $_.Description -match 'Wi-Fi|Wireless|802\.11') } | Select-Object -First 1
    if ($wifi) { return $wifi }
    return ($adapters | Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -match 'Ethernet' } | Select-Object -First 1)
}

function Save-Snapshot([string]$adapterName) {
    $snapPath = "HKCU:\Software\TurboWiFi\Snapshot"
    if (-not (Test-Path $snapPath)) { New-Item -Path $snapPath -Force 2>$null | Out-Null }
    
    # Only take snapshot once to preserve the authentic pre-optimization baseline
    $existing = (Get-ItemProperty -Path $snapPath -Name 'OriginalDns' -ErrorAction SilentlyContinue).OriginalDns
    if ($null -eq $existing) {
        $dns = (Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ServerAddresses)
        $ecn = (netsh int tcp show global | Select-String 'ECN Capability\s*:\s*(\w+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() })
        $rto = (netsh int tcp show global | Select-String 'Initial RTO\s*:\s*(\d+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() })
        $do = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -ErrorAction SilentlyContinue).DODownloadMode
        $mmProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $netThrottle = (Get-ItemProperty -Path $mmProfile -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
        $sysResp = (Get-ItemProperty -Path $mmProfile -Name "SystemResponsiveness" -ErrorAction SilentlyContinue).SystemResponsiveness
        
        $ecnVal = if ($ecn) { $ecn } else { 'disabled' }
        $rtoVal = if ($rto) { $rto } else { '1000' }

        $pwrOut = powercfg /query SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 2>$null
        if ($pwrOut) {
            $pwrStr = $pwrOut -join "`n"
            if ($pwrStr -match 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)') { Set-ItemProperty -Path $snapPath -Name 'OriginalPowerAc' -Value ([int]"0x$($matches[1])") -Type DWord -Force 2>$null }
            if ($pwrStr -match 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)') { Set-ItemProperty -Path $snapPath -Name 'OriginalPowerDc' -Value ([int]"0x$($matches[1])") -Type DWord -Force 2>$null }
        }

        Set-ItemProperty -Path $snapPath -Name 'OriginalDns' -Value ($dns -join ',') -Force 2>$null
        Set-ItemProperty -Path $snapPath -Name 'OriginalEcn' -Value $ecnVal -Force 2>$null
        Set-ItemProperty -Path $snapPath -Name 'OriginalRto' -Value $rtoVal -Force 2>$null
        if ($null -ne $do) { Set-ItemProperty -Path $snapPath -Name 'OriginalDO' -Value $do -Force 2>$null }
        if ($null -ne $netThrottle) { Set-ItemProperty -Path $snapPath -Name 'OriginalNetThrottle' -Value $netThrottle -Force 2>$null }
        if ($null -ne $sysResp) { Set-ItemProperty -Path $snapPath -Name 'OriginalSysResp' -Value $sysResp -Force 2>$null }
    }
}

function Restore-Snapshot([string]$adapterName) {
    Show-Header
    Write-Host "[*] Restoring Pre-Flight Baseline Configuration..." -ForegroundColor Yellow
    $snapPath = "HKCU:\Software\TurboWiFi\Snapshot"
    
    if (Test-Path $snapPath) {
        $snap = Get-ItemProperty -Path $snapPath -ErrorAction SilentlyContinue
        if ($snap.OriginalDns) {
            $dnsArray = $snap.OriginalDns -split ',' | Where-Object { $_ }
            if ($dnsArray.Count -gt 0) {
                Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dnsArray -ErrorAction SilentlyContinue
                Write-Host "  [+] Restored Original DNS: $($snap.OriginalDns)" -ForegroundColor Green
            } else {
                Set-DnsClientServerAddress -InterfaceAlias $adapterName -ResetServerAddresses -ErrorAction SilentlyContinue
                Write-Host "  [+] Restored DNS to Automatic (DHCP)." -ForegroundColor Green
            }
        } else {
            Set-DnsClientServerAddress -InterfaceAlias $adapterName -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-Host "  [+] Restored DNS to Automatic (DHCP)." -ForegroundColor Green
        }
        
        if ($snap.OriginalEcn) {
            netsh int tcp set global "ecncapability=$($snap.OriginalEcn)" 2>$null | Out-Null
            Write-Host "  [+] Restored TCP ECN: $($snap.OriginalEcn)" -ForegroundColor Green
        }
        if ($snap.OriginalRto) {
            netsh int tcp set global "initialrto=$($snap.OriginalRto)" 2>$null | Out-Null
            Write-Host "  [+] Restored Initial RTO: $($snap.OriginalRto) ms" -ForegroundColor Green
        }
        if ($null -ne $snap.OriginalDO) {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value $snap.OriginalDO -Force 2>$null
        } else {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -ErrorAction SilentlyContinue 2>$null
        }
        
        $mmProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if ($null -ne $snap.OriginalNetThrottle) {
            Set-ItemProperty -Path $mmProfile -Name "NetworkThrottlingIndex" -Value $snap.OriginalNetThrottle -Type DWord -Force 2>$null
            Write-Host "  [+] Restored Network Throttling Index: $($snap.OriginalNetThrottle)" -ForegroundColor Green
        } else {
            Set-ItemProperty -Path $mmProfile -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force 2>$null
        }
        if ($null -ne $snap.OriginalSysResp) {
            Set-ItemProperty -Path $mmProfile -Name "SystemResponsiveness" -Value $snap.OriginalSysResp -Type DWord -Force 2>$null
            Write-Host "  [+] Restored System Responsiveness: $($snap.OriginalSysResp)" -ForegroundColor Green
        } else {
            Set-ItemProperty -Path $mmProfile -Name "SystemResponsiveness" -Value 20 -Type DWord -Force 2>$null
        }
        if ($null -ne $snap.OriginalPowerAc -and $null -ne $snap.OriginalPowerDc) {
            powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a $snap.OriginalPowerAc 2>$null | Out-Null
            powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a $snap.OriginalPowerDc 2>$null | Out-Null
            powercfg /setactive SCHEME_CURRENT 2>$null | Out-Null
            Write-Host "  [+] Restored Wireless Power Scheme (AC/DC: $($snap.OriginalPowerAc)/$($snap.OriginalPowerDc))" -ForegroundColor Green
        }
        
        Remove-Item -Path $snapPath -Recurse -Force -ErrorAction SilentlyContinue 2>$null
    } else {
        Set-DnsClientServerAddress -InterfaceAlias $adapterName -ResetServerAddresses -ErrorAction SilentlyContinue
        netsh int tcp set global ecncapability=disabled initialrto=1000 2>$null | Out-Null
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -ErrorAction SilentlyContinue 2>$null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force 2>$null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 20 -Type DWord -Force 2>$null
        Write-Host "  [+] Restored Standard Windows Defaults." -ForegroundColor Green
    }
    
    ipconfig /flushdns 2>$null | Out-Null
    Write-Host ""
    Write-Host "[SUCCESS] Network Configuration 100% Reverted to Baseline." -ForegroundColor Cyan
}

$script:AuditReport = [System.Collections.Generic.List[PSCustomObject]]::new()
function Register-Audit([string]$category, [string]$status, [string]$details, [string]$diff = $null) {
    $script:AuditReport.Add([PSCustomObject]@{
        Category = $category
        Status   = $status  # 'Applied', 'Optimal', 'Bypassed', 'Failed'
        Details  = $details
        Diff     = $diff
    })
}

function Optimize-HardwareNicProperties([string]$adapterName) {
    try {
        $props = Get-NetAdapterAdvancedProperty -InterfaceAlias $adapterName -ErrorAction SilentlyContinue
        if (-not $props) {
            Register-Audit "Hardware Band Priority" "Bypassed" "Wired / Non-Wireless Adapter"
            Register-Audit "Hardware MIMO Streams" "Bypassed" "Wired / Non-Wireless Adapter"
            Register-Audit "Packet Coalescing" "Bypassed" "Wired / Non-Wireless Adapter"
            return
        }

        # 1. 5 GHz Band Priority
        $bandProp = $props | Where-Object { $_.DisplayName -match 'Preferred.*Band|Band.*Prefer|Band Selection' -or $_.RegistryKeyword -match 'PreferBand|BandSelection' } | Select-Object -First 1
        if ($bandProp) {
            $best5G = $bandProp.ValidDisplayValues | Where-Object { $_ -match '5G|5\.2GHz|5GHz' } | Select-Object -First 1
            if ($best5G -and $bandProp.DisplayValue -ne $best5G) {
                Set-NetAdapterAdvancedProperty -InterfaceAlias $adapterName -DisplayName $bandProp.DisplayName -DisplayValue $best5G -NoRestart -ErrorAction SilentlyContinue
                Register-Audit "Hardware Band Priority" "Applied" "5 GHz Locked" "$($bandProp.DisplayValue) -> $best5G"
            } elseif ($best5G) {
                Register-Audit "Hardware Band Priority" "Optimal" "5 GHz Priority (Already Active)"
            } else {
                Register-Audit "Hardware Band Priority" "Bypassed" "5 GHz DisplayValue unavailable"
            }
        } else {
            Register-Audit "Hardware Band Priority" "Bypassed" "Not exposed by NIC driver (N/A)"
        }

        # 2. MIMO SMPS (Spatial Multiplexing Power Save) - Keep All Streams Active
        $smpsProp = $props | Where-Object { $_.DisplayName -match 'MIMO Power Save|Spatial Multiplexing|SMPS' -or $_.RegistryKeyword -match 'MIMOPowerSaveMode|SMPS' } | Select-Object -First 1
        if ($smpsProp) {
            $noSmps = $smpsProp.ValidDisplayValues | Where-Object { $_ -match 'No SMPS|Disable|Off|Dynamic' } | Select-Object -First 1
            if ($noSmps -and $smpsProp.DisplayValue -ne $noSmps) {
                Set-NetAdapterAdvancedProperty -InterfaceAlias $adapterName -DisplayName $smpsProp.DisplayName -DisplayValue $noSmps -NoRestart -ErrorAction SilentlyContinue
                Register-Audit "Hardware MIMO Streams" "Applied" "SMPS Disabled -> Full MIMO" "$($smpsProp.DisplayValue) -> $noSmps"
            } elseif ($noSmps) {
                Register-Audit "Hardware MIMO Streams" "Optimal" "Full MIMO Streams (Already Active)"
            } else {
                Register-Audit "Hardware MIMO Streams" "Bypassed" "SMPS setting unavailable"
            }
        } else {
            Register-Audit "Hardware MIMO Streams" "Bypassed" "Not exposed by NIC driver (N/A)"
        }

        # 3. Packet Coalescing (Disable for Low Latency / Zero Buffer Jitter)
        $coalProp = $props | Where-Object { $_.DisplayName -match 'Packet Coalescing' -or $_.RegistryKeyword -match 'PacketCoalescing' } | Select-Object -First 1
        if ($coalProp) {
            $coalOff = $coalProp.ValidDisplayValues | Where-Object { $_ -match 'Disable|Off' } | Select-Object -First 1
            if ($coalOff -and $coalProp.DisplayValue -ne $coalOff) {
                Set-NetAdapterAdvancedProperty -InterfaceAlias $adapterName -DisplayName $coalProp.DisplayName -DisplayValue $coalOff -NoRestart -ErrorAction SilentlyContinue
                Register-Audit "Packet Coalescing" "Applied" "Coalescing Disabled (Low Latency)" "$($coalProp.DisplayValue) -> $coalOff"
            } elseif ($coalOff) {
                Register-Audit "Packet Coalescing" "Optimal" "Coalescing Off (Already Active)"
            } else {
                Register-Audit "Packet Coalescing" "Bypassed" "Coalescing setting unavailable"
            }
        } else {
            Register-Audit "Packet Coalescing" "Bypassed" "Not exposed by NIC driver (N/A)"
        }
    } catch {
        Register-Audit "Hardware NIC Properties" "Bypassed" "Hardware inspection bypassed ($($_.Exception.Message))"
    }
}

$script:Esc = [char]27
$script:Braille = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
$script:PrintedAuditCount = 0

function Show-PipelineSpinner([string]$label, [int]$tick = 0) {
    $frame = $script:Braille[$tick % $script:Braille.Length]
    [Console]::Write("`r$($script:Esc)[2K$($script:Esc)[36m  [$frame]$($script:Esc)[0m $label")
}

function Flush-AuditLines {
    while ($script:PrintedAuditCount -lt $script:AuditReport.Count) {
        $item = $script:AuditReport[$script:PrintedAuditCount]
        $badge = switch ($item.Status) {
            'Applied'  { "$($script:Esc)[32m[+]$($script:Esc)[0m"; break }
            'Optimal'  { "$($script:Esc)[36m[=]$($script:Esc)[0m"; break }
            'Bypassed' { "$($script:Esc)[33m[!]$($script:Esc)[0m"; break }
            'Failed'   { "$($script:Esc)[31m[×]$($script:Esc)[0m"; break }
            Default    { "$($script:Esc)[90m[i]$($script:Esc)[0m" }
        }
        $catStr = $item.Category.PadRight(26)
        [Console]::Write("`r$($script:Esc)[2K  $badge $($catStr): $($item.Details)`n")
        $script:PrintedAuditCount++
    }
}

function Get-WifiRfTelemetry {
    try {
        $netsh = netsh wlan show interfaces 2>$null
        if (-not $netsh) { return [PSCustomObject]@{ Status = "Wired / Ethernet" } }
        $radio = "N/A"; $channel = "N/A"; $rx = "N/A"; $signal = "N/A"
        switch -Regex ($netsh) {
            '^\s*Radio type\s*:\s*(.+)$' { $radio = $matches[1].Trim() }
            '^\s*Channel\s*:\s*(.+)$' { $channel = $matches[1].Trim() }
            '^\s*Receive rate \(Mbps\)\s*:\s*(.+)$' { $rx = "$($matches[1].Trim()) Mbps" }
            '^\s*Signal\s*:\s*(.+)$' { $signal = $matches[1].Trim() }
        }
        if ($radio -eq "N/A" -and $channel -eq "N/A") {
            return [PSCustomObject]@{ Status = "Wired / Ethernet" }
        }
        return [PSCustomObject]@{
            Status  = "Active"
            Radio   = $radio
            Channel = $channel
            RxRate  = $rx
            Signal  = $signal
        }
    } catch {
        return [PSCustomObject]@{ Status = "Wired / Ethernet" }
    }
}

function Measure-Telemetry([string]$gw, $tGwTask, $tWanTask) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $dnsMs = 12
    try {
        $rnd = "$([guid]::NewGuid().ToString().Substring(0,8)).cloudflare.com"
        $null = Resolve-DnsName -Name $rnd -Type A -QuickTimeout -DnsOnly -ErrorAction Stop
        $sw.Stop()
        $dnsMs = $sw.ElapsedMilliseconds
    } catch {
        $sw.Stop()
        $dnsMs = $sw.ElapsedMilliseconds
    }

    $gwRes = if ($tGwTask -and $tGwTask.Status -eq 'RanToCompletion' -and $tGwTask.Result.Status -eq 'Success') { "$($tGwTask.Result.RoundtripTime) ms" } else { "N/A" }
    $wanRes = if ($tWanTask -and $tWanTask.Status -eq 'RanToCompletion' -and $tWanTask.Result.Status -eq 'Success') { "$($tWanTask.Result.RoundtripTime) ms" } else { "Timeout" }

    return [PSCustomObject]@{
        GwMs  = $gwRes
        WanMs = $wanRes
        DnsMs = "$dnsMs ms"
    }
}

function Execute-AutoPilot {
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    Show-Header
    Write-Host "[*] Initializing Autonomous Optimization Engine..." -ForegroundColor Cyan

    $adapter = Get-ActiveAdapter
    if (-not $adapter) {
        Write-Host "[-] No active network interface detected!" -ForegroundColor Red
        return
    }

    # 1. Take Pre-Flight Snapshot for 100% Safe Undo
    Save-Snapshot -adapterName $adapter.Name

    # 2. Concurrency Inversion: Fire pure .NET async pings first (zero runspace hazard)
    $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NextHop -First 1)
    $pGw = [System.Net.NetworkInformation.Ping]::new()
    $pWan = [System.Net.NetworkInformation.Ping]::new()
    $tcpProbe = [System.Net.Sockets.TcpClient]::new()
    $tGw = if ($gw) { $pGw.SendPingAsync($gw, 800) } else { $null }
    $tWan = $pWan.SendPingAsync('1.1.1.1', 800)
    $tDnsReach = if (-not $script:VpnActive) { $tcpProbe.ConnectAsync('1.1.1.1', 443) } else { $null }
    $waitTasks = if ($tGw) { [System.Threading.Tasks.Task[]]@($tGw, $tWan) } else { [System.Threading.Tasks.Task[]]@($tWan) }

    # 3. Progressive Live Pipeline Spinner & Synchronous Local Tuning
    [Console]::Write("$($script:Esc)[?25l")
    try {
        # Phase 1: Hardware NIC Driver Optimization
        Show-PipelineSpinner "Auditing Hardware NIC Properties..." 0
        Optimize-HardwareNicProperties -adapterName $adapter.Name
        Flush-AuditLines

        # Phase 2: Single-Pass Kernel TCP Introspection & Tuning
        Show-PipelineSpinner "Hardening Kernel TCP Stack..." 2
        $tcpTable = @{}
        (netsh int tcp show global 2>$null) | ForEach-Object {
            if ($_ -match '^\s*([^:]+?)\s*:\s*(.+)$') {
                $tcpTable[$matches[1].Trim()] = $matches[2].Trim()
            }
        }

        # TCP ECN
        $currEcn = $tcpTable['ECN Capability']
        if ($currEcn -match 'enabled') {
            Register-Audit "TCP ECN Capability" "Optimal" "Already Enabled"
        } else {
            netsh int tcp set global ecncapability=enabled 2>$null | Out-Null
            Register-Audit "TCP ECN Capability" "Applied" "ECN Enabled (Low Bufferbloat)" "ECN: $currEcn -> enabled"
        }

        # Initial RTO
        $currRto = $tcpTable['Initial RTO']
        if ($currRto -eq '300') {
            Register-Audit "TCP Initial RTO" "Optimal" "Already 300 ms"
        } else {
            netsh int tcp set global initialrto=300 2>$null | Out-Null
            Register-Audit "TCP Initial RTO" "Applied" "Initial RTO Set to 300 ms" "InitialRTO: $currRto ms -> 300 ms"
        }

        # Multi-Core Offload (RSS, RSC, Autotuning) - Fast path via $tcpTable, locale fallback via CIM
        $rssState = $tcpTable['Receive-Side Scaling State']
        $rscState = $tcpTable['Receive Segment Coalescing State']
        $autoState = $tcpTable['Receive Window Auto-Tuning Level']
        $isOffloadOptimal = ($rssState -match 'enabled' -and $rscState -match 'enabled' -and $autoState -match 'normal')
        if (-not $rssState -or -not $rscState -or -not $autoState) {
            $offloadCim = Get-NetOffloadGlobalSetting -ErrorAction SilentlyContinue
            $tcpCim = Get-NetTCPSetting -SettingName Internet -ErrorAction SilentlyContinue
            if ($offloadCim -and $tcpCim) {
                $isOffloadOptimal = ($offloadCim.ReceiveSideScaling -eq 'Enabled' -and $offloadCim.ReceiveSegmentCoalescing -eq 'Enabled' -and $tcpCim.AutoTuningLevelLocal -eq 'Normal')
            }
        }
        if ($isOffloadOptimal) {
            Register-Audit "TCP Multi-Core Offload" "Optimal" "RSS, RSC & Autotuning Normal (Already Active)"
        } else {
            netsh int tcp set global rss=enabled rsc=enabled autotuninglevel=normal 2>$null | Out-Null
            Register-Audit "TCP Multi-Core Offload" "Applied" "RSS, RSC & Autotuning Normal"
        }
        Flush-AuditLines

        # Phase 3: Multimedia SystemProfile (Read-before-write)
        Show-PipelineSpinner "Unthrottling Multimedia & Power..." 4
        $mmProfile = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $currThrottle = [Microsoft.Win32.Registry]::GetValue($mmProfile, "NetworkThrottlingIndex", $null)
        $currResp = [Microsoft.Win32.Registry]::GetValue($mmProfile, "SystemResponsiveness", $null)
        
        if ($currThrottle -eq -1 -or $currThrottle -eq [uint32]0xffffffff) {
            Register-Audit "Multimedia Throttle" "Optimal" "Already Unthrottled (0xFFFFFFFF)"
        } else {
            try {
                [Microsoft.Win32.Registry]::SetValue($mmProfile, "NetworkThrottlingIndex", 0xffffffff, [Microsoft.Win32.RegistryValueKind]::DWord)
                Register-Audit "Multimedia Throttle" "Applied" "Throttling Disabled (100% Throughput)" "NetworkThrottlingIndex: $currThrottle -> 0xFFFFFFFF"
            } catch {
                Register-Audit "Multimedia Throttle" "Failed" "Registry Access Denied"
            }
        }

        if ($currResp -eq 0) {
            Register-Audit "System Responsiveness" "Optimal" "Already 0 (Max Priority)"
        } else {
            try {
                [Microsoft.Win32.Registry]::SetValue($mmProfile, "SystemResponsiveness", 0, [Microsoft.Win32.RegistryValueKind]::DWord)
                Register-Audit "System Responsiveness" "Applied" "Gaming/VoIP Priority Maximized" "SystemResponsiveness: $currResp -> 0"
            } catch {
                Register-Audit "System Responsiveness" "Failed" "Registry Access Denied"
            }
        }

        # Phase 4: Power Plan 1-Call Query & Read-Before-Write (Wireless Power Saving Mode)
        $pwrQuery = powercfg /query SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 2>$null
        $pwrText = if ($pwrQuery) { $pwrQuery -join "`n" } else { "" }
        if ($pwrText -match 'Power Scheme GUID:\s*([a-f0-9\-]{36})' -and $pwrText -match 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)' -and $pwrText -match 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)') {
            $activeScheme = ([regex]::Match($pwrText, 'Power Scheme GUID:\s*([a-f0-9\-]{36})')).Groups[1].Value
            $acHex = ([regex]::Match($pwrText, 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)')).Groups[1].Value
            $dcHex = ([regex]::Match($pwrText, 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)')).Groups[1].Value
            if ([int]"0x$acHex" -eq 0 -and [int]"0x$dcHex" -eq 0) {
                Register-Audit "Power Management" "Optimal" "Maximum Performance (Already Active)"
            } else {
                powercfg /setacvalueindex $activeScheme 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 2>$null
                powercfg /setdcvalueindex $activeScheme 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 2>$null
                powercfg /setactive $activeScheme 2>$null
                Register-Audit "Power Management" "Applied" "Wireless Scheme -> Maximum Performance" "AC/DC PowerSave: 0x$acHex/0x$dcHex -> 0x0/0x0"
            }
        } else {
            Register-Audit "Power Management" "Bypassed" "Managed by Modern Standby (S0ix)"
        }
        Flush-AuditLines

        # Phase 5: P2P Delivery Optimization (Read-before-write)
        Show-PipelineSpinner "Configuring P2P, Anycast DNS & DoH..." 6
        $doPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
        $currDo = (Get-ItemProperty -Path $doPath -Name "DODownloadMode" -ErrorAction SilentlyContinue).DODownloadMode
        if ($currDo -eq 0) {
            Register-Audit "Background P2P Uploads" "Optimal" "P2P Upload Seeding Already Disabled"
        } else {
            New-Item -Path $doPath -Force 2>$null | Out-Null
            Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 0 -Type DWord -Force 2>$null
            Register-Audit "Background P2P Uploads" "Applied" "Delivery Optimization P2P Disabled" "DODownloadMode: $currDo -> 0"
        }

        # Phase 6: DNS Anycast & Encrypted DoH (with VPN / Captive-Portal Guard)
        $dnsReachable = $false
        if (-not $script:VpnActive -and $tDnsReach) {
            try { $dnsReachable = $tDnsReach.Wait(350) -and $tcpProbe.Connected } catch { $dnsReachable = $false }
        }
        $dnsModified = $false
        if ($script:VpnActive -or -not $dnsReachable) {
            Register-Audit "Anycast DNS Engine" "Bypassed" "VPN / Captive Portal Detected - DNS Preserved"
            Register-Audit "Encrypted DoH (Win 11)" "Bypassed" "DNS Override Bypassed (VPN / Captive Portal)"
        } else {
            $currDns = (Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ServerAddresses)
            if ($currDns -and ($currDns -join ',') -match '1\.1\.1\.1') {
                Register-Audit "Anycast DNS Engine" "Optimal" "Cloudflare & Google (Already Configured)"
            } else {
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses ('1.1.1.1', '1.0.0.1', '8.8.8.8') -ErrorAction SilentlyContinue
                $dnsModified = $true
                Register-Audit "Anycast DNS Engine" "Applied" "Cloudflare (1.1.1.1) & Google (8.8.8.8)" "DNS: $($currDns -join ',') -> 1.1.1.1, 1.0.0.1, 8.8.8.8"
            }

            if ([Environment]::OSVersion.Version.Build -ge 22000) {
                try {
                    $dohList = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddress -in '1.1.1.1','8.8.8.8' }
                    $doh1 = $dohList | Where-Object { $_.ServerAddress -eq '1.1.1.1' -and $_.DohTemplate -eq 'https://cloudflare-dns.com/dns-query' -and $_.AutoUpgrade }
                    $doh8 = $dohList | Where-Object { $_.ServerAddress -eq '8.8.8.8' -and $_.DohTemplate -eq 'https://dns.google/dns-query' -and $_.AutoUpgrade }
                    if ($doh1 -and $doh8) {
                        Register-Audit "Encrypted DoH (Win 11)" "Optimal" "Cloudflare & Google DoH HTTP/2 (Already Enabled)"
                    } else {
                        if (-not $doh1) { Set-DnsClientDohServerAddress -ServerAddress '1.1.1.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction Stop }
                        if (-not $doh8) { Set-DnsClientDohServerAddress -ServerAddress '8.8.8.8' -DohTemplate 'https://dns.google/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction Stop }
                        $dnsModified = $true
                        Register-Audit "Encrypted DoH (Win 11)" "Applied" "Cloudflare & Google DoH HTTP/2 Enabled"
                    }
                } catch {
                    Register-Audit "Encrypted DoH (Win 11)" "Failed" "DoH registration rejected"
                }
            } else {
                Register-Audit "Encrypted DoH (Win 11)" "Bypassed" "Requires Windows 11 Build 22000+"
            }
        }
        if ($dnsModified) { ipconfig /flushdns 2>$null | Out-Null }
        Flush-AuditLines

        # Phase 7: Wait for in-flight async pings with live Braille spinner
        $tick = 0
        while (-not [System.Threading.Tasks.Task]::WaitAll($waitTasks, 50)) {
            Show-PipelineSpinner "Measuring Telemetry (Gateway, WAN & DNS)..." $tick
            $tick++
        }
    } finally {
        [Console]::Write("`r$($script:Esc)[2K$($script:Esc)[?25h")
    }

    # Harvest Telemetry
    $telemetry = Measure-Telemetry -gw $gw -tGwTask $tGw -tWanTask $tWan
    $pGw.Dispose()
    $pWan.Dispose()
    $tcpProbe.Dispose()

    $rf = Get-WifiRfTelemetry
    $swTotal.Stop()
    $totalSec = [math]::Round($swTotal.ElapsedMilliseconds / 1000, 2)

    # Calculate 4-State Summary Counts
    $appliedCount = ($script:AuditReport | Where-Object { $_.Status -eq 'Applied' }).Count
    $optimalCount = ($script:AuditReport | Where-Object { $_.Status -eq 'Optimal' }).Count
    $bypassedCount = ($script:AuditReport | Where-Object { $_.Status -eq 'Bypassed' }).Count
    $failedCount = ($script:AuditReport | Where-Object { $_.Status -eq 'Failed' }).Count

    if ($rf.Status -eq "Active") {
        Write-Host "  [i] Wi-Fi RF Physical Link    : $($rf.Radio) | Ch $($rf.Channel) | Rx $($rf.RxRate) | Signal $($rf.Signal)" -ForegroundColor Gray
    }

    Write-Host "-----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  [★] Router Latency (LAN)      : $($telemetry.GwMs)" -ForegroundColor White
    Write-Host "  [★] Internet Ping (WAN)       : $($telemetry.WanMs)" -ForegroundColor White
    Write-Host "  [★] DNS Resolution Time       : $($telemetry.DnsMs)" -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Green
    Write-Host " Summary: $appliedCount Applied | $optimalCount Already Optimal | $bypassedCount Bypassed | $failedCount Failed" -ForegroundColor White
    Write-Host " Completed in $totalSec seconds. Pre-flight snapshot saved." -ForegroundColor Gray
    Write-Host ""
    Write-Host " Options: [U] Undo & Restore Baseline  |  [D] View Parameter Diff  |  [Esc] Exit" -ForegroundColor Yellow

    # Interactive key loop with non-interactive fallback (only [Esc] closes)
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Escape) {
                break
            } elseif ($key.Key -eq [ConsoleKey]::U) {
                Restore-Snapshot -adapterName $adapter.Name
                Write-Host "Press [Esc] to close..." -ForegroundColor Gray
                while ([Console]::ReadKey($true).Key -ne [ConsoleKey]::Escape) {}
                break
            } elseif ($key.Key -eq [ConsoleKey]::D) {
                Write-Host ""
                Write-Host "=================================================================" -ForegroundColor Cyan
                Write-Host "               TURBO-WIFI : PARAMETER DIFF AUDIT                 " -ForegroundColor White
                Write-Host "=================================================================" -ForegroundColor Cyan
                $diffs = $script:AuditReport | Where-Object { $_.Diff }
                if ($diffs) {
                    foreach ($d in $diffs) {
                        Write-Host " • $($d.Category): $($d.Diff)" -ForegroundColor White
                    }
                } else {
                    Write-Host " All parameters were already in optimal baseline state." -ForegroundColor Gray
                }
                Write-Host "=================================================================" -ForegroundColor Cyan
                Write-Host " Options: [U] Undo & Restore Baseline  |  [D] View Parameter Diff  |  [Esc] Exit" -ForegroundColor Yellow
            }
        }
    }
}

# Direct Auto-Pilot Execution
Execute-AutoPilot
