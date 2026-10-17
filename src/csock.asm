;;
;; SPDX-License-Identifier: MIT
;; SPDX-FileCopyrightText: 1986-2026 https://github.com/robert-j
;;
;; Stubs for dosemu2's socket VxD (device ID 1235h), the raw API that
;; libd2sock's csock.h describes. dosemu2 implements it in
;; src/dosext/dpmi/vxd_sock.c. Bindings: csock.pas.
;;
;; The entry point takes and returns all registers in full, also in real
;; mode: EAX = function, EDI = socket handle, ESI = buffer as a 16:16 far
;; pointer (DS is ignored), ECX = length, EBX/EDX = address/port in
;; network byte order. CF set on error, EAX = CSOCK_ERR_xxx.
;;
;; Every stub returns AX = 0, CSOCK_ERR_xxx, or the function number when
;; dosemu2 doesn't implement the call: it then returns CF clear with EAX
;; untouched. The stubs write their outputs only when CF is clear.
;;
;; The stubs preserve ESI and EDI, as code that TSRs call must.
;; dosemu2 itself changes only its outputs.
;;
;; 386 code. The bindings call a stub only after CSockInit has found the
;; VxD, which only dosemu2 provides.
;;
	;; ((header))
	.MODEL	LARGE,PASCAL
	LOCALS

	.DATA

	EXTRN	CSockEntry:DWORD	; owned by csock.pas

	.CODE
	.386				; after .MODEL: the segment stays USE16

	; ((publics))
	PUBLIC	CSockGetVersion, CSockGetDriverInfo
	PUBLIC	CSockOpen, CSockClose, CSockBind, CSockConnect
	PUBLIC	CSockListen, CSockAccept
	PUBLIC	CSockSend, CSockRecv, CSockSendTo, CSockRecvFrom
	PUBLIC	CSockSelect, CSockGetFds, CSockFionRead
	PUBLIC	CSockGetSockName, CSockGetPeerName
	PUBLIC	CSockGetNonBlocking, CSockSetNonBlocking
	PUBLIC	CSockGetSoError, CSockSetLinger
	PUBLIC	CSockGetBroadcast, CSockSetBroadcast
	PUBLIC	CSockGetNoDelay, CSockSetNoDelay
	PUBLIC	CSockSendMsg, CSockRecvMsg

	; functions (EAX), as in vxd_sock.c
	SOCK_VER		EQU	0
	SOCK_OPEN		EQU	1
	SOCK_CLOSE		EQU	2
	SOCK_BIND		EQU	3
	SOCK_SENDTO		EQU	4
	SOCK_RECVFROM		EQU	5
	SOCK_SELECT		EQU	6
	SOCK_CONNECT		EQU	7
	SOCK_SEND		EQU	8
	SOCK_RECV		EQU	9
	SOCK_LISTEN		EQU	10
	SOCK_ACCEPT		EQU	12
	SOCK_GETSOCKNAME	EQU	13
	SOCK_GETPEERNAME	EQU	14
	SOCK_NBM		EQU	15
	SOCK_GETFDS		EQU	16
	SOCK_FIONREAD		EQU	17
	SOCK_GETSOERR		EQU	18
	SOCK_SOLINGER		EQU	19
	SOCK_SOBCAST		EQU	20
	SOCK_TCPNODELAY		EQU	21
	SOCK_SENDMSG		EQU	22
	SOCK_RECVMSG		EQU	23

	CSOCK_ERR_INTERNAL	EQU	700h

	; SizeOf(TCSockDriverInfo), checked in csock.pas
	DRIVER_INFO_SIZE	EQU	285

;;
;; Swaps the bytes of a 32-bit register. BSWAP needs a 486.
;;
SWAP32	MACRO	R32, RL, RH
	xchg	RL, RH
	rol	R32, 16
	xchg	RL, RH
	ENDM

;; ((obj: csver))
;; function CSockGetVersion(var Version: Longint): Word;
;;
;; EDI = 0 skips the driver info, so the call can't fail.
;;
CSockGetVersion PROC FAR USES edi, Ver:DWORD
	xor	edi, edi
	mov	eax, SOCK_VER
	call	dword ptr CSockEntry
	les	di, Ver
	mov	es:[di], eax
	xor	ax, ax
	ret
