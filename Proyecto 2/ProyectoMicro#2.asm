.data
    menu:       .string "\nMenu:\n1. Ingresar expresion\n2. Ingresar X (hexadecimal)\n3. Evaluar\n4. Salir\nOpcion: "
    prompt_exp: .string "\nIngrese la expresion (ej: (x+4)*5^x): "
    prompt_x:   .string "\nIngrese X (hexadecimal): "
    resultado:  .string "\nResultado: "
    buffer_exp: .space 256
    buffer_x:   .space 32
    .align 4
    x_value:    .word 0
    x_set:      .word 0     # Flag para verificar si X fue ingresado
    err_div0:   .string "\nError: Division por cero"
    err_exp:    .string "\nError: Expresion invalida"
    err_char:   .string "\nError: Caracter invalido encontrado"
    err_paren:  .string "\nError: Parentesis no balanceados"
    err_empty:  .string "\nError: Expresion vacia"
    err_no_x:   .string "\nError: Debe ingresar X primero"
    err_incomplete: .string "\nError: Expresion incompleta"
    newline:    .string "\n"
    .align 4
    rpn_queue:  .space 512
    op_stack:   .space 128
    num_stack:  .space 512

.text
.globl _start

# Configurar stack pointer inicial
_start:
    li t0, 0x10010000
    mv sp, t0

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

# Opción 1: Leer expresión con validación
opcion1:
    la a0, prompt_exp
    li a7, 4
    ecall
    la a0, buffer_exp
    li a1, 256
    li a7, 8
    ecall
    
    # Validar expresión
    la a0, buffer_exp
    jal validar_expresion
    bnez a0, invalid_expr
    j menu_loop
    
invalid_expr:
    mv t0, a0
    li t1, 1
    beq t0, t1, show_char_error
    li t1, 2
    beq t0, t1, show_paren_error
    li t1, 3
    beq t0, t1, show_empty_error
    li t1, 4
    beq t0, t1, show_incomplete_error
    j menu_loop
    
show_char_error:
    la a0, err_char
    j show_error
show_paren_error:
    la a0, err_paren
    j show_error
show_empty_error:
    la a0, err_empty
    j show_error
show_incomplete_error:
    la a0, err_incomplete
show_error:
    li a7, 4
    ecall
    j menu_loop

# Opción 2: Leer X (hexadecimal)
opcion2:
    la a0, prompt_x
    li a7, 4
    ecall
    la a0, buffer_x
    li a1, 32
    li a7, 8
    ecall
    
    # Convertir hex a entero
    la a0, buffer_x
    jal hex_to_int
    
    # Guardar el valor
    la t0, x_value
    sw a0, (t0)
    li t1, 1
    la t0, x_set
    sw t1, (t0)    # Marcar que X fue ingresado
    
    # Debug: mostrar el valor leído
    la a0, newline
    li a7, 4
    ecall
    la a0, newline
    li a7, 4
    ecall
    la t0, x_value
    lw a0, (t0)
    li a7, 1
    ecall
    la a0, newline
    li a7, 4
    ecall
    
    j menu_loop

# Opción 3: Evaluar
opcion3:
    # Verificar que X fue ingresado
    lw t0, x_set
    beqz t0, no_x_error
    
    # Verificar que hay expresión
    la t0, buffer_exp
    lbu t1, (t0)
    beqz t1, empty_expr_error
    
    # Sustituir X
    la a0, buffer_exp
    lw a1, x_value
    jal sustituir_x
    
    # Convertir a RPN
    jal shunting_yard
    
    # Evaluar RPN
    jal evaluar_rpn
    bnez t6, eval_error_main    # t6 se usa para errores
    
    # Mostrar resultado
    la a0, resultado
    li a7, 4
    ecall
    mv a0, a1  # El resultado viene en a1
    li a7, 1
    ecall
    
    j menu_loop
    
no_x_error:
    la a0, err_no_x
    li a7, 4
    ecall
    j menu_loop
    
empty_expr_error:
    la a0, err_empty
    li a7, 4
    ecall
    j menu_loop
    
eval_error_main:
    la a0, err_exp
    li a7, 4
    ecall
    j menu_loop

# Validar expresión completa
validar_expresion:
    # Guardar registros
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    
    mv s0, a0        # buffer
    li s1, 0         # contador paréntesis
    li s2, 0         # flag último caracter operador
    li s3, 0         # flag expresión no vacía
    
    # Verificar si está vacía
    lbu t0, (s0)
    beqz t0, val_empty
    li t1, '\n'
    beq t0, t1, val_empty
    
