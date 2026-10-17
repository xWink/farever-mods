"""Patch a disposable HashLink TEST runtime to look up reference classes.

Stock sys_resolve_type patches caller methods (unsupported by the current JIT).
The oracle calls the returned original objects via reflection, so it needs only
name lookup, without method patching or caller/reference layout equivalence.
Never use this test runtime to launch Farever.
"""
from pathlib import Path
import sys
p=Path(sys.argv[1])/'src/main.c'
s=p.read_text();a=s.index('static vdynamic *resolve_type(');b=s.index('\n#ifdef HL_VCC',a)
s=s[:a]+'''static vdynamic *resolve_type(hl_type *t, hl_type *gt) {
    for (int i = 0; i < main_ctx->m->code->ntypes; i++) {
        hl_type *candidate = main_ctx->m->code->types + i;
        if (candidate->kind == HOBJ && ucmp(t->obj->name, candidate->obj->name) == 0)
            return (vdynamic*)*candidate->obj->global_value;
    }
    return NULL;
}
'''+s[b:];p.write_text(s)
