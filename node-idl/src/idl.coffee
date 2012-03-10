# Require Node.js core modules.
fs            = require("fs")
sys           = require("sys")
showdown      = require("./../vendor/docco/vendor/showdown").Showdown
fred          = require("path")
{spawn, exec} = require 'child_process'

github = (callback) ->
  remotes =        ""
  git =             spawn "git", [ "remote", "-v" ]
  git.stdout.on     "data", (buffer) -> remotes += buffer.toString()
  git.stderr.on     "data", (buffer) -> process.stdout.write buffer.toString()
  git.on            "exit", (status) ->
    process.exit(1) if status != 0
    remote = /\s+git@github.com:(.*\/.*).git\s+/.exec(remotes)
    callback(remote and remote[1])

# Generate the source by creating a IDL object model to define the project, then
# passing the IDL object model to the templating engine.
#
# The method will create a default `./site/idl.css` if none exists.
generate = (source, destination) ->
  try
    docco = fs.readdirSync("./documentation")
  catch e
    throw e if e.errno isnt 2
  github (remote) ->
    fs.readFile source, "utf8", (error, code) ->
      structure = parse source, code
      structure.github = remote
      structure.docco = docco
      try
        fs.mkdirSync("./site", 0755)
      catch e
        throw e if e.errno isnt 17
      try
        fs.statSync "./site/idl.css"
      catch e
        throw e if e.errno isnt 2
        css = fs.readFileSync "#{__dirname}/../site/idl.css", "utf8"
        fs.writeFileSync "./site/idl.css", css, "utf8"
      munge structure.sections.slice(0), ->
        ejs = "./site/idl.ejs"
        try
          fs.statSync ejs
        catch _
          ejs = "#{__dirname}/../site/idl.ejs"
        fs.readFile ejs, "utf8", (error, code) ->
          throw error if error
          html = template(code) structure
          fs.writeFileSync(destination, html)
      true
    true
  true

class Section
  # Construct a member and link it into its parent.
  constructor: (@parent, @name, @type) ->
    @members    = {}
    @parameters = []
    @blocks     = [ [] ]
    @html       = []
    @parent.members[@name] = this if @parent

  addBlock: ->
    @blocks.push([])

  pushLine: (line) ->
    @blocks[@blocks.length - 1].push(line)

  depth: ->
    depth = 0
    parent = @parent
    while parent.parent
      depth++
      parent = parent.parent
    depth

  shortName: ->
    name = @name
    if /^function|class$/.test(@type)
      params = []
      separator = ""
      for parameter in @parameters
        if parameter.optional
          params.push("#{separator} [#{parameter.name}]")
        else if parameter.variable
          params.push("#{separator} #{parameter.name}...")
        else
          params.push(separator + parameter.name)
        separator = ", "
      name += "(#{params.join("")})"
    else if @type is "event"
      params = []
      separator = ""
      for parameter in @parameters
        if parameter.optional
          params.push("#{separator} [#{parameter.name}]")
        else if parameter.variable
          params.push("#{separator} #{parameter.name}...")
        else
          params.push(separator + parameter.name)
        separator = ", "
      name = "on(\"#{name}\", function (#{params.join("")}) {})"
    name

  fullName: ->
    path = [ @shortName() ]
    parent = @parent
    while parent.parent
      path.push(parent.name)
      parent = parent.parent
    path.reverse()
    path.join(".")

