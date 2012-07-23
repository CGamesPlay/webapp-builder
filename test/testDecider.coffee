{ Builder } = require '../lib/Builder'
BuildManager = require '../lib/BuildManager'
{ Decider } = require '../lib/Decider'
{ FileSystemMock } = require './mock/FileSystemMock'
chai = require 'chai'

expect = chai.expect

describe 'Decider', ->
  describe "#isBuilderCurrent", ->
    before ->
      @fs = new FileSystemMock
        "test.txt": "It works!"

      @manager = new BuildManager
        fileSystem: @fs
        sourcePath: '.'
        targetPath: 'out'
      @specific_file = new Builder.Copy 'out/test-copied.txt', 'test.txt',
        manager: @manager
      @dependent_file = new Builder.AppCache 'out/app.cache', @specific_file,
        manager: @manager

      @manager
        .register(@specific_file)
        .register(@dependent_file)

    it "is not current when target doesn't exist", ->
      expect(@manager.decider.isBuilderCurrent @specific_file).to.equal(false)

    it "becomes current after building", (next) ->
      # Note: make dependent_file for use later on
      @manager.make @dependent_file.target, (results) =>
        return next err for t, err of results when err?
        expect(results[@specific_file.target.getPath()]).not.to.exist
        current = @manager.decider.isBuilderCurrent @specific_file
        expect(current).to.equal(true)
        next()

    it "becomes out of date when a source is modified", (next) ->
      node = @fs.resolve 'test.txt'
      node.writeFile 'new data', (err) =>
        expect(err).not.to.exist
        current = @manager.decider.isBuilderCurrent @specific_file
        expect(current).to.equal(false)
        next()

    it "is not current when a Builder dependency is not current", ->
      expect(@manager.decider.isBuilderCurrent @dependent_file).to.equal(false)
