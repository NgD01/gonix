arch ?= x86_64
kernel := build/kernel-$(arch).bin
iso := build/gonix-$(arch).iso

ldscript := src/arch/$(arch)/linker.ld
grubcfg := src/arch/$(arch)/grub.cfg

asm_source_files := $(wildcard src/arch/$(arch)/*.asm)
asm_object_files := $(patsubst src/arch/$(arch)/%.asm, build/arch/$(arch)/%.o, $(asm_source_files))

.PHONY: all clean run iso

all: $(kernel)

clean:
	@rm -r build

run: $(iso)
	@qemu-system-x86_64 -drive format=raw,file=$(iso)

iso: $(iso)

$(iso): $(kernel) $(grubcfg)
	@mkdir -p build/isofiles/boot/grub
	@cp $(kernel) build/isofiles/boot/kernel.bin
	@cp $(grubcfg) build/isofiles/boot/grub/grub.cfg
	@grub-mkrescue -o $(iso) build/isofiles 2> /dev/null

$(kernel): $(asm_object_files) $(ldscript)
	@ld -n -T $(ldscript) -o $(kernel) $(asm_object_files)

build/arch/$(arch)/%.o: src/arch/$(arch)/%.asm
	@mkdir -p $(shell dirname $@)
	@nasm -felf64 $< -o $@
