(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *)

unit VxDApi;

interface

(*
 * Gets the V86 API of the VxD specified by its device ID
 *)
function GetVxDApiById(deviceId: Word): Pointer;


implementation

(*
 * INT 2F, AX 1684, BX = deviceId -> ES:DI API
 *
 * https://fd.lod.bz/rbil/interrup/windows/2f1684.html
 *)
function GetVxDApiById(deviceId: Word): Pointer; assembler;
asm
  mov  ax, $1684
  mov  bx, deviceId
  xor  di, di
  mov  es, di
  int  $2f
  mov  dx, es
  mov  ax, di
end;


end.
