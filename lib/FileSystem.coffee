{ EventEmitter } = require 'events'
fs = require 'fs'
mkdirp = require 'mkdirp'
path = require 'path'
watchr = require 'watchr'

exports.FileSystem = class FileSystem extends EventEmitter
  @FILE_CHANGED = "FILE_CHANGED"

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

  startWatching: ->
    watchr.watch
      paths: [ @fallbackPath, @writePath ]
      listener: @fileModified

  mkdirp: (dir, next) ->
    mkdirp dir, next

  fileModified: (event, path, stat, old_stat) =>
    @emit FileSystem.FILE_CHANGED, event, @resolve(path), stat, old_stat

class FileSystem.Node extends EventEmitter
  constructor: (@fs, @filename) ->

  toString: -> @getPath()

  getPath: -> @filename
  getVariantPath: -> @fs.getVariantPath @getPath()
  getReadablePath: ->
    return @getPath() if @exists()

    # Try our variant
    variant_path = @getVariantPath()
    if variant_path is @getPath()
      # No variant available
      throw new FileNotFoundException @getPath()

    variant = @fs.resolve variant_path
    unless variant.exists()
      throw new FileNotFoundException [ variant.getPath(), @getPath() ]

    return variant.getPath()

  equals: (other) ->
    @getPath() is other.getPath()

  isAffectedBy: (other) ->
    return true if @equals other
    # If we tried to read this node and we don't exist, we would fall back to
    # the variant.
    if not @exists()
      return @getVariantPath() is other.getPath()
    false

  exists: ->
    path.existsSync @getPath()

  getStat: ->
    fs.statSync @getReadablePath()

  getData: (next) ->
    fs.readFile @getReadablePath(), next
  getDataSync: -> fs.readFileSync @getReadablePath()

  writeFile: (data, next) ->
    fs.writeFile @getPath(), data, next

exports.FileNotFoundException = class FileNotFoundException extends Error
  constructor: (@filenames) ->
    @filenames = [ @filenames ] unless Array.isArray @filenames
    @filename = @filenames[0]
    @name = @constructor.name
    @message = "File #{@filename} not found"
    if @filenames.length > 1
      @message += " (also tried #{@filenames[1..]})"
    @message += "."
    Error.captureStackTrace @, @constructor
