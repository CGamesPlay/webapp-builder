{ Builder, MissingDependencyError } = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
{ FileSystemMock, FileNotFoundException } = require './mock/FileSystemMock'
chai = require 'chai'

expect = chai.expect

describe 'Builder', ->
  beforeEach ->
    @fs = new FileSystemMock
      "test.txt": "It works!"
      "something.coffee": "coffeescript"
      "style.less": "less and junk"
      "module.js": "javascript"
      "out":
        "style.css": "/* what css? */"

    @manager = new BuildManager
      fileSystem: @fs
      sourcePath: '.'
      targetPath: 'out'
    @specific_file = new Builder.Copy 'out/test.txt', 'test.txt',
      manager: @manager
    @dependent_file = new Builder.AppCache 'out/app.cache', @specific_file,
      manager: @manager
    @failure_builder = new Builder.Copy 'out/404.txt', '404.txt',
      manager: @manager

  describe "#inferTarget", ->
    class WithSuffix extends Builder
      @targetSuffix: '.js'

    beforeEach ->
      @builder = new WithSuffix "something.coffee",
        manager: @manager

    it "works", ->
      expect(@builder.getPath()).to.equal("something.js")

    it "handles suffixes", ->
      target = @builder.inferTarget()
      expect(target.getPath()).to.equal("something.js")

  describe "#removeListeners", ->
    it "properly removes listeners", ->
      # Precondition:
      expect(@specific_file.listeners Builder.BUILD_FINISHED).to.have.length 1
      @dependent_file.removeListeners()
      expect(@specific_file.listeners Builder.BUILD_FINISHED).to.have.length 0

    it "emits READY_TO_BUILD once dependencies have finished", (done) ->
      @dependent_file.once Builder.READY_TO_BUILD, ->
        done()
      @dependent_file.queueBuild()
      # Now this should be waiting on @specific_file
      @specific_file.doBuild()

  describe "#isAffectedBy", ->
    it "handles filenames", ->
      file = @fs.resolve "test.txt"
      ret = @specific_file.isAffectedBy file
      expect(ret).to.be.true

    it "ignores incorrect filenames", ->
      file = @fs.resolve "something.coffee"
      ret = @specific_file.isAffectedBy file
      expect(ret).to.be.false

    it "cascades", ->
      file = @fs.resolve "test.txt"
      ret = @dependent_file.isAffectedBy file
      expect(ret).to.be.true

    it "handles variant directories", ->
      file = @fs.resolve "test.txt"
      ret = @specific_file.isAffectedBy file
      expect(ret).to.be.true

  describe "#queueBuild", ->
    it "emits READY_TO_BUILD for simple tasks", (done) ->
      @specific_file.once Builder.READY_TO_BUILD, ->
        done()
      @specific_file.queueBuild()

    it "emits READY_TO_BUILD once dependencies have finished", (done) ->
      @dependent_file.once Builder.READY_TO_BUILD, ->
        done()
      @dependent_file.queueBuild()
      # Now this should be waiting on @specific_file
      @specific_file.doBuild()

    it "emits BUILD_FINISHED if dependencies error", (done) ->
      dependent = new Builder.AppCache 'out/app.cache', @failure_builder,
        manager: @manager
      dependent.once Builder.BUILD_FINISHED, (b, err) ->
        expect(err).to.exist
        expect(err).to.be.an.instanceof MissingDependencyError
        done()
      dependent.queueBuild()
      # Now this should be waiting on @specific_file
      @failure_builder.doBuild()

  describe "#doBuild", ->
    it "emits BUILD_FINISHED when successful", (done) ->
      @specific_file.once Builder.BUILD_FINISHED, (builder, err) ->
        done err
      @specific_file.doBuild()

    it "emits BUILD_FINISHED when unsuccessful", (done) ->
      @failure_builder.once Builder.BUILD_FINISHED, (b, err) ->
        expect(err).to.exist
        expect(err).to.be.an.instanceof Error
        done()
      @failure_builder.doBuild()

describe 'Builder.Less', ->
  # This Builder isn't tested, because we can't override the file system
  # importer safely.
  beforeEach ->
    @fs = new FileSystemMock
      "include.less": "\n"
      "index.less": "@import 'include';"

    @manager = new BuildManager
      fileSystem: @fs
      sourcePath: '.'
      targetPath: 'out'
    @include = @fs.resolve 'include.less'
    @source = @fs.resolve 'index.less'
    @builder = new Builder.Less 'index.css', 'index.less',
      manager: @manager

  describe "#getData", ->
    it "has the correct sources for compiled files", (next) ->
      @builder.getData (err, data) =>
        return next err if err?
        sources = for s in @builder.impliedSources['less']
          s.getPath()
        expect(sources).to.deep.equal [
          'include.less'
        ]
        next()

    it "will error correctly for missing files", (next) ->
      @source.mockUpdateFile '@import "404";'
      @builder.getData (err, data) =>
        expect(err).to.exist
        expect(err).to.be.an.instanceof FileNotFoundException

        expect(@builder.impliedSources['less-missing']).to.deep.equal [
          @fs.resolve '404.less'
        ]
        next()
