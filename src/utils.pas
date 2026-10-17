(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * The subset of the "real" Utils that UTests and ucsock need. Pure Pascal.
 *)

unit Utils;

interface

uses
  Bits;

{#region Number to string conversions}

type
  TWordStr = String[4];
  TPtrStr  = String[9];

function WordToHex(W: Word): TWordStr;
function PtrToHex(P: Pointer): TPtrStr;
function IntToStr(L: Longint): String;
function IntToHex(L: Longint; Width: Integer): String;

{#endregion}

{#region String to number conversions}

function TryCStrToInt(S: PChar; var Value: Longint): Boolean;
function TryStrToInt(const S: String; var Value: Longint): Boolean;

{#endregion}

{#region Case conversion, string and mem-based}

function UpperStr(const S: String): String;
procedure LowerStrVar(var S: String);

{#endregion}

{#region String routines}

function MakeString(Len: Byte; C: Char): String;

function IpAddrToStr(IpAddr: Longint): String;
function IpAddrFromString(const S: String): Longint;

{#endregion}

{#region String Pos-like routines}

function RPos(const SubStr: String; const Target: String): Byte;

{#endregion}

{#region String to string conversions and safety}

function StrToPas(Str: PChar): String;
function StrPasDef(Str: PChar; const Def: String): String;

{#endregion}

{#region String comparison and matching}

function StrMatchPattern(const Source, Pattern: String; Invariant: Boolean): Boolean;
function StrIMatchPattern(const Source, Pattern: String): Boolean;

{#endregion}

{#region Routines on generic memory}

function FindFirstNotOf(const Data; DataLen: Word; C: Char): Word;

{#endregion}

{#region Path functions, string-based, w/out file system interaction}

function PathRemoveBackSlash(const Path: String): String;
function PathChangeExt(const Path, Ext: String): String;
function PathGetBaseName(const Path: String): String;
function PathGetDirName(const Path: String): String;

{#endregion}

{#region Exit handling}

procedure AddExitHandler(Proc: TProcedure);

{#endregion}

implementation

{#region Number to string conversions}

const
  Dig16: array[0..15] of Char = '0123456789abcdef';

(*
 * Optimized for stack space.
 *)
function WordToHex(w: Word): TWordStr;
begin
  WordToHex[0] := #4;
  WordToHex[1] := Dig16[hi(w) shr 4];
  WordToHex[2] := Dig16[hi(w) and $0F];
  WordToHex[3] := Dig16[lo(w) shr 4];
  WordToHex[4] := Dig16[lo(w) and $0F];
end;

(*
 * Optimized for stack space.
 *)
function PtrToHex(P: Pointer): TPtrStr;
begin
  PtrToHex[0] := #9;
  PtrToHex[1] := Dig16[Hi(PtrRec(P).Seg) shr 4];
  PtrToHex[2] := Dig16[Hi(PtrRec(P).Seg) and $0F];
  PtrToHex[3] := Dig16[Lo(PtrRec(P).Seg) shr 4];
  PtrToHex[4] := Dig16[Lo(PtrRec(P).Seg) and $0F];
  PtrToHex[5] := ':';
  PtrToHex[6] := Dig16[Hi(PtrRec(P).Ofs) shr 4];
  PtrToHex[7] := Dig16[Hi(PtrRec(P).Ofs) and $0F];
  PtrToHex[8] := Dig16[Lo(PtrRec(P).Ofs) shr 4];
  PtrToHex[9] := Dig16[Lo(PtrRec(P).Ofs) and $0F];
end;

(*
 * Uses System.Str internally. Not padding whatsoever. Fast.
 *)
function IntToStr(L: Longint): String;
var
  PResult: PString;
begin
  { PResult := @Result }
  asm
    les   di, @Result
    mov   word ptr PResult, di
    mov   word ptr PResult + 2, es
  end;
  Str(L, PResult^);
end;

(*
 * Lower case hex digits, zero-padded to at least @Width digits, like
 * printf's "%.*x".
 *)
function IntToHex(L: Longint; Width: Integer): String;
var
  S: String;
begin
  S := '';
  repeat
    S := Dig16[Word(L) and $0F] + S;
    L := L shr 4;
  until L = 0;
  while (Length(S) < Width) and (Length(S) < 255) do
    S := '0' + S;
  IntToHex := S;
end;

{#endregion}

{#region StrToInt }

(*
 * TryStrToInt for zero-terminated strings. Unlike System.Val, we bail out
 * when S is nil.
 *
 * Uses System.Val only, so '$' is the only radix specifier.
 *)
function TryCStrToInt(S: PChar; var Value: Longint): Boolean;
var
  Err: Integer;
begin
  if S = nil then
  begin
    TryCStrToInt := false;
    exit;
  end;

  Val(S, Value, Err);
  TryCStrToInt := Err = 0;
end;

function TryStrToInt(const S: String; var Value: Longint): Boolean;
var
  Err: Integer;
begin
  Val(S, Value, Err);
  TryStrToInt := Err = 0;
end;

{#endregion}

{#region Upper/Lower}

(*
 *
 *)
function UpperStr(const S: String): String; assembler;
asm
  push    ds
  lds     si, s
  les     di, @result
  cld
  lodsb
  stosb
  mov     cl, al
  xor     ch, ch
  jcxz    @3
@1:
  lodsb
  cmp     al, 'a'
  jb      @2
  cmp     al, 'z'
  ja      @2
  sub     al, 20h
@2:
  stosb
  loop    @1
@3:
  pop     ds
end;

(*
 *
 *)
procedure LowerMem(var Data; Len: Word); assembler;
asm
  push    ds
  lds     si, Data
  les     di, Data
  cld
  mov     cx, Len
  jcxz    @3
@1:
  lodsb
  cmp     al, 'A'
  jb      @2
  cmp     al, 'Z'
  ja      @2
  add     al, 20h
@2:
  stosb
  loop    @1
@3:
  pop     ds
end;

(*
 *
 *)
procedure LowerStrVar(var S: String);
begin
  LowerMem(S[1], Length(S));
end;

{#endregion}

{#region IP address conversions}

(*
 * Ported from xfsng/xsock/wsex.cpp:inet_ntoa.
 *
 * Assumes that Buf is array[0..16] of Char.
 * Assumes that IpAddr is in net byte order (BE).
 *
 * Returns the length of the IP address in chars.
 *)
function IpAddrToPChar(IpAddr: Longint; Buf: PChar): Byte;
var
  I: Integer;
  A: Integer;
  Len: Byte;
begin
  Len := 0;
  for I := 0 to 3 do
  begin
    A := (IpAddr shr (8 * i)) and $ff;
    if A >= 100 then
    begin
      Buf^ := Chr(A div 100 + Ord('0'));
      Inc(Buf);
      Inc(Len);
    end;
    if A >= 10 then
    begin
      Buf^ := Chr(A mod 100 div 10 + Ord('0'));
      Inc(Buf);
      Inc(Len);
    end;
    Buf^ := Chr(a mod 10 + Ord('0'));
    Inc(Buf);
    Inc(Len);
    if i < 3 then
    begin
      Buf^ := '.';
      Inc(Buf);
      Inc(Len);
    end;
  end;
  Buf^ := #0;
  IpAddrToPChar := Len;
end;

(*
 * Ported from xfsng/xsock/wsexvxd.cpp:inet_addr.
 *
 * Returns Addr in net byte order (BE).
 *)
function IpAddrFromStringImpl(const S: String; var Addr: Longint): Boolean;
var
  B: Word;
  Count: Byte;
  Shift: Word;
  Buf, BufEnd: PChar;
begin
  IpAddrFromStringImpl := false;
  Addr := 0;
  Count := 0;
  Shift := 0;
  Buf := @S[1];
  BufEnd := @S[Length(S)];
  Inc(BufEnd);
  while (Buf <> BufEnd) do
  begin
    B := 0;
    while ((Buf^ <> '.') and (Buf <> BufEnd)) do
    begin
      if (Buf^ < '0') or (Buf^ > '9') then exit;
      B := B * 10 + (Ord(Buf^) - Ord('0'));
      Inc(Buf);
    end;

    { validate byte }
    if B > 255 then exit;

    { accumulate }
    Addr := Addr + (Longint(B) shl Shift);
    Inc(Shift, 8);

    Inc(Count);

    { check EOS }
    if Buf = BufEnd then break;
    Inc(Buf);
  end;
  { we expect that 4 bytes were decoded }
  IpAddrFromStringImpl := Count = 4;
end;

(*
 *
 *)
function IpAddrToStr(IpAddr: Longint): String;
var
  PResult: PString;
begin
  { PResult := @Result }
  asm
    les   di, @Result
    mov   word ptr PResult, di
    mov   word ptr PResult + 2, es
  end;
  { decode into PResult }
  PResult^[0] := Char(IpAddrToPChar(htonl(IpAddr), @PResult^[1]));
end;

(*
 *
 *)
function IpAddrFromString(const S: String): Longint;
var
  Addr: Longint;
begin
  if IpAddrFromStringImpl(S, Addr) then
    IpAddrFromString := ntohl(Addr)
  else
    IpAddrFromString := -1;
end;

{#endregion}

{#region Pos-like routines}

(*
 * Similar to Pos(), starts searching from the right.
 *)
function RPos(const SubStr: String; const Target: String): Byte;
var
  I: Integer;
begin
  RPos := 0;
  if Length(SubStr) = 0 then exit;

  for I := Length(Target) - Length(SubStr) + 1 downto 1 do
    if Copy(Target, I, Length(SubStr)) = SubStr then
    begin
      RPos := I;
      exit;
    end;
end;

{#endregion}

{#region Misc String routines}

(*
 * Makes a string filled with the specified char.
 *)
function MakeString(Len: Byte; C: Char): String; assembler;
asm
  les   di, @Result
  mov   al, Len       { store Len }
  cld
  stosb
  mov   al, C         { store C, Len times }
  xor   ch, ch
  mov   cl, Len
  repz  stosb
end;

{#endregion}

{#region String<->Str conversions}

(*
 * Bug-fixed version of Strings.StrPas that doesn't overflow
 * the Pascal string when StrLen(Str) > 255.
 *)
function StrToPas(Str: PChar): String; assembler;
asm
  push  ds
  cld
  les   di, Str
  mov   cx, 256
  xor   al, al
  repne scasb
  not   cl
  lds   si, Str
  les   di, @Result
  mov   al, cl
  stosb
  rep   movsb
  pop   ds
end;

(*
 * Like StrPas, returns a default value when Str is nil.
 *)
function StrPasDef(Str: PChar; const Def: String): String;
begin
  if not Assigned(Str) then
    StrPasDef := Def
  else
    StrPasDef := StrToPas(Str);
end;

{#endregion}

{#region Path functions}

(*
 * Stackless
 *)
function PathRemoveBackSlash(const Path: String): String;
var
  Len: Byte;
begin
  Len := Length(Path);
  PathRemoveBackSlash := Path;
  while Path[Len] = '\' do
  begin
    Dec(Len);
    PathRemoveBackSlash[0] := Chr(Len);
  end;
end;

(*
 * Replaces the extension of @Path with @Ext.
 *
 * @Ext must either start with the leading dot of the new extension,
 * or be empty to be able to remove the extension of @Path.
 *
 * PathChangeExt('foo.bar', '')     -> 'foo'
 * PathChangeExt('foo.bar', '.qux') -> 'foo.qux'
 * PathChangeExt('foo.bar', 'qux')  -> 'fooqux'
 * PathChangeExt('foo', '.bar')     -> 'foo.bar'
 *)
function PathChangeExt(const Path, Ext: String): String;
var
  DotPos: Integer;
begin
  DotPos := RPos('.', Path);
  if DotPos > 0 then
  begin
    if RPos('\', Path) < DotPos then
    begin
      PathChangeExt := Copy(Path, 1, DotPos - 1) + Ext;
      exit;
    end;
  end;
  PathChangeExt := Concat(Path, Ext);
end;

(*
 *
 *)
function PathGetBaseName(const Path: String): String;
begin
  PathGetBaseName := Copy(PathRemoveBackSlash(Path),
    RPos('\', PathRemoveBackSlash(Path)) + 1, MaxInt);
end;

(*
 *
 *)
function PathGetDirName(const Path: String): String;
begin
  PathGetDirName := Copy(Path, 1, RPos('\', PathRemoveBackSlash(Path)) - 1);
end;

{#endregion}

{#region Misc string routines}

(*
 * Returns the index of the first character in @Data NOT equal to @C.
 *
 * Returns @DataLen if @Data consists only of @C.
 *)
function FindFirstNotOf(const Data; DataLen: Word; C: Char): Word;
var
  A: TCharArray absolute Data;
  I: Word;
begin
  FindFirstNotOf := DataLen;
  if DataLen = 0 then exit;

  for I := 0 to DataLen - 1 do
    if A[I] <> C then
    begin
      FindFirstNotOf := I;
      break;
    end;
end;

{#endregion}

{#region Pattern matching}

(*
 * The function matches like DOS file name patterns:
 *
 *    'hello'     matches exactly the string 'hello'
 *    'hello*'    matches 'hello' at start of a string
 *    '*hello'    matches 'hello' at the end of a string
 *    '*hello*'   matches 'hello' everywhere
 *    'hello?'    matches 'hello' at start of a string, expects one more char
 *    '*hello*world*'  matches 'hello' followed by zero or more chars, then
 *                'world' followed by zero or more chars
 *    ...
 *
 * Taken from my old digits.pas (from speedy's backup, a dev machine from
 * the 90s) with the RCS header "digits.pas,v 1.6 1993/02/01 23:54:31 lwf Exp".
 * I don't remember if I wrote this state machine myself.
 * The invariant stuff and fixes are from 2023-24.
 *)
function StrMatchPattern(const Source, Pattern: String; Invariant: Boolean): Boolean;
type
  TState = (stLoop, stNoMatch, stMatch);
var
  SLen: Byte absolute Source;
  PLen: Byte absolute Pattern;

  { compares 2 chars while taking Invariant into account. }
  function Compare(A, B: Char): Boolean;
  begin
    if Invariant then
      Compare := UpCase(A) = UpCase(B)
    else
      Compare := A = B;
  end;

  { matches at pos S in Source and pos P in Pattern }
  function Match(S, P: Integer): TState;
  var
    State: TState;
  begin
    State := stLoop;
    repeat
      if (S > SLen) and (P > PLen) then
        State := stMatch
      else if P > PLen then
        State := stNoMatch
      else if Pattern[P] = '*' then
        if P = PLen then
          State := stMatch
        else
          repeat
            State := Match(S, P + 1);
            Inc(S);
          until (State = stMatch) or (S > SLen)
      else if (Pattern[P] <> '?') and (not Compare(Pattern[P], Source[S])) then
        State := stNoMatch
      else
      begin
        Inc(S);
        Inc(P)
      end;
    until State <> stLoop;
    Match := State
  end;

begin
  if PLen = 0 then
     { an empty pattern matches all source strings }
    StrMatchPattern := true
  else
    { start matching at pos (1, 1) }
    StrMatchPattern := (Match(1, 1) = stMatch);
end;

(*
 * Like StrMatchPattern, case invariant.
 *)
function StrIMatchPattern(const Source, Pattern: String): Boolean;
begin
  StrIMatchPattern := StrMatchPattern(Source, Pattern, true);
end;

{#endregion}

{#region Exit procedure handling}

type
  { Idea borrowed from Borland Delphi }
  PExitProcInfo = ^TExitProcInfo;
  TExitProcInfo = record
    Next: PExitProcInfo;
    PrevExitProc: Pointer;
    Proc: TProcedure;
  end;

var
  ExitProcList: PExitProcInfo;

procedure DoExitProc; far;
var
  P: PExitProcInfo;
  Proc: TProcedure;
begin
  P := ExitProcList;
  ExitProcList := P^.Next;
  ExitProc := P^.PrevExitProc;
  Proc := P^.Proc;
  Dispose(P);
  Proc;
end;

(*
 * Adds an exit handler which is processed with the usual ExitProc
 * infrastructure, but it less error-prone: just add a handler with
 * this API and don't deal with ExitProc's scheme anymore.
 *)
procedure AddExitHandler(Proc: TProcedure);
var
  P: PExitProcInfo;
begin
  New(P);
  P^.Next := ExitProcList;
  P^.PrevExitProc := ExitProc;
  P^.Proc := Proc;
  ExitProcList := P;
  ExitProc := @DoExitProc;
end;

{#endregion}

end.
