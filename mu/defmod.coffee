# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

# The `defmod` function provides a utility wrapper to namespace code blocks.
#
# This functionality has been adapted from the `namespace` function defined in
# the [CoffeeScript FAQ](https://github.com/jashkenas/coffee-script/wiki/FAQ).
defmod = (name, definition) ->
  parts = name.split '.'
  target = this
  init = (parts) ->
    target = target[p] or= {} for p in parts
    return
  if typeof exports isnt 'undefined'
    target = exports
    if parts.length > 1
      init parts.slice 1
  else
    init parts
  definition target, this
  return
