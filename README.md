# Simple Hostboot Bootloader (HBB)

This is a simple replacement for the Hostboot boot loader which is
what the SBE loads and runs once it's initialised the system. It will
load the payload data from a fixed PNOR flash location (0x00425000
which by default is the HBI partition).

## Prerequisites

Building requires the `ecc` utility which can be found at
https://github.com/open-power/ffs.git along with the
`create-container` utility built as part of the skiboot
(https://github.com/open-power/skiboot.git) build process.

## Building

`make`

## Installation

Copy the resulting `HBB` file to the HBB PNOR flash partition. On a
OpenBMC system in development mode this can be achieved by copying it
to /usr/local/share/pnor/HBB.
