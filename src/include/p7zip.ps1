Function Get-Program
{
    param(
        [string[]]$path_arr
    )
    $program_path = ''
    foreach ($path in $path_arr)
    {
        if (Test-Path $path)
        {
            $program_path = Resolve-Path $path
            Break
        }
    }
    Return $program_path
}

Function Expand-Tar
{
    param(
        [string]$tarFile,
        [string]$dest
    )

    if (! $P7Zip)
    {
        Expand-7Zip $tarFile $dest
    }
    else
    { & $P7zip -bso0 -bsp0 x $tarFile -aoa }
}


Function Update-Tar
{
    param(
        [string]$tarFile,
        [string[]]$files
    )

    if (! $P7Zip)
    {
        Compress-7Zip $tarFIle -Append $(, $files)
    }
    else
    { & $P7Zip -bso0 -bsp0 a $tarFile $(, $files) }
}
