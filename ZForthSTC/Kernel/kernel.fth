\ High-level ZForthSTC — loaded after the inner primitives and the
\ assembly bootstrap compiler (: ; CREATE DOES> , HERE POSTPONE ...).
\ This file is real Forth, not .ascii embedded in the assembler.
\ PARSE / SETDOC are CODE; DOC" arms help for the next : / CREATE.

: DOC"  34 PARSE SETDOC ;

DOC" PAD ( -- addr ) scratch buffer"
CREATE PAD 256 ALLOT

\ --- Stack helpers ----------------------------------------------------------
\ NIP TUCK 2DUP 2DROP ROT 2SWAP 1+ 1- NEGATE are CODE (STC dual-tail).
DOC" 2>R ( x1 x2 -- ) ( R: -- x1 x2 ) move pair to return stack"
: 2>R  SWAP >R >R ;
DOC" 2R> ( -- x1 x2 ) ( R: x1 x2 -- ) restore pair from return stack"
: 2R>  R> R> SWAP ;
DOC" 2R@ ( -- x1 x2 ) ( R: x1 x2 -- x1 x2 ) copy pair from return stack"
: 2R@  R> R> 2DUP >R >R SWAP ;

\ --- CREATE-family ----------------------------------------------------------
DOC" CONSTANT ( x 'name' -- ) create constant"
: CONSTANT  CREATE , DOES> @ ;
DOC" VARIABLE ( 'name' -- ) create cell variable (0)"
: VARIABLE  CREATE 0 , ;

DOC" VOCABULARY ( 'name' -- ) named word list; execute to push onto search order"
: VOCABULARY  CREATE WORDLIST DROP DOES> PUSH-ORDER ;

VOCABULARY BIG-INTEGER
VOCABULARY EDITOR
VOCABULARY ASSEMBLER
VOCABULARY FP
VOCABULARY GRAPHICS
\ Minimal GRAPHICS stubs so PI/PIMAIN can load without AppKit words.
ALSO GRAPHICS DEFINITIONS
: CLS ;
: KEY  0 ;
PREVIOUS DEFINITIONS
ONLY FORTH DEFINITIONS

DOC" FALSE ( -- 0 )"
0 CONSTANT FALSE
DOC" TRUE ( -- -1 )"
-1 CONSTANT TRUE
DOC" CELL ( -- n ) address units per cell"
8 CONSTANT CELL
DOC" BL ( -- c ) space character"
32 CONSTANT BL

\ CELL+ CELLS = <> > 0<> are CODE (STC dual-tail).

