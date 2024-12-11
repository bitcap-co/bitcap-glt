<#PSScriptInfo

.VERSION 0.2.7

.GUID fe8bfeb4-23ab-4a96-824c-6a36d85d61b3

.AUTHOR MatthewWertman

.COMPANYNAME bitcap-shell

#>

<#
.DESCRIPTION
glt launcher

#>

[CmdletBinding()]
$VerbosePreference = 'SilentlyContinue'
$PSScriptInfo = (Test-ScriptFileInfo .\glt_launcher.ps1)

$config = (Get-Content .\config.json) | ConvertFrom-Json

$FORCE_LOCAL = $config.forceLocalPrograms
$AM_API = $config.params.awesomeMinerAPIConfig.enabled
$AM_API_URL = $config.params.awesomeMinerAPIConfig.awesomeHostURL
$AM_API_KEY = $config.params.awesomeMinerAPIConfig.awesomeAPIKey


Function Get-Version
{
    return $PSScriptInfo.Version
}


Function Show-Help
{
    $cmd_args = '.\help_man.ps1;', 'PAUSE'
    Start-Process -FilePath powershell.exe -ArgumentList $cmd_args
}


function Update-Script
{
    Start-Process 'https://github.com/bitcap-co/bitcap-glt/releases/latest'
}


Function Get-Miner-Obj
{
    $miner_type = $null
    if ($miner.gpuList)
    {
        $miner_type = 'GPU'
    }
    elseif ($miner.asicList)
    {
        $miner_type = 'ASIC'
    }
    return [PSCustomObject]@{
        id       = $miner.id
        name     = $miner.name
        hostname = $miner.hostname
        type     = $miner_type
    }
}


Function Update-AM-Miner-List
{
    # Fetch and store all miners from the AM dashboard
    $ProgressPreference = 'SilentlyContinue'
    $miners = (Invoke-WebRequest -UseBasicParsing -Uri "$AM_API_URL/miners?key=$AM_API_KEY").Content | ConvertFrom-Json
    $ProgressPreference = 'Continue'
    $miners_json = @()
    $groups = $miners.groupList
    foreach ($group in $groups)
    {
        if ($group.groupList)
        {
            foreach ($group in $group.groupList)
            {
                if ($group.minerList)
                {
                    foreach ($miner in $group.minerList)
                    {
                        $miners_json += (Get-Miner-Obj)
                    }
                }
            }
        }
        if ($group.minerList)
        {
            foreach ($miner in $group.minerList)
            {
                $miners_json += (Get-Miner-Obj)
            }
        }
    }
    $miners_json | ConvertTo-Json | Out-File 'miners.json' -Force
    if ((Test-Path .\miners.json) -and (Get-Item .\miners.json).length -gt 0)
    {
        Write-Host 'Successfully refreshed the miner list.'
    }
    else
    { Write-Error 'Failed to fetch miner list from the API' }
}


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


## External Programs
# cmd
$CMD = 'C:\Windows\System32\cmd.exe'

# 7Zip
Write-Verbose 'Finding 7-zip installation path...'
$P7ZipLocations = 'C:\Program Files\7-Zip\', 'C:\Program Files (x86)\7-Zip\'
$P7Zip = (Get-ChildItem -Path (& Get-Program $P7ZipLocations) -File 7z.exe).FullName
if (! $P7Zip)
{
    Write-Warning 'Unable able to find 7Zip.'
    if (-not $FORCE_LOCAL)
    {
        Write-Verbose 'Fetching 7Zip4PowerShell Module...'
        if (-not (Get-Command Expand-7Zip -ErrorAction Ignore))
        {
            Install-Package -Scope CurrentUser -Force 7Zip4Powershell > $null
        }
        Write-Verbose 'Successfully installed 7Zip4PowerShell module!'
    }
    else
    { Throw 'ERROR (Unable to fetch 7zip! Is -ForceLocalPrograms on?)' }

}
else
{ Write-Verbose "Found 7-zip at $P7Zip." }

