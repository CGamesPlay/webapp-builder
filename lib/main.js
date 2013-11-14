require('coffee-script');
var Server = require('./Server');

function webapp(config) {
  return new Server(config).middleware;
}

webapp.BuildManager = require('./BuildManager');
webapp.Builder = require('./Builder').Builder;
webapp.Server = require('./Server');

module.exports = webapp;
