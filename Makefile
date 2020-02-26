STAGES=$(wildcard boot/*.asm)
BOOT=${STAGES:.asm=.bin}

C_SOURCES=$(wildcard lib/*.c kernel/*.c drivers/*.c)
HEADERS = $(wildcard include/kernel/*.h drivers/*.h)

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
	gcc-i386 \
	-I kernel \
	-I./include \
	-ffreestanding -c $< -o $@


boot/stage2.bin: boot/stage2.asm kernel.bin
	$(eval size=$(shell stat -L -f %z kernel.bin))
	$(eval sectors=$(shell echo $$(( $(size) / 512 )) ))
	$(eval remainder=$(shell echo $$(( $(size) % 512)) ))
	$(eval sectors=$(shell if [ $(remainder) -gt 0 ]; then echo $$(( $(sectors) + 1)); else echo $(sectors); fi ))
	nasm -f bin boot/stage2.asm -dKERNEL_SIZE=$(sectors) -o boot/stage2.bin

%.bin : %.asm
	nasm -f bin $< -o $@


clean:
	rm -f boot/*.bin kernel/*.o drivers/*.o *.o *.bin os-image