CSockGetVersion ENDP

;; ((obj: csinfo))
;; function CSockGetDriverInfo(var Info: TCSockDriverInfo): Word;
;;
;; Converts the five addresses at the start of Info to host byte order.
;;
CSockGetDriverInfo PROC FAR USES esi edi, Info:DWORD
	mov	edi, DRIVER_INFO_SIZE
	mov	esi, Info
	mov	eax, SOCK_VER
	call	dword ptr CSockEntry
	jc	@@fail
	les	di, Info
	mov	cx, 5
@@swap:
	mov	eax, es:[di]
	SWAP32	eax, al, ah
	mov	es:[di], eax
	add	di, 4
	loop	@@swap
	xor	ax, ax
	ret
@@fail:
	mov	ax, CSOCK_ERR_INTERNAL	; dosemu2 leaves EAX = 0
	ret
CSockGetDriverInfo ENDP

;; ((obj: csopen))
;; function CSockOpen(Proto: Word; var Fd: Word): Word;
;;
CSockOpen PROC FAR USES edi, Protocol:WORD, Fd:DWORD
	movzx	ebx, Protocol
	mov	eax, SOCK_OPEN
	call	dword ptr CSockEntry
	jc	@@done
	mov	dx, di			; the new handle
	les	di, Fd
	mov	es:[di], dx
@@done:
	ret
CSockOpen ENDP

;; ((obj: csclose))
;; function CSockClose(Fd: Word): Word;
;;
CSockClose PROC FAR USES edi, Fd:WORD
	movzx	edi, Fd
	mov	eax, SOCK_CLOSE
	call	dword ptr CSockEntry
	ret
CSockClose ENDP

;; ((obj: csbind))
;; function CSockBind(Fd: Word; IpAddr: Longint; IpPort: Word): Word;
;;
CSockBind PROC FAR USES edi, Fd:WORD, IpAddr:DWORD, IpPort:WORD
	movzx	edi, Fd
	mov	ebx, IpAddr
	SWAP32	ebx, bl, bh
	movzx	edx, IpPort
	xchg	dl, dh
	mov	eax, SOCK_BIND
	call	dword ptr CSockEntry
	ret
CSockBind ENDP

;; ((obj: csconn))
;; function CSockConnect(Fd: Word; IpAddr: Longint; IpPort: Word): Word;
;;
CSockConnect PROC FAR USES edi, Fd:WORD, IpAddr:DWORD, IpPort:WORD
	movzx	edi, Fd
	mov	ebx, IpAddr
	SWAP32	ebx, bl, bh
	movzx	edx, IpPort
	xchg	dl, dh
	mov	eax, SOCK_CONNECT
	call	dword ptr CSockEntry
	ret
CSockConnect ENDP

;; ((obj: cslstn))
;; function CSockListen(Fd: Word; Backlog: Word): Word;
;;
CSockListen PROC FAR USES edi, Fd:WORD, Backlog:WORD
	movzx	edi, Fd
	movzx	ecx, Backlog
	mov	eax, SOCK_LISTEN
	call	dword ptr CSockEntry
	ret
CSockListen ENDP

;; ((obj: csaccpt))
;; function CSockAccept(Fd: Word; var NewFd: Word; var IpAddr: Longint;
;;   var IpPort: Word): Word;
;;
;; Returns EDX = new handle, EBX = port, ECX = address: not the order
;; of RecvFrom.
;;
CSockAccept PROC FAR USES edi, Fd:WORD, NewFd:DWORD, IpAddr:DWORD, IpPort:DWORD
	movzx	edi, Fd
	mov	eax, SOCK_ACCEPT
	call	dword ptr CSockEntry
	jc	@@done
	les	di, NewFd
	mov	es:[di], dx
	SWAP32	ecx, cl, ch
	les	di, IpAddr
	mov	es:[di], ecx
	xchg	bl, bh
	les	di, IpPort
	mov	es:[di], bx
@@done:
	ret
