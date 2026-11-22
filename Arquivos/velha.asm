default rel
global velha_run
extern printf, puts, fgets, stdin

section .data

    tabu   db '1','2','3','4','5','6','7','8','9'
    player  db 'X'
    turnoo   db 0

    ; 8 combinacoes vencedoras
    linha   db 0,1,2, 3,4,5, 6,7,8      ; linhas
            db 0,3,6, 1,4,7, 2,5,8      ; colunas
            db 0,4,8, 2,4,6             ; diagonais

    horiz db " %c | %c | %c ", 10, 0
    sep     db "---+---+---", 0
    vazio   db 0
    pergunta db "Jogador %c, escolha uma casa (1-9): ", 0
    invalido db "Entrada invalida! Digite um numero de 1 a 9.", 0
    ocupado db "Casa ocupada! Escolha outra.", 0
    vict db "Jogador %c venceu! Parabens!", 10, 0
    desenha db "Deu velha! Empate.", 0
    volta db "Pressione ENTER para voltar ao menu...", 0
    inictab db '1','2','3','4','5','6','7','8','9'

section .bss
    esc   resb 16

section .text


; empate_tabu: imprime o tabuleiro

empate_tabu:
    push    rbx
    push    r12
    sub     rsp, 8                  ; alinha a pilha em 16 bytes
    lea     r12, [tabu]
    lea     rdi, [vazio]
    call    puts                    ; linha em branco
    xor     ebx, ebx                ; rbx = indice do inicio da linha (0,3,6)
.row:
    lea     rdi, [horiz]
    movzx   esi, byte [r12 + rbx]
    movzx   edx, byte [r12 + rbx + 1]
    movzx   ecx, byte [r12 + rbx + 2]
    xor     eax, eax                ; 0 registradores vetoriais (varargs)
    call    printf
    cmp     rbx, 6
    jge     .skip_sep
    lea     rdi, [sep]
    call    puts
.skip_sep:
    add     rbx, 3
    cmp     rbx, 9
    jl      .row
    lea     rdi, [vazio]
    call    puts
    add     rsp, 8
    pop     r12
    pop     rbx
    ret


; checavit: eax = 1 se o jogador atual completou uma linha

checavit:
    lea     rsi, [linha]
    lea     r8, [tabu]
    mov     al, [player]
    xor     ecx, ecx
.prox:
    movzx   edx, byte [rsi]
    cmp     [r8 + rdx], al
    jne     .no
    movzx   edx, byte [rsi + 1]
    cmp     [r8 + rdx], al
    jne     .no
    movzx   edx, byte [rsi + 2]
    cmp     [r8 + rdx], al
    jne     .no
    mov     eax, 1
    ret
.no:
    add     rsi, 3
    inc     ecx
    cmp     ecx, 8
    jl      .prox
    xor     eax, eax
    ret

; ------------------------------------------------------------
; velha_run: joga uma partida completa e volta ao chamador
; ------------------------------------------------------------
velha_run:
    push    rbx
    push    r12
    sub     rsp, 8                  ; alinhamento de pilha
    lea     r12, [tabu]

    ; reinicia o estado (o menu pode chamar varias vezes)
    lea     rsi, [inictab]
    xor     ecx, ecx
.reset:
    mov     al, [rsi + rcx]
    mov     [r12 + rcx], al
    inc     ecx
    cmp     ecx, 9
    jb      .reset
    mov     byte [player], 'X'
    mov     byte [turnoo], 0

.turno:
    call    empate_tabu
.per:
    lea     rdi, [pergunta]
    movzx   esi, byte [player]
    xor     eax, eax
    call    printf

    lea     rdi, [esc]
    mov     esi, 16
    mov     rdx, [stdin]
    call    fgets
    test    rax, rax
    jz      .sai                   ; EOF: encerra

    cmp     byte [esc + 1], 10    ; esperamos exatamente "d\n"
    jne     .invalido
    movzx   eax, byte [esc]
    cmp     al, '1'
    jb      .invalido
    cmp     al, '9'
    ja      .invalido

    sub     eax, '1'                ; indice 0..8
    mov     ebx, eax
    lea     ecx, [rax + '1']        ; caractere original da casa
    cmp     [r12 + rbx], cl
    jne     .ocupado

    mov     dl, [player]
    mov     [r12 + rbx], dl         ; registra a jogada
    inc     byte [turnoo]

    call    checavit
    test    eax, eax
    jnz     .vitoria
    cmp     byte [turnoo], 9
    je      .empate

    xor     byte [player], 'X' ^ 'O'    ; troca X <-> O
    jmp     .turno

.invalido:
    lea     rdi, [invalido]
    call    puts
    jmp     .per
.ocupado:
    lea     rdi, [ocupado]
    call    puts
    jmp     .per

.vitoria:
    call    empate_tabu
    lea     rdi, [vict]
    movzx   esi, byte [player]
    xor     eax, eax
    call    printf
    jmp     .espera
.empate:
    call    empate_tabu
    lea     rdi, [desenha]
    call    puts

    ; espera ENTER para o jogador ler o resultado
.espera:
    lea     rdi, [volta]
    call    puts
    lea     rdi, [esc]
    mov     esi, 16
    mov     rdx, [stdin]
    call    fgets

.sai:
    xor     eax, eax
    add     rsp, 8
    pop     r12
    pop     rbx
    ret


