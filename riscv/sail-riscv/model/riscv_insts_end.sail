

/* End definitions */
end ast
end execute
end assembly
end encdec
end encdec_compressed

val print_insn : ast -> string
function print_insn insn = assembly(insn)

overload to_str = {print_insn}

val decode : bits(32) -> ast effect {rreg}
function decode bv = encdec(bv)

val decodeCompressed : bits(16) -> ast effect {rreg}
function decodeCompressed bv = encdec_compressed(bv)
