{ FileSystem, FileNotFoundException } = require '../../lib/FileSystem'
path = require 'path'

exports.FileSystemMock = class FileSystemMock extends FileSystem
  constructor: (@vfs) ->

  mkdirp: (dir, next) ->
    components = path.normalize(dir).split '/'
    search = @vfs
    for c in components when c.length > 0
      search = search[c] ?= {}
    process.nextTick ->
      next null
    @

  getFile: (filename) ->
    components = path.normalize(filename).split '/'
    search = @vfs
    for c in components when c.length > 0
      search = search[c]
      if not search?
        return null
    return search

class FileSystemMock.Node extends FileSystem.Node
  exists: ->
    !!@fs.getFile @getPath()

  getData: (next) ->
    try
      next null, @fs.getFile @getReadablePath()
    catch err
      next err
    @

  writeFile: (data, next) ->
    dir = path.dirname @getPath()
    file = path.basename @getPath()
    dir_object = @fs.getFile dir
    if dir_object?
      dir_object[file] = data
      process.nextTick ->
        next null
    else
      process.nextTick ->
        next err

exports.FileNotFoundException = FileNotFoundException
