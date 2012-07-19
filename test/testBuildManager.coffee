Builder = require '../lib/Builder'
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
      disableBuiltin: yes
      fileSystem: @fs

    @some_file = new Builder.Copy 'out/index.html',
      manager: @manager
    @another_file = new Builder.Copy 'out/test.txt',
      manager: @manager
    @cache_everything = new Builder.AppCache 'out/app.cache', @some_file,
      manager: @manager

    @manager
      .register(@some_file)
      .register(@another_file)
      .register(@cache_everything)

  describe "#make", ->
    it "makes simple targets", (done) ->
      @manager.make 'out/index.html', done

  describe "#resolve", ->
    it "identifies a target", ->
      target = @fs.resolve "out/app.cache"
      builder = @manager.resolve target
      expect(builder).to.exist
      expect(builder).to.equal(@cache_everything)

  describe "#constructDependencyTreeFor", ->
    it "handles a simple target", ->
      target = @fs.resolve "out/index.html"
      tasks = @manager.constructDependencyTreeFor [ target ]
      expect(tasks).to.deep.equal
        'out/index.html': []

    it "handles a composite target", ->
      target = @fs.resolve "out/app.cache"
      tasks = @manager.constructDependencyTreeFor [ target ]
      expect(tasks).to.deep.equal
        'out/app.cache': [ 'out/index.html' ]
        'out/index.html': []

    it "handles multiple targets", ->
      targets = [
        @fs.resolve "out/app.cache"
        @fs.resolve "out/test.txt"
      ]
      tasks = @manager.constructDependencyTreeFor targets
      expect(tasks).to.deep.equal
        'out/app.cache': [ 'out/index.html' ]
        'out/index.html': []
        'out/test.txt': []

  describe "#findTargetsAffectedBy", ->
    it "identifies all targets", ->
      file = @fs.resolve "out/index.html"
      targets = @manager.findTargetsAffectedBy file
      expect(targets).to.have.length(2)
      expect(targets).to.contain @some_file
      expect(targets).to.contain @cache_everything
