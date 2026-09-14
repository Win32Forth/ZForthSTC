\ autoload.fth — 64Forth product boot (lowercase name required)
\ Loaded automatically after kernel_init when present in Resources/AutoLoad/.
\ During load, session cwd is this AutoLoad folder (nested FLOAD sees siblings).

ONLY FORTH DEFINITIONS

\ --- Required boot word ------------------------------------------------------
\ Host executes MAIN once after autoload. Wrap the body in CATCH so faults
\ print cleanly and return to the REPL.
\ Note: use ." (not .() for the fault message — .( is IMMEDIATE and would
\ print while compiling MAIN. 64Forth has no .ERROR; print the code with .

: APP-RUN  ( -- )
  \ Default: nothing (editor / hyper / emitter already loaded above).
  \ Put product startup here, or enable the template block below.
  ;

: MAIN  ( -- )
  ['] APP-RUN CATCH
  ?DUP IF
    ." AutoLoad MAIN: exception " . CR
  THEN
  ;
