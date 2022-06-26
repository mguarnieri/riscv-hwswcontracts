


/* operators for architech state */
val SaveArchState : unit -> conf effect {rreg}
function SaveArchState () = {

    AS : list(xlenbits) = [||];
    foreach (i from 0 to 31) {
        AS = ( Xs[31-i] :: AS );
    }; 
    print("-------------Architecture state saved-----------");
    print_bits("Bpaswin:  ", Bpaswin);
    print_bits("PC: ", PC);
    print_bits("nextPC: ", nextPC);
    print("------------------------------------------------");
    (Bpaswin :: PC :: nextPC :: AS)
}

val SetArchState : conf -> unit effect {rreg, wreg}
function SetArchState (AS) = {
  let r : list(xlenbits) = match AS {
    [||] => [||],
    a :: b => { Bpaswin = a; match b {
                                      [||]     => [||],
                                      b1 :: b2 => { PC = b1; match b2{
                                                              [||]     => [||],
                                                              c1 :: c2 => { nextPC = c1; c2 }
                                                              }
                                                            }

                                      }
                                    }

  };
print("-------------Architecture state set-----------");
    print_bits("Bpaswin:  ", Bpaswin);
    print_bits("PC: ", PC);
    print_bits("nextPC: ", nextPC);
print("------------------------------------------------");
  t : list(xlenbits) = r; 
  foreach (i from 0 to 31) {
    let t3 : list(xlenbits) = match t {
      [||]     => [||],
      a :: t2  => { Xs[i] = a; t2}
    };
    t = t3;
  }
}

/* function exeSpec() for instructions */
//todo
val execBpas : (ast, list(conf), bool) -> (list(conf), Retired, bool)  effect {barr, eamem, escape, exmem, rmem, rmemt, rreg, undef, wmv, wmvt, wreg}



function clause execBpas (STORE(imm, rs2, rs1, width, aq, rl), s, flag) = {
  if flag then{
    retired : Retired = execute(STORE(imm, rs2, rs1, width, aq, rl));
    (s, retired, false)
  }
  else {
    s1 : conf = SaveArchState();
    initBpasWindow();
    (s1 :: s, RETIRE_SUCCESS, false)
  }
}


/*
function clause execSpec (RISCV_JAL(imm, rd), s, TempMem) = {
    (s, TempMem)
}


function clause execSpec (RISCV_JALR(imm, rs1, rd), s, TempMem) = {
    (s, TempMem)
}

*/
function clause execBpas (ast, s, flag) = {
    retired : Retired = execute(ast);
    if retired == RETIRE_SUCCESS then {
        decrementBpasWindow();
    };
    (s, retired, flag)
}


/* rollback */
val divide_list : list(conf) -> (conf, list(conf)) // get top and the rest of stack
function divide_list (s) = {
  match s { 
     [||] => ([||], [||]), 
     head :: rest => (head, rest)
 }
}


val rollback: list(conf) -> list(conf) effect {rmem, rreg, wmem, wreg}
function rollback s = 
{
    let (head, rest) = divide_list(s);
    SetArchState(head);
    rest
}