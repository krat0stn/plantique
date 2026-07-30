const multer = require("multer");

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "./storages");
  },
  filename: (req, file, cb) => {
    console.log(file.originalname);
    cb(null, file.originalname);
  },
});

module.exports = multer({ storage: storage }); //fileFilter: fileFilter, limits: { _fileSize: 1024 * 1024 * 1024 * 10 } });
