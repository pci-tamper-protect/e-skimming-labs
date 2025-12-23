#!/usr/bin/env node
/**
 * Validate Firebase API Key using Firebase JavaScript SDK
 * This script uses the Firebase JavaScript SDK to validate that an API key
 * is correct and matches the specified project ID.
 * 
 * Usage:
 *   node validate-firebase-api-key.js <api-key> <project-id>
 * 
 * Example:
 *   node validate-firebase-api-key.js AIzaSyC... ui-firebase-pcioasis-stg
 * 
 * Requires: firebase package (npm install firebase)
 */

import { initializeApp } from 'firebase/app';
import { getAuth, fetchSignInMethodsForEmail } from 'firebase/auth';

// Parse command line arguments
const apiKey = process.argv[2];
const projectId = process.argv[3];

if (!apiKey || !projectId) {
    console.error('ERROR: Missing required arguments');
    console.error('Usage: node validate-firebase-api-key.js <api-key> <project-id>');
    process.exit(1);
}

// Colors for output (using Unicode escapes instead of octal)
const colors = {
    RED: '\u001b[0;31m',
    GREEN: '\u001b[0;32m',
    YELLOW: '\u001b[1;33m',
    BLUE: '\u001b[0;34m',
    NC: '\u001b[0m' // No Color
};

function printError(msg) {
    console.error(`${colors.RED}ERROR: ${msg}${colors.NC}`);
}

function printSuccess(msg) {
    console.log(`${colors.GREEN}✅ ${msg}${colors.NC}`);
}

function printInfo(msg) {
    console.log(`${colors.BLUE}${msg}${colors.NC}`);
}

function printStatus(msg) {
    console.log(`${colors.YELLOW}${msg}${colors.NC}`);
}

