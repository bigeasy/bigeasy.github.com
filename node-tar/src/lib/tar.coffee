# Require Node.js core modules.
events = require "events"
stream = require "stream"

# Require `node-packet`.
packet = require "packet"

module.exports.Writer = class Writer extends events.EventEmitter
  constructor: ->

class Entry extends stream.Stream
  constructor: (@input) ->
    @readable = true

  setEncoding: (encoding) ->
    @_decoder = new (require("string_decoder").StringDecoder)(encoding)

  # For these, we punt.
  pause:          -> @input.pause()
  resume:         -> @input.resume()
  destroySoon:    -> @input.destroySoon()

  destroy: ->
    @input.destroy()
    @readable = false

  _end:           -> @emit "end"
  _error: (error) ->
    @emit "error", error
    @readable = false

  _write: (buffer, offset, length) ->
    slice = buffer.slice(offset, offset + length)
    if @_decoder
      string = @_decoder.write(slice)
      @emit "data", string if string.length
    else
      @emit "data", slice

# The ustar magic message indicates ustar if it contains the characters `u`,
# `s`, `t`, `a`, `r` and `\0`. We compare the magic against the buffer above.
magical = (magic) ->
  for b, i in "ustar\0"
    if magic[i] isnt b.charCodeAt(0)
      return false
  true

class module.exports.Reader extends stream.Stream
  constructor: ->
    @writable = true
    @parser = new packet.Parser(@)
    @parser.packet("basic", [
      "b8[100]z|utf8()"           # The file name.
      "b8[8]z|utf8()|atoi(8)"     # The file mode as a zero padded octal.
      "b8[8]z|utf8()|atoi(8)"     # The owner uid.
      "b8[8]z|utf8()|atoi(8)"     # The owner gid.
      "b8[12]|utf8()|atoi(8)"     # The size.
      "b8[12]|utf8()|atoi(8)"     # The modified time.
      "b8[8]z|utf8()|atoi(8)"     # The checksum.
      "b8"                        # The type flag.
      "b8[100]z|utf8()"           # The link name.
      "b8[6]"                     # The USTAR magic message.
    ].join(","), @basic)
    @parser.packet("ustar", [
      "b8[2]z|utf8()"             # The USTAR version.
      "b8[32]z|utf8()"            # The user name.
      "b8[32]z|utf8()"            # The group name.
      "b8[8]z|utf8()|atoi(8)"     # The device major number.
      "b8[8]z|utf8()|atoi(8)"     # The device minor number.
      "b8[155]z|utf8()"           # The prefix for the name.
      "x8[12]"                    # Nothing.
    ].join(","),  @ustar)
    @parser.packet("skip", [
      "x8[249]"                   # The remaining bytes if not ustar.
    ].join(","), @skip)
    @reset()

  reset: ->
    @mode     = "start"
    @_end      = 0

  basic: (name, mode, uid, gid, size, mtime, checksum, type, linkname, magic, parser) ->
    @header = { name, mode, uid, gid, size, mtime, checksum, type, linkname, magic }

    if magical magic
      @parser.parse("ustar")
    else
      @parser.parse("skip")

  ustar: (version, user, group, devmajor, devminor, prefix) ->
    for k, v of  { version, user, group, devmajor, devminor, prefix }
      @header[k] = v

    @header.ustar     = true
    @header.filename  = @header.prefix + @header.name

    @skip()

  skip: ->
    @header.filename  or= @header.name
    @header.ustar     or= false
    @_entry             = new Entry(@)
    @emit "entry", @header, @_entry
    if @header.size
      @mode     = "data"
      @size     = @header.size
      @blocks   = Math.floor(((@header.size) + 511) /  512)
      @offset   = 0
    else
      @_entry._end()
      @mode     = "start"

  write: (buffer, encoding) ->
    if typeof buffer is "string"
      buffer = new Buffer(buffer, encoding)
    offset = 0
    length = buffer.length
    read = 0
    while @_end < 2 and read < length
      switch @mode
        when "start"
          if buffer[offset + read] is 0
            @mode = "data"
            @size = 0
            @blocks = 1
            @offset = 0
            ending = true
          else
            @mode = "header"
            @parser.parse("basic")
            ending = false
        when "header"
          read += @parser.read(buffer, offset + read, length - read)
        when "data"
          data = Math.min(@size - @offset, length - read)
          if data > 0
            @_entry._write buffer, offset + read, data
            @offset += data
            read  += data
          blocks = Math.min(@blocks * 512 - @offset, length - read)
          @offset += blocks
          read  += blocks
          if @blocks * 512 == @offset
            @mode = "start"
            if ending
              if ++@_end == 2
                @emit "end"
            else
              @_entry._end()
    true

  end: (string, encoding) ->
    write(string, encoding) if string

  destroy: ->
  destroySoon: ->
