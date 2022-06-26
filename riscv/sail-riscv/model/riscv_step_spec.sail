/* The emulator fetch-execute-interrupt dispatch loop. */
/* returns whether to increment the step count in the trace */
function step(step_no : int, s : list(conf), TempMem : tempmem) -> (bool,  list(conf), observations,tempmem) = {
  /* for step extensions */
  ext_pre_step_hook();

  minstret_written = false;     /* see note for minstret */
  let ( sx, obs, TempMemx, retired, stepped) : (list(conf), observations, tempmem, Retired, bool) =
    match dispatchInterrupt(cur_privilege) {
      Some(intr, priv) => {
        if   get_config_print_instr()
        then print_bits("Handling interrupt: ", interruptType_to_bits(intr));
        handle_interrupt(intr, priv);
        ( s, EPSILON(), TempMem, RETIRE_FAIL, false)
      },
      None() => {
        /* the extension hook interposes on the fetch result */
        let f : FetchResult = ext_fetch_hook(fetch());
        match f {
          /* extension error */
          F_Ext_Error(e)   => {
            ext_handle_fetch_check_error(e);
            ( s, EPSILON(), TempMem, RETIRE_FAIL, false)
          },
          /* standard error */
          F_Error(e, addr) => {
            handle_mem_exception(addr, e);
            ( s, EPSILON(), TempMem, RETIRE_FAIL, false)
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
              let (s1, TempMem1, b) = execSpec(ext_post_decode_hook(ast), s, TempMem);
              
              let ob : observations = match b {
                RETIRE_SUCCESS => { label(true, ast) },
                RETIRE_FAIL    => { print("retired not successfully--------------");label(false, ast) }
              };
              print(obs_str(ob));
              (s1, ob, TempMem1, b, true)
             } else {
              handle_illegal();
              ( s, EPSILON(), TempMem, RETIRE_FAIL, true)
             }
          },
          F_Base(w) => {
            let ast = decode(w);
            if   get_config_print_instr()
            then {
              print_instr("[" ^ string_of_int(step_no) ^ "] [" ^ to_str(cur_privilege) ^ "]: " ^ BitStr(PC) ^ " (" ^ BitStr(w) ^ ") " ^ to_str(ast));
            };
            nextPC = PC + 4;
            let ( s1, TempMem1, b) = execSpec(ext_post_decode_hook(ast), s, TempMem);
              let ob : observations = match b {
                RETIRE_SUCCESS => {  label(true, ast) },
                RETIRE_FAIL    => { print("retired not successfully--------------"); label(false, ast) }
              };
              print(obs_str(ob));
              print("\n");
              (s1, ob, TempMem1, b, true)
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
  (stepped,  sx, obs,TempMemx)
}


function loop () : unit -> unit = {
  let insns_per_tick = plat_insns_per_tick();
  i : int = 0;
  step_no : int = 0;
  s : list(conf) = [||];
  TempMem : tempmem = [||];
  t : list(observations) = [||];
  stepped : bool = false;
  obs : observations = EPSILON();
  Specwin = 0xFFFFFFFFFFFFFFFF;
  while (~ (htif_done)) do {
    (stepped, s, obs, TempMem) = step(step_no, s, TempMem);
    state_output(TempMem);
    if stepped then { 
      step_no = step_no + 1;
      t = append_obs(t, obs);
    };
    if Specwin == 0x0000000000000000 then {
      print("-----------rollback---------------");
            (s, TempMem) = rollback(s);
            state_output(TempMem);
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
