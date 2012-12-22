{ Builder, DiscoveredNewSourcesError } = require '../Builder'
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

        try_builder = manager.resolve try_source
        if try_builder?
          return tried: tried, found: try_builder

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
    search_path = @manager.getOption 'sourcePath'
    target_path = @manager.getOption 'targetPath'

    main_name = path.relative search_path, main_node.getPath()
    # Bug in modulr means it won't accept file names
    main_name = main_name.substr 0, main_name.lastIndexOf "."

    global_paths = @manager.getOption "modulrIncludePaths"
    paths = [ search_path, target_path ].concat global_paths

    config =
      environment: 'development'
      manager: @manager
      builder: @
      paths: paths

    @impliedSources['modulr'] = []
    @impliedSources['modulr-alternates'] = []
    @impliedSources['missing'] = []
    # Get rid of all the detected sources
    @removeSource s for s, i in @sources when i isnt 0

    resolver = new CustomDependencyResolver config
    module = resolver.createModule main_name

    resolver.fromModule module, (err, result) =>
      if err instanceof DiscoveredNewSourcesError
        @addSource s for s in err.sources when @sources.indexOf(s) == -1
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

      if found instanceof Builder and
         not @manager.decider.isBuilderCurrent found
        # We have a generated source that isn't yet generated. Throw an
        # exception.
        return callback new DiscoveredNewSourcesError @builder, found
    catch err
      if err instanceof FileNotFoundException
        for f in err.filenames
          @builder.impliedSources['missing'].push @manager.fs.resolve f
      return callback err

    # Make sure we don't rebuild the whole thing
    found = found.target if found instanceof Builder

    module.relativePath = found.getPath()
    module.ext = module.relativePath.substr module.relativePath.lastIndexOf '.'

    found.getData (err, src) ->
      if err
        module.missing = yes
        callback err, no
      else
        module.raw = src.toString('utf-8')
        callback null, no
