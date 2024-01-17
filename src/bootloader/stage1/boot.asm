[bits 16]
org 0x7C00

%define ENDL 0x0D, 0x0A


;
; FAT12 header
;
jmp short start
nop

bdb_oem:                  db "MSWIN4.1"      ; 8 bytes
bdb_bytes_per_sector:     dw 512  
bdb_sectors_per_cluster:  db 1   
bdb_reserved_sectors:     dw 1    
bdb_number_of_fats:       db 2    
bdb_dir_entries_count:    dw 0E0h
bdb_total_sectors:        dw 2880            ;2880 * 512 = 1.44MB
bdb_media_descriptor:     db 0F0h            ;F0 = 3.5" 1.44MB floppy
bdb_sectors_per_fat:      dw 9               ;9 sectors per fat
bdb_sectors_per_track:    dw 18              
bdb_heads:                dw 2               
bdb_hidden_sectors:       dd 0
bdb_large_sectors:        dd 0

; extended boot record
ebr_drive_number:   db 0             ;0x00 floppy, 0x80 hard drive
                    db 0             ;reserved
ebr_signature:      db 29h
ebr_volume_id:      dd 12h, 34h, 56h, 78h           
ebr_volume_label:   db "NO NAME    "  ;11 bytes 
ebr_system_id:      db "FAT12   "     ;8 bytes

start:

    ;set up data segments
    mov ax, 0   ;can not directly write to ds and es
    mov ds, ax
    mov es, ax

    ;set up stack
    mov ss, ax
    mov sp, 0x7C00  ;stack grows downward hence wont overwrite the os

    push es;
    push word .after
    retf
.after:

    ; read something from the floppy
    ; BIOS should set dl to the drvie number
    mov [ebr_drive_number], dl

    ;;print hello world
    mov si, msg_loading
    call puts

    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3f ;remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx

    inc dh
    mov [bdb_heads], dh         ;head count

    ; read FAT root direfctory
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_number_of_fats]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors]
    push ax

    mov ax, [bdb_sectors_per_fat]
    shl ax, 5
    xor dx, dx
    div word [bdb_bytes_per_sector]

    test dx, dx
    jz .root_dir_after
    inc ax

.root_dir_after:

    ;read root dir
    mov cl, al
    pop ax
    mov dl, [ebr_drive_number];
    mov bx, buffer
    call disk_read


    ;look for stage2.bin
    xor bx, bx
    mov di, buffer
    
    
.search_stage2:
    mov si, stage2_file_name
    mov cx, 11
    push di

    repe cmpsb
    pop di
    je .found_stage2

    add di, 32              ;size of directory entry
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_stage2

    jmp stage2_not_found


.found_stage2:
    mov ax, [di+26]       ;cluster number
    mov [stage2_cluster], ax

    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov di, [ebr_drive_number]
    call disk_read

    ;read stage2 and process FAT chain
    mov bx, stage2_LOAD_SEGMENT
    mov es, bx
    mov bx, stage2_LOAD_OFFSET

.load_stage2:

    mov ax, [stage2_cluster]
    add ax, 31

    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ;comput next cluster
    mov ax, [stage2_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after
.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0xFF8
    jae .read_finshed

    mov [stage2_cluster], ax
    jmp .load_stage2


.read_finshed:
    mov dl, [ebr_drive_number]
    
    mov ax, stage2_LOAD_SEGMENT
    mov ds, ax
    mov es, ax

    jmp stage2_LOAD_SEGMENT:stage2_LOAD_OFFSET

    mov si, msg_read_failed

    jmp wait_key_and_reboot ;should not reach here

    cli
    hlt

; Error handling
;
 floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

stage2_not_found:
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for keypress
    jmp 0FFFFh:0                ; jump to beginning of BIOS, should reboot
.halt:
    cli
    hlt



puts:
    push si
    push ax
    push bx

.loop:
    lodsb
    or al, al
    jz .done

    mov ah, 0x0E
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret

    

;
;Disk rotuines
;

; Converts a LBA to CHS
; Params:
;   - ax: LBA address
; Returns:
;   -cx [bits 0-5]: sector number
;   -cx [bits 6-15]: cylinder
;   -dh: head
;
 lba_to_chs:

        push ax
        push dx

        xor dx, dx                          ; dx = 0
        div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                            ; dx = LBA % SectorsPerTrack

        inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
        mov cx, dx                          ; cx = sector

        xor dx, dx                          ; dx = 0
        div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                            ; dx = (LBA / SectorsPerTrack) % Heads = head
        mov dh, dl                          ; dh = head
        mov ch, al                          ; ch = cylinder (lower 8 bits)
        shl ah, 6
        or cl, ah                           ; put upper 2 bits of cylinder in CL

        pop ax
        mov dl, al                          ; restore DL
        pop ax
        ret

;
;Read sectors from a disk
;Parmaeters:
;    -ax: lba address
;    -cl: numbers of secotrs to read
;    -dl: drive num
;    -es:bx: memory address where to store read data
;
disk_read:
    push ax
    push bx
    push cx
    push dx             
    push di

    push cx
    call lba_to_chs     ;convert lba to chs
    pop ax              ;al has the chs address and ax no longer needed
    
    mov ah, 02h
    ;should retry since floppy drives are unreliable
    mov di, 3           ;retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry
.fail:
    ;all attempts failed
    jmp floppy_error
.done:
    popa
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
       
;
; Resets the disk controller
; Params:
;   - dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_loading:            db 'Loading...',ENDL, 0
msg_read_failed:        db 'Read from disk failed',ENDL, 0
stage2_file_name:       db 'STAGE2  BIN'
stage2_cluster:         dw 0

stage2_LOAD_SEGMENT    equ 0x2000
stage2_LOAD_OFFSET     equ 0

times 510-($-$$) db 0
dw 0AA55h

buffer: