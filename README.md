# Simplified Hostboot Bootloader (HBB)

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

# Creating a small cache-contained Linux system

The simplified Hostboot boot loader is designed primarily to load and
boot a small Linux kernel image and rootfs. A suitable kernel tree is
available at https://github.com/apopple/linux/tree/bare .

## Creating an initramfs

Due to the limited amount of available ram (~10MB) it is critical to
keep the initial ram fs so as to leave enough memory free to run. In
order to achieve this a minimal Busybox build may be used in
conjunction with a description of the initramfs like the below saved
to a file:

```
dir /dev 755 0 0
nod /dev/console 644 0 0 c 5 1
nod /dev/ttyS0 644 0 0 c 4 64
dir /bin 755 1000 1000
slink /bin/sh busybox 777 0 0
file /bin/busybox <PATH TO BUSYBOX BINARY> 755 0 0
dir /proc 755 0 0
dir /sys 755 0 0
dir /mnt 755 0 0
slink /init /bin/busybox 755 0 0
slink /bin/ls /bin/busybox 777 0 0
slink /bin/mount /bin/busybox 777 0 0
slink /bin/echo /bin/busybox 777 0 0
slink /bin/cat /bin/busybox 777 0 0
```

## Building

In order to boot to userspace an initramfs is required. By setting
CONFIG_INITRAMFS_SOURCE to point at the description file created above
it's possilbe to get the kernel to build the cpio as part of the build
process. See linux/Documentation/early-userspace/README for a more in
depth description of how this works.

```
git clone -b bare https://github.com/apopple/linux.git
ARCH=powerpc CROSS_COMPILE=powerpc64-buildroot-linux-gnu- make bare_defconfig
ARCH=powerpc CROSS_COMPILE=powerpc64-buildroot-linux-gnu- make vmlinux
strip vmlinux -o vmlinux.bin
objcopy -O binary vmlinux.bin
```

# Booting

