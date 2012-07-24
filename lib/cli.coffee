ArgumentParser = require('argparse').ArgumentParser
Reporter = require './Reporter'
path = require 'path'

parser = new ArgumentParser
  addHelp: yes
  description: 'Command-line frontend to bootstrap making web applications.'

common_args = (parser) ->
  parser.addArgument [ '-f', '--file' ],
    help: "File to use as a build script."

  parser.addArgument [ '-v', '--verbose' ],
    action: 'count'
    help: "Increase amount of logging."

  parser.addArgument [ '-j', '--jobs' ],
    help: 'Number of builds to perform simultaneously. Default is number of ' +
          'CPUs.'
    defaultValue: null
    type: 'int'
    dest: 'concurrency'

common_args parser

subparsers = parser.addSubparsers
  title: 'Valid commands'
  dest: 'command'

server_parser = subparsers.addParser 'serve'
  addHelp: yes
  help: 'Run an auto-building web server.'
  description: "Create a web server that serves from the source directory. Any
    built files requested will automatically be built and served in real time."

common_args server_parser

server_parser.addArgument [ '-p', '--port' ],
  help: 'Port to listen on. Defaults to the PORT environment variable or 8000.'
  defaultValue: process.env.PORT ? 0
  type: 'int'

server_parser.addArgument [ '--no-watch' ],
  help: 'Disable watching the file system for changes and auto-refresh.'
  action: 'storeFalse'
  dest: 'watchFileSystem'
  defaultValue: true

server_parser.addArgument [ '--no-browser' ],
  help: 'Do not automatically open the browser to the server\'s address.'
  action: 'storeFalse'
  dest: 'openBrowser'
  defaultValue: true

build_parser = subparsers.addParser "build"
  addHelp: yes
  help: 'Build all defined assets.'

common_args build_parser

build_parser.addArgument [ 'targets' ],
  help: 'Targets to build'
  nargs: '*'
  metavar: 'target'

args = parser.parseArgs()

commands =
  serve: ->
    server = require './server'
    server.standalone args
  build: ->
    BuildManager = require './BuildManager'
    args.verbose += Reporter.INFO
    m = new BuildManager args
    m.make args.targets, (results) ->
      m.saveCache()
      code = 0
      code = 1 for err in results when err?

      process.exit code

commands[args.command]()