# plink
Write-Verbose 'Finding PuTTY installation path...'
$PuTTYLocations = 'C:\Program Files\PuTTY\', 'C:\Program File (x86)\PuTTY\', $env:TEMP
$putty = (Get-ChildItem -Path (& Get-Program $PuTTYLocations) -File putty.exe).FullName
if (! $putty)
{
    Write-Warning 'Unable to launch PuTTY Session (putty.exe not found). Continuing...'
}
$plink = (Get-ChildItem -Path (& Get-Program $PuTTYLocations) -File plink.exe).FullName
if (! $plink)
{
    Write-Warning 'Unable able to find plink.'
    if (-not $FORCE_LOCAL)
    {
        Write-Verbose 'Fetching Plink.exe from upstream...'
        # if plink is not found, lets go and get it!
        $Uri = 'https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe'
        $Path = $env:TEMP
        if (-not(Test-Path $Path -ErrorAction SilentlyContinue))
        {
            New-Item -ItemType Directory -Path $Path
        }

        $filename = $Uri.Substring($Uri.LastIndexOf('/') + 1)
        Write-Verbose "Downloading Plink from $Uri to $Path..."

        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile (Join-Path $Path $filename)
        $plink = (Join-Path $Path $filename)
    }
    else
    { Throw 'ERROR (Unable to fetch plink! Is -ForceLocalPrograms on?)' }
}
Write-Verbose "Found plink at $plink."

## End External Programs


# Load in WPF depends
Write-Verbose 'Trying to load WPF dependecies...'
try
{
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Windows.Forms
}
catch
{ Throw 'ERROR (Failed Operation: Unable to load WPF Dependencies)' }

$GUI_PATH = '.\ui\GUI.xaml'
[xml]$XML_WPF = Get-Content -Path $GUI_PATH

if (! $XML_WPF) { Throw "ERROR (Failed Operation: Unabled to find 'GUI.xaml' in script directory.)" }
Write-Verbose 'Found GUI xaml...'

$XAML_GUI = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XML_WPF))

# Import named components as variables
Write-Verbose 'Importing objects from GUI xaml...'
$XML_WPF.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    Set-Variable -Name ($_.Name) -Value $XAML_GUI.FindName($_.Name)
}

# Update version
$AboutTagVersion.Header += "$( Get-Version )"

#Load Window Icon
$icon_URI = New-Object System.uri((Get-ChildItem '.\resources\icons\BitCapLngLogo_BLK-04.png').FullName)
$MainWindow.Icon = New-Object System.Windows.Media.Imaging.BitmapImage $icon_URI

$FilterElements = @($LabelFilterTitle, $LabelFilter, $TextFilterList)
$FilterElements | ForEach-Object { $_.Visibility = 'Hidden' }
$OptToolCheckFilter.add_click(
    {
        if ($OptToolCheckFilter.IsChecked)
        {
            # Lets hide the logo when filtering is enabled
            $SVGLogoViewBox.Opacity = 0
            $FilterElements | ForEach-Object { $_.Visibility = 'Visible' }

        }
        else
        { $SVGLogoViewBox.Opacity = 0.75; $FilterElements | ForEach-Object { $_.Visibility = 'Hidden' } }
    }
)

# Hook 'Set Default Password' button to store current password
$OptToolButtonDefault.add_click(
    {
        try
        {
            $DefaultENV = ConvertFrom-SecureString -SecureString $PasswdBox.SecurePassword -ErrorAction Stop
            Write-Host 'Created new default password. Writing to system...'

            try
            {
                [System.Environment]::SetEnvironmentVariable('Default', $DefaultENV, 'User')
                Remove-Variable DefaultENV
            }
            catch
            { Write-Error 'ERROR (Unable to store environment variable. Skipping...' }
        }
        catch [System.Management.Automation.PSArgumentException]
        { Write-Error 'ERROR (Invalid input: supplied password cannot be set as default)' }
    }
)

# Hook 'Refresh Miner List' button to fetch latest data from am api
$OptToolButtonRefresh.add_click(
    {
        if ($AM_API)
        {
            Update-AM-Miner-List
        }
        else
        {
            Write-Warning 'AwesomeMiner API is disabled in config. Ignoring...'
        }
    }
)

$OptToolButtonKillOutput.add_click(
    {
        Stop-Process -Name 'cmd' -ErrorAction SilentlyContinue
    }
)

# Hook "Help" button to display man page
$AboutButtonHelp.add_click(
    {
        Show-Help
    }
)

# Hook 'Check for updates' to fetch latest release
$AboutButtonUpdate.add_click(
    {
        Update-Script
    }
)

