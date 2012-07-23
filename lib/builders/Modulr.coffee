{ Builder } = require '../Builder'
{ FileNotFoundException } = require '../FileSystem'
CoffeeScript = require 'coffee-script'
{ DependencyResolver } = require 'module-grapher/lib/dependency-resolver'
ModuleGrapher = require 'module-grapher'
{ SrcResolver } = require 'module-grapher/lib/src-resolver'
modulr_builder = require 'modulr/lib/builder'
path = require 'path'

Builder.registerBuilder class Modulr extends Builder
  @targetSuffix: '.js'

  @suffixes = [ '.js', '.coffee' ]

  @resolveModule: (manager, basename, disallow = null) ->
    # Store a list of all sources that were tried before the current one was
    # found. If one of these files appears in the future, it will override the
    # other one :-X
    tried = []
    for suffix in Modulr.suffixes
      try_source = manager.fs.resolve basename + suffix
      if disallow and try_source.equals(disallow)
        try_source = manager.fs.resolve try_source.getVariantPath()
        if try_source.equals(disallow)
          # We can't compile the output file to itself
          continue
      try
        try_source.getReadablePath()
        # No exception. Found it!
        return tried: tried, found: try_source
      catch _
        tried.push try_source

    err = new FileNotFoundException tried
    err.message = "Module #{basename} not found. " +
      "Tried " + tried.join(', ') + "."
    throw err

  @createBuilderFor: (manager, target) ->
    basename = path.join path.dirname(target.getPath()),
                         path.basename(target.getPath(), @targetSuffix)
    { tried, found } = Modulr.resolveModule manager, basename, target
    builder = new Modulr target, [ found ],
      manager: manager
    builder.impliedSources['alternates'] = tried
    return builder

  constructor: (target, sources, options) ->
    super target, sources, options
    @rootDir = path.dirname @sources[0].getPath()

  getData: (next) ->
    if @target.getPath() is @sources[0].getPath()
      return next new Error "#{@} cannot compile itself."

    main_node = @sources[0]

    main_name = path.basename main_node.getPath()
    # Bug in modulr means it won't accept file names
    main_name = main_name.substr 0, main_name.lastIndexOf "."

    config =
      environment: 'development'
      manager: @manager
      builder: @
      paths: [ path.dirname main_node.getPath() ]

    resolver = new CustomDependencyResolver config
    module = resolver.createModule main_name

    resolver.fromModule module, (err, result) =>
      @impliedSources['modulr'] = []
      @impliedSources['modulr-alternates'] = []
      for name, module of result.modules
        @impliedSources['modulr'].push @manager.fs.resolve module.relativePath
        @impliedSources['modulr-alternates'].push p for p in module.triedPaths

      if err instanceof FileNotFoundException
        @impliedSources['missing'] = []
        for f in err.filenames
          @impliedSources['missing'].push @manager.fs.resolve f
      else
        delete @impliedSources['missing']

      return next err if err?

      result.output = modulr_builder.create(config).build result
      # Hurr hurr durr
      delete global.id
      next null, result.output

class CustomDependencyResolver extends DependencyResolver
  createSrcResolver: (config) ->
    return new CustomSrcResolver config

class CustomSrcResolver extends SrcResolver
  constructor: (config) ->
    super config
    { @manager, @builder } = config

  setPaths: (paths) -> @paths = paths.slice 0

  resolvePath: (relative, module, callback) ->
    try
      { tried, found } = Modulr.resolveModule @manager, relative
    catch err
      return callback err

    module.triedPaths = tried
    module.relativePath = found.getPath()
    module.ext = module.relativePath.substr module.relativePath.lastIndexOf '.'

    found.getData (err, src) ->
      if err
        module.missing = yes
        callback err, no
      else
        module.raw = src.toString('utf-8')
        callback null, no
