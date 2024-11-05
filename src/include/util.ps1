## GETTERS
Function Get-Baseboard-Product-Name
{
    return (Get-Content .\mb_product_name.txt)
}


Function Get-PCI-Handle-Count
{
    $pci_handles = @((Get-Content .\dmidecodet9.txt | Select-String -Pattern 'Handle ' -AllMatches) | ForEach-Object { $_ | Show-Column -Column 1 })
    return $pci_handles.Count
}
## END GETTERS


Function Show-Column
{
    param (
        [Parameter(Mandatory, ValueFromPipeline)][string]$line,
        [string]$Delimiter,
        [int]$Column
    )
    if (! $Delimiter) { $Delimiter = ' ' }
    ($line -split $Delimiter)[$Column]
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
