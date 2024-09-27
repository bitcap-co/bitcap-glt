Function Expand-Tar
{
    param(
        [string]$tarFile,
        [string]$dest
    )

    & $P7zip -bso0 -bsp0 x $tarFile -aoa

}

$P7Zip = (Get-ChildItem -Path 'C:\Program Files\7-Zip\' -File 7z.exe).FullName


Function Test-Expected-Value
{
    param(
        $Name,
        $Expected,
        $Result
    )
    Write-Host "Expected value of ${Name}:", "$Expected"
    if ($null -eq $Expected -or $Expected -isnot [System.Array])
    {
        if ($Expected -eq $Result) { Write-Host "Passed"} else { Write-Error ('ERROR: got {0}' -f ($Result -join ','))}
    } elseif ($Expected -is [System.Array])
    {
        if ($(Compare-Object $Expected $Result)) { Write-Error ('ERROR: got {0}' -f ($Result -join ','))} else { Write-Host "Passed" }
    }
}

$test_results = @()
$test_dirs = '.\tests\Amd', '.\tests\Nvidia', '.\tests\Baseboards'
foreach ($test_path in $test_dirs)
{
    if (Test-Path $test_path)
    {
        $test_path = Resolve-Path $test_path
        foreach ($test in (Get-ChildItem -Path $test_path -Recurse -Filter '*.tar.bz2').FullName)
        {
            Expand-Tar $test .
            $archive_name = $test.Split('\')[-1]
            $tar_name = $archive_name.Replace('.bz2', '')
            Expand-Tar $tar_name .
            Remove-Item $tar_name
            Write-Host "Testing $($test.Replace($PWD, ''))..."
            . .\expected.ps1
            . .\gpu_lookup_tableGUI.ps1 -ConfigFile ".\configs\default.json" -Verbose
            # Test mb_product_name
            Test-Expected-Value -Name "Baseboard Product Name" -Expected $expected_mb_product_name -Result $mb_product_name
            # Test for $PIRQ_FOUND
            Test-Expected-Value -Name "PIRQ_FOUND" -Expected $expected_PIRQ_FOUND -Result $PIRQ_FOUND
            # Test $pirq_map
            Test-Expected-Value -Name "PIRQ Map" -Expected $expected_pirq_map -Result $pirq_map
            # Test $pci_busids
            Test-Expected-Value -Name "PCI BUSIDS" -Expected $expected_pci_busids -Result $pci_busids
            # Test $pci_missing_devices
            Test-Expected-Value -Name "PCI Missing Devices" -Expected $expected_pci_missing_devices -Result $pci_missing_devices.Count
            # Test $pci_info_ids
            Test-Expected-Value -Name "PCI Info IDs" -Expected $expected_pci_info_ids -Result $pci_info_ids
            # Test $pci_info_designations
            Test-Expected-Value -Name "PCI Info Designations" -Expected $expected_pci_info_designations -Result $pci_info_designations
            # Test $gpu_busids
            Test-Expected-Value -Name "GPU BUSIDS" -Expected $expected_gpu_busids -Result $gpu_busids
            # Test $gpu_missing_devices
            Test-Expected-Value -Name "GPU Missing Devices" -Expected $expected_gpu_missing_devices -Result $gpu_missing_devices.Count
            # Test $gpu_ids
            Test-Expected-Value -Name "GPU Info IDs" -Expected $expected_gpu_ids -Result $gpu_ids
            # Test $gi_indicators
            Test-Expected-Value -Name "GPU GI Indicators" -Expected $expected_gi_indicators -Result $gi_indicators
            # Test detected cards
            Test-Expected-Value -Name "Total Detected Cards" -Expected $expected_total_detected_cards -Result $n_detected_cards
            # Test output

            break
            # notepad.exe biosdecode.txt
            # notepad.exe dmidecodet9.txt
            # if ((test-path .\console_output.txt))
            # {
            #     notepad.exe console_output.txt
            # }
            # notepad.exe lshwpci.txt
            # notepad.exe lspcimm.txt
            # notepad.exe mb_product_name.txt
            # $cmd_args = '-ep Bypass', '.\gpu_lookup_tableGUI.ps1', '-ConfigFile', '.\configs\default.json', '-Verbose'
            # Start-Process -FilePath powershell.exe -ArgumentList $cmd_args -NoNewWindow -Wait -
            # $continue = Read-Host 'Did it work? (y/n) '
            # if ($continue)
            # {
            #     $failed = $false
            #     $issue = $null
            #     if ($continue -eq 'n')
            #     {
            #         $failed = $true
            #         $issue = Read-Host 'Describe issue: '
            #     }
            #     $test_results += [PSCustomObject]@{
            #         test_path    = $test.Replace($PWD, '')
            #         archive_name = $archive_name
            #         failed       = $failed
            #         issue        = $issue
            #     }
            #     Stop-Process -Name 'notepad'
            #     Remove-Item .\192.168.*.json -ErrorAction SilentlyContinue
            #     Remove-Item .\console_output.txt -ErrorAction SilentlyContinue
            #     Remove-Item .\dmidecodebios.txt -ErrorAction SilentlyContinue
            # }
        }
    }
    break
}
Write-Output $test_results
