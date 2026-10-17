# csock

Unit tests for dosemu2's socket VxD, `vxd_sock`. The VxD has the device
ID 1235h and implements the raw socket API that libd2sock's `csock.h`
describes; the dosemu2 source is `src/dosext/dpmi/vxd_sock.c`.

The tests run in real mode and in 16-bit protected mode:

| Program       | Mode                          |
|---------------|-------------------------------|
| `ucsockd.exe` | Real mode                     |
| `ucsockp.exe` | 16-bit protected mode (DPMI)  |

## Contents

| File                     | Purpose                                         |
|--------------------------|-------------------------------------------------|
| `src/ucsock.pas`         | The tests                                       |
| `src/csock.pas`          | CSock, the Pascal bindings of the VxD API       |
| `src/csock.asm`          | The TASM stubs behind CSock                     |
| `src/utests.pas`         | The unit test framework                         |
| `src/utils.pas`, `src/bits.pas`, `src/ticker.pas`, `src/vxdapi.pas` | Support units |

## Building

Requires Borland Pascal 7 with TASM and Borland MAKE. Set `BPROOT` in
`src/makefile` to your Borland Pascal directory, then run in `src`:

```
make
```

The programs end up in `src\build`. `make clean` removes the directory.

## Running

Inside dosemu2:

```
ucsockd [<host> [<port>]]
ucsockp [<host> [<port>]]
```

`<host>` is the IP address of an HTTP server, `<port>` its port.
Default port: 80. Without arguments, the tests use 192.168.0.200:81.

`ucsockp.exe` needs Borland Pascal's `RTM.EXE` in the current directory or
on the `PATH`. dosemu2 provides the DPMI host.

The tests expect:

- an HTTP/1.0 server on `<host>:<port>` that closes the connection after
  the response (TcpTests)
- nothing listening on `<host>:1` (ConnectRefusedTests)
- the DNS server that dosemu2 reports, answering a query for `localhost`;
  any reply counts (UdpTests)
- the host's loopback interface (LoopbackTests, SendMsgTests,
  RecvMsgTests)

dosemu2 builds without functions 21 to 23 (`SOCK_TCPNODELAY`,
`SOCK_SENDMSG`, `SOCK_RECVMSG`) skip BoolOptTests, SendMsgTests and
RecvMsgTests.

A failed test exits with code 1 and leaves its sockets open in dosemu2,
which has 32. Without the VxD, the programs display
`CSOCK unavailable, nothing to test` and exit with code 0.

Environment variables control the test runner:

| Variable           | Effect                                           |
|--------------------|--------------------------------------------------|
| `UTESTV=1`         | Verbose output                                   |
| `UTESTP=<pattern>` | Runs only the tests matching `<pattern>`, e.g. `Loopback*` |
| `UTESTR=<n>`       | Runs every test `<n>` times                      |
| `UTESTB=1`         | Batch mode                                       |
| `UTESTI3=1`        | Breaks into the debugger before every test       |

## License

MIT, see the SPDX headers of the sources.
