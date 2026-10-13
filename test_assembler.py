from assembler import *

# ---------------------------------------------------------------------------
# first_pass sobre game.s
# ---------------------------------------------------------------------------
labels, instrs = first_pass(read_source("sw/game.s"))

# 1) Chequeos fijos: dependen de la versión actual de game.s.
#    Si el juego cambia, actualizar estos números (y revisar que tengan sentido).
assert len(instrs) == 97
assert labels["start_round"] == 0x30
assert labels["wait_3s"] == 0x4c
assert labels["show_target"] == 0x94
assert labels["correct"] == 0xb4
assert labels["game_over"] == 0x120
assert labels["wrong"] == 0x174

# 2) Chequeos generales: valen para cualquier versión de game.s.
pcs = [pc for _, pc, _, _ in instrs]
assert pcs == list(range(0, 4 * len(instrs), 4)), "los PC deben ser 0, 4, 8, ... sin saltos"
assert all(pc % 4 == 0 for pc in labels.values()), "toda etiqueta debe estar alineada a 4"
assert all(pc <= 4 * len(instrs) for pc in labels.values()), "ninguna etiqueta fuera del programa"

# Toda etiqueta usada por un salto debe existir (si no, la pasada 2 fallará).
SALTOS = {"beq", "bne", "blt", "bge", "bltu", "bgeu", "jal", "j"}
for line_no, pc, mnem, ops in instrs:
    print(f"|| {line_no} || {pc} || {mnem} || {ops} ||")
    if mnem in SALTOS:
        destino = ops[-1]                  # la etiqueta siempre es el último operando
        assert destino in labels, f"línea {line_no}: etiqueta '{destino}' no definida"

print("ETIQUETAS")
for i, label in enumerate(labels):
    print(f"{i + 1} - {label} ||")

print("game.s OK:", len(instrs), "instrucciones,", len(labels), "etiquetas")

# R
assert encode_r(0b0110011, 0b000, 0b0000000, rd=9, rs1=12, rs2=13) == 0x00d604b3   # add x9, x12, x13   (lámina 20)
assert encode_r(0b0110011, 0b000, 0b0100000, rd=10, rs1=10, rs2=7) == 0x40750533   # sub x10, x10, x7   (game.s) ← prueba funct7
assert encode_r(0b0110011, 0b100, 0b0000000, rd=11, rs1=11, rs2=15) == 0x00f5c5b3  # xor x11, x11, x15  (game.s) ← prueba funct3
assert encode_r(0b0110011, 0b000, 0b0000000, rd=8, rs1=8, rs2=10)  == 0x00a40433   # add x8, x8, x10    (game.s)
assert encode_r(0b0110011, 0b000, 0b0000000, rd=15, rs1=15, rs2=15) == 0x00f787b3  # registro máximo de RV32E en los 3 campos
assert encode_r(0b0110011, 0b000, 0b0000000, rd=0, rs1=0, rs2=0)   == 0x00000033   # todo en cero: solo queda el opcode

# I
assert encode_i(0b0010011, 0b000, rd=2, rs1=2, imm=4)     == 0x00410113   # addi x2, x2, 4     (blink.hex, línea 2)
assert encode_i(0b0010011, 0b000, rd=3, rs1=3, imm=-1)    == 0xfff18193   # addi x3, x3, -1    (blink.hex, línea 6)
assert encode_i(0b0010011, 0b100, rd=1, rs1=1, imm=15)    == 0x00f0c093   # xori x1, x1, 15    (blink.hex, línea 8)
assert encode_i(0b0010011, 0b111, rd=4, rs1=1, imm=15)    == 0x00f0f213   # andi x4, x1, 15    (7seg.hex, línea 8)
assert encode_i(0b0010011, 0b000, rd=9, rs1=9, imm=-1856) == 0x8c048493   # addi x9, x9, -1856 (game.s, los 3 segundos)
assert encode_i(0b0010011, 0b000, rd=1, rs1=0, imm=2047)  == 0x7ff00093   # máximo positivo de 12 bits
assert encode_i(0b0010011, 0b000, rd=1, rs1=0, imm=-2048) == 0x80000093   # mínimo negativo de 12 bits
assert encode_i(0b0000011, 0b010, rd=1, rs1=2, imm=0)     == 0x00012083   # lw x1, 0(x2)       (buttons_leds.hex, línea 5) ← load usa formato 

# S
assert encode_s(0b0100011, 0b010, rs1=2, rs2=1, imm=0)     == 0x00112023   # sw x1, 0(x2)    (blink.hex, línea 4)
assert encode_s(0b0100011, 0b010, rs1=3, rs2=1, imm=0)     == 0x0011a023   # sw x1, 0(x3)    (buttons_leds.hex, línea 6)
assert encode_s(0b0100011, 0b010, rs1=4, rs2=7, imm=0)     == 0x00722023   # sw x7, 0(x4)    (game.s, LEDs)
assert encode_s(0b0100011, 0b010, rs1=3, rs2=10, imm=0)    == 0x00a1a023   # sw x10, 0(x3)   (game.s, display)
assert encode_s(0b0100011, 0b010, rs1=2, rs2=5, imm=-4)    == 0xfe512e23   # sw x5, -4(x2)
assert encode_s(0b0100011, 0b010, rs1=2, rs2=5, imm=36)    == 0x02512223   # sw x5, 36(x2)   ← usa ambos pedazos
assert encode_s(0b0100011, 0b010, rs1=2, rs2=5, imm=2047)  == 0x7e512fa3   # máximo de 12 bits
assert encode_s(0b0100011, 0b010, rs1=2, rs2=5, imm=-2048) == 0x80512023   # mínimo de 12 bits
assert encode_s(0b0100011, 0b000, rs1=2, rs2=5, imm=3)     == 0x005101a3   # sb x5, 3(x2)    ← otro funct3

