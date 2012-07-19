{ EventEmitter } = require 'events'
mkdirp = require 'mkdirp'
path = require 'path'

exports.FileSystem = class FileSystem
  setVariantDir: (@writePath, @fallbackPath) ->

  resolve: (filename) ->
    return filename if filename instanceof @constructor.Node
    new @constructor.Node @, filename

  getVariantPath: (filename) ->
    within_dir = path.relative @writePath, filename
    if filename.substr(0, 2) != '..'
      path.join @fallbackPath, within_dir
    else
      filename

  mkdirp: (dir, next) ->
    mkdirp dir, next

class FileSystem.Node extends EventEmitter
  constructor: (@fs, @filename) ->

  toString: -> @getPath()

  getPath: -> @filename
  getReadablePath: ->
    return @getPath() if @exists()
    variant = @fs.resolve @fs.getVariantPath @getPath()
    throw new FileNotFoundException @getPath() unless variant.exists()
    return variant.getPath()

  equals: (other) ->
    @getPath() is other.getPath()

  getData: (next) ->
    next new Error "Not implemented"

  writeFile: (data, next) ->
    next new Error "Not implemented"

exports.FileNotFoundException = class FileNotFoundException extends Error
  constructor: (@filename) ->
    @name = @constructor.name
    @message = "File #{@filename} not found."
    Error.captureStackTrace @, @constructor
