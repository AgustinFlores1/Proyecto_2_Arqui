#!/usr/bin/env python3
"""
Assembler RV32E para Pochoco SoC / Espino Core.

Uso:
    python3 assembler.py sw/game.s -o sw/game.hex

Salida: una palabra de 32 bits en hexadecimal (8 dígitos, minúscula) por línea,
compatible con $readmemh en pochoco_ram.v.

Solo usa la librería estándar de Python (no se necesita pip install).
"""

import argparse   # leer argumentos de la línea de comandos (archivo de entrada, -o salida)
import re         # expresiones regulares: útil para separar "8(x6)" en offset y registro
import sys        # sys.exit() con código de error si el .s tiene errores


# ---------------------------------------------------------------------------
# Errores
# ---------------------------------------------------------------------------

class AsmError(Exception):
    """Error de ensamblado con número de línea, para mensajes claros."""
    def __init__(self, line_no, msg):
        super().__init__(f"línea {line_no}: {msg}")


# ---------------------------------------------------------------------------
# Tablas (las rellenas tú)
# ---------------------------------------------------------------------------

# mnemónico -> (formato, opcode, funct3, funct7)
# Ejemplo de una entrada:
#   "add": ("R", 0b0110011, 0b000, 0b0000000),
INSTRUCTIONS = {
    # mnem:    (tipo, opcode,     funct3, funct7)
    # --- R: rd, rs1, rs2 ---  (OPCODE_OP = 7'h33, decoder líneas 151-165)
    "add":   ("R",  0b0110011, 0b000, 0b0000000),
    "sub":   ("R",  0b0110011, 0b000, 0b0100000),
    "slt":   ("R",  0b0110011, 0b010, 0b0000000),
    "sltu":  ("R",  0b0110011, 0b011, 0b0000000),
    "xor":   ("R",  0b0110011, 0b100, 0b0000000),
    "or":    ("R",  0b0110011, 0b110, 0b0000000),
    "and":   ("R",  0b0110011, 0b111, 0b0000000),

    # --- I aritméticas: rd, rs1, imm ---  (OPCODE_OPIMM = 7'h13, líneas 133-148)
    "addi":  ("I",  0b0010011, 0b000, None),
    "slti":  ("I",  0b0010011, 0b010, None),
    "sltiu": ("I",  0b0010011, 0b011, None),
    "xori":  ("I",  0b0010011, 0b100, None),
    "ori":   ("I",  0b0010011, 0b110, None),
    "andi":  ("I",  0b0010011, 0b111, None),

    # --- I loads (y jalr): rd, imm(rs1) ---  (OPCODE_LOAD = 7'h03, líneas 168-184)
    "lb":    ("IL", 0b0000011, 0b000, None),
    "lh":    ("IL", 0b0000011, 0b001, None),
    "lw":    ("IL", 0b0000011, 0b010, None),
    "lbu":   ("IL", 0b0000011, 0b100, None),
    "lhu":   ("IL", 0b0000011, 0b101, None),
    "jalr":  ("IL", 0b1100111, 0b000, None),   # OPCODE_JALR = 7'h67, líneas 225-231

    # --- S: rs2, imm(rs1) ---  (OPCODE_STORE = 7'h23, líneas 187-199)
    "sb":    ("S",  0b0100011, 0b000, None),
    "sh":    ("S",  0b0100011, 0b001, None),
    "sw":    ("S",  0b0100011, 0b010, None),

    # --- B: rs1, rs2, etiqueta ---  (OPCODE_BRANCH = 7'h63, líneas 202-215)
    "beq":   ("B",  0b1100011, 0b000, None),
    "bne":   ("B",  0b1100011, 0b001, None),
    "blt":   ("B",  0b1100011, 0b100, None),
    "bge":   ("B",  0b1100011, 0b101, None),
    "bltu":  ("B",  0b1100011, 0b110, None),
    "bgeu":  ("B",  0b1100011, 0b111, None),

    # --- U: rd, imm ---  (OPCODE_LUI = 7'h37, OPCODE_AUIPC = 7'h17)
    "lui":   ("U",  0b0110111, None, None),
    "auipc": ("U",  0b0010111, None, None),

    # --- J: rd, etiqueta ---  (OPCODE_JAL = 7'h6f, líneas 218-223)
    "jal":   ("J",  0b1101111, None, None),

    # Shifts (sll, srl, sra, slli, srli, srai) NO se incluyen
}

