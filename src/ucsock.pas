(*
 * SPDX-License-Identifier: MIT
 * SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
 *
 * Tests CSock, the bindings for dosemu2's socket VxD (see csock.pas),
 * against dosemu2.
 *
 * Usage:
 *
 *   ucsock [<host> [<port>]]
 *
 * <host> is the IP address of the HTTP server, <port> its port. Default
 * port: 80. Without arguments, the server is HttpHost:HttpPort below.
 *
 * Expects:
 *
 *   - an HTTP/1.0 server on HttpHost:HttpPort that closes the connection
 *     after the response
 *   - nothing listening on HttpHost:ClosedPort
 *   - a DNS server, as reported by the driver, that answers queries
 *     for localhost
 *
 * LoopbackTests needs nothing but the host's loopback interface.
 *
 * A failing test leaves its sockets open in dosemu2, which has only 32.
 * BasicTests displays the open ones.
 *)

program ucsock;

uses
  UTests, Strings, Utils, Ticker, CSock;

const
  { Both are configurable using the command line }
  HttpHost: String = '192.168.0.200';
  HttpPort: Word = 81;

const
  ClosedPort = 1;
  DnsPort = 53;
  LoopbackHost = '127.0.0.1';

  Timeout = 4000;         { milliseconds }

  { ID $1234, RD; one question: localhost, type A, class IN }
  DnsQuery: array[0 .. 26] of Char =
    #$12#$34#$01#$00#$00#$01#$00#$00#$00#$00#$00#$00#9'localhost'#0#$00#$01#$00#$01;

(*
 * Polls until Fd is readable or Timeout has elapsed.
 *)
function WaitReadable(Fd: Word): Boolean;
var
  ReadFds, WriteFds, ExceptFds, Start: Longint;
begin
  Start := Ticks;
  repeat
    ReadFds := Longint(1) shl Fd;
    WriteFds := 0;
    ExceptFds := 0;
    Assert(CSockSelect(ReadFds, WriteFds, ExceptFds, CSockPoll) = 0);
  until (ReadFds <> 0) or (ElapsedTicks(Start) > Timeout);
  WaitReadable := ReadFds <> 0;
end;

(*
 *
 *)
procedure BasicTests; far;
var
  Version, Fds: Longint;
begin
  Assert(CSockInit);
  Assert(CSockGetVersion(Version) = 0);
  WriteLn('Version:  ', Version);
  Assert(Version >= 2);

  Assert(CSockGetFds(Fds) = 0);
  WriteLn('Open fds: ', IntToHex(Fds, 8));
end;

(*
 *
 *)
procedure DriverInfoTests; far;
var
  Info: TCSockDriverInfo;
  HostMask: Longint;
