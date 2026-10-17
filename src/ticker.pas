(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * The pure Pascal implementation extracted for CSOCK, based on the BIOS
 * ticker. It works on all CPUs.
 *
 * Note that Ticks is not monotonic. You'll have to use ElapsedTicks
 * for computing tick differences safely. Tick differences greater
 * than 24 hours are not supported.
 *)

unit Ticker;

interface

(*
 * Returns the number of milliseconds that have elapsed since
 * the system was started up.
 *
 * Does not handle rollovers at midnight. Use ElapsedTicks for computing
 * tick differences.
 *
 * Resolution: about 55 milliseconds.
 *)
function Ticks: Longint;

(*
 * Returns the number of milliseconds that have elapsed since Ticks was
 * assigned to 'StartTicks', basically computing Ticks - StartTicks.
 *
 * ElapsedTicks supports midnight rollovers => it is monotonic.
 *
 * Resolution: about 55 milliseconds.
 *)
function ElapsedTicks(StartTicks: Longint): Longint;

implementation

uses
  Bits;

const
  { amount of BIOS ticks per day in milliseconds }
  MsPerDay = 55 * $1800b0;

(*
 *
 *)
function Ticks: Longint;
var
  T: Longint;
begin
  BeginDisableInterrupts;
  T := MemL[Seg0040:$6c];
  EndDisableInterrupts;
  Ticks := T * 55;
end;

(*
 *
 *)
function ElapsedTicks(StartTicks: Longint): Longint;
var
  T: Longint;
begin
  T := Ticks;
  if T < StartTicks then Inc(T, MsPerDay);
  ElapsedTicks := T - StartTicks;
end;

end.
