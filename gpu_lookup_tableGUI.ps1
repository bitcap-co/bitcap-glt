[CmdletBinding()]
Param (
    [string]$ConfigFile
)

if (! $ConfigFile) { $ConfigFile = '.\instance.json' }
$config = (Get-Content $ConfigFile) | ConvertFrom-Json

$AM_API_URL = $config.params.awesomeHostURL
if (-not $config.debug.debugMode -and -not $config.tests.testMode)
{
    if (! $config.params.awesomeAPIKey) { Throw 'ERROR (Missing API Key: Provide the api key with -AwesomeAPIKey)' }
}
$AM_API_KEY = $config.params.awesomeAPIKey

# External Programs
$putty = $config.programs.putty
$plink = $config.programs.plink

if (-not $config.tests.testMode)
{
    . .\p7zip_util.ps1
    $P7Zip = $config.programs.p7zip
}

# HELPERS

[Regex]$BUSID_REGEX = '(:[0-9a-f]{2}){2}\.\d'
[Regex]$GPU_BUSID_REGEX = '(:[0-9a-f]{2})(:00)\.\d'

# Supported baseboard names
$SUPPORTED_BASEBOARDS = @(
    'BTC-T37',
    'BTC-S37',
    'ONDA B250 BTC V1.05',
    'TB85',
    # OctoMiner
    '12XTREME',
    'X12ULTRA',
    'B85 ULTRA',
    'CRESCENTBAY',
    'B75',
    'skylake'
)

## PIRQ MAPS
# ONDA B250
$b250_pirq_hard_map = @(16, 37, 38, 39, 40, 41, 42, 43, 48, 53, 54, 55)
# BTC-T37, BTC-S37
$x37_pirq_hard_map = @(16, 9, 10, 16, 17, 18, 33, 34)
# TB85
$tb85_pirq_hard_map = @(16, 33, 34, 8, 9, 10)
# Octo 8x (ULTRA)
$octo8_pirq_hard_map = @(34, 33, 32, 39, 35, 36, 37, 38)
# CRESCENTBAY
$crescentbay_pirq_hard_map = @(16, 33, 34, 35, 36, 37, 38, 39)
# B75
$b75_pirq_hard_map = @(33, 34, 8, 9, 10, 6, 17, 18)  #slot 6 doesn't have a slot number
# skylake
$skylake_pirq_hard_map = @(32, 37, 36, 35, 40, 43, 41, 33)

## End PIRQ MAPS

# OctoMiner 12x (XTREME/ULTRA)
$octo12_hard_map = @('01', '07', '0c', '0d', '0b', '05', '0a', '04', '09', '03', '08', '02')


# FUNCTIONS


Function Find-GPU-Context-Offset
{
    $gpu_driver_context = (Get-Content .\gpu_driver.txt)
    if ($gpu_driver_context -eq 'nvidia')
    {
        return 1
    }
    elseif ($gpu_driver_context -eq 'amdgpu')
    {
        if ((Get-Content .\lspcimm.txt | Select-String -Pattern 'Ellesmere').Matches)
        {
            return 1
        }
        return 2
    }
    return $gpu_driver_context
}


Function Find-GPU-Miner
{
    $miners = (Get-Content .\miners.json) | ConvertFrom-Json
    if (-not $config.options.checkBypassAM)
    {
        foreach ($miner in $miners)
        {
            if ($miner.type -eq 'GPU' -and $miner.hostname -eq $remote_ip)
            {
                $miner = (Invoke-WebRequest -UseBasicParsing -Uri "$AM_API_URL/miners/$($miner.id)?key=$AM_API_KEY").Content | ConvertFrom-Json
                # miner can't be offline or disabled
                if (! $miner.isOffline)
                {
                    return $miner
                }
                else
                { Throw 'ERROR (Offline Miner: unable to fetch miner due to it being offline.)' }
            }
        }
        Throw 'ERROR (Unknown Miner: unable to find miner. Miner could be disabled or has recently been added to AM.)'
    }
}