val_loop:
    lbu t0, (s0)
    beqz t0, val_end
    li t1, '\n'
    beq t0, t1, val_end
    
    # Marcar que hay contenido
    li s3, 1
    
    # Verificar caracteres válidos
    li t1, ' '
    beq t0, t1, val_next
    li t1, '\t'
    beq t0, t1, val_next
    
    # Dígitos
    li t1, '0'
    blt t0, t1, no_digit_val
    li t1, '9'
    ble t0, t1, digit_val
    
no_digit_val:
    # Variable x/X
    li t1, 'x'
    beq t0, t1, var_val
    li t1, 'X'
    beq t0, t1, var_val
    
    # Operadores
    li t1, '+'
    beq t0, t1, op_val
    li t1, '-'
    beq t0, t1, handle_minus_val
    li t1, '*'
    beq t0, t1, op_val
    li t1, '/'
    beq t0, t1, op_val
    li t1, '^'
    beq t0, t1, op_val
    
    # Paréntesis
    li t1, '('
    beq t0, t1, lparen_val
    li t1, ')'
    beq t0, t1, rparen_val
    
    # Caracter inválido
    li a0, 1    # Error tipo caracter inválido
    j val_done
    
digit_val:
var_val:
    li s2, 0    # No es operador
    j val_next
    
handle_minus_val:
    # El signo menos puede ser unario al inicio o después de operador/paréntesis
    beqz s3, val_next    # Al inicio está bien
    addi t1, s0, -1
    lbu t2, (t1)
    li t3, '('
    beq t2, t3, val_next
    li t3, '+'
    beq t2, t3, val_next
    li t3, '-'
    beq t2, t3, val_next
    li t3, '*'
    beq t2, t3, val_next
    li t3, '/'
    beq t2, t3, val_next
    li t3, '^'
    beq t2, t3, val_next
    # Si no es después de operador, tratar como operador
    j op_val
    
op_val:
    # Verificar que no hay dos operadores seguidos
    bnez s2, val_incomplete
    li s2, 1    # Marcar como operador
    j val_next
    
lparen_val:
    addi s1, s1, 1
    li s2, 0
    j val_next
    
rparen_val:
    addi s1, s1, -1
    blt s1, zero, val_paren_error
    li s2, 0
    j val_next
    
val_next:
    addi s0, s0, 1
    j val_loop
    
val_end:
    # Verificar paréntesis balanceados
    bnez s1, val_paren_error
    # Verificar que no termina en operador
    bnez s2, val_incomplete
    # Verificar que no está vacía
    beqz s3, val_empty
    
    # Todo OK
    li a0, 0
    j val_done
    
val_empty:
    li a0, 3
    j val_done
    
val_paren_error:
    li a0, 2
    j val_done
    
val_incomplete:
    li a0, 4
    
val_done:
    lw ra, 16(sp)
    lw s0, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 20
    ret

# Conversión hexadecimal a entero (soporta negativos)
hex_to_int:
    li t1, 0      # resultado
    li t3, 16     # base
    li t5, 0      # flag negativo
    
    # Verificar signo
    lbu t2, (a0)
    li t4, '-'
    bne t2, t4, loop_hex
    li t5, 1
    addi a0, a0, 1
    
loop_hex:
    lbu t2, (a0)
    beqz t2, end_hex
    
    # Verificar fin de línea
    li t4, '\n'
    beq t2, t4, end_hex
    li t4, '\r'
    beq t2, t4, end_hex
    li t4, ' '
    beq t2, t4, end_hex
    
    # Inicializar valor del dígito
    li t6, -1     # -1 indica dígito inválido
    
    # Verificar si es dígito 0-9
    li t4, '0'
    blt t2, t4, not_decimal
    li t4, '9'
    bgt t2, t4, not_decimal
    # Es dígito 0-9
    addi t6, t2, -48
    j found_digit
    
not_decimal:
    # Verificar si es letra mayúscula A-F
    li t4, 'A'
    blt t2, t4, not_upper
    li t4, 'F'
    bgt t2, t4, not_upper
    # Es letra A-F
    addi t6, t2, -55    # 'A' = 65, 65-55 = 10
    j found_digit
    
