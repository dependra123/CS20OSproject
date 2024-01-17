bits 16

section _TEXT class=CODE

;
;void _cdecl x86_div64_32(uint64_t* dividend, uint32_t divisor, uint64_t* quotient, uint32_t* remainder);
;
global _x86_div64_32
_x86_div64_32:
    ;new call frame
    push bp         ;save old call frame
    mov bp, sp      ;init new call frame
    push bx

    ; divide upper 32 bits
    mov eax, [bp+8]
    mov ecx, [bp+12]
    xor edx, edx
    div ecx         ;eax - qout, edx remandir

    ;store upper 32 bits of the qoutint
    mov bx, [bp+16]
    mov [bx + 4], eax

    ;divide lower 32 bits
    mov eax, [bp + 4]

    div ecx

    mov [bx], eax
    mov bx, [bp + 18]
    mov [bx], edx

    pop bx
    ;restore old call frame
    mov sp, bp
    pop bp
    ret

global _x86_VideoWriteChartTeletype
_x86_VideoWriteChartTeletype:               
    push bp         ;save old call frame
    mov bp, sp      ;set up new call frame

    ;[bp + 0] - old call frame
    ;[bp + 2] - return address (small memory model => 2 bytes)
    ;[bp + 4] - fir argument (char); bytes are converted into words (cant push single byte to stack)
    ;[bp + 6] - second argument (page)
    mov ah, 0Eh
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 10h

    ;restor bx
    pop bx

    ;restore old call frame
    mov sp, bp 
    pop bp
    ret

;
; void _cdecl x86_DiskReset(uint8_t drive);
;
global _x86_DiskReset
_86_DiskReset:
    push bp         ;save old call frame
    mov bp, sp      ;setup new call frame

    mov ah, 0
    mov dl, [bp+4]  ;dl-drive num
    stc
    int 13h

    mov ax, 1
    sbb ax, 0       ;carry flag set then 0 else 1

    
    ;restore old call frame
    mov sp, bp 
    pop bp
    ret

; void _cdecl x86_DiskRead(uint8_t drive,
;                          uint16_t cylinder,
;                          uint16_t head,
;                          uint16_t sector,
;                          uint8_t count,
;                          uint8_t far* dataOut);
global _x86_DiskRead
_x86_DiskRead:
    push bp         ;save old call frame
    mov bp, sp      ;setup new call frame

    mov dl, [bp+4]  ;dl-drive num

    mov ch, [bp+6]  ;ch-cylender (lower 8 bits)
    mov cl, [bp+7]
    shl cl, 6

    mov dh, [bp+8]  ;dh- head

    mov al, [bp+10]
    and al, 3Fh
    or cl, al       ;cl - sector to bits 0-5
    
    mov al, [bp+12] ;al- count

    mov bx, [bp + 16]
    mov es, bx
    mov bx, [bp+14]

    ;call
    mov ah, 02h
    stc
    int 13h

    mov ax, 1
    sbb ax, 0       ;carry flag set then 0 else 1

    ;restore regs
    pop es
    pop bx
    
    ;restore old call frame
    mov sp, bp 
    pop bp
    ret

; void _cdecl x86_DiskGetParmas(uint8_t drive,
;                               uint8_t* driveTypeOut,
;                               uint16_t* cylindersOut,
;                               uint16_t* sectorsOut,
;                               uint16_t* headsOut);


global _x86_DiskGetParmas
_x86_DiskGetParmas:
    
    ;make new call frame
    push bp     ;save old call frame
    mov bp, sp  ;init new call frame

    ;save regs
    push es
    push bx
    push si
    push di

    ;call int 13h
    mov bl, [bp+4]
    mov ah, 08h
    mov di, 0
    mov es, di
    stc
    int 13h

    ;return
    mov ax, 1
    sbb ax, 0

    ;out param
    mov si, [bp+6]  ;drive type
    mov [si], bl

    mov bl, ch      ;lower bits in ch
    mov bh, cl
    shr bh, 6
    mov si, [bp+8]  ;cylingers out
    mov [si], bx

    xor ch, ch      ;sectors - lower 5 bits in cl
    and cl, 3Fh
    mov si, [bp+10]
    mov [si], cx

    mov cl, dh
    mov si, [bp+12]
    mov [si], cx

    ;restore regs
    pop di
    pop si
    pop bx
    pop es
    ;restore old call frame
    mov sp, bp
    pop bp
    ret