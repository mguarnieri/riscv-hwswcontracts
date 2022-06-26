
--for RV64
*	Observation

    ** seperate the end definition and illegal instructions: creat a new file riscv_insts_illegal.sail for illegal instructions.
	
	** riscv_insts_obs_ct.sail riscv_insts_obs_arch.sail riscv_insts_obs_ct-pc.sail 
		
		*** the files should be placed between riscv_insts_end.sail and riscv_insts_illegal.sail.
		
		*** the ddefinition of observations
		
		*** operators for obsevations and trace
		
		*** label() for LOAD, STORE, RISCV_JAL, RISCV_JALR, BTYPE and default 



*	Main loop
	** Seq riscv_step_seq.sail
		*** riscv_step_seq.sail: add the label() to step() in riscv_step.sail
			
	** Speculative: 
		*** riscv_regs_specwin.sail
			**** placed after riscv_regs.sail
			**** definition of specwin, conf and tempmem
			**** initial of window size k
			**** operators for speculative window

		*** riscv_mem_spec.sail
			**** placed after riscv_mem.sail
			**** functions for speculative memory read and write

		*** riscv_insts_spec.sail
			**** save and set the architecture state (registers, TempMem)
			**** exexSpec() for LOAD, STORE, BTYPE and default
			**** operators for list(conf)

		*** riscv_step_spec.sail
			**** initialize the list(conf), Tempmem and list(observations) in loop(), and pass/undate them in step()

* Others
	** riscv_state_output_seq.sail riscv_state_output_spec.sail
		**** placed before step file
		**** output the PC, nextPC and Tempmem (if spec)