
val state_output: unit -> unit effect {rreg}
function state_output () = {
    print_bits("PC: ", PC);
    print("\n")
}
