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
