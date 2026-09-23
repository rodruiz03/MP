# Evaluador de Expresiones - Proyecto Microprogramación
# Arquitectura RISC-V 1.5
# Operaciones: +, -, *, /, ^
# Notación infix ? postfix y evaluación mejorada

    .data
menu_line1: .string "\n--- EVALUADOR DE EXPRESIONES ---\n"
menu_line2: .string "1. Ingresar expresión\n"
menu_line3: .string "2. Ingresar valor de X (hexadecimal)\n"
menu_line4: .string "3. Evaluar la expresión\n"
menu_line5: .string "4. Salir del programa\n"
menu_line6: .string "Ingrese su opción: "

msg_expr:   .string "Ingrese la expresión matemática: "
msg_x:      .string "Ingrese el valor de X en hexadecimal: 0x"
msg_result: .string "Resultado: "
msg_no:     .string "Primero debe ingresar expresión y valor de X\n"
msg_error:  .string "Error en la evaluación de la expresión\n"
msg_bye:    .string "¡Gracias por usar el programa!\n"

# Buffers y variables de control
expression: .space 1024
token_buff: .space 64
infix:      .space 1024
postfix:    .space 1024
.align 2
num_stack:  .space 400
op_stack:   .space 100
x_value:    .word 0
has_expr:   .byte 0
has_x:      .byte 0

    .text
    .globl main
main:
    j menu_loop

# Menú principal del programa
menu_loop:
    # Imprimir opciones del menú
    la a0, menu_line1
    li a7, 4
    ecall
    la a0, menu_line2
    li a7, 4
    ecall
    la a0, menu_line3
    li a7, 4
    ecall
    la a0, menu_line4
    li a7, 4
    ecall
    la a0, menu_line5
    li a7, 4
    ecall
    la a0, menu_line6
    li a7, 4
    ecall

    # Leer opción del usuario
    li a7, 5
    ecall
    mv t0, a0

    # Saltar a la opción correspondiente
    li t1, 1
    beq t0, t1, input_expr
    li t1, 2
    beq t0, t1, input_x
    li t1, 3
    beq t0, t1, eval_expr
    li t1, 4
    beq t0, t1, exit_prg
    j menu_loop

# Entrada de expresión matemática
input_expr:
    la a0, msg_expr
    li a7, 4
    ecall
    la a0, expression
    li a1, 1024
    li a7, 8
    ecall
    li t0, 1
    la t1, has_expr
    sb t0, 0(t1)   # Establecer bandera de expresión
    j menu_loop

# Entrada de valor de X en hexadecimal
input_x:
    la a0, msg_x
    li a7, 4
    ecall
    la a0, token_buff
    li a1, 64
    li a7, 8
    ecall
    # Truncar salto de línea
    la a0, token_buff
    jal truncate_newline       # Nueva función
    la a0, token_buff
    jal hex_to_int
    la t0, x_value
    sw a0, 0(t0)
    li t0, 1
    la t1, has_x
    sb t0, 0(t1)   # Establecer bandera de X
    j menu_loop

# Evaluar la expresión
eval_expr:
    # Verificar que se haya ingresado expresión y valor de X
    lb t0, has_expr
    lb t1, has_x
    and t2, t0, t1
    beqz t2, no_input

    # Convertir expresión de infija a tokens
    la a0, expression
    la a1, infix
    jal parse_expression

    # Convertir tokens de infija a postfija
    la a0, infix
    la a1, postfix
    jal infix_to_postfix

    # Evaluar expresión postfija
    la a0, postfix
    la t0, x_value
    lw a1, 0(t0)
    jal evaluate_postfix

    # Mostrar resultado
    mv a1, a0
    la a0, msg_result
    li a7, 4
    ecall
    mv a0, a1
    li a7, 1
    ecall
    li a0, 10
    li a7, 11
    ecall
    j menu_loop

# Mensaje de error si no se ha ingresado expresión o X
no_input:
    la a0, msg_no
    li a7, 4
    ecall
    j menu_loop

# Salir del programa
exit_prg:
    la a0, msg_bye
    li a7, 4
    ecall
    li a7, 10
    ecall

# Conversión de hexadecimal a entero
    .globl hex_to_int
hex_to_int:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
    li s1, 0
hex_loop:
    lb t0, 0(s0)
    beqz t0, hex_end
    
    # Convertir dígitos hexadecimales
    li t1, '0'
    blt t0, t1, chk_upper
    li t2, '9'
    bgt t0, t2, chk_upper
    sub t3, t0, t1
    j proc_digit
chk_upper:
    li t1, 'A'
    blt t0, t1, chk_lower
    li t2, 'F'
    bgt t0, t2, hex_next
    sub t3, t0, t1
    addi t3, t3, 10
    j proc_digit
