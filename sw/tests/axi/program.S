.option norvc
.section .text
.globl _start
_start:
    lui x1, 4
    addi x1, x1, 0
    lui x2, 70179
    addi x2, x2, 836
    sw x2, 0(x1)
    lw x3, 0(x1)
    bne x2, x3, fail
    addi x4, x0, 170
    sb x4, 1(x1)
    lui x5, 70187
    addi x5, x5, -1468
    lw x3, 0(x1)
    bne x3, x5, fail
    lbu x3, 1(x1)
    bne x3, x4, fail
    addi x5, x0, -86
    lb x3, 1(x1)
    bne x3, x5, fail
    lui x4, 5
    addi x4, x4, 1382
    sh x4, 2(x1)
    lhu x3, 2(x1)
    bne x3, x4, fail
    lui x5, 349803
    addi x5, x5, -1468
    lw x3, 0(x1)
    bne x3, x5, fail
    sw x2, 5(x1)
    lw x3, 5(x1)
    bne x3, x2, fail
    lui x5, 1
    addi x5, x5, 290
    lh x3, 7(x1)
    bne x3, x5, fail
    lui x6, 16
    addi x6, x6, 0
    sw x2, 4(x6)
    lw x3, 4(x6)
    lui x5, 3
    addi x5, x5, 836
    bne x3, x5, fail
    addi x4, x0, 170
    sb x4, 5(x6)
    lw x3, 4(x6)
    lui x5, 11
    addi x5, x5, -1468
    bne x3, x5, fail
    lw x3, 0(x6)
    lui x5, 6
    addi x5, x5, -1371
    bne x3, x5, fail
    lui x7, 17
    addi x7, x7, 0
    addi x4, x0, 3
    sw x4, 0(x7)
    lui x4, 16
    addi x4, x4, -1
    sw x4, 4(x7)
    addi x4, x0, 1
    sw x4, 16(x7)
    sw x4, 12(x7)
    addi x8, x0, 30
delay:
    addi x8,x8,-1
    bne x8, x0, delay
    sw x0, 12(x7)
    lw x3, 20(x7)
    beq x3, x0, fail
    sw x4, 8(x7)
    lw x3, 20(x7)
    bne x3, x0, fail
    sw x0, 8(x7)
    lui x9, 32
    addi x9, x9, 0
    lw x3, 0(x9)
    bne x3, x0, fail
    sw x2, 0(x9)
    addi x20, x0, 1
    sw x20, 256(x1)
pass:
    jal x0,0
fail:
    addi x20, x0, -1
    jal x0,0
