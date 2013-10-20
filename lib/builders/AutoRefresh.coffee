{ Builder } = require '../Builder'
{ FileSystem } = require '../FileSystem'
path = require 'path'

Builder.registerBuilder class AutoRefresh extends Builder
  @targetSuffix: '.html'

  @suffixes = [ '.html', '.html' ]

  @generateBuilder: (config) ->
    { manager, target_path, search_path, target } = config
    target_node = manager.fs.resolve path.join target_path, target
    source = manager.fs.resolve path.join search_path, target
    source.getReadablePath()
    return new AutoRefresh target_node, [ source ],
      manager: manager

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  inferTarget: -> @sources[0]

  getData: (next) ->
    # Must get data from the variant directory.
    if @sources[0].getPath() is @target.getPath()
      throw new Error "#{@}: source and destination identical."

    # Don't do anything unless there is a ClientManager hooked up
    return @sources[0].getData next unless @manager.clientManager?

    @sources[0].getData (err, data) =>
      return next err if err?
      trailer = @manager.clientManager.getTrailerFor @
      data = data.toString() + trailer
      data = new Buffer data
      next null, data
