{ Builder } = require '../Builder'
{ FileSystem } = require '../FileSystem'
path = require 'path'

Builder.registerBuilder class Copy extends Builder
  @generateBuilder: (config) ->
    { manager, target_path, search_path, target } = config
    target_node = manager.fs.resolve path.join target_path, target
    source = manager.fs.resolve path.join search_path, target
    source.getReadablePath()
    return new Copy target_node, [ source ],
      manager: manager

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  inferTarget: -> @sources[0]

  getData: (next) ->
    # Copy *must* get data from the variant directory, otherwise the whole copy
    # thing doesn't make sense.
    if @sources[0].getPath() is @target.getPath()
      throw new Error "#{@}: source and destination identical."
    @sources[0].getData next
