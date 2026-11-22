; ============================================================
; FILE: src/polish.asm
; Module 10: Simple Pause (P Key) & Time Bonus
; ============================================================

p_was_down      db 0            ; 1 if P key was already held down last frame
str_paused      db "PAUSED", 0

; ------------------------------------------------------------
; CheckPause: press P to pause, press P again to resume
; ------------------------------------------------------------
CheckPause:
    push ax
    push bx
    push cx
    push dx
    push si

    mov al, SC_P
    call IsKeyDown
    cmp al, 0
    je .p_not_held              ; P is not pressed right now

    cmp byte [p_was_down], 1
    je .cp_done                 ; still holding P from last frame -> ignore
    mov byte [p_was_down], 1    ; remember P was just pressed

    ; Toggle between PLAYING and PAUSED
    cmp byte [game_state], STATE_PLAYING
    je .pause_game
    cmp byte [game_state], STATE_PAUSED
    je .resume_game
    jmp .cp_done

.pause_game:
    mov byte [game_state], STATE_PAUSED
    call StopSound
    mov si, str_paused
    mov bx, 142                 ; center X
    mov dx, 90                  ; center Y
    mov cl, COL_TEXT
    call DrawString
    call FlipFullBuffer
    jmp .cp_done

.resume_game:
    mov byte [game_state], STATE_PLAYING
    mov byte [need_redraw], 1   ; erase "PAUSED" text by redrawing level
    jmp .cp_done

.p_not_held:
    mov byte [p_was_down], 0

.cp_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; AddTimeBonus: adds (time_left * 50) to score on win
; ------------------------------------------------------------
AddTimeBonus:
    push ax
    push cx
    push dx

    mov ax, [time_left]
    mov cx, PTS_PER_SECOND      ; 50 points per second
    mul cx                      ; DX:AX = time_left * 50
    call AddScore

    mov word [time_left], 0     ; set clock to 0
    mov byte [hud_dirty], 1     ; update top HUD bar

    pop dx
    pop cx
    pop ax
    ret