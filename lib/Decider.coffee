{ FileSystem } = require './FileSystem'
{ Builder } = require './Builder'
crypto = require 'crypto'

exports.Decider = class Decider
  constructor: (@manager) ->
    @savedInfo = {}

  getCacheInfo: -> @savedInfo
  loadCacheInfo: (@savedInfo) ->

  # Check to see if the sources have changed since the last time
  # updateAfterBuild was called with this builder. Token is an object. If given,
  # it can then be passed to updateSourceInfoFor immediately after building
  # successfully to increase performance.
  isBuilderCurrent: (builder, token = null) ->
    prev_info = @savedInfo[builder.getCacheKey()]
    curr_info = @getInfoForSources builder

    token[k] = v for k, v of curr_info if token?

    return false unless builder.target.exists() and prev_info?

    for path, prev of prev_info
      return false if @hasSourceChanged curr_info[path], prev
    # Also count any *new* sources that showed up magically.
    for path, curr of curr_info
      return false unless prev_info[path]?

    for s in builder.sources when s instanceof Builder
      return false unless @isBuilderCurrent s

    return true

  # Update the cache of source information
  updateSourceInfoFor: (builder, token = null) ->
    @savedInfo[builder.getCacheKey()] = @getInfoForSources builder, token

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

  # Fetch info for all sources of this builder. If token is given, information
  # in it will be used instead of collecting information from the file system.
  getInfoForSources: (builder, token) ->
    info = {}
    save_info = (path) =>
      info[path] = token?[path] ? @getInfoFor @manager.fs.resolve path

    for s in builder.sources
      s = s.target if s instanceof Builder
      save_info s.getPath()
      variant = s.getVariantPath()
      save_info variant if variant isnt s.getPath()

    for cat, list of builder.impliedSources
      for s in list
        s = s.target if s instanceof Builder
        save_info s.getPath()
        variant = s.getVariantPath()
        save_info variant if variant isnt s.getPath()

    info

class Decider.AlwaysRebuild extends Decider
  isBuilderCurrent: (builder) ->
    return no

  getInfoFor: (target) ->
    return {}

class Decider.Timestamp extends Decider
  hasSourceChanged: (curr, prev) ->
    # Any of size, mtime differ -> changed
    return yes unless curr.exists is prev.exists and
                      curr.mtime is prev.mtime and
                      curr.size is prev.size
    # Else -> unchanged
    return no

class Decider.MD5 extends Decider
  hasSourceChanged: (curr, prev) ->
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