Function Read-All-PCI-Busids
{
    if (
        $PIRQ_FOUND -or
        # PRIME Z390 exemption
        $mb_product_name -eq 'PRIME Z390-P'
    )
    {
        $pdev = @()

        # Navi Support
        if ((Get-Content .\lspcimm.txt | Select-String -Pattern 'Navi').Matches)
        {
            $pci_bridges = (Get-Content .\lspcimm.txt | Select-String -Pattern 'Upstream Port of PCI').Line | ForEach-Object { $_ | Show-Column -Column 0 }
        }
        # Vega Support
        elseif ((Get-Content .\lspcimm.txt | Select-String -Pattern 'Vega').Matches)
        {
            $pci_bridges = (Get-Content .\lspcimm.txt | Select-String -Pattern 'PCIe Bridge" -rc3').Line | ForEach-Object { $_ | Show-Column -Column 0 }
        }
        else
        { $pci_bridges = (Get-Content .\lspcimm.txt | Select-String -Pattern '"PCI bridge" "Intel').Line | ForEach-Object { $_ | Show-Column -Column 0 } }
        foreach ($bus in $pci_bridges)
        {
            $is_lshwpci_gpu = (Get-Content .\lshwpci.txt | Select-String -Pattern "0000:$bus" -Context 0, (Find-GPU-Context-Offset) | Out-String -Stream | Select-String -Pattern $GPU_BUSID_REGEX -AllMatches).Matches
            if ($is_lshwpci_gpu)
            {
                $lshwpci_gpu = $is_lshwpci_gpu[-1].Value.Trim(':')
                $is_ethernet = (Get-Content .\lspcimm.txt | Select-String -Pattern $lshwpci_gpu | Out-String -Stream | Select-String 'Ethernet')
                if (-not $is_ethernet.Matches)
                {
                    $pdev += $bus
                }
            }
        }
        return Write-Output -NoEnumerate $pdev
    }
    Write-Output -NoEnumerate $BUSID_REGEX.Matches((& Get-Content .\dmidecodet9.txt | Select-String -Pattern 'Bus Address')) | ForEach-Object { $_.Value.Trim(':') }
}


Function Read-All-GPU-Busids
{
    $gdev = @()
    foreach ($bus in $pci_busids)
    {
        $installed_gpu = (Get-Content .\lshwpci.txt | Select-String -Pattern "0000:$bus" -Context 0, (Find-GPU-Context-Offset ) | Out-String -Stream | Select-String -Pattern $GPU_BUSID_REGEX -AllMatches).Matches[-1].Value.Trim(':')
        $gdev += $installed_gpu
    }
    return Write-Output -NoEnumerate $gdev
}


Function Get-GPU-Driver
{
    $gpu_driver = (Get-Content .\gpu_driver.txt)
    return $gpu_driver
}


Function Get-GPU-Info
{
    $gpu_infos = @()
    $gpu_detect = (Get-Content .\gpu_detect.json) | ConvertFrom-Json
    foreach ($bus in $gpu_busids)
    {
        $bus_info = $gpu_detect | Where-Object { $_.busid -eq $bus }
        $gpu_infos += '{0} {1} {2}' -f ($bus_info.subvendor, $bus_info.name, $bus_info.mem)
    }
    return Write-Output -NoEnumerate $gpu_infos
}


Function Read-Filtered-PCI-Busids
{
    $pdev = @()
    foreach ($bus in $gpu_busids)
    {
        $attached_pci = (Get-Content .\lshwpci.txt | Select-String -Pattern "0000:$bus" -Context (Find-GPU-Context-Offset), 0 | Out-String -Stream | Select-String -Pattern $BUSID_REGEX -AllMatches).Matches[0].Value.Trim(':')
        $pdev += $attached_pci
    }
    return Write-Output -NoEnumerate $pdev
}


Function Read-PCI-Slot-Info
{
    param(
        [string]$query
    )
    if ($mb_product_name -eq 'PRIME Z390-P')
    {
        $pci_busids = Write-Output -NoEnumerate $BUSID_REGEX.Matches((& Get-Content .\dmidecodet9.txt | Select-String -Pattern 'Bus Address')) | ForEach-Object { $_.Value.Trim(':') }
    }

    $empty_index = 0
    $empty_pci_slot_lines = (Get-Content .\dmidecodet9.txt | Select-String -Pattern '0000:00:00.0').LineNumber

    $pci_query_info = @()
    for ($idx = 0; $idx -lt $pci_busids.count; $idx++)
    {
        $pci_slot_info = (Get-Content .\dmidecodet9.txt | Select-String -Pattern $pci_busids[$idx] -Context 12, 0 | Out-String -Stream | Select-String -CaseSensitive -Pattern $query | Show-Column -Column 3)
        if ($pci_busids[$idx] -eq '00:00.0')
        {
            $pci_slot_info = (Get-Content .\dmidecodet9.txt -TotalCount ($empty_pci_slot_lines[$empty_index]) | Select-String -CaseSensitive -Pattern $query -Context 12, 0).Line | Select-Object -Last 1 | Show-Column -Column 1
            $empty_index++
        }
        if ($mb_product_name -eq 'TB360-BTC D+')
        {
            if ($query -eq 'Designation')
            {
                if ($idx -eq 0)
                {
                    $pci_query_info += $pci_slot_info
                }
                else
                {
                    $pci_query_info += Write-Output "PEX16_$($pci_slot_info[-1].ToString().ToInt32($null) + 1)"
                }
            }
            else
            { $pci_query_info += $pci_slot_info }
        }
        else
        { $pci_query_info += $pci_slot_info }
    }
    return Write-Output -NoEnumerate $pci_query_info
}


