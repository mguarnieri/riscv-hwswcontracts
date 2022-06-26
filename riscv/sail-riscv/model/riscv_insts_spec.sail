


/* operators for architech state */
val SaveArchState : tempmem -> conf effect {rreg}
function SaveArchState (TempMem) = {

    AS : list(xlenbits) = [||];
    foreach (i from 0 to 31) {
        AS = ( Xs[31-i] :: AS );
    }; 
    print("-------------Architecture state saved-----------");
    print_bits("Specwin:  ", Specwin);
    print_bits("PC: ", PC);
    print_bits("nextPC: ", nextPC);
    print("------------------------------------------------");
    (Specwin :: PC :: nextPC :: AS, TempMem)
}

val SetArchState : conf -> tempmem effect {rreg, wreg}
function SetArchState (AS) = {
  let (r, tm) : (list(xlenbits), tempmem) = match AS {
    ([||], _) => ([||], [||]),
    (a :: b, AS1) => { Specwin = a; match b {
                                      [||]     => ([||], [||]),
                                      b1 :: b2 => { PC = b1; match b2{
                                                              [||]     => ([||], [||]),
                                                              c1 :: c2 => { nextPC = c1; (c2, AS1)
                                                              }
                                                            }

                                      }
                                    }

    }

  };
print("-------------Architecture state set-----------");
    print_bits("Specwin:  ", Specwin);
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
  };
  tm
}

/* function exeSpec() for instructions */
//todo
val execSpec : (ast, list(conf), tempmem) -> (list(conf), tempmem, Retired)  effect {barr, eamem, escape, exmem, rmem, rmemt, rreg, undef, wmv, wmvt, wreg}


function clause execSpec (BTYPE(imm, rs2, rs1, op), s, TempMem) = {
    let save : xlenbits = nextPC;
    retired : Retired = execute(BTYPE(imm, rs2, rs1, op));
    
        

        st : conf = SaveArchState(TempMem);
        nextPC = save;
        initWindow();
        let rs1_val = X(rs1);
        let rs2_val = X(rs2);
        let taken : bool = match op {
          RISCV_BEQ  => rs1_val == rs2_val,
          RISCV_BNE  => rs1_val != rs2_val,
          RISCV_BLT  => rs1_val <_s rs2_val,
          RISCV_BGE  => rs1_val >=_s rs2_val,
          RISCV_BLTU => rs1_val <_u rs2_val,
          RISCV_BGEU => rs1_val >=_u rs2_val
        };
        let t : xlenbits = PC + EXTS(imm);
        if taken then (st :: s, TempMem, RETIRE_SUCCESS)
        else {
          /* Extensions get the first checks on the prospective target address. */
          match ext_control_check_pc(t) {
            Ext_ControlAddr_Error(e) => {
              ext_handle_control_check_error(e);
              (st :: s, TempMem, RETIRE_FAIL)
            },
            Ext_ControlAddr_OK(target) => {
              if bit_to_bool(target[1]) & (~ (haveRVC())) then {
                handle_mem_exception(target, E_Fetch_Addr_Align());
                (st :: s, TempMem, RETIRE_FAIL);
              } else {
                set_next_pc(target);
                (st :: s, TempMem, RETIRE_SUCCESS)
              }
            }
          }
        }
   

}