chk_lower:
    li t1, 'a'
    blt t0, t1, hex_next
    li t2, 'f'
    bgt t0, t2, hex_next
    sub t3, t0, t1
    addi t3, t3, 10
proc_digit:
    slli s1, s1, 4
    add s1, s1, t3
hex_next:
    addi s0, s0, 1
    j hex_loop
hex_end:
    mv a0, s1
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

# Conversión de cadena decimal a entero
    .globl atoi
atoi:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    mv s0, a0
    li t0, 0
    li t6, 0  # Bandera para números negativos
    
    # Verificar signo negativo
    lb t1, 0(s0)
    li t2, '-'
    bne t1, t2, atoi_loop
    li t6, 1
    addi s0, s0, 1

atoi_loop:
    lb t1, 0(s0)
    beqz t1, atoi_end
    li t2, '0'
    blt t1, t2, atoi_end
    li t3, '9'
    bgt t1, t3, atoi_end
    sub t4, t1, t2
    li t5, 10
    mul t0, t0, t5
    add t0, t0, t4
    addi s0, s0, 1
    j atoi_loop
atoi_end:
    # Manejar signo negativo
    beqz t6, atoi_return
    neg t0, t0
atoi_return:
    mv a0, t0
    lw ra, 8(sp)
    lw s0, 4(sp)
    addi sp, sp, 12
    ret

# Determinar precedencia de operadores
    .globl prec
prec:
    li t0, '+'
    beq a0, t0, prec_low
    li t0, '-'
    beq a0, t0, prec_low
    li t0, '*'
    beq a0, t0, prec_mid
    li t0, '/'
    beq a0, t0, prec_mid
    li t0, '^'
    beq a0, t0, prec_high
    li a0, 0
    ret
prec_low:
    li a0, 1
    ret
prec_mid:
    li a0, 2
    ret
prec_high:
    li a0, 3
    ret
# Parsear expresión en tokens
    .globl parse_expression
parse_expression:
    addi sp, sp, -40
    sw ra, 36(sp)
    sw s0, 32(sp)
    sw s1, 28(sp)
    sw s2, 24(sp)
    sw s3, 20(sp)
    sw s4, 16(sp)       # Nuevo registro para índice de infix
    
    mv s0, a0           # ptr expr
    mv s1, a1           # ptr infix
    la s2, token_buff
    li s3, 0            # Índice para expresión (bytes)
    li s4, 0            # Índice para infix (bytes)
    
parse_loop:
    add t0, s0, s3      # Cargar carácter de la expresión
    lb t1, 0(t0)
    beqz t1, parse_end

    # Saltar espacios
    li t2, ' '
    beq t1, t2, parse_skip

    # Verificar números
    li t2, '0'
    blt t1, t2, check_op
    li t2, '9'
    ble t1, t2, handle_num

check_op:
    li t2, '+'
    beq t1, t2, store_op
    li t2, '-'
    beq t1, t2, store_op
    li t2, '*'
    beq t1, t2, store_op
    li t2, '/'
    beq t1, t2, store_op
    li t2, '^'
    beq t1, t2, store_op
    li t2, '('
    beq t1, t2, store_paren
    li t2, ')'
    beq t1, t2, store_paren
    
    # Manejar variables
    li t2, 'X'
    beq t1, t2, store_var
    li t2, 'x'
    beq t1, t2, store_var

    j parse_skip

handle_num:
    # Parsear número
    li t4, 0            # Longitud del número
    la s2, token_buff   # Buffer temporal
num_loop:
    add t0, s0, s3
    lb t1, 0(t0)
    li t2, '0'
    blt t1, t2, num_done
    li t2, '9'
    bgt t1, t2, num_done
    add t3, s2, t4
    sb t1, 0(t3)
    addi t4, t4, 1
    addi s3, s3, 1
    j num_loop
num_done:
    add t3, s2, t4
    sb zero, 0(t3)      # Terminar cadena
    
    # Convertir a entero
    mv a0, s2
    jal atoi
    
    # Almacenar en infix
    mv t5, s1
    add t5, t5, s4      # t5 = infix + s4
    li t0, 'N'
    sb t0, 0(t5)        # Tipo: número
    sw a0, 4(t5)        # Valor (alineado)
    addi s4, s4, 8      # Avanzar 8 bytes en infix
    j parse_loop

store_op:
    mv t5, s1
    add t5, t5, s4      # t5 = infix + s4
    sb t1, 0(t5)        # Almacenar operador
    sb zero, 1(t5)
    sb zero, 2(t5)
    sb zero, 3(t5)
    sw zero, 4(t5)      # Padding
    addi s4, s4, 8      # Avanzar infix
    addi s3, s3, 1      # Avanzar expresión
    j parse_loop

