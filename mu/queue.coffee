# This Queue implementation has been ported over from the JavaScript version
# in Bluebird.
#
# Changes to this file by The Wikifactory Authors are in the Public Domain.
# See the Wikifactory UNLICENSE file for details.
#
# Copyright (c) 2014 Petka Antonov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:</p>
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

define 'µ', (µ, root) ->

  copyArray = (src, srcIndex, dst, dstIndex, len) ->
    `for (var j = 0; j < len; ++j) {
        dst[j + dstIndex] = src[j + srcIndex];
    }`
    return

  pow2AtLeast = (n) ->
    n = n >>> 0
    n = n - 1
    n = n | (n >> 1)
    n = n | (n >> 2)
    n = n | (n >> 4)
    n = n | (n >> 8)
    n = n | (n >> 16)
    return n + 1

  µ.Queue = Queue = (capacity) ->
    this._c = pow2AtLeast(Math.min(Math.max(16, capacity), 1073741824))
    this._l = 0
    this._f = 0
    this._make()
    return

  Queue.prototype =

    _one: (arg) ->
      length = this.length()
      this._check(length + 1)
      i = (this._f + length) & (this._c - 1)
      this[i] = arg
      this._l = length + 1
      return

    push: (fn, receiver, arg) ->
      length = this.length() + 3
      if this._c < length
        # The fast array copies expect the underlying array to be filled completely.
        this._one fn
        this._one receiver
        this._one arg
        return
      j = this._f + length - 3
      this._check(length)
      wrapMask = this._c - 1
      this[(j + 0) & wrapMask] = fn
      this[(j + 1) & wrapMask] = receiver
      this[(j + 2) & wrapMask] = arg
      this._l = length
      return

    shift: ->
      front = this._f
      ret = this[front]
      this[front] = undefined
      this._f = (front + 1) & (this._c - 1)
      this._l--
      return ret

    length: ->
      this._l

    _make: ->
      len = this._c
      `for (var i = 0; i < len; ++i) {
        this[i] = void 0;
      }`
      return

    _check: (size) ->
      if this._c < size
        this._resizeTo(this._c << 3)
      return

    _resizeTo: (capacity) ->
      oldFront = this._f
      oldCapacity = this._c
      oldQueue = new Array(oldCapacity)
      length = this.length()
      copyArray(this, 0, oldQueue, 0, oldCapacity)
      this._c = capacity
      this._make()
      this._f = 0
      # Can perform direct linear copy.
      if (oldFront + length) <= oldCapacity
        copyArray(oldQueue, oldFront, this, 0, length)
      else
        # Cannot perform copy directly, perform as much as possible
        # at the end, and then copy the rest to the beginning of the buffer.
        lengthBeforeWrapping = length - ((oldFront + length) & (oldCapacity - 1))
        copyArray(oldQueue, oldFront, this, 0, lengthBeforeWrapping)
        copyArray(oldQueue, 0, this, lengthBeforeWrapping, length - lengthBeforeWrapping)
      return

  return
