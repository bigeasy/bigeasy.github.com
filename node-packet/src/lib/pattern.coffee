# This module is separated for isolation during testing. It is not meant to be
# exposed as part of the public API.

# Regular expression to match a pipeline argument, expressed as a JavaScript
# scalar, taken in part from [json2.js](http://www.JSON.org/json2.js). 
{argument, constant} = require "./argument"
next = /^(-?)([xbl])(\d+)([fha]?)(.*)$/

##### packing(pattern)
# Parse bit packing.

# The `pattern` is the bit packing pattern to parse.
packing = (pattern, size, index) ->

  fields  = []
  rest    = pattern

  loop
    # Match an element pattern.
    match = /^(-?)([xb])(\d+)(.*)$/.exec rest
    if not match
      throw new Error "invalid pattern at #{index}"

    return
    # Convert the match into an object.
    f =
      signed:     !!match[1]
      endianness: match[2]
      bits:       parseInt(match[3], 10)
      type:       'n'

    size -= f.bits
    if size < 0
      throw new Error "bit field overflow at #{index}"

    # Move the character position up to the bit count.
    index++ if f.signed
    index++

    # Check for a valid bit size.
    if f.bits == 0
      throw new Error("bit size must be non-zero at #{index}")

    # Move the character position up to the rest of the pattern.
    index += match[3].length
    index++ if match[4]

  if size != 0
    throw new Error "bit field underflow at #{index}"

pass = -> true

number = (pattern, index) ->
  if match = /^(&)(\d+)(.*)$/.exec pattern
    [ !! match[1], parseInt(match[2], 10), index + match[1].length + match[2].length, match[2] ]
  else if match = /^(&)0x([0-9a-f]+)(.*)$/i.exec pattern
    [ !! match[1], parseInt(match[2], 16), index + match[1].length + match[2].length, match[2] ]
  else
    throw new Error "invalid pattern at #{index}"

between = (mininum, maximum) ->
  (value) -> minimm <= value && value <= maximum

equal = (target) ->
  (value) -> value is target

mask = (mask) ->
  (value) -> (value & mask) is mask

branch = (pattern, index) ->
  rest = pattern
  branches = []
  branch = {}
  while rest
    match = /^([^:]+):(.*)$/.exec rest
    if match
      condition = match[1]
      rest = match[2]
      [ mask, value, index, rest ] = number condition, index
      if not mask
        if  rest[0] is "-"
          index++
          [ mask, maximum, index, rest ] = number condition.substring(1), index
          if mask
            throw new Error "invalid pattern at #{index}"
          branch.condition = between value, maximum
        else
          branch.condition = equal value
      else
        branch.condition = mask value
    else
      branch.condition = pass
    match = /^([^|]+)|(.*)$/
    pipe = rest.indexOf("|")
    if match
      alternate = match[1]
      rest = match[2]
    else
      alternate = rest
      rest = ""
    pattern({ pattern: alternate, index, next: element })
    index += alternate.length
    index += 1 if match

##### parse(pattern)
# Parse a pattern and create a list of fields.

# The `pattern` is the pattern to parse.
module.exports.parse = (pattern) -> parse({ pattern, index: 0, next })

parse = (o) ->
  fields          = []
  lengthEncoded   = false

  # We chip away at the pattern, removing the parts we.ve match, while keeping
  # track of the index separately for error messages.
  rest            = o.pattern
  index           = o.index
  loop
    # Match a packet pattern.
    match = o.next.exec(rest)
    if !match
      throw  new Error "invalid pattern at #{index}"

    # The remainder of the pattern, if any.
    rest = match.pop()

    # Convert the match into an object.
    f =
      signed:     !!match[1] || match[4] == "f"
      endianness: if match[2] == 'n' then 'b' else match[2]
      bits:       parseInt(match[3], 10)
      type:       match[4] || 'n'

    # Move the character position up to the bit count.
    index++ if f.signed
    index++

    # Check for a valid character
    if f.bits == 0
      throw new Error("bit size must be non-zero at #{index}")
    if f.bits % 8
      throw new Error("bits must be divisible by 8 at #{index}")
    if f.type == "f" and !(f.bits == 32 || f.bits == 64)
      throw Error("floats can only be 32 or 64 bits at #{index}")

    # Move the character position up to the rest of the pattern.
    index += match[3].length
    index++ if match[4]

    # Set the implicit fields.
    f.type      = "a" if f.bits > 64 and f.type == "n"
    f.bytes     = f.bits / 8
    f.unpacked  = f.signed or f.bytes > 8 or "ha".indexOf(f.type) != -1

    # Check for alternation.
    alternation = /^\(([^)]+)\)(.*)$/.exec(rest)
    if alternation
      f.alternation = branches alternation[1]
      rest          = alternation[2]

    # Check for bit backing.
    pack = /^{([^b-][^}]+)}(.*)$/.exec(rest)
    if pack
      f.unpacked  = true
      f.packing   = packing pack[1]
      rest        = pack[2]

    # Check if this is a length encoding.
    length = /^\/(.*)$/.exec(rest)
    if length
      f.length = true
      rest = length[1]
      f.arrayed = false
      f.repeat = 1
      lengthEncoded = true
      fields.push(f)
      # Nothing else can apply to a length encoding.
      continue

    f.repeat    = 1
    f.arrayed   = lengthEncoded
    if not lengthEncoded
      # Check for structure modifiers.
      arrayed = /^\[(\d+)\](.*)$/.exec(rest)
      if arrayed
        f.arrayed = true
        f.repeat = parseInt(arrayed[1], 10)
        index++
        if f.repeat == 0
          throw new Error("array length must be non-zero at " + index)
        index += arrayed[1].length + 1
        rest = arrayed[2]

    # Check for a padding value.
    padding = /^{(0x|0)?(\d+)}(.*)$/.exec(rest)
    if padding
      base      = padding[1]
      pad       = padding[2]
      rest      = padding[3]

      if base
        if base == "0x"
          f.padding = parseInt(pad, 16)
        else
          f.padding = parseInt(pad, 8)
      else
        f.padding = parseInt(pad, 10)

    # Check for zero termination.
    tz = /^z(?:<(.*?)>)?(.*)$/.exec(rest)
    if tz
      index += rest.length - tz[2].length
      f.terminator = tz[1] or "\0"
      f.arrayed = true
      rest = tz[2]
      if f.repeat is 1
        f.repeat = Number.MAX_VALUE

    # Parse piplines.
    while pipe = /^\|(\w[\w\d]*)\((\)?)(.*)/.exec(rest)
      index          += rest.length - pipe[3].length
      transform       = { name: pipe[1], parameters: [] }
      rest            = pipe[3]
      hasArgument     = not pipe[2]

      while hasArgument
        arg         = argument.exec(rest)
        index      += rest.length - arg[3].length
        value       = eval(arg[1])
        hasArgument = arg[2].indexOf(")") is -1
        rest        = arg[3]

        transform.parameters.push(value)

      (f.transforms or= []).push(transform)

    # Named pattern.
    name = /\s*=>\s*(\w[\w\d]+)\s*(.*)/.exec(rest)
    if name
      index += rest.length - name[2].length
      f.name = name[1]
      rest = name[2]

    # Record the new field pattern object.
    fields.push(f)

    # A comma indicates that we're to continue.
    more = /\s*,\s*(.*)/.exec(rest)
    break if not more

    # Reset for the next iteration.
    rest = more[1]
    lengthEncoded = false

  if /\S/.test(rest)
    throw  new Error "invalid pattern at #{index}"

  fields
