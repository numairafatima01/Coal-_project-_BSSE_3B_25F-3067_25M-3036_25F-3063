ORG 100h
jmp start                       ; skip the data below, start running at "start"
; ============================================================
; ===== CONSTANTS =====
; ============================================================

; ---- screen and level ----
VIDEO_SEG       EQU 0A000h      ; the screen lives here in memory (VGA mode 13h)
SCREEN_W        EQU 320         ; screen is 320 pixels wide
SCREEN_H        EQU 200         ; screen is 200 pixels tall
TILE_SIZE       EQU 16          ; every tile and sprite is 16 x 16 pixels
HUD_HEIGHT      EQU 16          ; top 16 pixels show score, coins, time (map row 0)
VISIBLE_H       EQU 192         ; game area height = 12 rows x 16 pixels
VISIBLE_COLS    EQU 20          ; 20 tiles fit across the screen (20 x 16 = 320)
MAP_COLS        EQU 60          ; the whole level is 60 tiles wide
MAP_ROWS        EQU 12          ; and 12 tiles tall
LEVEL_W_PX      EQU 960         ; level width in pixels (60 x 16)
CAMERA_MAX      EQU 640         ; camera can't go further than this (960 - 320)
CAMERA_FOLLOW_X EQU 160         ; once Mario is past screen x 160, the camera follows
START_X         EQU 32          ; Mario begins at x = 32 in the level
START_Y         EQU 10*TILE_SIZE ; Mario's feet start at y = 160 (top of ground row 10)
PIT_Y           EQU 192         ; if Mario's feet reach y = 192 he fell in a pit
LEFT_BEHIND     EQU 32          ; enemy 32 pixels left of the screen gets removed
ACTIVATE_DIST   EQU 16          ; enemy starts walking 1 tile before it enters the screen

; ---- sprite sizes ----
SMALL_H         EQU 16          ; small Mario is 16 pixels tall
SUPER_H         EQU 32          ; super Mario is 32 pixels tall
HIT_W           EQU 12          ; hitbox is 12 wide (sprite is 16) so hits feel fair

; ---- tile codes ----
TILE_SKY        EQU 0
TILE_GROUND     EQU 1
TILE_BRICK      EQU 2
TILE_QCOIN      EQU 3
TILE_QMUSH      EQU 4
TILE_EMPTY      EQU 5
TILE_PIPE_TL    EQU 6
TILE_PIPE_TR    EQU 7
TILE_PIPE_BL    EQU 8
TILE_PIPE_BR    EQU 9
TILE_STAIR      EQU 10
TILE_COIN       EQU 11
TILE_FLAG       EQU 12

; ---- colours ----
COL_SKY         EQU 9
COL_GROUND      EQU 6
COL_BRICK       EQU 4
COL_PIPE        EQU 2
COL_HERO        EQU 12
COL_ENEMY       EQU 5
COL_TEXT        EQU 15
COL_HUD         EQU 1

; ---- keyboard scan codes ----
SC_ESC          EQU 01h
SC_ENTER        EQU 1Ch
SC_P            EQU 19h
SC_LSHIFT       EQU 2Ah
SC_SPACE        EQU 39h
SC_UP           EQU 48h
SC_DOWN         EQU 50h
SC_LEFT         EQU 4Bh
SC_RIGHT        EQU 4Dh

; ---- physics (8.8 fixed point) ----
WALK_ACCEL      EQU 0020h
FRICTION        EQU 0010h
MAX_WALK        EQU 0180h
MAX_RUN         EQU 0280h
GRAVITY         EQU 0040h
JUMP_START      EQU 0FA80h
JUMP_CUTOFF     EQU 0FE00h
MAX_FALL        EQU 0400h
STOMP_BOUNCE    EQU 0FD00h
GOOMBA_SPEED    EQU 0080h
KOOPA_SPEED     EQU 00C0h
SHELL_SPEED     EQU 0300h
MUSHROOM_SPEED  EQU 0100h

; ---- game limits ----
START_LIVES     EQU 3
MAX_LIVES       EQU 99
LEVEL_TIME      EQU 300
COINS_FOR_LIFE  EQU 100
MAX_HP          EQU 2
MAX_ENEMIES     EQU 8
MAX_SCORE_HI    EQU 000Fh
MAX_SCORE_LO    EQU 423Fh

; ---- points ----
PTS_COIN        EQU 200
PTS_KICK        EQU 400
PTS_SHELL_KILL  EQU 500
PTS_MUSHROOM    EQU 1000
PTS_BRICK       EQU 50
PTS_PER_SECOND  EQU 50
STOMP_MAX       EQU 10

; ---- timings ----
FRAME_RATE      EQU 30
TICKS_PER_SEC   EQU FRAME_RATE
INVULN_FRAMES   EQU 2*FRAME_RATE
FLAT_FRAMES     EQU FRAME_RATE
KICK_GRACE      EQU 8
DEATH_FRAMES    EQU FRAME_RATE*3/2
LIFELOST_FRAMES EQU 2*FRAME_RATE
SLIDE_FRAMES    EQU FRAME_RATE
WALK_FRAMES     EQU FRAME_RATE
DEATH_HOP       EQU 48

; ---- game states ----
STATE_TITLE     EQU 0
STATE_PLAYING   EQU 1
STATE_PAUSED    EQU 2
STATE_DYING     EQU 3
STATE_LIFELOST  EQU 4
STATE_WIN       EQU 5
STATE_LEVELDONE EQU 6
STATE_GAMEOVER  EQU 7
STATE_EXIT      EQU 8

