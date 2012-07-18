Builder = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
{ FileSystemMock } = require './mock/FileSystemMock'
chai = require 'chai'

expect = chai.expect

describe 'Builder', ->
  beforeEach ->
    @fs = new FileSystemMock
      "test.txt": "It works!"
      "something.coffee": "coffeescript"

    @manager = new BuildManager
      disableBuiltin: true
      fileSystem: @fs
      sourcePath: '.'
      targetPath: 'out'
    @specific_file = new Builder.Copy 'test.txt',
      manager: @manager
    @dependent_file = new Builder.AppCache 'app.cache', @specific_file,
      manager: @manager

  describe "#inferTarget", ->
    class WithSuffix extends Builder
      @targetSuffix: '.js'

    beforeEach ->
      @builder = new WithSuffix "something.coffee",
        manager: @manager

    it "works", ->
      expect(@builder.target.getPath()).to.equal("something.js")

    it "handles suffixes", ->
      target = @builder.inferTarget()
      expect(target.getPath()).to.equal("something.js")

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
