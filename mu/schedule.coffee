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

  _ = µ._
  _.tickID = 0

  queue = new µ.Queue(25000 * 3)
  queued = false

  # TODO(tav): Ensure that callbacks don't throw any errors.
  tick = ->
    _.tickID++
    while queue.length() > 0
      queue.shift()(queue.shift(), queue.shift())
    queued = false
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

  _.schedule = (callback, arg1, arg2) ->
    queue.push callback, arg1, arg2
    if not queued
      queued = true
      scheduleTick()
    return

  return
