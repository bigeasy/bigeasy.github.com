var tar = require("./lib/tar"),
    fs  = require("fs");

/* Pluck a file from a tarball and write to stdout. */
function cat(tarfile, filename) {
  var reader = new tar.Reader();
  reader.on("entry", function (header, stream) {
    if (filename == header.name) {
      stream.pipe(process.stdout);
    }
  });
  readable = fs.createReadStream(tarfile);
  readable.pipe(reader);
}

cat("hello.tar", "hello/hello.txt");
