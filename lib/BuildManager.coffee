{ Builder, MissingDependencyError, DiscoveredNewSourcesError } = require './Builder'
{ Decider } = require './Decider'
{ FileSystem } = require './FileSystem'
MakefileProcessor = require './MakefileProcessor'
Reporter = require './Reporter'
async = require 'async'
fs = require 'fs'
path = require 'path'

module.exports = class BuildManager
  @defaultOptions:
    cacheFilename: '.webapp-cache.json'
    concurrency: require('os').cpus().length
    deciderType: 'MD5'
    sourcePath: '.'
    targetPath: 'out'
    verbose: Reporter.WARNING

  constructor: (@externalOptions = {}) ->
    @effectiveOptions = {}
    @cacheInfo = {}
    @fs = @externalOptions.fileSystem ? new FileSystem
    @reporter = new Reporter
      logLevel: @getOption 'verbose'
    @queue = async.queue @processQueueJob, 1
    @loadCache()
    @reset()

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
    @reporter.setLogLevel @getOption 'verbose'
    @queue.concurrency = @getOption 'concurrency'
    @decider = new Decider[@getOption 'deciderType'] @
    @decider.loadCacheInfo @cacheInfo.decider if @cacheInfo.decider?

    for b in @builders
      b.updateWithOptions()

    @reporter.verbose "Done loading makefiles.\n"

  getOption: (opt) ->
    @effectiveOptions[opt] ?
      @externalOptions[opt] ?
      BuildManager.defaultOptions[opt]

  setOption: (opt, value) ->
    @effectiveOptions[opt] = value

  loadCache: ->
    try
      path = @fs.resolve(@getOption 'cacheFilename').getPath()
      data = fs.readFileSync path, 'utf-8'
      @cacheInfo = JSON.parse(data)
      @reporter.verbose "Loaded cache information."
    catch _
      # Gulp

  saveCache: ->
    cache_info =
      builders: {}
      decider: @decider.getCacheInfo()

    cache_info.builders[b.getCacheKey()] = b.getCacheInfo() for b in @builders

    path = @fs.resolve(@getOption 'cacheFilename').getPath()
    fs.writeFileSync path, JSON.stringify(cache_info)

  builderIsReady: (builder) =>
    @queue.push builder

  processQueueJob: (builder, done) =>
    @reporter.debug "Building #{builder.getPath()} using #{builder}"
    finished_handler = (b, err) =>
      if err instanceof MissingDependencyError
        @reporter.warning "Unable to build #{b.getPath()} due to " +
          "previous failures."
      else if err instanceof DiscoveredNewSourcesError
        @reporter.debug "Restarting #{b.getPath()} because it discovered new " +
          "sources."
      else if err
        @reporter.error "Error while building #{b.getPath()}\n#{err.stack}\n"

      done()

    builder.doBuild()
    builder.once Builder.BUILD_FINISHED, finished_handler

  register: (builder) ->
    @builders.unshift(builder)
    builder.on Builder.READY_TO_BUILD, @builderIsReady

    if @cacheInfo.builders?[builder.getCacheKey()]
      builder.loadCacheInfo @cacheInfo.builders[builder.getCacheKey()]

    @reporter.verbose "Added #{builder}"
    @

  unregister: (needle) ->
    @builders = (b for b in @builders when b isnt needle)
    needle.removeListener Builder.READY_TO_BUILD, @builderIsReady
    needle.removeListeners()
    @reporter.verbose "Removed #{needle}"
    @

  make: (targets, done) ->
    if not targets? or targets.length == 0
      targets = @builders
    else
      targets = [ targets ] unless Array.isArray targets
      targets = (@fs.resolve t for t in targets)

    results = {}
    waiting_on = 0

    target_finished = (b, err) =>
      if err instanceof DiscoveredNewSourcesError
        b.queueBuild()
        b.once Builder.BUILD_FINISHED, target_finished
        return

      waiting_on -= 1
      results[b.getPath()] = err

      # Update cache info for this builder
      @cacheInfo.builders ?= {}
      @cacheInfo.builders[b.getCacheKey()] = b.getCacheInfo()

      if waiting_on is 0
        process.nextTick ->
          done results

    for t in targets
      b = @resolve t
      unless b?
        # Try to guess what builder to use
        b = Builder.generateBuilder manager: @, target: t.getVariantPath()

      if b?
        waiting_on += 1
        b.queueBuild()
        b.once Builder.BUILD_FINISHED, target_finished
      else
        error = new Error "No builder available for #{t}."
        results[t.getPath()] = error
        @reporter.error "Error: #{error.message}"

    if waiting_on is 0
      process.nextTick ->
        done results
    @

  resolve: (node) ->
    for builder in @builders
      return builder if builder.target.equals node
    null

  findTargetsAffectedBy: (node) ->
    b for b in @builders when b.isAffectedBy node

  dumpAllBuilders: ->
    b.dump() for b in @builders