CSockAccept ENDP

;; ((obj: cssend))
;; function CSockSend(Fd: Word; const Buf; BufLen: Word;
;;   var Sent: Word): Word;
;;
CSockSend PROC FAR USES esi edi, Fd:WORD, Buf:DWORD, BufLen:WORD, Sent:DWORD
	movzx	edi, Fd
	mov	esi, Buf
	movzx	ecx, BufLen
	mov	eax, SOCK_SEND
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Sent
	mov	es:[di], cx
@@done:
	ret
CSockSend ENDP

;; ((obj: csrcv))
;; function CSockRecv(Fd: Word; var Buf; BufLen: Word;
;;   var Rcvd: Word): Word;
;;
CSockRecv PROC FAR USES esi edi, Fd:WORD, Buf:DWORD, BufLen:WORD, Rcvd:DWORD
	movzx	edi, Fd
	mov	esi, Buf
	movzx	ecx, BufLen
	mov	eax, SOCK_RECV
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Rcvd
	mov	es:[di], cx
@@done:
	ret
CSockRecv ENDP

;; ((obj: cssndto))
;; function CSockSendTo(Fd: Word; IpAddr: Longint; IpPort: Word;
;;   const Buf; BufLen: Word; var Sent: Word): Word;
;;
CSockSendTo PROC FAR USES esi edi, Fd:WORD, IpAddr:DWORD, IpPort:WORD, Buf:DWORD, BufLen:WORD, Sent:DWORD
	movzx	edi, Fd
	mov	ebx, IpAddr
	SWAP32	ebx, bl, bh
	movzx	edx, IpPort
	xchg	dl, dh
	mov	esi, Buf
	movzx	ecx, BufLen
	mov	eax, SOCK_SENDTO
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Sent
	mov	es:[di], cx
@@done:
	ret
CSockSendTo ENDP

;; ((obj: csrcvfr))
;; function CSockRecvFrom(Fd: Word; var Buf; BufLen: Word;
;;   var Rcvd: Word; var IpAddr: Longint; var IpPort: Word): Word;
;;
;; In non-blocking mode, dosemu2 doesn't report the sender of an empty
;; datagram; the stub returns 0.0.0.0:0 then.
;;
CSockRecvFrom PROC FAR USES esi edi, Fd:WORD, Buf:DWORD, BufLen:WORD, Rcvd:DWORD, IpAddr:DWORD, IpPort:DWORD
	movzx	edi, Fd
	mov	esi, Buf
	movzx	ecx, BufLen
	xor	ebx, ebx
	xor	edx, edx
	mov	eax, SOCK_RECVFROM
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Rcvd
	mov	es:[di], cx
	SWAP32	ebx, bl, bh
	les	di, IpAddr
	mov	es:[di], ebx
	xchg	dl, dh
	les	di, IpPort
	mov	es:[di], dx
@@done:
	ret
CSockRecvFrom ENDP

;; ((obj: csslct))
;; function CSockSelect(var ReadFds, WriteFds, ExceptFds: Longint;
;;   Timeout: Longint): Word;
;;
;; Timeout in microseconds. On a timeout, dosemu2 returns EAX = 0 with
;; the requested masks; the stub clears them.
;;
CSockSelect PROC FAR USES edi, ReadFds:DWORD, WriteFds:DWORD, ExceptFds:DWORD, Timeout:DWORD
	les	di, ReadFds
	mov	ebx, es:[di]
	les	di, WriteFds
	mov	ecx, es:[di]
	les	di, ExceptFds
	mov	edx, es:[di]
	mov	edi, Timeout
	mov	eax, SOCK_SELECT
	call	dword ptr CSockEntry
	jc	@@done
	test	eax, eax
	jnz	@@ready
	xor	ebx, ebx
	xor	ecx, ecx
	xor	edx, edx
@@ready:
	les	di, ReadFds
	mov	es:[di], ebx
	les	di, WriteFds
	mov	es:[di], ecx
	les	di, ExceptFds
	mov	es:[di], edx
	xor	ax, ax			; EAX was the number of ready handles
@@done:
	ret
