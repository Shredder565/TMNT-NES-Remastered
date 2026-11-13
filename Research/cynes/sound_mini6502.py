"""A very small 6502 interpreter, just enough to run the game's own sound
program out of the player's ROM in isolation and write down every value it
sends to the sound chip ($4000-$4017), frame by frame.  Nothing of the ROM is
kept here: the ROM file is read at run time.  Official opcodes only.

Memory: $0000-$07FF RAM, $8000-$BFFF = PRG bank 0 (the sound bank),
$C000-$FFFF = PRG bank 7 (fixed).  Writes to $4000-$4017 are logged."""
import sys

class Cpu:
    def __init__(self, rom_path):
        rom = open(rom_path, 'rb').read()
        prg = rom[16:16 + 0x20000]
        self.mem = bytearray(0x10000)
        self.mem[0x8000:0xC000] = prg[0:0x4000]
        self.mem[0xC000:0x10000] = prg[7 * 0x4000:8 * 0x4000]
        self.a = self.x = self.y = 0
        self.sp = 0xFF
        self.c = self.z = self.n = self.v = 0
        self.pc = 0
        self.writes = []          # (register, value) since last cleared

    def rd(self, a):
        return self.mem[a]

    def wr(self, a, v):
        if a < 0x800:
            self.mem[a] = v
        elif 0x4000 <= a <= 0x4017:
            self.writes.append((a, v))
        # anything else (mapper registers) is ignored

    def push(self, v):
        self.mem[0x100 + self.sp] = v; self.sp = (self.sp - 1) & 0xFF

    def pop(self):
        self.sp = (self.sp + 1) & 0xFF; return self.mem[0x100 + self.sp]

    def nz(self, v):
        self.z = 1 if v == 0 else 0; self.n = v >> 7; return v

    def call(self, addr, a=0, x=0, y=0, limit=2000000):
        """Run the subroutine at addr until it returns."""
        self.a, self.x, self.y = a, x, y
        self.sp = 0xFD
        self.push(0xFF); self.push(0xFE)      # return address $FFFF -> stops us
        self.pc = addr
        n = 0
        while self.pc != 0x0000 or True:
            if self.sp == 0xFF and self.pc == 0x0000:
                break
            self.step()
            n += 1
            if n > limit:
                raise RuntimeError('runaway at %04X' % self.pc)
            if self.done:
                break

    done = False

    def step(self):
        m = self.mem; pc = self.pc; op = m[pc]
        self.done = False
        mode = MODE.get(op)
        if mode is None:
            raise RuntimeError('bad opcode %02X at %04X' % (op, pc))
        name, am = mode
        ea = None; val = None
        if am == 'imp' or am == 'acc':
            pc += 1
        elif am == 'imm':
            ea = pc + 1; pc += 2
        elif am == 'zp':
            ea = m[pc + 1]; pc += 2
        elif am == 'zpx':
            ea = (m[pc + 1] + self.x) & 0xFF; pc += 2
        elif am == 'zpy':
            ea = (m[pc + 1] + self.y) & 0xFF; pc += 2
        elif am == 'abs':
            ea = m[pc + 1] | m[pc + 2] << 8; pc += 3
        elif am == 'abx':
            ea = ((m[pc + 1] | m[pc + 2] << 8) + self.x) & 0xFFFF; pc += 3
        elif am == 'aby':
            ea = ((m[pc + 1] | m[pc + 2] << 8) + self.y) & 0xFFFF; pc += 3
        elif am == 'izx':
            z = (m[pc + 1] + self.x) & 0xFF; ea = m[z] | m[(z + 1) & 0xFF] << 8; pc += 2
        elif am == 'izy':
            z = m[pc + 1]; ea = ((m[z] | m[(z + 1) & 0xFF] << 8) + self.y) & 0xFFFF; pc += 2
        elif am == 'rel':
            o = m[pc + 1]; pc += 2; ea = (pc + (o - 256 if o > 127 else o)) & 0xFFFF
        elif am == 'ind':
            p = m[pc + 1] | m[pc + 2] << 8; ea = m[p] | m[(p & 0xFF00) | ((p + 1) & 0xFF)] << 8; pc += 3
        self.pc = pc
        getattr(self, 'op_' + name)(ea, am)

    # loads / stores
    def op_LDA(s, ea, am): s.a = s.nz(s.rd(ea))
    def op_LDX(s, ea, am): s.x = s.nz(s.rd(ea))
    def op_LDY(s, ea, am): s.y = s.nz(s.rd(ea))
    def op_STA(s, ea, am): s.wr(ea, s.a)
    def op_STX(s, ea, am): s.wr(ea, s.x)
    def op_STY(s, ea, am): s.wr(ea, s.y)
    def op_TAX(s, ea, am): s.x = s.nz(s.a)
    def op_TAY(s, ea, am): s.y = s.nz(s.a)
    def op_TXA(s, ea, am): s.a = s.nz(s.x)
    def op_TYA(s, ea, am): s.a = s.nz(s.y)
    def op_TSX(s, ea, am): s.x = s.nz(s.sp)
    def op_TXS(s, ea, am): s.sp = s.x
    def op_PHA(s, ea, am): s.push(s.a)
    def op_PLA(s, ea, am): s.a = s.nz(s.pop())
    def op_PHP(s, ea, am): s.push(s.n << 7 | s.v << 6 | 0x30 | s.z << 1 | s.c)
    def op_PLP(s, ea, am):
        p = s.pop(); s.n = p >> 7; s.v = (p >> 6) & 1; s.z = (p >> 1) & 1; s.c = p & 1
    # logic / arithmetic
    def op_AND(s, ea, am): s.a = s.nz(s.a & s.rd(ea))
    def op_ORA(s, ea, am): s.a = s.nz(s.a | s.rd(ea))
    def op_EOR(s, ea, am): s.a = s.nz(s.a ^ s.rd(ea))
    def op_BIT(s, ea, am):
        v = s.rd(ea); s.z = 1 if (s.a & v) == 0 else 0; s.n = v >> 7; s.v = (v >> 6) & 1
    def op_ADC(s, ea, am):
        v = s.rd(ea); r = s.a + v + s.c
        s.v = 1 if (~(s.a ^ v) & (s.a ^ r) & 0x80) else 0
        s.c = 1 if r > 0xFF else 0; s.a = s.nz(r & 0xFF)
    def op_SBC(s, ea, am):
        v = s.rd(ea) ^ 0xFF; r = s.a + v + s.c
        s.v = 1 if (~(s.a ^ v) & (s.a ^ r) & 0x80) else 0
        s.c = 1 if r > 0xFF else 0; s.a = s.nz(r & 0xFF)
    def _cmp(s, reg, ea):
        v = s.rd(ea); s.c = 1 if reg >= v else 0; s.nz((reg - v) & 0xFF)
    def op_CMP(s, ea, am): s._cmp(s.a, ea)
    def op_CPX(s, ea, am): s._cmp(s.x, ea)
    def op_CPY(s, ea, am): s._cmp(s.y, ea)
    def op_INC(s, ea, am): s.wr(ea, s.nz((s.rd(ea) + 1) & 0xFF))
    def op_DEC(s, ea, am): s.wr(ea, s.nz((s.rd(ea) - 1) & 0xFF))
    def op_INX(s, ea, am): s.x = s.nz((s.x + 1) & 0xFF)
    def op_INY(s, ea, am): s.y = s.nz((s.y + 1) & 0xFF)
    def op_DEX(s, ea, am): s.x = s.nz((s.x - 1) & 0xFF)
    def op_DEY(s, ea, am): s.y = s.nz((s.y - 1) & 0xFF)
    def _shift(s, ea, am, f):
        if am == 'acc': s.a = s.nz(f(s.a))
        else: s.wr(ea, s.nz(f(s.rd(ea))))
    def op_ASL(s, ea, am):
        def f(v): s.c = v >> 7; return (v << 1) & 0xFF
        s._shift(ea, am, f)
    def op_LSR(s, ea, am):
        def f(v): s.c = v & 1; return v >> 1
        s._shift(ea, am, f)
    def op_ROL(s, ea, am):
        def f(v): c = s.c; s.c = v >> 7; return ((v << 1) | c) & 0xFF
        s._shift(ea, am, f)
    def op_ROR(s, ea, am):
        def f(v): c = s.c; s.c = v & 1; return (v >> 1) | (c << 7)
        s._shift(ea, am, f)
    # flow
    def op_JMP(s, ea, am): s.pc = ea
    def op_JSR(s, ea, am):
        r = (s.pc - 1) & 0xFFFF; s.push(r >> 8); s.push(r & 0xFF); s.pc = ea
    def op_RTS(s, ea, am):
        lo = s.pop(); hi = s.pop(); s.pc = ((hi << 8 | lo) + 1) & 0xFFFF
        if s.pc == 0xFFFF: s.done = True
    def op_BCC(s, ea, am):
        if not s.c: s.pc = ea
    def op_BCS(s, ea, am):
        if s.c: s.pc = ea
    def op_BEQ(s, ea, am):
        if s.z: s.pc = ea
    def op_BNE(s, ea, am):
        if not s.z: s.pc = ea
    def op_BMI(s, ea, am):
        if s.n: s.pc = ea
    def op_BPL(s, ea, am):
        if not s.n: s.pc = ea
    def op_BVC(s, ea, am):
        if not s.v: s.pc = ea
    def op_BVS(s, ea, am):
        if s.v: s.pc = ea
    def op_CLC(s, ea, am): s.c = 0
    def op_SEC(s, ea, am): s.c = 1
    def op_CLV(s, ea, am): s.v = 0
    def op_CLD(s, ea, am): pass
    def op_SED(s, ea, am): pass
    def op_CLI(s, ea, am): pass
    def op_SEI(s, ea, am): pass
    def op_NOP(s, ea, am): pass

