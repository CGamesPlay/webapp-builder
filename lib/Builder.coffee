Node = require './Node'
fs = require 'fs'
mime = require 'mime'
path = require 'path'

module.exports = class Builder
  @builderTypes: {}

  @registerBuilder: (b) ->
    @builderTypes[b.name] = b
    Builder[b.name] = b

  # Usage:
  # parseArguments([ TARGET, SOURCES, OPTIONS ])
  # parseArguments([ TARGET, SOURCES ])
  # parseArguments([ SOURCES, OPTIONS ])
  # parseArguments([ SOURCES ])
  #
  # Returns: [ TARGET, SOURCES, OPTIONS ]
  @parseArguments: (args) ->
      if args.length == 1
        [ sources ] = args
      else if args.length == 2 and (typeof args[1] == 'string' or
                                   Array.isArray args[1])
        [ target, sources ] = args
      else if args.length == 2
        [ sources, options ] = args
      else
        [ target, sources, options ] = args
      sources = [ sources ] unless Array.isArray sources
      options ?= {}

      [ target, sources, options ]

  constructor: (args...) ->
    [ @target, @sources, @options ] = Builder.parseArguments args
    @manager = @options.manager

    @target = Node.resolve @target, @manager.getTargetPath if @target?
    @sources = (Node.resolve s, @manager.getSourcePath for s in @sources)

    @validateSources()
    @target = @inferTarget() unless @target?
    @name = @target.name

  toString: ->
    "Builder.#{@constructor.name}(#{@target?.toString()}, " +
      "[ #{(s?.toString() for s in @sources).join ', '} ])"

  validateSources: ->
    @

  inferTarget: ->
    unless @constructor.targetSuffix?
      throw new Error "#{@} cannot infer target filename"

    idx = @sources[0].name.lastIndexOf '.'
    basename = if idx != -1
      @sources[0].name.substr(0, idx)
    else
      @sources[0].name

    target = "#{basename}#{@constructor.targetSuffix}"
    Node.resolve target, @manager.getTargetPath

  getBuilderFor: (target_node) ->
    # If this Builder can't build this path, return null
    return null unless @target.nameMatches target_node.name
    if !(@target instanceof Node.Wildcard)
      return @

    else
      # We have to resolve the wildcards to see if we can build this
      token = @target.extractWildcard target_node.name
      @resolveUsing token

  resolveUsing: (token) ->
    can_resolve = true
    resolved_sources = for s in @sources
      resolved_source = s.resolveUsing token
      if not resolved_source? or
          resolved_source instanceof Node and not resolved_source.exists()
        if @manager.getOption('verbose') >= 2
          console.log "#{@} can't build due to missing " +
            "#{path.relative process.cwd(), resolved_source.getPath()}."
        can_resolve = false
        break
      resolved_source
    return null unless can_resolve
    resolved_target = @target.resolveUsing token

    options = {}
    options[k] = v for own k, v of @options

    return new @constructor resolved_target, resolved_sources, options

  isAffectedBy: (node) ->
    for s in @sources
      if s instanceof Node
        if s.refersTo node
          return true
      else if s.isAffectedBy node
        return true
    return false

  getMimeType: ->
    mime.lookup @target.name

  getData: ->
    throw new Error "#{@} must implement getData"

  handleRequest: (req, res, next) ->
    @getData (err, data) =>
      return next err if err?
      res.setHeader 'Content-Type', @getMimeType
      res.write data
      res.end()

# Import all builders. They self-register.
require './builders/index'