# U
assert encode_u(0b0110111, rd=2, imm=0x80000) == 0x80000137   # lui x2, 0x80000   (blink.hex, línea 1)
assert encode_u(0b0110111, rd=3, imm=0x200)   == 0x002001b7   # lui x3, 0x200     (blink.hex, línea 5)
assert encode_u(0b0110111, rd=3, imm=0x80000) == 0x800001b7   # lui x3, 0x80000   (buttons_leds.hex, línea 3)
assert encode_u(0b0110111, rd=9, imm=0x4787)  == 0x047874b7   # lui x9, 0x4787    (game.s, 75.000.000)
assert encode_u(0b0110111, rd=9, imm=0x262)   == 0x002624b7   # lui x9, 0x262     (game.s, 2.500.000)
assert encode_u(0b0110111, rd=1, imm=0xFFFFF) == 0xfffff0b7   # máximo de 20 bits
assert encode_u(0b0110111, rd=5, imm=0)       == 0x000002b7   # inmediato cero

# B
assert encode_b(0b1100011, 0b001, rs1=3, rs2=0, offset=-4)     == 0xfe019ee3  # bne x3, x0, delay   (blink.hex, línea 7)
assert encode_b(0b1100011, 0b001, rs1=4, rs2=5, offset=8)      == 0x00521463  # bne x4, x5, skip    (7seg.hex, línea 10)
assert encode_b(0b1100011, 0b001, rs1=1, rs2=5, offset=-40)    == 0xfc509ce3  # bne x1, x5, loop    (7seg.hex, línea 13)
assert encode_b(0b1100011, 0b110, rs1=10, rs2=9, offset=-8)    == 0xfe956ce3  # bltu x10, x9, wait_3s     (game.s)
assert encode_b(0b1100011, 0b000, rs1=14, rs2=0, offset=-4)    == 0xfe070ee3  # beq x14, x0, wait_button (game.s)
assert encode_b(0b1100011, 0b000, rs1=14, rs2=12, offset=8)    == 0x00c70463  # beq, adelante, chico
assert encode_b(0b1100011, 0b000, rs1=14, rs2=12, offset=-8)   == 0xfec70ce3  # beq, atrás
assert encode_b(0b1100011, 0b000, rs1=14, rs2=12, offset=2048) == 0x00c700e3  # solo offset[11] → instr[7]
assert encode_b(0b1100011, 0b000, rs1=14, rs2=12, offset=4094) == 0x7ec70fe3  # máximo (+4094, par)
assert encode_b(0b1100011, 0b000, rs1=14, rs2=12, offset=-4096) == 0x80c70063 # mínimo (-4096)

# J
assert encode_j(0b1101111, rd=0, offset=-20)      == 0xfedff06f   # jal x0, loop   (blink.hex, línea 9)
assert encode_j(0b1101111, rd=0, offset=-48)      == 0xfd1ff06f   # jal x0, loop   (7seg.hex, línea 15)
assert encode_j(0b1101111, rd=0, offset=-8)       == 0xff9ff06f   # jal x0, loop   (buttons_leds.hex, línea 7)
assert encode_j(0b1101111, rd=0, offset=0x18)     == 0x0180006f   # jal x0, show_target  (game.s, desde PC 0x68)
assert encode_j(0b1101111, rd=0, offset=8)        == 0x0080006f
assert encode_j(0b1101111, rd=1, offset=256)      == 0x100000ef   # jal x1, ... ← rd ≠ 0 (llamada a subrutina)
assert encode_j(0b1101111, rd=0, offset=4096)     == 0x0000106f   # solo offset[12]
assert encode_j(0b1101111, rd=0, offset=-128)     == 0xf81ff06f
assert encode_j(0b1101111, rd=0, offset=1048574)  == 0x7ffff06f   # máximo (+1 MiB − 2)
assert encode_j(0b1101111, rd=0, offset=-1048576) == 0x8000006f   # mínimo (−1 MiB)

for nombre in ["blink", "7seg", "buttons_leds"]:
    labels, instrs = first_pass(read_source(f"sw/{nombre}.s"))
    words = second_pass(instrs, labels)
    esperado = [int(l, 16) for l in open(f"sw/{nombre}.hex") if l.strip()]
    for i, (w, e) in enumerate(zip(words, esperado)):
        if w != e:
            print(f"{nombre} instrucción {i} (PC {4*i:#x}): obtuve {w:08x}, esperaba {e:08x}")
    assert words == esperado, nombre
print("Los 3 programas coinciden con GNU as ✓")