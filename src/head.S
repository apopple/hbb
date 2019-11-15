#include <bitutils.h>
#include <processor.h>
#include <asm-utils.h>

/* TODO: It looks like the SBE passes us this information so we should
	either read it from there or read it directly from the
	LPC_BASE_REG (0x90040) SCOM register rather than hardcoding
	it. */
#define LPC_BASE_ADDR	(0x8006030000000000)
#define LPC_IO_SPACE	0xd0010000
#define LPC_FW_SPACE	0xf0000000

/* TODO: We sould read this from the TOC, but for now lets use the HBI
	partition as by default that seems to be the biggest */
#define PAYLOAD_OFFSET (0x10000000 - 0x4000000 + 0x425000)

/* Real address to load the kernel, needs to not overlap with this
   bootloader which gets loaded at 0x8000000 */
#define KERNEL_LOAD_ADDR (0x210000)

	. = 0
.global _start
_start:
	b	start

	/* QEMU puts us here */
	. = 0x10
	b	start

/* Print a message from r3 to the UART. Clobbers r4, r5 and
 * cr0.
 * TODO: Not overflow the fifo */
print:
	LOAD_IMM64(%r4, LPC_BASE_ADDR + LPC_IO_SPACE + 0x3f8)
	subi	%r3,%r3,1

1:	lbzu	%r5,1(%r3)
	cmpi	cr0,0,%r5,0
	beqlr	cr0
	stbcix	%r5,0,%r4
	b	1b

start:
	/* Fixup our MSR (remove TA) */
	LOAD_IMM64(%r3, (MSR_HV | MSR_SF))
	mtmsrd	%r3,0
	nop
	li	%r20,0
	oris	%r20,0,0

	/* Check our PIR, avoid threads */
	mfspr	%r31,SPR_PIR
	and.	%r0,%r31,%r26
	bne	secondary_wait

	/* Initialize per-core SPRs */
	bl init_shared_sprs

	/* Make sure we are in SMT medium */
	smt_medium

	/* Initialize thread SPRs */
	bl init_replicated_sprs

	LOAD_IMM64(%r3, cache - _start)
	bl print

	/* Initialise the 10MB L3 (RA 0x8000000 - 0x8a00000) */
	LOAD_IMM64(%r3, ((END - _start) / 128 + 1) * 128)
	LOAD_IMM64(%r4, 0xa00000)

	subf	%r4,%r3,%r4
	srdi	%r4,%r4,7
	mtctr	%r4

1:	dcbz	0, %r3
	addi	%r3,%r3,128
	bdnz	1b

	LOAD_IMM64(%r3, loading - _start)
	bl print

	/* Start loading the image */
	LOAD_IMM64(%r3, KERNEL_LOAD_ADDR)
	LOAD_IMM64(%r4, 0xa00000)
	LOAD_IMM64(%r5, LPC_BASE_ADDR + LPC_FW_SPACE + PAYLOAD_OFFSET)
	subf	%r4,%r3,%r4
	srdi	%r4,%r4,3
	mtctr	%r4
	subi	%r3,%r3,0x8

	/* Copy image in */
1:	ldcix	%r4,0,%r5
	addi	%r5,%r5,0x8
	stdu	%r4,8(%r3)
	bdnz	1b

	/* Load device-tree high */
	LOAD_IMM64(%r3,0x900000)
	LOAD_IMM64(%r4,0x901000)
	LOAD_IMM64(%r5,device_tree - _start)
	subf	%r4,%r3,%r4
	srdi	%r4,%r4,3
	mtctr	%r4
	subi	%r5,%r5,0x8
	subi	%r3,%r3,0x8

	/* Copy image in */
1:	ldu	%r4,8(%r5)
	stdu	%r4,8(%r3)
	bdnz	1b

	/* Print greeting to uart */
	LOAD_IMM64(%r3,greeting - _start)
	bl	print

	/* kexec style kernel entry with device tree at 0x900000 */
1:	LOAD_IMM64(%r3, 0x900000)
	mfspr	%r4,SPR_HRMOR
	or	%r3,%r3,%r4
	LOAD_IMM64(%r5, 0)

	/* r4 is the kernel address */
	LOAD_IMM64(%r4, KERNEL_LOAD_ADDR)
	mtctr	%r4

	bctr

secondary_wait:
	b	.

/* Functions to initialize replicated and shared SPRs to sane
 * values. This is called at boot and on soft-reset
 */
.global init_shared_sprs
init_shared_sprs:
	li	%r0,0
	mtspr	SPR_AMOR, %r0

	mfspr	%r3,SPR_PVR
	srdi	%r3,%r3,16
	cmpwi	cr0,%r3,PVR_TYPE_P7
	beq	1f
	cmpwi	cr0,%r3,PVR_TYPE_P7P
	beq	2f
	cmpwi	cr0,%r3,PVR_TYPE_P8E
	beq	3f
	cmpwi	cr0,%r3,PVR_TYPE_P8
	beq	3f
	cmpwi	cr0,%r3,PVR_TYPE_P8NVL
	beq	3f
	cmpwi	cr0,%r3,PVR_TYPE_P9
	beq	4f
	/* Unsupported CPU type... what do we do ? */
	b	9f

