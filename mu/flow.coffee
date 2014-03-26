# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  ABORTABLE = 0

  _try = µ.try
  tryError = _try.error
  tryFn = _try.fn

  Flow = ->
    @_b = 0
    return

  isFlow = (f) ->
    f instanceof Flow

  isAbortable = (f) ->
    (f._b & ABORTABLE) > 0

  setAbortable = (f) ->
    f._b |= ABORTABLE
    return f

  clearTimeout = root.clearTimeout
  setTimeout = root.setTimeout

  Flow:: =

    _b: 0            # bit flags
    _p: undefined    # parent
    _v: undefined    # stored value

    # reject
    error: (reason) ->
      return

    then: (handler) ->
      @

    catch: (handler) ->
      return

    log: ->
      @then (value) ->
        console.log value
        return
      .catch (reason) ->
        console.error reason
        return

    catchError: (error, handler) ->
      if not ((error:: instanceof Error) or (error is Error))
        throw new TypeError("catchError can only catch Error and its subclasses")
      return

    finally: (handler)->
      return

    # try: (fn) ->
    #   f = @
    #   resp = tryFn fn
    #   if resp is tryError
    #     f.reject resp.e
    #   else
    #     f.resolve resp
    #   return f

    buffer: ->
      return

    # set
    update: (value) ->
      return

    push: ->
      return

    resolve: (value) ->
      return

    # bufferN = ->
    #   return

    filter: (pred) ->
      @then (value) ->
        if pred value
          return value

    reduce: () ->
      return

    # merge: (other) ->
    #   return

    debounce: (wait, immediate) ->
      return

    throttle: (wait) ->
      return

    toString: ->
      '[object Flow]'

    abort: ->
      f = @
      while f._a isnt undefined
        f = f._a
      f.reject(new µ.Abort)
      return

    abortable: ->
      setAbortable @

    sleep: (duration) ->
      @then (value) ->
        f = new Flow
        setTimeout ->
          f.set value
        , duration
        return f

    timeout: (wait) ->
      f = @
      setTimeout ->
        f.reject new µ.Timeout
      , duration
      return

  newFlow = (spec) ->
    new Flow
    return

  newPromise = ->
    new Flow

  newStream = ->
    new Flow

  newValue = (obj) ->
    v = new Flow
    if obj is undefined
      return v
    v.set obj
    return v

  newFlow._typ = newPromise._typ = newStream._typ = newValue._typ = Flow

  console = root.console
  newFlow.unhandled = (flow, reason) ->
    if typeof console is 'object'
      msg = "Uncaught #{reason}"
      if typeof console.error is 'function'
        console.error msg
      else if typeof console.log is 'function'
        console.log msg
    return

  µ.flow = newFlow
  µ.promise = newPromise
  µ.stream = newStream
  µ.value = newValue

  # Returns a value-like flow.
  all = (flows) ->
    return

  sync = (flows...) ->
    return all(flows)

  sync.all = all

  # Returns a stream-like flow.
  sync.any = (flows) ->
    return anyN 1, flows

  # Returns a value-like flow.
  sync.anyN = (n, flows) ->
    return

  # Returns a value-like flow.
  sync.object = (obj) ->
    return

  # Returns a promise-like flow.
  sync.first = (flows) ->
    return

  # Returns a value-like flow.
  sync.when = (flows) ->
    return

  µ.sync = sync

  # µ.constant
  # µ.channel (backpressure)

  µ.every = (duration) ->
    return

  # µ.merge

  # µ.map = (seq) ->
  #   return

  return