parse = (source, code) ->
  lines     = code.split "\n"
  indent    = -1
  section   = new Section null, null, "narrative"
  sections  = [ section ]
  structure = { sections: sections }
  mode      = "text"
  type      = null
  procedure = null

  for line in lines
    code      = /^\s*```(\S*)\s*$/.exec(line)
    if mode is "text"
      title     = /^\s*#\s+(.*?)\s*$/.exec(line)
      heading   = /^\s*##\s+(.*?)\s*$/.exec(line)

      spaces    = /^(\s*)/.exec(line)[1].length
      directive = /^\s*(namespace|class|event|function|parameter|factory|return):\s*(.*?)\s*$/.exec line
      ns        = /^@(.*)$/.exec line
      member    = /^\s*~(.*)$/.exec line

      structure.title or= title[1] if title

      if code
        section.addBlock()
        section.pushLine code[1]
        mode = "code"
      else if heading
        section = new Section null, heading[1], "narrative"
        section.pushLine line
        sections.push(section)
      else if directive
        [directive, name] = [directive[1], directive[2]]
        if directive == "namespace"
          type        = null
          procedure   = null
          path        = name.split /\./
          namespace   = section

          # Rewind to the parent narrative section.
          while section.parent
            section     = section.parent

          for part, i in path
            new Section namespace, part, "namespace"
            namespace = namespace.members[part]

          section = namespace
          sections.push(section)
        else if directive == "class"
          procedure   = null
          type        = namespace
          path        = name.split /\./
          for part, i in path
             new Section type, part, "class"
            type = type.members[part]
          section = type
          sections.push(section)
        else if directive == "function"
          procedure = section = new Section type or namespace, name, "function"
          sections.push(section)
        else if directive == "event"
          procedure = section = new Section type, name, "event"
          sections.push(section)
        else if directive == "parameter"
          properties = name.split(/\s+/)
          name = properties.shift()
          parameter = section = new Section (procedure || type), name, "parameter"
          for property in properties
            parameter[property] = true
          (procedure || type).parameters.push(parameter)
          indent = spaces
      else if ns
        name        = ns[1].trim()
        type        = null
        procedure   = null
        path        = name.split /\./
        namespace   = section

        # Rewind to the parent narrative section.
        while section.parent
          section     = section.parent

        for part, i in path
          new Section namespace, part, "namespace"
          namespace = namespace.members[part]

        section = namespace
        sections.push(section)
      else if member
        definition = member[1].trim()
        if match = /^new ([^(]+)\((.*)\)$/.exec(definition)
          [ name, parameters ] = match.slice 1
          procedure   = null
          type        = namespace
          path        = name.split /\./
          for part, i in path
             new Section type, part, "class"
            type = type.members[part]
          section = type
          sections.push(section)
        else if match = /^(\S+)\s*\((.*)\)$/.exec definition
          [ name, parameters ] = match.splice 1
          procedure = section = new Section type or namespace, name, "function"
          sections.push(section)
        else if match = /^([\w\d]+)(\?|\.\.\.)?\s*(?:-(.*))$/.exec definition
          [ name, option, rest ] = match.slice 1
          parameter = section = new Section (procedure || type), name, "parameter"
          for key, value of { "?": "optional", "...": "variable" }
            parameter[value] = true if option is key
          (procedure || type).parameters.push(parameter)
          indent = spaces
          section.pushLine(rest) if rest and /\S/.test rest
      else if spaces < indent and /\S/.test(line)
        section = procedure || type
        section.pushLine(line)
      else
        section.pushLine(line)
    else if code
      mode = "text"
      section.addBlock()
    else
      section.pushLine(line)

  structure

munge = (sections, callback) ->
  text = true
  next = -> munge sections, callback
  if sections.length
    parameters = (p for p in sections[0].parameters when p.blocks.length)
    if parameters.length
      munge parameters.slice(0), next
    else
      section     = sections[0]
      exposition  = section.blocks.shift()
      code        = section.blocks.shift()
      if exposition
        section.html.push(showdown.makeHtml exposition.join("\n"))
        if code
          highlight section, code, next
        else
          next()
      else
        sections.shift()
        next()
  else
    callback()

# Micro-templating, originally by John Resig, borrowed by way of
# [Underscore.js](http://documentcloud.github.com/underscore/).
template = (str) ->
  new Function 'obj',
    'var p=[],print=function(){p.push.apply(p,arguments);};' +
    'with(obj){p.push(\'' +
    str  .replace(/\r/g, '\\r')
         .replace(/\n/g, '\\n')
         .replace(/\t/g, '\\t')
         .replace(/'(?=[^%]*%>)/g,"✄")
         .split("'").join("\\'")
         .split("✄").join("'")
         .replace(/<%=(.+?)%>/g, "',$1,'")
         .split("<%").join("');")
         .split("%>").join("p.push('") + "');}return p.join('');"

# Highlights a single chunk of CoffeeScript code, using **Pygments** over stdio,
# and runs the text of its corresponding comment through **Markdown**, using the
# **Github-flavored-Markdown** modification of
# [Showdown.js](http://attacklab.net/showdown/).
#
# We process the entire file in a single call to Pygments by inserting little
# marker comments between each section and then splitting the result string
# wherever our markers occur.
highlight = (section, block, callback) ->
  language = block.shift()
  if language
    pygments = spawn 'pygmentize', ['-l', language, '-f', 'html', '-O', 'encoding=utf-8']
    output   = ''
    pygments.stderr.addListener 'data',  (error)  ->
      puts error if error
    pygments.stdout.addListener 'data', (result) ->
      output += result if result
    pygments.addListener 'exit', ->
      section.html.push(output)
      #output = output.replace(highlight_start, '').replace(highlight_end, '')
      #fragments = output.split language.divider_html
      #for section, i in sections
      #j.u  section.code_html = highlight_start + fragments[i] + highlight_end
      #  section.docs_html = showdown.makeHtml section.docs_text
      callback()
    pygments.stdin.write(block.join("\n"))
    pygments.stdin.end()
  else if block.length
    indent = parseInt(/^(\s*)/.exec(block[0])[1], 10)
    block = for line in block
      line.substring(indent)
    block = block.join("\n")
    block = block.replace(/&/g, "&amp").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    section.html.push("<div class='highlight'><pre>" + block + "</pre></div>")
    callback()


module.exports.generate = generate
