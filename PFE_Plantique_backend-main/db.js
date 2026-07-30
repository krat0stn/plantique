const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    // Default local MongoDB URI
    const conn = await mongoose.connect('mongodb://localhost:27017/plantiquedb');
    
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1); // Exit with failure
  }
};

module.exports = connectDB;