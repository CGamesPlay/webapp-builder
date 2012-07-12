MakefileProcessor = require './MakefileProcessor'
path = require 'path'

module.exports = class BuildManager
  @defaultOptions:
    sourcePath: path.resolve '.'
    targetPath: path.resolve 'out'
    verbose: 0
    disableBuiltin: no

  constructor: (@externalOptions) ->
    @reset()

  reset: ->
    @effectiveOptions = {}
    @builders = []
    @makefileProcessor = new MakefileProcessor @,
      disableBuiltin: @getOption 'disableBuiltin'
    if @getOption('file')?
      @makefileProcessor.loadFile @getOption 'file'
    else
      @makefileProcessor.loadDefault()

  getSourcePath: => @getOption 'sourcePath'
  getTargetPath: => @getOption 'targetPath'

  getOption: (opt) ->
    @effectiveOptions[opt] ?
      @externalOptions?[opt] ?
      BuildManager.defaultOptions[opt]

  setOption: (opt, value) ->
    @effectiveOptions[opt] = value

  register: (builder) ->
    @builders.unshift(builder)
    if @getOption('verbose') >= 1
      console.log "Added #{builder}"
    @

  resolve: (path) ->
    for try_builder in @builders
      actual_builder = try_builder.getBuilderFor path
      return actual_builder if actual_builder?
    null

  findTargetsAffectedBy: (path) ->
    b for b in @builders when b.isAffectedBy path
