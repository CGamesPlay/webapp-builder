{ EventEmitter } = require 'events'
{ FileSystem, FileNotFoundException } = require './FileSystem'
fs = require 'fs'
mime = require 'mime'
path = require 'path'

exports.Builder = class Builder extends EventEmitter
  @READY_TO_BUILD = "READY_TO_BUILD"
  @BUILD_FINISHED = "BUILD_FINISHED"

  @builderTypes: {}

  @registerBuilder: (b) ->
    @builderTypes[b.getName()] = b
    Builder[b.getName()] = b

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

  @getName: -> @name

  constructor: (args...) ->
    [ @target, @sources, @options ] = Builder.parseArguments args
    @manager = @options.manager
    @isActive = no
    @waitingOn = {}

    # A list of sources that are inferred from other places--such as files that
    # would have resulted in different builders had they existed, or files that
    # the named sources depend on. Stored as a collection of categories:
    # @impliedSources['alternates'] = [ node, ... ]
    @impliedSources = {}

    @target = @manager.fs.resolve @target if @target?
    @sources = for source in @sources
      if source instanceof Builder
        source
      else
        @manager.fs.resolve source

    @target = @inferTarget() unless @target?
    @validateSources()
    @name = @target.name

    # Listen for finish events so we know when to update ourselves.
    for s in @sources when s instanceof Builder
      s.on Builder.BUILD_FINISHED, @dependencyFinished

  toString: ->
    "Builder.#{@constructor.getName()}(#{@target?.toString()})"

  dump: ->
    @manager.reporter.error "#{@}"
    for s in @sources
      @manager.reporter.error "  #{s}"
    for cat, list of @impliedSources
      for s in list
        @manager.reporter.error "  (#{cat}) #{s}"
    @

  getPath: -> @target.getPath()

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

  removeListeners: ->
    for s in @sources when s instanceof Builder
      s.removeListener Builder.BUILD_FINISHED, @dependencyFinished
    @

  addSource: (s) ->
    s.addListener Builder.BUILD_FINISHED, @dependencyFinished
    @sources.push s

  removeSource: (s) ->
    s.removeListener Builder.BUILD_FINISHED, @dependencyFinished
    @sources = (t for t in @sources when t isnt s)

  updateWithOptions: ->
    # Called after the Makefiles have been read and options applied. Useful to
    # translate sources out of the variant directory.
    for s, i in @sources when s instanceof FileSystem.Node
      if @target.getPath() is s.getPath() and
         @target.getPath() isnt s.getVariantPath()
        s.removeListener Builder.BUILD_FINISHED, @dependencyFinished
        @sources[i] = s = @manager.fs.resolve s.getVariantPath()
        s.on Builder.BUILD_FINISHED, @dependencyFinished

  # When a dependency has been updated, check to see if we need to update
  # ourselves.
  dependencyFinished: (dep, err) =>
    return unless @isActive

    if err?
      @waitingOn[dep.getPath()] = yes
      @emit Builder.BUILD_FINISHED, @, new MissingDependencyError @, dep, err
      return

    delete @waitingOn[dep.getPath()]

    pending = Object.keys(@waitingOn).length
    if pending is 0
      process.nextTick =>
        if @manager.decider.isBuilderCurrent @
          @manager.reporter.debug "#{@} is up to date."
          @isActive = no
          @emit Builder.BUILD_FINISHED, @
        else
          @emit Builder.READY_TO_BUILD, @

  isAffectedBy: (node) ->
    for s in @sources
      return true if s.isAffectedBy node
    for cat, list of @impliedSources
      for s in list
        return true if s.isAffectedBy node
    return false

  getCacheKey: ->
    return @constructor.getName() + ":" + @target.getPath()

  getCacheInfo: ->
    info = {}
    info.impliedSources = {}
    for cat, list of @impliedSources
      info.impliedSources[cat] = (s.getPath() for s in list)
    info

  loadCacheInfo: (info) ->
    if info.impliedSources
      @impliedSources = {}
      for cat, list of info.impliedSources
        @impliedSources[cat] = (@manager.fs.resolve s for s in list)

  queueBuild: ->
    @isActive = yes
    @waitingOn = {}

    for s in @sources when s instanceof Builder
      @waitingOn[s.getPath()] = yes
      s.queueBuild()

    # Fire off a check in case we are already up to date (or have no deps)
    @dependencyFinished @, null

  doBuild: ->
    @buildToFile (err) =>
      @isActive = no
      @emit Builder.BUILD_FINISHED, @, err

  getMimeType: ->
    mime.lookup @getPath()

  getData: (next) ->
    next new Error "#{@} does not implement getData"

  buildToFile: (next) ->
    token = {}
    if @manager.decider.isBuilderCurrent @, token
      @manager.reporter.debug "#{@} is up to date."
      return next()

    @manager.fs.mkdirp path.dirname(@target.getPath()), (err) =>
      return next err if err?

      @target.unlink (err) =>
        return next err if err? and err.code isnt 'ENOENT'

        @getData (err, data) =>
          return next err if err?
          @manager.decider.updateSourceInfoFor @, token
          @target.writeFile data, next

exports.MissingDependencyError = class MissingDependencyError extends Error
  constructor: (@builder, @dependency, @innerException) ->
    @name = @constructor.name
    @message = "Unable to build #{@builder.target} due to dependency error."
    Error.captureStackTrace @, @constructor

  toString: -> "#{@name}: #{@message}\n    #{@innerException}"

exports.DiscoveredNewSourcesError =
class DiscoveredNewSourcesError extends Error
  constructor: (@builder, @sources) ->
    @sources = [ @sources ] unless Array.isArray @sources
    @name = @constructor.name
    @message =
      "Discovered new sources for #{@builder.target} while it was building."
    Error.captureStackTrace @, @constructor

  toString: -> "#{@name}: #{@message}"

# Import all builders. They self-register.
require './builders/index'
