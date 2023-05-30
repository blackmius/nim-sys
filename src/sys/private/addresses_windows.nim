#
#            Abstractions for operating system services
#                   Copyright (c) 2021 Leorize
#
# Licensed under the terms of the MIT license which can be found in
# the file "license.txt" included with this distribution. Alternatively,
# the full text can be found at: https://spdx.org/licenses/MIT.html

import syscall/winim/winim/core as wincore except Handle

type
  IP4Impl {.borrow: `.`.} = distinct InAddr
  IP6Impl {.borrow: `.`.} = distinct In6Addr

template ip4Word() {.dirty.} =
  result = cast[uint32](ip.S_addr)

template ip4SetWord() {.dirty.} =
  ip.S_addr = cast[int32](w)

type IP4EndpointImpl {.requiresInit, borrow: `.`.} = distinct Sockaddr_in

template ip4InitEndpoint() {.dirty.} =
  result = IP4EndpointImpl:
    sockaddr_in(
      sin_family: AF_INET,
      sin_addr: InAddr(ip),
      sin_port: toBE(port.uint16)
    )

template ip4EndpointAddr() {.dirty.} =
  result = IP4 e.sin_addr

template ip4EndpointPort() {.dirty.} =
  result = Port fromBE(e.sin_port)


