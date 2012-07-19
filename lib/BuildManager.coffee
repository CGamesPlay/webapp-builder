Builder = require './Builder'
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
    @reset()

  reset: ->
    @effectiveOptions = {}
    @builders = []
    @makefileProcessor = new MakefileProcessor @,
      disableBuiltin: @getOption 'disableBuiltin'
    if @getOption('file')?
      @makefileProcessor.loadFile @getOption 'file'
    else
      @makefileProcessor.loadDefault()
    @fs.setVariantDir @getOption('targetPath'), @getOption('sourcePath')
    if @getOption('verbose') >= 2
      console.log "Done loading makefiles.\n"

  getOption: (opt) ->
    @effectiveOptions[opt] ?
      @externalOptions?[opt] ?
      BuildManager.defaultOptions[opt]

  setOption: (opt, value) ->
    @effectiveOptions[opt] = value

  make: (targets, done) ->
    targets = [ targets ] unless Array.isArray targets
    if targets.length > 0
      targets = (@fs.resolve t for t in targets)
    else
      throw new Error 'Not implemented yet. Explicit targets pls'

    generate_task = (builder) -> (next, results) ->
      task =
        builder: builder
        dependencies: results
      queue.push task, next

    process_queue = (task, next) =>
      builder = task.builder

      # Verify all sources built correctly
      for s, i in builder.sources when s instanceof Builder
        dep = task.dependencies[s.target.name]
        if dep.error
          return next null,
            builder: builder
            error: true

      if @getOption('verbose') is 1
        console.log "Building #{builder.target.name}..."
      else if @getOption('verbose') >= 2
        console.log "Building #{builder.target.name} using #{builder}..."

      # Perform this task
      builder.buildToFile (err, result) =>
        if err?
          console.error "While building #{builder}:"
          if @getOption('verbose') >= 2
            console.error "Using: #{builder}"
          console.error "  #{err.stack}"

        next null,
          builder: builder
          error: err

    jobs_finished = (err, results) ->
      # Exceptions should be handled by the async queue so if we get one here
      # it's unexpected.
      throw err if err?

      error = null
      error ?= target.error for name, target of results
      console.error "Build failed due to errors" if error?

      done? error

    # Create a queue for doing the actual building
    queue = async.queue process_queue, @getOption('concurrency')

    # Construct a dependency graph
    try
      tasks = @constructDependencyTreeFor targets, generate_task
    catch error
      console.error "#{error.name}: #{error.message}"
      return done error

    # And start everything going
    async.auto tasks, jobs_finished

  register: (builder) ->
    @builders.unshift(builder)
    if @getOption('verbose') >= 2
      console.log "Added #{builder}"
    @

  resolve: (path) ->
    for builder in @builders
      return builder if builder.target.equals path
    null

  # Construct a dependency tree suitable for use with async#auto.
  constructDependencyTreeFor: (targets, task_generator) ->
    tasks = {}
    queueDependencies = (target) =>
      b = @resolve target
      if b?
        task = tasks[target.getPath()] ?= []
        for s in b.sources when s instanceof Builder
          task.push s.target.getPath()
          queueDependencies s.target
        task.push task_generator b if task_generator?
      else
        throw new Error "No builders available for #{target.getPath()}"

    queueDependencies t for t in targets
    tasks

  findTargetsAffectedBy: (path) ->
    b for b in @builders when b.isAffectedBy path
