%define W         30            ; colunas do campo
%define H         20            ; linhas do campo
%define CELL      24            ; tamanho de cada celula em pixels
%define HUD       40            ; altura da barra de placar
%define SCREEN_W  (W*CELL)
%define SCREEN_H  (HUD + H*CELL)
%define MAXLEN    (W*H)

; teclas (raylib KeyboardKey)
%define KEY_SPACE 32
%define KEY_R     82
%define KEY_ESC   256
%define KEY_ENTER 257

; cores 0xAABBGGRR
%define COL_BG     0xFF1B1A18
%define COL_ALT    0xFF24221F
%define COL_BORDER 0xFF6E645A
%define COL_BODY   0xFF78C850
%define COL_HEAD   0xFFA0F08C
%define COL_FOOD   0xFF5050F0
%define COL_TEXT   0xFFF0F0F0
%define COL_DIM    0xA0000000

extern WindowShouldClose
extern BeginDrawing, EndDrawing, ClearBackground
extern DrawRectangle, DrawRectangleLines, DrawText, MeasureText
extern TextFormat, IsKeyPressed, GetRandomValue, SetRandomSeed
extern time

section .data
fmt_hud:    db "Pontos: %d    Recorde: %d", 0
fmt_final:  db "Pontos: %d", 0
s_over:     db "FIM DE JOGO", 0
s_restart:  db "ENTER ou ESPACO para jogar de novo", 0

dir_x:      db 1                ; direcao pedida pelo jogador
dir_y:      db 0
last_x:     db 1                ; ultima direcao realmente aplicada
last_y:     db 0
food_x:     db 0
food_y:     db 0
state:      db 0                ; 0 = jogando, 1 = fim de jogo
align 8
len:        dq 3
score:      dd 0
best:       dd 0
tick:       dd 0

; tabela de teclas: codigo (dd), dx (db), dy (db), padding (dw)
%macro KEY 3
    dd %1
    db %2, %3
    dw 0
%endmacro
key_table:
    KEY 265, 0, -1              ; seta cima
    KEY 264, 0,  1              ; seta baixo
    KEY 263, -1, 0              ; seta esquerda
    KEY 262, 1,  0              ; seta direita
    KEY 'W', 0, -1
    KEY 'S', 0,  1
    KEY 'A', -1, 0
    KEY 'D', 1,  0
%define KEY_COUNT 8

section .bss
snake_x:    resb MAXLEN
snake_y:    resb MAXLEN

section .text
global snake_run

;  snake_run: roda o jogo ate o jogador apertar ESC (volta ao
;  menu) ou a janela ser fechada. A janela ja deve estar aberta
snake_run:
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                  ; alinha a pilha em 16 bytes

    xor edi, edi
    call time wrt ..plt
    mov edi, eax
    call SetRandomSeed wrt ..plt

    call reset_game

.frame:
    call WindowShouldClose wrt ..plt
    test al, al
    jnz .quit

    mov edi, KEY_ESC            ; ESC volta ao menu
    call IsKeyPressed wrt ..plt
    test al, al
    jnz .quit

    cmp byte [state], 0
    jne .gameover

  ;jogando: le teclas e avanca a cobra a cada N quadros
    call read_input
    inc dword [tick]

    mov eax, [score]            ; N = 8 - pontos/50, minimo 3
    xor edx, edx
    mov ecx, 50
    div ecx
    mov ecx, 8
    sub ecx, eax
    cmp ecx, 3
    jge .speed_ok
    mov ecx, 3
.speed_ok:
    cmp [tick], ecx
    jb .draw
    mov dword [tick], 0
    call step_game
    jmp .draw

.gameover:
    mov edi, KEY_ENTER
    call IsKeyPressed wrt ..plt
    test al, al
    jnz .restart
    mov edi, KEY_SPACE
    call IsKeyPressed wrt ..plt
    test al, al
    jnz .restart
    mov edi, KEY_R
    call IsKeyPressed wrt ..plt
    test al, al
    jz .draw
.restart:
    call reset_game

.draw:
    call draw
    jmp .frame

.quit:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

;  reset_game: estado inicial (cobra de 3 segmentos no centro)
reset_game:
    push rbx
    xor ecx, ecx
