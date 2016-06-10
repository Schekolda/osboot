run: all
	@echo -e "\n=> 4: Run, baby, run!"
	qemu-system-i386 -fda disk.img -boot a

all: hello floppy_disk patch_disk

hello:
	@echo -e "\n=> 1: Compile"
	@echo "compile boot.asm"
	nasm -l boot.lst -f bin -o boot.bin boot.asm
#	@echo "compile boot-2nd.asm"
#	nasm -l boot-2nd.lst -f bin -o boot-2nd.bin boot-2nd.asm

floppy_disk:
	@echo -e "\n=> 2: Make floppy disk image"
	dd if=/dev/zero of=disk.img bs=1024 count=1440

patch_disk:
	@echo -e "\n=> 3: Write program to floppy image"
	@echo "write boot sector"
	dd if=boot.bin of=disk.img conv=notrunc
#	@echo "write 2nd sector"
#	dd if=boot-2nd.bin of=disk.img bs=512 seek=1 conv=notrunc

clean:
	rm *.bin *.lst disk.img

