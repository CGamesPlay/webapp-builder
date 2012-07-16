fs = require 'fs'
path = require 'path'

module.exports = class Node
  @nameWithinPrefix: (name, prefixGetter) ->
    resolved_prefix = path.resolve prefixGetter()
    resolved_name = path.resolve resolved_prefix, name
    relative_name = path.relative resolved_prefix, resolved_name
    if relative_name[0..2] is '../'
      throw new Error "#{name} is not within #{prefixGetter()}"
    relative_name

  @resolve: (name, prefixGetter) ->
    if name instanceof Node
      name = name.name

    name = @nameWithinPrefix name, prefixGetter
    if name.indexOf('%') != -1
      return new Node.Wildcard name, prefixGetter

    try
      stats = fs.statSync path.resolve prefixGetter(), name
      if not stats.isDirectory()
        new Node.File name, prefixGetter
      else
        new Node.Dir name, prefixGetter
    catch err
      new Node name, prefixGetter

  constructor: (@name, @prefixGetter) ->

  toString: -> JSON.stringify(@name)

  getPath: ->
    path.join @prefixGetter(), @name

  nameMatches: (name) ->
    @name == name

  # Returns true if this node could be referencing the given node.
  refersTo: (node) ->
    @getPath() is node.getPath()

  exists: ->
    path.existsSync @getPath()

  getData: (next) ->
    throw new Error "Node.#{@constructor.name} cannot be read"

  resolveUsing: (token) ->
    @

class Node.Wildcard extends Node
  constructor: (@name, @prefixGetter) ->
    super @name, @prefixGetter

    @regexp = new RegExp ('^' + @name + '$')
      .replace(/\./g, '\\\.')
      .replace(/%%/g, '([-/_.a-zA-Z0-9]+)')
      .replace(/%/g, '([-_.a-zA-Z0-9]+)')

  nameMatches: (name) ->
    @regexp.test name

  refersTo: (node) ->
    @nameMatches(node.name) and @prefixGetter() is node.prefixGetter()

  exists: -> false

  extractWildcard: (path) ->
    matches = @regexp.exec path
    if matches then matches[1] else undefined

  resolveUsing: (token) ->
    replaced = @name
      .replace('%%', token)
      .replace('%', path.basename token)
    resolved = Node.resolve replaced, @prefixGetter

  resolveWildcards: (sources, resolved_path) ->
    token = @extractWildcard resolved_path
    throw new Error "Path does not match #{@name}" unless matches?

    for source in sources
      if source instanceof Node
        replaced = source.name
          .replace('%%', token)
          .replace('%', path.basename token)
        Node.resolve replaced, source.prefixGetter
      else
        # Assume it's a builder and ensure we can getBuilderFor the resolved
        # form.
        console.log "Need to resolve #{source} using #{@} and #{resolved_path}"

class Node.File extends Node
  getData: (next) ->
    fs.readFile @getPath(), next

class Node.Dir extends Node
