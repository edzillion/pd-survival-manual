const nodePandoc = require("node-pandoc");
const fs = require("node:fs");
const assert = require("assert");
const path = require("node:path");
const Jimp = require("jimp");
const MergeFiles = require("merge-files");

const FILTER_FOLDER = "filters";
const MARKDOWN_FOLDER = "SurvivalManual.wiki";
const OUTPUT_FOLDER = "source/json";

const MAX_IMAGE_DIMENSIONS = { x: 380, y: 1200 };

console.info("Starting convert_and_move_files.js script, checking folders ...");

fs.lstatSync(FILTER_FOLDER).isDirectory();
fs.lstatSync(MARKDOWN_FOLDER).isDirectory();
fs.lstatSync(OUTPUT_FOLDER).isDirectory();

const files = fs.readdirSync(MARKDOWN_FOLDER);
const mdFiles = files.filter((file) => {
	var fileTitle = path.basename(file, path.extname(file));
	return path.extname(file) === ".md" && fileTitle != "Home";
});

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

function runNodePandoc(src, args) {
	return new Promise((resolve, reject) => {
		nodePandoc(src, args, (err, data) => {
			if (err) {
				reject(err); // Reject the promise if there's an error
			} else {
				resolve(data); // Resolve the promise with the data
			}
		});
	});
}

// add toc
if (!fs.existsSync("temp")) {
	fs.mkdirSync("temp");
}
if (!fs.existsSync("temp/toc")) {
	fs.mkdirSync("temp/toc");
}
if (!fs.existsSync("temp/md")) {
	fs.mkdirSync("temp/md");
}

var tocArgs = [];
var filesToMerge = [];

// make toc
mdFiles.forEach(function (filename) {
	var args =
		"-s -f gfm --toc --template=templates/toc.tex -o temp/toc/" + filename;
	var src = MARKDOWN_FOLDER + "/" + filename;
	filesToMerge.push(["temp/toc/" + filename, src, "temp/md/" + filename]);
	tocArgs.push({ src: src, args: args });
});

var convertArgs = [];
// convert
mdFiles.forEach(function (filename) {
	var name = path.parse(filename).name;
	var src = "temp/md/" + filename;
	var args =
		"-f gfm-smart -t json --lua-filter=" +
		FILTER_FOLDER +
		"/" +
		filterFiles.join(" --lua-filter=" + FILTER_FOLDER + "/") +
		" -o " +
		OUTPUT_FOLDER +
		"/" +
		name +
		".json";
  console.log(args)
	convertArgs.push({ src: src, args: args });
});

// copy Home separately, since it doesn't need a TOC
fs.copyFile(MARKDOWN_FOLDER + "/Home.md", "temp/md/Home.md", (err) => {
	if (err) throw err;
	console.info("Home.md copied to temp folder");
});

async function processFiles() {
	console.info("Generating tocs");
	await Promise.all(
		tocArgs.map((tTask) => {
			return runNodePandoc(tTask.src, tTask.args)
				.then((results) => {
					console.info("Generating TOC successful: " + tTask.src);
				})
				.catch((error) => {
					throw error;
				});
		})
	)
		.then((results) => {
			console.info("Generating TOCs completed successfully.");
		})
		.catch((error) => {
			throw error;
		});

	copyFiles = [];

	filesToMerge = filesToMerge.filter((files) => {
		var file = fs.readFileSync(files[0], "utf8");
		if (file.trim() == "**TABLE OF CONTENTS**") {
			copyFiles.push(files[0].substring(9));
			return false;
		}
		return true;
	});

	console.info("Copying unmerged files");
	copyFiles.map((filename) =>
		fs.copyFileSync(MARKDOWN_FOLDER + "/" + filename, "temp/md/" + filename)
	);

	console.info("Merging files");
	await Promise.all(
		filesToMerge.map((twoFiles) =>
			MergeFiles([twoFiles[0], twoFiles[1]], twoFiles[2])
				.then(function (results) {
					console.info("Merging file successful: " + twoFiles[2]);
				})
				.catch(function (err) {
					console.log(err);
				})
		)
	)
		.then(function (results) {
			console.info("Merging files completed successfully.");
		})
		.catch(function (err) {
			console.log(err);
		});

	console.info("Converting markdown into json");
	await Promise.all(
		convertArgs.map((cTask) => {
			return runNodePandoc(cTask.src, cTask.args)
				.then((results) => {
					console.info("Conversion successful: " + results.trim());
					// fs.rmSync("temp", { recursive: true });
				})
				.catch((error) => {
					throw error;
				});
		})
	)
		.then((results) => {
			console.info("Conversion completed successfully.");
			// fs.rmSync("temp", { recursive: true });
		})
		.catch((error) => {
			throw error;
		});
}

processFiles();

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
	return image;
}

if (jpgFiles) {
	console.info("JPG Files found. Converting ...");
	jpgFiles.forEach(function (filename) {
		var name = path.parse(filename).name;
		Jimp.read(MARKDOWN_FOLDER + "/" + filename, function (err, image) {
			if (err) {
				console.log(err);
			} else {
				image = containImage(image, MAX_IMAGE_DIMENSIONS);
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
