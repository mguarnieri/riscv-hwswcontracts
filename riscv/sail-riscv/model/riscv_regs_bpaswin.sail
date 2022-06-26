/* Speculative window */
register Bpaswin : xlenbits

let k1 : xlenbits = 0x0000000000000003 //initial value for Bpaswin

/* operators for speculative window */
val decrementBpasWindow : unit -> unit effect {rreg,wreg}
function decrementBpasWindow() = 
    match Bpaswin {
        0xFFFFFFFFFFFFFFFF => (), 
        _ : xlenbits       =>  Bpaswin = Bpaswin - 1
    }


val initBpasWindow : unit -> unit effect {rreg,wreg}
function initBpasWindow() = 
    match Bpaswin {
        0xFFFFFFFFFFFFFFFF => Bpaswin = k1, //  k is a constant value specifying the initial window
        _ : xlenbits       => Bpaswin = Bpaswin - 1
    }


val cleanBpasWindow : unit -> unit effect {rreg,wreg}
function cleanBpasWindow() = 
    match Bpaswin {
        _ : xlenbits       => Bpaswin = 0x0000000000000000
    }



/* type 0f conf */
type conf = list(xlenbits)