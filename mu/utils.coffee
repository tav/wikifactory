# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  µ.is = (obj, ctor) ->
    obj instanceof ctor._typ

  µ.isArray = root.Array.isArray

  µ.isError = (err) ->
    err instanceof Error

  µ.isFunction = (f) ->
    typeof f is 'function'

  µ.keys = keys = root.Object.keys

  last = 0
  evict = (lru) ->
    data = lru._d
    items = []
    for key in keys(data)
      items.push [key, data[key][0]]
    items.sort (a, b) ->
      a[1] - b[1]
    for spec in items.slice(lru.length = lru._n)
      delete data[spec[0]]
    return

  LRU = (n) ->
    @length = 0
    @_d = {}
    @_n = n
    @_m = n * 2
    return

  LRU:: =

    get: (key) ->
      if (state = @_d[key]) is undefined
        return state
      state[0] = last++
      return state[1]

    set: (key, value) ->
      if @not(key)
        @length++
      @_d[key] = [last++, value]
      if @length < @_m
        return
      evict @
      return

    delete: (key) ->
      if @not(key)
        return
      delete @_d[key]
      @length--
      return

    not: (key) ->
      @_d[key] is undefined

  lru = (limit) ->
    if (limit = limit|0) > 0
      new LRU(limit)
    else
      throw new µ.ValueError("invalid lru limit value")

  lru._typ = LRU
  µ.lru = lru

  µ.now = now = root.Date.now

  perf = root.performance
  if perf and perf.now
    µ.clock = ->
      perf.now()
  else
    latest = now()
    µ.clock = ->
      v = now()
      if v >= latest
        return latest = v
      ++latest

  return
