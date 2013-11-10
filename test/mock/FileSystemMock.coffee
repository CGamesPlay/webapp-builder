{ Buffer } = require 'buffer'
{ FileSystem, FileNotFoundException } = require '../../lib/FileSystem'
path = require 'path'

exports.FileSystemMock = class FileSystemMock extends FileSystem
  constructor: (vfs) ->
    @timestamp = 0

    # Fix up the VFS to be nodes rather than strings
    make_dir = (dir) ->
      new_dir =
        type: 'dir'
        contents: {}
      for name, node of dir
        if typeof node is "string"
          new_dir.contents[name] =
            type: 'file'
            data: new Buffer(node)
            mtime: new Date(2000, 1, @timestamp)
        else unless node.type is 'file'
          new_dir.contents[name] = make_dir node
      new_dir
    @vfs = make_dir vfs

  startWatching: ->
    throw new Error "Watching isn't mocked."

  mkdirp: (dir, next) ->
    components = path.normalize(dir).split '/'
    dir = @vfs
    for c in components when c.length > 0
      if dir.type isnt 'dir'
        throw new Error "File already exists"
      dir = dir.contents[c] ?=
        type: 'dir'
        contents: {}

    process.nextTick ->
      next null
    @

  getFile: (filename) ->
    node = @getNode filename
    if node? and node.type is 'file'
      return node
    null

  getNode: (filename) ->
    components = path.normalize(filename).split '/'
    search = @vfs
    for c in components when c.length > 0 and c isnt '.'
      search = search.contents[c]
      if not search? or search.type isnt 'dir'
        break
    return search

class FileSystemMock.Node extends FileSystem.Node
  exists: ->
    !!@fs.getNode @getPath()

  getStat: ->
    file = @fs.getNode @getReadablePath()
    stat =
      size: file.data?.length
      mtime: file.mtime
      isDirectory: -> file.type is 'dir'

  getData: (next) ->
    try
      next null, @fs.getFile(@getReadablePath()).data
    catch err
      next err
    @
  getDataSync: -> @fs.getFile(@getReadablePath()).data

  writeFile: (data, next) ->
    ex = null
    try
      @mockUpdateFile data.toString()
    catch caught_ex
      ex = caught_ex
    process.nextTick ->
      next ex

  # Synchronous method for updating files. Only available for tests.
  mockUpdateFile: (data) ->
    dir = path.dirname @getPath()
    file = path.basename @getPath()
    dir_object = @fs.getNode dir
    if dir_object?
      if typeof data is 'string'
        @fs.timestamp += 1
        data =
          type: 'file'
          data: new Buffer(data)
          mtime: new Date(2000, 1, @fs.timestamp)
      dir_object.contents[file] = data
    else
      throw new FileNotFoundException dir

exports.FileNotFoundException = FileNotFoundException
