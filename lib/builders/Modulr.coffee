Builder = require '../Builder'
path = require 'path'
modulr = require 'modulr'

Builder.registerBuilder class Modulr extends Builder
  @targetSuffix: '.js'

  constructor: (target, sources, options) ->
    super target, sources, options

    @config =
      environment: 'development'
      minify: false
      paths: [ path.dirname @sources[0].getPath() ]

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  invalidateCaches: ->
    @cachedBuild = null

  getData: (next) ->
    return next null, @cachedBuild.output if @cachedBuild?

    main_path = @sources[0].getPath()
    # Bug in modulr means it won't accept file names
    main = main_path.substr 0, main_path.lastIndexOf "."

    modulr.build main, @config, (err, builtSpec) =>
      return next err if err?

      @cachedBuild = builtSpec
      next null, builtSpec.output
