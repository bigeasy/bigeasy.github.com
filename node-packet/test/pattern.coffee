{TwerpTest} = require "twerp"
{parse}     = require "pattern"

class exports.PacketTest extends TwerpTest
  trap: (callback) ->
    try
      callback()
    catch e
      @ok 1

  'test: parse a single byte': (done) ->
    field = parse('b8')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single signed byte': (done) ->
    field = parse('-b8')
    @deepEqual field, [
      { signed: true
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single 16 bit number': (done) ->
    field = parse('b16')
    @deepEqual field, [
      { signed: false
      , bits: 16
      , endianness: 'b'
      , bytes: 2
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single signed 16 bit number': (done) ->
    field = parse('-b16')
    @deepEqual field, [
      { signed: true
      , bits: 16
      , endianness: 'b'
      , bytes: 2
      , type: 'n'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single big-endian 16 bit number': (done) ->
    field = parse('b16')
    @deepEqual field, [
      { signed: false
      , bits: 16
      , endianness: 'b'
      , bytes: 2
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single little-endian 16 bit number': (done) ->
    field = parse('l16')
    @deepEqual field, [
      { signed: false
      , bits: 16
      , endianness: 'l'
      , bytes: 2
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single signed little-endian 16 bit number': (done) ->
    field = parse('-l16')
    @deepEqual field, [
      { signed: true
      , bits: 16
      , endianness: 'l'
      , bytes: 2
      , type: 'n'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single 16 bit skip': (done) ->
    field = parse('x16')
    @deepEqual field, [
      { signed: false
      , bits: 16
      , endianness: 'x'
      , bytes: 2
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a signed little-endian 16 bit number followed by a byte': (done) ->
    field = parse('-l16, b8')
    @deepEqual field,
    [
      { signed: true
      , bits: 16
      , endianness: 'l'
      , bytes: 2
      , type: 'n'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ,
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a number greater than 64 bits with no type.': (done) ->
    field =  parse('b128')
    @deepEqual field, [
      { signed: false
      , bits: 128
      , endianness: 'b'
      , bytes: 16
      , type: 'a'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a 16 bit hex string.': (done) ->
    field = parse('l16h')
    @deepEqual field, [
      { signed: false
      , bits: 16
      , endianness: 'l'
      , bytes: 2
      , type: 'h'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single 32 bit float.': (done) ->
    field = parse('b32f')
    @deepEqual field, [
      { signed: true
      , bits: 32
      , endianness: 'b'
      , bytes: 4
      , type: 'f'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a single 64 bit float.': (done) ->
    field = parse('b64f')
    @deepEqual field, [
      { signed: true
      , bits: 64
      , endianness: 'b'
      , bytes: 8
      , type: 'f'
      , unpacked: true
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse an array of 8 bytes.': (done) ->
    field = parse('b8[8]')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: 8
      }
    ]
    done 1

  'test: parse a length encoded array of 16 bit numbers.': (done) ->
    field = parse('b8/b16')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      , length: true
      }
    ,
      { signed: false
      , bits: 16
      , endianness: 'b'
      , bytes: 2
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: 1
      }
    ]
    done 1

  'test: parse a list of bytes terminated by zero.': (done) ->
    field = parse('b8z')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      }
    ]
    done 1

  'test: parse a zero terminated array of 8 bytes zero filled.': (done) ->
    field = parse('b8[8]{0}z')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: 8
      , terminator: "\0"
      , padding: 0
      }
    ]
    done 1

  'test: parse a zero terminated array of 8 bytes 0x10 filled.': (done) ->
    field = parse('b8[8]{0x10}z')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: 8
      , terminator: "\0"
      , padding: 16
      }
    ]
    done 1

  'test: parse a zero terminated array of 8 bytes 010 filled.': (done) ->
    field = parse('b8[8]{010}z')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: 8
      , terminator: "\0"
      , padding: 8
      }
    ]
    done 1

  'test: parse an list of bytes termianted by zero piped to a transform.': (done) ->
    field = parse('b8z|str()')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "str"
          , parameters: []
          }
        ]
      }
    ]
    done 1

  'test: parse a transform a with a single parameter.': (done) ->
    field = parse('b8z|str("utf8")')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "str"
          , parameters: [ "utf8" ]
          }
        ]
      }
    ]
    done 1

  'test: parse a transform followed by a 16 bit number.': (done) ->
    field = parse('b8z|str("utf8"), b16')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "str"
          , parameters: [ "utf8" ]
          }
        ]
      }
    ,
      { signed: false
      , bits: 16
      , endianness: 'b'
      , bytes: 2
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      }
    ]
    done 1

  'test: parse a transform with an integer parameter.': (done) ->
    field = parse('b8z|twiddle(8)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ 8 ]
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a negative integer parameter.': (done) ->
    field = parse('b8z|twiddle(-8)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ -8 ]
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with an float parameter.': (done) ->
    field = parse('b8z|twiddle(' + Number.MAX_VALUE + ')')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ Number.MAX_VALUE ]
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a negative float parameter.': (done) ->
    field = parse('b8z|twiddle(' + Number.MIN_VALUE + ')')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ Number.MIN_VALUE ]
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a null parameter.': (done) ->
    field = parse('b8z|twiddle(null)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ null ],
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a true parameter.': (done) ->
    field = parse('b8z|twiddle(true)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ true ],
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a false parameter.': (done) ->
    field = parse('b8z|twiddle(false)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ false ],
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a single quoted string parameter.': (done) ->
    field = parse("b8z|twiddle('test: parse a \\u00DF b \\' c')")
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ "a \u00DF b \" c" ],
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a single quoted string parameter.': (done) ->
    field = parse('b8z|twiddle("a \\u00DF b \\" c")')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ "a \u00DF b \" c" ],
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with a two parameters.': (done) ->
    field = parse('b8z|twiddle("utf8", 8)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ "utf8", 8 ],
          }
        ]
      }
    ]
    done 1

  'test: parse a transform with many parameters.': (done) ->
    field = parse('b8z|twiddle("utf8", 8, 8.1, false)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "twiddle"
          , parameters: [ "utf8", 8, 8.1, false ],
          }
        ]
      }
    ]
    done 1

  'test: parse a two transforms in a row.': (done) ->
    field = parse('b8z|utf8()|atoi(8)')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "utf8"
          , parameters: []
          }
          ,
          { name: "atoi"
          , parameters: [ 8 ]
          }
        ]
      }
    ]
    done 1

  'test: parse a named element.': (done) ->
    field = parse('b8z|utf8()|atoi(8) => mode, b32 => length')
    @deepEqual field, [
      { signed: false
      , bits: 8
      , endianness: 'b'
      , bytes: 1
      , type: 'n'
      , name: "mode"
      , unpacked: false
      , arrayed: true
      , repeat: Number.MAX_VALUE
      , terminator: "\0"
      , transforms:
        [
          { name: "utf8"
          , parameters: []
          }
          ,
          { name: "atoi"
          , parameters: [ 8 ]
          }
        ]
      },
      { signed: false
      , endianness: 'b'
      , bits: 32
      , bytes: 4
      , type: 'n'
      , unpacked: false
      , arrayed: false
      , repeat: 1
      , name: "length"
      }
    ]
    done 1

  'test: parse utter nonsense.': (done) ->
    @trap -> parse("blurdy")
    done 1

  'test: parse a 7 bit pattern.': (done) ->
    @trap -> parse("b7")
    done 1

  'test: parse a 0 bit pattern.': (done) ->
    @trap -> parse("b0")
    done 1

  'test: parse a float pattern other than 32 or 64 bits.': (done) ->
    @trap -> parse('b16f')
    done 1

  'test: parse two patterns together without a comma.': (done) ->
    @trap -> parse('l16b8')
    done 1

  'test: parse a little-endian integer packed in an integer.': (done) ->
    @trap -> parse('b8{l4,b4}')
    done 1
