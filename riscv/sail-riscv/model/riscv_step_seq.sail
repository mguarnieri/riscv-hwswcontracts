/* The emulator fetch-execute-interrupt dispatch loop. */

/* returns whether to increment the step count in the trace */
function step(step_no : int) -> (observations, bool ) = {
  /* for step extensions */
  ext_pre_step_hook();

  minstret_written = false;     /* see note for minstret */
  let ( obs, retired, stepped) : (observations, Retired, bool) =
    match dispatchInterrupt(cur_privilege) {
      Some(intr, priv) => {
        if   get_config_print_instr()
        then print_bits("Handling interrupt: ", interruptType_to_bits(intr));
        handle_interrupt(intr, priv);
        ( EPSILON(), RETIRE_FAIL, false)
      },
      None() => {
        /* the extension hook interposes on the fetch result */
        let f : FetchResult = ext_fetch_hook(fetch());
        match f {
          /* extension error */
          F_Ext_Error(e)   => {
            ext_handle_fetch_check_error(e);
            ( EPSILON(), RETIRE_FAIL, false)
          },
          /* standard error */
          F_Error(e, addr) => {
            handle_mem_exception(addr, e);
            (EPSILON(), RETIRE_FAIL, false)
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
              let b : Retired = execute(ext_post_decode_hook(ast));
              let ob : observations = match b {
                RETIRE_SUCCESS => { print(obs_str(label(true, ast))); label(true, ast) },
                RETIRE_FAIL    => { print(obs_str(label(false, ast))); label(false, ast) }
              };
              print(obs_str(ob));
              (ob, b, true)
             } else {
              handle_illegal();
              ( EPSILON(),RETIRE_FAIL, true)
             }
          },
          F_Base(w) => {
            let ast = decode(w);
            if   get_config_print_instr()
            then {
              print_instr("[" ^ string_of_int(step_no) ^ "] [" ^ to_str(cur_privilege) ^ "]: " ^ BitStr(PC) ^ " (" ^ BitStr(w) ^ ") " ^ to_str(ast));
            };
            nextPC = PC + 4;
            let b : Retired = execute(ext_post_decode_hook(ast));
              let ob : observations = match b {
                RETIRE_SUCCESS => { print(obs_str(label(true, ast))); label(true, ast) },
                RETIRE_FAIL    => { print(obs_str(label(false, ast))); label(false, ast) }
              };
              print(obs_str(ob));
              (ob, b, true)
          }
        }
      }
    };
  print_bits("nextPC: ", nextPC);
  tick_pc();

  /* update minstret */
  match retired {
    RETIRE_SUCCESS => retire_instruction(),
    RETIRE_FAIL    => ()
  };

  /* for step extensions */
  ext_post_step_hook();

  (obs, stepped)
}

function loop () : unit -> unit = {
  let insns_per_tick = plat_insns_per_tick();
  i : int = 0;
  step_no : int = 0;
  t : list(observations) = [||];
  stepped : bool = false;
  obs : observations = EPSILON();

  while (~ (htif_done)) do {
    let (obs, stepped) = step(step_no);
    state_output();
    if stepped then { 
      step_no = step_no + 1;
      t = append_obs(t, obs);
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