CSockSelect ENDP

;; ((obj: csgtfds))
;; function CSockGetFds(var Fds: Longint): Word;
;;
CSockGetFds PROC FAR Fds:DWORD
	mov	eax, SOCK_GETFDS
	call	dword ptr CSockEntry
	les	di, Fds
	mov	es:[di], eax
	xor	ax, ax
	ret
CSockGetFds ENDP

;; ((obj: csfionr))
;; function CSockFionRead(Fd: Word; var Avail: Longint): Word;
;;
CSockFionRead PROC FAR USES edi, Fd:WORD, Avail:DWORD
	movzx	edi, Fd
	mov	eax, SOCK_FIONREAD
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Avail
	mov	es:[di], ecx
@@done:
	ret
CSockFionRead ENDP

;; ((obj: cssname))
;; function CSockGetSockName(Fd: Word; var IpAddr: Longint;
;;   var IpPort: Word): Word;
;;
CSockGetSockName PROC FAR USES edi, Fd:WORD, IpAddr:DWORD, IpPort:DWORD
	movzx	edi, Fd
	mov	eax, SOCK_GETSOCKNAME
	call	dword ptr CSockEntry
	jc	@@done
	SWAP32	ecx, cl, ch		; ECX = address, EBX = port
	les	di, IpAddr
	mov	es:[di], ecx
	xchg	bl, bh
	les	di, IpPort
	mov	es:[di], bx
@@done:
	ret
CSockGetSockName ENDP

;; ((obj: cspname))
;; function CSockGetPeerName(Fd: Word; var IpAddr: Longint;
;;   var IpPort: Word): Word;
;;
CSockGetPeerName PROC FAR USES edi, Fd:WORD, IpAddr:DWORD, IpPort:DWORD
	movzx	edi, Fd
	mov	eax, SOCK_GETPEERNAME
	call	dword ptr CSockEntry
	jc	@@done
	SWAP32	ecx, cl, ch		; ECX = address, EBX = port
	les	di, IpAddr
	mov	es:[di], ecx
	xchg	bl, bh
	les	di, IpPort
	mov	es:[di], bx
@@done:
	ret
CSockGetPeerName ENDP

;; ((obj: csgnblk))
;; function CSockGetNonBlocking(Fd: Word; var NonBlocking: Boolean): Word;
;;
CSockGetNonBlocking PROC FAR USES edi, Fd:WORD, NonBlocking:DWORD
	movzx	edi, Fd
	xor	ecx, ecx		; get
	mov	eax, SOCK_NBM
	call	dword ptr CSockEntry
	jc	@@done
	les	di, NonBlocking
	mov	es:[di], dl
@@done:
	ret
CSockGetNonBlocking ENDP

;; ((obj: cssnblk))
;; function CSockSetNonBlocking(Fd: Word; NonBlocking: Boolean): Word;
;;
CSockSetNonBlocking PROC FAR USES edi, Fd:WORD, NonBlocking:WORD
	movzx	edi, Fd
	mov	ecx, 1			; set
	movzx	edx, byte ptr NonBlocking	; Boolean is a byte
	mov	eax, SOCK_NBM
	call	dword ptr CSockEntry
	ret
CSockSetNonBlocking ENDP

;; ((obj: csgerr))
;; function CSockGetSoError(Fd: Word; var SoError: Longint): Word;
;;
CSockGetSoError PROC FAR USES edi, Fd:WORD, SoError:DWORD
	movzx	edi, Fd
	mov	eax, SOCK_GETSOERR
	call	dword ptr CSockEntry
	jc	@@done
	les	di, SoError
	mov	es:[di], edx
@@done:
	ret
CSockGetSoError ENDP

;; ((obj: csslng))
;; function CSockSetLinger(Fd: Word; OnOff: Boolean; Seconds: Word): Word;
;;
CSockSetLinger PROC FAR USES edi, Fd:WORD, OnOff:WORD, Seconds:WORD
	movzx	edi, Fd
	movzx	ecx, byte ptr OnOff
	movzx	edx, Seconds
	mov	eax, SOCK_SOLINGER
	call	dword ptr CSockEntry
	ret