# Directivas que se aceptan pero se ignoran
IGNORED_DIRECTIVES = {".section", ".text", ".global", ".globl"}


# ---------------------------------------------------------------------------
# Lectura del archivo
# ---------------------------------------------------------------------------

def read_source(path):
    """Devuelve una lista de (numero_de_linea, texto) con las líneas del .s.

    Guardamos el número de línea original para poder reportar errores
    ("línea 42: registro x16 no existe en RV32E").
    """
    with open(path, "r", encoding="utf-8") as f:
        return [(i, line) for i, line in enumerate(f, start=1)]


# ---------------------------------------------------------------------------
# Helpers (los implementas tú)
# ---------------------------------------------------------------------------

def clean_line(text: str) -> str:
    """Quita comentarios (#) y espacios. Devuelve '' si no queda nada."""
    return text.split('#')[0].strip()


def parse_register(tok: str, line_no: int) -> int:
    """'x5' -> 5. Error si no es x0..x15 (RV32E)."""
    tok = tok.strip()
    if not (tok.startswith("x") and tok[1:].isdigit()):
        raise AsmError(line_no, f"No se entrego un registro de forma 'x<numero>', Entregado: '{tok}'")
    num = int(tok[1:])
    if (num < 0 or num > 15):
        raise AsmError(line_no, f"Se intento acceder a un registro fuera de rango (0...15), Entregado: '{tok}'")
    return num


def parse_immediate(tok: str, line_no: int, symbols: dict) -> int:
    """'12', '-4', '0x80000' -> int. (Opcional: nombres definidos con .equ)."""
    # Pista: int(tok, 0) entiende decimal, 0x.. y 0b.. automáticamente.
    tok = tok.strip()
    if tok in symbols.keys():
        return symbols[tok]
    try:
        num = int(tok, 0)
    except ValueError:
        raise AsmError(line_no, f"Inmediato invalido, Entregado: '{tok}'")

    return num


def parse_mem_operand(tok: str, line_no: int, symbols: dict) -> tuple[int, int]:
    """'8(x6)' -> (8, 6). Pista: re.fullmatch(r"(.+)\\((.+)\\)", tok)"""
    tok = tok.strip()
    mtch = re.fullmatch(r"(.+)\((.+)\)", tok)

    if mtch is None:
        raise AsmError(line_no, f"Se esperaba una direccion valida <offset>(<register>), Entregado: '{tok}'")

    offset, register = mtch.groups()
    
    return (parse_immediate(offset, line_no, symbols), parse_register(register, line_no))


def check_range(value: int, n_bits: int, signed: bool, line_no: int) -> None:
    """Lanza AsmError si value no cabe en 'bits' bits."""
    if (signed):
        limit: int = 2**(n_bits - 1)
        if (value > limit - 1 or value < -limit):
            raise AsmError(line_no, f"Valor fuera del rango del numero de bits permitidos ({-limit}, {limit - 1}), Entregado: {value}")
    else:
        limit: int = 2**n_bits - 1
        if (value > limit or value < 0):
            raise AsmError(line_no, f"Valor fuera del rango del numero de bits permitidos (0, {limit}), Entregado: {value}")


# ---------------------------------------------------------------------------
# Pasada 1: etiquetas
# ---------------------------------------------------------------------------

