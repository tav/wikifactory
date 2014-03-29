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

  queueA = []
  queueB = []
  useA = true

  # TODO(tav): Ensure that callbacks don't throw any errors.
  run = (queue) ->
    for callback in queue
      callback()
    queue.length = 0
    return

  tick = ->
    if useA
      useA = false
      run queueA
    else
      useA = true
      run queueB
    return

  MutationObserver = root.MutationObserver or root.WebKitMutationObserver
  setTimeout = root.setTimeout

  if MutationObserver
    $div = root.document.createElement 'div'
    observer = new MutationObserver tick
    observer.observe $div, attributes: true
    scheduleTick = ->
      $div.setAttribute 'class', 'tick'
      return
  else
    scheduleTick = ->
      setTimeout tick, 0
      return

  µ.schedule = (callback) ->
    if useA
      if queueA.push(callback) is 1
        scheduleTick()
    else
      if queueB.push(callback) is 1
        scheduleTick()
    return

  return
