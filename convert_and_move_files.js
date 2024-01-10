const nodePandoc = require("node-pandoc");
const fs = require("node:fs");
const assert = require("assert");
const path = require("node:path");
const Jimp = require("jimp");

const FILTER_FOLDER = "filters";
const MARKDOWN_FOLDER = "SurvivalManual.wiki";
const OUTPUT_FOLDER = "source/json";

const MAX_IMAGE_DIMENSIONS = { x: 400, y: 1200 };

console.info("Starting convert_and_move_files.js script, checking folders ...");

fs.lstatSync(FILTER_FOLDER).isDirectory();
fs.lstatSync(MARKDOWN_FOLDER).isDirectory();
fs.lstatSync(OUTPUT_FOLDER).isDirectory();

const files = fs.readdirSync(MARKDOWN_FOLDER);
const mdFiles = files.filter((file) => path.extname(file) === ".md");
const filterFiles = fs.readdirSync(FILTER_FOLDER);
// const jpgFiles = null
// const pngFiles = null
const jpgFiles = files.filter((file) => path.extname(file) === ".jpg");
const pngFiles = files.filter((file) => path.extname(file) === ".png");

assert(mdFiles.length, "No .md files found in folder: /" + MARKDOWN_FOLDER);


fs.copyFile("playout/playout.lua", "source/playout.lua", (err) => {
	if (err) throw err;
	console.info("playout.lua copied to source folder");
});


console.info("Files found. Converting ...");

mdFiles.forEach(function (filename) {
	var name = path.parse(filename).name;
	args =
		"-f markdown-smart -t json --lua-filter=" +
		FILTER_FOLDER +
		"/" +
		filterFiles.join(" --lua-filter=" + FILTER_FOLDER + "/") +
		" -o " +
		OUTPUT_FOLDER +
		"/" +
		name +
		".json";

	console.info("args", args);
	nodePandoc(MARKDOWN_FOLDER + "/" + filename, args, function (err, success) {
		if (err) {
			console.warn("Pandoc failed to convert file: " + filename, err);
		}
		if (success) {
			console.info("Pandoc successfully converted file: " + filename);
		}
	});
});

function containImage(image, maxSizePt) {
	var width = image.bitmap.width;
	var height = image.bitmap.height;
	if (width > height) {
		if (width > maxSizePt.x) {
			width = maxSizePt.x;
			height = Jimp.AUTO;
		} else if (height > maxSizePt.y) {
			height = maxSizePt.y;
			width = Jimp.AUTO;
		}
	} else {
		if (height > maxSizePt.y) {
			height = maxSizePt.y;
			width = Jimp.AUTO;
		} else if (width > maxSizePt.x) {
			width = maxSizePt.x;
			height = Jimp.AUTO;
		}
	}
	image.resize(width, height);
  return image
}

if (jpgFiles) {
	console.info("JPG Files found. Converting ...");
	jpgFiles.forEach(function (filename) {
		var name = path.parse(filename).name;
		Jimp.read(MARKDOWN_FOLDER + "/" + filename, function (err, image) {
			if (err) {
				console.log(err);
			} else {
				image = containImage(image, MAX_IMAGE_DIMENSIONS)
				image.write("source/images/" + name + ".png");
				console.info("Jimp successfully converted image: " + filename);
			}
		});
	});
}

if (pngFiles) {
	console.info("PNG Files found. Converting ...");
	pngFiles.forEach(function (filename) {
		Jimp.read(MARKDOWN_FOLDER + "/" + filename, function (err, image) {
			if (err) {
				console.log(err);
			} else {
        image = containImage(image, MAX_IMAGE_DIMENSIONS);
				image.write("source/images/" + filename);
				console.info("Jimp successfully converted image: " + filename);
			}
		});
	});
}
