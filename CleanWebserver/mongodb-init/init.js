// ============================================
// FK Webstack - MongoDB Initialization Script
// ============================================
//
// This script runs when MongoDB container starts
// It creates the fkdb database with initial profile data

// Authenticate with root credentials
// (When run via initdb, auth is not required for init scripts)

// Switch to fkdb database
const db = db.getSiblingDB('fkdb');

// Create profile collection if it doesn't exist
db.createCollection('profile');

// Insert initial profile document with name
// Frontend calls /api/name which retrieves this document
db.profile.insertOne({
    name: 'Frank Koch',
    created_at: new Date(),
    updated_at: new Date()
});

print('✓ MongoDB initialized successfully');
print('✓ Database: fkdb');
print('✓ Collection: profile');
print('✓ Document: {name: "Frank Koch"}');

// Verify insert worked
const count = db.profile.countDocuments({});
print(`✓ Document count: ${count}`);;
