{ Builder } = require '../Builder'
{ FileNotFoundException } = require '../FileSystem'
path = require 'path'
less = require 'less'

# Monkey patching!
original_importer = less.Parser.importer
less.Parser.importer = (file, info, callback, env) ->
  if env.builder?
    env.builder.customImporter file, info, callback, env
  else
    original_importer file, info, callback, env

Builder.registerBuilder class Less extends Builder
  @targetSuffix: '.css'
  @sourceSuffix: '.less'

  constructor: (target, sources, options) ->
    super target, sources, options

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  getData: (next) ->
    env = new less.tree.parseEnv
      paths: [ path.dirname @sources[0].getPath() ]
      filename: @sources[0].getPath()
    env.builder = @
    parser = new less.Parser env

    @sources[0].getData (err, data) =>
      return next err if err?

      @dealWithLess data.toString(), parser, (err, tree, data) =>
        if err instanceof FileNotFoundException
          @impliedSources['less-missing'] =
            (@manager.fs.resolve f for f in err.filenames)

        return next err if err?
        next null, data

  # Less has horrible exception semantics
  dealWithLess: (data, parser, next) =>
    @impliedSources['less'] = []

    try
      parser.parse data, (err, tree) =>
        # If next throws it cannot go through less because less will wrap it in
        # a silly exception type.
        process.nextTick =>
          return next @wrapLessError err if err?
          err = null
          try
            css = tree.toCSS()
          catch caught_err
            err = @wrapLessError caught_err
          next err, tree, css
    catch err
      # Less both throws and passes errors. Joy.
      process.nextTick =>
        return next @wrapLessError err

  customImporter: (file, info, callback, env) =>
    for p in [info.currentDirectory].concat env.paths
      try
        node = @manager.fs.resolve path.join p, file
        node.getReadablePath()
        break
      catch _
        node = null

    unless node?
      return callback type: 'File', message: new FileNotFoundException file

    @impliedSources['less'].push node
    node.getData (err, data) ->
      return callback err if err?

      data = data.toString()
      parser = new less.Parser
        paths: [ path.dirname node.getPath() ]
        filename: node.getPath()
      parser.parse data, (e, root) ->
        callback null, root, data

  # Either unwraps an existing Error from Less, or wraps a less error in an
  # error that has a real stack trace.
  wrapLessError: (less_info) ->
    if less_info.message instanceof Error
      less_info.message
    else
      new LessError less_info

exports.LessError = class LessError extends Error
  constructor: (less_info) ->
    @name = @constructor.name
    @message = "#{less_info.type}: #{less_info.message}"
    Error.captureStackTrace @, @constructor
