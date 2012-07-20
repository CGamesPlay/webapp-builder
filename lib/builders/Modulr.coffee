{ Builder } = require '../Builder'
{ FileNotFoundException } = require '../FileSystem'
path = require 'path'
modulr = require 'modulr'

Builder.registerBuilder class Modulr extends Builder
  @targetSuffix: '.js'

  @createBuilderFor: (manager, target) ->
    suffixes = [ '.js', '.coffee' ]
    basename = path.join path.dirname(target.getPath()),
                         path.basename(target.getPath(), @targetSuffix)
    # Store a list of all sources that were tried before the current one was
    # found. If one of these files appears in the future, it will override the
    # other one :-X
    tried = []
    for suffix in suffixes
      try_source = manager.fs.resolve basename + suffix
      tried.push try_source.getPath()
      try
        try_source.getReadablePath()
        return new Modulr target, tried,
          manager: manager
      catch _
        # Gulp

    err = new FileNotFoundException basename
    err.message = "Module #{basename} not found. " +
      "Tried " + tried.join(', ') + "."
    throw err

  constructor: (target, sources, options) ->
    super target, sources, options

  getData: (next) ->
    main_path = @sources[0].getReadablePath()
    # Bug in modulr means it won't accept file names
    main = main_path.substr 0, main_path.lastIndexOf "."

    config =
      environment: 'development'
      minify: false
      paths: [ path.dirname @sources[0].getReadablePath() ]

    modulr.build main, config, (err, builtSpec) =>
      return next err if err?

      next null, builtSpec.output
