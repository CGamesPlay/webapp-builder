{ Builder, MissingDependencyError } = require './Builder'
MakefileProcessor = require './MakefileProcessor'
{ FileSystem } = require './FileSystem'
async = require 'async'
path = require 'path'

module.exports = class BuildManager
  @defaultOptions:
    concurrency: 1
    sourcePath: '.'
    targetPath: 'out'
    verbose: 0

  constructor: (@externalOptions) ->
    @fs = @externalOptions?.fileSystem ? new FileSystem
    @queue = async.queue @processQueueJob, 1
    @reset()
    if @getOption('watchFileSystem')
      @fs.startWatching()

  reset: ->
    if @queue.length() isnt 0
      throw new Error "Attempted to reset BuildManager while builds are in " +
        "progress."
    # Remove listeners for builders
    if @builders?
      for b in @builders
        b.removeListener Builder.READY_TO_BUILD, @builderIsReady

    @effectiveOptions = {}
    @builders = []
    @makefileProcessor = new MakefileProcessor @
    if @getOption('file')?
      @makefileProcessor.loadFile @getOption 'file'
    else
      @makefileProcessor.loadDefault()

    @fs.setVariantDir @getOption('targetPath'), @getOption('sourcePath')
    @queue.concurrency = @getOption 'concurrency'

    if @getOption('verbose') >= 2
      console.log "Done loading makefiles.\n"

  getOption: (opt) ->
    @effectiveOptions[opt] ?
      @externalOptions?[opt] ?
      BuildManager.defaultOptions[opt]

  setOption: (opt, value) ->
    @effectiveOptions[opt] = value

  builderIsReady: (builder) =>
    @queue.push builder

  processQueueJob: (builder, done) =>
    if @getOption('verbose') > 0
      console.log "Building #{builder.getPath()} using #{builder}"
    builder.doBuild()
    builder.once Builder.BUILD_FINISHED, (b, err) ->
      if err instanceof MissingDependencyError
        console.error "Unable to build #{b.getPath()} due to " +
          "previous failures."
      else if err
        console.error "Error while building #{b.getPath()}"
        console.error err.stack
        console.error ""

      done()

  register: (builder) ->
    @builders.unshift(builder)
    builder.on Builder.READY_TO_BUILD, @builderIsReady
    if @getOption('verbose') >= 2
      console.log "Added #{builder}"
    @

  unregister: (needle) ->
    @builders = (b for b in @builders when b isnt needle)
    needle.removeListener Builder.READY_TO_BUILD, @builderIsReady
    needle.removeListeners()
    if @getOption('verbose') >= 2
      console.log "Removed #{needle}"
    @

  make: (targets, done) ->
    if not targets? or targets.length == 0
      targets = @builders
    else
      targets = [ targets ] unless Array.isArray targets
      targets = (@fs.resolve t for t in targets)

    results = {}
    waiting_on = targets.length
    temporary_builders = []

    target_finished = (b, err) =>
      waiting_on -= 1
      results[b.getPath()] = err

      if waiting_on is 0
        @unregister b for b in temporary_builders
        done results

    for t in targets
      b = @resolve t
      unless b?
        # Try to guess what builder to use
        b = Builder.createBuilderFor @, t
        temporary_builders.push b if b?

      if b?
        b.queueBuild()
        b.once Builder.BUILD_FINISHED, target_finished
      else
        error = new Error "No builder available for #{t}."
        results[t.getPath()] = error
        console.error "Error: #{error.message}"
    @

  resolve: (node) ->
    for builder in @builders
      return builder if builder.target.equals node
    null

  findTargetsAffectedBy: (node) ->
    b for b in @builders when b.isAffectedBy node

  dumpAllBuilders: ->
    b.dump() for b in @builders