function clause execSpec (LOAD(imm, rs1, rd, is_unsigned, width, aq, rl), s, TempMem) = { 
  decrementWindow();
  let offset : xlenbits = EXTS(imm);
  /* Get the address, X(rs1) + offset.
     Some extensions perform additional checks on address validity. */
  match ext_data_get_addr(rs1, offset, Read(Data), width) {
    Ext_DataAddr_Error(e)  => { ext_handle_data_check_error(e); (s, TempMem, RETIRE_FAIL) },
    Ext_DataAddr_OK(vaddr) =>
      if   check_misaligned(vaddr, width)
      then { handle_mem_exception(vaddr, E_Load_Addr_Align()); (s, TempMem, RETIRE_FAIL) }
      else match translateAddr(vaddr, Read(Data)) {
        TR_Failure(e, _) => { handle_mem_exception(vaddr, e); (s, TempMem, RETIRE_FAIL) },
        TR_Address(paddr, _) => {
            let retired : Retired = match (width, sizeof(xlen)) {
              (BYTE, _)   =>
                process_load(rd, vaddr, mem_read_spec(Read(Data), paddr, 1, aq, rl, false, TempMem), is_unsigned),
              (HALF, _)   =>
                process_load(rd, vaddr, mem_read_spec(Read(Data), paddr, 2, aq, rl, false, TempMem), is_unsigned),
              (WORD, _)   =>
                process_load(rd, vaddr, mem_read_spec(Read(Data), paddr, 4, aq, rl, false, TempMem), is_unsigned),
              (DOUBLE, 64) =>
                process_load(rd, vaddr, mem_read_spec(Read(Data), paddr, 8, aq, rl, false, TempMem), is_unsigned)
            };
            (s, TempMem, retired)
        }
      }
  }
}



function clause execSpec (STORE(imm, rs2, rs1, width, aq, rl), s, TempMem) = {
  decrementWindow();
  let offset : xlenbits = EXTS(imm);
  /* Get the address, X(rs1) + offset.
     Some extensions perform additional checks on address validity. */
  match ext_data_get_addr(rs1, offset, Write(Data), width) {
    Ext_DataAddr_Error(e)  => { ext_handle_data_check_error(e); (s, TempMem, RETIRE_FAIL) },
    Ext_DataAddr_OK(vaddr) =>
      if   check_misaligned(vaddr, width)
      then { handle_mem_exception(vaddr, E_SAMO_Addr_Align()); (s, TempMem, RETIRE_FAIL) }
      else match translateAddr(vaddr, Write(Data)) {
        TR_Failure(e, _)    => { handle_mem_exception(vaddr, e); (s, TempMem, RETIRE_FAIL) },
        TR_Address(paddr, _) => {
          let eares : MemoryOpResult(unit) = match width {
            BYTE   => mem_write_ea(paddr, 1, aq, rl, false),
            HALF   => mem_write_ea(paddr, 2, aq, rl, false),
            WORD   => mem_write_ea(paddr, 4, aq, rl, false),
            DOUBLE => mem_write_ea(paddr, 8, aq, rl, false)
          };
          match (eares) {
            MemException(e) => { handle_mem_exception(vaddr, e); (s, TempMem, RETIRE_FAIL) },
            MemValue(_) => {
              let rs2_val = X(rs2);
              let (res, TempMemX) : (MemoryOpResult(bool), tempmem) = match (width, sizeof(xlen)) {
                  (BYTE, _)    => mem_write_value_spec(paddr, 1, rs2_val[7..0],  aq, rl, false, TempMem),
                  (HALF, _)    => mem_write_value_spec(paddr, 2, rs2_val[15..0], aq, rl, false, TempMem),
                  (WORD, _)    => mem_write_value_spec(paddr, 4, rs2_val[31..0], aq, rl, false, TempMem),
                  (DOUBLE, 64) => mem_write_value_spec(paddr, 8, rs2_val,        aq, rl, false, TempMem)
              };
              let retired : Retired = match (res) {
                  MemValue(true)  => RETIRE_SUCCESS,
                  MemValue(false) => internal_error("store got false from mem_write_value"),
                  MemException(e) => { handle_mem_exception(vaddr, e); RETIRE_FAIL }
              };
              
              (s, TempMemX, retired)
            }
          }
        }
      }
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
function clause execSpec (ast, s, TempMem) = {
    retired : Retired = execute(ast);
    if retired == RETIRE_SUCCESS then {
        decrementWindow();
    };
    (s, TempMem, retired)
}


/* rollback */
val divide_list : list(conf) -> (conf, list(conf)) // get top and the rest of stack
function divide_list (s) = {
  match s { 
     [||] => (([||], [||]), [||]), 
     head :: rest => (head, rest)
 }
}


val rollback: list(conf) -> (list(conf), tempmem) effect {rmem, rreg, wmem, wreg}
function rollback s = 
{
    let (head, rest) = divide_list(s);
    TempMem = SetArchState(head);
    (rest, TempMem)
}