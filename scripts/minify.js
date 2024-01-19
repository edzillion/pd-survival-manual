var luamin = require("luamin");
const fs = require("node:fs");
const path = require("node:path");

const files = fs.readdirSync('source');
const luaFiles = files.filter((file) => {	
	return path.extname(file) === ".lua";
});

console.info("minifying files");
luaFiles.forEach(function(file) {
  var fileText = fs.readFileSync('source/' + file, "utf8");
  var modifiedText = luamin.minify(fileText);
  fs.writeFileSync("source/" + file, modifiedText);
  console.info("minified " + file);
})
console.info("minifying files complete.");