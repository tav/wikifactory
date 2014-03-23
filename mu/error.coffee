# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

define 'µ', (µ, root) ->

  captureStackTrace = Error.captureStackTrace

  newError = (name, defaultMessage) ->
    Exception = (message) ->
      if !(@ instanceof Exception)
        return new Exception(message)
      @name = name
      @message = if typeof message is 'string' then message else defaultMessage
      if captureStackTrace
        captureStackTrace @, Exception
      return
    Exception:: = Object.create Error::,
      constructor:
        value: Exception
    return Exception

  µ.newError = newError

  µ.Abort = newError 'Abort', 'operation was aborted'
  µ.Timeout = newError 'Timeout', 'timeout error'

  return
