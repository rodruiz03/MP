.eqv MAX_EXPR_LEN 256
.eqv MAX_RPN_LEN 512

.data
    menu:       .asciz "\nMenu:\n1. Ingresar expresion\n2. Ingresar X (decimal)\n3. Evaluar\n4. Salir\nOpcion: "
    prompt_exp: .asciz "\nIngrese la expresion (ej: (x+4)*5^x): "
    prompt_x:   .asciz "\nIngrese X (decimal): "
    resultado:  .asciz "\nResultado: "
    buffer_exp: .space MAX_EXPR_LEN
    buffer_x:   .space 32
    x_value:    .word 0
    err_div0:   .asciz "\nError: Division por cero"
    err_exp:    .asciz "\nExpresion invalida"
    newline:    .asciz "\n"
    rpn_queue:  .space MAX_RPN_LEN
    op_stack:   .space 128
    num_stack:  .space 512  # Aumentado para evitar desbordamiento

.text
.globl _start

#------------------------
# Macros
#------------------------
.macro push(%reg)
    addi sp, sp, -4
    sw %reg, 0(sp)
.end_macro

.macro pop(%reg)
    lw %reg, 0(sp)
    addi sp, sp, 4
.end_macro

#------------------------
# Menú principal
#------------------------
_start:
    la sp, op_stack
    addi sp, sp, 128  # Inicializar stack pointer
    
menu_loop:
    la a0, menu
    li a7, 4
    ecall
    
    li a7, 5
    ecall
    mv t0, a0
    
    li t1, 1
    beq t0, t1, opcion1
    li t1, 2
    beq t0, t1, opcion2
    li t1, 3
    beq t0, t1, opcion3
    li t1, 4
    beq t0, t1, exit
    j menu_loop

#------------------------
# Opción 1: Leer expresión
#------------------------
opcion1:
    la a0, prompt_exp
    li a7, 4
    ecall
    la a0, buffer_exp
    li a1, MAX_EXPR_LEN
    li a7, 8
    ecall
    j menu_loop

#------------------------
# Opción 2: Leer X (decimal)
#------------------------
opcion2:
    la a0, prompt_x
    li a7, 4
    ecall
    la a0, buffer_x
    li a1, 32  # Ampliado para buffer seguro
    li a7, 8
    ecall
    
    la a0, buffer_x
    jal dec_to_int
    sw a0, x_value, t0
    j menu_loop

#------------------------
# Opción 3: Evaluar
#------------------------
opcion3:
    # Guardar $ra para poder volver
    push(ra)
    
    # Inicializar buffer RPN y operadores
    la t0, rpn_queue
    li t1, 0
    sb t1, 0(t0)
    
    la t0, op_stack
    li t1, 0
    sb t1, 0(t0)
    
    # Sustituir X en la expresión
    la a0, buffer_exp
    lw a1, x_value
    jal sustituir_x
    
    # Convertir a notación polaca
    jal shunting_yard
    
    # Evaluar la expresión
    jal evaluar_rpn
    
    # Mostrar resultado
    la a0, resultado
    li a7, 4
    ecall
    mv a0, s0
    li a7, 1
    ecall
    
    pop(ra)
    j menu_loop

#------------------------
# dec_to_int - Conversión decimal
#------------------------
dec_to_int:
    push(ra)
    mv t0, a0     # puntero al buffer
    li t1, 0      # resultado
    li t3, 10     # constante para multiplicación
    
loop_dec:
    lbu t2, (t0)
    beqz t2, end_dec
    
    li t4, '\n'   # Verificar fin de línea
    beq t2, t4, end_dec
    
    li t4, '0'
    blt t2, t4, inv_dec
    li t4, '9'
    bgt t2, t4, inv_dec
    
    mul t1, t1, t3
    addi t2, t2, -48  # Convertir a valor numérico
    add t1, t1, t2
    addi t0, t0, 1
    j loop_dec
    
inv_dec:
    li t4, 0x0A  # \n
    beq t2, t4, end_dec
    li t4, 0x00  # null
    beq t2, t4, end_dec
    
    la a0, err_exp
    li a7, 4
    ecall
    li a0, 0  # Valor por defecto en caso de error
    pop(ra)
    ret
    
