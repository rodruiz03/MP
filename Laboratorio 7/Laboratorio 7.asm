# comentarios van: #
# Si es keysensitve, instrucciones en minuscula
# Todos los numeros son por defecto decimales
.global programa #Establecemos punto de arranque
.data # segmento de datos
	hola: .string "Hola Inge Como esta"
.text # segemento de codigo
# nombre ":" .tipo valor
programa:
li a0, 5		
addi a0, a0, 48		
li a7, 11		
ecall
#Imprimir cadena
la a0, hola		
li a7, 4		
ecall

# Ejercicio 3
mv s11, t3
