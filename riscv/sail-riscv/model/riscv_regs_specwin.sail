/* Speculative window */
register Specwin : xlenbits

let k : xlenbits = 0x0000000000000010 //initial value for Specwin

/* operators for speculative window */
val decrementWindow : unit -> unit effect {rreg,wreg}
function decrementWindow() = 
    match Specwin {
        0xFFFFFFFFFFFFFFFF => (), 
        _ : xlenbits       =>  Specwin = Specwin - 1
    }


val initWindow : unit -> unit effect {rreg,wreg}
function initWindow() = 
    match Specwin {
        0xFFFFFFFFFFFFFFFF => Specwin = k, //  k is a constant value specifying the initial window
        _ : xlenbits       => Specwin = Specwin - 1
    }


val cleanWindow : unit -> unit effect {rreg,wreg}
function cleanWindow() = 
    match Specwin {
        _ : xlenbits       => Specwin = 0x0000000000000000
    }



/* type 0f tempmem */
type mementry = (xlenbits, bits(8)) //(addr, value)
type tempmem = list(mementry)
type conf = (list(xlenbits), tempmem)