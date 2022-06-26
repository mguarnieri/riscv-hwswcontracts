/* Physical memory model.
 *
 * This assumes that the platform memory map has been defined, so that accesses
 * to MMIO regions can be dispatched.
 *
 * The implementation below supports the reading and writing of memory
 * metadata in addition to raw memory data.
 *
 * The external API for this module is
 *   {mem_read, mem_read_meta, mem_write_ea, mem_write_value_meta, mem_write_value}
 * where mem_write_value is a special case of mem_write_value_meta that uses
 * a default value of the metadata.
 *
 * The internal implementation first performs a PMP check (if PMP is
 * enabled), and then dispatches to MMIO regions or physical memory as
 * per the platform memory map.
 */
val "or_vec" : forall 'n. (bits('n), bits('n)) -> bits('n)

val zero_extend = "zero_extend" : forall 'n 'm, 'm >= 'n. (bits('n), atom('m)) -> bits('m)

overload operator | = {or_vec}

val zeros = "zeros" : forall 'n. atom('n) -> bits('n)

val find : (xlenbits, list(mementry)) -> (bool, bits(8))
function find (addr, vMem) = {
    flag : bool = false;
    value : bits(8) = 0x00;
    vMemX = vMem;
    while ((vMemX != [||]) & (flag != true)) do {
        let (addr1, value1) :: vMem1 = vMemX;
        if (addr == addr1) then {
            flag = true;
            value = value1;
        }
        else {
            vMemX = vMem1;
        };
    };
    (flag, value)
}


val read_ram_spec : forall 'n, 0 < 'n <= max_mem_access .  (read_kind, xlenbits, atom('n), tempmem, bool) -> (bits(8 * 'n), mem_meta) effect {rmem, rreg}
function read_ram_spec(rk, addr, width, TempMem, read_meta) = {
  let meta = if read_meta then __ReadRAM_Meta(addr, width) else default_meta;
  match Specwin {
        0xFFFFFFFFFFFFFFFF => // we're not speculating
                {
                     (__read_mem(rk, sizeof(xlen), addr, width), meta)
                }, 
        _ : xlenbits       => // we're  speculating
                {   
                    result = zeros(width * 8);
                    addrx : xlenbits = addr;
                    foreach (i from 1 to width) {
                        let (flag, value) = find(addrx, TempMem);
                        if flag then {
                            result = (result << 8) | zero_extend(value, width * 8);
                        }
                        else{
                            result = (result << 8) | zero_extend(__read_mem(rk, sizeof(xlen), addr, 1), width * 8);
                        };
                        addrx = addrx + 1;
                    };
                    (result, meta)
                } 
    }

}


// only used for actual memory regions, to avoid MMIO effects
function phys_mem_read_spec forall 'n, 0 < 'n <= max_mem_access . (t : AccessType(ext_access_type), paddr : xlenbits, width : atom('n), aq : bool, rl: bool, res : bool, TempMem : tempmem, meta : bool) -> MemoryOpResult((bits(8 * 'n), mem_meta)) = {
  let result = (match read_kind_of_flags(aq, rl, res) {
    Some(rk) => Some(read_ram_spec(rk, paddr, width, TempMem, meta)),
    None()   => None()
  }) : option((bits(8 * 'n), mem_meta));
  match (t, result) {
    (Execute(),  None()) => MemException(E_Fetch_Access_Fault()),
    (Read(Data), None()) => MemException(E_Load_Access_Fault()),
    (_,          None()) => MemException(E_SAMO_Access_Fault()),
    (_,      Some(v, m)) => { if   get_config_print_mem()
                              then print_mem("mem[" ^ to_str(t) ^ "," ^ BitStr(paddr) ^ "] -> " ^ BitStr(v));
                              MemValue(v, m) }
  }
}

/* dispatches to MMIO regions or physical memory regions depending on physical memory map */
function checked_mem_read_spec forall 'n, 0 < 'n <= max_mem_access . (t : AccessType(ext_access_type), paddr : xlenbits, width : atom('n), aq : bool, rl : bool, res: bool, TempMem : tempmem, meta : bool) -> MemoryOpResult((bits(8 * 'n), mem_meta)) =
  if   within_mmio_readable(paddr, width)
  then MemoryOpResult_add_meta(mmio_read(t, paddr, width), default_meta)
  else if within_phys_mem(paddr, width)
  then phys_mem_read_spec(t, paddr, width, aq, rl, res,TempMem, meta)
  else match t {
    Execute()  => MemException(E_Fetch_Access_Fault()),
    Read(Data) => MemException(E_Load_Access_Fault()),
    _          => MemException(E_SAMO_Access_Fault())
  }

/* PMP checks if enabled */
function pmp_mem_read_spec forall 'n, 0 < 'n <= max_mem_access . (t : AccessType(ext_access_type), paddr : xlenbits, width : atom('n), aq : bool, rl : bool, res: bool, TempMem : tempmem, meta : bool) -> MemoryOpResult((bits(8 * 'n), mem_meta)) =
  if   (~ (plat_enable_pmp ()))
  then checked_mem_read_spec(t, paddr, width, aq, rl, res, TempMem, meta)
  else {
    match pmpCheck(paddr, width, t, effectivePrivilege(t, mstatus, cur_privilege)) {
      None()  => checked_mem_read_spec(t, paddr, width, aq, rl, res, TempMem, meta),
      Some(e) => MemException(e)
    }
  }



/* NOTE: The rreg effect is due to MMIO. */
$ifdef RVFI_DII
val mem_read_spec      : forall 'n, 0 < 'n <= max_mem_access . (AccessType(ext_access_type), xlenbits, atom('n), bool, bool, bool, tempmem)       -> MemoryOpResult(bits(8 * 'n))           effect {wreg, rmem, rmemt, rreg, escape}
val mem_read_meta_spec : forall 'n, 0 < 'n <= max_mem_access . (AccessType(ext_access_type), xlenbits, atom('n), bool, bool, bool, tempmem, bool) -> MemoryOpResult((bits(8 * 'n), mem_meta)) effect {wreg, rmem, rmemt, rreg, escape}
$else
val mem_read_spec      : forall 'n, 0 < 'n <= max_mem_access . (AccessType(ext_access_type), xlenbits, atom('n), bool, bool, bool, tempmem)       -> MemoryOpResult(bits(8 * 'n))            effect {rmem, rmemt, rreg, escape}
val mem_read_meta_spec : forall 'n, 0 < 'n <= max_mem_access . (AccessType(ext_access_type), xlenbits, atom('n), bool, bool, bool, tempmem, bool) -> MemoryOpResult((bits(8 * 'n), mem_meta)) effect {rmem, rmemt, rreg, escape}
$endif

