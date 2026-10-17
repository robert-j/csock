(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * The subset of the "real" Bits that UTests, Utils and Ticker need.
 *)

unit Bits;

interface

{#region Types}

type
  { Pointers of fundamental types }
  PString = ^String;

  { Pointer cracker }
  PtrRec = record
    Ofs, Seg: Word;
  end;

  { Arrays of fundamental types, compatible with Borland's Objects unit
    and Delphi's SysUtils unit. }
  TByteArray = array[0..32767] of Byte;
  TCharArray = array[0..32767] of Char;

  { Pointers to arrays of fundamental types }
  PByteArray = ^TByteArray;

  { Generic procedure }
  TProcedure = procedure;

  { Like stdint.h. Use these to define records that must have the same
    layout on all architectures. }
  UInt32  = Longint;
  IntPtr  = Longint;

{#endregion}

{#region Inlines}

(*
 * Returns the max value of the specified 2 integers.
 *)
function IntMax(A, B: Integer): Integer;
  inline(
    $58/      { pop  ax     }
    $5B/      { pop  bx     }
    $3B/$C3/  { cmp  ax, bx }
    $7F/$01/  { jg   +1     }
    $93       { xchg ax, bx }
  );

(*
 * 32 bit Little endian <-> Big endian conversions.
 * Named after BSD's <arpa/inet.h functions.
 *)
function htonl(Value: UInt32): UInt32;
  inline(
    $5a/$58/  { pop dx; pop ax }
    $86/$e0/  { xchg ah, al    }
    $86/$f2   { xcgh dh, dl    }
  );

(*
 * 32 bit Little endian <-> Big endian conversions.
 * Named after BSD's <arpa/inet.h functions.
 *)
function ntohl(Value: UInt32): UInt32;
  inline(
    $5a/$58/  { pop dx; pop ax }
    $86/$e0/  { xchg ah, al    }
    $86/$f2   { xcgh dh, dl    }
  );

(*
 * Disables interrupts and saves the interrupt mask.
 * Must be used pairwise with EndDisableInterrupts.
 *)
procedure BeginDisableInterrupts;
  inline(
    $9c/        { pushf }
    $fa         { cli }
  );

(*
 * Restores the interrupt mask saved by BeginDisableInterrupts.
 * Must be used pairwise with BeginDisableInterrupts.
 *)
procedure EndDisableInterrupts;
  inline(
    $9d         { popf }
  );

(*
 * Invokes the debugger.
 *)
procedure DebugBreak;
  inline(
    $cc         { int 3 }
  );

(*
 * Gets the address of the call site of the routine that invokes this inline.
 *
 * The routine calling this inline must be declared 'far'.
 *)
function GetCallerAddr: Pointer;
  inline(
    $8b/$56/$04/    { mov dx, [bp+4] }
    $8b/$46/$02     { mov ax, [bp+2] }
  );

{#endregion}

{#region Delegates}

(*
 * Delegates
 *
 * How to use them:
 *
 * 1. create a TDelegate from a nested far proc with MakeDelegate
 * 2. pass it to a function that processes such delegates
 * 3. from within this function, invoke the delegate with
 *    InvokeDelegate_<args>(Delegate, Args, ...);
 *
 * Notes:
 *
 * We're abusing a Real to implement TDelegate & InvokeDelegate. Real comes
 * handy because
 *
 * - it is 3 words long, exactly what we need to implement delegates
 *   to nested funcs
 *
 * - it can be returned from functions, which makes the Delegate APIs
 *   more user-friendly.
 *)

type
  TDelegate = Real;

(*
 * Creates a delegate for the specified nested far proc. Must
 * be invoked by the function that embeds the nested far proc.
 *)
function MakeDelegate(Func: Pointer): TDelegate;
  inline(
    $58/            { pop   ax        ; ax = Ofs(Func) }
    $5b/            { pop   bx        ; bx = Seg(Func) }
    $89/$ea         { mov   dx, bp    ; this stack frame }
  );

(*
 * The inline code performs:
 *      push    Del.Frame
 *      call    Del.Func
 *      pop     Del
 *
 * This is equivalent to:
 *      call    Del.Func(Del.Frame)
 *
 * Result is automatically in dx:ax as returned by Del.Func.
 *)
function InvokeDelegate_Void(const Del: TDelegate): IntPtr;
  inline($89/$e3/$36/$ff/$77/$04/$36/$ff/$5f/$00/$83/$c4/$06);

{#endregion}

{#region SetJump}

(*
 * Environment of SetJmp, LongJmp.
 *
 * Don't change this record's layout unless SetJmp, LongJmp are adjusted, too.
 *)
type
  TJmpEnv = record
    bp: Word;             { offs 0: saved BP reg}
    sp: Word;             { offs 2: saved SP reg }
    ss: Word;             { offs 4: saved SS reg }
    ip: Word;             { offs 6: IP of return location }
    cs: Word;             { offs 8: CS of return location }
  end;

(*
 * Like setjmp(3), the C runtime library function.
 * Like Catch(), the Windows 3.1 API.
 *)
function SetJmp(var Env: TJmpEnv): Word;
  inline(
    $5f/                  { pop di           ; di = Ofs(Env) }
    $07/                  { pop es           ; es = Seg(Env) }
    $26/$89/$2d/          { mov es:[di],bp   ; save bp }
    $26/$89/$65/$02/      { mov es:[di+2],sp ; save sp }
    $26/$8c/$55/$04/      { mov es:[di+4],ss ; save ss }
    $e8/$00/$00/          { call near +1     ; trick to push IP onto stack }
    $58/                  { pop ax           ; pop IP into ax }
                          { begin: }
    $05/$0e/$00/          { add ax, 0eh      ; advance IP to "end:", len = end - begin = 0eh }
    $26/$89/$45/$06/      { mov es:[di+6],ax ; save into Env.ip }
    $26/$8c/$4d/$08/      { mov es:[di+8],cs ; save into Env.cs }
    $31/$c0               { xor ax, ax       ; return 0 }
  );                      { end: }

(*
 * Like longjmp(3), the C runtime library function.
 * Like Throw(), the Windows 3.1 API, but Throw() does not ensure that
 * RetVal <> 0.
 *)
procedure LongJmp(const Env: TJmpEnv; RetVal: Word);
  inline(
    $58/                  { pop ax            ; ax = RetVal }
    $83/$f8/$01/          { cmp ax, 1         ; ensure RetVal is never 0 }
    $83/$d0/$00/          { adc ax, 0         ; }
    $5f/                  { pop di            ; di = Ofs(Env) }
    $07/                  { pop es            ; es = Seg(Env) }
    $26/$8b/$2d/          { mov bp,es:[di]    ; bp = Env.bp }
    $26/$8e/$55/$04/      { mov ss,es:[di+4]  ; ss = Env.ss }
    $26/$8b/$65/$02/      { mov sp,es:[di+2]  ; sp = Env.sp }
    $26/$ff/$6d/$06       { jmp far es:[di+6] ; jmp Env.cs:Env.ip }
  );

{#endregion}

{#region Stack}

(*
 * Pushes a 32-bit value onto the stack.
 * Use with caution and pairwise with StackPop32!
 *)
procedure StackPush32(Value: Longint);
  inline(
    $90     { nop  -> leave Value on the stack }
  );

(*
 * Pops a previously pushed long from the stack.
 * Use with caution and pairwise with StackPush32!
 *)
function StackPop32: Longint;
  inline(
    $58/      { pop ax }
    $5a       { pop dx }
  );

(*
 * Pushes a 16-bit value onto the stack.
 * Use with caution and pairwise with StackPop16!
 *)
procedure StackPush16(Value: Word);
  inline(
    $90     { nop  -> leave Value on the stack }
  );

(*
 * Pops a previously pushed word from the stack.
 * Use with caution and pairwise with StackPush16!
 *)
function StackPop16: Word;
  inline(
    $58     { pop ax }
  );

{#endregion}

{#region Mapping}

(*
 * Returns the logical (as in the MAP file) address of the
 * specified physical address.
 *
 * When used this way (from inside a far proc):
 *
 * GetLogicalAddr(Bits.GetCallerAddr)
 *
 * the function returns the logical address of the
 * call site of the function which invoked GetLogicalAddr.
 *
 * Note that in Protected Mode, when the selector is $ffff
 * then GetLogicalAddr has failed to return a valid address.
 *)
function GetLogicalAddr(PhysAddr: Pointer): Pointer;

{#endregion}

implementation

{#region Mapping}

(*
 * Inspired by the Borland RTL's exit code.
 *
 * The RTL is printing the error location at exit, so I could deduce
 * from its code how the physical/logical mapping is performed.
 *)
function GetLogicalAddr(PhysAddr: Pointer): Pointer;
begin
{$ifdef DPMI}
  asm
    mov   ax, PhysAddr.word[2]
    verr  ax                      { valid selector? }
    je    @1
    mov   PhysAddr.word[2], $ffff { no, map to $ffff }
    jmp   @2                      { ... and leave }
  @1:
    mov  ax, PhysAddr.word[2]     { selector is valid }
    mov  es, ax
    mov  ax, word ptr es:0        { get logical address from selector }
    mov  PhysAddr.word[2], ax     { ... and store it}
  @2:
  end;
{$endif}

{$ifdef MSDOS}
  { it's simple: subtract (PrefixSeg + (SizeOf(PSP) = $10)) from segment }
  Dec(PtrRec(PhysAddr).Seg, PrefixSeg + $10);
{$endif}

  GetLogicalAddr := PhysAddr;
end;

{#endregion}

end.