Function Get-PCI-Handle-Count
{
    $pci_handles = @((Get-Content .\dmidecodet9.txt | Select-String -Pattern 'Handle ' -AllMatches) | ForEach-Object { $_ | Show-Column -Column 1 })
    return $pci_handles.Count
}


Function Get-Baseboard-Product-Name
{
    return (Get-Content .\mb_product_name.txt)
}


# PIRQ TABLE FUNCS


Function Test-For-PIRQ-Table
{
    if ((Get-Content .\biosdecode.txt | Select-String -Pattern 'PCI Interrupt Routing').Matches) { return 0 }
    return 1
}


Function Read-Baseboard-BIOS
{
    return (Get-Content .\dmidecodebios.txt)
}


Function Update-Baseboard-Product-Name
{
    for ($idx = 0; $idx -lt $SUPPORTED_BASEBOARDS.Count; $idx++)
    {
        if ($SUPPORTED_BASEBOARDS[$idx] -eq $mb_product_name)
        {
            return ( $idx + 1 )
        }
    }
    return $mb_product_name
}


Function Search-PIRQ-Hard-Maps
{
    $support_idx = $mb_product -as [int]
    if ($null -eq $support_idx)
    { Throw "ERROR (Unsupported: The detected motherboard model is not supported: $mb_product)" }

    switch ($support_idx)
    {
        # BTC-S37, BTC-T37
        { ($_ -eq 1) -or ($_ -eq 2) } { return Write-Output -NoEnumerate $x37_pirq_hard_map }
        # ONDA B250
        3 { return Write-Output -NoEnumerate $b250_pirq_hard_map }
        # TB85
        4 { return Write-Output -NoEnumerate $tb85_pirq_hard_map }
        #  12XTREME, X12ULTRA
        { ($_ -eq 5) -or ($_ -eq 6) } { return Write-Output -NoEnumerate $octo12_hard_map }
        # B85 ULTRA
        7 { return Write-Output -NoEnumerate $octo8_pirq_hard_map }
        # CRESCENTBAY
        8 { return Write-Output -NoEnumerate $crescentbay_pirq_hard_map }
        # B75
        9 { return Write-Output -NoEnumerate $b75_pirq_hard_map }
        # skylake
        10 { return Write-Output -NoEnumerate $skylake_pirq_hard_map }
    }
}