end_dec:
    mv a0, t1
    pop(ra)
    ret

#------------------------
# sustituir_x - Reemplaza 'x' por su valor numérico
#------------------------
sustituir_x:
    push(ra)
    push(s0)
    push(s1)
    push(s2)
    push(s3)
    push(s4)
    
    mv s0, a0     # buffer_exp
    mv s1, a1     # valor de X
    
    # Crear un buffer temporal en el stack
    addi sp, sp, -MAX_EXPR_LEN
    mv s2, sp     # s2 apunta al buffer temporal
    mv s3, s2     # s3 es el puntero de escritura actual
    
    # Copiar caracteres, reemplazando X
loop_sub:
    lbu t0, (s0)
    beqz t0, end_sub     # Fin de cadena
    
    li t1, 'x'
    beq t0, t1, replace_x
    li t1, 'X'
    beq t0, t1, replace_x
    
    # Copiar caracter normal
    sb t0, (s3)
    addi s3, s3, 1
    addi s0, s0, 1
    j loop_sub
    
replace_x:
    # Convertir número a string
    addi sp, sp, -32
    mv s4, sp     # s4 apunta al buffer para número
    
    # Convertir el entero a string
    mv a0, s1
    mv a1, s4
    jal int_to_str
    
    # Copiar el número convertido al buffer temporal
    mv a0, s3     # Destino: posición actual en buffer temp
    mv a1, s4     # Origen: buffer con número
    jal strcpy
    
    # Calcular nuevo puntero de escritura
    mv a0, s4
    jal strlen
    add s3, s3, a0
    
    addi sp, sp, 32  # Liberar buffer de números
    addi s0, s0, 1   # Avanzar en la expresión original
    j loop_sub
    
end_sub:
    # Terminar con null
    sb zero, (s3)
    
    # Copiar de vuelta al buffer_exp
    la a0, buffer_exp
    mv a1, s2
    jal strcpy
    
    addi sp, sp, MAX_EXPR_LEN  # Liberar buffer temporal
    
    pop(s4)
    pop(s3)
    pop(s2)
    pop(s1)
    pop(s0)
    pop(ra)
    ret

#------------------------
# Strlen - Calcula longitud de string
#------------------------
strlen:
    li t0, 0      # Contador
strlen_loop:
    lbu t1, (a0)
    beqz t1, strlen_end
    addi t0, t0, 1
    addi a0, a0, 1
    j strlen_loop
strlen_end:
    mv a0, t0
    ret

#------------------------
# Strcpy - Copia una cadena
#------------------------
strcpy:
    push(s0)
    push(s1)
    
    mv s0, a0     # destino
    mv s1, a1     # origen
    
strcpy_loop:
    lbu t0, (s1)
    sb t0, (s0)
    beqz t0, strcpy_end
    addi s0, s0, 1
    addi s1, s1, 1
    j strcpy_loop
    
strcpy_end:
    mv a0, a0     # Devolver puntero original
    
    pop(s1)
    pop(s0)
    ret

#------------------------
# int_to_str - Convierte entero a string
#------------------------
int_to_str:
    push(ra)
    push(s0)
    push(s1)
    push(s2)
    
    mv s0, a0     # número a convertir
    mv s1, a1     # buffer destino
    mv s2, a1     # guardar inicio del buffer
    
    # Manejar caso especial de cero
    bnez s0, not_zero
    li t0, '0'
    sb t0, (s1)
    addi s1, s1, 1
    sb zero, (s1)
    mv a0, s2
    j int_to_str_end
    
not_zero:
    # Manejar número negativo
    bgez s0, positive
    li t0, '-'
    sb t0, (s1)
    addi s1, s1, 1
    neg s0, s0
    
positive:
    # Convertir usando división
    addi sp, sp, -32     # Espacio para dígitos
    mv t0, sp           # Inicio del stack
    li t1, 10           # Divisor
    
digits_loop:
    rem t2, s0, t1      # residuo
    div s0, s0, t1      # cociente
    addi t2, t2, 48     # convertir a ASCII
    sb t2, (t0)         # guardar dígito
    addi t0, t0, 1      # incrementar puntero
    bnez s0, digits_loop
    
    # Copiar dígitos en orden inverso
