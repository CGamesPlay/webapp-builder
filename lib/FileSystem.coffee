{ EventEmitter } = require 'events'
fs = require 'fs'
mkdirp = require 'mkdirp'
path = require 'path'

exports.FileSystem = class FileSystem
  setVariantDir: (@writePath, @fallbackPath) ->

  resolve: (filename) ->
    return filename if filename instanceof @constructor.Node
    new @constructor.Node @, filename

  getVariantPath: (filename) ->
    relative_to_write = path.relative @writePath, filename
    if relative_to_write.substr(0, 2) != '..'
      path.join @fallbackPath, relative_to_write
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
    throw new FileNotFoundException variant.getPath() unless variant.exists()
    return variant.getPath()

  equals: (other) ->
    @getPath() is other.getPath()

  exists: ->
    path.existsSync @getPath()

  getStat: ->
    fs.statSync @getReadablePath()

  getData: (next) ->
    fs.readFile @getReadablePath(), next

  writeFile: (data, next) ->
    fs.writeFile @getPath(), data, next

exports.FileNotFoundException = class FileNotFoundException extends Error
  constructor: (@filename) ->
    @name = @constructor.name
    @message = "File #{@filename} not found."
    Error.captureStackTrace @, @constructor