Function Read-PIRQ-Device-Slot-Ids
{
    $devices = $gpu_busids
    if ((Get-Content .\gpu_driver.txt | Select-String -Pattern 'amdgpu').Matches -and (Find-GPU-Context-Offset) -ne 1)
    {
        $devices = $pci_busids
    }
    $pirq_device_slot_ids = @()
    # OctoMiner 12x
    if ($mb_product_name -eq '12XTREME' -or $mb_product_name -eq 'X12ULTRA')
    {
        foreach ($bus in $devices)
        {
            for ($idx = 0; $idx -lt $pirq_map.Count; $idx++)
            {
                if ("$bus".Substring(0, 2) -eq $pirq_map[$idx])
                {
                    $pirq_device_slot_ids += $idx
                    break
                }
            }
        }
        return Write-Output -NoEnumerate $pirq_device_slot_ids
    }
    $cp_of_pirq_map = $pirq_map.Clone()
    foreach ($bus in $devices)
    {
        if ($bus -eq 'MISSING') { continue }
        $is_pirq_slot_number_match = (Get-Content .\biosdecode.txt | Select-String -Pattern $bus.Split('.')[0] | Out-String -Stream | Select-String -Pattern 'slot(?: number | )([0-9]{1,})')
        try
        {
            $pirq_slot_number = $is_pirq_slot_number_match.Matches.Groups[1].Value
        }
        catch
        {
            #
        }

        # little bit of headache to get around multiple "16" entries with crescentbay boards
        if ($bus -eq '01:00.0' -and $pirq_slot_number -eq '16')
        {
            $pirq_device_slot_ids += 0
            $cp_of_pirq_map[0] = ''
            continue
        }
        elseif ($pirq_slot_number -eq '16' -and $bus -ne '01:00.0')
        {
            $cp_of_pirq_map[0] = ''
        }
        # fix BTC-X37 showing slot 1 MISSING when slot 7 is MISSING
        if ($mb_product_name -eq 'BTC-T37' -or $mb_product_name -eq 'BTC-S37')
        {
            if ($pirq_slot_number -eq '33' -and $bus -eq '01:00.0')
            {
                $pirq_device_slot_ids += 0
                $cp_of_pirq_map[0] = ''
                continue
            }
        }
        # fix B75 slot 6 not having slot number
        if ($mb_product_name -eq 'B75')
        {
            if ($null -eq $is_pirq_slot_number_match)
            {
                $pirq_device_slot_ids += 5
                $cp_of_pirq_map[5] = ''
                continue
            }
        }
        for ($idx = 0; $idx -lt $cp_of_pirq_map.Count; $idx++)
        {
            if ($cp_of_pirq_map[$idx] -eq $pirq_slot_number)
            {
                $pirq_device_slot_ids += $idx
                $cp_of_pirq_map[$idx] = ''
                break
            }
        }
    }
    Remove-Variable devices
    Remove-Variable cp_of_pirq_map
    return Write-Output -NoEnumerate $pirq_device_slot_ids
}


Function Get-Missing-Slot-Ids
{
    $missing_slot_ids = @()
    if ($PIRQ_FOUND)
    {
        $slot_ids = @(0..($pirq_map.Count - 1))
    }
    else
    { $slot_ids = @(0..((Get-PCI-Handle-Count) - 1)) }
    foreach ($id in $slot_ids)
    {
        if ($pci_info_ids -notcontains $id)
        {
            $missing_slot_ids += $id
        }
    }
    return Write-Output -NoEnumerate $missing_slot_ids
}


Function Get-PIRQ-Device-Designations
{
    $pirq_device_slot_designations = @()
    foreach ($id in $pci_info_ids)
    {
        $pirq_device_slot_designations += "PCIE $( $id + 1 )"
    }
    return Write-Output -NoEnumerate $pirq_device_slot_designations
}


## END PIRQ TABLE FUNCS


Function Request-Data
{
    # Need to make manual connection first to accept remote host key
    Write-Output 'Ensuring remote host is trusted and can connect...'
    Write-Output 'y' | & $plink -ssh  user@$remote_ip 2> $null
    $bios_info = ''
    if ($config.debug.debugBIOS)
    {
        $bios_info = 'for d in system-manufacturer system-product-name bios-release-date bios-version; do echo "${d^} : " $(sudo dmidecode -s $d); done > /tmp/dmidecodebios.txt;'
    }
    $gi_info = ''
    if ($config.options.checkGI)
    {
        $gi_info = "head -n 30 /var/log/awesome/$($miner.softwareType)*/console_output.txt > /tmp/console_output.txt;"
    }
    $payload = "$bios_info $gi_info lsmod | grep -oE 'nvidia|amdgpu' -m 1 > /tmp/gpu_driver.txt; cat `$GPU_DETECT_JSON > /tmp/gpu_detect.json; sudo dmidecode -s baseboard-product-name > /tmp/mb_product_name.txt; sudo dmidecode -t 9 > /tmp/dmidecodet9.txt; sudo biosdecode > /tmp/biosdecode.txt; sudo lspci -mm > /tmp/lspcimm.txt; sudo lshw | grep 'pci@' > /tmp/lshwpci.txt; cd /tmp && tar -jcf - gpu_driver.txt gpu_detect.json mb_product_name.txt dmidecodebios.txt dmidecodet9.txt biosdecode.txt lspcimm.txt lshwpci.txt console_output.txt"
    $cmd_string = "`"$plink`" -ssh -pw `"$pl_passwd`" -batch user@$remote_ip `"$payload`" > ..\$remote_ip.tar.bz2"
    & $CMD /c $cmd_string 2> $null
    # lets exit if we encounter errors with plink
    if ($LASTEXITCODE -eq 1) { Throw 'ERROR (Connection Error: unable to connect to remote IP. Supplied password may not have been accepted)' }
    Expand-Tar "..\$remote_ip.tar.bz2" .
    Expand-Tar "$remote_ip.tar" .
    if ($config.debug.keepFiles)
    {
        $miner | ConvertTo-Json -Depth 4 | Out-File 'miner.json'
        Update-Tar "$remote_ip.tar" 'miner.json', 'instance.json'
        Update-Tar "..\$remote_ip.tar.bz2" "$remote_ip.tar"
    }
    else
    {
        Write-Verbose 'Keep not supplied, removing remote files...'
        Remove-Item "..\$remote_ip.tar.bz2" -ErrorAction SilentlyContinue
    }
    Remove-Item "$remote_ip.tar" -ErrorAction SilentlyContinue
}


