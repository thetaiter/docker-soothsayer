var express = require('express');
var app = express();
var os = require('os');

var hostname = os.hostname();

app.get('/', function(req, res) {
  res.send('<html><head><title>' + hostname + '</title></head><body>Hello from NodeJS application running in container ' + hostname + '!</body></html>');
});

app.listen(3000, function() {
  console.log('My Application is running on port 3000');
});
