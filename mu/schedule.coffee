# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  # It would have been nice to use the `setImmediate` API proposed by Microsoft
  # that's present in both IE10 and recent versions of NodeJS. Unfortunately,
  # the way it interfaces with timer functions like `setTimeout` means that it
  # is possible for registered callbacks to never get called. Similar issues
  # also rules out the use of postMessage and MessageChannel on IE.
  #
  # Source:
  # http://codeforhire.com/2013/09/21/setimmediate-and-messagechannel-broken-on-internet-explorer-10/

  queue = []
  nextQueue = []
  useNext = false

  # TODO(tav): Ensure that callbacks don't throw any errors.
  execTick = ->
    if useNext
      useNext = false
      for callback in nextQueue
        callback()
      nextQueue.length = 0
    else
      useNext = true
      for callback in queue
        callback()
      queue.length = 0
    return

  MutationObserver = root.MutationObserver or root.WebKitMutationObserver
  setTimeout = root.setTimeout

  if MutationObserver
    $div = root.document.createElement 'div'
    observer = new MutationObserver execTick
    observer.observe $div, attributes: true
    tick = ->
      $div.setAttribute 'class', 'tick'
      return
  else
    tick = ->
      setTimeout execTick, 0
      return

  µ.asap = (callback) ->
    if useNext
      if nextQueue.push(callback) is 1
        tick()
    else
      if queue.push(callback) is 1
        tick()
    return

  µ.setTimeout = setTimeout

  return
