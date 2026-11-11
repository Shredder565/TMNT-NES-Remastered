"""Turns the program part of the player's own ROM into a readable listing.

    python disassemble_rom.py "path/to/Teenage Mutant Ninja Turtles (USA).nes"

It writes one text file per program bank (bank0.txt to bank7.txt) into the
folder rom_listing/ at the top of the project. That folder is in
.gitignore: the listing is the game's own code, so like the ROM and the
ripped graphics it stays on your computer and is never committed.

The listing is how the notes in Research/ were worked out: read what the
original does, describe it in plain words in a note, then write our own
code from the note. Nothing is copied from the listing into the project.

It is a plain start-to-end listing, so tables of numbers in between the
code come out as nonsense instructions. Addresses are shown as the
console sees them: banks 0 to 6 at $8000, bank 7 at $C000.
"""
import os, sys

PRG=b''
OPS={}
T="""00 BRK imp|01 ORA izx|05 ORA zp|06 ASL zp|08 PHP imp|09 ORA imm|0A ASL acc|0D ORA abs|0E ASL abs|10 BPL rel|11 ORA izy|15 ORA zpx|16 ASL zpx|18 CLC imp|19 ORA aby|1D ORA abx|1E ASL abx|20 JSR abs|21 AND izx|24 BIT zp|25 AND zp|26 ROL zp|28 PLP imp|29 AND imm|2A ROL acc|2C BIT abs|2D AND abs|2E ROL abs|30 BMI rel|31 AND izy|35 AND zpx|36 ROL zpx|38 SEC imp|39 AND aby|3D AND abx|3E ROL abx|40 RTI imp|41 EOR izx|45 EOR zp|46 LSR zp|48 PHA imp|49 EOR imm|4A LSR acc|4C JMP abs|4D EOR abs|4E LSR abs|50 BVC rel|51 EOR izy|55 EOR zpx|56 LSR zpx|58 CLI imp|59 EOR aby|5D EOR abx|5E LSR abx|60 RTS imp|61 ADC izx|65 ADC zp|66 ROR zp|68 PLA imp|69 ADC imm|6A ROR acc|6C JMP ind|6D ADC abs|6E ROR abs|70 BVS rel|71 ADC izy|75 ADC zpx|76 ROR zpx|78 SEI imp|79 ADC aby|7D ADC abx|7E ROR abx|81 STA izx|84 STY zp|85 STA zp|86 STX zp|88 DEY imp|8A TXA imp|8C STY abs|8D STA abs|8E STX abs|90 BCC rel|91 STA izy|94 STY zpx|95 STA zpx|96 STX zpy|98 TYA imp|99 STA aby|9A TXS imp|9D STA abx|A0 LDY imm|A1 LDA izx|A2 LDX imm|A4 LDY zp|A5 LDA zp|A6 LDX zp|A8 TAY imp|A9 LDA imm|AA TAX imp|AC LDY abs|AD LDA abs|AE LDX abs|B0 BCS rel|B1 LDA izy|B4 LDY zpx|B5 LDA zpx|B6 LDX zpy|B8 CLV imp|B9 LDA aby|BA TSX imp|BC LDY abx|BD LDA abx|BE LDX aby|C0 CPY imm|C1 CMP izx|C4 CPY zp|C5 CMP zp|C6 DEC zp|C8 INY imp|C9 CMP imm|CA DEX imp|CC CPY abs|CD CMP abs|CE DEC abs|D0 BNE rel|D1 CMP izy|D5 CMP zpx|D6 DEC zpx|D8 CLD imp|D9 CMP aby|DD CMP abx|DE DEC abx|E0 CPX imm|E1 SBC izx|E4 CPX zp|E5 SBC zp|E6 INC zp|E8 INX imp|E9 SBC imm|EA NOP imp|EC CPX abs|ED SBC abs|EE INC abs|F0 BEQ rel|F1 SBC izy|F5 SBC zpx|F6 INC zpx|F8 SED imp|F9 SBC aby|FD SBC abx|FE INC abx"""
for e in T.split('|'):
    c,m,mode=e.split(); OPS[int(c,16)]=(m,mode)
LEN={'imp':1,'acc':1,'imm':2,'zp':2,'zpx':2,'zpy':2,'izx':2,'izy':2,'rel':2,'abs':3,'abx':3,'aby':3,'ind':3}
def off(bank,addr): return bank*0x4000+(addr&0x3FFF)
def dis(bank,start,end,out=sys.stdout):
    a=start
    while a<end:
        o=off(bank,a); b=PRG[o]
        if b not in OPS:
            out.write(f"{bank}:{a:04X}  {b:02X}        .db ${b:02X}\n"); a+=1; continue
        m,mode=OPS[b]; n=LEN[mode]; raw=PRG[o:o+n]
        if len(raw)<n or a+n>end:
            out.write(f"{bank}:{a:04X}  {b:02X}        .db ${b:02X}\n"); a+=1; continue
        v=raw[1] if n==2 else (raw[1]|raw[2]<<8 if n==3 else 0)
        s={'imp':'','acc':'A','imm':f'#${v:02X}','zp':f'${v:02X}','zpx':f'${v:02X},X','zpy':f'${v:02X},Y','izx':f'(${v:02X},X)','izy':f'(${v:02X}),Y','abs':f'${v:04X}','abx':f'${v:04X},X','aby':f'${v:04X},Y','ind':f'(${v:04X})'}.get(mode)
        if mode=='rel': s=f'${(a+2+(v-256 if v>127 else v))&0xFFFF:04X}'
        out.write(f"{bank}:{a:04X}  {' '.join('%02X'%x for x in raw):<9} {m} {s}\n"); a+=n

def main():
    if len(sys.argv) < 2:
        print(__doc__); return
    global PRG
    rom = open(sys.argv[1], 'rb').read()
    PRG = rom[16:16 + 0x20000]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'rom_listing')
    os.makedirs(out_dir, exist_ok=True)
    for bank in range(8):
        start = 0xC000 if bank == 7 else 0x8000
        with open(os.path.join(out_dir, 'bank%d.txt' % bank), 'w') as out:
            dis(bank, start, start + 0x4000, out)
    print('Wrote 8 listings to', os.path.normpath(out_dir))

if __name__ == '__main__':
    main()
