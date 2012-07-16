Builder = require './Builder'
MakefileProcessor = require './MakefileProcessor'
Node = require './Node'
async = require 'async'
path = require 'path'

module.exports = class BuildManager
  @defaultOptions:
    sourcePath: path.resolve '.'
    targetPath: path.resolve 'out'
    verbose: 0
    disableBuiltin: no

  # Interface designed to be used from the cli. Read the makefile, build the
  # targets.
  @make: (args, finished) ->
    args.runtime = 'build'
    m = new BuildManager args

    if args.targets.length > 0
      targets = (Node.resolve t, m.getTargetPath for t in args.targets)
    else
      throw new Error 'Not implemented yet. Explicit targets pls'

    generate_task = (builder) -> (next, results) ->
      task =
        builder: builder
        dependencies: results
      queue.push task, next

    process_queue = (task, next) ->
      builder = task.builder

      # Verify all sources built correctly
      for s, i in builder.sources when s instanceof Builder
        dep = task.dependencies[s.target.name]
        if dep.error
          return next null,
            builder: builder
            error: true

      if m.getOption('verbose') is 1
        console.log "Building #{builder.target.name}..."
      else if m.getOption('verbose') >= 2
        console.log "Building #{builder.target.name} using #{builder}..."

      # Perform this task
      builder.buildToFile (err, result) ->
        if err?
          console.error "While building #{builder.target.name}:"
          if m.getOption('verbose') >= 2
            console.error "Using: #{builder}"
          console.error "  #{err.stack}"

        next null,
          builder: builder
          error: err

    jobs_finished = (err, results) ->
      # Exceptions should be handled by the async queue so if we get one here
      # it's unexpected.
      throw err if err?

      success = true
      success = false for name, target of results when target.error?
      console.error "Build failed due to errors" unless success

      finished? success

    # Create a queue for doing the actual building
    queue = async.queue process_queue, args.concurrency ? 1

    # Construct a dependency graph
    try
      tasks = m.constructDependencyTreeFor targets, generate_task
    catch error
      console.error "#{error.name}: #{error.message}"
      return finished false

    # And start everything going
    async.auto tasks, jobs_finished

  constructor: (@externalOptions) ->
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
    if @getOption('verbose') >= 2
      console.log "Done loading makefiles.\n"

  getSourcePath: => @getOption 'sourcePath'
  getTargetPath: => @getOption 'targetPath'

  getOption: (opt) ->
    @effectiveOptions[opt] ?
      @externalOptions?[opt] ?
      BuildManager.defaultOptions[opt]

  setOption: (opt, value) ->
    @effectiveOptions[opt] = value

  register: (builder) ->
    @builders.unshift(builder)
    if @getOption('verbose') >= 2
      console.log "Added #{builder}"
    @

  resolve: (path) ->
    for try_builder in @builders
      actual_builder = try_builder.getBuilderFor path
      return actual_builder if actual_builder?
    null

  # Construct a dependency tree suitable for use with async#auto.
  constructDependencyTreeFor: (targets, task_generator) ->
    tasks = {}
    queueDependencies = (target) =>
      b = @resolve target
      if b?
        task = tasks[target.name] ?= []
        for s in b.sources when s instanceof Builder
          task.push s.target.name
          queueDependencies s.target
        task.push task_generator b if task_generator?
      else
        target_name = path.relative process.cwd(), target.getPath()
        throw new Error "No builders available for #{target_name}"

    queueDependencies t for t in targets
    tasks

  findTargetsAffectedBy: (path) ->
    b for b in @builders when b.isAffectedBy path
