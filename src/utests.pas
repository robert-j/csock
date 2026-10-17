(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * UTests - Unit Test Framework
 *
 * The subset of the "real" UTests without source locator (MapLib),
 * disassembler, colors, command line, Windows and Delphi support.
 * Environment variables control the runner:
 *
 *   UTESTV=1          verbose output
 *   UTESTP=<pattern>  runs only the test procs matching the DOS-like
 *                     <pattern>, e.g. Loopback*
 *   UTESTR=<n>        runs every test proc <n> times
 *   UTESTB=1          batch mode, see IgnoreBatch
 *   UTESTI3=1         breaks into the debugger before each test proc
 *
 * A failing suite terminates with exit code 1.
 *)

{$F+}

unit UTests;

interface

uses
  Bits;

{#region Runners}

type
  TUnitTest = procedure;

(*
 * The following procs and funcs should by called from the main block of
 * an unit test.
 *)

{ Registers and runs a test procedure. @Name should match the proc's name. }
procedure RunTest(const Name: String; Test: TUnitTest);

{ Registers and runs a test procedure @Count times. }
procedure RunTestMulti(const Name: String; Test: TUnitTest; Count: Word);

{ Registers a proc that is invoked BEFORE every test in the suite.
  Can be unregistered with SetStartUpProc('', nil). }
procedure SetStartUpProc(const Name: String; Proc: TUnitTest);

{ Registers a proc that is invoked AFTER every test in the suite. Ditto. }
procedure SetTearDownProc(const Name: String; Proc: TUnitTest);

{#endregion}

{#region Asserts}

(*
 * The following procs and funcs are only valid when called from inside
 * a test proc. Do no call them outside the code path of a test proc.
 *)

{ Asserts that @Condition is true. }
procedure Assert(Condition: Boolean);

{ Asserts with a custom message that @Condition is true. }
procedure AssertMsg(Condition: Boolean; const Msg: String);

{ Asserts that the range contains only zeros. }
procedure AssertMemZero(const Data; Len: Word);

{ Asserts that the range contains only Cs. }
procedure AssertMem(const Data; Len: Word; C: Char);

{ Asserts that @Condition is true. Does not terminate current test proc. }
procedure SoftAssert(Condition: Boolean);

{#endregion}

{#region Test control & info}

{ When invoked inside a test proc, verbose output of UTests is suppressed.
  Useful in test procs with MANY asserts.
  Verbosity is reset to default after test proc's termination. }
procedure BeSilent;

{ When invoked inside a test proc, verbose output of UTests is enabled.
  Verbosity is reset to default after test proc's termination. }
procedure BeVerbose;

{ Whether verbose is turned on. }
function  IsVerbose: Boolean;

{ Whether the suite is run in batch mode, i.e. env var UTESTB is set. }
function  IsBatch: Boolean;

{ Whether the current proc is 'under test' (manually selected with UTESTP) }
function  IsExplicit: Boolean;

{ Disables memory checks for the duration of the test proc. Useful when
  a test is leaking heap memory on purpose. }
procedure DisableMemCheck(const Reason: String);

{ Disables memory checks for the duration of the first iteration of
  the test proc. Useful when a test is leaking heap memory once. }
procedure DisableFirstMemCheck(const Reason: String);

{ Disables memory checks for the duration of the test proc. Checks that
  up to Size bytes were consumed. Size must be negative for leaks and
  positive for releases. }
procedure ExpectMemUsage(Size: Longint);

{ Don't emit stack usage below this limit. }
procedure SetStackReportLimit(Limit: Word);

{ Returns the current iteration of the current test. }
function GetTestIter: Integer;

{ Returns the name of the current test proc. Const. }
function GetTestProcName: PString;

{#endregion}

{#region Ignores}

{ Ignores a test proc. Must be called before any other Assert. }
procedure Ignore;
procedure IgnoreMsg(const Msg: String);

{ Ignores a test proc when in batch mode, i.e. env var UTESTB is set. }
procedure IgnoreBatch;

procedure IgnoreDpmi;
procedure IgnoreWindows;
procedure IgnoreDos;
procedure IgnoreDosXt;
procedure IgnoreKernel;
procedure IgnoreRealMode;
procedure IgnoreProtectedMode;

{ Runs the test proc only when explicitly selected. See UTESTP env var. }
procedure WhenExplicit;

{ Runs the test proc only when a math coprocessor is available. }
procedure When8087;

{ Runs the test proc only in Windows. }
procedure WhenWindows;

{ Runs the test proc only on DPMI. }
procedure WhenDpmi;

{ Runs the test proc only in Protected Mode. }
procedure WhenProtectedMode;

{ Runs test proc only once. }
procedure WhenFirst;

{#endregion}

{#region RNG}

{ Returns a random Longint. }
function  LongRand: Longint;

{ Returns a random string of a random length between 0 and MaxLen. }
function  StrRand(MaxLen: Word): String;

{ Returns a random 255 chars string. }
function  MaxStrRand: String;

{#endregion}

{#region Simple stopwatch}

type
  TStopWatch = object
    FStart: Longint;
    FStops: Longint;

    { Initializes and resets the stopwatch. Can be called multiple times. }
    constructor Init;

    { Returns the difference in ms between now and the Init time. }
    function Stop: Longint;

    { Returns true if Stop >= MilliSecs and emits Iterations if Log is true.
      Example:
        repeat
          ...
        until B.Loop(1000, true);
      executes the loop for 1000 millis and emits the amount of iterations. }
    function Loop(MilliSecs: Longint; Log: Boolean): Boolean;

    { Shortcut of Loop(1000, true) }
    function Plenty: Boolean;

    { returns how often Stop was invoked }
    function Iterations: Longint;
  end;

{#endregion}

{#region Canaries}

(*
 * Pushes a canary on the stack. Must be used pairwise with PopCanary.
 *
 * Example:
 *
 *   PushCanary;
 *   ...
 *   Assert(PopCanary);
 *)
procedure PushCanary;
  inline(
    $b8/$cc/$cc/    { mov   ax, $cccc }
    $50             { push  ax }
  );

(*
 * Pops the canary from the stack and returns true if has the expected value.
 * Must be used pairwise with PushCanary.
 *)
function PopCanary: Boolean;
  inline(
    $58/            { pop   ax }
    $3d/$cc/$cc/    { cmp   ax, $cccc }
    $75/$05/        { jne   +5 }
    $b8/$01/$00/    { mov   ax, 1 }
    $eb/$02/        { jmp   +2}
    $31/$c0         { xor   ax, ax }
  );

{#endregion}

{#region Benchmarks}

{ Runs a standard benchmark of the supplied Proc. Must be invoked from within
  a test proc. }
procedure RunBench(Proc: TUnitTest);

{ Runs a standard benchmark of the supplied Action which must be a nested
  procedure with the signature "procedure Action; far;"
  Must be invoked from within a test proc. }
procedure RunBenchAction(const Action: TDelegate);

{#endregion}

implementation

uses
  WinDos, Ticker, Utils;

{#region Globals}

type
  { Generic type for strings occurring in UTests. }
  TName = String[64];

var
  StartUpProcName: TName;         { name of StartUpProc }
  StartUpProc: TUnitTest;         { current StartUpProc }
  InStartUpProc: Boolean;         { StartUpProc is currently running }
  TearDownProcName: TName;        { name of TearDownProc }
  TearDownProc: TUnitTest;        { current TearDownProc }
  InTearDownProc: Boolean;        { TearDownProc currently running }
  SuiteName: TName;               { "ufoo.t" }
  SuiteTime: Longint;             { start time of the suite }
  SuiteTestsRun: Longint;         { how many test procs ran so far }
  SuiteTestsIgnored: Longint;     { how many test procs ignored }
  AssertsRun: Longint;            { how many asserts ran so far }
  GlobalVerbose: Boolean;         { default verbosity }
  Verbose: Boolean;               { current verbosity }
  GlobalMemCheck: Boolean;        { default memcheck }
  MemCheck: Boolean;              { current memcheck }
  DisableMemCheckReason: TName;   { message set by DisableMemCheck }
  ExpectedMemUsage: Longint;      { size set by DisableMemCheck }
  CurrEnv: TJmpEnv;               { for Assert's SetJmp/LongJmp handling }
  Ignored: Boolean;               { whether the current test proc is ignored }
  IgnoreMessage: String[80];      { message for "ignority" }
  Failed: Boolean;                { whether an assert failed }
  SoftFailed: Boolean;            { whether an assert failed softly, proc still running }
  GuardTop: Word;                 { top of the region armed by ArmStackGuard, 0 = unarmed }
  StackReportLimit: Word;         { don't report stack usage less than this amount }
  CurrentTestName: TName;         { name of current test proc }
  CurrentIter: Integer;           { current iteration (1...) }
  ProcFilter: TName;              { pattern for proc names to be run }
  IsProcUnderTest: Boolean;       { whether the current proc was matched by ProcFilter }
  BreakProcUnderTest: Boolean;    { whether to set a breakpoint before a test proc }
  LastAssertAddr: Pointer;        { last address of an Assert call site }
  RepeatAmount: Integer;          { how many times to run a test }
  BatchMode: Boolean;             { whether batch mode is active }

{#endregion}

{#region Timing}

function ReadTimer: Longint;
begin
  ReadTimer := Ticks;
end;

function ElapsedTime(Start, Stop : Longint): Longint;
begin
  ElapsedTime := Stop - Start;
end;

{#endregion}

{#region Runner + Asserts}

(*
 * Sets the global Failed flag.
 *)
procedure SetFailed;
begin
  Failed := true;
end;

(*
 *
 *)
procedure EnsureInsideTestProc;
begin
  if CurrentTestName <> '' then exit;
  WriteLn('::');
  WriteLn(':: FATAL ERROR: Cannot invoke Assert/Ignore from outside of a test proc.');
  WriteLn('::');
  SetFailed;
  Halt(2);
end;

(*
 *
 *)
procedure AssertImpl(Condition: Boolean; const Msg: String; ErrAddr: Pointer);
begin
  if Failed then exit;

  EnsureInsideTestProc;
  ErrAddr := GetLogicalAddr(ErrAddr);
  LastAssertAddr := ErrAddr;

  Inc(AssertsRun);

  if Verbose and not Ignored then
    Write('[', AssertsRun, ']');

  if Ignored then
  begin
    Write('[', UpperStr(IgnoreMessage), ']');
    if not Verbose then WriteLn;
  end;

  if Condition then exit;   { success }

  if Verbose then WriteLn;
  WriteLn('::');
  WriteLn(':: Suite: ', SuiteName);
  Write  (':: Test:  ', CurrentTestName);
  if InStartUpProc then
    Write(' in StartUpProc: ', StartUpProcName);
  if InTearDownProc then
    Write(' in TearDownProc: ', TearDownProcName);
  WriteLn;
  WriteLn('::');
  WriteLn(':: Assert #', AssertsRun, ' failed at program address ', PtrToHex(ErrAddr));
  if Length(Msg) > 0 then
  begin
    Writeln(':: Message: ', Msg);
  end;
  SetFailed;
  LongJmp(CurrEnv, 2);
end;

(*
 *
 *)
procedure AssertMsg(Condition: Boolean; const Msg: String);
begin
  AssertImpl(Condition, Msg, GetCallerAddr);
end;

(*
 *
 *)
procedure Assert(Condition: Boolean);
begin
  AssertImpl(Condition, '', GetCallerAddr);
end;

(*
 *
 *)
procedure SoftAssert(Condition: Boolean);
begin
  if Failed then exit;

  Inc(AssertsRun);

  if Verbose then
    Write('[', AssertsRun, ']');

  if Condition then exit;

  if Verbose then WriteLn;
  WriteLn(':: Soft assert #', AssertsRun, ' failed at ',
    'logical program address ', PtrToHex(GetLogicalAddr(GetCallerAddr)));
  SoftFailed := true;
end;

(*
 *
 *)
procedure InitSuite;
var
  Target: TName;
begin
  if Length(SuiteName) <> 0 then exit;

  SuiteName := PathChangeExt(PathGetBaseName(ParamStr(0)), '');
  Target := PathGetBaseName(PathGetDirName(ParamStr(0)));
  if Length(Target) > 0 then Target := '.' + Target;
  SuiteName := SuiteName + Target;
  LowerStrVar(SuiteName);
  SuiteTime := ReadTimer;
  SuiteTestsRun := 0;
  SuiteTestsIgnored := 0;
  AssertsRun := 0;
  Failed := false;
  SoftFailed := false;
  WriteLn('Start suite ', SuiteName);
end;

(*
 *
 *)
procedure DoneSuite;
begin
  if Length(SuiteName) = 0 then exit;

  Write('End suite ', SuiteName, ' after ',
    SuiteTestsRun, ' tests(s) in ',
    ElapsedTime(SuiteTime, ReadTimer), ' ms.');

  if SuiteTestsIgnored > 0 then
    Write(' ', SuiteTestsIgnored, ' test(s) ignored');

  WriteLn;

  { no tests => fail }
  if SuiteTestsRun = 0 then
  begin
    WriteLn('No tests to run.');
    SetFailed;
  end;

  SuiteName := '';
end;

(*
 *
 *)
procedure RunTestImpl(const Name: String; Test: TUnitTest; Iter, TotalIter: Word);
var
  T: Longint;
  Elapsed: Longint;
  MemStart, MemEnd: Longint;
  StackUsed, StrayOfs: Word;
  StrayFound: Boolean;
begin
  if Failed then exit;

  InitSuite;

  if Length(Name) = 0 then
  begin
    WriteLn('RunTest must be invoked with a name.');
    Halt(1);
  end;

  { check whether we only want to run tests by name/pattern }
  if not StrIMatchPattern(Name, ProcFilter) then exit;
  IsProcUnderTest := Length(ProcFilter) > 0;

  Write('Start proc ', SuiteName, '::', Name);
  if TotalIter > 1 then Write('  (', Iter, ' of ', TotalIter, ')');
  WriteLn;

  MemCheck := GlobalMemCheck;
  DisableMemCheckReason := '';
  ExpectedMemUsage := 0;
  AssertsRun := 0;
  CurrentTestName := Name;
  CurrentIter := Iter;
  Ignored := false;
  RandSeed := 42;
  Verbose := GlobalVerbose;
  MemStart := MemAvail;

  { StartUp }
  if Assigned(StartUpProc) then
  begin
    WriteLn('Start StartUp proc ', StartUpProcName);
    InStartUpProc := true;
    { set jump target for Assert/Ignore and execute StartUpProc }
    if SetJmp(CurrEnv) = 0 then StartUpProc;
    if Failed then exit;
    InStartUpProc := false;
    if Verbose then WriteLn;
    WriteLn('End   StartUp proc ', StartUpProcName);
    { don't count the Asserts of StartUpProc }
    AssertsRun := 0;
    Verbose := GlobalVerbose;
  end;

  T := ReadTimer;

  PushCanary;

  { set jump target for Assert/Ignore and execute test proc }
  if SetJmp(CurrEnv) = 0 then
  begin
    if BreakProcUnderTest then
      DebugBreak;
    Test;
  end;

  Elapsed := ElapsedTime(T, ReadTimer);

  InOutRes := 0;  { reset, as a test may have caused an I/O error }

  { reset to default }
  Verbose := GlobalVerbose;

  if not PopCanary then
  begin
    WriteLn('::');
    WriteLn(':: StackCheck failed after assert #', AssertsRun);
    WriteLn(':: Last known address: ', PtrToHex(LastAssertAddr));
    SetFailed;
    exit;
  end;

  if not Failed and Ignored then Assert(true);
  if Verbose then WriteLn;
  Inc(SuiteTestsRun);

  { TearDown }
  if Assigned(TearDownProc) then
  begin
    StackPush32(AssertsRun);
    AssertsRun := 0;
    { we don't ignore TearDownProcs }
    Ignored := false;
    WriteLn('Start TearDown proc ', TearDownProcName);
    InTearDownProc := true;
    { set jump target for Assert/Ignore and execute TearDownProc }
    if SetJmp(CurrEnv) = 0 then TearDownProc;
    if Failed then exit;
    InTearDownProc := false;
    if Verbose then WriteLn;
    WriteLn('End   TearDown proc ', TearDownProcName);
    { don't count the Asserts of TearDownProc }
    AssertsRun := StackPop32;
    Verbose := GlobalVerbose;
  end
  else
    if Failed then exit;

  MemEnd := MemAvail;
  if MemStart <> MemEnd then
  begin
    if MemCheck or ((ExpectedMemUsage <> 0) and (ExpectedMemUsage > MemEnd - MemStart)) then
    begin
      WriteLn('::');
      WriteLn(':: Test: "', CurrentTestName, '"');
      WriteLn(':: Heap diff: ', MemEnd - MemStart, ', expected: ', ExpectedMemUsage);
      WriteLn(':: MemCheck assertion failed after #', AssertsRun);
      WriteLn(':: Last known address: ', PtrToHex(LastAssertAddr));
      SetFailed;
      exit;
    end
    else
      WriteLn(^i, 'Heap diff: ', MemEnd - MemStart, ', resolution: ',
        DisableMemCheckReason);
  end;

  if AssertsRun = 0 then
  begin
    WriteLn('No tests run.');
    SetFailed;
  end;

  if SoftFailed then
  begin
    WriteLn('Soft asserts have failed.');
    SetFailed;
  end;

  WriteLn('End   proc ', SuiteName, '::', Name,
    ' after ', AssertsRun, ' assert(s) in ',
    Elapsed, ' ms.');

  CurrentTestName := '';
end;

(*
 *
 *)
procedure RunTest(const Name: String; Test: TUnitTest);
begin
  RunTestMulti(Name, Test, IntMax(RepeatAmount, 1));
end;

(*
 *
 *)
procedure RunTestMulti(const Name: String; Test: TUnitTest; Count: Word);
var
  I: Word;
begin
  for I := 1 to Count do
  begin
    RunTestImpl(Name, Test, I, Count);
    if Failed then exit;
  end;
end;

(*
 *
 *)
procedure SetStartUpProc(const Name: String; Proc: TUnitTest);
begin
  StartUpProcName := Name;
  StartUpProc := Proc;
end;

(*
 *
 *)
procedure SetTearDownProc(const Name: String; Proc: TUnitTest);
begin
  TearDownProcName := Name;
  TearDownProc := Proc;
end;

{#endregion}

{#region Test controls & info}

(*
 *
 *)
procedure BeSilent;
begin
  Verbose := false;
end;

(*
 *
 *)
procedure BeVerbose;
begin
  Verbose := true;
end;

(*
 *
 *)
function IsVerbose: Boolean;
begin
  IsVerbose := Verbose;
end;

(*
 *
 *)
function IsBatch: Boolean;
begin
  IsBatch := BatchMode;
end;

(*
 *
 *)
function IsExplicit: Boolean;
begin
  IsExplicit := IsProcUnderTest;
end;

(*
 *
 *)
procedure IgnoreMsg(const Msg: String);
begin
  EnsureInsideTestProc;

  IgnoreMessage := Msg;

  if AssertsRun <> 0 then
  begin
    if Verbose then WriteLn;
    WriteLn('::');
    WriteLn(':: An IGNORE must be invoked before any other ASSERT.');
    WriteLn(':: The issue is around assert #', AssertsRun, ' at address ',
      PtrToHex(LastAssertAddr));

    SetFailed;
  end;

  Ignored := true;
  Inc(SuiteTestsIgnored);
  LongJmp(CurrEnv, 1);
end;

(*
 *
 *)
procedure Ignore;
begin
  IgnoreMsg('Ignored');
end;

(*
 *
 *)
procedure IgnoreBatch;
begin
  if IsBatch and not IsProcUnderTest then IgnoreMsg('Ignored in batch mode');
end;

(*
 *
 *)
procedure IgnoreDpmi;
begin
  {$ifdef DPMI} IgnoreMsg('Ignored for target "DPMI"'); {$endif}
end;

(*
 *
 *)
procedure IgnoreWindows;
begin
  {$ifdef Windows} IgnoreMsg('Ignored for target "Windows"'); {$endif}
end;

(*
 *
 *)
procedure IgnoreProtectedMode;
begin
  IgnoreDpmi;
  IgnoreWindows;
end;

(*
 *
 *)
procedure IgnoreDos;
begin
  {$ifdef MSDOS} IgnoreMsg('Ignored for target "DOS"'); {$endif}
end;

(*
 *
 *)
procedure IgnoreDosXt;
begin
  {$ifdef MSDOS}
    {$ifopt G-}
      IgnoreMsg('Ignored for target "DOS XT"');
    {$endif}
  {$endif}
end;

(*
 *
 *)
procedure IgnoreKernel;
begin
  {$ifdef kernel}
    IgnoreMsg('Ignored for target "kernel"');
  {$endif}
end;

(*
 *
 *)
procedure IgnoreRealMode;
begin
  IgnoreDos;
  IgnoreDosXt;
  IgnoreKernel;
end;

(*
 *
 *)
procedure WhenExplicit;
begin
  if not IsProcUnderTest then
    IgnoreMsg('Ignored, must be run explicitly');
end;

(*
 *
 *)
procedure When8087;
begin
  if Test8087 = 0 then
    IgnoreMsg('Ignored, needs an 80x87');
end;

(*
 *
 *)
procedure WhenWindows;
begin
{$ifndef Windows}
  IgnoreMsg('Ignored, needs Windows');
{$endif}
end;

(*
 *
 *)
procedure WhenDpmi;
begin
{$ifndef DPMI}
  IgnoreMsg('Ignored, needs DPMI');
{$endif}
end;

(*
 *
 *)
procedure WhenProtectedMode;
begin
{$ifdef MSDOS}
  IgnoreMsg('Ignored, needs DPMI or Windows');
{$endif}
end;

(*
 *
 *)
procedure WhenFirst;
begin
  if CurrentIter <> 1 then IgnoreMsg('Ignored, test not reentrant');
end;

(*
 *
 *)
procedure DisableMemCheck(const Reason: String);
begin
  MemCheck := false;
  DisableMemCheckReason := Reason;
end;

(*
 *
 *)
procedure DisableFirstMemCheck(const Reason: String);
begin
  if CurrentIter = 1 then DisableMemCheck(Reason + ' [ONCE]');
end;

(*
 *
 *)
procedure SetStackReportLimit(limit: Word);
begin
  StackReportLimit := Limit;
end;

(*
 *
 *)
procedure ExpectMemUsage(Size: Longint);
begin
  MemCheck := false;
  ExpectedMemUsage := Size;
  DisableMemCheckReason := 'ExpectMemUsage(' + IntToStr(Size) + ') in effect';
end;

(*
 *
 *)
function GetTestIter: Integer;
begin
  GetTestIter := CurrentIter;
end;

(*
 *
 *)
function GetTestProcName: PString;
begin
  GetTestProcName := PString(@CurrentTestName);
end;

{#endregion}

{#region Stopwatch}

(*
 *
 *)
constructor TStopWatch.Init;
begin
  FStart := ReadTimer;
  FStops := 0;
end;

(*
 *
 *)
function TStopWatch.Stop: Longint;
begin
  Inc(FStops);
  Stop := ElapsedTime(FStart, ReadTimer);
end;

(*
 *
 *)
function TStopWatch.Iterations: Longint;
begin
  Iterations := FStops;
end;

(*
 *
 *)
function TStopWatch.Loop(MilliSecs: Longint; Log: Boolean): Boolean;
begin
  if Stop >= MilliSecs then
  begin
    Loop := true;
    if Log and (MilliSecs <> 0) then
      WriteLn('[Iters/1000ms: ', (FStops / MilliSecs) * 1000:0:0, ']');
  end
  else
    Loop := false;
end;

(*
 *
 *)
function TStopWatch.Plenty: Boolean;
begin
  Plenty := Loop(1000, true);
end;

{#endregion}

{#region Benchmarks}

(*
 *
 *)
procedure RunBench(Proc: TUnitTest);
var
  S: TStopWatch;
begin
  StackPush16(Ord(Verbose));
  BeSilent;
  S.Init;
  repeat
    Proc;
  until S.Plenty;
  Verbose := Boolean(StackPop16);
end;

(*
 *
 *)
procedure RunBenchAction(const Action: TDelegate);
var
  S: TStopWatch;
begin
  StackPush16(Ord(Verbose));
  BeSilent;
  S.Init;
  repeat
    InvokeDelegate_Void(Action);
  until S.Plenty;
  Verbose := Boolean(StackPop16);
end;

{#endregion}

{#region More asserts}

(*
 *
 *)
procedure AssertMemZero(const Data; Len: Word);
begin
  AssertImpl(FindFirstNotOf(Data, Len, #0) = Len, '', GetCallerAddr);
end;

(*
 *
 *)
procedure AssertMem(const Data; Len: Word; C: Char);
begin
  AssertImpl(FindFirstNotOf(Data, Len, C) = Len, '', GetCallerAddr);
end;

{#endregion}

{#region RNG}

(*
 *
 *)
function LongRand: Longint;
var
  Ignore: Byte;
begin
  Ignore := Random(1);
  LongRand := RandSeed;
end;

(*
 *
 *)
function StrRand(MaxLen: Word): String;
begin
  if MaxLen > 256 then MaxLen := 256;
  StrRand := MakeString(Random(MaxLen), Chr(Random(MaxLen)));
end;

(*
 *
 *)
function MaxStrRand: String;
var
  I: Integer;
begin
  MaxStrRand[0] := Char(255);
  for I := 1 to 255 do
    MaxStrRand[I] := Char(Random(256));
end;

{#endregion}

{#region Environment}

(*
 * Returns the value of an env var as integer.
 *)
function GetIntEnvVar(Name: PChar; Def: Integer): Integer;
var
  Value: Longint;
begin
  if TryCStrToInt(GetEnvVar(Name), Value) then
    GetIntEnvVar := Value
  else
    GetIntEnvVar := Def
end;

{#endregion}

{#region Exit handling}

(*
 * Things to do at exit.
 *)
procedure AtExit; far;
begin
  InOutRes := 0;

  { no hard error. this is a "good" exit point }
  if ErrorAddr = nil then
  begin
    { terminate suite }
    DoneSuite;
    { set ExitCode when we failed on something so makefiles can detect
      this situation as well. }
    if Failed then ExitCode := 1;
  end else
  begin
    { this is a proper runtime error }
    WriteLn;
    WriteLn('::');
    WriteLn(':: RUNTIME ERROR ', ExitCode, ' at program address ',
      PtrToHex(ErrorAddr));
    if CurrentTestName <> '' then
      WriteLn(':: Predicted location: ', CurrentTestName);
    if InStartUpProc then
      WriteLn(':: Predicted location: ', StartUpProcName);
    if InTearDownProc then
      WriteLn(':: Predicted location: ', TearDownProcName);
  end;
end;

{#endregion}

begin
  GlobalMemCheck := true;
  GlobalVerbose := GetIntEnvVar('UTESTV', 0) <> 0;
  BatchMode := GetIntEnvVar('UTESTB', 0) <> 0;
  ProcFilter := StrPasDef(GetEnvVar('UTESTP'), '');
  RepeatAmount := GetIntEnvVar('UTESTR', 0);
  BreakProcUnderTest := GetIntEnvVar('UTESTI3', 0) <> 0;
  AddExitHandler(AtExit);
end.
