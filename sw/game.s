.section .text
.global _start

#=====================================================================
#                       Direcciones de memoria
#=====================================================================
# x0 = 0
# x1 = Contador de rondas
# x2 = Dirección base de todos los périfericos (x080000)
# x3 = Display
# x4 = LEDs
# x5 = Botones
# x6 = Reloj/Cycle counter
# x7 = Registro temporal (buffer)
# x8 = Acumulador global de tiempo total
# x9 = Constantes grandes (para las esperas de 3s y los 2.500.000 ciclos)
# x10 = Registro matemático temporal
# x11 = Número aleatorio original
# x12 = El LED traducido en bits
# x13 = Tiempo exacto en el que se encendió el LED objetivo
# x14 = Boton presionado fisicamente
# x15 = Tiempo de reacción crudo del jugador



_start:
# ====================================================================
#                      CONFIGURACION INICIAL
#=====================================================================

    addi x1, x0, 0      # Number of rounds initialized to 0
    addi x8, x0, 0      # Initialize the total time accumulator to 0

    # MMIO addresses
    lui  x2, 0x80000    # Carga en los 20 bits superiores. x2 será la dirección base de periféricos
    addi x3, x2, 0      # Display
    addi x4, x2, 4      # LEDs
    addi x5, x2, 8      # Buttons
    addi x6, x2, 12     # Cycle counter


start_round:

wait_release:
    lw x14, 0(x5) # Lee los botones
    bne x14, x0, wait_release # Si se sigue presionando (!= 0), sigue esperando

    # Encendemos los 4 LEDs para indicar que empezo la espera
    addi x7, x0, 15 
    sw x7, 0(x4)

    # Guarda el cycle counter inicial de la ronda
    lw x7, 0(x6) 

    # Cargar los 75mm de ciclos (3 segundos en 25 MHz)
    lui  x9, 0x4787
    addi x9, x9, -1856 


wait_3s:
    # x10 = contador actual
    lw   x10, 0(x6)
    # x10 = contador actual - contador inicial
    sub  x10, x10, x7
    # Si los ciclos transcurridos son < 75.000.000, vuelve a wait_3s
    bltu x10, x9, wait_3s

    # Pseudo-random
    lw   x11, 0(x6)
    xor x11, x11, x15
    andi x11, x11, 3

    # Convierte 0–3 en el LED correspondiente
    beq  x11, x0, target_0

    addi x12, x0, 1
    beq  x11, x12, target_1

    addi x12, x0, 2
    beq  x11, x12, target_2

    # Otherwise target = 3
    addi x12, x0, 8
    jal  x0, show_target

target_0:
    addi x12, x0, 1
    jal  x0, show_target

target_1:
    addi x12, x0, 2
    jal  x0, show_target

target_2:
    addi x12, x0, 4

show_target:
    sw   x12, 0(x4)
    lw   x13, 0(x6)

wait_button:
    lw   x14, 0(x5)
    beq  x14, x0, wait_button  

    # Capturar tiempo de reaccion en ccclos
    lw   x15, 0(x6)
    sub  x15, x15, x13

    # Checkear el botón presionado, respecto al target 
    beq  x14, x12, correct
    jal  x0, wrong

correct: 
    sw x0, 0(x4) # Apaga los leds indiando el fin de la ronda


    # Se cargan las 2.500.00 décimas de segundo en x9 (0x002625A0 en hexadecimal)
    lui x9, 0x262 # Toma la sección 00262 de las decimas y lo guarda en el registro (0x00262000)
    addi x9, x9, 0x5A0 # Le suma el restante de las décimas (5A0)

    addi x10, x0 , 0 # Inicializa el contador de décimas en 0

resta_sucesiva:

    # si los ciclos en x15 son menores a 2.500.000 (x9), se termina la división
    bltu x15, x9, fin_division

    sub x15, x15, x9 # Restamos 2.500.000 a los ciclos totales
    addi x10, x10, 1 # sumamos uno al contador de décimas
    j resta_sucesiva # volvemos a realizar la resta

fin_division:

    sw x10, 0(x3) # enviamos las decimas de segundo exactas al Display de 7 segmentos
    add x8, x8, x10 # Suma el tiempo de esta ronda al total (x8)
    addi x1, x1, 1 # Sumamos uno al contador de rondas (x1 = x1 + 1)
    addi x7, x0 , 10 # Guardamos un 10 en nuestro registro de datos temporales
    bne x1, x7, start_round # Si las rondas (x1) no son 10 (x7), salta a la seccion wait_3s

game_over: 

    # Se prepara la división por 10 (total acumulado en x8 / 10)
    addi x7, x0, 10 # el divisor será 10
    addi x10, x0, 0

resta_promedio:
    # Si el tiempo total (x8) es menor a 10, se termina la división
    bltu x8, x7, fin_promedio 
    sub x8, x8, x7 # Restamos 10 al total
    addi x10, x10, 1 # Sumamos uno al promedio final
    j resta_promedio

fin_promedio:
    sw x10, 0(x3) # Se mustra el promedio exacto en el Display de 7 segmentos

trampa_infinita:
    lw x14, 0(x5) # Lee los botones
    beq x14, x0, trampa_infinita # Si todos estan en cero, sigue mostrando el promedio
    j _start # si se presiona cualquier boton es enviado al inicio

wrong: 
   # Prende los leds indicando que hay un error (15 en binario = 1111)
    addi x7, x0, 15
    sw x7, 0(x4) 
    j start_round # Devuelve a la sección de start_round ya que no cuenta como ronda ganada
