(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * Bindings for dosemu2's socket VxD (device ID 1235h), the raw API that
 * libd2sock's csock.h describes. dosemu2 implements it in
 * src/dosext/dpmi/vxd_sock.c. The stubs are in csock.asm.
 *
 + Notes
 *
 * Our API is little endian: the stubs convert addresses and ports from
 * and to network byte order.
 *
 * Every call returns 0 or a CSockErr* code. 1..$FF is the number of a
 * function that this dosemu2 doesn't implement. Outputs are valid only
 * when the call returns 0.
 *
 * The stubs use 386 instructions. Call nothing before CSockInit has
 * returned true: it finds the VxD only under dosemu2, which always
 * provides a 386.
 *
 * Sockets start in blocking mode, where Recv, RecvFrom, Connect and
 * Accept wait inside dosemu2 until they are done. Send and SendTo never
 * wait; they fail with CSockErrWouldBlock instead. In non-blocking mode,
 * repeat Connect until it no longer fails with CSockErrWouldBlock.
 *
 * Handles are 0..31; bit n of the CSockSelect masks is handle n. Poll
 * with CSockSelect (Timeout = 0): dosemu2 reuses the fd_sets that the
 * host's select() has cleared, so a longer timeout misses everything
 * that arrives after its first poll.
 *)

unit CSock;

interface