begin
  FillChar(Info, SizeOf(Info), $ff);
  Assert(CSockGetDriverInfo(Info) = 0);

  WriteLn('Ip:       ', IpAddrToStr(Info.IpAddr));
  WriteLn('Netmask:  ', IpAddrToStr(Info.Netmask));
  WriteLn('Gateway:  ', IpAddrToStr(Info.Gateway));
  WriteLn('DNS:      ', IpAddrToStr(Info.DnsServer));
  WriteLn('MTU:      ', Info.Mtu);
  WriteLn('TCP MSS:  ', Info.TcpMss);
  WriteLn('Domain:   ', StrToPas(Info.Domain));

  Assert(Info.IpAddr <> 0);
  Assert(Info.Netmask <> 0);
  { The netmask's bits are contiguous from the top. This fails as well
    when the stub didn't convert the byte order. }
  HostMask := not Info.Netmask;
  Assert((HostMask and (HostMask + 1)) = 0);
  { the gateway is on our subnet }
  Assert((Info.Gateway and Info.Netmask) = (Info.IpAddr and Info.Netmask));
end;

(*
 *
 *)
procedure OpenCloseTests; far;
var
  Udp, Tcp: Word;
  Fds: Longint;
begin
  Assert(CSockOpen(CSockProtoUdp, Udp) = 0);
  Assert(CSockOpen(CSockProtoTcp, Tcp) = 0);
  Assert(Udp <> Tcp);
  Assert(CSockGetFds(Fds) = 0);
  Assert((Fds and (Longint(1) shl Udp)) <> 0);
  Assert((Fds and (Longint(1) shl Tcp)) <> 0);

  Assert(CSockClose(Tcp) = 0);
  Assert(CSockClose(Udp) = 0);
  Assert(CSockGetFds(Fds) = 0);
  Assert((Fds and (Longint(1) shl Udp)) = 0);
  Assert((Fds and (Longint(1) shl Tcp)) = 0);

  { a closed handle is invalid }
  Assert(CSockClose(Udp) = CSockErrInvalidSocket);
end;

(*
 * Handle 31 is free unless 32 sockets are open.
 *)
procedure BadHandleTests; far;
var
  Sent: Word;
begin
  Assert(CSockClose(31) = CSockErrInvalidSocket);
  Assert(CSockSend(31, DnsQuery, SizeOf(DnsQuery), Sent) = CSockErrInvalidSocket);
end;

(*
 *
 *)
procedure NonBlockingTests; far;
var
  Buf: array[0 .. 15] of Char;
  Fd, Rcvd, Port: Word;
  NonBlocking: Boolean;
  Addr, ReadFds, WriteFds, ExceptFds: Longint;
begin
  Assert(CSockOpen(CSockProtoUdp, Fd) = 0);

  { sockets start in blocking mode }
  NonBlocking := true;
  Assert(CSockGetNonBlocking(Fd, NonBlocking) = 0);
  Assert(not NonBlocking);

  Assert(CSockSetNonBlocking(Fd, true) = 0);
  Assert(CSockGetNonBlocking(Fd, NonBlocking) = 0);
  Assert(NonBlocking);

  Assert(CSockRecvFrom(Fd, Buf, SizeOf(Buf), Rcvd, Addr, Port) = CSockErrWouldBlock);

  { dosemu2 returns the requested masks on a timeout; the stub clears them }
  ReadFds := Longint(1) shl Fd;
  WriteFds := 0;
  ExceptFds := 0;
  Assert(CSockSelect(ReadFds, WriteFds, ExceptFds, CSockPoll) = 0);
  Assert(ReadFds = 0);

  Assert(CSockClose(Fd) = 0);
end;

(*
 *
 *)
procedure SockOptTests; far;
var
  Fd: Word;
  SoError: Longint;
begin
  Assert(CSockOpen(CSockProtoTcp, Fd) = 0);
  SoError := -1;
  Assert(CSockGetSoError(Fd, SoError) = 0);
  Assert(SoError = 0);
  Assert(CSockSetLinger(Fd, true, 0) = 0);
  Assert(CSockClose(Fd) = 0);
end;

(*
 * SO_BROADCAST and TCP_NODELAY. An older dosemu2 lacks SOCK_TCPNODELAY
 * and returns its function number; the test is skipped then.
 *)
procedure BoolOptTests; far;
var
  Udp, Tcp, Res: Word;
  Enabled: Boolean;
begin
  Assert(CSockOpen(CSockProtoTcp, Tcp) = 0);
  Enabled := true;
  Res := CSockGetNoDelay(Tcp, Enabled);
  if (Res > 0) and (Res <= $FF) then
  begin
    WriteLn('SOCK_TCPNODELAY unimplemented, skipped');
    Assert(CSockClose(Tcp) = 0);
    exit;
  end;
  { Nagle is on by default }
  Assert(Res = 0);
  Assert(not Enabled);
  Assert(CSockSetNoDelay(Tcp, true) = 0);
  Assert(CSockGetNoDelay(Tcp, Enabled) = 0);
  Assert(Enabled);
  Assert(CSockSetNoDelay(Tcp, false) = 0);
  Assert(CSockGetNoDelay(Tcp, Enabled) = 0);
  Assert(not Enabled);
  Assert(CSockClose(Tcp) = 0);

  Assert(CSockOpen(CSockProtoUdp, Udp) = 0);
  Enabled := true;
  Assert(CSockGetBroadcast(Udp, Enabled) = 0);
  Assert(not Enabled);
  Assert(CSockSetBroadcast(Udp, true) = 0);
  Assert(CSockGetBroadcast(Udp, Enabled) = 0);
  Assert(Enabled);
  { a TCP option on a UDP socket }
  Assert(CSockSetNoDelay(Udp, true) = CSockErrInvalidParam);
  Assert(CSockGetNoDelay(Udp, Enabled) = CSockErrInvalidParam);
  Assert(CSockClose(Udp) = 0);
end;

(*
 * Gather sends over UDP on the loopback interface, which also check the
 * byte order of the address and port. An older dosemu2 lacks SOCK_SENDMSG
 * and returns its function number; the test is skipped then.
 *)
procedure SendMsgTests; far;
const
  Mark: array[0 .. 3] of Char = 'mark';
  Payload: array[0 .. 6] of Char = 'payload';
var
  Iov: array[0 .. 2] of TCSockIoVec;
  Buf: array[0 .. 15] of Char;
  Rx, Tx, Rcvd, RxPort, TxPort, Port, Res: Word;
  Loopback, Addr, Sent: Longint;
begin
  Loopback := IpAddrFromString(LoopbackHost);
  Assert(CSockOpen(CSockProtoUdp, Rx) = 0);
  Assert(CSockBind(Rx, Loopback, 0) = 0);
  Assert(CSockGetSockName(Rx, Addr, RxPort) = 0);
  Assert(CSockOpen(CSockProtoUdp, Tx) = 0);

  { three segments, the middle one empty }
  Iov[0].Base := @Mark;
  Iov[0].Len := SizeOf(Mark);
  Iov[1].Base := nil;
  Iov[1].Len := 0;
  Iov[2].Base := @Payload;
  Iov[2].Len := SizeOf(Payload);

  Res := CSockSendMsg(Tx, Loopback, RxPort, Iov, 3, Sent);
  if (Res > 0) and (Res <= $FF) then
  begin
    WriteLn('SOCK_SENDMSG unimplemented, skipped');
    Assert(CSockClose(Tx) = 0);
    Assert(CSockClose(Rx) = 0);
    exit;
  end;
  Assert(Res = 0);
  Assert(Sent = SizeOf(Mark) + SizeOf(Payload));

  { one datagram, the segments in order, from Tx }
  Assert(WaitReadable(Rx));
  Assert(CSockRecvFrom(Rx, Buf, SizeOf(Buf), Rcvd, Addr, Port) = 0);
  Assert(Rcvd = SizeOf(Mark) + SizeOf(Payload));
  Assert(StrLComp(Buf, 'markpayload', Rcvd) = 0);
  Assert(CSockGetSockName(Tx, Addr, TxPort) = 0);
  Assert(Port = TxPort);

  { connected: to the peer without an address, and no address allowed }
  Assert(CSockConnect(Tx, Loopback, RxPort) = 0);
  Assert(CSockSendMsg(Tx, 0, 0, Iov, 3, Sent) = 0);
  Assert(Sent = SizeOf(Mark) + SizeOf(Payload));
  Assert(WaitReadable(Rx));
  Assert(CSockRecvFrom(Rx, Buf, SizeOf(Buf), Rcvd, Addr, Port) = 0);
  Assert(Rcvd = SizeOf(Mark) + SizeOf(Payload));
  Assert(CSockSendMsg(Tx, Loopback, RxPort, Iov, 3, Sent) = CSockErrInvalidParam);

  { segment counts out of range }
  Assert(CSockSendMsg(Tx, 0, 0, Iov, 0, Sent) = CSockErrInvalidParam);
  Assert(CSockSendMsg(Tx, 0, 0, Iov, CSockIovMax + 1, Sent) = CSockErrInvalidParam);

  Assert(CSockClose(Tx) = 0);
  Assert(CSockClose(Rx) = 0);
end;

(*
 * Peeks and scatter receives over UDP on the loopback interface. An older
 * dosemu2 lacks SOCK_RECVMSG and returns its function number; the test is
 * skipped then.
 *)
procedure RecvMsgTests; far;
const
  Msg: array[0 .. 10] of Char = 'XIDXpayload';
var
  Iov: array[0 .. 1] of TCSockIoVec;
  Xid: array[0 .. 3] of Char;
  Head: array[0 .. 2] of Char;
  Tail: array[0 .. 15] of Char;
  Rx, Tx, Sent, RxPort, TxPort, Port, Res: Word;
  Loopback, Addr, Rcvd: Longint;
begin
  Loopback := IpAddrFromString(LoopbackHost);
  Assert(CSockOpen(CSockProtoUdp, Rx) = 0);
  Assert(CSockBind(Rx, Loopback, 0) = 0);
  Assert(CSockGetSockName(Rx, Addr, RxPort) = 0);
  Assert(CSockSetNonBlocking(Rx, true) = 0);

  { nothing there yet }
  Iov[0].Base := @Xid;
  Iov[0].Len := SizeOf(Xid);
  Res := CSockRecvMsg(Rx, Iov, 1, 0, Rcvd, Addr, Port);
  if (Res > 0) and (Res <= $FF) then
  begin
    WriteLn('SOCK_RECVMSG unimplemented, skipped');
    Assert(CSockClose(Rx) = 0);
    exit;
  end;
  Assert(Res = CSockErrWouldBlock);

  Assert(CSockOpen(CSockProtoUdp, Tx) = 0);
  Assert(CSockSendTo(Tx, Loopback, RxPort, Msg, SizeOf(Msg), Sent) = 0);
  Assert(CSockGetSockName(Tx, Addr, TxPort) = 0);
  Assert(WaitReadable(Rx));

  { a peek at the first 4 bytes leaves the datagram queued }
  Assert(CSockRecvMsg(Rx, Iov, 1, CSockMsgPeek, Rcvd, Addr, Port) = 0);
  Assert(Rcvd = SizeOf(Xid));
  Assert(StrLComp(Xid, 'XIDX', 4) = 0);
  Assert(Addr = Loopback);
  Assert(Port = TxPort);

  { the whole datagram, scattered over two segments }
  Iov[0].Base := @Head;
  Iov[0].Len := SizeOf(Head);
  Iov[1].Base := @Tail;
  Iov[1].Len := SizeOf(Tail);
  Assert(CSockRecvMsg(Rx, Iov, 2, 0, Rcvd, Addr, Port) = 0);
  Assert(Rcvd = SizeOf(Msg));
  Assert(StrLComp(Head, 'XID', 3) = 0);
  Assert(StrLComp(Tail, 'Xpayload', 8) = 0);
  Assert(Port = TxPort);

  { consumed now }
  Assert(CSockRecvMsg(Rx, Iov, 2, 0, Rcvd, Addr, Port) = CSockErrWouldBlock);

  { a blocking socket, with the datagram already there so that it can't hang }
  Assert(CSockSetNonBlocking(Rx, false) = 0);
  Assert(CSockSendTo(Tx, Loopback, RxPort, Msg, SizeOf(Msg), Sent) = 0);
  Assert(WaitReadable(Rx));
  Assert(CSockRecvMsg(Rx, Iov, 2, 0, Rcvd, Addr, Port) = 0);
  Assert(Rcvd = SizeOf(Msg));

  { unknown flags, segment counts out of range }
  Assert(CSockRecvMsg(Rx, Iov, 2, $8000, Rcvd, Addr, Port) = CSockErrInvalidParam);
  Assert(CSockRecvMsg(Rx, Iov, 0, 0, Rcvd, Addr, Port) = CSockErrInvalidParam);
  Assert(CSockRecvMsg(Rx, Iov, CSockIovMax + 1, 0, Rcvd, Addr, Port) = CSockErrInvalidParam);

  Assert(CSockClose(Tx) = 0);
  Assert(CSockClose(Rx) = 0);
end;

(*
 * A DNS round trip. The sender of the reply checks the byte order of
 * both directions against a known port.
 *)
procedure UdpTests; far;
var
  Info: TCSockDriverInfo;
  Reply: array[0 .. 511] of Byte;
  Fd, Sent, Rcvd, Port: Word;
  Addr, Avail: Longint;
begin
  Assert(CSockGetDriverInfo(Info) = 0);
  Assert(CSockOpen(CSockProtoUdp, Fd) = 0);
  Assert(CSockSetNonBlocking(Fd, true) = 0);

  Assert(CSockSendTo(Fd, Info.DnsServer, DnsPort, DnsQuery, SizeOf(DnsQuery), Sent) = 0);
  Assert(Sent = SizeOf(DnsQuery));

  Assert(WaitReadable(Fd));
  Assert(CSockFionRead(Fd, Avail) = 0);
  Assert(Avail >= 12);

  Assert(CSockRecvFrom(Fd, Reply, SizeOf(Reply), Rcvd, Addr, Port) = 0);
  Assert(Rcvd >= 12);                             { a header at least }
  Assert((Reply[0] = $12) and (Reply[1] = $34));  { our ID }
  Assert((Reply[2] and $80) <> 0);                { QR: a response }
  Assert(Addr = Info.DnsServer);
  Assert(Port = DnsPort);

  { SendTo has bound the socket to an ephemeral port }
  Assert(CSockGetSockName(Fd, Addr, Port) = 0);
  Assert(Port <> 0);

  Assert(CSockClose(Fd) = 0);
end;

(*
 * A listener, a client and the accepted server socket on the loopback
 * interface. The listener and the client are non-blocking, so that
 * nothing waits forever.
 *)
procedure LoopbackTests; far;
const
  Msg: array[0 .. 3] of Char = 'ping';
var
  Buf: array[0 .. 15] of Char;
  Listener, Client, Server, Sent, Rcvd, Res: Word;
  ListenPort, ClientPort, Port: Word;
  Loopback, Addr, Avail, Start: Longint;
begin
  Loopback := IpAddrFromString(LoopbackHost);

  Assert(CSockOpen(CSockProtoTcp, Listener) = 0);
  Assert(CSockBind(Listener, Loopback, 0) = 0);
  Assert(CSockGetSockName(Listener, Addr, ListenPort) = 0);
  Assert(Addr = Loopback);
  Assert(ListenPort <> 0);
  Assert(CSockListen(Listener, 1) = 0);
  Assert(CSockSetNonBlocking(Listener, true) = 0);

  Assert(CSockOpen(CSockProtoTcp, Client) = 0);
  Assert(CSockSetNonBlocking(Client, true) = 0);
  Res := CSockConnect(Client, Loopback, ListenPort);
  Assert((Res = 0) or (Res = CSockErrWouldBlock));

  Start := Ticks;
  repeat
    Res := CSockAccept(Listener, Server, Addr, Port);
  until (Res <> CSockErrWouldBlock) or (ElapsedTicks(Start) > Timeout);
  Assert(Res = 0);
  Assert(Addr = Loopback);

  { a repeated connect succeeds once the connection is up }
  Start := Ticks;
  repeat
    Res := CSockConnect(Client, Loopback, ListenPort);
  until (Res <> CSockErrWouldBlock) or (ElapsedTicks(Start) > Timeout);
  Assert(Res = 0);

  { both ends agree on the endpoints }
  Assert(CSockGetSockName(Client, Addr, ClientPort) = 0);
  Assert(Port = ClientPort);
  Assert(CSockGetPeerName(Server, Addr, Port) = 0);
  Assert((Addr = Loopback) and (Port = ClientPort));
  Assert(CSockGetPeerName(Client, Addr, Port) = 0);
  Assert((Addr = Loopback) and (Port = ListenPort));

  Assert(CSockSend(Client, Msg, SizeOf(Msg), Sent) = 0);
  Assert(Sent = SizeOf(Msg));

  { the server socket is in blocking mode: wait before reading }
  Assert(WaitReadable(Server));
  Assert(CSockFionRead(Server, Avail) = 0);
  Assert(Avail = SizeOf(Msg));
  Assert(CSockRecv(Server, Buf, SizeOf(Buf), Rcvd) = 0);
  Assert(Rcvd = SizeOf(Msg));
  Assert(StrLComp(Buf, Msg, SizeOf(Msg)) = 0);

  { the client's close is an EOF for the server }
  Assert(CSockClose(Client) = 0);
  Assert(WaitReadable(Server));
  Assert(CSockRecv(Server, Buf, SizeOf(Buf), Rcvd) = 0);
  Assert(Rcvd = 0);

  Assert(CSockClose(Server) = 0);
  Assert(CSockClose(Listener) = 0);
end;

(*
 * Connects in blocking mode, then reads the response in non-blocking
 * mode until EOF.
 *)
procedure TcpTests; far;
const
  Request: array[0 .. 17] of Char = 'GET / HTTP/1.0'^m^j^m^j;
var
  Buf: array[0 .. 1023] of Char;
  Fd, Sent, Rcvd, Port, Res: Word;
  Addr, Total, Start: Longint;
begin
  Assert(CSockOpen(CSockProtoTcp, Fd) = 0);
  Assert(CSockConnect(Fd, IpAddrFromString(HttpHost), HttpPort) = 0);
  Assert(CSockGetPeerName(Fd, Addr, Port) = 0);
  Assert(Addr = IpAddrFromString(HttpHost));
  Assert(Port = HttpPort);

  Assert(CSockSend(Fd, Request, SizeOf(Request), Sent) = 0);
  Assert(Sent = SizeOf(Request));

  Assert(CSockSetNonBlocking(Fd, true) = 0);
  Total := 0;
  Start := Ticks;
  repeat
    Res := CSockRecv(Fd, Buf, SizeOf(Buf), Rcvd);
    if Res = 0 then
    begin
      if Total = 0 then
        Assert((Rcvd >= 7) and (StrLComp(Buf, 'HTTP/1.', 7) = 0));
      Inc(Total, Rcvd);
    end;
  until ((Res = 0) and (Rcvd = 0)) or
    ((Res <> 0) and (Res <> CSockErrWouldBlock)) or
    (ElapsedTicks(Start) > Timeout);
  Assert(Res = 0);
  Assert(Rcvd = 0);                               { EOF }
  Assert(Total > 0);

  Assert(CSockClose(Fd) = 0);
end;

(*
 *
 *)
procedure ConnectRefusedTests; far;
var
  Fd: Word;
begin
  Assert(CSockOpen(CSockProtoTcp, Fd) = 0);
  Assert(CSockConnect(Fd, IpAddrFromString(HttpHost), ClosedPort) = CSockErrNotConnected);
  Assert(CSockClose(Fd) = 0);
end;

(*
 * Displays the usage and terminates.
 *)
procedure Usage;
begin
  WriteLn('Usage: ucsock [<host> [<port>]]');
  WriteLn;
  WriteLn('Where:');
  WriteLn('  <host>  IP address of the HTTP server.');
  WriteLn('  <port>  Port of the HTTP server. Default: 80');
  WriteLn;
  WriteLn('Without arguments: ', HttpHost, ':', HttpPort);
  Halt(1);
end;

(*
 * Sets HttpHost and HttpPort from the command line. A bad address would
 * fail TcpTests without a hint, so both are validated.
 *)
procedure ParseCommandLine;
var
  Port: Longint;
begin
  if ParamCount = 0 then exit;

  { IpAddrFromString returns -1 for 255.255.255.255 as well, which is
    no HTTP server either }
  if (ParamCount > 2) or (IpAddrFromString(ParamStr(1)) = -1) then
    Usage;

  Port := 80;
  if ParamCount = 2 then
    if not TryStrToInt(ParamStr(2), Port) or (Port < 1) or (Port > $FFFF) then
      Usage;

  HttpHost := ParamStr(1);
  HttpPort := Port;
end;

begin
  ParseCommandLine;

  if not CSockInit then
  begin
    WriteLn('CSOCK unavailable, nothing to test');
    Halt(1);
  end;

  RunTest('BasicTests', BasicTests);
  RunTest('DriverInfoTests', DriverInfoTests);
  RunTest('OpenCloseTests', OpenCloseTests);
  RunTest('BadHandleTests', BadHandleTests);
  RunTest('NonBlockingTests', NonBlockingTests);
  RunTest('SockOptTests', SockOptTests);
  RunTest('BoolOptTests', BoolOptTests);
  RunTest('SendMsgTests', SendMsgTests);
  RunTest('RecvMsgTests', RecvMsgTests);
  RunTest('UdpTests', UdpTests);
  RunTest('LoopbackTests', LoopbackTests);
  RunTest('TcpTests', TcpTests);
  RunTest('ConnectRefusedTests', ConnectRefusedTests);
end.
