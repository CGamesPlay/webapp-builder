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
    variant_path = @sources[0].getVariantPath()
    if variant_path is @target.getPath()
      throw new Error "#{@}: source and destination identical."
    variant_node = @manager.fs.resolve variant_path
    variant_node.getData next