const
  { error codes, from Coda's sock.vxd }
  CSockErrInvalidParam = $100;
  CSockErrNoMemory = $200;
  CSockErrInvalidSocket = $300;
  CSockErrAlreadyBound = $400;
  CSockErrNotBound = $500;
  CSockErrAccess = $600;
  CSockErrInternal = $700;
  CSockErrFdInUse = $800;
  CSockErrInfiniteWait = $900;
  CSockErrNotConnected = $A00;
  CSockErrWouldBlock = $B00;
  CSockErrNotListening = $C00;

  { CSockOpen protocols. dosemu2 opens UDP for anything but TCP. }
  CSockProtoTcp = 6;
  CSockProtoUdp = 17;

  { CSockSelect timeouts, in microseconds }
  CSockPoll = 0;
  CSockForever = -1;

  { the most segments CSockSendMsg and CSockRecvMsg take }
  CSockIovMax = 16;

  { CSockRecvMsg flags }
  CSockMsgPeek = 2;

type
  { Result of CSockGetDriverInfo. The addresses are in host byte order. }
  PCSockDriverInfo = ^TCSockDriverInfo;
  TCSockDriverInfo = record
    IpAddr: Longint;
    Netmask: Longint;
    Gateway: Longint;
    DnsServer: Longint;
    TimeServer: Longint;
    Mtu: Word;
    Ttl: Byte;
    Tos: Byte;
    TcpMss: Word;
    TcpRwin: Word;
    Debug: Word;
    Domain: array[0 .. 254] of Char;  { dosemu2: the host name, #0 terminated }
  end;

  { One segment of CSockSendMsg and CSockRecvMsg, in the VxD's own format }
  PCSockIoVec = ^TCSockIoVec;
  TCSockIoVec = record
    Base: Pointer;
    Len: Longint;
  end;

function CSockInit: Boolean;

function CSockGetVersion(var Version: Longint): Word;
function CSockGetDriverInfo(var Info: TCSockDriverInfo): Word;

function CSockOpen(Proto: Word; var Fd: Word): Word;
function CSockClose(Fd: Word): Word;
function CSockBind(Fd: Word; IpAddr: Longint; IpPort: Word): Word;
function CSockConnect(Fd: Word; IpAddr: Longint; IpPort: Word): Word;
function CSockListen(Fd: Word; Backlog: Word): Word;
function CSockAccept(Fd: Word; var NewFd: Word; var IpAddr: Longint;
  var IpPort: Word): Word;

function CSockSend(Fd: Word; const Buf; BufLen: Word; var Sent: Word): Word;
function CSockRecv(Fd: Word; var Buf; BufLen: Word; var Rcvd: Word): Word;
function CSockSendTo(Fd: Word; IpAddr: Longint; IpPort: Word;
  const Buf; BufLen: Word; var Sent: Word): Word;
function CSockRecvFrom(Fd: Word; var Buf; BufLen: Word; var Rcvd: Word;
  var IpAddr: Longint; var IpPort: Word): Word;

function CSockSelect(var ReadFds, WriteFds, ExceptFds: Longint;
  Timeout: Longint): Word;
function CSockGetFds(var Fds: Longint): Word;
function CSockFionRead(Fd: Word; var Avail: Longint): Word;

function CSockGetSockName(Fd: Word; var IpAddr: Longint; var IpPort: Word): Word;
function CSockGetPeerName(Fd: Word; var IpAddr: Longint; var IpPort: Word): Word;
function CSockGetNonBlocking(Fd: Word; var NonBlocking: Boolean): Word;
function CSockSetNonBlocking(Fd: Word; NonBlocking: Boolean): Word;
function CSockGetSoError(Fd: Word; var SoError: Longint): Word;
function CSockSetLinger(Fd: Word; OnOff: Boolean; Seconds: Word): Word;

function CSockGetBroadcast(Fd: Word; var Broadcast: Boolean): Word;
function CSockSetBroadcast(Fd: Word; Broadcast: Boolean): Word;
function CSockGetNoDelay(Fd: Word; var NoDelay: Boolean): Word;
function CSockSetNoDelay(Fd: Word; NoDelay: Boolean): Word;

{ A gather send: Iov is an array of Cnt TCSockIoVec, 1..CSockIovMax. One
  call is one datagram. IpAddr = 0 sends to the connected peer; only an
  unconnected socket may name an address. }
function CSockSendMsg(Fd: Word; IpAddr: Longint; IpPort: Word;
  const Iov; Cnt: Word; var Sent: Longint): Word;

{ A scatter receive into Cnt TCSockIoVec, 1..CSockIovMax. One call is one
  datagram, cut to the segments; CSockMsgPeek leaves it queued. Waits on a
  blocking socket like CSockRecvFrom. }
function CSockRecvMsg(Fd: Word; const Iov; Cnt, Flags: Word;
  var Rcvd: Longint; var IpAddr: Longint; var IpPort: Word): Word;

implementation

uses
  VxdApi;

const
  CSockVxdId = $1235;

  { compile-time check: csock.asm passes DRIVER_INFO_SIZE }
  StaticAssertDriverInfoSize = 1 div Ord(SizeOf(TCSockDriverInfo) = 285);

  { compile-time check: the VxD takes 8-byte segments }
  StaticAssertIoVecSize = 1 div Ord(SizeOf(TCSockIoVec) = 8);

var
  { the VxD's entry point; the stubs call through it }
  CSockEntry: Pointer;

(*
 * Finds the VxD and checks that it implements version 2 at least, as
 * libd2sock does.
 *)
function CSockInit: Boolean;
var
  Version: Longint;
begin
  CSockInit := false;
  CSockEntry := GetVxDApiById(CSockVxdId);
  if CSockEntry = nil then
    exit;
  if (CSockGetVersion(Version) = 0) and (Version >= 2) then
    CSockInit := true
  else
    CSockEntry := nil;
end;

function CSockGetVersion; external;
function CSockGetDriverInfo; external;
function CSockOpen; external;
function CSockClose; external;
function CSockBind; external;
function CSockConnect; external;
function CSockListen; external;
function CSockAccept; external;
function CSockSend; external;
function CSockRecv; external;
function CSockSendTo; external;
function CSockRecvFrom; external;
function CSockSelect; external;
function CSockGetFds; external;
function CSockFionRead; external;
function CSockGetSockName; external;
function CSockGetPeerName; external;
function CSockGetNonBlocking; external;
function CSockSetNonBlocking; external;
function CSockGetSoError; external;
function CSockSetLinger; external;
function CSockGetBroadcast; external;
function CSockSetBroadcast; external;
function CSockGetNoDelay; external;
function CSockSetNoDelay; external;
function CSockSendMsg; external;
function CSockRecvMsg; external;

{$l csock.obj}

end.
