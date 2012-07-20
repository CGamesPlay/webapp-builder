{ Builder } = require '../Builder'
fs = require 'fs'
path = require 'path'
less = require 'less'

Builder.registerBuilder class Less extends Builder
  @targetSuffix: '.css'
  @sourceSuffix: '.less'

  constructor: (target, sources, options) ->
    super target, sources, options

    @config = {}

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  getData: (next) ->
    parser = new less.Parser @config
    @sources[0].getData (err, data) ->
      return next err if err?

      parser.parse data, (err, tree) ->
        return next err if err?

        next null, tree.toCSS()
