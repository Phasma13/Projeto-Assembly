default rel

%define SCREEN_W  720
%define SCREEN_H  520
%define MENU_N    3             ; numero de opcoes
%define ITEM_SZ   24            ; bytes reservados por texto de opcao

%define KEY_SPACE 32
%define KEY_W     87
%define KEY_S     83
%define KEY_ESC   256
%define KEY_ENTER 257
%define KEY_DOWN  264
%define KEY_UP    265

; cores 0xAABBGGRR
%define COL_BG     0xFF1B1A18
%define COL_BORDER 0xFF6E645A
%define COL_BODY   0xFF78C850
%define COL_HEAD   0xFFA0F08C
%define COL_TEXT   0xFFF0F0F0

extern InitWindow, CloseWindow, WindowShouldClose, SetTargetFPS, SetExitKey
extern BeginDrawing, EndDrawing, ClearBackground
extern DrawRectangle, DrawText, MeasureText, IsKeyPressed
extern snake_run, velha_run

%macro ITEM 1
%%s:    db %1, 0
        times ITEM_SZ-($-%%s) db 0
%endmacro

section .data
title:      db "Menu de Jogos", 0
s_title:    db "JOGOS EM ASSEMBLY", 0
s_sub:      db "Projeto Final", 0
s_help:     db "Setas / W S: navegar    ENTER: escolher    ESC: sair", 0
items:
    ITEM "Snake"
    ITEM "Jogo da Velha"
    ITEM "Sair"
sel:        dd 0

section .text
global main
;  open_window: cria a janela e configura FPS e tecla de saida
open_window:
    sub rsp, 8
    mov edi, SCREEN_W
    mov esi, SCREEN_H
    lea rdx, [title]
    call InitWindow wrt ..plt
    mov edi, 60
    call SetTargetFPS wrt ..plt
    xor edi, edi                ; sem tecla de saida: ESC volta ao menu
    call SetExitKey wrt ..plt
    add rsp, 8
    ret

;  key2: edi = tecla A, esi = tecla B -> eax != 0 se alguma foi apertada
key2:
    push rbx
    mov ebx, esi
    call IsKeyPressed wrt ..plt
    test al, al
    jnz .yes
    mov edi, ebx
    call IsKeyPressed wrt ..plt
.yes:
    movzx eax, al
    pop rbx
    ret

;  draw_centered: rdi = texto, esi = y, edx = fonte, ecx = cor
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
    shr esi, 1
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

;  draw: desenha o menu
draw:
    push rbx
    push r12
    push r13                    ; 3 pushes -> pilha alinhada
    call BeginDrawing wrt ..plt
    mov edi, COL_BG
    call ClearBackground wrt ..plt

    lea rdi, [s_title]
    mov esi, 60
    mov edx, 56
    mov ecx, COL_HEAD
    call draw_centered

    lea rdi, [s_sub]
    mov esi, 130
    mov edx, 22
    mov ecx, COL_BORDER
    call draw_centered

    xor ebx, ebx                ; indice da opcao
.items:
    cmp ebx, MENU_N
    jae .items_done
    imul r12d, ebx, 70
    add r12d, 190               ; y da opcao
    cmp ebx, [sel]
    jne .plain
    mov edi, (SCREEN_W-400)/2   ; barra de destaque
    mov esi, r12d
    mov edx, 400
    mov ecx, 52
    mov r8d, COL_BODY
    call DrawRectangle wrt ..plt
    mov r13d, COL_BG            ; texto escuro sobre o destaque
    jmp .text
.plain:
    mov r13d, COL_TEXT
.text:
    imul eax, ebx, ITEM_SZ
    lea rdi, [items]
    add rdi, rax
    lea esi, [r12 + 10]
    mov edx, 32
    mov ecx, r13d
    call draw_centered
    inc ebx
    jmp .items
.items_done:

    lea rdi, [s_help]
    mov esi, 470
    mov edx, 18
    mov ecx, COL_BORDER
    call draw_centered

    call EndDrawing wrt ..plt
    pop r13
    pop r12
    pop rbx
    ret
    
main:
    push rbx                    ; entrada = 8 mod 16 -> alinhado
    call open_window

.frame:
    call WindowShouldClose wrt ..plt
    test al, al
    jnz .quit

    mov edi, KEY_ESC
    call IsKeyPressed wrt ..plt
    test al, al
    jnz .quit

    ; cima / W
    mov edi, KEY_UP
    mov esi, KEY_W
    call key2
    test eax, eax
    jz .no_up
    mov eax, [sel]
    test eax, eax
    jnz .dec
    mov eax, MENU_N
.dec:
    dec eax
    mov [sel], eax
.no_up:

    ; baixo / S
    mov edi, KEY_DOWN
    mov esi, KEY_S
    call key2
    test eax, eax
    jz .no_down
    mov eax, [sel]
    inc eax
    cmp eax, MENU_N
    jb .store
    xor eax, eax
.store:
    mov [sel], eax
.no_down:

    ; ENTER / ESPACO
    mov edi, KEY_ENTER
    mov esi, KEY_SPACE
    call key2
    test eax, eax
    jz .draw

    mov eax, [sel]
    cmp eax, 0
    je .snake
    cmp eax, 1
    je .velha
    jmp .quit                   ; "Sair"

.snake:
    call snake_run
    ; um quadro vazio para a raylib atualizar o estado das teclas
    ; (senao o ESC que saiu do jogo tambem fecharia o menu)
    call BeginDrawing wrt ..plt
    call EndDrawing wrt ..plt
    jmp .frame

.velha:
    call CloseWindow wrt ..plt  ; o jogo da velha usa o terminal
    call velha_run
    call open_window
    jmp .frame

.draw:
    call draw
    jmp .frame

.quit:
    call CloseWindow wrt ..plt
    xor eax, eax
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
