.section .text
.global _start
# Compiled with -O2 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -Wl,--no-relax 

_start:
    # ; computation starts from here!
    lla     a5,x
    lla     a4,array1_size
    lw      a5,0(a5)
    lw      a4,0(a4)
    bgeu    a5,a4,.L2
    lla     a4,.LANCHOR0
    slli    a5,a5,2
    add     a5,a4,a5
    lla     a4,temp
    lw      a4,0(a4)
    lw      a5,0(a5)
    add     a5,a5,a4
    slli    a3,a5,8
    lla     a4,.LANCHOR1
    add     a4,a4,a3
    lw      a4,0(a4)
    slli    a5,a5,6
    and     a5,a4,a5
    sw      a5,temp,a4
.L2:
    li      a0,0
    j  .END

# ; tear-down code ensuring that tohost is set to 1 so that simulator terminates
.END:
    la      t1, tohost
    li      t2, 1
    sw      t2, 0(t1)
    j   .END # loop until execution terminates


    # ; declared global variables
    .hidden x
    .globl  x
    .hidden temp
    .globl  temp
    .hidden array2
    .globl  array2
    .hidden array1
    .globl  array1
    .hidden array1_size
    .globl  array1_size

    # ; needed for running with SPIKE/C-simulator from SAIL-RISCV
    .section .tohost, "aw", @progbits
    .globl tohost
    .align 4
    tohost: .dword 0
    .globl fromhost
    .align 4
    fromhost: .dword 0

.section .data
    # ; data here!
        .align  2
        .set    .LANCHOR1,. + 0
        .type   array1, @object
        .size   array1, 64
array1:
        .word   1
        .word   2
        .word   3
        .word   4
        .word   5
        .word   6
        .word   7
        .word   8
        .word   9
        .word   10
        .word   11
        .word   12
        .word   13
        .word   14
        .word   15
        .word   16
        .bss
        .align  2
        .set    .LANCHOR0,. + 0
        .type   array2, @object
        .size   array2, 64
array2:
        .zero   64
        .section        .sbss,"aw",@nobits
        .align  2
        .type   temp, @object
        .size   temp, 4
temp:
        .zero   4
        .section        .sdata,"aw"
        .align  2
        .type   x, @object
        .size   x, 4
x:
        .word   18
        .type   array1_size, @object
        .size   array1_size, 4
array1_size:
        .word   16