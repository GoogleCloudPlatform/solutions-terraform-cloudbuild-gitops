const path = require('path');

module.exports = {
  // The entry point file described above
  entry: './src/index.js',
  // The location of the build folder described above
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'bundle.js'
  },
  module: {
    rules: [{
            test: /\.css$/,
            include: [
                path.resolve(__dirname, 'src')
            ],
            use: ['style-loader', 'css-loader']
        }
    ]
  }
};