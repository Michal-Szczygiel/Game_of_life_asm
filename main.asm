bits    64

%define XRES        1920
%define YRES        1080

%define XCELLS      240
%define YCELLS      135

%define FRAMES      128

global  _start

section .data
file:
        .path:      db      "frames/frame_0000.bmp",0
        .handle:    dq      0

frame:
        .header:    db      0x42,0x4d,0x36,0xec,0x5e,0x00,0x00,0x00,0x00,
                    db      0x00,0x36,0x00,0x00,0x00,0x28,0x00,0x00,0x00,
                    db      0x80,0x07,0x00,0x00,0x38,0x04,0x00,0x00,0x01,
                    db      0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0xec,
                    db      0x5e,0x00,0x74,0x12,0x00,0x00,0x74,0x12,0x00,
                    db      0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
        .hSize:     equ     $ - .header

currentFrame:       dq      0

random:
        .current:   dq      0.0
        .one:       dq      1.0
        .four:      dq      4.0

probability:        dq      0.2

board:
        .buffer:    dq      0
        .bufferS:   dq      0

aliveColor:
        .red:       db      122
        .green:     db      255
        .blue:      db      229

backbroundColor:
        .red:       db      14
        .green:     db      61
        .blue:      db      66

section .bss
frameBuffer:        resb    XRES * YRES * 3
boardBuffer:        resb    XCELLS * YCELLS
boardBufferSwap:    resb    XCELLS * YCELLS

section .text
_start:
        call        initRandom
        call        initBoards

        mov         r15, 0
.iter:
        cmp         r15, FRAMES + 1
        je          .exit

        call        nextStep
        call        drawFrame

        call        openFile
        call        saveFrame
        call        closeFile
        call        nextFrame

        inc         r15
        jmp         .iter
.exit:
; Process exit:
        mov         rax, 60
        mov         rdi, 0
        syscall


; [] -> []
initBoards:
        push        rbp
        mov         rbp, rsp

        mov         qword [board.buffer], boardBuffer
        mov         qword [board.bufferS], boardBufferSwap

        mov         r8, 1
.y_iter:
        cmp         r8, YCELLS - 1
        je          .y_exit
        mov         r9, 1
.x_iter:
        cmp         r9, XCELLS - 1
        je          .x_exit

        call        nextRandom
        call        getRandomState
        
        mov         rdi, r8
        imul        rdi, XCELLS
        add         rdi, r9

        mov         [boardBuffer + rdi], al

        inc         r9
        jmp         .x_iter
.x_exit:
        inc         r8
        jmp         .y_iter
.y_exit:
        leave
        ret


; [] -> []
openFile:
        push        rbp
        mov         rbp, rsp
        mov         rax, 2
        mov         rdi, file.path
        mov         rsi, 101o
        mov         rdx, 777o
        syscall
        mov         [file.handle], rax
        leave
        ret


; [] -> []
closeFile:
        push        rbp
        mov         rbp, rsp
        mov         rax, 3
        mov         rdi, [file.handle]
        syscall
        leave
        ret


; [] -> []
nextFrame:
        push        rbp
        mov         rbp, rsp

        mov         rax, [currentFrame]
        mov         rdx, 0
        mov         r8, 1000
        div         r8
        add         rax, 48
        mov         byte [file.path + 13], al

        mov         rax, rdx
        mov         rdx, 0
        mov         r8, 100
        div         r8
        add         rax, 48
        mov         byte [file.path + 14], al

        mov         rax, rdx
        mov         rdx, 0
        mov         r8, 10
        div         r8
        add         rax, 48
        mov         byte [file.path + 15], al

        add         rdx, 48
        mov         byte [file.path + 16], dl

        inc         qword [currentFrame]

        leave
        ret


; [] -> []
saveFrame:
        push        rbp
        mov         rbp, rsp

        mov         rax, 1
        mov         rdi, [file.handle]
        mov         rsi, frame.header
        mov         rdx, frame.hSize
        syscall

        mov         rax, 1
        mov         rdi, [file.handle]
        mov         rsi, frameBuffer
        mov         rdx, XRES * YRES * 3
        syscall

        leave
        ret


; [] -> []
initRandom:
        push        rbp
        mov         rbp, rsp

; Time syscall:
        mov         rax, 201
        mov         rdi, 0
        syscall

; Result truncation to 16 bit int:
        mov         rdi, 0
        mov         di, 0xffff

        mov         rsi, 0
        mov         si, ax

; Result division:
        cvtsi2sd    xmm0, rsi
        cvtsi2sd    xmm1, rdi
        divsd       xmm0, xmm1

; Saving result:
        movsd       [random.current], xmm0

        leave
        ret


