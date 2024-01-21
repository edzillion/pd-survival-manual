const fs = require("node:fs");
const path = require("node:path");
const strip = require("strip-comments");

const files = fs.readdirSync("source");
const luaFiles = files.filter((file) => {
	return path.extname(file) === ".lua";
});

const logLines = /^.*log\..*$/gm;
const logImports = /^.*= import "pd-log".*$/gm;

console.info("stripping files");
luaFiles.forEach(function (filename) {
	var file = fs.readFileSync("source/" + filename, "utf8");
	var modifiedText = file.replace(logLines, "");
	modifiedText = modifiedText.replace(logImports, "");
	modifiedText = strip(modifiedText, { language: "lua" });
	fs.writeFileSync("source/" + filename, modifiedText);
  console.info("stripped " + filename);
});
console.info("stripping files complete.");