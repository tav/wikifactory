# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  {keys} = µ._
  {now} = µ

  µ.is = (obj, ctor) ->
    obj instanceof ctor._typ

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
    me = @
    me.length = 0
    me._d = {}
    me._n = n
    me._m = n * 2
    return

  LRU:: =

    get: (key) ->
      if (state = @_d[key]) is undefined
        return state
      state[0] = last++
      return state[1]

    set: (key, value) ->
      me = @
      if me.not(key)
        me.length++
      me._d[key] = [last++, value]
      if me.length < me._m
        return
      evict me
      return

    delete: (key) ->
      me = @
      if me.not(key)
        return
      delete me._d[key]
      me.length--
      return

    not: (key) ->
      @_d[key] is undefined

    toString: ->
      '[object LRU]'

  lru = (limit) ->
    if (limit = limit|0) > 0
      new LRU(limit)
    else
      throw new µ.ValueError("invalid lru limit parameter")

  lru._typ = LRU
  µ.lru = lru

  perf = root.performance
  if perf and perf.now
    clock = ->
      perf.now()
  else
    latest = now()
    skew = 0
    clock = ->
      v = now()
      if v < latest
        skew += latest - v + 1
      latest = v
      return v + skew

  µ.clock = clock

  return
