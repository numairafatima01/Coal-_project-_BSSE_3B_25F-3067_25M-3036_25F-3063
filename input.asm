; FILE: input.asm | Module 5: Real-Time Keyboard ISR (INT 09h) & Timer (INT 08h)

; ------------------------------------------------------------
; Name     : InstallHandlers
; Purpose  : saves original BIOS INT 09h (keyboard) and INT 08h (timer)
;            interrupt vectors and installs our custom real-time handlers
; Inputs   : none
; Outputs  : updates [old_int09], [old_int08], and IVT entries 08h & 09h
; Changes  : none (AX, BX, DX, ES are saved and restored)
; ------------------------------------------------------------
InstallHandlers:
    push ax
    push bx
    push dx
    push es

    ; 1. Save original INT 09h (Keyboard) vector using DOS function 35h
    mov ax, 3509h
    int 21h                     ; returns ES:BX = current INT 09h handler
    mov [old_int09], bx
    mov [old_int09 + 2], es

    ; 2. Save original INT 08h (System Timer) vector using DOS function 35h
    mov ax, 3508h
    int 21h                     ; returns ES:BX = current INT 08h handler
    mov [old_int08], bx
    mov [old_int08 + 2], es

    ; 3. Clear key_state table (all 128 keys = 0 / released)
    call ClearKeys

    ; 4. Install custom INT 09h and INT 08h handlers safely with interrupts off
    cli
    mov ax, 2509h               ; DOS function 25h = set interrupt vector 09h
    mov dx, KeyboardISR
    int 21h

    mov ax, 2508h               ; DOS function 25h = set interrupt vector 08h
    mov dx, TimerISR
    int 21h
    sti

    pop es
    pop dx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : RestoreHandlers
; Purpose  : puts back the original BIOS INT 09h and INT 08h vectors
;            MUST be called before exiting to DOS so the keyboard/clock work
; Inputs   : [old_int09], [old_int08]
; Outputs  : restores original IVT entries 08h & 09h
; Changes  : none (AX, DX, DS are saved and restored)
; ------------------------------------------------------------
RestoreHandlers:
    push ax
    push dx
    push ds

    cli
    ; Restore original INT 09h vector
    mov dx, [cs:old_int09]
    mov ds, [cs:old_int09 + 2]
    mov ax, 2509h
    int 21h

    ; Restore original INT 08h vector
    mov dx, [cs:old_int08]
    mov ds, [cs:old_int08 + 2]
    mov ax, 2508h
    int 21h
    sti

    pop ds
    pop dx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : ClearKeys
; Purpose  : resets all 128 bytes of key_state to 0 (no keys held)
; Inputs   : none
; Outputs  : zeroes key_state[0..127] and key_extended
; Changes  : none (AX, CX, DI, ES are saved and restored)
; ------------------------------------------------------------
ClearKeys:
    push ax
    push cx
    push di
    push es

    push ds
    pop es
    mov di, key_state
    mov cx, 128
    xor al, al
    cld
    rep stosb
    mov byte [key_extended], 0

    pop es
    pop di
    pop cx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : IsKeyDown
; Purpose  : checks if a specific scan code is currently held down
; Inputs   : AL = scan code (0..127, e.g., SC_LEFT, SC_SPACE, SC_ESC)
; Outputs  : Zero Flag (ZF) = 0 (JNZ) if held down, ZF = 1 (JZ) if released
; Changes  : Flags only (all registers preserved)
; ------------------------------------------------------------
IsKeyDown:
    push bx
    xor bh, bh
    mov bl, al
    and bl, 7Fh                 ; keep within 0..127 bounds
    cmp byte [key_state + bx], 0
    pop bx
    ret

; ------------------------------------------------------------
; Name     : KeyboardISR
; Purpose  : hardware interrupt 09h handler; updates key_state[0..127]
;            with 1 on key press (make) and 0 on key release (break)
; Inputs   : hardware port 60h (keyboard scan code)
; Outputs  : updates key_state array and sends EOI (20h) to PIC port 20h
; Changes  : none (interrupt handler saves/restores all used registers)
; ------------------------------------------------------------
KeyboardISR:
    push ax
    push bx
    push ds

    push cs
    pop ds                      ; ensure DS points to our .COM data segment

    in al, 60h                  ; read raw scan code from keyboard controller

    cmp al, 0E0h                ; extended key prefix (sent before arrow keys)?
    jne .not_e0
    mov byte [key_extended], 1
    jmp .eoi

.not_e0:
    mov byte [key_extended], 0  ; clear extended flag (arrow scan codes 4Bh/4Dh/48h/50h are unique < 128)

    test al, 80h                ; bit 7 set = key released (break code)?
    jnz .key_released

    ; --- KEY PRESSED (Make code: bit 7 == 0) ---
    xor bh, bh
    mov bl, al
    and bl, 7Fh
    mov byte [key_state + bx], 1
    jmp .eoi

.key_released:
    ; --- KEY RELEASED (Break code: bit 7 == 1) ---
    xor bh, bh
    mov bl, al
    and bl, 7Fh                 ; strip release bit 7 to get base scan code
    mov byte [key_state + bx], 0

.eoi:
    ; Acknowledge keyboard controller (toggle bit 7 of port 61h)
    in al, 61h
    mov ah, al
    or al, 80h
    out 61h, al
    mov al, ah
    out 61h, al

    ; Send End-of-Interrupt (EOI) to Programmable Interrupt Controller (PIC)
    mov al, 20h
    out 20h, al

    pop ds
    pop bx
    pop ax
    iret

; ------------------------------------------------------------
; Name     : TimerISR
; Purpose  : hardware interrupt 08h handler; increments tick_count every
;            timer tick and chains to original BIOS INT 08h for system clock
; Inputs   : hardware IRQ 0 timer pulse
; Outputs  : increments [tick_count]
; Changes  : none (chains to [old_int08], which executes IRET)
; ------------------------------------------------------------
TimerISR:
    push ds
    push cs
    pop ds                      ; ensure DS points to our .COM segment

    inc word [tick_count]       ; advance frame/tick counter

    pop ds
    jmp far [cs:old_int08]      ; chain to original BIOS timer handler (sends EOI & IRET)

; ------------------------------------------------------------
; Name     : WaitNextFrame
; Purpose  : paces the game loop to 1 frame per timer tick and updates
;            the level countdown clock (time_left) once every TICKS_PER_SEC
; Inputs   : [tick_count], [last_tick], [sec_ticks], [time_left]
; Outputs  : updates [last_tick], [sec_ticks], and decrements [time_left]
; Changes  : none (AX is saved and restored)
; ------------------------------------------------------------
WaitNextFrame:
    push ax

.spin:
    hlt                         ; low-power CPU halt until next hardware interrupt
    mov ax, [tick_count]
    cmp ax, [last_tick]
    je .spin                    ; wait until tick_count advances

    mov [last_tick], ax         ; record current tick

    ; Advance 1-second sub-counter
    inc byte [sec_ticks]
    cmp byte [sec_ticks], TICKS_PER_SEC
    jb .wnf_done

    mov byte [sec_ticks], 0
    cmp word [time_left], 0
    je .wnf_done
    dec word [time_left]        ; count down 1 second on the level clock

.wnf_done:
    pop ax
    ret