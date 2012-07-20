{ EventEmitter } = require 'events'
{ FileSystem, FileNotFoundException } = require './FileSystem'
fs = require 'fs'
mime = require 'mime'
path = require 'path'

exports.Builder = class Builder extends EventEmitter
  @READY_TO_BUILD = "READY_TO_BUILD"
  @BUILD_FINISHED = "BUILD_FINISHED"

  @builderTypes: {}
  @builderList: []

  @registerBuilder: (b) ->
    @builderTypes[b.name] = b
    @builderList.unshift b
    Builder[b.name] = b

  @createBuilderFor: (manager, target) ->
    idx = target.getPath().lastIndexOf '.'
    basename = if idx != -1
      target.getPath().substr 0, idx
    else
      target.getPath()

    builder = null
    for type in @builderList
      try
        if not type.targetSuffix or
            target.getPath() is "#{basename}#{type.targetSuffix}"
          if type.createBuilderFor isnt Builder.createBuilderFor
            builder = type.createBuilderFor manager, target
            break if builder?

          else if type.targetSuffix?
            unless type.sourceSuffix?
              throw new Error "Builder.#{type.name} does not define a " +
                "source suffix and does not override createBuilderFor."

            found_source = manager.fs.resolve "#{basename}#{type.sourceSuffix}"
            # This will throw if file not found
            found_source.getReadablePath()
            builder = new type target, [ found_source ],
              manager: manager
            break

      catch err
        if err instanceof FileNotFoundException
          if manager.getOption('verbose') >= 2
            console.log "Builder.#{type.name} cannot build " +
              "#{target} because #{err.filename} was not found."

        else
          console.error "Builder.#{type.name} cannot build " +
            "#{target} due to #{err}"

    if builder?
      manager.register builder
    builder

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
    @isActive = no
    @waitingOn = {}

    @target = @manager.fs.resolve @target if @target?
    @sources = for source in @sources
      if source instanceof Builder
        source
      else
        @manager.fs.resolve source

    @validateSources()
    @target = @inferTarget() unless @target?
    @name = @target.name

    # Listen for finish events so we know when to update ourselves.
    for s in @sources when s instanceof Builder
      s.on Builder.BUILD_FINISHED, @dependencyFinished

  toString: ->
    "Builder.#{@constructor.name}(#{@target?.toString()})"

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
        # XXX check to see if we actually need to build or if we are already up
        # to date.
        @emit Builder.READY_TO_BUILD, @

  isAffectedBy: (node) ->
    for s in @sources
      if s instanceof FileSystem.Node
        return s.getPath() is node.getPath()
      else if s.isAffectedBy node
        return true
    return false

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
      @emit Builder.BUILD_FINISHED, @, err

  getMimeType: ->
    mime.lookup @getPath()

  getData: (next) ->
    next new Error "#{@} does not implement getData"

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

exports.MissingDependencyError = class MissingDependencyError extends Error
  constructor: (@builder, @dependency, @innerException) ->
    @name = @constructor.name
    @message = "Unable to build #{@builder.target} due to dependency error."
    Error.captureStackTrace @, @constructor

  toString: -> "#{@name}: #{@message}\n    #{@innerException}"

# Import all builders. They self-register.
require './builders/index'
