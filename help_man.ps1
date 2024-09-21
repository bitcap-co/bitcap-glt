Function Write-Man
{
    return @'
SYNOPSIS
gpu_lookup_table -- maps installed GPU devices to their PCI(E) slot addresses
                      and their physical locations.

DESCRIPTION
gpu_lookup_tableGUI is a small utility script allowing the user to map all GPU
devices to their corresponding PCIE slot addresses/locations on a remote system.
Interacted with a GUI window.

INPUTS
Script functionality can't be operated via CLI. The script makes use of a WPF dialog instead!
Upon running the script, a 'GPU Lookup Table GUI' window will appear.
The following sections are an overview of the UI in the dialog window:

TOOLBAR LAYOUT
Along the top, One can see 'Debug', 'Options', and 'About' categories in the toolbar. Below goes into detail about
each category:

    The 'Debug' Category
    Here, one can see a few debugging options that one can enable. The end user has access to these but
    don't need any of these options for the script to run. These are intended debugging issues that may arise
    with the script. Check out the Reporting Bugs section in NOTES for more information.

        'Keep Remote Files' Checkbox - Keep and store the data it gets from the remote target on the host. These
                                       are put in the gpu_lookup\ directory named <ip_address>.tar.bz2.

        'Get BIOS Information' Checkbox - Fetch BIOS information and append to the outputted table. Stored
                                          locally in 'dmidecodebios.txt'.

    The 'Options' Category
    Extra optional functionality.
        'Enable Filter Mode' Checkbox - Enable filtering. When checked, will show a new 'Filtering' set of elements
                                        in the dialog. The labeled 'Filter List' textbox is for filtering input.
                                        Check out the 'Filtering' section in NOTES.

        'List View' Checkbox - Enable an alternative list view of the data gathered by the script, sorted in order
                               of PCI(E) slot.

        'Kill All Output' Button - Will close all the currently open output windows.

        'Set Default Password' Button - Will set the supplied password in the password box as the default. The
                                        script will try this password when the password box is blank.

        'Refresh Miner List' Button - Fetches the full list of miners from the AM dashboard. The script then uses
                                      this list to validate that it is connecting to a node that exists and is
                                      active. See 'Bypass AM Validation' Quick Option to skip this valildation.

    The 'About' Category
    Meta information and self-update.

        'Help' Button - Shows this output to the command window. If using PowerShell 7, will open an separate
                        window for a more interactive experience.

        'Check for Updates' Button - Will self-update the script by fetching the latest release from the repository.

        'Version' Tag - Shows the current version of the script.

GRID LAYOUT

    Text field containing '192.168.' - Supply the IP address of the target remote system.

    Credentials

        'Password' Password Box - Supply the password used for remote login. Leave blank to
                                  use the default password.

    Quick Options

        'Show All' Checkbox - Ensures that all devices are shown in the output table; a complete table. if not
                              not checked, will only show GI/MISSING cards.

        'Bypass AM Validation' Checkbox - The scipt will validate the entered IP address with AwesomeMiner by default.
                                          Use this option to disable that behavior. NOTE: This will also disable GI
                                          Examination.

        'Launch PuTTY Session' Checkbox - Launches a standalone PuTTY session on the provided IP address.
                                          Useful for further diagnosing issues with a remote target.

    Click 'Go!' button or press ENTER to generate a table with the currently set options.

OUTPUTS
A custom PSObject to the console window, representing a table.

NOTES
External Programs

    Script makes use of some external programs that are needed to function, 7Zip and PuTTY (plink.exe).
    In the event that these are not on the current system, the script will fetch the programs for you.

    In this case, the script will make use of:
    The 7Zip4PowerShell module (Package Manager)
    Source: https://github.com/thoemmi/7Zip4Powershell

    Plink.exe (Direct Download)
    Source: https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe

    To disable this behavior, change "forceLocalPrograms" key "True" within config.json.

Required Files

    Script can NOT operate without the file "GUI.xaml" in the same directory of script.

    "config.json" can be used to further configure the script. For the script to properly function,
    please supply 'awesomeHostURL' and 'awesomeAPIKey' with your AwesomeMiner local host
    and API key respectfully.

List of Supported Hardware

    As it stands, most systems in-house should be supported. Unfortunately, not all motherboards and GPUs work
    "out of the box". They require hard-coded support within the script. One can read more about this process
    in the 'Aside on How Hardware is Supported' section further below.
    Below is all the motherboards and GPUs that have been tested so far:

    MOTHERBOARDS
        Motherboards (supported via $PIRQ)
            - ONDA B250 (12x)
            - BTC-S37/BTC-T37 (8x)
            - CRESCENTBAY
            - 'skylake' (8x)
            - OctoMiner
            - TB85 (6x ATX)

        Other boards that are supported "out of the box":
            - TB360
            - ASUS Prime Z390

        Not currently supported:
            - Gigabyte Z390 UD; wontfix

    GPUs
        AMD
            - Ellesmere (400 series)
            - Polaris (500 series)
            - Navi (5000 series, 6000 series, BC-160)
            - Vega

        NVIDIA
            - Turing (1660, 1660 Super, 20 series)
            - Pascal (10 series)
            - Ampere (30 series, A2000)

Aside on How Hardware is Supported

    The $PIRQ Table (PCI Interrupt Table) is a table in read-only memory (ROM) that stores a lot of information
    about how PCI(E) devices have been detected in the system after boot. The script will check here first and
    use this information to gather the particular order of the PCI devices if it exists.

    A fallback method used by the script is reading from the DMI table, which is another table in ROM.
    Especially for Intel chipset-driven motherboards, this table can be inaccurate, wrong, or flat-out
    incomplete as this information must be manually provided by the OEM.

    Comparatively, the $PIRQ table is generally more reliable but requires a hard-coded "map" baked into the
    script. Which means support varies from motherboard to motherboard.

Setting a Default Password For Remote Login

    To make remote login easier, one can set a default password that
    the script will use for login.

    Enter the desired password into the password box and then naviagate Options -> 'Set Default Password' !

    Leaving the 'Password' password box blank will tell the script to try and use the provided default password.

    If no password is supplied in the password box AND no provided default password, the script will throw an
    error saying 'Missing Credentials'.

Filtering

    Using the 'Filter' Option, One can find a specified GPU device or specified list of GPU devices
    given their device index. returns a table of just the specified device(s).

    To find a specified GPU device, supply the device index shown on the AM dashboard in the input field.
    Can supply multiple indexes by separating them with a comma.

    EXAMPLE:
    '0,3,6,9' will get GPU 0, GPU 3, GPU 6, and GPU 9 from the system and only display those in the outputted
    table.

GI Indicators

    The following values are shown in the GPU_GI_INDICATORS column to indicate GI:
        - MISSING - Missing from the system
        - NOT AVAILABLE - Detected in the system, but not picked-up by the miner software
        - DEAD - Detected in the miner software, but not hashing
        - HIGH TEMP - GPU has temp higher or equal to 79C
        - THROTTLING - If GPU temp is higher or equal to 85C, it is assumed to be throttling.

'@
}

Write-Man | Out-String -Width 180
