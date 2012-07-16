Builder = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
NodeMock = require './mock/NodeMock'
chai = require 'chai'

expect = chai.expect

describe 'BuildManager', ->
  noPrefix = -> '.'
  NodeMock.use
    "test.txt": "It works!"

  it "instantiates", ->
    new BuildManager
    expect(-> new BuildManager).to.not.throw()

  beforeEach ->
    @manager = new BuildManager
      disableBuiltin: yes
      sourcePath: '.'

    @wildcard = new Builder.Copy '%%',
      manager: @manager
    @some_file = new Builder.Copy 'index.html'
      manager: @manager
    @cache_everything = new Builder.AppCache 'app.cache', @some_file,
      manager: @manager

    @manager
      .register(@wildcard)
      .register(@some_file)
      .register(@cache_everything)

  describe "#resolve", ->
    it "identifies a target", ->
      target = NodeMock.resolve "app.cache", @manager.getTargetPath
      builder = @manager.resolve target
      expect(builder).to.exist
      expect(builder).to.equal(@cache_everything)

  describe "#constructDependencyTreeFor", ->
    it "handles a simple target", ->
      target = NodeMock.resolve "test.txt", @manager.getTargetPath
      tasks = @manager.constructDependencyTreeFor [ target ]
      expect(tasks).to.deep.equal
        'test.txt': []

    it "handles a composite target", ->
      target = NodeMock.resolve "app.cache", @manager.getTargetPath
      tasks = @manager.constructDependencyTreeFor [ target ]
      expect(tasks).to.deep.equal
        'app.cache': [ 'index.html' ]
        'index.html': []

    it "handles multiple targets", ->
      targets = [
        NodeMock.resolve "app.cache", @manager.getTargetPath
        NodeMock.resolve "test.txt", @manager.getTargetPath
      ]
      tasks = @manager.constructDependencyTreeFor targets
      expect(tasks).to.deep.equal
        'app.cache': [ 'index.html' ]
        'index.html': []
        'test.txt': []

  describe "#findTargetsAffectedBy", ->
    it "identifies all targets", ->
      file = NodeMock.resolve "index.html", noPrefix
      targets = @manager.findTargetsAffectedBy file
      expect(targets).to.have.length(3)
      expect(targets).to.contain @wildcard
      expect(targets).to.contain @some_file
      expect(targets).to.contain @cache_everything