reverse_loop:
    addi t0, t0, -1     # retroceder en el stack
    lbu t2, (t0)        # leer dígito
    sb t2, (s1)         # escribir en destino
    addi s1, s1, 1      # avanzar destino
    bge t0, sp, reverse_loop
    
    # Terminar con null
    sb zero, (s1)
    addi sp, sp, 32     # Liberar stack
    
    mv a0, s2           # Devolver puntero original
    
int_to_str_end:
    pop(s2)
    pop(s1)
    pop(s0)
    pop(ra)
    ret

#------------------------
# Shunting-yard Algorithm - Convertir infijo a RPN
#------------------------
shunting_yard:
    push(ra)
    push(s0)
    push(s1)
    push(s2)
    push(s3)
    push(s4)
    push(s5)
    
    la s0, buffer_exp   # Expresión de entrada
    la s1, rpn_queue    # Cola de salida RPN
    la s2, op_stack     # Pila de operadores
    li s3, 0            # Contador de operadores en pila
    
parse_loop:
    lbu t0, (s0)
    beqz t0, parse_end  # Fin de la expresión
    
    # Verificar si es un espacio
    li t1, ' '
    beq t0, t1, next_char
    li t1, '\t'
    beq t0, t1, next_char
    li t1, '\n'
    beq t0, t1, next_char
    
    # Verificar si es un dígito
    mv a0, t0
    jal is_digit
    bnez a0, process_number
    
    # Verificar si es paréntesis de apertura
    li t1, '('
    beq t0, t1, push_left_paren
    
    # Verificar si es paréntesis de cierre
    li t1, ')'
    beq t0, t1, process_right_paren
    
    # Verificar si es operador
    mv a0, t0
    jal is_operator
    beqz a0, parse_invalid
    
    # Procesar operador
    j process_operator
    
next_char:
    addi s0, s0, 1
    j parse_loop
    
#--- Procesar número ---
process_number:
    mv s5, s1           # Guardar posición actual en cola RPN
    
digit_loop:
    # Copiar dígito a la cola RPN
    sb t0, (s1)
    addi s1, s1, 1
    
    # Leer siguiente caracter
    addi s0, s0, 1
    lbu t0, (s0)
    
    # Verificar si sigue siendo dígito
    mv a0, t0
    jal is_digit
    bnez a0, digit_loop
    
    # Agregar espacio para separar el número
    li t1, ' '
    sb t1, (s1)
    addi s1, s1, 1
    
    j parse_loop  # Continuar con el siguiente token
    
#--- Procesar paréntesis izquierdo ---
push_left_paren:
    # Poner en la pila
    sb t0, (s2)
    addi s2, s2, 1
    addi s3, s3, 1
    addi s0, s0, 1
    j parse_loop
    
#--- Procesar paréntesis derecho ---
process_right_paren:
right_paren_loop:
    # Verificar pila vacía
    beqz s3, parse_invalid
    
    # Obtener operador del tope
    addi s2, s2, -1
    addi s3, s3, -1
    lbu t1, (s2)
    
    # Verificar si es paréntesis izquierdo
    li t2, '('
    beq t1, t2, right_paren_done
    
    # Poner operador en la cola
    sb t1, (s1)
    addi s1, s1, 1
    li t2, ' '
    sb t2, (s1)
    addi s1, s1, 1
    
    j right_paren_loop
    
right_paren_done:
    addi s0, s0, 1
    j parse_loop
    
#--- Procesar operador ---
process_operator:
    # Obtener precedencia del operador actual
    mv a0, t0
    jal get_precedence
    mv s4, a0  # s4 = precedencia del operador actual
    
op_loop:
    # Si la pila está vacía, poner operador en la pila
    beqz s3, push_operator
    
    # Obtener operador del tope sin sacarlo
    mv t1, s2
    addi t1, t1, -1
    lb t2, (t1)
    
    # Obtener precedencia del operador del tope
    mv t0, t2
    mv a0, t0
    jal get_precedence
    
    # Si precedencia tope <= actual, poner en pila
    ble a0, s4, push_operator
    
    # Sacar operador y ponerlo en la cola
    addi s2, s2, -1
    addi s3, s3, -1
    sb t2, (s1)
    addi s1, s1, 1
    li t3, ' '
    sb t3, (s1)
    addi s1, s1, 1
    
    j op_loop
    
