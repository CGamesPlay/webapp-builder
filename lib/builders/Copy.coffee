{ Builder } = require '../Builder'
{ FileSystem } = require '../FileSystem'

Builder.registerBuilder class Copy extends Builder
  @createBuilderFor: (manager, target) ->
    variant_node = manager.fs.resolve target.getVariantPath()
    variant_node.getReadablePath()
    return new Copy target, [ variant_node ],
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
