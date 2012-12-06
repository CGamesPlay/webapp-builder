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

  @resolveModule: (manager, basename, paths) ->
    # Store a list of all sources that were tried before the current one was
    # found. If one of these files appears in the future, it will override the
    # other one :-X
    tried = []
    for dir in paths
      for suffix in Modulr.suffixes
        try_source = manager.fs.resolve path.join dir, basename + suffix
        if try_source.exists()
          # Found at the primary path
          return tried: tried, found: try_source
        else
          tried.push try_source

        try_variant = manager.fs.resolve try_source.getVariantPath()
        unless try_source.equals try_variant
          # Only try variant if it's different
          if try_variant.exists()
            # Found at the alternate path
            return tried: tried, found: try_variant
          else
            tried.push try_variant

    err = new FileNotFoundException tried
    err.message = "Module #{basename} not found. " +
      "Tried " + tried.join(', ') + "."
    throw err

  @generateBuilder: (config) ->
    { manager, target, search_path } = config
    basename = path.join path.dirname(target),
                         path.basename(target, @targetSuffix)
    { tried, found } = Modulr.resolveModule manager, basename, [ search_path ]
    target_node = path.join config.target_path, target
    builder = new Modulr target_node, [ found ],
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

    @impliedSources['modulr'] = []
    @impliedSources['modulr-alternates'] = []
    @impliedSources['missing'] = []
    resolver = new CustomDependencyResolver config
    module = resolver.createModule main_name

    resolver.fromModule module, (err, result) =>
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
      { tried, found } = Modulr.resolveModule @manager, relative, @paths
      @builder.impliedSources['modulr'].push found
      @builder.impliedSources['modulr-alternates'].push p for p in tried
    catch err
      if err instanceof FileNotFoundException
        for f in err.filenames
          @builder.impliedSources['missing'].push @manager.fs.resolve f
      return callback err

    module.relativePath = found.getPath()
    module.ext = module.relativePath.substr module.relativePath.lastIndexOf '.'

    found.getData (err, src) ->
      if err
        module.missing = yes
        callback err, no
      else
        module.raw = src.toString('utf-8')
        callback null, no