push_operator:
    mv t0, s0
    lb t0, (t0)
    sb t0, (s2)
    addi s2, s2, 1
    addi s3, s3, 1
    addi s0, s0, 1
    j parse_loop
    
#--- Finalizar parsing ---
parse_end:
    # Vaciar la pila de operadores
empty_stack:
    beqz s3, parsing_successful
    
    addi s2, s2, -1
    addi s3, s3, -1
    lbu t0, (s2)
    
    # Verificar paréntesis izquierdo (error si queda alguno)
    li t1, '('
    beq t0, t1, parse_invalid
    
    # Agregar operador a la cola
    sb t0, (s1)
    addi s1, s1, 1
    li t1, ' '
    sb t1, (s1)
    addi s1, s1, 1
    
    j empty_stack
    
parsing_successful:
    # Terminar la cola con null
    sb zero, (s1)
    
    pop(s5)
    pop(s4)
    pop(s3)
    pop(s2)
    pop(s1)
    pop(s0)
    pop(ra)
    ret
    
parse_invalid:
    la a0, err_exp
    li a7, 4
    ecall
    
    pop(s5)
    pop(s4)
    pop(s3)
    pop(s2)
    pop(s1)
    pop(s0)
    pop(ra)
    j menu_loop

#------------------------
# is_digit - Verifica si un carácter es dígito
#------------------------
is_digit:
    li a0, 0
    li t1, '0'
    blt t0, t1, not_digit
    li t1, '9'
    bgt t0, t1, not_digit
    li a0, 1
not_digit:
    ret

#------------------------
# is_operator - Verifica si un carácter es operador
#------------------------
is_operator:
    li a0, 0
    li t1, '+'
    beq t0, t1, yes_op
    li t1, '-'
    beq t0, t1, yes_op
    li t1, '*'
    beq t0, t1, yes_op
    li t1, '/'
    beq t0, t1, yes_op
    li t1, '^'
    beq t0, t1, yes_op
    ret
yes_op:
    li a0, 1
    ret

#------------------------
# get_precedence - Obtiene precedencia de operador
#------------------------
get_precedence:
    li a0, 0
    li t1, '^'
    beq t0, t1, prec3
    li t1, '*'
    beq t0, t1, prec2
    li t1, '/'
    beq t0, t1, prec2
    li t1, '+'
    beq t0, t1, prec1
    li t1, '-'
    beq t0, t1, prec1
    ret
prec3:
    li a0, 3
    ret
prec2:
    li a0, 2
    ret
prec1:
    li a0, 1
    ret

#------------------------
# evaluar_rpn - Evalúa expresión en notación polaca
#------------------------
evaluar_rpn:
    push(ra)
    push(s0)
    push(s1)
    push(s2)
    
    la s0, rpn_queue    # Cola RPN
    la s1, num_stack    # Pila de números
    li s2, 0            # Elementos en la pila
    
rpn_loop:
    # Saltar espacios
    lbu t0, (s0)
    beqz t0, rpn_end    # Fin de la expresión
    
    li t1, ' '
    beq t0, t1, skip_space
    
    # Verificar si es operador
    li t1, '+'
    beq t0, t1, do_add
    li t1, '-'
    beq t0, t1, do_sub
    li t1, '*'
    beq t0, t1, do_mul
    li t1, '/'
    beq t0, t1, do_div
    li t1, '^'
    beq t0, t1, do_pow
    
    # Si no es operador, debe ser número
    jal parse_rpn_number
    j rpn_next
    
skip_space:
    addi s0, s0, 1
    j rpn_loop
    
#--- Operaciones ---
do_add:
    # Sacar dos operandos
    addi s1, s1, -4
    lw t1, (s1)  # Segundo operando
    addi s2, s2, -1
    
    addi s1, s1, -4
    lw t2, (s1)  # Primer operando
    addi s2, s2, -1
    
    # Realizar suma
    add t3, t2, t1
    
    # Guardar resultado
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1  # Avanzar al siguiente token
    j rpn_loop
    