not_upper:
    # Verificar si es letra minúscula a-f
    li t4, 'a'
    blt t2, t4, invalid_char
    li t4, 'f'
    bgt t2, t4, invalid_char
    # Es letra a-f
    addi t6, t2, -87    # 'a' = 97, 97-87 = 10
    j found_digit
    
invalid_char:
    # Caracter inválido, terminar
    j end_hex
    
found_digit:
    # t6 contiene el valor del dígito (0-15)
    # Multiplicar resultado actual por 16 y sumar nuevo dígito
    mul t1, t1, t3
    add t1, t1, t6
    addi a0, a0, 1
    j loop_hex
    
end_hex:
    # Aplicar signo si es negativo
    beqz t5, no_negate
    neg t1, t1
no_negate:
    mv a0, t1
    ret

# Sustituir X por su valor (maneja negativos)
sustituir_x:
    # Guardar registros
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    
    mv s0, a0     # buffer_exp
    mv s1, a1     # valor de X
    
    # Buffer temporal
    addi sp, sp, -256
    mv s2, sp
    mv s3, sp     # puntero de escritura
    
    # Procesar cada caracter
loop_sustituir:
    lbu t0, (s0)
    beqz t0, end_sustituir
    
    # Verificar si es 'x' o 'X'
    li t1, 'x'
    beq t0, t1, reemplazar_x
    li t1, 'X'
    beq t0, t1, reemplazar_x
    
    # Copiar caracter normal
    sb t0, (s3)
    addi s3, s3, 1
    addi s0, s0, 1
    j loop_sustituir
    
reemplazar_x:
    # Debug: mostrar valor de s1 antes de convertir
    mv a0, s1
    li a7, 1
    ecall
    la a0, newline
    li a7, 4
    ecall
    
    # Si X es negativo, agregar paréntesis
    bgez s1, positive_x
    li t0, '('
    sb t0, (s3)
    addi s3, s3, 1
    
positive_x:
    # Convertir número a string
    mv a0, s1
    mv a1, s3
    jal int_to_str
    
    # Debug: mostrar string generado
    mv a0, s3
    li a7, 4
    ecall
    la a0, newline
    li a7, 4
    ecall
    
    # Avanzar puntero por longitud del número
    mv a0, s3
    jal strlen
    add s3, s3, a0
    
    # Si X era negativo, cerrar paréntesis
    bgez s1, no_close_paren
    li t0, ')'
    sb t0, (s3)
    addi s3, s3, 1
    
no_close_paren:
    addi s0, s0, 1
    j loop_sustituir
    
end_sustituir:
    sb zero, (s3)
    
    # Copiar de vuelta
    la a0, buffer_exp
    mv a1, s2
    jal strcpy
    
    # Restaurar stack y registros
    addi sp, sp, 256
    lw ra, 16(sp)
    lw s0, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 20
    ret

# Calcular longitud de string
strlen:
    li t0, 0
strlen_loop:
    lbu t1, (a0)
    beqz t1, strlen_end
    addi t0, t0, 1
    addi a0, a0, 1
    j strlen_loop
strlen_end:
    mv a0, t0
    ret

# Copiar string
strcpy:
    mv t0, a0
strcpy_loop:
    lbu t1, (a1)
    sb t1, (a0)
    beqz t1, strcpy_end
    addi a0, a0, 1
    addi a1, a1, 1
    j strcpy_loop
strcpy_end:
    mv a0, t0
    ret

# Convertir entero a string (maneja negativos)
int_to_str:
    # Guardar registros
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)
    
    mv s0, a0     # número
    mv s1, a1     # buffer
    mv s2, a1     # guardar inicio
    
    # Manejar cero
    bnez s0, no_zero
    li t0, '0'
    sb t0, (s1)
    addi s1, s1, 1
    sb zero, (s1)
    mv a0, s2
    j int_to_str_end
    
no_zero:
    # Manejar negativo
    bgez s0, positivo
    li t0, '-'
    sb t0, (s1)
    addi s1, s1, 1
    neg s0, s0
    
positivo:
    # Extraer dígitos y obtener posición final
    mv a0, s0
    mv a1, s1
    jal extract_digits
    mv s1, a0      # a0 contiene la posición final
    
    # Agregar terminador null
    sb zero, (s1)
    
    mv a0, s2
    
int_to_str_end:
    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 16
    ret

