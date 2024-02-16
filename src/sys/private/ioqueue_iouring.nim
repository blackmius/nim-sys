type
  EventQueueImpl = object
    ## The queue of io_uring is implemented in a different module

template initImpl() {.dirty.} = discard

template runningImpl(): bool {.dirty.} =
  iouring.running()

template pollImpl() {.dirty.} =
  iouring.poll(runnable, timeout)

template persistImpl() {.dirty.} =
  iouring.persist(fd)

template unregisterImpl() {.dirty.} =
  iouring.unregister(fd)

template waitEventImpl() {.dirty.} = discard