; [] -> []
nextRandom:
        push        rbp
        mov         rbp, rsp
        movsd       xmm0, [random.one]
        subsd       xmm0, [random.current]
        mulsd       xmm0, [random.current]
        mulsd       xmm0, [random.four]
        movsd       [random.current], xmm0
        leave
        ret


; [] -> [rax: i64]
getRandomState:
        push        rbp
        mov         rbp, rsp

        mov         rax, 0
        movsd       xmm0, [random.current]
        movsd       xmm1, [probability]
        comiss      xmm0, xmm1
        jb          .exit
        mov         rax, 1
.exit:
        leave
        ret


; [] -> []
nextStep:
        push        rbp
        mov         rbp, rsp

        mov         r8, 1                           ; y loop
        mov         rdi, [board.buffer]             ; main board pointer
        mov         rsi, [board.bufferS]            ; swap board pointer
.y_iter:
        cmp         r8, YCELLS - 1
        je          .y_exit
        mov         r9, 1                           ; x loop
.x_iter:
        cmp         r9, XCELLS - 1
        je          .x_exit

        mov         rbx, 0                          ; alive counter

        mov         rdx, r8                         ; row y - 1
        dec         rdx
        imul        rdx, XCELLS
        add         rdx, r9

        dec         rdx
        add         bl, [rdi + rdx]
        inc         rdx
        add         bl, [rdi + rdx]
        inc         rdx
        add         bl, [rdi + rdx]

        mov         rdx, r8                         ; row y
        imul        rdx, XCELLS
        add         rdx, r9

        dec         rdx
        add         bl, [rdi + rdx]
        add         rdx, 2
        add         bl, [rdi + rdx]

        mov         rdx, r8                         ; row y + 1
        inc         rdx
        imul        rdx, XCELLS
        add         rdx, r9

        dec         rdx
        add         bl, [rdi + rdx]
        inc         rdx
        add         bl, [rdi + rdx]
        inc         rdx
        add         bl, [rdi + rdx]

        mov         rdx, r8
        imul        rdx, XCELLS
        add         rdx, r9                         ; current cell number in rdx

        mov         byte [rsi + rdx], 0

        cmp         rbx, 2
        jne         .continue
        mov         bl, [rdi + rdx]
        mov         [rsi + rdx], bl
        jmp         .end
.continue:
        cmp         rbx, 3
        jne         .end
        mov         byte [rsi + rdx], 1
.end:

        inc         r9
        jmp         .x_iter
.x_exit:
        inc         r8
        jmp         .y_iter
.y_exit:
        mov         [board.buffer], rsi             ; buffers swap
        mov         [board.bufferS], rdi

        leave
        ret


; [] -> []
drawFrame:
        push        rbp
        mov         rbp, rsp

        mov         r8, 0                           ; y loop
.y_iter:
        cmp         r8, YRES
        je          .y_exit
        mov         r9, 0                           ; x loop
.x_iter:
        cmp         r9, XRES
        je          .x_exit

        mov         rdx, 0                          ; get cell y index
        mov         rax, r8
        mov         r14, 8
        div         r14
        mov         rbx, rax                        ; cell y index in rbx

        mov         rdx, 0                          ; get cell x index
        mov         rax, r9
        mov         r14, 8
        div         r14
        mov         rcx, rax                        ; cell x index in rcx

        mov         rdx, 0
        mov         rdx, rbx
        imul        rdx, XCELLS
        add         rdx, rcx                        ; cell number in rdx

        mov         rbx, [board.buffer]             ; board pointer in rbx

        mov         rcx, r8
        imul        rcx, XRES
        add         rcx, r9
        imul        rcx, 3                          ; pixel index in rcx

        cmp         byte [rbx + rdx], 0
        je          .dead
        mov         r14b, [aliveColor.blue]
        mov         byte [frameBuffer + rcx], r14b
        inc         rcx
        mov         r14b, [aliveColor.green]
        mov         byte [frameBuffer + rcx], r14b
        inc         rcx
        mov         r14b, [aliveColor.red]
        mov         byte [frameBuffer + rcx], r14b
        jmp         .end
.dead:
        mov         r14b, [backbroundColor.blue]
        mov         byte [frameBuffer + rcx], r14b
        inc         rcx
        mov         r14b, [backbroundColor.green]
        mov         byte [frameBuffer + rcx], r14b
        inc         rcx
        mov         r14b, [backbroundColor.red]
        mov         byte [frameBuffer + rcx], r14b
.end:
        inc         r9
        jmp         .x_iter
.x_exit:
        inc         r8
        jmp         .y_iter
.y_exit:
        leave
        ret
