{ Builder } = require '../Builder'
{ FileSystem } = require '../FileSystem'

Builder.registerBuilder class Copy extends Builder
  @createBuilderFor: (manager, target) ->
    variant_path = manager.fs.getVariantPath target.getPath()
    variant_node = manager.fs.resolve variant_path
    variant_node.getReadablePath()
    return new Copy target, [ variant_node ],
      manager: manager

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  inferTarget: -> @sources[0]

  handleRequest: (req, res, next) ->
    if @sources[0].getStat().isDirectory() and req.url.substr(-1) != "/"
      # For directories, redirect to the trailing / form. This will cause the
      # server to realize it is dealing with a directory and serve index.html
      # appropriately.
      res.redirect "#{req.url}/"
      res.end()

    else
      super req, res, next

  getData: (next) ->
    # Copy *must* get data from the variant directory, otherwise the whole copy
    # thing doesn't make sense.
    variant_path = @manager.fs.getVariantPath @sources[0].getPath()
    if variant_path is @target.getPath()
      throw new Error "#{@}: source and destination identical."
    variant_node = @manager.fs.resolve variant_path
    variant_node.getData next