The resulting vmlinux.bin should be copied to the HBI partition so the
simplified HBB can load it. However due to issues with the vpnor
implementation this must be copied into the HBI partition of the
system flash image. The simplest way of doing this is to download an
existing PNOR image and use pflash (part of
https://github.com/open-power/skiboot) to update it like so:

```
wget "https://openpower.xyz/job/openpower/job/openpower-op-build/label=slave,target=witherspoon/lastSuccessfulBuild/artifact/images/witherspoon.pnor"
pflash -f -F witherspoon.pnor -p vmlinux.bin -P HBI
```

The resulting `witherspoon.pnor` can then be copied onto the BMC and
activated with:

`mboxctl --backend file:/tmp/spoon2.img && mboxctl --backend vpnor`

Assuming the HBB file have been copied to `/usr/local/share/pnor` the
system should now be ready to boot with `obmcutil poweron`.

# Sample output

All going well the BMC console should produce something like the
following at power on:

```
--== Welcome to SBE - CommitId[0x1410677b] ==--
istep 3.19
istep 3.20
istep 3.21
istep 3.22
istep 4.1
istep 4.2
istep 4.3
istep 4.4
istep 4.5
istep 4.6
istep 4.7
istep 4.8
istep 4.9
istep 4.10
istep 4.11
istep 4.12
istep 4.13
istep 4.14
istep 4.15
istep 4.16
istep 4.17
istep 4.18
istep 4.19
istep 4.20
istep 4.21
istep 4.22
istep 4.23
istep 4.24
istep 4.25
istep 4.26
istep 4.27
istep 4.28
istep 4.29
istep 4.30
istep 4.31
istep 4.32
istep 4.33
istep 4.34
istep 5.1
istep 5.2
SBE starting hostboot
Clearing L3 cachLoading kernel image
Booting linux...** 19 printk messages dropped **
  always          = 0x0000006f8b5c91a1
cpu_user_features = 0xdc0061c2 0xaee00000
mmu_features      = 0x3c006041
firmware_features = 0x0000000000000000
hash-mmu: ppc64_pft_size    = 0x0
hash-mmu: kernel vmalloc start   = 0xc008000000000000
hash-mmu: kernel IO start        = 0xc00a000000000000
hash-mmu: kernel vmemmap start   = 0xc00c000000000000
physical_start    = 0x8000000
-----------------------------------------------------
barrier-nospec: using ORI speculation barrier
barrier-nospec: patched 208 locations
Top of RAM: 0x8a00000, Total RAM: 0x8a00000
Memory hole size: 0MB
Zone ranges:
  Normal   [mem 0x0000000000000000-0x00000000089fffff]
Movable zone start for each node
Early memory node ranges
  node   0: [mem 0x0000000000000000-0x00000000089fffff]
Initmem setup node 0 [mem 0x0000000000000000-0x00000000089fffff]
On node 0 totalpages: 35328
  Normal zone: 483 pages used for memmap
  Normal zone: 0 pages reserved
  Normal zone: 35328 pages, LIFO batch:7
percpu: Embedded 19 pages/cpu s47776 r0 d30048 u77824
pcpu-alloc: s47776 r0 d30048 u77824 alloc=19*4096
pcpu-alloc: [0] 0
Built 1 zonelists, mobility grouping on.  Total pages: 34845
Kernel command line: console=ttyS0 dhash_entries=1 ihash_entries=1 single
Dentry cache hash table entries: 1 (order: -9, 8 bytes)
Inode-cache hash table entries: 1 (order: -9, 8 bytes)
Memory: 5296K/141312K available (1480K kernel code, 148K rwdata, 120K rodata, 544K init, 134K bss, 136016K reserved, 0K cma-reserved)
SLUB: HWalign=128, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
rcu: Hierarchical RCU implementation.
rcu:    RCU restricting CPUs from NR_CPUS=2 to nr_cpu_ids=1.
rcu: RCU calculated value of scheduler-enlistment delay is 10 jiffies.
rcu: Adjusting geometry for rcu_fanout_leaf=16, nr_cpu_ids=1
NR_IRQS: 32, nr_irqs: 32, preallocated irqs: 16
time_init: decrementer frequency = 475.000000 MHz
time_init: processor frequency   = 3800.000000 MHz
time_init: 32 bit decrementer (max: 7fffffff)
clocksource: timebase: mask: 0xffffffffffffffff max_cycles: 0xdb195f9191, max_idle_ns: 881590502282 ns
clocksource: timebase mult[10d7943] shift[23] registered
clockevent: decrementer mult[7999999a] shift[32] cpu[0]
pid_max: default: 4096 minimum: 301
Mount-cache hash table entries: 512 (order: 0, 4096 bytes)
Mountpoint-cache hash table entries: 512 (order: 0, 4096 bytes)
smp: Bringing up secondary CPUs ...
smp: Brought up 1 node, 1 CPU
Using standard scheduler topology
devtmpfs: initialized
clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604462750000 ns
futex hash table entries: 16 (order: -1, 2048 bytes)
clocksource: Switched to clocksource timebase
hugetlbfs: disabling because there are no supported hugepage sizes
workingset: timestamp_bits=62 max_order=11 bucket_order=0
Serial: 8250/16550 driver, 4 ports, IRQ sharing disabled
printk: console [ttyS0] disabled
80060300d00103f8.serial: ttyS0 at MMIO 0x80060300d00103f8 (irq = 0, base_baud = 115200) is a 16550
printk: console [ttyS0] enabled
i2c /dev entries driver
drmem: No dynamic reconfiguration memory found
random: get_random_bytes called from 0xc000000008037f00 with crng_init=0
Freeing unused kernel memory: 544K
This architecture does not have kernel memory protection.
Run /init as init process
init started: BusyBox v1.31.1 (2019-11-15 11:01:07 AEDT)
starting pid 21, tty '': '-/bin/sh'


BusyBox v1.31.1 (2019-11-15 11:01:07 AEDT) built-in shell (ash)

#
```

# TODO

- The HBB console message output gets corrupted/overwritten as the
  extremely dumb HBB console driver does not check for UART FIFO
  overflow.