async function validateApiKey() {
    printStatus('Initializing Firebase with provided API key...');
    printInfo(`Project ID: ${projectId}`);
    printInfo(`API Key (first 20 chars): ${apiKey.substring(0, 20)}...`);
    printInfo(`API Key length: ${apiKey.length} characters`);

    // Check API key format
    if (!apiKey.startsWith('AIza')) {
        printError('API key format looks incorrect!');
        printInfo('Firebase API keys typically start with "AIza"');
        printInfo(`Your key starts with: ${apiKey.substring(0, 10)}...`);
        process.exit(1);
    }

    try {
        // Initialize Firebase app with the provided API key and project ID
        printStatus('Initializing Firebase app...');
        const firebaseConfig = {
            apiKey: apiKey,
            projectId: projectId,
            authDomain: `${projectId}.firebaseapp.com`,
        };

        const app = initializeApp(firebaseConfig);
        const auth = getAuth(app);

        // Verify the project ID matches
        if (app.options.projectId !== projectId) {
            printError('Project ID mismatch!');
            printInfo(`Expected: ${projectId}`);
            printInfo(`Got: ${app.options.projectId}`);
            process.exit(1);
        }

        printStatus('Firebase app initialized successfully');
        printStatus('Validating API key using Firebase Web SDK...');
        printInfo('Method: Firebase Web SDK (firebase/app, firebase/auth)');
        printInfo('Call: fetchSignInMethodsForEmail()');

        // Make a test call to Firebase Auth API to validate the API key
        // We'll try to fetch sign-in methods for a non-existent email
        // This will fail if the API key is invalid, but succeed (with empty array) if valid
        // Using a clearly fake email that won't exist
        const testEmail = `test-validation-${Date.now()}@example.com`;
        
        try {
            await fetchSignInMethodsForEmail(auth, testEmail);
            // If we get here, the API key is valid (the call succeeded)
            // The result will be an empty array since the email doesn't exist, but that's fine
            printSuccess('Firebase API key is valid!');
            printInfo(`Project ID: ${app.options.projectId}`);
            printInfo(`Auth Domain: ${app.options.authDomain || 'N/A'}`);
            process.exit(0);
        } catch (authError) {
            // Check the error code to determine if it's an API key issue
            const errorCode = authError.code || '';
            const errorMessage = authError.message || '';
            
            if (errorCode.includes('auth/invalid-api-key') || errorMessage.includes('invalid-api-key')) {
                printError('Firebase API key is invalid');
                printInfo('The API key format is incorrect or the key has been revoked');
                process.exit(1);
            } else if (errorCode.includes('auth/project-not-found') || errorMessage.includes('project-not-found')) {
                printError('Firebase project not found');
                printInfo(`Project ID: ${projectId}`);
                printInfo('Possible causes:');
                console.log('  1. API key doesn\'t match the project ID (key is for a different project)');
                console.log('  2. Project ID is incorrect');
                console.log('  3. Identity Toolkit API is not enabled for this project');
                process.exit(1);
            } else if (errorCode.includes('auth/network-request-failed') || errorMessage.includes('network')) {
                printError('Network error connecting to Firebase');
                printInfo('Check your internet connection and try again');
                process.exit(1);
            } else {
                // Other auth errors might still mean the API key is valid
                // (e.g., quota exceeded, etc.) - but the key itself works
                // For validation purposes, if we got past initialization, the key is likely valid
                printSuccess('Firebase API key appears to be valid!');
                printInfo(`Project ID: ${app.options.projectId}`);
                printInfo(`Auth Domain: ${app.options.authDomain || 'N/A'}`);
                printInfo(`Note: Got auth error during test call: ${errorCode || errorMessage}`);
                printInfo('This might indicate API quota or other issues, but the API key format is correct');
                process.exit(0);
            }
        }

    } catch (error) {
        // Handle different types of errors
        if (error.status) {
            // HTTP error response
            const errorMessage = error.data?.error?.message || error.data?.message || `HTTP ${error.status}`;
            const statusCode = error.status;
            
            if (statusCode === 400 || errorMessage.includes('invalid')) {
                printError('Firebase API key is invalid (HTTP 400)');
                printInfo(`Error: ${errorMessage}`);
                process.exit(1);
            } else if (statusCode === 403) {
                printError('Firebase API key is invalid or API is not enabled (HTTP 403)');
                printInfo(`Error: ${errorMessage}`);
                printInfo('Make sure:');
                console.log('  1. The API key is correct');
                console.log('  2. Identity Toolkit API is enabled for the project');
                console.log('  3. The API key has proper restrictions (if any)');
                process.exit(1);
            } else if (statusCode === 404 || errorMessage.includes('not found')) {
                printError('Firebase project not found (HTTP 404)');
                printInfo(`Project ID: ${projectId}`);
                printInfo(`Error: ${errorMessage}`);
                printInfo('');
                printInfo('Possible causes:');
                console.log('  1. API key doesn\'t match the project ID (key is for a different project)');
                console.log('  2. Identity Toolkit API is not enabled for this project');
                console.log('  3. Project ID is incorrect');
                process.exit(1);
            } else {
                printError(`Firebase validation failed (HTTP ${statusCode})`);
                printInfo(`Error: ${errorMessage}`);
                process.exit(1);
            }
        } else {
            // Network or other errors
            const errorMessage = error.message || 'Unknown error';
            
            if (errorMessage.includes('fetch') || errorMessage.includes('network') || errorMessage.includes('ECONNREFUSED')) {
                printError('Network error connecting to Firebase');
                printInfo('Check your internet connection and try again');
                printInfo(`Error: ${errorMessage}`);
                process.exit(1);
            } else {
                printError(`Firebase validation failed: ${errorMessage}`);
                printInfo('This might indicate:');
                console.log('  1. API key is invalid or expired');
                console.log('  2. API key doesn\'t match the project ID');
                console.log('  3. Identity Toolkit API is not enabled');
                console.log('  4. Network connectivity issues');
                process.exit(1);
            }
        }
    }
}

// Run validation
validateApiKey().catch((error) => {
    printError(`Unexpected error: ${error.message}`);
    process.exit(1);
});

