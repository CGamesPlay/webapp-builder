{ Builder } = require '../Builder'
{ FileNotFoundException } = require '../FileSystem'
CoffeeScript = require 'coffee-script'
path = require 'path'
modulr = require 'modulr'

Builder.registerBuilder class Modulr extends Builder
  @targetSuffix: '.js'

  @suffixes = [ '.js', '.coffee' ]

  @createBuilderFor: (manager, target) ->
    basename = path.join path.dirname(target.getPath()),
                         path.basename(target.getPath(), @targetSuffix)
    # Store a list of all sources that were tried before the current one was
    # found. If one of these files appears in the future, it will override the
    # other one :-X
    tried = []
    for suffix in Modulr.suffixes
      try_source = manager.fs.resolve basename + suffix
      try
        try_source.getReadablePath()
        # Found the main. Make it the first source.
        builder = new Modulr target, [ try_source ],
          manager: manager
        builder.impliedSources.splice -1, 0, tried...
        return builder
      catch _
        tried.push try_source

    err = new FileNotFoundException tried
    err.message = "Module #{basename} not found. " +
      "Tried " + tried.join(', ') + "."
    throw err

  constructor: (target, sources, options) ->
    super target, sources, options
    @modulrDependencies = []

  dump: ->
    super()
    for s in @modulrDependencies
      @manager.reporter.debug "  (modulr) #{s}"

  isAffectedBy: (node) ->
    return true if super node
    for s in @modulrDependencies
      return true if s.isAffectedBy node
    return false

  getData: (next) ->
    main_node = @sources[0]

    main_name = path.basename main_node.getPath()
    # Bug in modulr means it won't accept file names
    main_name = main_name.substr 0, main_name.lastIndexOf "."

    paths = [ path.dirname main_node.getPath() ]
    if main_node.getVariantPath() isnt main_node.getPath()
      paths.push path.dirname main_node.getVariantPath()

    config =
      environment: 'development'
      minify: false
      paths: paths

    modulr.build main_name, config, (err, builtSpec) =>
      return @handleError err, next if err?

      @modulrDependencies = for name, module of builtSpec.modules
        @manager.fs.resolve module.relativePath

      next null, builtSpec.output

  handleError: (err, next) ->
    idx = err.message.indexOf "Cannot find module:"
    if idx != -1
      # We need to extract the searched paths as implicit sources.
      idx = err.longDesc.indexOf "\n", idx
      paths = err.longDesc.substr(idx + 1).split("\n")
      root_dir = path.dirname @sources[0].getPath()
      paths = for p in paths
        # Trim spaces
        p = p.substr 4
        p = path.relative root_dir, p
        continue if p.substr(0, 2) is '..'
        p
      # We will also need to monitor the broken file.
      paths.push path.relative root_dir, err.file
      related_files = []
      for p in paths
        p = p.substr 0, p.lastIndexOf "."
        p = path.join root_dir, p
        for suffix in Modulr.suffixes
          related_files.push @manager.fs.resolve p + suffix

      @modulrDependencies = related_files

    file = CoffeeScript.compile """
      target = #{JSON.stringify @.toString()}
      longDesc = #{JSON.stringify err.longDesc}
      console.error "Error while building \#{target}:\\n\#{longDesc}"
    """
    next null, file
