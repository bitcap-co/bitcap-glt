## Contributing to GLT

### Reporting Issues
If encountering any issues, please submit an issue using the [ISSUE_TEMPLATE](./ISSUE_TEMPLATE.md).
Describe the issue as accurately as possible and provide any screenshots/archives to help recreate the issue.

If creating an issue for baseboard support, please use the [BASEBOARD_SUPPORT_TEMPLATE](./BASEBOARD_SUPPORT_TEMPLATE.md) and provide the data specified from the [Baseboard support section](./CONTRIBUTING.md#baseboard-support). Also, provide a data archive of an example system with the baseboard installed.

### Providing data archives
To get a data archive output from the script, make sure that Debug -> 'Keep Remote Files' is checked. If it is not, check the option and run on the same remote host again.
You can find the archive at \<INSTALLDIR\>\gpu_lookup_tableGUI\gpu_lookup\\<REMOTEIP\>.tar.bz2.

If the current baseboard is not supported, one can make the data archive manually by running the following with `plink.exe` from PuTTY.
```powershell
$pl_passwd = "" # your password
$remote_ip = "" # remote host with baseboard installed
$bios_info = 'for d in system-manufacturer system-product-name bios-release-date bios-version; do echo "${d^} : " $(sudo dmidecode -s $d); done > /tmp/dmidecodebios.txt;'
$payload = "$bios_info lsmod | grep -oE 'nvidia|amdgpu' -m 1 > /tmp/gpu_driver.txt; cat `$GPU_DETECT_JSON > /tmp/gpu_detect.json; sudo dmidecode -s baseboard-product-name > /tmp/mb_product_name.txt; sudo dmidecode -t 9 > /tmp/dmidecodet9.txt; sudo biosdecode > /tmp/biosdecode.txt; sudo lspci -mm > /tmp/lspcimm.txt; sudo lshw | grep 'pci@' > /tmp/lshwpci.txt; cd /tmp && tar -jcf - gpu_driver.txt gpu_detect.json mb_product_name.txt dmidecodebios.txt dmidecodet9.txt biosdecode.txt lspcimm.txt lshwpci.txt console_output.txt"
plink.exe -ssh -pw `"$pl_passwd`" -batch user@$remote_ip `"$payload`" > ..\data.tar.bz2"
```
#### Naming data archives
Before attaching the archive to an issue/pull request, rename the archive to `data.tar.bz2`. If supplying multiple archives, number the archives like so `data1.tar.bz2`, `data2.tar.bz2`, etc.

### Baseboard support
This section will instruct you how to get the necessary data to report/implement baseboard support.

If you would like to contribute more baseboard support, it's a little bit of a tedious process requiring physical access to the hardware itself. To include support for a baseboard, the script must have a hard-coded map of the PCIe slot order from the BIOS. For now, there is a manual process that can be done to generate this map order. In the future, this process will be automated a bit within the tool.

Depends: dmidecode

Run the following command to get the baseboard name as root:
```bash
dmidecode -s baseboard-product-name
```

#### Creating the $PIRQ map:
 1. Install one GPU in the first available PCIe slot and boot the system.
 2. Run `biosdecode` to read the $PIRQ map if it has one. Look for `PCI Interrupt Routing` and record the `slot number` value in the entry.
 3. Shutdown the system and repeat steps 1 and 2 for the remaining PCIe slots, installing GPUs one by one.

After all slots are populated, you will have a list of `slot number` values in order.


> [!NOTE]
> if $PIRQ is not available, run `dmidecode` instead. Though this table is generally less accurate. So you must verify that it's reporting accurate data before submitting.

For the list of currently supported baseboards, check the [README](../README.md#supported-hardware).

### Testing/Debugging
To ensure that the output of the script is expected, run against the data archive with Debug -> 'Enable Debug Mode'.
Simply extract the data files from the archive in the source directory and click 'Go!' within the script.

To run the script against the test archives in `tests` directory, simply run `.\run_tests.ps1` to ensure all tests pass related to data retrieval.

### Contributing new test archives and `expected.ps1`
The provided test archives in the repo include a `expected.ps1` that can be generated to ensure the output of the scipt is working as expected.
If want to contribute a new test, one must generate the expected script using the Debug -> 'Generate Expected File' to update the data archive with the expected values.

The `expected.ps1` provides the expected values for the the variables created by GLT on runtime. Looking at `tests\Amd\BC-160.tar.bz2` for example:
```poweshell
># contents of expected.ps1
#\tests\Amd\BC-160\BC-160.tar.bz2
$expected_mb_product_name = "TB360-BTC D+"
$expected_PIRQ_FOUND = $False
$expected_pirq_map = $null
$expected_pci_busids = @("00:00.0", "0e:00.0", "11:00.0", "14:00.0", "01:00.0", "04:00.0", "07:00.0", "0a:00.0")
$expected_pci_missing_devices = 0
$expected_pci_info_ids = @(0, 1, 2, 3, 4, 5, 6, 7)
$expected_pci_info_designations = @("PEX16_1", "PEX16_2", "PEX16_3", "PEX16_4", "PEX16_5", "PEX16_6", "PEX16_7", "PEX16_8")
$expected_gpu_busids = @("MISSING", "10:00.0", "13:00.0", "16:00.0", "03:00.0", "06:00.0", "09:00.0", "0c:00.0")
$expected_gpu_missing_devices = 1
$expected_gpu_ids = @("-", "0", "1", "2", "3", "4", "5", "6")
$expected_gi_indicators = $null
$expected_total_detected_cards = 7
```
`run_tests.ps1` simply compares the expected values with the output of the script to ensure all the data retrieval was successful.