store_var:
    mv t5, s1
    add t5, t5, s4      # t5 = infix + s4
    li t0, 'X'
    sb t0, 0(t5)        # Tipo: variable
    sb zero, 1(t5)
    sb zero, 2(t5)
    sb zero, 3(t5)
    sw zero, 4(t5)      # Padding
    addi s4, s4, 8      # Avanzar infix
    addi s3, s3, 1      # Avanzar expresión
    j parse_loop

store_paren:
    mv t5, s1
    add t5, t5, s4      # t5 = infix + s4
    sb t1, 0(t5)        # Almacenar paréntesis
    sb zero, 1(t5)
    sb zero, 2(t5)
    sb zero, 3(t5)
    sw zero, 4(t5)      # Padding
    addi s4, s4, 8      # Avanzar infix
    addi s3, s3, 1      # Avanzar expresión
    j parse_loop

parse_skip:
    addi s3, s3, 1      # Solo avanzar en expresión
    j parse_loop

parse_end:
    # Terminar infix con null
    mv t5, s1
    add t5, t5, s4
    sb zero, 0(t5)
    
    # Restaurar registros
    lw ra, 36(sp)
    lw s0, 32(sp)
    lw s1, 28(sp)
    lw s2, 24(sp)
    lw s3, 20(sp)
    lw s4, 16(sp)
    addi sp, sp, 40
    ret

# Conversión de notación infija a postfija (Algoritmo Shunting-Yard)
    .globl infix_to_postfix
infix_to_postfix:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    
    mv s0, a0        # ptr infix
    mv s1, a1        # ptr postfix
    la s2, op_stack
    li s3, 0         # índice de la cima

sh_loop:
    lb t0, 0(s0)
    beqz t0, sh_empty_stack

    li t1, 'N'
    beq t0, t1, sh_copy_num
    li t1, 'X'
    beq t0, t1, sh_copy_num
    
    li t1, '('
    beq t0, t1, sh_push_paren
    
    li t1, ')'
    beq t0, t1, sh_close_paren
    
    # Verificar si es operador
    li t1, '+'
    beq t0, t1, sh_process_op
    li t1, '-'
    beq t0, t1, sh_process_op
    li t1, '*'
    beq t0, t1, sh_process_op
    li t1, '/'
    beq t0, t1, sh_process_op
    li t1, '^'
    beq t0, t1, sh_process_op
    
    # Saltar espacios o caracteres no reconocidos
    j sh_continue

sh_push_paren:
    # Apilar paréntesis de apertura
    add t1, s2, s3
    sb t0, 0(t1)
    addi s3, s3, 1
    addi s0, s0, 8
    j sh_loop

sh_close_paren:
    # Procesar paréntesis de cierre
    beqz s3, sh_error
    
    add t2, s2, s3
    addi t2, t2, -1
    lb t3, 0(t2)
    
    # Desapilar hasta encontrar paréntesis de apertura
    li t5, '('
    beq t3, t5, sh_skip_paren
    
    # Copiar operador a postfix
    sb t3, 0(s1)
    addi s1, s1, 1
    addi s3, s3, -1
    j sh_close_paren

sh_skip_paren:
    # Descartar paréntesis de apertura
    addi s3, s3, -1
    addi s0, s0, 8
    j sh_loop

sh_copy_num:
    # Copiar número o variable directamente a postfix
    lw t1, 4(s0)
    sb t0, 0(s1)
    sw t1, 4(s1)
    addi s1, s1, 8
    addi s0, s0, 8
    j sh_continue

sh_process_op:
    # Procesar operadores con precedencia
    mv a0, t0
    jal prec
    mv t4, a0  # Precedencia del operador actual

    # Comparar precedencia y apilar/desapilar
    beqz s3, sh_push_op
    
    # Obtener operador de la cima de la pila
    add t2, s2, s3
    addi t2, t2, -1
    lb t3, 0(t2)
    
    # Saltar si es paréntesis de apertura
    li t5, '('
    beq t3, t5, sh_push_op
    
    # Comparar precedencia
    mv a0, t3
    jal prec
    bge a0, t4, sh_pop_to_postfix

sh_push_op:
    # Verificar límite de la pila (100 bytes)
    li t6, 100
    bge s3, t6, sh_error       # Si s3 >= 100, error
    # Apilar operador
    add t1, s2, s3
    sb t0, 0(t1)
    addi s3, s3, 1
    j sh_continue

sh_pop_to_postfix:
    # Desapilar operador a postfix
    add t2, s2, s3
    addi t2, t2, -1
    lb t3, 0(t2)
    
    # Copiar operador a postfix
    sb t3, 0(s1)
    addi s1, s1, 1
    
    # Reducir tamaño de la pila
    addi s3, s3, -1
    
    # Volver a comparar
    j sh_process_op

