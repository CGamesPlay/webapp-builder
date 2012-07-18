{ FileSystem, FileNotFoundException } = require '../../lib/FileSystem'
path = require 'path'

exports.FileSystemMock = class FileSystemMock extends FileSystem
  constructor: (@vfs) ->

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

exports.FileNotFoundException = FileNotFoundException
