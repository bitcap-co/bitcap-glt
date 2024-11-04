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
