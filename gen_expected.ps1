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
            Write-Host "Generating test file for $($test.Replace($PWD, ''))..."
            . .\gpu_lookup_tableGUI.ps1 -ConfigFile ".\configs\tests.json"
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
                $expected -f $test.Replace($PWD, ''),
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
            Write-Host "Wrote expected.ps1."
            Update-Tar -tarFile $tar_name -files .\expected.ps1
            Update-Tar -tarFile $test -files ".\$tar_name"
            Remove-Item ".\$tar_name"
            Remove-Item .\expected.ps1
            Write-Host "Successfully updated archive with test file."
            Remove-Item .\console_output.txt -ErrorAction SilentlyContinue
            Remove-Item .\dmidecodebios.txt -ErrorAction SilentlyContinue
        }
    }
}

