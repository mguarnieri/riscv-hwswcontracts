/* The emulator fetch-execute-interrupt dispatch loop. */
/* returns whether to increment the step count in the trace */
function step(step_no : int, s : list(conf), flag : bool) -> (bool,  list(conf), observations, bool) = {
  /* for step extensions */
  ext_pre_step_hook();

  minstret_written = false;     /* see note for minstret */
  let ( sx, obs, retired, stepped, flag1) : (list(conf), observations, Retired, bool, bool) =
    match dispatchInterrupt(cur_privilege) {
      Some(intr, priv) => {
        if   get_config_print_instr()
        then print_bits("Handling interrupt: ", interruptType_to_bits(intr));
        handle_interrupt(intr, priv);
        ( s, EPSILON(), RETIRE_FAIL, false, flag)
      },
      None() => {
        /* the extension hook interposes on the fetch result */
        let f : FetchResult = ext_fetch_hook(fetch());
        match f {
          /* extension error */
          F_Ext_Error(e)   => {
            ext_handle_fetch_check_error(e);
            ( s, EPSILON(), RETIRE_FAIL, false, flag)
          },
          /* standard error */
          F_Error(e, addr) => {
            handle_mem_exception(addr, e);
            ( s, EPSILON(), RETIRE_FAIL, false, flag)
          },
          /* non-error cases: */
          F_RVC(h) => {
            let ast = decodeCompressed(h);
            if   get_config_print_instr()
            then {
              print_instr("[" ^ string_of_int(step_no) ^ "] [" ^ to_str(cur_privilege) ^ "]: " ^ BitStr(PC) ^ " (" ^ BitStr(h) ^ ") " ^ to_str(ast));
            };
            /* check for RVC once here instead of every RVC execute clause. */
            if haveRVC() then {
              nextPC = PC + 2;
              let (s1, b, flag2) = execBpas(ext_post_decode_hook(ast), s, flag);
              
              let ob : observations = match b {
                RETIRE_SUCCESS => { 
                  match (flag, ast){
                      (false, STORE(imm, rs2, rs1, width, aq, rl)) => EPSILON(),
                      (_,_)                                        => label(true, ast) 
                  } 
                },
                
                
                RETIRE_FAIL    => { 
                  match (flag, ast){
                      (false, STORE(imm, rs2, rs1, width, aq, rl)) => EPSILON(),
                      (_,_)                                        => label(false, ast) 
                  } 
                }
              };
              print(obs_str(ob));
              (s1, ob, b, true, flag2)
             } else {
              handle_illegal();
              ( s, EPSILON(), RETIRE_FAIL, true, flag)
             }
          },
          F_Base(w) => {
            let ast = decode(w);
            if   get_config_print_instr()
            then {
              print_instr("[" ^ string_of_int(step_no) ^ "] [" ^ to_str(cur_privilege) ^ "]: " ^ BitStr(PC) ^ " (" ^ BitStr(w) ^ ") " ^ to_str(ast));
            };
            nextPC = PC + 4;
            let ( s1, b, flag2) = execBpas(ext_post_decode_hook(ast), s, flag);
                            let ob : observations = match b {
                RETIRE_SUCCESS => { 
                  match (flag, ast){
                      (false, STORE(imm, rs2, rs1, width, aq, rl)) => EPSILON(),
                      (_,_)                                        => label(true, ast) 
                  } 
                },
                
                
                RETIRE_FAIL    => { 
                  match (flag, ast){
                      (false, STORE(imm, rs2, rs1, width, aq, rl)) => EPSILON(),
                      (_,_)                                        => label(false, ast) 
                  } 
                }
              };
              print(obs_str(ob));
              print("\n");
              (s1, ob, b, true, flag2)
          }
        }
      }
    };

    tick_pc();
  /* update minstret */
  match retired {
    RETIRE_SUCCESS => retire_instruction(),
    RETIRE_FAIL    => ()
  };

  /* for step extensions */
  ext_post_step_hook();
  (stepped,  sx, obs, flag1)
}


function loop () : unit -> unit = {
  let insns_per_tick = plat_insns_per_tick();
  i : int = 0;
  step_no : int = 0;
  s : list(conf) = [||];
  t : list(observations) = [||];
  stepped : bool = false;
  obs : observations = EPSILON();
  flag : bool = false;
  Bpaswin = 0xFFFFFFFFFFFFFFFF;
  while (~ (htif_done)) do {
    (stepped, s, obs, flag) = step(step_no, s, flag);
    state_output();
    if stepped then { 
      step_no = step_no + 1;
      t = append_obs(t, obs);
    };
    if Bpaswin == 0x0000000000000000 then {
      print("-----------rollback---------------");
            s = rollback(s);
            flag = true;
            nextPC = PC;
            state_output();
            tick_pc();
            t = OBSPC(true, nextPC) :: t;
    };


    /* check htif exit */
    if htif_done then {
      let exit_val = unsigned(htif_exit_code);
      if exit_val == 0 then print("SUCCESS")
      else print_int("FAILURE: ", exit_val);
    } else {
      /* update time */
      i = i + 1;
      if i == insns_per_tick then {
        tick_clock();
        /* for now, we drive the platform i/o at every clock tick. */
        tick_platform();
        i = 0;
      }
    }
  };
  print(trace_str(t))
}

/* initialize model state */
function init_model () -> unit = {
  init_platform (); /* devices */
  init_sys ();      /* processor */
  init_vmem ();     /* virtual memory */

  /* initialize extensions last */
  ext_init ();
  ext_init_regs ();
}
