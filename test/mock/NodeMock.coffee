Node = require '../../lib/Node'
path = require 'path'

module.exports = class NodeMock extends Node
  @use: (vfs) ->
    before =>
      @vfs = vfs
      @saved_resolve = Node.resolve
      Node.resolve = @resolve

    after =>
      Node.resolve = @saved_resolve

  @resolve: (name, prefixGetter) =>
    return name if typeof name is 'object'
    if name.indexOf('%') != -1
      return new Node.Wildcard name, prefixGetter

    file = @getFile path.join prefixGetter(), name
    if not file?
      new NodeMock name, prefixGetter
    else if typeof file is "string"
      new NodeMock.File name, prefixGetter
    else
      new NodeMock.Dir name, prefixGetter

  @getFile: (filename) ->
    components = path.normalize(filename).split '/'
    search = @vfs
    for c in components when c.length > 0
      search = search[c]
      if not search?
        return null
    return search

  exists: ->
    NodeMock.getFile(@getPath())?

class NodeMock.File extends NodeMock
  getData: (next) ->
    next null, NodeMock.getFile @getPath()

class NodeMock.Dir extends NodeMock