\ --- Compile state ----------------------------------------------------------
DOC" [ ( -- ) enter interpret state (immediate)"
: [  0 STATE !  ; IMMEDIATE
DOC" ] ( -- ) enter compile state"
: ] -1 STATE !  ;
\ LITERAL is CODE (STC mov/DPUSH).
DOC" ['] ( C: 'name' -- ) ( -- xt ) compile xt of name (immediate)"
: [']  ' POSTPONE LITERAL ; IMMEDIATE
\ RECURSE is CODE (via _compile_word); do not redefine here.

\ --- Control structures (STC native branches / _stc_*_rt) -----------------
\ Compiled in asm (IF THEN ELSE BEGIN … DO/?DO/LOOP/+LOOP).

\ MIN MAX ABS ?DUP /MOD MOD are CODE (STC dual-tail).

\ --- I/O --------------------------------------------------------------------
\ CR SPACE SPACES COUNT TYPE are CODE (STC dual-tail).
DOC" DOT-QUOTE ( C: ccc -- ) compile print of string (immediate)"
\ Interpret or compile: print until " (ANS ." is compile-only; we allow both).
\ 34 = ASCII '"' — avoid [CHAR] (defined later / may be absent).
\ ." is CODE (immediate; STC-aware via S" compile path).
\ : ." STATE @ IF POSTPONE S" POSTPONE TYPE ELSE 34 PARSE TYPE THEN ; IMMEDIATE
DOC" .( ( -- ) print text until ) immediately (immediate; Core Ext)"
\ Skip leading spaces/tabs (ANS), then PARSE to ')' and TYPE.
\ 41 = ASCII ')'.
\ Use >IN @ 1+ >IN ! — +! is defined later in this file.
: .(
    BEGIN
      SOURCE NIP >IN @ >
      IF SOURCE DROP >IN @ + C@ DUP BL = SWAP 9 = OR ELSE FALSE THEN
    WHILE >IN @ 1+ >IN ! REPEAT
    41 PARSE TYPE ; IMMEDIATE

\ --- Memory words
\ CMOVE is CODE (STC dual-tail).

\ --- Number base ------------------------------------------------------------
DOC" DECIMAL ( -- ) set BASE to 10"
: DECIMAL  10 BASE ! ;
DOC" HEX ( -- ) set BASE to 16"
: HEX      16 BASE ! ;

\ --- Number output ----------------------------------------------------------
DOC" U. ( u -- ) print unsigned in BASE 10"
: U.  10 /MOD DUP IF RECURSE ELSE DROP THEN  48 + EMIT ;
DOC" (.) ( n -- ) print signed without trailing space"
: (.) DUP 0< IF 45 EMIT NEGATE THEN U. ;
DOC" . ( n -- ) print signed with trailing space"
: .   (.) SPACE ;

DOC" .S ( -- ) print data stack contents"
: .S  ( -- )
     DEPTH ." (" DUP (.) ." ) "
     DUP  0 > IF
         BEGIN DUP WHILE
             DUP PICK . 1 -
         REPEAT
     THEN DROP CR ;

\ --- Pictured numeric output (64Forth-style) --------------------------------
\ +! is CODE (STC dual-tail).
DOC" HLD ( -- a-addr ) pictured-output pointer variable"
VARIABLE HLD
DOC" <# ( -- ) begin pictured numeric output"
: <#  ( -- )  PAD 256 + HLD ! ;
DOC" HOLD ( char -- ) add char to pictured output"
: HOLD  ( char -- )  -1 HLD +!  HLD @ C! ;
DOC" #> ( xd -- c-addr u ) end pictured numeric output"
: #>  ( xd -- c-addr u )  2DROP HLD @ PAD 256 + OVER - ;
DOC" # ( ud1 -- ud2 ) convert one pictured digit"
: #   ( ud1 -- ud2 )
    0 BASE @ UM/MOD >R BASE @ UM/MOD R> ROT
    DUP 9 > IF 7 + THEN 48 + HOLD ;
DOC" #S ( ud1 -- ud2 ) convert remaining pictured digits"
: #S  ( ud1 -- ud2 )  BEGIN # 2DUP OR 0= UNTIL ;
DOC" SIGN ( n -- ) HOLD minus if n<0"
: SIGN  ( n -- )  0< IF 45 HOLD THEN ;
DOC" UD. ( ud -- ) print unsigned double"
: UD.  ( ud -- )  <# #S #> TYPE SPACE ;
DOC" D. ( n -- ) print signed via pictured output"
: D.   ( n -- )
    DUP 0< IF NEGATE 0 <# #S 45 HOLD #> ELSE 0 <# #S #> THEN TYPE SPACE ;

\ --- Dictionary walking -----------------------------------------------------
DOC" >LINK ( xt -- a-addr ) link field address"
: >LINK  16 - ;
DOC" >FLAGS ( xt -- a-addr ) flags field address"
: >FLAGS 8 - ;
DOC" >NAME ( xt -- nfa ) name field address"
: >NAME  DUP >FLAGS @ 65535 AND - ;
DOC" NFA ( xt -- nfa ) synonym for >NAME"
: NFA    >NAME ;
DOC" NAME>STRING ( xt -- c-addr u ) name as string"
: NAME>STRING  NFA COUNT ;
DOC" HFA ( xt -- hfa ) help field address"
: HFA    DUP >FLAGS @ 16 RSHIFT 65535 AND - ;
DOC" VIEW-LINE ( xt -- u ) 1-based source line in FLAGS (0=none)"
: VIEW-LINE  >FLAGS @ 32 RSHIFT 65535 AND ;
DOC" VIEW-FILE# ( xt -- u ) source file-id in FLAGS (0=none)"
: VIEW-FILE#  >FLAGS @ 48 RSHIFT 32767 AND ;
DOC" >HELP ( xt -- hfa ) help counted string"
: >HELP  HFA ;
DOC" >BODY ( xt -- a-addr ) parameter field (CFA+8)"
: >BODY  8 + ;

\ DEFER / IS — after ['] and >BODY (DEFER compiles ['] ABORT; DEFER@ uses >BODY).
\ Layout matches CONSTANT (data at >BODY CELL+ under STC CREATE/DOES>).
DOC" DEFER ( 'name' -- ) create deferred word (default ABORT; set with IS)"
: DEFER  CREATE ['] ABORT , DOES> @ EXECUTE ;
DOC" DEFER@ ( xt1 -- xt2 ) xt currently executed by deferred xt1"
: DEFER@  >BODY CELL+ @ ;
DOC" DEFER! ( xt1 xt2 -- ) set deferred xt2 to execute xt1"
: DEFER!  >BODY CELL+ ! ;
DOC" IS ( xt 'name' -- ) set deferred name (immediate)"
: IS  STATE @ IF POSTPONE ['] POSTPONE DEFER! ELSE ' DEFER! THEN ; IMMEDIATE
DOC" ACTION-OF ( 'name' -- xt ) xt currently in deferred name (immediate)"
: ACTION-OF  STATE @ IF POSTPONE ['] POSTPONE DEFER@ ELSE ' DEFER@ THEN ; IMMEDIATE

DOC" ALIGNED ( addr -- a-addr ) align upward to cell"
: ALIGNED  7 + 7 INVERT AND ;
DOC" ALIGN ( -- ) align HERE to cell boundary"
: ALIGN  HERE ALIGNED HERE - ALLOT ;
\ CHAR+ 2@ 2! UNDER+ are CODE (STC dual-tail).
DOC" FILL ( addr u b -- ) fill u bytes at addr with b"
: FILL  >R BEGIN DUP WHILE OVER R@ SWAP C! SWAP 1+ SWAP 1- REPEAT R> DROP 2DROP ;
DOC" ERASE ( addr u -- ) fill u bytes with zero"
: ERASE  0 FILL ;
VARIABLE (CMP-U1)
VARIABLE (CMP-U2)
DOC" COMPARE ( c-addr1 u1 c-addr2 u2 -- n ) string compare -1/0/1"
: COMPARE  ( c-addr1 u1 c-addr2 u2 -- n )
  (CMP-U2) ! >R (CMP-U1) ! >R      \ R: ca2 ca1
  R> R>                            \ ca1 ca2
  (CMP-U1) @ (CMP-U2) @ MIN 0 ?DO
    OVER I + C@  OVER I + C@ -
    ?DUP IF
      NIP NIP
      0< IF -1 ELSE 1 THEN
      UNLOOP EXIT
    THEN
  LOOP
  2DROP
  (CMP-U1) @ (CMP-U2) @
  2DUP = IF 2DROP 0 ELSE < IF -1 ELSE 1 THEN THEN ;
DOC" [DEFINED] ( 'name' -- flag ) true if name is found (immediate)"
: [DEFINED]  BL WORD FIND NIP 0<> ; IMMEDIATE
DOC" [UNDEFINED] ( 'name' -- flag ) true if name is not found (immediate)"
: [UNDEFINED]  BL WORD FIND NIP 0= ; IMMEDIATE
DOC" [THEN] ( -- ) end of [IF] (immediate no-op)"
: [THEN]  ; IMMEDIATE
DOC" [ELSE] ( -- ) skip to matching [THEN] (immediate)"
: [ELSE]
  1 BEGIN
    BEGIN BL WORD COUNT DUP WHILE
      2DUP S" [IF]" COMPARE 0= IF 2DROP 1+
      ELSE 2DUP S" [ELSE]" COMPARE 0= IF 2DROP 1- DUP IF 1+ THEN
      ELSE 2DUP S" [THEN]" COMPARE 0= IF 2DROP 1- ELSE 2DROP THEN THEN THEN
      DUP 0= IF DROP EXIT THEN
    REPEAT 2DROP REFILL 0= UNTIL DROP ; IMMEDIATE
DOC" [IF] ( flag -- ) interpret if true else skip to [ELSE]/[THEN] (immediate)"
: [IF]  0= IF POSTPONE [ELSE] THEN ; IMMEDIATE
DOC" ABORT-QUOTE ( flag -- ) if flag nonzero type message and ABORT (immediate)"
: ABORT"  STATE @ IF
    POSTPONE IF POSTPONE S" POSTPONE TYPE POSTPONE CR
    POSTPONE ABORT POSTPONE THEN
  ELSE 34 PARSE ROT IF TYPE CR ABORT THEN 2DROP THEN ; IMMEDIATE
\ CONTEXT = search_order[0] = GET-ORDER wid1 (not widn). Empty order -> FORTH.
DOC" (CONTEXT) ( -- wid ) first search-order wordlist (wid1), or FORTH"
: (CONTEXT)  GET-ORDER ?DUP 0= IF FORTH-WORDLIST EXIT THEN
  1- 0 ?DO NIP LOOP ;

DOC" (UPC) ( c -- c' ) uppercase ASCII letter"
: (UPC)  DUP 97 < 0= OVER 122 > 0= AND IF 32 - THEN ;

\ Optional WORDS filter (64Forth-style substring; case-insensitive)
CREATE (WFILT) 64 ALLOT
VARIABLE (WFILT-U)
VARIABLE (WM-CA)
VARIABLE (WM-U)
VARIABLE (WM-I)
VARIABLE (WM-OK)

DOC" (WFILT!) ( c-addr u -- ) store uppercased filter (max 63)"
: (WFILT!)
  63 MIN DUP (WFILT-U) !
  0 ?DO DUP I + C@ (UPC) (WFILT) I + C! LOOP DROP ;

DOC" (WORDS-AT?) ( -- flag ) match filter at (WM-CA)+(WM-I)"
: (WORDS-AT?)
  -1 (WM-OK) !
  (WFILT-U) @ 0 ?DO
    (WM-CA) @ (WM-I) @ + I + C@ (UPC)
    (WFILT) I + C@ <> IF 0 (WM-OK) ! LEAVE THEN
  LOOP (WM-OK) @ ;

DOC" (WORDS-MATCH?) ( xt -- flag ) true if name contains filter (or no filter)"
: (WORDS-MATCH?)
  (WFILT-U) @ 0= IF DROP TRUE EXIT THEN
  >NAME COUNT (WM-U) ! (WM-CA) !
  (WM-U) @ (WFILT-U) @ < IF FALSE EXIT THEN
  (WM-U) @ (WFILT-U) @ - 1+ 0 ?DO
    I (WM-I) !
    (WORDS-AT?) IF TRUE UNLOOP EXIT THEN
  LOOP FALSE ;

DOC" WORDS ( ['filter'] -- ) list CONTEXT names; optional substring filter"
: WORDS
    BL WORD COUNT (WFILT!)
    0 >R
    (CONTEXT) @
    BEGIN DUP WHILE
        DUP (WORDS-MATCH?) IF
            DUP >NAME COUNT DUP R> + >R TYPE SPACE
            R@ 60 > IF CR R> DROP 0 >R THEN
        THEN
        >LINK @
    REPEAT DROP R> DROP CR ;

\ --- SEE / HELP / LOCATE (STC Forth decompiler) -----------------------------
\ Colon bodies: CFA points at native code (typically xt+8). Decode adrp/add/blr,
\ lit, strings, and simple IF/ELSE/THEN. End bound = next word's HFA (or HERE).

VARIABLE VIEW-LEAF-A
VARIABLE VIEW-LEAF-U
DOC" (VIEW-BASENAME) leaf after last /"
: (VIEW-BASENAME)
    DUP 0= IF EXIT THEN
    OVER VIEW-LEAF-A ! DUP VIEW-LEAF-U ! 2DROP
    VIEW-LEAF-U @
    BEGIN 1- DUP 0< 0= WHILE
        VIEW-LEAF-A @ OVER + C@ 47 = IF
            1+ DUP VIEW-LEAF-A @ +
            SWAP VIEW-LEAF-U @ SWAP -
            EXIT
        THEN
    REPEAT
    DROP VIEW-LEAF-A @ VIEW-LEAF-U @ ;

DOC" (SEE-WHERE) ( xt -- ) print leaf:line when VIEW known"
: (SEE-WHERE)
    DUP VIEW-FILE# ?DUP 0= IF DROP EXIT THEN
    VIEW-PATH DUP 0= IF 2DROP DROP EXIT THEN
    (VIEW-BASENAME) TYPE 58 EMIT VIEW-LINE . CR ;

DOC" (SEE-HDR) ( xt -- xt ) print :/CODE tag and help or name"
: (SEE-HDR) ( xt -- xt )
    DUP XT? IF DUP @ OVER 8 + = ELSE FALSE THEN IF
        58 EMIT SPACE
    ELSE 67 EMIT 79 EMIT 68 EMIT 69 EMIT SPACE THEN
    DUP >HELP COUNT DUP IF TYPE ELSE 2DROP DUP NAME>STRING TYPE THEN CR ;

\ --- Body end: nearest later HFA across all registered wordlists ------------
\ WORDLISTS exposes the registry (FORTH + VOCABULARY wids). Exclusive end =
\ minimum HFA strictly above this word's code start, else HERE.
VARIABLE (SEE-CODE0)
VARIABLE (SEE-END-A)
DOC" (SEE-NEAR) ( nt -- flag ) if HFA is after code0 and closer than end, keep it"
: (SEE-NEAR)
    {: nt | h -- :}
    nt HFA TO h
    (SEE-CODE0) @ h U<
    h (SEE-END-A) @ U< AND IF h (SEE-END-A) ! THEN
    TRUE ;
DOC" (SEE-END) ( xt -- addr ) exclusive end = nearest later HFA, else HERE"
: (SEE-END)
    {: xt -- :}
    HERE (SEE-END-A) !
    xt @ (SEE-CODE0) !
    ['] (SEE-NEAR) FORTH-WORDLIST TRAVERSE-WORDLIST
    WORDLISTS 0 ?DO
        DUP I CELLS + @
        DUP FORTH-WORDLIST = IF DROP
        ELSE ['] (SEE-NEAR) SWAP TRAVERSE-WORDLIST THEN
    LOOP DROP
    (SEE-END-A) @ ;

\ --- Branch target map (addr,kind); kind 1=THEN 2=skip ---------------------
32 CONSTANT (SEE-TMAX)
CREATE (SEE-TADDR) (SEE-TMAX) CELLS ALLOT
CREATE (SEE-TKIND) (SEE-TMAX) CELLS ALLOT
VARIABLE (SEE-T#)
VARIABLE (SEE-SKIP-CBZ)   \ after LOOP-RT, swallow following back-cbz

DOC" (SEE-TCLR) ( -- ) clear branch target map"
: (SEE-TCLR)  0 (SEE-T#) !  FALSE (SEE-SKIP-CBZ) ! ;
DOC" (SEE-TREC) ( addr kind -- ) record branch target"
: (SEE-TREC)
    (SEE-T#) @ (SEE-TMAX) < IF
        (SEE-T#) @ CELLS (SEE-TKIND) + !
        (SEE-T#) @ CELLS (SEE-TADDR) + !
        1 (SEE-T#) +!
    ELSE 2DROP THEN ;
DOC" (SEE-TFIND) ( addr -- kind|0 ) lookup and clear slot"
: (SEE-TFIND)
    {: a | i k -- :}
    0 TO i  0 TO k
    BEGIN i (SEE-T#) @ < WHILE
        (SEE-TADDR) i CELLS + @ a = IF
            (SEE-TKIND) i CELLS + @ TO k
            0 (SEE-TADDR) i CELLS + !
            k EXIT
        THEN
        i 1+ TO i
    REPEAT
    k ;

DOC" (SEE-TCLR1) ( addr -- ) drop any recorded target at addr (no print)"
: (SEE-TCLR1)  (SEE-TFIND) DROP ;

DOC" (SEE-IND) ( -- ) print two-space indent (after CR before a conditional)"
: (SEE-IND)  SPACE SPACE ;

\ True after a token on the current line; CF only CRs when mid-line (no blank first line).
VARIABLE (SEE-NEED-CR)

DOC" (SEE-TOK) ( c-addr u -- ) type token + space (horizontal body)"
: (SEE-TOK)  TYPE SPACE  TRUE (SEE-NEED-CR) ! ;

DOC" (SEE-CF.) ( c-addr u -- ) CR if mid-line, indent, type conditional + space"
: (SEE-CF.)
    (SEE-NEED-CR) @ IF CR THEN
    (SEE-IND) TYPE SPACE
    TRUE (SEE-NEED-CR) ! ;

\ --- Insn predicates / decoders (decimal; kernel _number is decimal-only) --
\ Values = ARM64 encodings (hex in comments). Recompute with: HEX <enc> DECIMAL .
\ str x30,[x23,#-8]!          F81F8EFE
4162817790 CONSTANT (SEE-PROLOG)
\ ldr x30,[x23],#8            F84086FE
4164978430 CONSTANT (SEE-EPI-LDR)
\ ret                         D65F03C0
3596551104 CONSTANT (SEE-RET)
\ ldr x0,[x22],#8             F84086C0
4164978368 CONSTANT (SEE-DPOP0)
\ str x0,[x22,#-8]!           F81F8EC0
4162817728 CONSTANT (SEE-DPUSH0)
\ blr x16                     D63F0200
3594453504 CONSTANT (SEE-BLR16)
\ adrp x16: (insn AND 9F00001F) = 90000010
2415919120 CONSTANT (SEE-ADRP16M)
2667577375 CONSTANT (SEE-ADRP16A)
\ add x16,x16,#imm: (insn AND FFC003FF) = 91000210
2432696848 CONSTANT (SEE-ADD16M)
4290774015 CONSTANT (SEE-ADD16A)
\ movz x0,#imm: (insn AND FFE0001F) = D2800000
3531603968 CONSTANT (SEE-MOVZ0)
\ movk x0 markers (documentation / future; lit decode uses shifts)
4070572032 CONSTANT (SEE-MOVK16)
4072669184 CONSTANT (SEE-MOVK32)
4074766336 CONSTANT (SEE-MOVK48)
4292870175 CONSTANT (SEE-MOVMSK)
\ cbz/cbnz x0 / b
3019898880 CONSTANT (SEE-CBZ0)
3036676096 CONSTANT (SEE-CBNZ0)
4278190111 CONSTANT (SEE-CBMSK)
335544320 CONSTANT (SEE-B)
4227858432 CONSTANT (SEE-BMSK)

DOC" (SEE-ADRP?) ( insn -- flag )"
: (SEE-ADRP?)  (SEE-ADRP16A) AND (SEE-ADRP16M) = ;
DOC" (SEE-ADD16?) ( insn -- flag )"
: (SEE-ADD16?)  (SEE-ADD16A) AND (SEE-ADD16M) = ;
DOC" (SEE-SEX21) ( u21 -- n ) sign-extend 21-bit page imm"
: (SEE-SEX21)
    DUP 1048576 AND IF  -2097152 OR  ELSE  2097151 AND  THEN ;
DOC" (SEE-ADRP-TARGET) ( ip -- tgt ) decode adrp x16; add x16 at ip"
: (SEE-ADRP-TARGET)
    {: ip | insn imm page -- :}
    ip L@ TO insn
    insn 29 RSHIFT 3 AND
    insn 5 RSHIFT 524287 AND 2 LSHIFT OR (SEE-SEX21) TO imm
    ip 4095 INVERT AND  imm 12 LSHIFT + TO page
    ip 4 + L@ 10 RSHIFT 4095 AND  page + ;

DOC" (SEE-MOV-IMM) ( ip -- x ) assemble movz/movk x0 cluster at ip"
: (SEE-MOV-IMM)
    {: ip | x -- :}
    ip L@ 5 RSHIFT 65535 AND TO x
    ip 4 + L@ 5 RSHIFT 65535 AND 16 LSHIFT x OR TO x
    ip 8 + L@ 5 RSHIFT 65535 AND 32 LSHIFT x OR TO x
    ip 12 + L@ 5 RSHIFT 65535 AND 48 LSHIFT x OR TO x
    x ;

DOC" (SEE-BR-TGT) ( ip insn -- tgt ) B or CBZ/CBNZ target (imm in insns ×4)"
: (SEE-BR-TGT)
    {: ip insn | off -- :}
    insn (SEE-BMSK) AND (SEE-B) = IF
        insn 67108863 AND DUP 33554432 AND IF 67108864 - THEN TO off
    ELSE
        insn 5 RSHIFT 524287 AND DUP 262144 AND IF 524288 - THEN TO off
    THEN
    ip off 4 * + ;

DOC" (SEE-HEX.) ( u -- ) print 8 hex digits"
: (SEE-HEX.)
    BASE @ >R HEX 0 <# # # # # # # # # #> TYPE R> BASE ! ;

DOC" (SEE-NAME.) ( xt -- ) name + space (horizontal)"
: (SEE-NAME.)  NAME>STRING (SEE-TOK) ;

DOC" (SEE-XT.) ( x -- ) if x is an xt print its name, else lit x"
: (SEE-XT.)
    DUP XT? IF (SEE-NAME.) ELSE S" lit" (SEE-TOK) . THEN ;

DOC" (SEE-ALIGN8) ( addr -- addr' )"
: (SEE-ALIGN8)  7 + 7 INVERT AND ;

\ mov xt + blr _stc_create_xt (VARIABLE / CONSTANT / DOES> child)
DOC" (SEE-AT-CREATE?) ( ip -- flag ) movz cluster at ip followed by create-xt call"
: (SEE-AT-CREATE?)
    {: ip -- :}
    ip 16 + L@ (SEE-ADRP?) 0= IF FALSE EXIT THEN
    ip 20 + L@ (SEE-ADD16?) 0= IF FALSE EXIT THEN
    ip 24 + L@ (SEE-BLR16) = 0= IF FALSE EXIT THEN
    ip 16 + (SEE-ADRP-TARGET) CREATE-XT-ADDR = ;

DOC" (SEE-CREATE-XT) ( ip -- ip' ) mov xt + create-xt → name (imm is xt, not code)"
: (SEE-CREATE-XT)
    DUP (SEE-MOV-IMM) (SEE-XT.)
    28 + ;

\ --- Call / string / lit / branch steps ------------------------------------
DOC" (SEE-SLIT) ( ip -- ip' ) after blr _stc_slit: print S-quote string"
: (SEE-SLIT)
    {: ip | u -- :}
    ip @ TO u
    83 EMIT 34 EMIT SPACE
    ip 8 + u TYPE  34 EMIT SPACE
    ip 8 + u + (SEE-ALIGN8) ;

DOC" (SEE-CSTR) ( ip -- ip' ) after blr _stc_cstr"
: (SEE-CSTR)
    {: ip | u -- :}
    ip C@ TO u
    67 EMIT 34 EMIT SPACE
    ip 1+ u TYPE  34 EMIT SPACE
    ip u + 1+ (SEE-ALIGN8) ;

DOC" (SEE-CALL) ( ip -- ip' ) adrp/add/blr at ip"
: (SEE-CALL)
    {: ip | tgt xt -- :}
    ip (SEE-ADRP-TARGET) TO tgt
    tgt SLIT-ADDR = IF  ip 12 + (SEE-SLIT) EXIT  THEN
    tgt CSTR-ADDR = IF  ip 12 + (SEE-CSTR) EXIT  THEN
    tgt DO-RT-ADDR = IF  S" DO" (SEE-CF.) ip 12 + EXIT  THEN
    tgt QDO-RT-ADDR = IF  S" ?DO" (SEE-CF.) ip 12 + EXIT  THEN
    tgt LOOP-RT-ADDR = IF
        S" LOOP" (SEE-CF.) TRUE (SEE-SKIP-CBZ) !
        ip 12 + EXIT THEN
    tgt PLOOP-RT-ADDR = IF
        S" +LOOP" (SEE-CF.) TRUE (SEE-SKIP-CBZ) !
        ip 12 + EXIT THEN
    tgt DOES-RT-ADDR = IF  S" DOES>" (SEE-CF.) ip 12 + EXIT  THEN
    tgt FRAME-EXIT-ADDR = IF  ip 12 + EXIT  THEN
    \ create-xt alone (mov already consumed) or lookback if entered at adrp
    tgt CREATE-XT-ADDR = IF
        ip 16 - DUP L@ (SEE-MOVMSK) AND (SEE-MOVZ0) = IF
            (SEE-MOV-IMM) (SEE-XT.)
        ELSE DROP S" (create)" (SEE-TOK) THEN
        ip 12 + EXIT THEN
    tgt CODE>XT TO xt
    xt IF xt (SEE-NAME.) ELSE S" (???)" (SEE-TOK) THEN
    ip 12 + ;

DOC" (SEE-AT-LABEL) ( ip -- ) print THEN if ip is a recorded target"
: (SEE-AT-LABEL)
    (SEE-TFIND) 1 = IF S" THEN" (SEE-CF.) THEN ;

VARIABLE (SEE-DONE)   \ set when epilogue seen

DOC" (SEE-STEP) ( ip -- ip' ) decompile one pattern; epilogue prints ;"
: (SEE-STEP)
    {: ip | insn tgt -- :}
    ip L@ TO insn
    \ 1. colon epilogue: mid-body EXIT vs final ;
    \ EXIT and ; both plant ldr x30 / ret; only stop when nothing remains to end.
    insn (SEE-EPI-LDR) = IF
        ip 4 + L@ (SEE-RET) = IF
            ip 8 + (SEE-END-A) @ U< IF
                S" EXIT" (SEE-TOK)
            ELSE
                59 EMIT CR
                FALSE (SEE-NEED-CR) !
                TRUE (SEE-DONE) !
            THEN
            ip 8 + EXIT THEN THEN
    \ 2. adrp/add/blr x16
    insn (SEE-ADRP?) IF
        ip 4 + L@ (SEE-ADD16?) IF
            ip 8 + L@ (SEE-BLR16) = IF
                ip (SEE-CALL) EXIT THEN THEN THEN
    \ 3. movz/movk×4: lit ( + DPUSH) or VARIABLE/CONSTANT/DOES> ( + create-xt)
    insn (SEE-MOVMSK) AND (SEE-MOVZ0) = IF
        ip 16 + L@ (SEE-DPUSH0) = IF
            S" lit" (SEE-TOK) ip (SEE-MOV-IMM) .
            ip 20 + EXIT THEN
        ip (SEE-AT-CREATE?) IF
            ip (SEE-CREATE-XT) EXIT THEN THEN
    \ 4. DPOP + CBZ → IF (forward) or UNTIL (back)
    insn (SEE-DPOP0) = IF
        ip 4 + L@ DUP TO insn
        insn (SEE-CBMSK) AND (SEE-CBZ0) = IF
            ip 4 + insn (SEE-BR-TGT) TO tgt
            ip tgt U< IF
                S" IF" (SEE-CF.)
                tgt 1 (SEE-TREC)
            ELSE
                S" UNTIL" (SEE-CF.)
            THEN
            ip 8 + EXIT THEN THEN
    \ 5. CBZ alone (UNTIL / LOOP continue / IF without DPOP)
    insn (SEE-CBMSK) AND (SEE-CBZ0) = IF
        (SEE-SKIP-CBZ) @ IF
            FALSE (SEE-SKIP-CBZ) !
            ip 4 + EXIT THEN
        ip insn (SEE-BR-TGT) TO tgt
        tgt ip U< IF
            S" UNTIL" (SEE-CF.)
        ELSE
            S" IF" (SEE-CF.)
            tgt 1 (SEE-TREC)
        THEN
        ip 4 + EXIT THEN
    \ 6. B
    insn (SEE-BMSK) AND (SEE-B) = IF
        ip insn (SEE-BR-TGT) TO tgt
        tgt ip U< IF
            S" AGAIN" (SEE-CF.)
        ELSE
            \ IF's cbz lands on the insn after this B; drop that THEN marker
            ip 4 + (SEE-TCLR1)
            S" ELSE" (SEE-CF.)
            tgt 1 (SEE-TREC)
        THEN
        ip 4 + EXIT THEN
    \ 7. CBNZ (?DO skip) — quiet
    insn (SEE-CBMSK) AND (SEE-CBNZ0) = IF  ip 4 + EXIT THEN
    \ 8. unknown
    S" hex:" TYPE insn (SEE-HEX.) SPACE
    ip 4 + ;

DOC" (SEE-BODY) ( xt -- ) decompile STC colon body through ;"
: (SEE-BODY)
    {: xt | ip end -- :}
    (SEE-TCLR)  FALSE (SEE-DONE) !  FALSE (SEE-NEED-CR) !
    xt @ TO ip
    xt (SEE-END) TO end
    end ip U< IF HERE TO end THEN
    ip L@ (SEE-PROLOG) = IF ip 4 + TO ip THEN
    BEGIN
        (SEE-DONE) @ 0=  ip end U< AND
    WHILE
        ip (SEE-AT-LABEL)
        ip (SEE-STEP) TO ip
    REPEAT
    (SEE-DONE) @ 0= IF CR THEN ;

DOC" SEE ( 'name' -- ) header + STC body decompile (or (code))"
: SEE
    ' (SEE-HDR) DUP (SEE-WHERE)
    DUP XT? 0= IF DROP S" (code)" TYPE CR EXIT THEN
    DUP @ OVER 8 + = IF (SEE-BODY)
    ELSE DROP S" (code)" TYPE CR THEN ;

DOC" LOCATE ( 'name' -- ) print source leaf:line"
: LOCATE
    ' DUP VIEW-FILE# 0= IF DROP S" no source location" TYPE CR ELSE (SEE-WHERE) THEN ;

DOC" HELP ( 'name' -- ) synonym of SEE"
: HELP  SEE ;

\ --- SYSVOC: hide SEE / support helpers from FORTH (64Forth vocsys) ---------
DOC" VOC-WID ( vocab-xt -- wid ) body of a VOCABULARY child"
: VOC-WID  2 CELLS + ;

DOC" (WL-UNLINK#) ( xt wid -- thread ) unlink xt from wid; -1 if missing"
: (WL-UNLINK#)
    {: xt wid | slot pred -- :}
    DICT-THREADS 0 DO
        wid I CELLS + TO slot
        BEGIN slot @ DUP TO pred WHILE
            pred xt = IF
                pred >LINK @ slot !
                I UNLOOP EXIT
            THEN
            pred >LINK TO slot
        REPEAT DROP
    LOOP
    -1 ;

DOC" (WL-LINK#) ( xt wid thread -- ) link xt onto wid thread"
: (WL-LINK#)
    {: xt wid th | head -- :}
    th 0< IF S" XT>WL: not in source wid" TYPE CR ABORT THEN
    wid th CELLS + TO head
    head @ xt >LINK !
    xt head ! ;

DOC" XT>WL-FROM ( xt from-wid to-wid -- ) move xt between wordlists"
: XT>WL-FROM
    {: xt from to -- :}
    xt from (WL-UNLINK#)
    xt to ROT (WL-LINK#) ;

DOC" XT>WL ( xt to-wid -- ) move xt from FORTH-WORDLIST"
: XT>WL
    {: xt to -- :}
    xt FORTH-WORDLIST to XT>WL-FROM ;

DOC" FORTH>WL ( c-addr u wid -- ) move named FORTH word to wid (no-op if missing)"
: FORTH>WL
    >R 2DUP FORTH-WORDLIST SEARCH-WORDLIST
    DUP 0= IF DROP 2DROP R> DROP EXIT THEN
    DROP >R 2DROP R> R> XT>WL ;

DOC" FORTH>VOC ( c-addr u vocab-xt -- ) move named FORTH word into vocabulary"
: FORTH>VOC  VOC-WID FORTH>WL ;

DOC" SYSVOC ( -- ) vocabulary for system / support words; execute to ALSO it"
VOCABULARY SYSVOC

DOC" FORTH>SYSVOC ( c-addr u -- ) move named FORTH word into SYSVOC"
: FORTH>SYSVOC  ['] SYSVOC FORTH>VOC ;

\ Rechain SEE internals (compiled calls keep working; WORDS stays clean)
S" VIEW-LEAF-A" FORTH>SYSVOC
S" VIEW-LEAF-U" FORTH>SYSVOC
S" (VIEW-BASENAME)" FORTH>SYSVOC
S" (SEE-WHERE)" FORTH>SYSVOC
S" (SEE-HDR)" FORTH>SYSVOC
S" (SEE-CODE0)" FORTH>SYSVOC
S" (SEE-END-A)" FORTH>SYSVOC
S" (SEE-NEAR)" FORTH>SYSVOC
S" (SEE-END)" FORTH>SYSVOC
S" (SEE-TMAX)" FORTH>SYSVOC
S" (SEE-TADDR)" FORTH>SYSVOC
S" (SEE-TKIND)" FORTH>SYSVOC
S" (SEE-T#)" FORTH>SYSVOC
S" (SEE-SKIP-CBZ)" FORTH>SYSVOC
S" (SEE-TCLR)" FORTH>SYSVOC
S" (SEE-TREC)" FORTH>SYSVOC
S" (SEE-TFIND)" FORTH>SYSVOC
S" (SEE-TCLR1)" FORTH>SYSVOC
S" (SEE-IND)" FORTH>SYSVOC
S" (SEE-NEED-CR)" FORTH>SYSVOC
S" (SEE-TOK)" FORTH>SYSVOC
S" (SEE-CF.)" FORTH>SYSVOC
S" (SEE-PROLOG)" FORTH>SYSVOC
S" (SEE-EPI-LDR)" FORTH>SYSVOC
S" (SEE-RET)" FORTH>SYSVOC
S" (SEE-DPOP0)" FORTH>SYSVOC
S" (SEE-DPUSH0)" FORTH>SYSVOC
S" (SEE-BLR16)" FORTH>SYSVOC
S" (SEE-ADRP16M)" FORTH>SYSVOC
S" (SEE-ADRP16A)" FORTH>SYSVOC
S" (SEE-ADD16M)" FORTH>SYSVOC
S" (SEE-ADD16A)" FORTH>SYSVOC
S" (SEE-MOVZ0)" FORTH>SYSVOC
S" (SEE-MOVK16)" FORTH>SYSVOC
S" (SEE-MOVK32)" FORTH>SYSVOC
S" (SEE-MOVK48)" FORTH>SYSVOC
S" (SEE-MOVMSK)" FORTH>SYSVOC
S" (SEE-CBZ0)" FORTH>SYSVOC
S" (SEE-CBNZ0)" FORTH>SYSVOC
S" (SEE-CBMSK)" FORTH>SYSVOC
S" (SEE-B)" FORTH>SYSVOC
S" (SEE-BMSK)" FORTH>SYSVOC
S" (SEE-ADRP?)" FORTH>SYSVOC
S" (SEE-ADD16?)" FORTH>SYSVOC
S" (SEE-SEX21)" FORTH>SYSVOC
S" (SEE-ADRP-TARGET)" FORTH>SYSVOC
S" (SEE-MOV-IMM)" FORTH>SYSVOC
S" (SEE-BR-TGT)" FORTH>SYSVOC
S" (SEE-HEX.)" FORTH>SYSVOC
S" (SEE-NAME.)" FORTH>SYSVOC
S" (SEE-XT.)" FORTH>SYSVOC
S" (SEE-ALIGN8)" FORTH>SYSVOC
S" (SEE-AT-CREATE?)" FORTH>SYSVOC
S" (SEE-CREATE-XT)" FORTH>SYSVOC
S" (SEE-SLIT)" FORTH>SYSVOC
S" (SEE-CSTR)" FORTH>SYSVOC
S" (SEE-CALL)" FORTH>SYSVOC
S" (SEE-AT-LABEL)" FORTH>SYSVOC
S" (SEE-DONE)" FORTH>SYSVOC
S" (SEE-STEP)" FORTH>SYSVOC
S" (SEE-BODY)" FORTH>SYSVOC

ONLY FORTH DEFINITIONS

\ --- Timing (MS@ / MS are CODE; ELAPSED prints HH:MM:SS.mmm) -----------------
DOC" .2DIG ( n -- ) print n as 2 decimal digits"
: .2DIG  ( n -- )  10 /MOD 48 + EMIT 48 + EMIT ;
DOC" .3DIG ( n -- ) print n as 3 decimal digits"
: .3DIG  ( n -- )  100 /MOD 48 + EMIT .2DIG ;
DOC" .ELAPSED ( ms -- ) print ms as HH:MM:SS.mmm"
: .ELAPSED  ( ms -- )
    BASE @ >R DECIMAL
    1000 /MOD SWAP >R 60 /MOD SWAP >R 60 /MOD SWAP >R
    DUP 10 < IF 48 EMIT THEN 0 <# #S #> TYPE
    58 EMIT R> .2DIG 58 EMIT R> .2DIG 46 EMIT R> .3DIG
    R> BASE ! ;
DOC" ELAPSED ( 'name' -- ) run name once and print elapsed time"
: ELAPSED  ( "name" -- )  ' MS@ >R EXECUTE MS@ R> - CR .ELAPSED CR ;

\ --- Flags for FILE-ECHO etc. -----------------------------------------------
DOC" ON ( addr -- ) store true (-1) at addr"
: ON   -1 SWAP ! ;
DOC" OFF ( addr -- ) store 0 at addr"
: OFF   0 SWAP ! ;

\ --- Search-Order display helpers (64Forth lineage; DICT_THREADS=1) ----------
DOC" U.R ( u n -- ) print u right-justified in n field"
: U.R  >R 0 <# #S #> R> OVER - 0 MAX SPACES TYPE ;
DOC" .R ( n n -- ) print n right-justified in field (no trailing space)"
: .R  >R DUP ABS 0 <# #S ROT SIGN #> R> OVER - 0 MAX SPACES TYPE ;
DOC" (THREAD-DEPTH) ( head -- n ) count words in one hash chain"
: (THREAD-DEPTH)  0 SWAP BEGIN DUP WHILE SWAP 1+ SWAP 2 CELLS - @ REPEAT DROP ;
DOC" (WID.THREADS) ( wid -- ) print thread depths for wid"
: (WID.THREADS)  DICT-THREADS 0 DO DUP I CELLS + @ (THREAD-DEPTH) 5 .R LOOP DROP ;
DOC" .THREADS ( -- ) print CONTEXT wordlist chain depths"
: .THREADS  (CONTEXT) (WID.THREADS) CR ;
DOC" (TYPE-FIELD) ( c-addr u n -- ) type string left-justified in field n"
: (TYPE-FIELD)  >R 2DUP TYPE NIP R> SWAP - 0 MAX SPACES ;
DOC" (IS-VOCAB) ( nt -- flag ) true if nt was defined by VOCABULARY"
: (IS-VOCAB)  CELL+ @ ['] FP CELL+ @ = ;
DOC" (SHOW-VOCAB) ( nt -- true ) print vocabulary name and thread depths"
: (SHOW-VOCAB)  DUP (IS-VOCAB) IF DUP NAME>STRING 16 (TYPE-FIELD) 2 CELLS + (WID.THREADS) CR ELSE DROP THEN TRUE ;
VARIABLE (VW-T)  VARIABLE (VW-F)
DOC" (CHK-VOC-WID) ( nt -- cont ) TRAVERSE helper for (VOCAB-WID?)"
: (CHK-VOC-WID)  DUP (IS-VOCAB) IF 2 CELLS + (VW-T) @ = IF -1 (VW-F) ! FALSE ELSE TRUE THEN ELSE DROP TRUE THEN ;
DOC" (VOCAB-WID?) ( wid -- flag ) true if wid is a named VOCABULARY head array"
: (VOCAB-WID?)  (VW-T) ! 0 (VW-F) ! ['] (CHK-VOC-WID) FORTH-WORDLIST TRAVERSE-WORDLIST (VW-F) @ ;
DOC" (SHOW-BARE-WL) ( wid -- ) print one non-named wordlist from the registry"
: (SHOW-BARE-WL)
  DUP FORTH-WORDLIST = IF DROP EXIT THEN
  DUP (VOCAB-WID?) IF DROP EXIT THEN
  S" (wordlist)" 16 (TYPE-FIELD) (WID.THREADS) CR ;
DOC" (SHOW-WL-REG) ( -- ) print bare WORDLIST entries not already named"
: (SHOW-WL-REG)  WORDLISTS 0 ?DO DUP I CELLS + @ (SHOW-BARE-WL) LOOP DROP ;
DOC" .VOCABULARIES ( -- ) list FORTH, VOCABULARY lists, and bare WORDLISTs"
: .VOCABULARIES
  S" FORTH" 16 (TYPE-FIELD) FORTH-WORDLIST (WID.THREADS) CR
  ['] (SHOW-VOCAB) FORTH-WORDLIST TRAVERSE-WORDLIST (SHOW-WL-REG) ;
DOC" .WORDLISTS ( -- ) synonym of .VOCABULARIES"
: .WORDLISTS  .VOCABULARIES ;

\ --- Unsigned compare + DUMP (from 64Forth) ---------------------------------
\ U< WITHIN are CODE (STC dual-tail).

DOC" .H2 ( b -- ) print byte as 2 hex digits"
: .H2  255 AND 0 <# # # #> TYPE ;
DOC" .HA ( addr -- ) print address as 16 hex digits"
: .HA  0 <# # # # # # # # # # # # # # # # # #> TYPE ;
DOC" DUMP-END ( -- addr ) variable end of DUMP range"
VARIABLE DUMP-END
DOC" DUMP-LINE ( addr -- addr' ) dump one line"
: DUMP-LINE
    DUP .HA SPACE SPACE DUP
    16 0 DO
        DUP I + DUMP-END @ U< IF DUP I + C@ .H2 SPACE ELSE SPACE SPACE SPACE THEN
    LOOP
    SPACE SPACE
    16 0 DO
        DUP I + DUMP-END @ U< IF
            DUP I + C@ DUP BL 127 WITHIN 0= IF DROP BL THEN EMIT
        ELSE BL EMIT THEN
    LOOP
    DROP 16 + ;
DOC" DUMP ( addr u -- ) hex dump u bytes from addr (16 per line, ASCII gutter)"
: DUMP
    BASE @ >R HEX OVER + DUMP-END !
    BEGIN DUP DUMP-END @ U< WHILE CR DUMP-LINE REPEAT
    DROP CR R> BASE ! ;

\\ Don't want to load smoke tests for now

\ --- Smoke tests ------------------------------------------------------------
: SQUARE  DUP * ;
: TEST    5 SQUARE . CR ;

\ S" hi" TYPE CR
\ TEST
{
