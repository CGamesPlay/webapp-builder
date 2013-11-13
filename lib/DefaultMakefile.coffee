# This is the default Makefile.coffee for all projects.

# Clears all exisiting configuration. You may call this yourself if you want to
# prevent the default Makefile from affecting your project.
webapp.reset()

if webapp.getOption('env') is 'development'
  build_js = Modulr
  build_css = Less
  build_html = AutoRefresh
else
  # XXX build support for this
  # build_js = Pipeline [ Modulr, Uglify ]
  build_js = Modulr
  build_css = Less
  build_html = Copy

webapp.addServerRule
  target: '/%'
  builder: Copy
  source: '%'

webapp.addServerRule
  target: '/%.html'
  builder: build_html
  source: '%.html'

webapp.addServerRule
  target: '/%.css'
  builder: build_css
  source: '%.css'
webapp.addServerRule
  target: '/%.css'
  builder: build_css
  source: '%.less'

webapp.addServerRule
  target: '/%.js'
  builder: build_js
  source: '%.coffee'
webapp.addServerRule
  target: '/%.js'
  builder: build_js
  source: '%.js'
