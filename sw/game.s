.section .text
.global _start

_start:
    # MMIO addresses
    lui  x2, 0x80000    # Carga en los 20 bits superiores. x2 será la dirección base de periféricos
    addi x3, x2, 0      # Display
    addi x4, x2, 4      # LEDs
    addi x5, x2, 8      # Buttons
    addi x6, x2, 12     # Cycle counter

    # Prender LEDs
    addi x7, x0, 15
    sw   x7, 0(x4)

    # Guardar cycle count inicial
    lw   x8, 0(x6)

    # Cargar los 75mm de ciclos (3 segundos en 25 MHz)
    lui  x9, 0x4787
    addi x9, x9, -1856

wait_3s:
    #x10 = contador actual
    lw   x10, 0(x6)
    #x10 = contador actual - contador inicial
    sub  x10, x10, x8
    #Si los ciclos transcurridos son < 75.000.000, vuelve a wait_3s
    bltu x10, x9, wait_3s

    # Pseudo-random OJO esto mejorar para mas rondas!!!
    lw   x11, 0(x6)
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

    # Capturar tiempo de reaccion en cciclos
    lw   x15, 0(x6)
    sub  x15, x15, x13

    # Checkear el botón presionado, respecto al target 
    beq  x14, x12, correct
    jal  x0, wrong

correct:
    # Se apagan los leds indicando que se acabó la ronda
    sw   x0, 0(x4)

correct_loop:
    jal  x0, correct_loop

wrong:
    # Se prenden los leds indicando que hay un error
    addi x7, x0, 15
    sw   x7, 0(x4)

wrong_loop:
    jal  x0, wrong_loop