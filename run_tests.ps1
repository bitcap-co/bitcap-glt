Function Expand-Tar
{
    param(
        [string]$tarFile,
        [string]$dest
    )

    & $P7zip -bso0 -bsp0 x $tarFile -aoa

}

$P7Zip = (Get-ChildItem -Path 'C:\Program Files\7-Zip\' -File 7z.exe).FullName

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
            Write-Host 'Expected value of $mb_product_name:' "$expected_mb_product_name"
            if ($expected_mb_product_name -eq $mb_product_name) {Write-Host "Passed" } else { Write-Error "ERROR: got $mb_product_name" }
            # Test for $PIRQ_FOUND
            Write-Host 'Expected value of $PIRQ_FOUND:', "$expected_PIRQ_FOUND"
            if ($expected_PIRQ_FOUND -eq $PIRQ_FOUND) {Write-Host "Passed" } else { Write-Error "ERROR: got $PIRQ_FOUND" }
            # Test $pirq_map
            Write-Host 'Expected value of $pirq_map:', "$expected_pirq_map"
            if ($null -eq $expected_pirq_map) {
                if ($expected_pirq_map -eq $pirq_map) {Write-Host "Passed" } else { Write-Error ('pirq map - {0}' -f ($pirq_map -join ',')) }
            } else {
                if ($(Compare-Object $expected_pirq_map $pirq_map -PassThru)) { Write-Error ('pirq map - {0}' -f ($pirq_map -join ','))} else { Write-Host "Passed" }
            }
            # Test $pci_busids
            Write-Host 'Expected value of $pci_busids:', ('PCI BUSIDS - {0}' -f ($expected_pci_busids -join ','))
            if ($(Compare-Object $expected_pci_busids $pci_busids -PassThru)) { Write-Error ('PCI BUSIDS - {0}' -f ($pci_busids -join ','))} else { Write-Host "Passed" }
            # Test $gpu_busids
            Write-Host 'Expected value of $gpu_busids:', ('GPU BUSIDS - {0}' -f ($expected_gpu_busids -join ','))
            if ($(Compare-Object $expected_gpu_busids $gpu_busids -PassThru)) { Write-Error ('GPU BUSIDS - {0}' -f ($gpu_busids -join ','))} else { Write-Host "Passed" }
            # Test detected cards
            Write-Host 'Expected value of $total_detected_cards:' "$expected_total_detected_cards"
            if ($expected_total_detected_cards -eq $n_detected_cards) {Write-Host "Passed"} else { Write-Error "ERROR: got $n_detected_cards"}
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
