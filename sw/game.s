.section .text
.global _start

#=====================================================================
#                       Direcciones de memoria
#=====================================================================
# x0 = 0
# x1 = Contador de rondas correctas
# x2 = Dirección base de todos los periféricos (0x80000000)
# x3 = Display
# x4 = LEDs
# x5 = Botones
# x6 = Reloj/Cycle counter
# x7 = Registro temporal (buffer)
# x8 = Acumulador global de tiempo total (en décimas)
# x9 = Constantes grandes (para las esperas de 3s y los 2.500.000 ciclos)
# x10 = Registro matemático temporal
# x11 = Número aleatorio original
# x12 = El LED traducido en bits
# x13 = Tiempo exacto en el que se encendió el LED objetivo
# x14 = Boton presionado fisicamente
# x15 = Semilla / tiempo de reacción crudo del jugador



_start:
# ====================================================================
#                      CONFIGURACION INICIAL
#=====================================================================

    addi x1, x0, 0      # Contador de rondas en 0
    addi x8, x0, 0      # Acumulador de tiempo total en 0

    # MMIO addresses
    lui  x2, 0x80000    # Carga en los 20 bits superiores. x2 será la dirección base de periféricos
    addi x3, x2, 0      # Display
    addi x4, x2, 4      # LEDs
    addi x5, x2, 8      # Buttons
    addi x6, x2, 12     # Cycle counter

# ====================================================================
#                ESPERA DE INICIO + SEMILLA ALEATORIA
#=====================================================================
# Se encienden los LEDs de los extremos (1001) para indicar "listo,
# presiona cualquier botón para empezar"

    addi x7, x0, 9      # 9 = 1001 en binario
    sw   x7, 0(x4)

wait_start:
    lw   x14, 0(x5)                 # Lee los botones
    beq  x14, x0, wait_start        # Si no hay ninguno presionado, sigue esperando
    lw   x15, 0(x6)                 # Semilla = contador de ciclos al presionar


start_round:

wait_release:
    lw x14, 0(x5) # Lee los botones
    bne x14, x0, wait_release # Si se sigue presionando (!= 0), sigue esperando

    # Encendemos los 4 LEDs para indicar que empezo la espera
    addi x7, x0, 15
    sw x7, 0(x4)

    # Guarda el cycle counter inicial de la ronda
    lw x7, 0(x6)

    # Cargar los 75.000.000 de ciclos (3 segundos en 25 MHz)
    lui  x9, 0x4787
    addi x9, x9, -1856


wait_3s:
    # x10 = contador actual
    lw   x10, 0(x6)
    # x10 = contador actual - contador inicial
    sub  x10, x10, x7
    # Si los ciclos transcurridos son < 75.000.000, vuelve a wait_3s
    bltu x10, x9, wait_3s

    # Pseudo-random: contador actual XOR semilla / tiempo anterior
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

    # Capturar tiempo de reaccion en ciclos
    lw   x15, 0(x6)
    sub  x15, x15, x13

    # Checkear el botón presionado, respecto al target
    beq  x14, x12, correct
    jal  x0, wrong

correct:
    sw x0, 0(x4) # Apaga los leds indicando el fin de la ronda


    # Se cargan los 2.500.000 ciclos de una décima de segundo en x9 (0x002625A0 en hexadecimal)
    lui x9, 0x262 # Toma la sección 00262 y la guarda en el registro (0x00262000)
    addi x9, x9, 0x5A0 # Le suma el restante (5A0)

    addi x10, x0 , 0 # Inicializa el contador de décimas en 0

resta_sucesiva:

    # si los ciclos en x15 son menores a 2.500.000 (x9), se termina la división
    bltu x15, x9, fin_division

    sub x15, x15, x9 # Restamos 2.500.000 a los ciclos totales
    addi x10, x10, 1 # sumamos uno al contador de décimas
    j resta_sucesiva # volvemos a realizar la resta

fin_division:

    # Límite de 99 décimas (9,9 s): el display solo tiene 2 dígitos.
    # Si x10 >= 100, se fija en 99. Se aplica antes de acumular para que
    # el promedio sea consistente con los tiempos mostrados.
    addi x7, x0, 100
    bltu x10, x7, sin_limite    # Si x10 < 100, no hay que limitar
    addi x10, x0, 99            # Si no, se limita a 99

sin_limite:

    add x8, x8, x10 # Suma el tiempo de esta ronda al total (x8) en BINARIO

    # Convertimos x10 a BCD (Binary-Coded Decimal) usando x9 para las decenas
    addi x7, x0, 10
    addi x9, x0, 0 # x9 será el contador de decenas

bcd_ronda:

    bltu x10, x7, mostrar_ronda # si x10 es menor a x7 (10) salta a mostrar_ronda
    sub x10, x10, x7 # Restamos 10 unidades
    addi x9, x9, 1 # sumamos 1 a las decenas (x9)
    j bcd_ronda

mostrar_ronda:

    # Se multiplica las decenas (x9) por 16 (usando sumas, ya que los shifts están deshabilitados)
    add x9, x9, x9 # x2
    add x9, x9, x9 # x4
    add x9, x9, x9 # x8
    add x9, x9, x9 # x16

    add x10, x10, x9 # Se combina decenas desplazadas (x9) y unidades (x10)
    sw x10, 0(x3) # Se envian las decimas en formato BCD (decimal) al Display

    # Contador de rondas correctas
    addi x1, x1, 1              # Sumamos uno al contador de rondas
    addi x7, x0, 10
    bne  x1, x7, start_round    # Si todavía no van 10 rondas, se juega la siguiente

game_over:

    # Se prepara la división por 10 (total acumulado en x8 / 10)
    addi x7, x0, 10 # el divisor será 10
    addi x10, x0, 0 # x10 será el contador del promedio

resta_promedio:
    # Si el tiempo total (x8) es menor a 10, se termina la división
    bltu x8, x7, fin_promedio
    sub x8, x8, x7 # Restamos 10 al total
    addi x10, x10, 1 # Sumamos uno al promedio final
    j resta_promedio

fin_promedio:
    # Se convierte el promedio (x10) a BCD usando x9
    addi x7, x0, 10
    addi x9, x0, 0

bcd_promedio:

    bltu x10, x7, mostrar_promedio # Si el promedio (x10) es menor a x7 saltará a mostrar_promedio
    sub x10, x10, x7
    addi x9, x9, 1
    j bcd_promedio

mostrar_promedio:

    # Se desplaza las decenas por 16
    add x9, x9, x9
    add x9, x9, x9
    add x9, x9, x9
    add x9, x9, x9
    add x10, x10, x9

    sw x10, 0(x3) # mostramos el promedio en el Display en BCD

esperar_soltar_final:

    lw x14, 0(x5) # Se usa x14 para leer el hardware
    bne x14, x0, esperar_soltar_final # Esperamos a que suelte el boton de la última ronda

    # Vuelve al inicio: los LEDs 1001 indican "listo" y el promedio queda en
    # el display hasta que se presione un botón para jugar de nuevo
    # (wait_start toma además una semilla nueva).
    j _start

wrong:
    # Botón incorrecto: se muestra "EE" en el display y se apagan los LEDs.
    # La ronda se reinicia (no cuenta como ronda ganada) y "EE" queda visible
    # durante la espera de 3 s de la ronda repetida.
    addi x7, x0, 0xEE
    sw   x7, 0(x3)
    sw   x0, 0(x4)
    j start_round # Devuelve a start_round, que espera que se suelte el botón