def first_pass(lines):
    """Recorre el código y devuelve:
         labels:       {'loop': 0x0C, ...}
         instructions: [(line_no, pc, mnemonic, [operandos]), ...]
    """
    labels = {}
    instructions = []
    pc = 0

    for line_no, line in lines:
        cline = clean_line(line)
        if cline == "":
            continue
        if ":" in cline:
            items = cline.split(":", 1)
            label = items[0].strip()
            if (label == ""):
                raise AsmError(line_no, "Se entrego una etiqueta vacia")
            elif (label in labels.keys()):
                raise AsmError(line_no, f"Etiqueta '{label}' ya definida")
            
            labels[label] = pc
            cline = items[1].strip()
            if cline == "":
                continue

        if cline.startswith("."):
            directive = cline.split(None, 1)[0]
            if directive.strip() in IGNORED_DIRECTIVES:
                continue
            else:
                raise AsmError(line_no, f"Se utiliza directiva no reconocida por el assembler: '{directive}'") 

        parts = cline.split(None, 1)
        if len(parts) == 1:
            operators = []
        else:
            operators = [op.strip() for op in parts[1].split(",")]
        mnemonic = parts[0].strip().lower()
        instructions.append((
            line_no,
            pc,
            mnemonic,
            operators
        ))
        pc += 4
        
    return labels, instructions


# ---------------------------------------------------------------------------
# Pasada 2: codificación
# ---------------------------------------------------------------------------

def encode_r(opcode, f3, f7, rd, rs1, rs2):
    return (f7 << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | rd << 7 | opcode)

def encode_i(opcode, f3, rd, rs1, imm):
    return ((imm & 0xFFF) << 20 | rs1 << 15 | f3 << 12 | rd << 7 | opcode) 

def encode_s(opcode, f3, rs1, rs2, imm):
    return (((imm >> 5) & 0x7F) << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | (imm & 0x1F) << 7 | opcode)

def encode_b(opcode, f3, rs1, rs2, offset):
    return (((offset >> 12) & 0x1) << 31 | ((offset >> 5) & 0x3F) << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | ((offset >> 1) & 0xF) << 8 | ((offset >> 11) & 0x1) << 7 | opcode)

def encode_u(opcode, rd, imm):
    return ((imm & 0xFFFFF) << 12 | rd << 7 | opcode)

def encode_j(opcode, rd, offset):
    return (((offset >> 20) & 0x1) << 31 | ((offset >> 1)& 0x3FF) << 21 | ((offset >> 11) & 0x1) << 20 | ((offset >> 12) & 0xFF) << 12 | rd << 7 |opcode)

def expand_pseudo(mnem: str, ops: list, line_no: int) -> tuple[str, list]:
    """Traduce pseudo-instrucciones a instrucciones reales.
    Si mnem no es una pseudo-instrucción, la devuelve sin cambios.
    Todas las de aquí se expanden a UNA instrucción (4 bytes), así que
    first_pass no necesita saber de ellas para calcular los PC.
    """
    if mnem == "j":                      # j etiqueta      →  jal x0, etiqueta
        if len(ops) != 1:
            raise AsmError(line_no, f"'j' espera 1 operando (etiqueta), recibió {len(ops)}")
        return "jal", ["x0", ops[0]]

    if mnem == "nop":                    # nop             →  addi x0, x0, 0
        if len(ops) != 0:
            raise AsmError(line_no, f"'nop' no lleva operandos, recibió {len(ops)}")
        return "addi", ["x0", "x0", "0"]

    if mnem == "mv":                     # mv rd, rs       →  addi rd, rs, 0
        if len(ops) != 2:
            raise AsmError(line_no, f"'mv' espera 2 operandos, recibió {len(ops)}")
        return "addi", [ops[0], ops[1], "0"]

    return mnem, ops

def resolve_target(operand: str, pc: int, labels: dict, line_no: int) -> int:
    """Devuelve la dirección de una etiqueta. Lanza AsmError si no existe."""
    if operand not in labels:
        raise AsmError(line_no, f"Etiqueta '{operand}' no definida")
    return labels[operand] - pc