_T = """01 ORA izx|05 ORA zp|06 ASL zp|08 PHP imp|09 ORA imm|0A ASL acc|0D ORA abs|0E ASL abs|10 BPL rel|11 ORA izy|15 ORA zpx|16 ASL zpx|18 CLC imp|19 ORA aby|1D ORA abx|1E ASL abx|20 JSR abs|21 AND izx|24 BIT zp|25 AND zp|26 ROL zp|28 PLP imp|29 AND imm|2A ROL acc|2C BIT abs|2D AND abs|2E ROL abs|30 BMI rel|31 AND izy|35 AND zpx|36 ROL zpx|38 SEC imp|39 AND aby|3D AND abx|3E ROL abx|41 EOR izx|45 EOR zp|46 LSR zp|48 PHA imp|49 EOR imm|4A LSR acc|4C JMP abs|4D EOR abs|4E LSR abs|50 BVC rel|51 EOR izy|55 EOR zpx|56 LSR zpx|58 CLI imp|59 EOR aby|5D EOR abx|5E LSR abx|60 RTS imp|61 ADC izx|65 ADC zp|66 ROR zp|68 PLA imp|69 ADC imm|6A ROR acc|6C JMP ind|6D ADC abs|6E ROR abs|70 BVS rel|71 ADC izy|75 ADC zpx|76 ROR zpx|78 SEI imp|79 ADC aby|7D ADC abx|7E ROR abx|81 STA izx|84 STY zp|85 STA zp|86 STX zp|88 DEY imp|8A TXA imp|8C STY abs|8D STA abs|8E STX abs|90 BCC rel|91 STA izy|94 STY zpx|95 STA zpx|96 STX zpy|98 TYA imp|99 STA aby|9A TXS imp|9D STA abx|A0 LDY imm|A1 LDA izx|A2 LDX imm|A4 LDY zp|A5 LDA zp|A6 LDX zp|A8 TAY imp|A9 LDA imm|AA TAX imp|AC LDY abs|AD LDA abs|AE LDX abs|B0 BCS rel|B1 LDA izy|B4 LDY zpx|B5 LDA zpx|B6 LDX zpy|B8 CLV imp|B9 LDA aby|BA TSX imp|BC LDY abx|BD LDA abx|BE LDX aby|C0 CPY imm|C1 CMP izx|C4 CPY zp|C5 CMP zp|C6 DEC zp|C8 INY imp|C9 CMP imm|CA DEX imp|CC CPY abs|CD CMP abs|CE DEC abs|D0 BNE rel|D1 CMP izy|D5 CMP zpx|D6 DEC zpx|D8 CLD imp|D9 CMP aby|DD CMP abx|DE DEC abx|E0 CPX imm|E1 SBC izx|E4 CPX zp|E5 SBC zp|E6 INC zp|E8 INX imp|E9 SBC imm|EA NOP imp|EC CPX abs|ED SBC abs|EE INC abs|F0 BEQ rel|F1 SBC izy|F5 SBC zpx|F6 INC zpx|F8 SED imp|F9 SBC aby|FD SBC abx|FE INC abx"""
MODE = {}
for _e in _T.split('|'):
    _c, _m, _a = _e.split(); MODE[int(_c, 16)] = (_m, _a)

PLAY = 0x9057      # start sound number A
FRAME = 0x8644     # once a frame
STOP = 0x9016      # silence everything

class SoundRun:
    """The original's sound program, driven directly."""
    def __init__(self, rom='/home/claude/rom/tmnt.nes'):
        self.cpu = Cpu(rom)
    def play(self, n):
        self.cpu.call(PLAY, a=n)
    def stop(self):
        self.cpu.call(STOP)
    def frame(self):
        self.cpu.call(FRAME)
    def take_writes(self):
        w = self.cpu.writes; self.cpu.writes = []; return w
    def ram(self, a):
        return self.cpu.mem[a]
