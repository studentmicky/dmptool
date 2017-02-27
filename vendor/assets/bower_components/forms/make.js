let b = require('substance-bundler')
let path = require('path')

function _buildLib(transpileToES5, cleanup) {
  b.js('./lib/substance-forms.js', {
    target: {
      useStrict: !transpileToES5,
      dest: './dist/substance-forms.js',
      format: 'umd', moduleName: 'forms', sourceMapRoot: __dirname, sourceMapPrefix: 'forms'
    },
    // NOTE: do not include XNode (id must be the same as used by DefaultDOMElement)
    ignore: ['./XNode'],
    buble: Boolean(transpileToES5),
    cleanup: Boolean(cleanup)
  })
}

function _minifyLib() {
  b.minify('./dist/substance-forms.js', './dist/substance-forms.min.js')
}

b.task('assets', function() {
  b.copy('node_modules/font-awesome', './dist/lib/font-awesome')
  b.css('./node_modules/substance/substance-reset.css', './dist/substance-reset.css')
  b.css('./lib/substance-forms.css', './dist/substance-forms.css', { variables: true })
})

b.task('clean', function() {
  b.rm('./dist');
})

b.task('examples', function() {
  b.copy('./examples/index.html', './dist/')
  b.copy('./examples/comments.html', './dist/')
})

b.task('lib', function() {
  _buildLib('transpile', 'clean')
  _minifyLib()
})

b.task('dev:lib', function() {
  _buildLib()
})

b.task('default', ['clean', 'assets', 'examples', 'lib'])
b.task('dev', ['clean', 'assets', 'examples', 'dev:lib'])

b.setServerPort(5555)
b.serve({
  static: true, route: '/', folder: 'dist'
})