Function Get-GPU-Ids
{
    $gids = [string[]]::new($gpu_busids.Count)
    $gid = 0
    for ($idx = 0; $idx -lt $gpu_busids.Count; $idx++)
    {
        if ($gpu_busids[$idx] -ne 'MISSING')
        {
            $gids[$idx] = $gid
            $gid++
        }
        else
        { $gids[$idx] = '-' }
    }
    return Write-Output -NoEnumerate $gids
}


Function Get-GPU-Busids-Length
{
    $length = 0
    foreach ($dev in $gpu_busids)
    {
        if ($dev -ne 'MISSING')
        {
            $length++
        }
    }
    Write-Output $length
}


Function Test-GPU-Indexes
{
    param(
        [string[]]$gpu_indexes
    )
    $validated = @()
    foreach ($gpu_index in $gpu_indexes)
    {
        $gix = $gpu_index -as [int]
        if ($null -eq $gix)
        {
            Write-Warning "Invalid filter input: $gpu_index is not a valid index. Continuing..."
            continue
        }
        if ($gix -ge $n_system_slots)
        {
            Write-Warning "Invalid filter input: $gix is out of range of number of PCIE slots in the system. Continuing..."
            continue
        }
        if ($gpu_ids -notcontains $gix)
        {
            Write-Warning "Invalid filter input: $gix is non-existent GPU ID. Continuing..."
            continue
        }
        $validated += $gix
    }
    if ($validated.Length)
    {
        return Write-Output -NoEnumerate $validated
    }
}


Function Test-If-Empty
{
    param(
        $arr
    )

    if ($arr -and $arr[0] -is [int]) {
        return ('@(' + ($arr -join ", ") + ')')
    } elseif ($arr) {
        return ('@("' + ($arr -join '", "') + '")')
    } else {
        return '$null'
    }
}