sh_continue:
    # Continuar al siguiente token
    addi s0, s0, 8
    j sh_loop

sh_empty_stack:
    # Desapilar operadores restantes
    beqz s3, sh_finalize
    
    add t2, s2, s3
    addi t2, t2, -1
    lb t3, 0(t2)
    
    # Verificar paréntesis no balanceados
    li t5, '('
    beq t3, t5, sh_error
    
    # Copiar a postfix
    sb t3, 0(s1)
    addi s1, s1, 1
    addi s3, s3, -1
    j sh_empty_stack

sh_finalize:
    # Marcar fin de postfix
    sb x0, 0(s1)
    
    lw ra, 28(sp)
    lw s0, 24(sp)
    lw s1, 20(sp)
    lw s2, 16(sp)
    lw s3, 12(sp)
    addi sp, sp, 32
    ret

sh_error:
    # Manejar error de sintaxis
    la a0, msg_error
    li a7, 4
    ecall
    li a0, -1
    ret

# Evaluar expresión en notación postfija
    .globl evaluate_postfix
evaluate_postfix:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    
    mv s0, a0        # ptr postfix
    mv s1, a1        # valor de X
    la s2, num_stack
    li s3, 0         # índice de la cima de la pila

eval_loop:
    lb t0, 0(s0)
    beqz t0, eval_finish

    li t1, 'N'
    beq t0, t1, eval_push_num
    
    li t1, 'X'
    beq t0, t1, eval_push_x
    
    # Procesar operadores
    j eval_operate

eval_push_num:
    # Verificar límite de la pila (400 bytes)
    li t6, 400
    bge s3, t6, eval_error
    # Apilar número
    lw t1, 4(s0)
    add t2, s2, s3
    sw t1, 0(t2)
    addi s3, s3, 4        # Avanzar 4 bytes
    addi s0, s0, 8
    j eval_loop

eval_push_x:
    # Verificar límite de la pila (400 bytes)
    li t6, 400
    bge s3, t6, eval_error
    # Apilar valor de X
    add t2, s2, s3
    sw s1, 0(t2)
    addi s3, s3, 4        # Avanzar 4 bytes
    addi s0, s0, 8
    j eval_loop

eval_operate:
    # Verificar suficientes operandos (al menos 8 bytes en la pila)
    li t4, 8
    blt s3, t4, eval_error

    # Desapilar dos operandos
    addi s3, s3, -8       # Retroceder 8 bytes
    add t2, s2, s3
    lw t3, 4(t2)          # Segundo operando
    lw t4, 0(t2)          # Primer operando

    # Realizar operación según el operador
    li t5, '+'
    beq t0, t5, op_add
    li t5, '-'
    beq t0, t5, op_sub
    li t5, '*'
    beq t0, t5, op_mul
    li t5, '/'
    beq t0, t5, op_div
    li t5, '^'
    beq t0, t5, op_pow
    j eval_error

op_add:
    add t6, t4, t3
    j op_store

op_sub:
    sub t6, t4, t3
    j op_store

op_mul:
    mul t6, t4, t3
    j op_store

op_div:
    # Manejar división por cero
    beqz t3, eval_error
    div t6, t4, t3
    j op_store

op_pow:
    # Implementación de potencia
    li t5, 1
    beqz t3, op_pow_zero
    bltz t3, op_pow_neg
    mv t2, t3
    mv t3, t4
    li t4, 1
op_pow_loop:
    beqz t2, op_pow_end
    mul t4, t4, t3
    addi t2, t2, -1
    j op_pow_loop
op_pow_zero:
    li t6, 1
    j op_store
op_pow_neg:
    # Manejar exponentes negativos (simplificado)
    li t6, 0
    j op_store
op_pow_end:
    mv t6, t4

op_store:
    # Almacenar resultado
    add t2, s2, s3
    addi t2, t2, -8
    sw t6, 4(t2)
    addi s3, s3, -4
    addi s0, s0, 8
    j eval_loop

eval_error:
    # Manejar error de evaluación
    la a0, msg_error
    li a7, 4
    ecall
    li a0, -1
    j eval_finish

eval_finish:
    # Devolver resultado
    add t2, s2, s3
    addi t2, t2, -4
    lw a0, 0(t2)

    lw ra, 28(sp)
    lw s0, 24(sp)
    lw s1, 20(sp)
    lw s2, 16(sp)
    lw s3, 12(sp)
    addi sp, sp, 32
    ret
truncate_newline:
    mv t0, a0
truncate_loop:
    lb t1, 0(t0)
    beqz t1, truncate_end
    li t2, '\n'
    beq t1, t2, truncate_replace
    addi t0, t0, 1
    j truncate_loop
truncate_replace:
    sb zero, 0(t0)
truncate_end:
    ret