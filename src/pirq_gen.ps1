[CmdletBinding()]
Param (
    [string]$ConfigFile
)

# Includes
. .\include\p7zip.ps1
. .\include\pirq.ps1
. .\include\util.ps1

if (! $ConfigFile) { $ConfigFile = '.\instance.json' }
$config = (Get-Content $ConfigFile) | ConvertFrom-Json

# External Programs
$P7Zip = $config.programs.p7zip
$plink = $config.programs.plink
$CMD = 'C:\Windows\System32\cmd.exe'

$get_system = @"
for d in system-manufacturer system-product-name bios-release-date bios-version; do echo `"`${d^} : `" `$(echo `"$pl_passwd`" | sudo -S -k dmidecode -s `$d); done > /tmp/dmidecodebios.txt
echo `"$pl_passwd`" | sudo -S -k dmidecode -s baseboard-product-name > /tmp/mb_product_name.txt
echo `"$pl_passwd`" | sudo -S -k biosdecode > /tmp/biosdecode.txt
lspci -mm > /tmp/lspcimm.txt
cd /tmp && tar -jcf - dmidecodebios.txt mb_product_name.txt biosdecode.txt lspcimm.txt
"@

$get_pirq_slot = @"
echo `"$pl_passwd`" | sudo -S -k biosdecode
"@
# echo `"$pl_passwd`" | sudo -S -k shutdown now


Function Request-Data
{
    param (
        [switch]$StoreAsArchive = $FALSE,
        [string]$OutName = 'data',
        [Parameter(Mandatory)][string]$Payload
    )

    if ($StoreAsArchive)
    {
        $OutName = "$OutName.tar.bz2"
    }
    $Payload | Out-File -Encoding ascii -FilePath .\payload

    # Need to make manual connection first to accept remote host key
    Write-Output 'Ensuring remote host is trusted and can connect...'
    Write-Output 'y' | & $plink -ssh  $username@$remote_ip 2> $null
    $cmd_string = "`"$plink`" -ssh -pw `"$pl_passwd`" -batch $username@$remote_ip -m .\payload > $OutName"
    & $CMD /c $cmd_string 2> $null

    if ($StoreAsArchive)
    {
        $tar_name = $OutName.Replace('.bz2', '')
        Expand-Tar $OutName .
        Expand-Tar $tar_name .
        Remove-Item $tar_name
    }

    Remove-Item .\payload -ErrorAction SilentlyContinue
}


# Load in WPF depends
Write-Verbose 'Loading in WPF dependecies...'
try
{
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Windows.Forms
}
catch
{ Throw 'ERROR (Failed Operation: Unable to load WPF Dependencies)' }

[xml]$XML_WPF_INPUT = Get-Content -Path .\ui\Input.xaml
[xml]$XML_WPF_POPUP = Get-Content -Path .\ui\Popup.xaml
$XAML_INPUT = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XML_WPF_INPUT))
$XAML_POPUP = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XML_WPF_POPUP))

# Import named components as variables
Write-Verbose 'Importing objects from Input xaml...'
$XML_WPF_INPUT.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    Set-Variable -Name ($_.Name) -Value $XAML_INPUT.FindName($_.Name)
}

Write-Verbose 'Importing objects from Popup xaml...'
$XML_WPF_POPUP.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    Set-Variable -Name ($_.Name) -Value $XAML_POPUP.FindName($_.Name)
}
# Get window icon uri
$icon_uri = New-Object System.uri((Get-ChildItem '.\resources\icons\BitCapLngLogo_BLK-04.png').FullName)

# UserInput
$UserInput.Icon = New-Object System.Windows.Media.Imaging.BitmapImage $icon_uri
$UserInput.Title = '$PIRQ Map Generation: Configuration'
$YesButton.add_click(
    {
        Set-Variable -Name USER_CONTINUE -Value $TRUE -Scope Global
        $UserInput.Close()
    }
)
$NoButton.add_click(
    {
        Set-Variable -Name USER_CONTINUE -Value $FALSE -Scope Global
        $UserInput.Close()
    }
)

# Popup
$Popup.Icon = New-Object System.Windows.Media.Imaging.BitmapImage $icon_uri
$Popup.Title = 'Information Dialog'
$AcceptButton.add_click(
    {
        $Popup.Hide()
    }
)

$remote_ip = $config.options.input.remoteIP
$username = $config.options.input.username
$remote_passwd = $config.options.input.passwd

Write-Verbose "Setting up remote connection to $remote_ip..."
if (! $username.Length)
{
    $username = 'user'
}
if (! $remote_passwd.Length)
{
    if (! $env:Default) { Throw 'ERROR (Missing Credentials: No password for remote target supplied)' }
    $remote_passwd = $env:Default | ConvertTo-SecureString
}
else
{ $remote_passwd = $remote_passwd | ConvertTo-SecureString }
$pl_passwd = Unprotect-SecureString $remote_passwd
$remote_passwd = $remote_passwd.Dispose()

