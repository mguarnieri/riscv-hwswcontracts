/* Contract： CT */



/* Observations */
scattered union observations
union clause observations = EPSILON : unit
union clause observations = OBSPC : (bool, xlenbits)
union clause observations = OBSLOAD : (bool, xlenbits, word_width, xlenbits)
union clause observations = OBSSTORE : (bool, xlenbits, word_width, xlenbits)


type traces = list(observations)

/* functions for traces*/
val append_obs : (list(observations), observations) -> list(observations)
function append_obs(t, obs) =
    match obs {
       EPSILON() => t,
       _ =>  obs :: t
    }

val obs_str : observations -> string
function obs_str (obs) ={
    match obs {
        EPSILON() => "",
        OBSPC(b, pc) => "PC " ^ BitStr(pc),
        OBSLOAD(b, addr, width, va) => match width {
                                      BYTE    => "LOAD " ^ BitStr(addr) ^ " BYTE " ^ BitStr(va[7..0]),
                                      HALF    => "LOAD " ^ BitStr(addr) ^ " HALF " ^ BitStr(va[15..0]),
                                      WORD    => "LOAD " ^ BitStr(addr) ^ " WORD " ^ BitStr(va[31..0]),
                                      DOUBLE  => "LOAD " ^ BitStr(addr) ^ " DOUBLE " ^ BitStr(va)
                                      },
        OBSSTORE(b, addr, width, va) => match width {
                                      BYTE    => "STORE " ^ BitStr(addr) ^ " BYTE " ^ BitStr(va[7..0]),
                                      HALF    => "STORE " ^ BitStr(addr) ^ " HALF " ^ BitStr(va[15..0]),
                                      WORD    => "STORE " ^ BitStr(addr) ^ " WORD " ^ BitStr(va[31..0]),
                                      DOUBLE  => "STORE " ^ BitStr(addr) ^ " DOUBLE " ^ BitStr(va)
                                      }
    }
}

val trace_str : traces -> string 
function trace_str (t) = {
    if t == [||] then "Traces: \n"
    else { 
        match t {
        obs :: t1 => trace_str(t1) ^ obs_str(obs)^"\n",
        _ => "end"
        }
    }
}

/* functions: label()*/
val label : (bool, ast) -> observations effect {eamem, escape, rmem, rmemt, rreg, wmv, wmvt, wreg}
/* LOAD */ 
function clause label (retired, LOAD(imm, rs1, rd, is_unsigned, width, aq, rl)) = {
  let offset : xlenbits = EXTS(imm);
  /* Get the address, X(rs1) + offset.
     Some extensions perform additional checks on address validity. */
  OBSLOAD(retired, X(rs1) + offset, width, X(rd))
      
}



function clause label (retired, STORE(imm, rs2, rs1, width, aq, rl)) = {
    let offset : xlenbits = EXTS(imm);
  /* Get the address, X(rs1) + offset.
     Some extensions perform additional checks on address validity. */
    OBSSTORE(retired, X(rs1) + offset, width, X(rs2))
            
}



function clause label (retired, RISCV_JAL(imm, rd)) = {
  let t : xlenbits = PC + EXTS(imm);
  /* Extensions get the first checks on the prospective target address. */
  OBSPC(retired, nextPC)
}


function clause label (retired, RISCV_JALR(imm, rs1, rd)) = {
  OBSPC(retired, nextPC)
}



function clause label (retired, BTYPE(imm, rs2, rs1, op)) = {
  OBSPC(retired, nextPC)
}



function clause label _ = EPSILON()
