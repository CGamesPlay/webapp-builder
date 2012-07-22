{ Builder } = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
{ FileSystemMock } = require './mock/FileSystemMock'
chai = require 'chai'

expect = chai.expect

describe 'BuildManager', ->
  it "instantiates", ->
    new BuildManager
    expect(-> new BuildManager).to.not.throw()

  beforeEach ->
    @fs = new FileSystemMock
      "test.txt": "It works!"
      "index.html": "WOOOOO"
    @manager = new BuildManager
      fileSystem: @fs

    @some_file = new Builder.Copy 'out/index.html', 'index.html',
      manager: @manager
    @another_file = new Builder.Copy 'out/test.txt', 'test.txt',
      manager: @manager
    @cache_everything = new Builder.AppCache 'out/app.cache', @some_file,
      manager: @manager

    @manager
      .register(@some_file)
      .register(@another_file)
      .register(@cache_everything)

  describe "#reset", ->
    it "removes READY_TO_BUILD listeners", ->
      @manager.reset()
      expect(@some_file.listeners Builder.READY_TO_BUILD).to.be.length 0

  describe "#register", ->
    it "listens to READY_TO_BUILD", ->
      expect(@some_file.listeners Builder.READY_TO_BUILD).to.be.length 1

  describe "#unregister", ->
    it "removes event listeners from BuildManager", ->
      @manager.unregister @cache_everything
      expect(@cache_everything.listeners Builder.READY_TO_BUILD).to.be.length 0

    it "removes event listeners from dependencies", ->
      @manager.unregister @cache_everything
      expect(@some_file.listeners Builder.BUILD_FINISHED).to.be.length 0

  describe "#make", ->
    it "makes simple targets", (done) ->
      @manager.make 'out/index.html', (results) =>
        return done err for t, err of results when err?

        data = @fs.getFile 'out/index.html'
        expect(data).to.equal "WOOOOO"
        done()

    it "makes complex targets", (done) ->
      @manager.make 'out/app.cache', (results) =>
        return done err for t, err of results when err?

        data = @fs.getFile 'out/index.html'
        expect(data).to.equal "WOOOOO"
        done()

  describe "#resolve", ->
    it "identifies a target", ->
      target = @fs.resolve "out/app.cache"
      builder = @manager.resolve target
      expect(builder).to.exist
      expect(builder).to.equal(@cache_everything)

  describe "#findTargetsAffectedBy", ->
    it "identifies all targets", ->
      file = @fs.resolve "index.html"
      targets = @manager.findTargetsAffectedBy file
      expect(targets).to.have.length(2)
      expect(targets).to.contain @some_file
      expect(targets).to.contain @cache_everything