Function Format-Lookup-Table
{
    if ($config.debug.debugMode)
    {
        $table = 0..($gpu_busids.Length - 1) | ForEach-Object {
            [PSCustomObject]@{ GPU_ID = $gpu_ids[$_]; PCI_SLOT_ID = $pci_info_ids[$_]; PCI_LOCATOR = $pci_info_designations[$_]; PCI_BUS_IDS = $pci_busids[$_]; GPU_BUS_IDS = $gpu_busids[$_]; GPU_NAME = $gpu_detect_info[$_]; }
        }
        if ($config.options.checkGI)
        {
            $table = 0..($gpu_busids.Length - 1) | ForEach-Object {
                [PSCustomObject]@{ GPU_ID = $gpu_ids[$_]; PCI_SLOT_ID = $pci_info_ids[$_]; PCI_LOCATOR = $pci_info_designations[$_]; PCI_BUS_IDS = $pci_busids[$_]; GPU_BUS_IDS = $gpu_busids[$_]; GPU_GI_INDICATORS = $gi_indicators[$_]; GPU_NAME = $gpu_detect_info[$_]; }
            }
        }
        return $table
    }
    $table = 0..($gpu_busids.Length - 1) | ForEach-Object {
        [PSCustomObject]@{ GPU_ID = $gpu_ids[$_]; SLOT_NUMBER = $pci_info_designations[$_]; GPU_BUS_IDS = $gpu_busids[$_]; GPU_NAME = $gpu_detect_info[$_]; }
    }

    if (! $config.options.checkGI -and ! $config.options.checkAll)
    {
        Write-Warning 'Only showing MISSING PCI/GPU devices'
        $table = 0..($gpu_busids.Length - 1) | ForEach-Object {
            if ($pci_busids[$_] -eq 'MISSING' -or $gpu_busids[$_] -eq 'MISSING')
            {
                [PSCustomObject]@{ GPU_ID = $gpu_ids[$_]; SLOT_NUMBER = $pci_info_designations[$_]; GPU_BUS_IDS = $gpu_busids[$_]; GPU_NAME = $gpu_detect_info[$_]; }
            }
        }
        return $table
    }
    elseif ($config.options.checkGI -and ! $config.options.checkAll)
    {
        Write-Warning 'Only showing GPUs with indicated GIs'
        $table = 0..($gpu_busids.Length - 1) | ForEach-Object {
            if ($gi_indicators[$_])
            {
                [PSCustomObject]@{ GPU_ID = $gpu_ids[$_]; SLOT_NUMBER = $pci_info_designations[$_]; GPU_BUS_IDS = $gpu_busids[$_]; GPU_GI_INDICATORS = $gi_indicators[$_]; GPU_NAME = $gpu_detect_info[$_] }
            }
        }
        return $table
    }
    elseif ($config.options.checkGI -and $config.options.checkAll)
    {
        $table = 0..($gpu_busids.Length - 1) | ForEach-Object {
            [PSCustomObject]@{ GPU_ID = $gpu_ids[$_]; SLOT_NUMBER = $pci_info_designations[$_]; GPU_BUS_IDS = $gpu_busids[$_]; GPU_GI_INDICATORS = $gi_indicators[$_]; GPU_NAME = $gpu_detect_info[$_]; }
        }
    }

    if ($config.options.filterMode -and $search_list)
    {
        $filtered_table = @()
        $filter_list = Write-Output -NoEnumerate (Test-GPU-Indexes $search_list)
        if ($null -eq $filter_list)
        {
            Write-Warning 'Filter input was invalid or missing. Returning normal table...'
            return $table
        }
        foreach ($row in $table)
        {
            if ($filter_list -contains $row.GPU_ID)
            {
                $filtered_table += $row
            }
        }
        return $filtered_table
    }

    return $table
}

Function Show-Table
{
    Write-Output 'GPU Lookup Table'
    if ($config.options.filterMode -and $search_list -and $config.options.checkAll)
    {
        Write-Output "for $remote_ip`: $( $search_list -join ', ' )"
    }
    else
    { Write-Output "for $remote_ip" }

    Write-Output '####################################################'
    if ($config.debug.debugBIOS)
    {
        Write-Output (Read-Baseboard-BIOS)
        Remove-Item .\dmidecodebios.txt -ErrorAction SilentlyContinue
    }
    if ($config.options.listView)
    {
        Write-Output (Format-Lookup-Table) | Sort-Object -Property { [int]($_.SLOT_NUMBER -split '\s')[1] } | Format-List
    }
    else
    { Write-Output (Format-Lookup-Table) | Format-Table -AutoSize }
    Write-Output ('Total Detected Cards: {0}' -f $n_detected_cards)
}


Function Show-Column
{
    param (
        [Parameter(Mandatory, ValueFromPipeline)][string]$line,
        [int]$Column
    )

    ($line -split ' ')[$Column]
}


Function Unprotect-SecureString
{
    param (
        [System.Security.SecureString]$SecureString
    )
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    $Plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $SecureString = $SecureString.Dispose()
    Return $Plain
}


if ($config.debug.debugMode)
{
    $DebugPreference = 'Continue'
    Write-Debug 'Debug Mode Enabled.'
}

# cmd
$CMD = 'C:\Windows\System32\cmd.exe'

$remote_ip = $config.options.input.remoteIP
$remote_passwd = $config.options.input.passwd
$search_list = ($config.options.input.filterList).Split(',')

