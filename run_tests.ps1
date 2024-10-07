. .\p7zip_util.ps1
if (Test-Path -Path '.\instance.json')
{
    $instance = (Get-Content '.\instance.json') | ConvertFrom-Json
    $P7Zip = $instance.programs.p7zip
} else
{
    $P7ZipLocations = 'C:\Program Files\7-Zip\', 'C:\Program Files (x86)\7-Zip\'
    $P7Zip = (Get-ChildItem -Path (& Get-Program $P7ZipLocations) -File 7z.exe).FullName
}


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
        if ($Expected -eq $Result)
        {
            Write-Host 'Passed'
            return [PSCustomObject]@{
                test   = $Name
                passed = $true

            }
        }
        else
        {
            Write-Error ('ERROR: got {0}' -f ($Result -join ','))
            return [PSCustomObject]@{
                test     = $Name
                passed   = $false
                expected = $Expected
                result   = $Result
            }
        }
    }
    elseif ($Expected -is [System.Array])
    {
        $compare = (Compare-Object $Expected $Result)
        if ($compare)
        {
            Write-Error ('ERROR: got {0}' -f ($Result -join ','))
            return [PSCustomObject]@{
                test     = $Name
                passed   = $false
                expected = ($compare | Where-Object {$_.SideIndicator -eq '<='}).InputObject -join ", "
                result   = ($compare | Where-Object {$_.SideIndicator -eq '=>'}).InputObject -join ", "
            }
        }
        else
        {
            Write-Host 'Passed'
            return [PSCustomObject]@{
                test   = $Name
                passed = $true

            }
        }
    }
}


$test_results = @()
$test_dirs = '.\tests\Amd', '.\tests\Baseboards', '.\tests\Nvidia'
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
            $n_tests_passed = 0
            $tests = @()
            $f_tests = @()
            $f_tests_results = @()
            Write-Host "Testing $($test.Replace($PWD, ''))..."
            . .\expected.ps1
            . .\gpu_lookup_tableGUI.ps1 -ConfigFile '.\configs\tests.json'
            # Test mb_product_name
            $tests += (Test-Expected-Value -Name 'Baseboard Product Name' -Expected $expected_mb_product_name -Result $mb_product_name)
            # Test for $PIRQ_FOUND
            $tests += (Test-Expected-Value -Name 'PIRQ_FOUND' -Expected $expected_PIRQ_FOUND -Result $PIRQ_FOUND)
            # Test $pirq_map
            $tests += (Test-Expected-Value -Name 'PIRQ Map' -Expected $expected_pirq_map -Result $pirq_map)
            # Test $pci_busids
            $tests += (Test-Expected-Value -Name 'PCI BUSIDS' -Expected $expected_pci_busids -Result $pci_busids)
            # Test $pci_missing_devices
            $tests += (Test-Expected-Value -Name 'PCI Missing Devices' -Expected $expected_pci_missing_devices -Result $pci_missing_devices.Count)
            # Test $pci_info_ids
            $tests += (Test-Expected-Value -Name 'PCI Info IDs' -Expected $expected_pci_info_ids -Result $pci_info_ids)
            # Test $pci_info_designations
            $tests += (Test-Expected-Value -Name 'PCI Info Designations' -Expected $expected_pci_info_designations -Result $pci_info_designations)
            # Test $gpu_busids
            $tests += (Test-Expected-Value -Name 'GPU BUSIDS' -Expected $expected_gpu_busids -Result $gpu_busids)
            # Test $gpu_missing_devices
            $tests += (Test-Expected-Value -Name 'GPU Missing Devices' -Expected $expected_gpu_missing_devices -Result $gpu_missing_devices.Count)
            # Test $gpu_ids
            $tests += (Test-Expected-Value -Name 'GPU Info IDs' -Expected $expected_gpu_ids -Result $gpu_ids)
            # Test $gi_indicators
            $tests += (Test-Expected-Value -Name 'GPU GI Indicators' -Expected $expected_gi_indicators -Result $gi_indicators)
            # Test detected cards
            $tests += (Test-Expected-Value -Name 'Total Detected Cards' -Expected $expected_total_detected_cards -Result $n_detected_cards)
            # Test output
            foreach ($res in $tests)
            {
                if ($res.passed)
                {
                    $n_tests_passed += 1
                }
                else
                {
                    $f_tests += $res.test
                    $f_tests_results += '{0}; expected {1}' -f $res.result, $res.expected
                }
            }

            $test_results += [PSCustomObject]@{
                test_path     = $test.Replace($PWD, '')
                tests_passed  = $n_tests_passed
                total_ratio   = '{0}/{1}' -f $n_tests_passed, $tests.Count
                failed        = $f_tests
                failed_output = $f_tests_results
            }
            Remove-Item .\console_output.txt -ErrorAction SilentlyContinue
            Remove-Item .\dmidecodebios.txt -ErrorAction SilentlyContinue
        }
    }
}
Write-Output $test_results
