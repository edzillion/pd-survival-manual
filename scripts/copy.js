const fsextra = require("fs-extra");

DEV_FOLDER = 'dev';

console.info("Copying source from " + DEV_FOLDER);
fsextra.copySync(DEV_FOLDER, "source");
