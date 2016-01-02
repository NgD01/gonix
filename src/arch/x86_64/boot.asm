global start
extern long_mode_start

section .text
bits 32
start:
  ; initialize the stack
  mov esp, stack_top

  call check_multiboot
  call check_cpuid
  call check_long_mode

  call setup_page_tables
  call enable_paging

  ; load 64-bit GDT
  lgdt [gdt64.pointer]

  ; update selectors
  mov ax, gdt64.data
  mov ss, ax
  mov ds, ax
  mov es, ax

  jmp gdt64.code:long_mode_start

; create page tables and ensure entries are mapped
setup_page_tables:
  ; map first p4 to p3
  mov eax, p3_table
  or eax, 0b11  ; present, writeable
  mov [p4_table], eax

  ; map first p3 to p2
  mov eax, p2_table
  or eax, 0b11  ; present, writeable
  mov [p3_table], eax

  ; map p2 entries to 2MiB pages
  mov ecx, 0

.map_p2_table:
  ; map ecx-th p2 entry to a huge page at 2MiB * ecx
  mov eax, 0x200000
  mul ecx
  or eax, 0b10000011  ; present, writeable, huge
  mov [p2_table + ecx * 8], eax

  inc ecx
  cmp ecx, 512
  jne .map_p2_table

  ret

; enable paging
enable_paging:
  ; load p4 to cr3
  mov eax, p4_table
  mov cr3, eax

  ; enable PAE flag in cr4
  mov eax, cr4
  or eax, 1 << 5
  mov cr4, eax

  ; set long mode bit in EFER MSR
  mov ecx, 0xC0000080
  rdmsr
  or eax, 1 << 8
  wrmsr

  ; enable paging in cr0
  mov eax, cr0
  or eax, 1 << 31
  mov cr0, eax

  ret

; print 'ERR: ' + error code in al.
error:
  mov dword [0xb8000], 0x4f524f45
  mov dword [0xb8004], 0x4f3a4f52
  mov dword [0xb8008], 0x4f204f20
  mov byte [0xb800a], al
  hlt

; check for multiboot magic number. error code 0.
check_multiboot:
  cmp eax, 0x36d76289
  jne .no_multiboot
  ret
.no_multiboot:
  mov al, "0"
  jmp error

; check for CPUID support. error code 1.
check_cpuid:
  pushfd
  pop eax
  mov ecx, eax
  xor eax, 1 << 21
  push eax
  popfd
  pushfd
  pop eax
  push ecx
  popfd
  xor eax, ecx
  jz .no_cpuid
  ret
.no_cpuid:
  mov al, "1"
  jmp error

; check for long mode support. error code 2.
check_long_mode:
  mov eax, 0x80000000
  cpuid
  cmp eax, 0x80000001
  jb .no_long_mode
  mov eax, 0x80000001
  cpuid
  test edx, 1 << 29
  jz .no_long_mode
  ret
.no_long_mode:
  mov al, "2"
  jmp error


section .bss
align 4096
p4_table:
  resb 4096
p3_table:
  resb 4096
p2_table:
  resb 4096
stack_bottom:
  resb 64
stack_top:


section .rodata
gdt64:
  dq 0
.code: equ $ - gdt64
  dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53)  ; code segment
.data: equ $ - gdt64
  dq (1<<44) | (1<<47) | (1<<41)  ; data segment
.pointer:
  dw $ - gdt64 - 1
  dq gdt64

