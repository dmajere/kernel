STAGES=$(wildcard boot/*.asm)
BOOT=${STAGES:.asm=.bin}

C_SOURCES=$(wildcard kernel/*.c drivers/*.c)
HEADERS = $(wildcard kernel/*.h drivers/*.h)
OBJ=${C_SOURCES:.c=.o}

KERNEL_OFFSET=0x8000

hda: os-image
	qemu os-image

fda: os-image
	qemu -fda os-image

os-image: boot_sect.bin kernel.bin
	cat $^ > $@

kernel.bin: kernel/kernel_entry.o ${OBJ}
	ld-i386 -o $@ -Ttext ${KERNEL_OFFSET} $^ --oformat binary

boot_sect.bin: ${BOOT}
	cat boot/stage1.bin boot/stage2.bin > $@

%.o : %.asm
	nasm $< -f elf -o $@


%.o: %.c ${HEADERS}
	gcc-i386 -ffreestanding -c $< -o $@

%.bin : %.asm
	nasm -f bin $< -o $@


clean:
	rm -f boot/*.bin kernel/*.o drivers/*.o *.o *.bin os-image