.init:
    cmp ecx, 3
    jae .done
    mov eax, W/2
    sub eax, ecx
    mov [snake_x+rcx], al
    mov byte [snake_y+rcx], H/2
    inc ecx
    jmp .init
.done:
    mov qword [len], 3
    mov dword [score], 0
    mov dword [tick], 0
    mov byte [state], 0
    mov byte [dir_x], 1
    mov byte [dir_y], 0
    mov byte [last_x], 1
    mov byte [last_y], 0
    call place_food
    pop rbx
    ret


;  read_input: consulta as 8 teclas de direcao

read_input:
    push rbx
    push r12
    push r13                    ; 3 pushes -> pilha alinhada
    lea rbx, [rel key_table]
    mov r12d, KEY_COUNT
.ri:
    mov edi, [rbx]
    call IsKeyPressed wrt ..plt
    test al, al
    jz .next
    movsx r9d, byte [rbx+4]
    movsx r10d, byte [rbx+5]
    call try_dir
.next:
    add rbx, 8
    dec r12d
    jnz .ri
    pop r13
    pop r12
    pop rbx
    ret

; try_dir: r9d = novo dx, r10d = novo dy.
; Ignora a inversao de 180 graus em relacao a ultima direcao aplicada.
try_dir:
    movsx eax, byte [last_x]
    add eax, r9d
    jnz .ok
    movsx eax, byte [last_y]
    add eax, r10d
    jz .no
.ok:
    mov [dir_x], r9b
    mov [dir_y], r10b
.no:
    ret


;  step_game: move a cobra uma celula

step_game:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8

    mov al, [dir_x]
    mov [last_x], al
    mov al, [dir_y]
    mov [last_y], al

    movzx r12d, byte [snake_x]
    movzx r13d, byte [snake_y]
    movsx eax, byte [dir_x]
    add r12d, eax
    movsx eax, byte [dir_y]
    add r13d, eax

    cmp r12d, W                 ; parede (negativo vira grande sem sinal)
    jae .dead
    cmp r13d, H
    jae .dead

    ; comeu?
    xor r14d, r14d
    movzx eax, byte [food_x]
    cmp eax, r12d
    jne .noeat
    movzx eax, byte [food_y]
    cmp eax, r13d
    jne .noeat
    mov r14d, 1
.noeat:
    ; colisao com o corpo (o rabo sai do lugar se nao comeu)
    mov rcx, [len]
    test r14d, r14d
    jnz .cself
    dec rcx
.cself:
    xor ebx, ebx
.sl:
    cmp rbx, rcx
    jae .move
    movzx eax, byte [snake_x+rbx]
    cmp eax, r12d
    jne .sn
    movzx eax, byte [snake_y+rbx]
    cmp eax, r13d
    je .dead
.sn:
    inc rbx
    jmp .sl

.move:
    add [len], r14              ; cresce se comeu
    mov rcx, [len]
    dec rcx
.shift:
    test rcx, rcx
    jz .sethead
    mov al, [snake_x+rcx-1]
    mov [snake_x+rcx], al
    mov al, [snake_y+rcx-1]
    mov [snake_y+rcx], al
    dec rcx
    jmp .shift
.sethead:
    mov [snake_x], r12b
    mov [snake_y], r13b

    test r14d, r14d
    jz .out
    add dword [score], 10
    call place_food
    jmp .out

.dead:
    mov byte [state], 1
    mov eax, [score]
    cmp eax, [best]
    jbe .out
    mov [best], eax
.out:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret


;  place_food: sorteia uma celula livre com GetRandomValue (raylib)

place_food:
    push rbx                    ; alinha a pilha
.retry:
    xor edi, edi
    mov esi, W-1
    call GetRandomValue wrt ..plt
    mov [food_x], al
    xor edi, edi
    mov esi, H-1
    call GetRandomValue wrt ..plt
    mov [food_y], al

    xor ecx, ecx
    mov rbx, [len]
.chk:
    cmp rcx, rbx
    jae .done
    mov al, [snake_x+rcx]
    cmp al, [food_x]
    jne .nx
    mov al, [snake_y+rcx]
    cmp al, [food_y]
    je .retry                   ; caiu em cima da cobra: sorteia de novo
