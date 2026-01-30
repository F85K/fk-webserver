// Init script voor MongoDB: zet standaard naam
// Dit script wordt uitgevoerd door een init job in Kubernetes of bij Docker Compose

// Database kiezen
const dbName = "fkdb";
const collectionName = "profile";

// Upsert document met de naam
const dbRef = db.getSiblingDB(dbName);

dbRef[collectionName].updateOne(
  { key: "name" },
  { $set: { key: "name", value: "Frank Koch" } },
  { upsert: true }
);