function mem_read_meta_spec (typ, paddr, width, aq, rl, res, TempMem, meta) = {
  let result : MemoryOpResult((bits(8 * 'n), mem_meta)) =
    if (aq | res) & (~ (is_aligned_addr(paddr, width)))
    then MemException(E_Load_Addr_Align())
    else match (aq, rl, res) {
      (false, true,  false) => throw(Error_not_implemented("load.rl")),
      (false, true,  true)  => throw(Error_not_implemented("lr.rl")),
      (_, _, _)             => pmp_mem_read_spec(typ, paddr, width, aq, rl, res, TempMem, meta)
    };
  rvfi_read(paddr, width, MemoryOpResult_drop_meta(result));
  result
}

function mem_read_spec (typ, paddr, width, aq, rl, res, TempMem) =
  MemoryOpResult_drop_meta(mem_read_meta_spec(typ, paddr, width, aq, rl, res, TempMem, false))
















/* memery write*/


val write_ram_spec = {lem: "write_ram", coq: "write_ram"} : forall 'n, 0 < 'n <= max_mem_access . (write_kind, xlenbits, atom('n), bits(8 * 'n), tempmem, mem_meta) -> (bool, tempmem) effect {rreg, wmv, wmvt}
function write_ram_spec(wk, addr, width, value, TempMem, meta) = {
  /* Write out metadata only if the value write succeeds.
   * It is assumed for now that this write always succeeds;
   * there is currently no return value.
   * FIXME: We should convert the external API for all backends
   * (not just for Lem) to consume the value along with the
   * metadata to ensure atomicity.
   */
    match Specwin {
        0xFFFFFFFFFFFFFFFF => // we're not speculating
                {
                    let ret : bool = __write_mem(wk, sizeof(xlen), addr, width, value);
                    if ret then __WriteRAM_Meta(addr, width, meta);
                    (ret, TempMem)
                }, 
        _ : xlenbits       => // we're  speculating
                {  
                    addrx : xlenbits = addr;
                    TempMemX : tempmem = match width {
                      1    => ((addrx, value[7..0]) :: TempMem),
                      2    => ((addrx + 1, value[15..8]) :: ((addrx, value[7..0]) :: TempMem)),
                      4    => ((addrx + 3, value[31..24]) :: ((addrx + 2, value[23..16]) :: ((addrx + 1, value[15..8]) :: ((addrx, value[7..0]) :: TempMem)))),
                      8    => ((addrx + 7, value[63..56]) :: ((addrx + 6, value[55..48]) :: ((addrx + 5, value[47..40]) :: ((addrx + 4, value[39..32]) :: ((addrx + 3, value[31..24]) :: ((addrx + 2, value[23..16]) :: ((addrx + 1, value[15..8]) :: ((addrx, value[7..0]) :: TempMem))))))))
                    };
                    (true, TempMemX)
                } 
    }
}

// only used for actual memory regions, to avoid MMIO effects
function phys_mem_write_spec forall 'n, 0 < 'n <= max_mem_access . (wk : write_kind, paddr : xlenbits, width : atom('n), data : bits(8 * 'n), TempMem : tempmem, meta : mem_meta) -> (MemoryOpResult(bool), tempmem) = {
  rvfi_write(paddr, width, data);
  if TempMem == [||] then print("--------------------------------------------------------------------------------------------");
  let (res : bool, t : tempmem) = write_ram_spec(wk, paddr, width, data, TempMem, meta);
  if t == [||] then print("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
  result = MemValue(res);
  if   get_config_print_mem()
  then print_mem("mem[" ^ BitStr(paddr) ^ "] <- " ^ BitStr(data));
  (result, t)
}

/* dispatches to MMIO regions or physical memory regions depending on physical memory map */
function checked_mem_write_spec forall 'n, 0 < 'n <= max_mem_access . (wk : write_kind, paddr : xlenbits, width : atom('n), data: bits(8 * 'n), TempMem : tempmem, meta: mem_meta) -> (MemoryOpResult(bool), tempmem) =
  if   within_mmio_writable(paddr, width)
  then (mmio_write(paddr, width, data), TempMem)
  else if within_phys_mem(paddr, width)
  then phys_mem_write_spec(wk, paddr, width, data, TempMem, meta)
  else (MemException(E_SAMO_Access_Fault()), TempMem)

/* PMP checks if enabled */
function pmp_mem_write_spec forall 'n, 0 < 'n <= max_mem_access . (wk: write_kind, paddr : xlenbits, width : atom('n), data: bits(8 * 'n), ext_acc: ext_access_type, TempMem : tempmem, meta: mem_meta) -> (MemoryOpResult(bool), tempmem) =
  if   (~ (plat_enable_pmp ()))
  then checked_mem_write_spec(wk, paddr, width, data, TempMem, meta)
  else {
    let typ : AccessType(ext_access_type) = Write(ext_acc);
    match pmpCheck(paddr, width, typ, effectivePrivilege(typ, mstatus, cur_privilege)) {
      None()  => checked_mem_write_spec(wk, paddr, width, data, TempMem, meta),
      Some(e) => (MemException(e), TempMem)
    }
  }

/* Atomic accesses can be done to MMIO regions, e.g. in kernel access to device registers. */

/* Memory write with an explicit metadata value.  Metadata writes are
 * currently assumed to have the same alignment constraints as their
 * data.
 * NOTE: The wreg effect is due to MMIO, the rreg is due to checking mtime.
 */
val mem_write_value_meta_spec : forall 'n, 0 < 'n <= max_mem_access . (xlenbits, atom('n), bits(8 * 'n), ext_access_type, mem_meta, bool, bool, bool, tempmem) -> (MemoryOpResult(bool), tempmem) effect {wmv, wmvt, rreg, wreg, escape}
function mem_write_value_meta_spec (paddr, width, value, ext_acc, meta, aq, rl, con, TempMem) = {
  rvfi_write(paddr, width, value);
  if (rl | con) & (~ (is_aligned_addr(paddr, width)))
  then (MemException(E_SAMO_Addr_Align()), TempMem)
  else match (aq, rl, con) {
    (false, false, false) => pmp_mem_write_spec(Write_plain, paddr, width, value, ext_acc, TempMem, meta),
    (false, true,  false) => pmp_mem_write_spec(Write_RISCV_release, paddr, width, value, ext_acc, TempMem, meta),
    (false, false, true)  => pmp_mem_write_spec(Write_RISCV_conditional, paddr, width, value, ext_acc, TempMem, meta),
    (false, true , true)  => pmp_mem_write_spec(Write_RISCV_conditional_release, paddr, width, value, ext_acc, TempMem, meta),
    (true,  true,  false) => pmp_mem_write_spec(Write_RISCV_strong_release, paddr, width, value, ext_acc, TempMem, meta),
    (true,  true , true)  => pmp_mem_write_spec(Write_RISCV_conditional_strong_release, paddr, width, value, ext_acc, TempMem, meta),
    // throw an illegal instruction here?
    (true,  false, false) => (throw(Error_not_implemented("store.aq")), TempMem),
    (true,  false, true)  => (throw(Error_not_implemented("sc.aq")), TempMem)
  }
}

/* Memory write with a default metadata value. */
val mem_write_value_spec : forall 'n, 0 < 'n <= max_mem_access . (xlenbits, atom('n), bits(8 * 'n), bool, bool, bool, tempmem) -> (MemoryOpResult(bool), tempmem) effect {wmv, wmvt, rreg, wreg, escape}
function mem_write_value_spec (paddr, width, value, aq, rl, con, TempMem) =
  mem_write_value_meta_spec(paddr, width, value, default_write_acc, default_meta, aq, rl, con, TempMem)