# Extraer dígitos recursivamente
extract_digits:
    # Si n < 10, terminar recursión
    li t0, 10
    blt a0, t0, single_digit
    
    # Guardar registros
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw a0, 4(sp)
    sw a1, 0(sp)
    
    # Calcular n/10
    div s0, a0, t0
    
    # Llamada recursiva con n/10
    mv a0, s0
    jal extract_digits
    mv a1, a0      # a0 contiene nueva posición
    
    # Restaurar número original
    lw a0, 4(sp)
    
    # Calcular residuo (último dígito)
    li t0, 10
    rem t1, a0, t0
    
    # Convertir a ASCII y guardar
    addi t1, t1, 48
    sb t1, (a1)
    addi a1, a1, 1
    
    # Retornar nueva posición
    mv a0, a1
    
    # Restaurar ra y s0
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret
    
single_digit:
    # Convertir dígito único a ASCII
    addi t1, a0, 48
    sb t1, (a1)
    addi a1, a1, 1
    # Retornar nueva posición (NO poner null here)
    mv a0, a1
    ret

# Algoritmo Shunting-Yard mejorado
shunting_yard:
    # Guardar registros
    addi sp, sp, -28
    sw ra, 24(sp)
    sw s0, 20(sp)
    sw s1, 16(sp)
    sw s2, 12(sp)
    sw s3, 8(sp)
    sw s4, 4(sp)
    sw s5, 0(sp)
    
    la s0, buffer_exp    # entrada
    la s1, rpn_queue     # salida
    la s2, op_stack      # pila operadores
    li s3, 0             # contador pila
    li s4, 0             # flag último token fue operador
    
    # Limpiar salida
    sb zero, (s1)
    
parse_token:
    lbu t0, (s0)
    beqz t0, finish_parsing
    
    # Saltar espacios
    li t1, ' '
    beq t0, t1, next_token
    li t1, '\t'
    beq t0, t1, next_token
    li t1, '\n'
    beq t0, t1, finish_parsing
    
    # Verificar si es dígito
    li t1, '0'
    blt t0, t1, no_digit
    li t1, '9'
    bgt t0, t1, no_digit
    
    # Procesar número completo
    li s4, 0    # No es operador
process_num:
    lbu t0, (s0)
    li t1, '0'
    blt t0, t1, num_done
    li t1, '9'
    bgt t0, t1, num_done
    
    sb t0, (s1)
    addi s1, s1, 1
    addi s0, s0, 1
    j process_num
    
num_done:
    li t1, ' '
    sb t1, (s1)
    addi s1, s1, 1
    j parse_token
    
no_digit:
    # Verificar paréntesis
    li t1, '('
    beq t0, t1, push_lparen
    
    li t1, ')'
    beq t0, t1, handle_rparen
    
    # Verificar operadores
    li t1, '+'
    beq t0, t1, handle_operator
    li t1, '-'
    beq t0, t1, handle_minus
    li t1, '*'
    beq t0, t1, handle_operator
    li t1, '/'
    beq t0, t1, handle_operator
    li t1, '^'
    beq t0, t1, handle_operator
    
next_token:
    addi s0, s0, 1
    j parse_token
    
handle_minus:
    # Determinar si es unario o binario
    # Es unario si está al inicio o después de ( o operador
    bnez s4, unary_minus
    
    # Verificar caracter anterior
    beq s0, zero, unary_minus  # Al inicio
    addi t1, s0, -1
    lbu t2, (t1)
    li t3, '('
    beq t2, t3, unary_minus
    li t3, '+'
    beq t2, t3, unary_minus
    li t3, '-'
    beq t2, t3, unary_minus
    li t3, '*'
    beq t2, t3, unary_minus
    li t3, '/'
    beq t2, t3, unary_minus
    li t3, '^'
    beq t2, t3, unary_minus
    
    # Es binario
    j handle_operator
    
unary_minus:
    # Tratar como número 0 seguido de resta
    li t0, '0'
    sb t0, (s1)
    addi s1, s1, 1
    li t0, ' '
    sb t0, (s1)
    addi s1, s1, 1
    li t0, '-'
    j handle_operator
    
push_lparen:
    sb t0, (s2)
    addi s2, s2, 1
    addi s3, s3, 1
    li s4, 1    # Después de ( es como operador
    addi s0, s0, 1
    j parse_token
    
handle_rparen:
    li s4, 0    # No es operador
