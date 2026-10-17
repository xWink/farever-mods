"""Make a LOCAL TEST-ONLY copy of the surviving mod without HLX registration.
Original protocol, offer and session methods remain unchanged. Never distribute
this binary as an installable mod. Requires crashlink (Python).
"""
from pathlib import Path
import sys
from crashlink.core import Bytecode, Function, Opcode, Reg, tIndex
source, dest = map(Path,sys.argv[1:3])
c=Bytecode.from_path(str(source))
# The public parser uses a varint here; the HL wire format uses one byte.
from crashlink.core import Regs
Regs.serialise=lambda self:bytes([len(self.value)])+b''.join(v.serialise() for v in self.value)
c.flags.value=0; c.has_debug_info=False
for f in c.functions:f.has_debug=False
kept=[]
for n in c.natives:
    if not n.name.resolve(c).startswith('hlx_'):
        kept.append(n);continue
    d=n.type.resolve(c).definition
    f=Function();f.type=n.type;f.findex=n.findex;f.regs=d.args+[d.ret];f.has_debug=False
    r=Reg(len(d.args));kind=d.ret.resolve(c).kind.value
    if kind==0:f.ops=[Opcode('Ret',{'ret':r})]
    elif kind==7:
        from crashlink.core import SerialisableBool
        f.ops=[Opcode('Bool',{'dst':r,'value':SerialisableBool(False)}),Opcode('Ret',{'ret':r})]
    else:f.ops=[Opcode('Null',{'dst':r}),Opcode('Ret',{'ret':r})]
    c.functions.append(f)
c.natives=kept
# Keep Haxe class/global initialization, but do not start the game controller.
entry=next(f for f in c.functions if f.findex.value==c.entrypoint.value)
for i,op in enumerate(entry.ops):
    if op.op=='Call0' and op.df['fun'].value==352: entry.ops[i]=Opcode('Nop',{})
# Load the comparison test as a plugin so sys_resolve_type sees this reference
# binary as the host. This adds only a test entry call, not protocol changes.
from crashlink.core import Native, strRef, fIndex
n=Native();c.strings.value.extend(['std','sys_load_plugin','build/oracle-test.hl'])
n.lib=strRef(len(c.strings.value)-3);n.name=strRef(len(c.strings.value)-2)
n.type=tIndex(next(i for i,t in enumerate(c.types) if hasattr(t.definition,'args') and [a.value for a in t.definition.args]==[14] and t.definition.ret.value==7))
n.findex=fIndex(max([f.findex.value for f in c.functions]+[n.findex.value for n in c.natives])+1);c.natives.append(n)
r=Reg(len(entry.regs));b=Reg(len(entry.regs)+1);entry.regs.extend([tIndex(14),tIndex(7)])
entry.ops[-1:-1]=[Opcode('String',{'dst':r,'ptr':strRef(len(c.strings.value)-1)}),Opcode('Call1',{'dst':b,'fun':n.findex,'arg0':r})]
dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(c.serialise())
print('Prepared test-only oracle:',dest)