1:	/* P7 */
	mtspr	SPR_SDR1, %r0
	/* TSCR: Value from pHyp */
	LOAD_IMM32(%r3,0x880DE880)
	mtspr	SPR_TSCR, %r3
	b	9f

2:	/* P7+ */
	mtspr	SPR_SDR1, %r0
	/* TSCR: Recommended value by HW folks */
	LOAD_IMM32(%r3,0x88CDE880)
	mtspr	SPR_TSCR, %r3
	b	9f

3:	/* P8E/P8 */
	mtspr	SPR_SDR1, %r0
	/* TSCR: Recommended value by HW folks */
	LOAD_IMM32(%r3,0x8ACC6880)
	mtspr	SPR_TSCR, %r3

	/* HID0: Clear bit 13 (enable core recovery)
	 *       Clear bit 19 (HILE)
	 */
	mfspr	%r3,SPR_HID0
	li	%r0,1
	sldi	%r4,%r0,(63-13)
	sldi	%r5,%r0,(63-19)
	or	%r0,%r4,%r5
	andc	%r3,%r3,%r0
	sync
	mtspr	SPR_HID0,%r3
	mfspr	%r3,SPR_HID0
	mfspr	%r3,SPR_HID0
	mfspr	%r3,SPR_HID0
	mfspr	%r3,SPR_HID0
	mfspr	%r3,SPR_HID0
	mfspr	%r3,SPR_HID0
	isync
	/* HMEER: Enable HMIs for core recovery and TOD errors. */
	LOAD_IMM64(%r0,SPR_HMEER_HMI_ENABLE_MASK)
	mfspr	%r3,SPR_HMEER
	or	%r3,%r3,%r0
	sync
	mtspr	SPR_HMEER,%r3
	isync
	/* RPR (per-LPAR but let's treat it as replicated for now) */
	LOAD_IMM64(%r3,0x00000103070F1F3F)
	mtspr	SPR_RPR,%r3
	b	9f

4:	/* P9 */
	/* TSCR: Recommended value by HW folks */
	LOAD_IMM32(%r3,0x80287880)
	mtspr	SPR_TSCR, %r3
	/* HID0: Clear bit 5 (enable core recovery)
	 *       Clear bit 4 (HILE)
	 */
	mfspr	%r3,SPR_HID0
	li	%r0,1
	sldi	%r4,%r0,(63-5)
	sldi	%r5,%r0,(63-4)
	or	%r0,%r4,%r5
	andc	%r3,%r3,%r4
	or	%r3,%r3,%r5
	sync
	mtspr	SPR_HID0,%r3
	isync
	/* HMEER: Enable HMIs for core recovery and TOD errors. */
	LOAD_IMM64(%r0,SPR_HMEER_HMI_ENABLE_MASK)
	mfspr	%r3,SPR_HMEER
	or	%r3,%r3,%r0
	sync
	mtspr	SPR_HMEER,%r3
	isync

	LOAD_IMM64(%r3,0x00000103070F1F3F)
	mtspr	SPR_RPR,%r3
9:	blr

.global init_replicated_sprs
init_replicated_sprs:
	mfspr	%r3,SPR_PVR
	srdi	%r3,%r3,16
	cmpwi	cr0,%r3,PVR_TYPE_P7
	beq	1f
	cmpwi	cr0,%r3,PVR_TYPE_P7P
	beq	1f
	cmpwi	cr0,%r3,PVR_TYPE_P8E
	beq	3f
	cmpwi	cr0,%r3,PVR_TYPE_P8
	beq	3f
	cmpwi	cr0,%r3,PVR_TYPE_P8NVL
	beq	3f
	cmpwi	cr0,%r3,PVR_TYPE_P9
	beq	4f
	/* Unsupported CPU type... what do we do ? */
	b	9f

1:	/* P7, P7+ */
	/* LPCR: sane value */
	LOAD_IMM64(%r3,0x0040000000000004)
	mtspr	SPR_LPCR, %r3
	sync
	isync
	LOAD_IMM64(%r3,0x0)
	mtspr	SPR_DSCR,%r3
	b	9f

3:	/* P8, P8E */
	/* LPCR: sane value */
	LOAD_IMM64(%r3,0x0040000000000000)
	mtspr	SPR_LPCR, %r3
	sync
	isync
	LOAD_IMM64(%r3,0x0)
	mtspr	SPR_DSCR,%r3
	b	9f

4:	/* P9 */
	/* LPCR: sane value */
	LOAD_IMM64(%r3,0x0040000000000000)
	mtspr	SPR_LPCR, %r3
	sync
	isync
	/* DSCR: Stride-N Stream Enable */
	LOAD_IMM64(%r3,0x0000000000000010)
	mtspr	SPR_DSCR,%r3

9:	blr

cache:
	.string "Clearing L3 cache\r\n"

loading:
	.string "Loading kernel image\r\n"

greeting:
	.string "Booting linux...\r\n"

	.align 4
device_tree:
	.incbin "p9.dtb"
END:
