{ FileSystem } = require './FileSystem'
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

    @target = @manager.fs.resolve @target if @target?
    @sources = for source in @sources
        if source instanceof Builder
          source
        else
          @manager.fs.resolve source

    @validateSources()
    @target = @inferTarget() unless @target?
    @name = @target.name

    @invalidateCaches()

  toString: ->
    "Builder.#{@constructor.name}(#{@target?.toString()}, " +
      "[ #{(s?.toString() for s in @sources).join ', '} ])"

  validateSources: ->
    @

  inferTarget: ->
    unless @constructor.targetSuffix?
      throw new Error "#{@} cannot infer target filename"

    idx = @sources[0].getPath().lastIndexOf '.'
    basename = if idx != -1
      @sources[0].getPath().substr(0, idx)
    else
      @sources[0].getPath()

    target = "#{basename}#{@constructor.targetSuffix}"
    @manager.fs.resolve target

  isAffectedBy: (node) ->
    for s in @sources
      if s instanceof FileSystem.Node
        return s.getPath() is node.getPath()
      else if s.isAffectedBy node
        return true
    return false

  # Fired on a builder when the cache must be invalidated. This will be called
  # by the file watcher when a file is modified that affects this target (as
  # determined by isAffectedBy). The default implementation does not support
  # caching, so it is a NOP.
  invalidateCaches: -> undefined

  getMimeType: ->
    mime.lookup @target.name

  getData: ->
    throw new Error "#{@} must implement getData"

  buildToFile: (next) ->
    @manager.fs.mkdirp path.dirname(@target.getPath()), (err) =>
      return next err if err?

      @getData (err, data) =>
        return next err if err?

        @target.writeFile data, next

  handleRequest: (req, res, next) ->
    @getData (err, data) =>
      return next err if err?
      res.setHeader 'Content-Type', @getMimeType
      res.write data
      res.end()

# Import all builders. They self-register.
require './builders/index'
