

val state_output: tempmem -> unit effect {rreg}
function state_output(TempMem) = {
    print_bits("PC: ", PC);
    print_bits("nextPC: ", nextPC);

    print("Virtual memory:");
    
    TempMemx : tempmem = TempMem;
    while (TempMemx != [||]) do {
        let (addr, value) :: TempMem1 = TempMemx;
        print_bits("address: ", addr);
        print_bits("value: ", value);
        TempMemx = TempMem1;
    };
    print_bits("Specwin: ", Specwin);

    print("\n")
}