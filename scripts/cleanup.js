const fs = require("fs");

console.info('deleting old .pdx folders')
fs.readdirSync("./").forEach((file, index) => {
	if (fs.lstatSync(file).isDirectory()) {
		if (file.endsWith(".pdx")) {
			fs.rmSync(file, { recursive: true, force: true });
		}
	}
});

console.info("deleting temp folders");
if (fs.existsSync('temp')) {
  fs.rmdirSync("temp", { recursive: true, force: true });
}
console.info("cleanup complete");

