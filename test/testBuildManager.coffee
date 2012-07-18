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
      sourcePath: '.'

    @some_file = new Builder.Copy 'index.html',
      manager: @manager
    @another_file = new Builder.Copy 'test.txt',
      manager: @manager
    @cache_everything = new Builder.AppCache 'app.cache', @some_file,
      manager: @manager

    @manager
      .register(@some_file)
      .register(@another_file)
      .register(@cache_everything)

  describe "#resolve", ->
    it "identifies a target", ->
      target = @fs.resolve "app.cache"
      builder = @manager.resolve target
      expect(builder).to.exist
      expect(builder).to.equal(@cache_everything)

  describe "#constructDependencyTreeFor", ->
    it "handles a simple target", ->
      target = @fs.resolve "index.html"
      tasks = @manager.constructDependencyTreeFor [ target ]
      expect(tasks).to.deep.equal
        'index.html': []

    it "handles a composite target", ->
      target = @fs.resolve "app.cache"
      tasks = @manager.constructDependencyTreeFor [ target ]
      expect(tasks).to.deep.equal
        'app.cache': [ 'index.html' ]
        'index.html': []

    it "handles multiple targets", ->
      targets = [
        @fs.resolve "app.cache"
        @fs.resolve "test.txt"
      ]
      tasks = @manager.constructDependencyTreeFor targets
      expect(tasks).to.deep.equal
        'app.cache': [ 'index.html' ]
        'index.html': []
        'test.txt': []

  describe "#findTargetsAffectedBy", ->
    it "identifies all targets", ->
      file = @fs.resolve "index.html"
      targets = @manager.findTargetsAffectedBy file
      expect(targets).to.have.length(2)
      expect(targets).to.contain @some_file
      expect(targets).to.contain @cache_everything