# Comment when debugging
if (-not $config.debug.debugMode -and -not $config.tests.testMode)
{
    if (! $remote_passwd.Length)
    {
        if (! $env:Default) { Throw 'ERROR (Missing Credentials: No password for remote target supplied)' }
        $remote_passwd = $env:Default | ConvertTo-SecureString
    }
    else
    { $remote_passwd = $remote_passwd | ConvertTo-SecureString }
    $pl_passwd = Unprotect-SecureString $remote_passwd
    $remote_passwd = $remote_passwd.Dispose()

    # Fetch miner via ip from AM api
    if ($putty -and $config.options.checkPutty)
    {
        # Launch a new PuTTY session for further debugging
        $cmd_args = "-ssh -l user -pw `"$pl_passwd`" $remote_ip"
        Start-Process -FilePath $putty -ArgumentList $cmd_args
    }
    $miner = Find-GPU-Miner
    Write-Verbose "Setting up remote connection to $remote_ip..."
    Request-Data

    Remove-Variable pl_passwd -ErrorAction SilentlyContinue
}
# else
# { $miner = (Get-Content .\miner.json) | ConvertFrom-Json }

$PIRQ_FOUND = $FALSE # Flag for $PIRQ table found
$mb_product_name = (Get-Baseboard-Product-Name)
Write-Debug "Baseboard: $mb_product_name"
$mb_product = (Update-Baseboard-Product-Name)
if (
    (Test-For-PIRQ-Table) -eq 0 -or
    # OctoMiner 12x exemption
    $mb_product_name -eq '12XTREME' -or $mb_product_name -eq 'X12ULTRA'
)
{
    $PIRQ_FOUND = $TRUE
    $pirq_map = Search-PIRQ-Hard-Maps
    Write-Debug 'Using the BIOS PIRQ Table: '
    Write-Debug "$pirq_map"
}
else
{
    Write-Warning "`$PIRQ Table not found. Continuing..."
    Write-Warning 'The table information may be inaccurate, or flat-out incomplete.'
}

Write-Verbose 'Fetching PCI(E) and attached GPU bus addresses...'
$pci_busids = Read-All-PCI-Busids
Write-Debug ('PCI BUSIDS - {0}' -f ($pci_busids -join ','))
$gpu_busids = Read-All-GPU-Busids
Write-Debug ('GPU BUSIDS - {0}' -f ($gpu_busids -join ','))

# find the number on system slots
if ($PIRQ_FOUND)
{
    $n_system_slots = $pirq_map.Count
}
else
{ $n_system_slots = (Get-PCI-Handle-Count) }

Write-Verbose 'Examining System for MISSING PCI(E) slots and devices...'
$pci_missing_devices = @()
$gpu_missing_devices = @()
for ($idx = 0; $idx -lt $n_system_slots; $idx++)
{
    if ($null -eq $pci_busids[$idx])
    {
        $pci_busids += 'MISSING'
        $pci_missing_devices += 'MISSING'
    }
    if ($pci_busids[$idx] -eq '00:00.0' -or $pci_busids[$idx] -eq 'MISSING')
    {
        if ($gpu_busids[$idx])
        {
            $gpu_busids[$idx] = 'MISSING'
        }
        else
        { $gpu_busids += 'MISSING' }
        $gpu_missing_devices += 'MISSING'
    }
}
$n_detected_cards = Get-GPU-Busids-Length

$gpu_ids = Get-GPU-Ids

Write-Verbose 'Fetching GPU Make and Model Info...'
$gpu_detect_info = Get-GPU-Info

Write-Verbose 'Fetching PCI(E) slot ids and designations...'
if ($PIRQ_FOUND)
{
    $pci_info_ids = Read-PIRQ-Device-Slot-Ids
    if ($pci_missing_devices.Count -gt 0)
    {
        $pci_info_ids += (Get-Missing-Slot-Ids)
    }
    $pci_info_designations = Get-PIRQ-Device-Designations
}
else
{
    $pci_info_ids = (Read-PCI-Slot-Info 'ID')
    if ($pci_missing_devices.Count -gt 0)
    {
        $pci_info_ids += (Get-Missing-Slot-Ids)
    }
    $pci_info_designations = (Read-PCI-Slot-Info 'Designation')
}

if ($config.options.checkGI)
{
    $gi_indicators = @()
    $available_gpu_busids = @()
    Write-Verbose 'Examining GPU Devices for GI...'
    # THERMAL CONSTS
    $high_temp_value = 78
    $throttle_temp_value = 84
    $mining_software = $miner.softwareType
    $expected_hash = [System.Math]::Floor($miner.speedInfo.avgHashrateValue / $miner.gpuList.Count)
    Write-Debug "Found $mining_software for Miner Software."
    # GI vs. DETECTED DEVICES
    for ($idx = 0; $idx -lt $pci_busids.Count; $idx++)
    {
        # MISSING
        if ($gpu_busids[$idx] -eq 'MISSING' -or $null -eq $gpu_busids[$idx])
        {
            $gi_indicators += 'MISSING'
            Continue
        }

        # NOT AVAILABLE
        # not detected in the miner process (TeamRed and Trex only)
        if ($mining_software -eq 'TrexMiner' -or $mining_software -eq 'TeamRedMiner')
        {
            $bus = $gpu_busids[$idx].Split('.')[0].Split(':')
            if ($mining_software -eq 'TrexMiner')
            {
                [Array]::Reverse($bus)
            }
            $gpu_device = (Get-Content .\console_output.txt -ReadCount 0 | Select-String -Pattern ("($($gpu_busids[$idx].Split('.')[0])|_)\.0" -replace '_', ($bus -join ':'))).Line
            if (-not $gpu_device -or $gpu_device.Contains("- GPU #$idx"))
            {
                $gi_indicators += 'NOT AVAILABLE'
                Continue
            }
        }

        if ($null -eq $gi_indicators[$idx])
        {
            $gi_indicators += ''
            $available_gpu_busids += $gpu_busids[$idx]
        }
    }
    # # GI vs. AVAILABLE CARDS
    for ($idx = 0; $idx -lt $available_gpu_busids.Count; $idx++)
    {
        $gpu = $miner.gpuList[$idx]
        # DEAD
        if ($gpu.statusInfo.statusDisplay -match 'Dead' -or ($gpu.speedInfo.hashrateValue -eq 0 -and $gpu.deviceInfo.gpuActivity -eq 0))
        {
            $gi_indicators[$idx] = 'DEAD'
            Continue
        }

        # THERMALS
        # here we use the avg expected hash and compare with the current hash
        #   if hot and low hash = throttling
        #   if 0 load and low hash = throttling
        if (($gpu.deviceInfo.temperature -ge $throttle_temp_value -and $gpu.speedInfo.hashrateValue -lt (0.95 * $expected_hash)) -or
            ($gpu.speedInfo.hashrateValue -lt (0.95 * $expected_hash) -and $gpu.deviceInfo.gpuActivity -eq 0)
        )
        {
            $gi_indicators[$idx] = 'THROTTLING'
        }
        elseif ($gpu.deviceInfo.temperature -ge $high_temp_value)
        {
            $gi_indicators[$idx] = 'HIGH TEMP'
        }
    }
}
Remove-Item .\console_output.txt -ErrorAction SilentlyContinue

Write-Verbose 'Generating GPU Lookup table...'
if (-not $config.tests.testMode)
{
    Show-Table
    if ($config.debug.genExpected)
    {
        if (-not (Test-Path .\expected.ps1))
            {
                $expected = @'
#{0}
$expected_mb_product_name = "{1}"
$expected_PIRQ_FOUND = ${2}
$expected_pirq_map = {3}
$expected_pci_busids = @({4})
$expected_pci_missing_devices = {5}
$expected_pci_info_ids = @({6})
$expected_pci_info_designations = @({7})
$expected_gpu_busids = @({8})
$expected_gpu_missing_devices = {9}
$expected_gpu_ids = @({10})
$expected_gi_indicators = {11}
$expected_total_detected_cards = {12}
'@
                $expected -f 'expected.ps1',
                             $mb_product_name,
                             $PIRQ_FOUND,
                             (Test-If-Empty $pirq_map),
                             ('"' + ($pci_busids -join '", "') + '"'),
                             $pci_missing_devices.Count,
                             ($pci_info_ids -join ", "),
                             ('"' + ($pci_info_designations -join '", "') + '"'),
                             ('"' + ($gpu_busids -join '", "') + '"'),
                             $gpu_missing_devices.Count,
                             ('"' + ($gpu_ids -join '", "') + '"'),
                             (Test-If-Empty $gi_indicators),
                             $n_detected_cards | Out-File '.\expected.ps1'
            }
            Expand-Tar "..\$remote_ip.tar.bz2" .
            Expand-Tar "$remote_ip.tar" .
            Update-Tar "$remote_ip.tar" .\expected.ps1
            Update-Tar "..\$remote_ip.tar.bz2" "$remote_ip.tar"
            Remove-Item "$remote_ip.tar"
            Remove-Item .\expected.ps1
            Write-Verbose "Successfully updated archive with test file."
    }
}
Write-Verbose 'Done!'

Exit 0
