kernel.o: kernel.c
	gcc-i386 -ffreestanding -c $< -o $@

kernel_entry.o: kernel_entry.asm
	nasm $< -f elf -o $@

kernel.bin: kernel_entry.o kernel.o
	ld-i386 -o kernel.bin -Ttext 0x2200 $^ --oformat binary

stage1.bin: stage1.asm
	nasm -f bin $< -o $@

stage2.bin: stage2.asm
	nasm -f bin $< -o $@

boot.bin: stage1.bin stage2.bin kernel.bin
	cat $^ > $@

all: boot.bin

clean:
	rm -rf *.bin
	rm -rf *.o
