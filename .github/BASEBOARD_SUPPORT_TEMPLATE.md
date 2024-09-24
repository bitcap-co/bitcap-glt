<!-- This template is used for both issues and pulls -->
<!-- If creating a pull request, please also fill out the bottom two sections -->

<!--- Provide Add baseboard support: <PUT_BASEBOARD_NAME_HERE> in the Title above -->

## Baseboard Specification
Baseboard Name:

CPU Type:

Chipset:

Current BIOS Version:

Number of PCIe slots:

- [ ] $PIRQ available?
- [ ] DMI Table available?
- [ ] ACPI available?

If $PIRQ is available, provide $PIRQ PCIe map (see [CONTRIBUTING](./CONTRIBUTING.md#baseboard-support))

| Physical Slot (starting at CPU) | BIOS Slot Number |
|---------------|------------------|
| Slot 1        |                |
| Slot 2        |                |
| Slot 3        |                |
| Slot 4        |                |
| Slot 5        |                |
| Slot 6        |                |
| Slot 7        |                |
| Slot 8        |                |
| Slot 9        |                |
| Slot 10       |                |
| Slot 11       |                |
| Slot 12       |                |

<!-- You can erase any parts of this template that are not applicable. -->

## Remote Host Environment
<!-- Provide as much information on the remote host environment -->
  OS:

  Kernel Version: (`uname -srm`):

  Baseboard Name: (`dmidecode -s baseboard-product-name`):

  Dmidecode/biosdecode Version: (`dmidecode --v`):

  Installed GPUs:

  GPU Driver:


## Detailed Description
<!--- Provide a detailed description of the change or addition you are proposing -->

## Screenshots (if appropriate):

## -- Pull Request --

<!-- if fixing an existing issue -->
Fixes #

- [ ] ran in debug mode?
- [ ] output is what is expected?

## Implemention/Fixes
<!-- Provide a short summary of changes of how support was implemented and any fixes needed -->

## Provided artifacts
<!-- Provide example system output used for testing -->