rparen_loop:
    beqz s3, parse_error
    
    addi s2, s2, -1
    addi s3, s3, -1
    lbu t1, (s2)
    
    li t2, '('
    beq t1, t2, rparen_done
    
    sb t1, (s1)
    addi s1, s1, 1
    li t2, ' '
    sb t2, (s1)
    addi s1, s1, 1
    
    j rparen_loop
    
rparen_done:
    addi s0, s0, 1
    j parse_token
    
handle_operator:
    li s4, 1    # Es operador
    mv a0, t0
    jal get_precedence
    mv s5, a0  # precedencia actual
    
op_compare:
    beqz s3, push_op
    
    # Ver tope sin sacarlo
    addi t1, s2, -1
    lbu t2, (t1)
    
    li t1, '('
    beq t2, t1, push_op
    
    # Obtener precedencia del tope
    mv a0, t2
    jal get_precedence
    mv s5, a0
    
    # Comparar precedencias
    # Para ^ (asociativo derecha): solo sacar si precedencia > actual
    li t1, '^'
    beq t0, t1, handle_power_prec
    
    # Para otros (asociativo izquierda): sacar si precedencia >= actual
    blt s5, a0, push_op
    
pop_op:
    addi s2, s2, -1
    addi s3, s3, -1
    sb t2, (s1)
    addi s1, s1, 1
    li t3, ' '
    sb t3, (s1)
    addi s1, s1, 1
    j op_compare
    
handle_power_prec:
    bgt s5, a0, pop_op
    
push_op:
    sb t0, (s2)
    addi s2, s2, 1
    addi s3, s3, 1
    addi s0, s0, 1
    j parse_token
    
finish_parsing:
    # Vaciar pila de operadores
empty_ops:
    beqz s3, parsing_done
    
    addi s2, s2, -1
    addi s3, s3, -1
    lbu t0, (s2)
    
    li t1, '('
    beq t0, t1, parse_error
    
    sb t0, (s1)
    addi s1, s1, 1
    li t1, ' '
    sb t1, (s1)
    addi s1, s1, 1
    
    j empty_ops
    
parsing_done:
    # Remover último espacio y terminar
    beqz s1, parse_error    # No hay nada
    la t0, rpn_queue
    bne s1, t0, has_content
    j parse_error
    
has_content:
    addi s1, s1, -1
    sb zero, (s1)
    
    # Restaurar registros
    lw ra, 24(sp)
    lw s0, 20(sp)
    lw s1, 16(sp)
    lw s2, 12(sp)
    lw s3, 8(sp)
    lw s4, 4(sp)
    lw s5, 0(sp)
    addi sp, sp, 28
    ret
    
parse_error:
    la a0, err_exp
    li a7, 4
    ecall
    j parsing_done

# Obtener precedencia de operador
get_precedence:
    li a0, 0
    li t1, '^'
    beq t0, t1, prec_3
    li t1, '*'
    beq t0, t1, prec_2
    li t1, '/'
    beq t0, t1, prec_2
    li t1, '+'
    beq t0, t1, prec_1
    li t1, '-'
    beq t0, t1, prec_1
    ret
prec_3:
    li a0, 3
    ret
prec_2:
    li a0, 2
    ret
prec_1:
    li a0, 1
    ret

# Evaluar expresión RPN mejorado
evaluar_rpn:
    # Guardar registros
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    
    la s0, rpn_queue   # entrada RPN
    la s1, num_stack   # pila de números
    li s2, 0           # contador de pila
    li t6, 0           # flag de error
    
eval_loop:
    lbu t0, (s0)
    beqz t0, eval_done
    
    # Saltar espacios
    li t1, ' '
    beq t0, t1, skip_char
    
    # Verificar operadores
    li t1, '+'
    beq t0, t1, op_add
    li t1, '-'
    beq t0, t1, op_sub
    li t1, '*'
    beq t0, t1, op_mul
    li t1, '/'
    beq t0, t1, op_div
    li t1, '^'
    beq t0, t1, op_pow
    
    # Es un número, parsearlo
    jal parse_number
    j eval_loop
    
skip_char:
    addi s0, s0, 1
    j eval_loop
    
# Parsear número desde RPN (soporta negativos)
parse_number:
    li t2, 0      # acumulador
    li t3, 10     # base
    li t4, 0      # flag negativo
    
    # Verificar signo
    lbu t1, (s0)
    li t5, '-'
    bne t1, t5, parse_digit
    li t4, 1
    addi s0, s0, 1
    
