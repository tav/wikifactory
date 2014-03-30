# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  # The bit positions specify:
  #
  #   0    whether the flow has state
  #   1    whether the flow is mutable
  #   2    whether the flow is buffered
  #   3    whether the flow is stopable

  NO_STATE = 0
  MUTABLE = 2
  IMMUTABLE = 3
  BUFFERED = 4
  STOPABLE = 8

  µ.NO_STATE = NO_STATE
  µ.MUTABLE = MUTABLE
  µ.IMMUTABLE = IMMUTABLE
  µ.BUFFERED = BUFFERED

  {console, keys, tryErr, tryFn, tryFn1} = µ._
  {StopFlow, now, schedule} = µ
  {clearInterval, clearTimeout, setInterval, setTimeout} = root

  Flow = ->
    return

  isFlow = (f) ->
    f instanceof Flow

  isStopable = (f) ->
    (f._b & STOPABLE) > 0

  setStopable = (f) ->
    f._b |= STOPABLE
    return

  copyFlags = (upstream, downstream) ->
    return downstream

  pushValue = (upstream, downstream, value, success, successHandler, failureHandler) ->
    if success
      if successHandler is undefined
        schedule putValue, downstream, value
      else
        schedule runHandler, successHandler, downstream, value
    else
      if failureHandler is undefined
        schedule putError, downstream, error
      else
        schedule runHandler, failureHandler, downstream, value
    return

  putError = (flow, error) ->
    flow.putError error
    return

  putValue = (flow, value) ->
    flow.putValue value
    return

  runHandler = (handler, flow, value) ->
    ret = tryFn1 failureHandler, value
    if ret is tryErr
      downstream.putError ret.e
    else
      downstream.putValue ret
    return

  Flow:: =

    _b: 0            # bit field
    _h: undefined    # handler
    _f: undefined    # flow subscriber
    _p: undefined    # parent flow
    _v: undefined    # value

    catch: (handler) ->
      # @_s.push
      return

    catchError: (error, handler) ->
      if not ((error:: instanceof Error) or (error is Error))
        throw new TypeError("catchError can only catch Error and its subclasses")
      return

    debounce: (wait, immediate) ->
      return

    filter: (pred) ->
      @then (value) ->
        if pred value
          return value

    finally: (handler)->
      return

    limit: (duration) ->
      buf = []
      last = 0
      f = new Flow
      @then (value) ->
        n = now()
        setTimeout ->
          f.set value
        , duration
        return
      return f

    log: ->
      @then (value) ->
        console.log value
        return value
      .catch (err) ->
        console.error err
        throw err

    onStop: (handler) ->
      f = @
      setStopable f
      f.catchError StopFlow, handler

    putError: (err) ->
      return

    putValue: (value) ->
      return

    reduce: () ->
      return

    stop: ->
      f = @
      while f._a isnt undefined
        f = f._a
      f.reject(new StopFlow)
      return

    then: (handler) ->
      upstream = @
      downstream = new Flow
      downstream._b = 0
      # copy flags ...
      if isImmutable upstream
        setImmutable downstream
      if isStopable upstream
        setStopable downstream
        downstream._p = upstream
      if hasValue upstream
        pushValue upstream, downstream, upstream._value, handler, undefined
        if isMutable upstream
          # me._subscribers.extend([f, handler])
      else
        # me._subscribers.extend([f, handler])
      return downstream

    throttle: (wait) ->
      return

    timeout: (wait) ->
      f = @
      setTimeout ->
        f.setError new µ.Timeout
        return
      , duration
      return f

    to: (other) ->
      @.then (value) ->
        other.setValue value
        return
      return other

    toString: ->
      '[object Flow]'

  newFlow = (flags) ->
    f = new Flow
    f._b = flags|0
    return f

  newPromise = (value) ->
    f = new Flow
    f._b = IMMUTABLE
    if value isnt undefined
      f.setValue value
    return f

  newValue = (value) ->
    f = new Flow
    f._b = MUTABLE
    if value isnt undefined
      f.setValue value
    return f

  newFlow._typ = Flow
  newFlow.unhandled = (flow, reason) ->
    console.error "Uncaught flow error: #{reason}"
    return

  µ.flow = newFlow
  µ.promise = newPromise
  µ.value = newValue

  µ.every = (duration) ->
    s = newFlow NO_STATE
    i = 0
    timer = setInterval ->
      s.setValue i++
      return
    , duration
    s.onClose ->
      clearInterval timer
      return

  µ.merge = (flows...) ->
    f = newFlow BUFFERED
    buffer = (value) ->
      f.setValue
      return
    for flow in flows
      if isFlow flow
        flow.then buffer
      else
        f.setValue flow
    return f

  # Returns a value-like flow.
  sync = (flows...) ->
    return flow

  # Returns a value-like flow.
  sync.object = (spec) ->
    specKeys = keys spec
    specValues = []
    l = keys.length
    `for (var i = 0; i < l; i++) {
      values[i] = obj[specKeys[i]];
    }`
    return sync(values).then ->
      obj = {}
      args = [];
      `for (var i = 0; i < l; i++) {
        obj[specKeys[i]] = arguments[i];
      }`
      return obj

  µ.sync = sync

  # Returns a promise-like flow.
  # sync.first = (flows) ->
  #   return

  return