def second_pass(instructions, labels):
    """Devuelve una lista de enteros de 32 bits, uno por instrucción."""
    words = []

    for (line_no, pc, mnem, ops) in instructions:
        mnem, ops = expand_pseudo(mnem, ops, line_no)

        if mnem not in INSTRUCTIONS:
            raise AsmError(line_no, f"Instruccion desconocida: '{mnem}'")

        association, opcode, f3, f7 = INSTRUCTIONS[mnem]

        n_ops = len(ops)
        word: int
        match association:
            case "R":
                if n_ops != 3:
                    raise AsmError(line_no, f"{mnem} espera 3 operandos, recibio {n_ops}")
                rd = parse_register(ops[0], line_no)
                rs1 = parse_register(ops[1], line_no)
                rs2 = parse_register(ops[2], line_no)
                word = encode_r(opcode, f3, f7, rd, rs1, rs2)

            case "I":
                if n_ops != 3:
                    raise AsmError(line_no, f"{mnem} espera 3 operandos, recibio {n_ops}")
                rd = parse_register(ops[0], line_no)
                rs1 = parse_register(ops[1], line_no)
                imm = parse_immediate(ops[2], line_no, {})
                check_range(imm, 12, True, line_no)
                word = encode_i(opcode, f3, rd, rs1, imm)

            case "IL":
                if n_ops != 2:
                    raise AsmError(line_no, f"{mnem} espera 2 operandos, recibio {n_ops}")
                rd = parse_register(ops[0], line_no)
                imm, rs1 = parse_mem_operand(ops[1], line_no, {})
                check_range(imm, 12, True, line_no)
                word = encode_i(opcode, f3, rd, rs1, imm)

            case "S":
                if n_ops != 2:
                    raise AsmError(line_no, f"{mnem} espera 2 operandos, recibio {n_ops}")
                rs2 = parse_register(ops[0], line_no)
                imm, rs1 = parse_mem_operand(ops[1], line_no, {})
                check_range(imm, 12, True, line_no)
                word = encode_s(opcode, f3, rs1, rs2, imm)

            case "B":
                if n_ops != 3:
                    raise AsmError(line_no, f"{mnem} espera 3 operandos, recibio {n_ops}")
                rs1 = parse_register(ops[0], line_no)
                rs2 = parse_register(ops[1], line_no)
                offset = resolve_target(ops[2], pc, labels, line_no)
                check_range(offset, 13, True, line_no)
                word = encode_b(opcode, f3, rs1, rs2, offset)

            case "U":
                if n_ops != 2:
                    raise AsmError(line_no, f"{mnem} espera 2 operandos, recibio {n_ops}")
                rd = parse_register(ops[0], line_no)
                imm = parse_immediate(ops[1], line_no, {})
                check_range(imm, 20, False, line_no)
                word = encode_u(opcode, rd, imm)

            case "J":
                if n_ops != 2:
                    raise AsmError(line_no, f"{mnem} espera 2 operandos, recibio {n_ops}")
                rd = parse_register(ops[0], line_no)
                offset = resolve_target(ops[1], pc, labels, line_no)
                check_range(offset, 21, True, line_no)
                word = encode_j(opcode, rd, offset)
                
            case _:
                raise AsmError(line_no, f"Tipo de instrucción desconocido: '{association}'")

        words.append(word)
    return words


# ---------------------------------------------------------------------------
# Salida
# ---------------------------------------------------------------------------

def write_hex(words, path):
    with open(path, "w", encoding="utf-8") as f:
        for w in words:
            f.write(f"{w & 0xFFFFFFFF:08x}\n")   # 8 dígitos hex, minúscula


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Assembler RV32E para Pochoco SoC")
    ap.add_argument("input", help="archivo .s de entrada")
    ap.add_argument("-o", "--output", help="archivo .hex de salida (por defecto: mismo nombre .hex)")
    args = ap.parse_args()

    out_path = args.output or re.sub(r"\.s$", "", args.input) + ".hex"

    try:
        lines = read_source(args.input)
        labels, instructions = first_pass(lines)
        print("Etiquetas:", {k: hex(v) for k, v in labels.items()})   # debug, quítalo después
        words = second_pass(instructions, labels)
    except AsmError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    write_hex(words, out_path)
    print(f"{len(words)} instrucciones -> {out_path}")


if __name__ == "__main__":
    main()