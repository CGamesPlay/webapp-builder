{ FileSystem } = require './FileSystem'
crypto = require 'crypto'

exports.Decider = class Decider
  constructor: (@manager) ->
    @savedInfo = {}

  getCacheInfo: -> @savedInfo
  loadCacheInfo: (@savedInfo) ->

  isBuilderCurrent: (builder) ->
    prev_info  = @pullOldInfo builder

    return false unless builder.target.exists()

    for path, prev of prev_info
      curr = @savedInfo[path]
      return false if @hasSourceChanged curr, prev

    return true

  # Fetch the cached information for the sources of builder, then update the
  # cache.
  pullOldInfo: (builder) ->
    prev_info = {}
    pull_info = (s, path) =>
      # Use ?= to avoid a double-listed source overwriting prev.
      prev_info[path] ?= @savedInfo[path]
      delete @savedInfo[path]

    for s in builder.sources
      pull_info s, s.getPath()
      variant = s.getVariantPath()
      pull_info s, variant if variant isnt s.getPath()

    for cat, list of builder.impliedSources
      for s in list
        pull_info s, s.getPath()
        variant = s.getVariantPath()
        pull_info s, variant if variant isnt s.getPath()

    @updateInfoCache builder
    prev_info

  # Fill in blanks in the info cache for the sources of builder.
  updateInfoCache: (builder) ->
    save_info = (s, path) =>
      @savedInfo[path] ?= @getInfoFor @manager.fs.resolve path

    for s in builder.sources
      save_info s, s.getPath()
      variant = s.getVariantPath()
      save_info s, variant if variant isnt s.getPath()

    for cat, list of builder.impliedSources
      for s in list
        save_info s, s.getPath()
        variant = s.getVariantPath()
        save_info s, variant if variant isnt s.getPath()

  hasSourceChanged: (curr, prev) ->
    # Return true if dep is newer than target
    throw new Error "Decider.#{@constructor.name} does not implement " +
      "hasSourceChanged"

  getInfoFor: (target) ->
    result = {}
    result.exists = target.exists()
    unless result.exists
      return result

    stat = target.getStat()
    result.size = stat.size
    result.mtime = stat.mtime.getTime()

    return result

class Decider.AlwaysRebuild extends Decider
  hasSourceChanged: (curr, prev) ->
    return yes

  getInfoFor: (target) ->
    return {}

class Decider.Timestamp extends Decider
  hasSourceChanged: (curr, prev) ->
    # No previous info -> changed (first run)
    return yes unless prev?
    # Any of size, mtime differ -> changed
    return yes unless curr.exists is prev.exists and
                      curr.mtime is prev.mtime and
                      curr.size is prev.size
    # Else -> unchanged
    return no

class Decider.MD5 extends Decider
  hasSourceChanged: (curr, prev) ->
    # No previous info -> changed (first run)
    return yes unless prev?
    # Size, mtime identical -> unchanged
    return no if curr.exists is prev.exists and
                 curr.mtime is prev.mtime and
                 curr.size is prev.size
    # Signature changeed -> changed
    return yes unless curr.sig is prev.sig
    # Else -> unchanged
    return no

  getInfoFor: (target) ->
    result = super target
    return result unless result.exists

    data = target.getDataSync()
    hash = crypto.createHash('md5').update(data).digest('hex')
    result.sig = hash

    result
