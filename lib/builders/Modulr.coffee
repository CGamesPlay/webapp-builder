Builder = require '../Builder'
Node = require '../Node'
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

  getData: (next) ->
    main = @sources[0].getPath().substr 0,
      @sources[0].getPath().lastIndexOf "."

    modulr.build main, @config, (err, builtSpec) ->
      return next err if err?

      next null, builtSpec.output
