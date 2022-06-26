# Simulator genaration
	
1. To generate different contracts, move the corresponding makefile from  "../sail-riscv/makefiles" to "../sail-riscv", and rename it as 'makefile'.

2. Use command 
	'''
	$ make ARCH=RV64 ocaml_emulator/riscv_ocaml_sim_RV64
	'''
to generate the simulator with contracts. The simulate is ../ocaml_emulator/riscv_ocaml_sim_RV64.

3. Test examples are in ../test/riscv-tests. Use command
	'''
	$ ./ocaml_emulator/riscv_ocaml_sim_RV64  test/riscv-tests/example.elf
	'''
to run the program example.elf on the simulator.