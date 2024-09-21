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
$test_dirs = '.\debug', '.\tests\Amd', '.\tests\Nvidia', '.\tests\GI'
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
            notepad.exe biosdecode.txt
            notepad.exe dmidecodet9.txt
            if ((test-path .\console_output.txt))
            {
                notepad.exe console_output.txt
            }
            notepad.exe lshwpci.txt
            notepad.exe lspcimm.txt
            notepad.exe mb_product_name.txt
            $cmd_args = '-ep Bypass', '.\gpu_lookup_tableGUI.ps1', '-ConfigFile', '.\config\gi-enabled.json', '-Verbose'
            Start-Process -FilePath powershell.exe -ArgumentList $cmd_args -NoNewWindow -Wait
            $continue = Read-Host 'Did it work? (y/n) '
            if ($continue)
            {
                $failed = $false
                $issue = $null
                if ($continue -eq 'n')
                {
                    $failed = $true
                    $issue = Read-Host 'Describe issue: '
                }
                $test_results += [PSCustomObject]@{
                    test_path    = $test.Replace($PWD, '')
                    archive_name = $archive_name
                    failed       = $failed
                    issue        = $issue
                }
                Stop-Process -Name 'notepad'
                Remove-Item .\192.168.*.json -ErrorAction SilentlyContinue
                Remove-Item .\console_output.txt -ErrorAction SilentlyContinue
                Remove-Item .\dmidecodebios.txt -ErrorAction SilentlyContinue
            }
        }
    }
}
Write-Output $test_results
