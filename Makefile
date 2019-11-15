CROSS	?= powerpc64-buildroot-linux-gnu
CFLAGS	= -g -nostdlib -Iinclude

all: HBB

head: src/head.S p9.dtb
	$(CROSS)-gcc $(CFLAGS) -o $@ $<

head.bin: head
	$(CROSS)-objcopy -O binary $< $@

head.bin.stb: head.bin
	./sign-with-local-keys.sh $< $@ ./keys HBB

HBB: head.bin.stb
	dd if=$< of=$@.pad bs=932063 count=1 conv=sync
	ecc --inject $@.pad --output $@ --p8

p9.dtb: p9.dts
	dtc -I dts $< -O dtb > $@

clean:
	rm -f p9.dtb head.* HBB HBB.*
