Node = require './Node'
mime = require 'mime'
path = require 'path'

module.exports = class Builder
  @builderTypes: {}

  # Usage:
  # Builder.factory(TARGET, SOURCES, OPTIONS)
  # Builder.factory(TARGET, SOURCES)
  # Builder.factory(SOURCES, OPTIONS)
  # Builder.factory(SOURCES)
  @factory: (args...) ->
    if args.length == 1
      [ sources ] = args
    else if args.length == 2 and (typeof args[1] == 'string' or
                                 Array.isArray args[1])
      [ target, sources ] = args
    else if args.length == 2
      [ sources, options ] = args
    else
      [ target, sources, options ] = args

    maker = options?.maker ? require('./Maker').currentMaker

    target = Node.resolve target, maker.getTargetPath if target?
    sources = [ sources ] unless Array.isArray sources
    sources = for source in sources
      Node.resolve source, maker.getSourcePath
    options ?= {}

    options.maker = maker
    options[k] = v for k, v of maker.options when not options[k]?

    new @(target, sources, options)

  @registerBuilder: (b) ->
    @builderTypes[b.name] = b.factory.bind b

  constructor: (@target, @sources, @options) ->
    @maker = @options.maker

    @validateSources()
    @target = @inferTarget() unless @target?
    @name = @target.name

    @maker.registerBuilder @ unless @options.implied

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
    Node.resolve target, @maker.getTargetPath

  getBuilderFor: (path) ->
    # If this Builder can't build this path, return null
    return null unless @target.nameMatches path
    if !(@target instanceof Node.Wildcard)
      return @

    else
      # We have to resolve the wildcards to see if we can build this
      token = @target.extractWildcard path
      @resolveUsing token

  resolveUsing: (token) ->
    can_resolve = true
    resolved_sources = for s in @sources
      resolved_source = s.resolveUsing token
      if not resolved_source? or
          resolved_source instanceof Node and not resolved_source.exists()
        if @maker.options.verbose >= 2
          console.log "#{@} can't build due to missing " +
            "#{resolved_source.getPath()}."
        can_resolve = false
        break
      resolved_source
    return null unless can_resolve
    resolved_target = @target.resolveUsing token

    options = {}
    options[k] = v for own k, v of @options
    options.implied = true

    return new @constructor resolved_target, resolved_sources, options

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
