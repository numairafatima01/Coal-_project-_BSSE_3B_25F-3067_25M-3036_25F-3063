; ============================================================
; FILE: src/states.asm
; Modules 14 & 15: Title, Win, Game Over Screens & Level Reset
; ============================================================

HandleNonPlayingState:
    cmp byte [hud_dirty], 1
    jne .chk_enter
    mov byte [hud_dirty], 0
    call UpdateTimerAndHUD
    call DrawStateBanner
    call FlipFullBuffer

.chk_enter:
    mov al, SC_ENTER
    call IsKeyDown
    jz .hnps_done

    cmp byte [game_state], STATE_WIN
    je .restart_level
    mov word [score_lo], 0
    mov word [score_hi], 0
    mov byte [coins], 0
    mov byte [lives], START_LIVES

.restart_level:
    mov word [time_left], LEVEL_TIME
    mov byte [sec_ticks], 0
    call ResetMap
    call InitMario
    call InitEnemies
    mov byte [game_state], STATE_PLAYING
    mov byte [hud_dirty], 1
    call UpdateTimerAndHUD
    mov byte [hud_dirty], 0
    call RenderLevel
    call DrawEnemies
    call DrawMario
    call FlipFullBuffer

.hnps_done:
    ret