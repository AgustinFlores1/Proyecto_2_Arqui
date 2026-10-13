"""
Test de ida y vuelta (round-trip) del assembler sobre sw/game.s.

No existe un game.hex "oficial" con qué comparar, así que este test verifica
de otra forma: toma cada palabra que generó el assembler y la DECODIFICA con
las mismas fórmulas que usa el procesador (espino_decoder.v, líneas 88-100, y
espino_id_stage.v, líneas 56-58). Si lo decodificado coincide con lo que dice
game.s, el hardware va a ejecutar exactamente lo que escribimos.

El decodificador de aquí abajo es independiente de los encode_* del assembler:
si un encoder tiene un bug, este test lo detecta.

Uso (desde la raíz del repo):
    python3 test_game.py
"""

from assembler import first_pass, second_pass, read_source, expand_pseudo, INSTRUCTIONS

GAME = "sw/game.s"


# ---------------------------------------------------------------------------
# Decodificador: copia en Python de lo que hace el hardware
# ---------------------------------------------------------------------------

def bits(w, hi, lo):
    """instr[hi:lo] en Verilog."""
    return (w >> lo) & ((1 << (hi - lo + 1)) - 1)


def sext(value, n_bits):
    """Extensión de signo: lo que hace {{20{instr[31]}}, ...} en el decoder."""
    if value & (1 << (n_bits - 1)):
        return value - (1 << n_bits)
    return value


def decode(w):
    """Devuelve un dict con los campos de la instrucción, tal como los ve el core."""
    d = {
        "opcode": bits(w, 6, 0),       # decoder.v línea 88
        "funct3": bits(w, 14, 12),     # línea 89
        "funct7": bits(w, 31, 25),     # línea 90
        "rd":     bits(w, 11, 7),      # id_stage.v línea 58
        "rs1":    bits(w, 19, 15),     # línea 56
        "rs2":    bits(w, 24, 20),     # línea 57
    }
    # Inmediatos: decoder.v líneas 94-100
    d["imm_i"] = sext(bits(w, 31, 20), 12)
    d["imm_s"] = sext((bits(w, 31, 25) << 5) | bits(w, 11, 7), 12)
    d["imm_b"] = sext((bits(w, 31, 31) << 12) | (bits(w, 7, 7) << 11)
                      | (bits(w, 30, 25) << 5) | (bits(w, 11, 8) << 1), 13)
    d["imm_u"] = bits(w, 31, 12)
    d["imm_j"] = sext((bits(w, 31, 31) << 20) | (bits(w, 19, 12) << 12)
                      | (bits(w, 20, 20) << 11) | (bits(w, 30, 21) << 1), 21)
    return d


# ---------------------------------------------------------------------------
# Helpers para leer los operandos del .s (independientes del assembler)
# ---------------------------------------------------------------------------

def reg(tok):
    return int(tok.strip()[1:])


def mem(tok):
    off, r = tok.strip().rstrip(")").split("(")
    return int(off, 0), reg(r)


# ---------------------------------------------------------------------------
# El test
# ---------------------------------------------------------------------------

labels, instrs = first_pass(read_source(GAME))
words = second_pass(instrs, labels)

errores = []

def check(cond, line_no, pc, texto, msg):
    if not cond:
        errores.append(f"  línea {line_no:3d} (PC {pc:#05x})  {texto:<28}  → {msg}")


# 1) Una palabra por instrucción, y todas caben en 32 bits
assert len(words) == len(instrs), f"{len(words)} palabras para {len(instrs)} instrucciones"
for w in words:
    assert 0 <= w < 2**32, f"palabra fuera de 32 bits: {w:#x}"

