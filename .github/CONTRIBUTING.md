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
