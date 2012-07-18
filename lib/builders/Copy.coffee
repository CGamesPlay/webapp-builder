Builder = require '../Builder'
{ FileSystem } = require '../FileSystem'

Builder.registerBuilder class Copy extends Builder
  toString: ->
    if @target?.name is @sources[0].name
      "Copy(#{@target?.toString()})"
    else
      "Copy(#{@target?.toString()}, #{@sources[0]})"

  validateSources: ->
    if @sources.length != 1
      throw new Error "#{@} requires exactly one source."

  inferTarget: ->
    return super if @sources[0] instanceof Builder
    @manager.fs.resolve @sources[0]

  handleRequest: (req, res, next) ->
    throw new Error "Not written yet"
    if @sources[0] instanceof Node.Dir and req.url.substr(-1) != "/"
      # For directories, redirect to the trailing / form. This will cause the
      # server to realize it is dealing with a directory and serve index.html
      # appropriately.
      res.redirect "#{req.url}/"
      res.end()

    else
      super req, res, next

  getData: (next) ->
    @sources[0].getData next
