; ============================================================
; FILE: src/items.asm
; Module 12: ?-Blocks, Bricks, Coins, Mushrooms & Scoring
; ============================================================

; ------------------------------------------------------------
; Name     : HandleBlockBump
; Purpose  : reacts when Mario's head hits a tile from below:
;            - ? Coin block -> turns empty & awards coin/score
;            - ? Mushroom block -> turns empty & powers up Mario
;            - Brick block -> shatters into sky if Super Mario
; Inputs   : BX = world X of Mario's head, DX = world Y of tile
; Outputs  : updates map_working, form/hp, coins, score, need_redraw
; Changes  : none
; ------------------------------------------------------------
HandleBlockBump:
    push ax
    push bx
    push dx

    shr bx, 4                       ; col = BX / 16
    shr dx, 4                       ; row = DX / 16
    mov ax, dx
    mov dl, MAP_COLS
    mul dl                          ; AX = row * 60
    add ax, bx                      ; AX = row * 60 + col
    mov bx, ax

    mov al, [map_working + bx]      ; check what kind of block Mario bumped
    cmp al, TILE_QCOIN
    je .hit_qcoin
    cmp al, TILE_QMUSH
    je .hit_qmush
    cmp al, TILE_BRICK
    je .hit_brick
    jmp .hbb_done

.hit_qcoin:
    mov byte [map_working + bx], TILE_EMPTY
    mov byte [need_redraw], 1       ; redraw so ?-block turns into empty block
    call AddCoinAndScore
    jmp .hbb_done

.hit_qmush:
    mov byte [map_working + bx], TILE_EMPTY
    mov byte [need_redraw], 1       ; redraw so ?-block turns into empty block
    mov byte [form], 1              ; 1 = Super Mario (32px tall)
    mov byte [hp], MAX_HP           ; 2 hit points
    push si
    mov si, sfx_powerup
    call PlaySound
    pop si
    mov ax, PTS_MUSHROOM            ; +1000 points
    xor dx, dx
    call AddScore
    jmp .hbb_done

.hit_brick:
    cmp byte [form], 0
    je .hbb_done
    mov byte [map_working + bx], TILE_SKY ; remove broken brick
    mov byte [need_redraw], 1       ; redraw so broken brick disappears
    mov ax, PTS_BRICK               ; +50 points
    xor dx, dx
    call AddScore

.hbb_done:
    pop dx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : AddCoinAndScore
; Purpose  : adds 1 coin (awards 1-UP at 100 coins) and 200 points
; Inputs   : none
; Outputs  : updates coins, lives, and score_lo:score_hi
; Changes  : none
; ------------------------------------------------------------
AddCoinAndScore:
    push ax
    push dx
    push si
    mov si, sfx_coin
    call PlaySound
    pop si
    inc byte [coins]                ; add 1 coin
    cmp byte [coins], COINS_FOR_LIFE ; did we reach 100 coins?
    jl .coin_pts                    ; not yet -> award 200 points
    mov byte [coins], 0             ; reset coin counter back to 0
    cmp byte [lives], MAX_LIVES     ; cap lives at 99
    jge .coin_pts
    inc byte [lives]                ; award 1 extra life!
.coin_pts:
    mov ax, PTS_COIN                ; 200 points per coin
    xor dx, dx
    call AddScore
    pop dx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : AddScore
; Purpose  : adds 32-bit unsigned DX:AX to Mario's score and
;            caps the total at 999,999 (000F:423Fh)
; Inputs   : DX:AX = points to add
; Outputs  : updates score_lo and score_hi
; Changes  : none
; ------------------------------------------------------------
AddScore:
    add [score_lo], ax              ; add lower 16 bits
    adc [score_hi], dx              ; add upper 16 bits + carry
    cmp word [score_hi], MAX_SCORE_HI ; compare high word against 000Fh
    jb .score_ok                    ; strictly below 999,999 -> done
    ja .cap_score                   ; above 999,999 -> clamp to max
    cmp word [score_lo], MAX_SCORE_LO ; high word matches -> check low word (423Fh)
    jbe .score_ok
.cap_score:
    mov word [score_hi], MAX_SCORE_HI ; clamp score to 999,999
    mov word [score_lo], MAX_SCORE_LO
.score_ok:
    ret