.nx:
    inc rcx
    jmp .chk
.done:
    pop rbx
    ret


;  draw_cell: edi = coluna, esi = linha, edx = margem, ecx = cor

draw_cell:
    sub rsp, 8
    mov r8d, ecx                ; cor
    mov eax, edx                ; margem
    imul edi, edi, CELL
    add edi, eax                ; x
    imul esi, esi, CELL
    add esi, HUD
    add esi, eax                ; y
    shl eax, 1
    mov edx, CELL
    sub edx, eax                ; largura
    mov ecx, edx                ; altura
    call DrawRectangle wrt ..plt
    add rsp, 8
    ret


;  draw_centered: rdi = texto, esi = y, edx = tamanho da fonte, ecx = cor

draw_centered:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx

    mov esi, r13d               ; rdi ja tem o texto
    call MeasureText wrt ..plt
    mov esi, SCREEN_W
    sub esi, eax
    shr esi, 1                  ; x = (largura_tela - largura_texto) / 2
    mov rdi, rbx
    mov edx, r12d
    mov ecx, r13d
    mov r8d, r14d
    call DrawText wrt ..plt

    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret


;  draw: desenha o quadro inteiro

draw:
    push rbx
    push r12
    push r13                    ; 3 pushes -> pilha alinhada
    call BeginDrawing wrt ..plt
    mov edi, COL_BG
    call ClearBackground wrt ..plt

    ; tabuleiro xadrez (so as celulas "impares" precisam de cor extra)
    xor r12d, r12d              ; linha
.cy:
    cmp r12d, H
    jae .cy_done
    xor ebx, ebx                ; coluna
.cx:
    cmp ebx, W
    jae .cx_done
    mov eax, ebx
    add eax, r12d
    test eax, 1
    jz .skip
    mov edi, ebx
    mov esi, r12d
    xor edx, edx
    mov ecx, COL_ALT
    call draw_cell
.skip:
    inc ebx
    jmp .cx
.cx_done:
    inc r12d
    jmp .cy
.cy_done:

    ; borda do campo
    xor edi, edi
    mov esi, HUD
    mov edx, SCREEN_W
    mov ecx, H*CELL
    mov r8d, COL_BORDER
    call DrawRectangleLines wrt ..plt

    ; comida
    movzx edi, byte [food_x]
    movzx esi, byte [food_y]
    mov edx, 3
    mov ecx, COL_FOOD
    call draw_cell

    ; cobra (do rabo para a cabeca, a cabeca fica por cima)
    mov r12, [len]
.sn_loop:
    test r12, r12
    jz .sn_done
    dec r12
    movzx edi, byte [snake_x+r12]
    movzx esi, byte [snake_y+r12]
    mov edx, 1
    mov ecx, COL_BODY
    test r12, r12
    jnz .sn_draw
    mov ecx, COL_HEAD
.sn_draw:
    call draw_cell
    jmp .sn_loop
.sn_done:

    ; placar
    lea rdi, [rel fmt_hud]
    mov esi, [score]
    mov edx, [best]
    xor eax, eax                ; funcao variadica
    call TextFormat wrt ..plt
    mov rdi, rax
    mov esi, 12
    mov edx, 8
    mov ecx, 24
    mov r8d, COL_TEXT
    call DrawText wrt ..plt

    ; tela de fim de jogo
    cmp byte [state], 1
    jne .present
    xor edi, edi
    xor esi, esi
    mov edx, SCREEN_W
    mov ecx, SCREEN_H
    mov r8d, COL_DIM
    call DrawRectangle wrt ..plt

    lea rdi, [rel s_over]
    mov esi, 170
    mov edx, 56
    mov ecx, COL_TEXT
    call draw_centered

    lea rdi, [rel fmt_final]
    mov esi, [score]
    xor eax, eax
    call TextFormat wrt ..plt
    mov rdi, rax
    mov esi, 250
    mov edx, 32
    mov ecx, COL_TEXT
    call draw_centered

    lea rdi, [rel s_restart]
    mov esi, 310
    mov edx, 22
    mov ecx, COL_TEXT
    call draw_centered

.present:
    call EndDrawing wrt ..plt
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
