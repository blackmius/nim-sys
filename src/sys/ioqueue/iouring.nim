import std/[deques, options, times]
import pkg/cps
import pkg/nimuring

import ".."/handles
import ".."/private/[ioqueue_common, errors]

## Linux io_uring implementation of `ioqueue`
##
## Shares the same queue and interface with `ioqueue`. Most users
## do not need to import this module as it is exported by `ioqueue`.

type
  CqeCont = ref object of Continuation
    ## Continuation waiting for the completion event
    cqe: Cqe
  EventQueue = object
    case initialized: bool
    of true:
      q: Queue ## The io_uring queue
      sqes: Deque[Sqe] ## Stash for overflowed sqes
      ## io_uring sqes capacity is static and if we exceed it
      ## we need to store additional Sqes somewhere
      ## before feed io_uring with them
      cqes: seq[Cqe] ## Static array to copy cqes ring to
      events: int ## count of waitable cqes
    of false:
      discard

var eq {.threadvar.}: EventQueue

proc init() =
  ## Initializes the queue for processing
  if eq.initialized: return
  eq = EventQueue(
    initialized: true,
    q: newQueue(4096, {SETUP_SQPOLL}), # run kernels theads
    sqes: initDeque[Sqe](4096)
  )
  eq.cqes = newSeq[Cqe](eq.q.params.cqEntries)

proc running(): bool =
  ## See the documentation of `ioqueue.running()`
  eq.events > 0

template drainQueue() =
  ## Submit as much as possible ops to the queue from stash
  while eq.sqes.len != 0:
    var sqe = eq.q.getSqe()
    if sqe.isNil:
      break
    sqe[] = eq.sqes.popFirst()
  discard eq.q.submit()

proc poll(runnable: var seq[Continuation], timeout = none(Duration)) {.used.} =
  ## See the documentation of `ioqueue.poll()`
  ## Timeout is not supported
  init()
  if not running(): return
  drainQueue()
  let ready = eq.q.copyCqes(eq.cqes)
  for i in 0..<ready:
    var cqe = eq.cqes[i]
    var c = cast[CqeCont](cqe.userData)
    c.cqe = cqe
    discard trampoline c
    eq.events -= 1

proc getSqe*(): ptr Sqe {.inline.} =
  ## Get sqe from ring or stash
  result = eq.q.getSqe()
  if result.isNil:
    eq.sqes.addLast(Sqe())
    result = addr eq.sqes.peekLast()

proc link(c: CqeCont, sqe: ptr Sqe): CqeCont {.cpsMagic.} =
  ## Link current Continuation with sqe
  eq.events += 1
  # we are use sqe.userData to pass Continuation
  # within cqe result
  sqe.setUserData(addr c)
  return c

proc cqe(c: CqeCont): Cqe {.cpsVoodoo.} =
  c.cqe

proc submit*(sqe: ptr Sqe): Cqe {.cps: CqeCont.} =
  ## Send and recieve CQE from io_uring
  runnableExamples:
    proc nop() {.asyncio.} =
      ## Empty OP to ensure io_uring consumes sqes
      let cqe = submit getSqe().nop()
      if cqe.res < 0:
        raise newException(OSError, osErrorMsg(OSErrorCode(cqe.res)))
  link(sqe)
  cqe()

proc persist(fd: AnyFD) {.raises: [OSError].} =
  ## See the documentation of `ioqueue.persist()`
  bind init
  init()
  discard

proc unregister(fd: AnyFD) {.used.} =
  ## See the documentation of `ioqueue.unregister()`