# Hook AcceptButton
$AcceptButton.add_click(
    {
        $instance_json += [PSCustomObject]@{
            # params
            params   = $config.params
            # programs
            programs = [PSCustomObject]@{
                putty = $putty
                plink = $plink
                p7zip = $P7Zip
            }
            # debug
            debug    = [PSCustomObject]@{
                debugMode   = $DebugToolCheckDebug.IsChecked
                keepFiles   = $DebugToolCheckKeep.IsChecked
                genExpected = $DebugToolCheckGenExpected.IsChecked
                debugBIOS   = $DebugToolCheckBIOS.IsChecked
            }
            # options
            options  = [PSCustomObject]@{
                filterMode    = $OptToolCheckFilter.IsChecked
                listView      = $OptToolCheckLView.IsChecked
                # input
                input         = [PSCustomObject]@{
                    remoteIP   = $TextRemoteIP.Text
                    username   = $TextUser.Text
                    passwd     = if ($PasswdBox.Password.Length) { ($PasswdBox.SecurePassword | ConvertFrom-SecureString) } else { '' }
                    filterList = $TextFilterList.Text
                }
                # quick options
                checkAll      = $CheckAll.IsChecked
                checkBypassAM = $CheckBypassAM.IsChecked
                checkGI       = !$CheckBypassAM.IsChecked
                checkPutty    = $CheckPuTTY.IsChecked
            }
        }
        $instance_json | ConvertTo-Json | Out-File 'instance.json'
        # reset options
        # $TextRemoteIP.Text = '192.168.'
        $PasswdBox.Password = ''
        $TextFilterList.Text = ''
        $CheckBoxElements = @($DebugToolCheckDebug, $DebugToolCheckKeep, $DebugToolCheckGenExpected, $DebugToolCheckBIOS, $OptToolCheckFilter, $OptToolCheckLView)
        $CheckBoxElements | ForEach-Object {
            if ($null -ne $_)
            {
                $_.IsChecked = $FALSE
            }
        }
        $FilterElements = @($LabelFilterTitle, $LabelFilter, $TextFilterList)
        $FilterElements | ForEach-Object { $_.Visibility = 'Hidden' }
        $SVGLogoViewBox.Opacity = 0.75;

        $DebugToolCheckKeep.IsChecked = $TRUE
        $CheckAll.IsChecked = $TRUE

        $CMD_TITLE = $instance_json.options.input.remoteIP
        if (-not $instance_json.debug.debugMode)
        {
            if ((Test-Path .\miners.json))
            {
                $miners = (Get-Content .\miners.json) | ConvertFrom-Json
                foreach ($miner in $miners)
                {
                    if ($miner.hostname -eq $instance_json.options.input.remoteIP)
                    {
                        $CMD_TITLE = $($miner.name)
                        Break
                    }
                }
            }
        }
        else
        {
            $CMD_TITLE = '- DEBUG -'
        }

        $cmd_args = '/k', 'TITLE', "$CMD_TITLE", '&', 'powershell.exe', '-ep', 'Bypass', '.\gpu_lookup_tableGUI.ps1'
        Start-Process -FilePath $CMD -ArgumentList $cmd_args
    }
)

if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript')
{ $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition }
else
{
    $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    if (!$ScriptPath) { $ScriptPath = '.' }
}

# set default for $CheckBypassAM whether or not $AM_API is enabled
if ($AM_API)
{
    $CheckBypassAM.IsChecked = $FALSE
    if (-not $AM_API_URL -or -not $AM_API_KEY)
    {
        # bypass one time with warning
        Write-Warning 'No AwesomeMiner API host or key provided. Please check config.json. Ignoring...'
        $config.params.awesomeMinerAPIConfig.enabled = $FALSE
        $CheckBypassAM.IsChecked = $TRUE
    }
}
else
{
    $CheckBypassAM.IsChecked = $TRUE
}

# first-time launch
if (-not (Test-Path .\miners.json))
{
    Write-Verbose 'Detected first-time launch. fetching miner list...'
    if ($config.params.awesomeMinerAPIConfig.enabled)
    {
        Update-AM-Miner-List
    }
    # Make a shortcut to the app on the desktop
    $WScriptShell = New-Object -ComObject WScript.Shell
    $app_shortcut = $WScriptShell.CreateShortcut("$env:USERPROFILE\Desktop\glt_launcher.exe.lnk")
    $app_shortcut.WorkingDirectory = "$ScriptPath"
    $app_shortcut.TargetPath = "$ScriptPath\glt_launcher.exe"
    $app_shortcut.IconLocation = "$ScriptPath\resources\icons\BitCapLngLogo_BLK-04.ico"
    $app_shortcut.Save()
}
else
{
    if ($config.params.awesomeMinerAPIConfig.enabled)
    {
        # update miner list if older than a week
        $last_accessed = (Get-Item .\miners.json).LastWriteTime | Get-Date -UFormat %s
        if ((Get-Date -UFormat %s) - $last_accessed -ge 604800)
        {
            Update-AM-Miner-List
        }
    }
}

Write-Verbose 'Activating and Showing GUI dialog...'
$XAML_GUI.Activate() | Out-Null
$gui_result = $XAML_GUI.ShowDialog()
if ($gui_result -eq $FALSE)
{
    Write-Verbose 'Dialog closed, Exitting...'
    Exit 0
}
