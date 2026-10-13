from assembler import *

# ---------------------------------------------------------------------------
# first_pass sobre game.s
# ---------------------------------------------------------------------------
labels, instrs = first_pass(read_source("sw/game.s"))

# 1) Chequeos fijos: dependen de la versión actual de game.s.
#    Si el juego cambia, actualizar estos números (y revisar que tengan sentido).
assert len(instrs) == 66
assert labels["_start"] == 0x00
assert labels["start_round"] == 0x1c
assert labels["wait_release"] == labels["start_round"]   # dos etiquetas seguidas -> misma dirección
assert labels["wait_3s"] == 0x38
assert labels["show_target"] == 0x80
assert labels["correct"] == 0xa0
assert labels["game_over"] == 0xd4
assert labels["wrong"] == 0xfc

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
