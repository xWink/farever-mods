/* No DX12/ImGui dependency. Reproduce the native caller's pointer return ABI. */
#define HL_NAME(n) pipeline_pointer_test_##n
#include <hl.h>

static unsigned char pipeline;

HL_PRIM void *HL_NAME(create)(void) { return &pipeline; }

HL_PRIM vbyte *HL_NAME(unbox)(vdynamic *value) {
    return value ? value->v.ptr : NULL;
}

HL_PRIM bool HL_NAME(check_return)(vdynamic *value, vdynamic *shader, vdynamic *builder, bool expect_null) {
    if (!value || value->t->kind != HFUN) return false;
    vclosure *receiver = (vclosure *)value;
    if (receiver->hasValue || receiver->t->fun->nargs != 2) return false;
    // Invoke exactly as makePipeline's real caller does. A Dynamic receiver
    // returns its wrapper address here, which must fail pointer identity.
    void *result = ((void *(*)(vdynamic *, vdynamic *))receiver->fun)(shader, builder);
    return result == (expect_null ? NULL : &pipeline);
}

DEFINE_PRIM(_ABSTRACT(dx_resource), create, _NO_ARG);
DEFINE_PRIM(_BYTES, unbox, _DYN);
DEFINE_PRIM(_BOOL, check_return, _DYN _DYN _DYN _BOOL);
