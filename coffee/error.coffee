# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  newError = (name, defaultMessage) ->
    Exception = (message) ->
      if !(@ instanceof Exception)
        return new Exception(message)
      @name = name
      @message = if typeof message is 'string' then message else defaultMessage
      if Error.captureStackTrace
        Error.captureStackTrace @, @constructor
      return
    Exception:: = Object.create Error::,
      constructor:
        value: Exception
    return Exception

  µ.newError = newError

  µ.AbortError = newError 'AbortError', 'operation was aborted'
  µ.TimeoutError = newError 'TimeoutError', 'timeout error'

  return