# initial system check
Write-Verbose "Getting system info from $remote_ip..."
Request-Data -Payload $get_system -OutName $remote_ip -StoreAsArchive

Remove-Variable pl_passwd -ErrorAction SilentlyContinue

# Get baseboard name
$mb_product_name = (Get-Baseboard-Product-Name)
$mb_product = (Update-Baseboard-Product-Name)

if ($mb_product_name -ne $mb_product)  # if mb_product_name isnt return back
{
    $TextInformation.Text = "$mb_product_name is already supported within the script. No further action needed."
    $XAML_POPUP.Activate | Out-Null
    $result = $XAML_POPUP.ShowDialog()
    if (-not $result)
    {
        Write-Verbose 'Dialog closed, Exitting...'
        Exit 0
    }
}

if ((Test-For-PIRQ-Table) -eq 1)
{
    $TextInformation.Text = "$mb_product_name has no `$PIRQ Table available. Exitting..."
    $XAML_POPUP.Activate | Out-Null
    $result = $XAML_POPUP.ShowDialog()
    if (-not $result)
    {
        Write-Verbose 'Dialog closed, Exitting...'
        Exit 0
    }
}

# Generate the PIRQ MAP

# Show user what we found
$TextInformation.Text = "
IP Addr: $remote_ip
`$PIRQ FOUND!
Baseboard Name: $mb_product_name
Manufacturer:$(Get-Content .\dmidecodebios.txt | Select-String -Pattern 'System-manufacturer' | Show-Column -Delimiter ':' -Column 1)
BIOS Release:$(Get-Content .\dmidecodebios.txt | Select-String -Pattern 'Bios-release-date' | Show-Column -Delimiter ':' -Column 1)
BIOS Version:$(Get-Content .\dmidecodebios.txt | Select-String -Pattern 'Bios-version' | Show-Column -Delimiter ':' -Column 1)
"
$XAML_POPUP.Activate | Out-Null
$XAML_POPUP.ShowDialog()
if ($XAML_POPUP.Visibility -eq 'Hidden')
{
    $TextQuestion.Text = 'How many system PCI(E) slots are available?'
    $XAML_INPUT.Activate | Out-Null
    $result = $XAML_INPUT.ShowDialog()
    if (-not $result)
    {

    }
}

if ($USER_CONTINUE)
{
    $n_system_slots = $TextInput.Text -as [int]
    if ($null -eq $n_system_slots)
    { Throw 'ERROR (Invalid Input: Please input number of PCI(E) slots)' }
    Write-Verbose $n_system_slots
    $pirq_map = @()
    $busid_ignore = @()
    # figure out ethernet bus id to ignore
    $eth_bus_id = (Get-Content .\lspcimm.txt | Select-String -Pattern "Ethernet").Line | Show-Column -Column 0
    $busid_ignore += $eth_bus_id.Split('.')[0]
    $Popup.Title = '$PIRQ Map Generation: Setup'
    $TextInformation.Text = 'Starting $PIRQ Map generation! Have access to the system. Remove the GPU devices from the system and follow the on-screen instructions. Press Ok to start.'
    $result = $XAML_POPUP.ShowDialog()
    if (-not $result)
    {
        for ($i = 0; $i -lt $n_system_slots; $i++)
        {
            $slot_number = $($i + 1)
            $Popup.Title = "`$PIRQ Map Generation : Slot $slot_number"
            $TextInformation.Text = "Please install an GPU device in Slot $slot_number and boot up system. Once online, press Ok."
            $result = $XAML_POPUP.ShowDialog()
            if (-not $result)
            {
                # wait for ip
                if (Test-Connection -ComputerName $remote_ip -Quiet)
                {
                    Request-Data -Payload $get_pirq_slot -OutName biosdecode.txt
                    # parse and record new slot number
                    $pirq_slot_number_line_matches = (Get-Content .\biosdecode.txt | Select-string -Pattern 'slot(?: number | )([0-9]{1,})').Line
                    foreach ($line in $pirq_slot_number_line_matches)
                    {
                        $is_ignore = $FALSE
                        foreach ($bus in $busid_ignore)
                        {
                            if (($line | Select-String -Pattern $bus).Matches)
                            {
                                $is_ignore = $TRUE
                                break
                            }
                        }
                        if ($is_ignore) { continue }
                        $bus_id = ($line | Select-String -Pattern 'ID (:[0-9a-f]{2})(:00)')
                        $pirq_slot_number = ($line | Select-String -Pattern 'slot(?: number | )([0-9]{1,})').Matches.Groups[1].Value
                        $pirq_map += $pirq_slot_number
                        $busid_ignore += $bus_id
                        break
                    }
                }
            }
        }
        # output map
        Write-Verbose "$pirq_map"
    }
}