; ---- enemy types ----
ENEMY_NONE      EQU 0
ENEMY_GOOMBA    EQU 1
ENEMY_KOOPA     EQU 2
ENEMY_SHELL     EQU 3

; ---- enemy states ----
ENS_WAIT        EQU 0
ENS_WALK        EQU 1
ENS_FLAT        EQU 2
ENS_SHELL_STILL EQU 3
ENS_SHELL_SLIDE EQU 4

; ---- enemy record layout ----
EN_TYPE         EQU 0
EN_STATE        EQU 1
EN_X            EQU 2
EN_Y            EQU 4
EN_SPEED        EQU 6
EN_DIR          EQU 8
EN_TIMER        EQU 9
EN_VY           EQU 10
EN_SIZE         EQU 12

; ============================================================
; ===== VARIABLES =====
; ============================================================

; ---- hero (Mario) ----
mario_x         dw START_X
mario_x_sub     db 0
mario_y         dw START_Y*256
mario_vx        dw 0
mario_vy        dw 0
facing          db 0
on_ground       db 0
form            db 0
hp              db 1
invuln_timer    dw 0
stomp_chain     db 0
pose            db 0

; ---- camera & fast-redraw state ----
camera_x        dw 0
prev_camera_x   dw 0
need_redraw     db 1
prev_mario_x    dw START_X
prev_mario_y    dw START_Y

; ---- score and status ----
score_lo        dw 0
score_hi        dw 0
coins           db 0
lives           db START_LIVES

; ---- clock ----
time_left       dw LEVEL_TIME
tick_count      dw 0
last_tick       dw 0
sec_ticks       db 0

; ---- keys ----
key_state       times 128 db 0
key_extended    db 0

; ---- saved interrupt vectors ----
old_int09       dd 0
old_int08       dd 0

; ---- game control ----
game_state      db STATE_TITLE
fb_seg          dw 0
menu_choice     db 0
win_timer       dw 0
death_timer     dw 0

; ---- enemies ----
enemies         times MAX_ENEMIES*EN_SIZE db 0

; ---- score tables ----
stomp_points    dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000
flag_points     dw 5000, 2000, 800, 400, 100
flag_zone       db 0,0,0,0,1,2,3,3,4,4,4,4

; Include all modules right before the code section:
%include "video.asm"            ; Modules 1, 2, 3
%include "sprites.asm"          ; Module 4
%include "level.asm"            ; Module 5
%include "camera.asm"           ; Module 6
%include "input.asm"            ; Modules 7, 8
%include "physics.asm"          ; Module 9
%include "collide.asm"        ; Module 10
%include "enemies.asm"          ; Module 11
%include "items.asm"            ; Module 12
%include "ui.asm"               ; Module 13
%include "states.asm"           ; Modules 14, 15
%include "sound.asm"
%include "polish.asm"


; ============================================================
; ===== CODE =====
; ============================================================

start:
    mov ax, cs
    add ax, 1000h
    mov [fb_seg], ax

    call SetVideoMode
    call InstallHandlers
    call InitUI
    call ResetMap
    call InitMario
    call InitEnemies

    mov byte [game_state], STATE_TITLE
    mov byte [hud_dirty], 1
    call UpdateTimerAndHUD
    call RenderLevel
    call DrawEnemies
    call DrawMario
    call DrawStateBanner
    call FlipFullBuffer

.game_loop:
    call WaitNextFrame
    call UpdateSound
    call CheckPause
    cmp byte [game_state], STATE_PAUSED
    je near .game_loop 

    mov al, SC_ESC
    call IsKeyDown
    jnz near .exit_game

    ; Non-playing state (Title, Win, Game Over): handled in states.asm
    cmp byte [game_state], STATE_PLAYING
    je .active_frame
    call HandleNonPlayingState
    jmp .game_loop

.active_frame:
    mov ax, [mario_x]
    mov [prev_mario_x], ax
    mov ax, [mario_y]
    shr ax, 8
    mov [prev_mario_y], ax
    mov ax, [camera_x]
    mov [prev_camera_x], ax

    call UpdateMarioPhysics
    call UpdateEnemies
    call CheckMarioEnemyCollisions
    call CheckFlagpoleWin
    call UpdateTimerAndHUD

    ; Mark HUD dirty if banner just triggered (Win or Game Over)
    cmp byte [game_state], STATE_PLAYING
    je .erase_sprites
    mov byte [hud_dirty], 1

.erase_sprites:
    call EraseMarioTrail
    call EraseEnemies

    cmp byte [need_redraw], 1
    jne .check_scroll
    mov byte [need_redraw], 0
    call RenderLevel
    jmp .draw_all

.check_scroll:
    mov cx, [camera_x]
    sub cx, [prev_camera_x]
    jle .draw_all
    call ScrollScreenLeft

.draw_all:
    call DrawEnemies
    call DrawMario

    mov dx, 03DAh
.vretrace_end:
    in al, dx
    test al, 8
    jnz .vretrace_end
.vretrace_start:
    in al, dx
    test al, 8
    jz .vretrace_start

    ; Copy HUD only when hud_dirty = 1; otherwise use fast FlipBackBuffer
    cmp byte [hud_dirty], 1
    jne .fast_flip
    mov byte [hud_dirty], 0
    call FlipFullBuffer
    jmp .game_loop

.fast_flip:
    call FlipBackBuffer
    jmp .game_loop

.exit_game:
    call RestoreHandlers
    call StopSound
    call SetTextMode
    mov ax, 4C00h
    int 21h