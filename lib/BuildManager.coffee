{ Builder } = require './Builder'
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
    disableBuiltin: no

  # Interface designed to be used from the cli. Read the makefile, build the
  # targets.
  @make: (args, finished) ->
    args.runtime = 'build'
    m = new BuildManager args
    m.make args.targets, finished

  constructor: (@externalOptions) ->
    @fs = @externalOptions?.fileSystem ? new FileSystem
    @queue = async.queue @processQueueJob, 1
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
    @makefileProcessor = new MakefileProcessor @,
      disableBuiltin: @getOption 'disableBuiltin'
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
    builder.doBuild()
    builder.once Builder.BUILD_FINISHED, -> done()

  register: (builder) ->
    @builders.unshift(builder)
    builder.on Builder.READY_TO_BUILD, @builderIsReady
    if @getOption('verbose') >= 2
      console.log "Added #{builder}"
    @

  make: (targets, done) ->
    if targets?
      targets = [ targets ] unless Array.isArray targets
      targets = (@resolve @fs.resolve t for t in targets)
    else
      targets = @builders

    results = {}
    waiting_on = targets.length
    for t in targets
      t.queueBuild()
      t.once Builder.BUILD_FINISHED, (b, err) =>
        waiting_on -= 1
        results[t.target.getPath()] = err
        if waiting_on is 0
          done results
    @

  resolve: (path) ->
    for builder in @builders
      return builder if builder.target.equals path
    null

  findTargetsAffectedBy: (path) ->
    b for b in @builders when b.isAffectedBy path
