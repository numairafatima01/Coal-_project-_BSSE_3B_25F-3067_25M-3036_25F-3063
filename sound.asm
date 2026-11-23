; ============================================================
; FILE: src/sound.asm
; Module 9: Non-Blocking PC Speaker Sound Effects (Ports 42h/43h/61h)
; ============================================================

snd_ptr         dw 0            ; pointer to active note table (0 = silent)
snd_timer       db 0            ; remaining frames for current note

; Note table format: dw PIT_DIVISOR, dw DURATION_FRAMES (0 = end of sound)
; PIT frequency = 1,193,182 Hz / divisor

sfx_jump:
    dw 5400, 2                  ; ~220 Hz (A3)
    dw 4050, 2                  ; ~294 Hz (D4)
    dw 3040, 3                  ; ~392 Hz (G4)
    dw 0

sfx_coin:
    dw 2415, 2                  ; ~494 Hz (B4)
    dw 1810, 5                  ; ~659 Hz (E5)
    dw 0

sfx_stomp:
    dw 7000, 2                  ; ~170 Hz
    dw 9500, 3                  ; ~125 Hz
    dw 0

sfx_powerup:
    dw 4560, 2                  ; ~262 Hz (C4)
    dw 3619, 2                  ; ~330 Hz (E4)
    dw 3043, 2                  ; ~392 Hz (G4)
    dw 2280, 4                  ; ~523 Hz (C5)
    dw 0

sfx_hurt:
    dw 3619, 3                  ; ~330 Hz (E4)
    dw 5423, 3                  ; ~220 Hz (A3)
    dw 7239, 4                  ; ~165 Hz (E3)
    dw 0

sfx_win:
    dw 4560, 3                  ; C4
    dw 3619, 3                  ; E4
    dw 3043, 3                  ; G4
    dw 2280, 7                  ; C5
    dw 0

; ------------------------------------------------------------
; PlaySound: queues note table DS:SI to start on next frame tick
; ------------------------------------------------------------
PlaySound:
    mov [snd_ptr], si
    mov byte [snd_timer], 0
    ret

; ------------------------------------------------------------
; StopSound: silences PC speaker (port 61h bits 0..1 = 0)
; ------------------------------------------------------------
StopSound:
    push ax
    mov word [snd_ptr], 0
    mov byte [snd_timer], 0
    in al, 61h
    and al, 0FCh
    out 61h, al
    pop ax
    ret

; ------------------------------------------------------------
; UpdateSound: called once per frame in .game_loop
; ------------------------------------------------------------
UpdateSound:
    push ax
    push dx
    push si

    mov si, [snd_ptr]
    cmp si, 0
    je .us_done

    cmp byte [snd_timer], 0
    je .us_next_note
    dec byte [snd_timer]
    jnz .us_done

.us_next_note:
    mov ax, [si]                ; read PIT frequency divisor
    cmp ax, 0
    je .us_stop                 ; 0 = end of sound sequence

    mov dl, [si + 2]            ; read duration in frames
    mov [snd_timer], dl
    add word [snd_ptr], 4       ; advance 4 bytes (2 words) to next note

    ; Program PIT Channel 2 (square wave) and enable speaker
    push ax
    mov al, 0B6h
    out 43h, al
    pop ax
    out 42h, al                 ; low byte
    mov al, ah
    out 42h, al                 ; high byte

    in al, 61h
    or al, 03h                  ; gate speaker on
    out 61h, al
    jmp .us_done

.us_stop:
    call StopSound

.us_done:
    pop si
    pop dx
    pop ax
    ret