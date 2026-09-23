# Programa RISC-V para operaciones básicas
# Lee dos dígitos y realiza suma, resta, multiplicación y división

.data
prompt1:    .string "Ingrese el primer digito (0-9): "
prompt2:    .string "Ingrese el segundo digito (0-9): "
suma_msg:   .string "\nSuma: "
resta_msg:  .string "\nResta: "
mult_msg:   .string "\nMultiplicacion: "
div_msg:    .string "\nDivision (cociente): "
res_msg:    .string "\nDivision (residuo): "
newline:    .string "\n"

.text
.globl main

main:
    # Leer primer dígito
    la a0, prompt1
    li a7, 4
    ecall               # Imprimir prompt
    
    li a7, 5
    ecall               # Leer entero
    mv s0, a0           # Guardar primer dígito en s0
    
    # Leer segundo dígito
    la a0, prompt2
    li a7, 4
    ecall               # Imprimir prompt
    
    li a7, 5
    ecall               # Leer entero
    mv s1, a0           # Guardar segundo dígito en s1
    
    # --- SUMA ---
    add t0, s0, s1      # t0 = s0 + s1
    
    la a0, suma_msg
    li a7, 4
    ecall               # Imprimir mensaje de suma
    
    mv a0, t0
    li a7, 1
    ecall               # Imprimir resultado de suma
    
    # --- RESTA ---
    sub t0, s0, s1      # t0 = s0 - s1
    
    la a0, resta_msg
    li a7, 4
    ecall               # Imprimir mensaje de resta
    
    mv a0, t0
    li a7, 1
    ecall               # Imprimir resultado de resta
    
    # --- MULTIPLICACIÓN ---
    mul t0, s0, s1      # t0 = s0 * s1
    
    la a0, mult_msg
    li a7, 4
    ecall               # Imprimir mensaje de multiplicación
    
    mv a0, t0
    li a7, 1
    ecall               # Imprimir resultado de multiplicación
    
    # --- DIVISIÓN ---
    div t0, s0, s1      # t0 = s0 / s1 (cociente)
    rem t1, s0, s1      # t1 = s0 % s1 (residuo)
    
    la a0, div_msg
    li a7, 4
    ecall               # Imprimir mensaje de división (cociente)
    
    mv a0, t0
    li a7, 1
    ecall               # Imprimir cociente
    
    la a0, res_msg
    li a7, 4
    ecall               # Imprimir mensaje de división (residuo)
    
    mv a0, t1
    li a7, 1
    ecall               # Imprimir residuo
    
    # Salida limpia
    la a0, newline
    li a7, 4
    ecall
    
    # Terminar programa
    li a7, 10
    ecall