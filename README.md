## GPU Lookup Table (GLT)
GPU Lookup Table is a small utility script allowing the user to map all GPU
devices to their corresponding PCIE slot addresses/locations on a remote system.
Interacted with a GUI window.

## The Problem

GPU miners are traditionally hard to troubleshoot because 6, 8, or even 12 GPU devices can be in a single chassis at a time. Even with special management software and tools, one problem still exists in most systems. There is no way to know exactly which card is the “bad card” when an issue arises. Specifically, knowing which card to physically pull out of the system to further troubleshoot its problem.


PCI devices are given what is known as a bus address (looks something like this: 01:00.0). As you will see in HiveOS for example, it shows a table of the detected GPUs in the system with its bus address on the left-hand side. While this gives you a unique identifier for each GPU detected in the rig, it doesn’t tell where they are on the motherboard in the real world.

Supported Hardware

Without getting too much of the details here, essentially there are two different places that the script uses to gather PCI information. These both are located in read-only memory and contain data provided by the OEM/BIOS manufacturer. This makes it very dependent on the OEM to give accurate information. Information provided by the OEM may be incomplete, inaccurate, or wrong. This is why the data provided by the script can’t be 100% trusted.

**The following motherboards can all be supported. The table below shows the current status of support.

Status of Supported Motherboards:

| Baseboard Product Name | Current Status |
| -------------- |  ------------ |
| ONDA B250 (12X) | Y |
| CRESCENTBAY | Y |
| BTC-T37/BTC-S37 (8X) | Y|
| TB360-BTC | Y |
| TB85 | Y |
| ASUS Prime Z390 | Y |
| Gigabyte Z390 UD| N<sup>1</sup> |
| OctoMiner 12X (XTREME/ULTRA) | Y |
| OctoMiner 8X (XTREME/ULTRA) | Y |
| 'skylake' 8X | Y |
| 'B75' | Y |
| 'B85' | N |

Y = Currently Supported
N = Not Currently Supported

<sup>1</sup> Gigabyte Z390 UD on BIOS version F10 or newer will not be supported due to BIOS limitations.

## Common Errors and Warnings
This script is definitely not perfect! There will probably be bugs/errors that one will run into. This section will go over the more common ones and give some insight into meaning and what can be done.

#### Unsupported: the detected motherboard model is not supported
This one should be pretty self-explanatory. Whatever motherboard the remote system has is not supported by the script.

What can be done: Report the issue ( See [Reporting Issues/Contributing](./README.md#reporting-issuescontributing)) and support will be added shortly if possible!

#### Offline Miner: unable to fetch miner
The script will also validate that the hostname of the miner is reachable before trying to connect. If the miner is ‘Service Offline’, the script will show this error.

The script can only work if the miner is online.
What can be done: If the miner is on the network but AM is not able to see it, the script will say that it’s offline. To bypass this, you can check the ‘Bypass AM Validation’ option.

#### ‘$PIRQ Table not found’ Warning
The script is just letting the user know that it wasn’t able to find the preferred table of information. The script will continue but uses the generally less accurate DMI table to figure out the order of PCIE slots. As the following warning says, this may lead to inaccurate and incomplete output from the script.


## Reporting Issues/Contributing
See [CONTRIBUTING](./.github/CONTRIBUTING.md) to see how to report issues or contribute pull requests.
