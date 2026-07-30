require("dotenv").config();

const cloudinary = require("cloudinary").v2;
const { CloudinaryStorage } = require("multer-storage-cloudinary");

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: "plantique/blogs",
    allowed_formats: ["jpg", "jpeg", "png", "webp"],
    transformation: [{ quality: "auto:good", fetch_format: "auto" }],
    public_id: () => `blog_${Date.now()}`,
  },
});
const plantStorage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: process.env.CLD_PLANTS_FOLDER || "plantique/plants",
    resource_type: "image",
    allowed_formats: ["jpg", "jpeg", "png", "webp"],
    transformation: [{ quality: "auto:good", fetch_format: "auto" }],
    public_id: () => `plant_${Date.now()}`,
  },
});
const arMixedStorage = new CloudinaryStorage({
  cloudinary,
  params: async (req, file) => {
    const arFolder = process.env.CLD_AR_FOLDER || "plantique/ar_models";
    const thumbFolder = process.env.CLD_AR_THUMBS || "plantique/ar_thumbs";

    if (file.fieldname === "model") {
      return {
        folder: arFolder,
        resource_type: "raw",
        allowed_formats: ["glb", "gltf"],
        public_id: () => `ar_${Date.now()}`,
      };
    }
    if (file.fieldname === "thumbnail") {
      return {
        folder: thumbFolder,
        resource_type: "image",
        allowed_formats: ["jpg", "jpeg", "png", "webp"],
        transformation: [{ quality: "auto:good", fetch_format: "auto" }],
        public_id: () => `ar_thumb_${Date.now()}`,
      };
    }
    // Fallback (shouldn't be used)
    return {
      folder: "plantique/misc",
      resource_type: "auto",
    };
  },
});
module.exports = { arMixedStorage, cloudinary, storage, plantStorage };