parse_digit:
    lbu t1, (s0)
    li t5, '0'
    blt t1, t5, push_number
    li t5, '9'
    bgt t1, t5, push_number
    
    addi t1, t1, -48  # ASCII a número
    mul t2, t2, t3    # t2 = t2 * 10
    add t2, t2, t1    # t2 = t2 + dígito
    addi s0, s0, 1
    j parse_digit
    
push_number:
    # Aplicar signo si es negativo
    beqz t4, no_neg
    neg t2, t2
no_neg:
    # Guardar en pila
    sw t2, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    ret

# Operaciones aritméticas mejoradas
op_add:
    li t5, 2
    blt s2, t5, eval_error
    
    # Sacar dos operandos
    addi s1, s1, -4
    lw t1, (s1)     # segundo operando
    addi s1, s1, -4
    lw t2, (s1)     # primer operando
    addi s2, s2, -2
    
    # Realizar operación
    add t3, t2, t1
    
    # Guardar resultado
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1
    j eval_loop
    
op_sub:
    li t5, 2
    blt s2, t5, eval_error
    
    addi s1, s1, -4
    lw t1, (s1)
    addi s1, s1, -4
    lw t2, (s1)
    addi s2, s2, -2
    
    sub t3, t2, t1
    
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1
    j eval_loop
    
op_mul:
    li t5, 2
    blt s2, t5, eval_error
    
    addi s1, s1, -4
    lw t1, (s1)
    addi s1, s1, -4
    lw t2, (s1)
    addi s2, s2, -2
    
    mul t3, t2, t1
    
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1
    j eval_loop
    
op_div:
    li t5, 2
    blt s2, t5, eval_error
    
    addi s1, s1, -4
    lw t1, (s1)
    addi s1, s1, -4
    lw t2, (s1)
    addi s2, s2, -2
    
    beqz t1, div_error
    div t3, t2, t1
    j div_ok
    
div_error:
    la a0, err_div0
    li a7, 4
    ecall
    li t6, 1    # Marcar error
    li t3, 0
    
div_ok:
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1
    j eval_loop
    
op_pow:
    li t5, 2
    blt s2, t5, eval_error
    
    addi s1, s1, -4
    lw t1, (s1)    # exponente
    addi s1, s1, -4
    lw t2, (s1)    # base
    addi s2, s2, -2
    
    # Verificar exponente negativo
    blt t1, zero, pow_neg_exp
    
    # Calcular potencia
    mv a0, t2
    mv a1, t1
    jal potencia
    mv t3, a0
    j pow_done
    
pow_neg_exp:
    # Para exponentes negativos, 1/base^|exp|
    beqz t2, pow_base_zero_neg
    neg t1, t1
    mv a0, t2
    mv a1, t1
    jal potencia
    mv t2, a0
    li t3, 1
    div t3, t3, t2
    j pow_done
    
pow_base_zero_neg:
    li t6, 1    # Error: 0^(-n)
    li t3, 0
    
pow_done:
    sw t3, (s1)
    addi s1, s1, 4
    addi s2, s2, 1
    
    addi s0, s0, 1
    j eval_loop
    
eval_done:
    # Verificar que quede exactamente un valor
    li t5, 1
    bne s2, t5, eval_error
    
    # Obtener resultado final
    addi s1, s1, -4
    lw a1, (s1)    # El resultado va en a1
    
    # Restaurar registros
    lw ra, 16(sp)
    lw s0, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 20
    ret
    
eval_error:
    li t6, 1    # Marcar error
    li a1, 0
    j eval_done

# Función potencia mejorada
potencia:
    # Casos especiales
    beqz a1, pot_cero      # x^0 = 1
    li t0, 1
    beq a1, t0, pot_uno    # x^1 = x
    beqz a0, pot_base_cero # 0^n = 0 (si n > 0)
    
    # Verificar exponente negativo (no debería llegar aquí)
    blt a1, zero, pot_error
    
    # Calcular potencia iterativamente
    li t0, 1              # resultado = 1
    mv t1, a0             # base
    mv t2, a1             # exponente
    
pot_loop:
    beqz t2, pot_fin
    mul t0, t0, t1
    addi t2, t2, -1
    j pot_loop
    
pot_cero:
    li a0, 1
    ret
    
pot_uno:
    ret
    
pot_base_cero:
    li a0, 0
    ret
    
pot_error:
    li a0, 0
    ret
    
pot_fin:
    mv a0, t0
    ret

# Salir del programa
exit:
    li a7, 10
    ecall