CSockSetLinger ENDP

;; ((obj: csgbcst))
;; function CSockGetBroadcast(Fd: Word; var Broadcast: Boolean): Word;
;;
CSockGetBroadcast PROC FAR USES edi, Fd:WORD, Broadcast:DWORD
	movzx	edi, Fd
	xor	ecx, ecx		; get
	mov	eax, SOCK_SOBCAST
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Broadcast
	mov	es:[di], dl
@@done:
	ret
CSockGetBroadcast ENDP

;; ((obj: cssbcst))
;; function CSockSetBroadcast(Fd: Word; Broadcast: Boolean): Word;
;;
CSockSetBroadcast PROC FAR USES edi, Fd:WORD, Broadcast:WORD
	movzx	edi, Fd
	mov	ecx, 1			; set
	movzx	edx, byte ptr Broadcast	; Boolean is a byte
	mov	eax, SOCK_SOBCAST
	call	dword ptr CSockEntry
	ret
CSockSetBroadcast ENDP

;; ((obj: csgndly))
;; function CSockGetNoDelay(Fd: Word; var NoDelay: Boolean): Word;
;;
CSockGetNoDelay PROC FAR USES edi, Fd:WORD, NoDelay:DWORD
	movzx	edi, Fd
	xor	ecx, ecx		; get
	mov	eax, SOCK_TCPNODELAY
	call	dword ptr CSockEntry
	jc	@@done
	les	di, NoDelay
	mov	es:[di], dl
@@done:
	ret
CSockGetNoDelay ENDP

;; ((obj: cssndly))
;; function CSockSetNoDelay(Fd: Word; NoDelay: Boolean): Word;
;;
CSockSetNoDelay PROC FAR USES edi, Fd:WORD, NoDelay:WORD
	movzx	edi, Fd
	mov	ecx, 1			; set
	movzx	edx, byte ptr NoDelay	; Boolean is a byte
	mov	eax, SOCK_TCPNODELAY
	call	dword ptr CSockEntry
	ret
CSockSetNoDelay ENDP

;; ((obj: cssndmg))
;; function CSockSendMsg(Fd: Word; IpAddr: Longint; IpPort: Word;
;;   const Iov; Cnt: Word; var Sent: Longint): Word;
;;
;; Iov is an array of Cnt TCSockIoVec, which is the vxd_sock's own format.
;; IpAddr = 0 sends to the connected peer.
;;
CSockSendMsg PROC FAR USES esi edi, Fd:WORD, IpAddr:DWORD, IpPort:WORD, Iov:DWORD, Cnt:WORD, Sent:DWORD
	movzx	edi, Fd
	mov	ebx, IpAddr
	SWAP32	ebx, bl, bh
	movzx	edx, IpPort
	xchg	dl, dh
	mov	esi, Iov
	movzx	ecx, Cnt
	mov	eax, SOCK_SENDMSG
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Sent
	mov	es:[di], ecx
@@done:
	ret
CSockSendMsg ENDP

;; ((obj: csrcvmg))
;; function CSockRecvMsg(Fd: Word; const Iov; Cnt, Flags: Word;
;;   var Rcvd: Longint; var IpAddr: Longint; var IpPort: Word): Word;
;;
;; Iov is an array of Cnt TCSockIoVec.
;;
CSockRecvMsg PROC FAR USES esi edi, Fd:WORD, Iov:DWORD, Cnt:WORD, Flags:WORD, Rcvd:DWORD, IpAddr:DWORD, IpPort:DWORD
	movzx	edi, Fd
	mov	esi, Iov
	movzx	ecx, Cnt
	movzx	edx, Flags
	xor	ebx, ebx
	mov	eax, SOCK_RECVMSG
	call	dword ptr CSockEntry
	jc	@@done
	les	di, Rcvd
	mov	es:[di], ecx
	SWAP32	ebx, bl, bh
	les	di, IpAddr
	mov	es:[di], ebx
	xchg	dl, dh
	les	di, IpPort
	mov	es:[di], dx
@@done:
	ret
CSockRecvMsg ENDP

	END