do_sub:
    # Sacar dos operandos
    addi s1, s1, -4
    lw t1, (s1)  # Segundo operando
    addi s2, s2, -1
    
    addi s1, s1, -4
    lw t2, (s1)  # Primer operando
    addi s2, s2, -1
    
    # Realizar resta
    sub t3, t2, t1
    
    # Guardar resultado
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1  # Avanzar al siguiente token
    j rpn_loop
    
do_mul:
    # Sacar dos operandos
    addi s1, s1, -4
    lw t1, (s1)  # Segundo operando
    addi s2, s2, -1
    
    addi s1, s1, -4
    lw t2, (s1)  # Primer operando
    addi s2, s2, -1
    
    # Realizar multiplicación
    mul t3, t2, t1
    
    # Guardar resultado
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1  # Avanzar al siguiente token
    j rpn_loop
    
do_div:
    # Sacar dos operandos
    addi s1, s1, -4
    lw t1, (s1)  # Segundo operando
    addi s2, s2, -1
    
    addi s1, s1, -4
    lw t2, (s1)  # Primer operando
    addi s2, s2, -1
    
    # Verificar división por cero
    bnez t1, div_ok
    
    la a0, err_div0
    li a7, 4
    ecall
    
    # Valor por defecto en caso de error
    li t3, 0
    j div_done
    
div_ok:
    # Realizar división
    div t3, t2, t1
    
div_done:
    # Guardar resultado
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1  # Avanzar al siguiente token
    j rpn_loop
    
do_pow:
    # Sacar dos operandos
    addi s1, s1, -4
    lw t1, (s1)  # Exponente (segundo operando)
    addi s2, s2, -1
    
    addi s1, s1, -4
    lw t2, (s1)  # Base (primer operando)
    addi s2, s2, -1
    
    # Calcular potencia
    mv a0, t2     # Base
    mv a1, t1     # Exponente
    jal potencia
    mv t3, a0     # Resultado
    
    # Guardar resultado
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1  # Avanzar al siguiente token
    j rpn_loop
    
#--- Parsear número ---
parse_rpn_number:
    push(ra)
    li t2, 0      # Resultado
    li t3, 10     # Base decimal
    
rpn_num_loop:
    lbu t1, (s0)
    beqz t1, rpn_num_end
    
    li t4, ' '    # Espacio indica fin de número
    beq t1, t4, rpn_num_end
    
    mv t0, t1
    mv a0, t0
    jal is_digit
    beqz a0, rpn_num_end
    
    # Convertir dígito y acumular
    mul t2, t2, t3    # t2 = t2 * 10
    addi t1, t1, -48  # t1 = ASCII a valor
    add t2, t2, t1    # t2 = t2 + t1
    
    addi s0, s0, 1
    j rpn_num_loop
    
rpn_num_end:
    # Colocar número en la pila
    sw t2, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    pop(ra)
    ret
    
rpn_next:
    j rpn_loop
    
rpn_end:
    # Verificar que solo quede un número en la pila
    li t0, 1
    bne s2, t0, rpn_error
    
    # Obtener el resultado final
    addi s1, s1, -4
    lw s0, (s1)
    
    pop(s2)
    pop(s1)
    pop(s0)
    pop(ra)
    ret
    
rpn_error:
    la a0, err_exp
    li a7, 4
    ecall
    
    li s0, 0      # Resultado por defecto
    
    pop(s2)
    pop(s1)
    pop(s0)
    pop(ra)
    ret

#------------------------
# potencia - Calcula x^y
#------------------------
potencia:
    # a0 = base
    # a1 = exponente
    push(ra)
    push(s0)
    push(s1)
    
    mv s0, a0     # s0 = base
    mv s1, a1     # s1 = exponente
    
    # Caso especial: x^0 = 1
    bnez s1, not_exp_zero
    li a0, 1
    j pot_end
    
not_exp_zero:
    # Si exponente < 0, resultado = 0 (para enteros)
    bgez s1, pos_exp
    li a0, 0
    j pot_end
    
pos_exp:
    li a0, 1      # Resultado inicial
    
pot_loop:
    beqz s1, pot_end
    mul a0, a0, s0
    addi s1, s1, -1
    j pot_loop
    
pot_end:
    pop(s1)
    pop(s0)
    pop(ra)
    ret

exit:
    li a7, 10
    ecall
