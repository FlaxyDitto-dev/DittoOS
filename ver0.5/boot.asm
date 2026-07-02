[org 0x7c00]
bits 16

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Reset floppy drive hardware
    mov ah, 0x00
    mov dl, 0x00        ; Drive A:
    int 0x13

    ; Load DittoOS Kernel & Apps (8 sectors total = 4KB space)
    mov ah, 0x02        ; BIOS Read Sectors
    mov al, 8           ; Read 8 sectors from disk
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Start reading at Sector 2 (Right after boot sector)
    mov dh, 0           ; Head 0
    mov dl, 0           ; Drive A:
    mov bx, 0x7E00      ; Destination address in RAM
    int 0x13
    jc load_error       

    jmp 0x0000:0x7E00   ; Jump directly to the loaded Kernel!

load_error:
    jmp load_error      

times 510-($-$$) db 0   
dw 0xAA55