# 2) Cada palabra, decodificada, dice lo mismo que el .s
for (line_no, pc, mnem_src, ops_src), w in zip(instrs, words):
    texto = f"{mnem_src} {', '.join(ops_src)}"
    mnem, ops = expand_pseudo(mnem_src, ops_src, line_no)
    tipo, opcode, f3, f7 = INSTRUCTIONS[mnem]
    d = decode(w)

    # opcode / funct3 / funct7 → ¿el hardware reconoce la instrucción correcta?
    check(d["opcode"] == opcode, line_no, pc, texto, f"opcode {d['opcode']:07b}, esperado {opcode:07b}")
    if f3 is not None:
        check(d["funct3"] == f3, line_no, pc, texto, f"funct3 {d['funct3']:03b}, esperado {f3:03b}")
    if f7 is not None:
        check(d["funct7"] == f7, line_no, pc, texto, f"funct7 {d['funct7']:07b}, esperado {f7:07b}")

    # Operandos según el tipo
    if tipo == "R":
        check(d["rd"] == reg(ops[0]),  line_no, pc, texto, f"rd = x{d['rd']}")
        check(d["rs1"] == reg(ops[1]), line_no, pc, texto, f"rs1 = x{d['rs1']}")
        check(d["rs2"] == reg(ops[2]), line_no, pc, texto, f"rs2 = x{d['rs2']}")

    elif tipo == "I":
        check(d["rd"] == reg(ops[0]),  line_no, pc, texto, f"rd = x{d['rd']}")
        check(d["rs1"] == reg(ops[1]), line_no, pc, texto, f"rs1 = x{d['rs1']}")
        check(d["imm_i"] == int(ops[2], 0), line_no, pc, texto, f"imm = {d['imm_i']}")

    elif tipo == "IL":
        off, base = mem(ops[1])
        check(d["rd"] == reg(ops[0]), line_no, pc, texto, f"rd = x{d['rd']}")
        check(d["rs1"] == base,       line_no, pc, texto, f"rs1 = x{d['rs1']}")
        check(d["imm_i"] == off,      line_no, pc, texto, f"offset = {d['imm_i']}")

    elif tipo == "S":
        off, base = mem(ops[1])
        check(d["rs2"] == reg(ops[0]), line_no, pc, texto, f"rs2 = x{d['rs2']}")
        check(d["rs1"] == base,        line_no, pc, texto, f"rs1 = x{d['rs1']}")
        check(d["imm_s"] == off,       line_no, pc, texto, f"offset = {d['imm_s']}")

    elif tipo == "B":
        destino = pc + d["imm_b"]   # a dónde salta REALMENTE el core
        check(d["rs1"] == reg(ops[0]), line_no, pc, texto, f"rs1 = x{d['rs1']}")
        check(d["rs2"] == reg(ops[1]), line_no, pc, texto, f"rs2 = x{d['rs2']}")
        check(destino == labels[ops[2]], line_no, pc, texto,
              f"salta a {destino:#x}, '{ops[2]}' está en {labels[ops[2]]:#x}")

    elif tipo == "U":
        check(d["rd"] == reg(ops[0]), line_no, pc, texto, f"rd = x{d['rd']}")
        check(d["imm_u"] == int(ops[1], 0), line_no, pc, texto, f"imm = {d['imm_u']:#x}")

    elif tipo == "J":
        destino = pc + d["imm_j"]
        check(d["rd"] == reg(ops[0]), line_no, pc, texto, f"rd = x{d['rd']}")
        check(destino == labels[ops[1]], line_no, pc, texto,
              f"salta a {destino:#x}, '{ops[1]}' está en {labels[ops[1]]:#x}")

# 3) Ningún registro fuera de RV32E (el core ignora el bit 4 y x16 se volvería x0)
for (line_no, pc, mnem, ops), w in zip(instrs, words):
    d = decode(w)
    for campo in ("rd", "rs1", "rs2"):
        tipo = INSTRUCTIONS[expand_pseudo(mnem, ops, line_no)[0]][0]
        usa = {"R": ("rd", "rs1", "rs2"), "I": ("rd", "rs1"), "IL": ("rd", "rs1"),
               "S": ("rs1", "rs2"), "B": ("rs1", "rs2"), "U": ("rd",), "J": ("rd",)}[tipo]
        if campo in usa:
            check(d[campo] <= 15, line_no, pc, mnem, f"{campo} = x{d[campo]} no existe en RV32E")


# ---------------------------------------------------------------------------
# Resultado
# ---------------------------------------------------------------------------

if errores:
    print(f"game.s: {len(errores)} error(es) al decodificar:")
    print("\n".join(errores))
    raise SystemExit(1)

n_saltos = sum(1 for _, _, m, _ in instrs if m in {"beq", "bne", "blt", "bge", "bltu", "bgeu", "jal", "j"})
print(f"game.s OK: {len(words)} instrucciones decodificadas correctamente "
      f"({n_saltos} saltos llegan a su etiqueta)")
