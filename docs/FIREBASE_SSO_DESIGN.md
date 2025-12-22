# Firebase SSO Design for Multi-Domain Authentication

## Overview

This document outlines the design for implementing Single Sign-On (SSO) between `www.pcioasis.com` and `labs.pcioasis.com` using a shared Firebase project, while maintaining granular access control through custom claims and Firestore security rules.

## Architecture

### Shared Firebase Project

Both websites are configured as separate Firebase Web Apps within the same Firebase project (`ui-firebase-pcioasis-prd` for production, `ui-firebase-pcioasis-stg` for staging). This enables:

- **Unified Authentication**: Users sign in to the same Firebase Authentication user directory
- **Automatic SSO**: When a user logs in on one site, they can be automatically logged into the other
- **Shared User Accounts**: No need for separate user accounts per domain

### Authentication Domain (`authDomain`)

The `authDomain` configuration in Firebase initialization determines where Firebase Auth stores session data:

#### Production (`pcioasis.com` and `labs.pcioasis.com`)

```javascript
firebase.initializeApp({
  authDomain: "pcioasis.com",
  // ... other config
})
```

- Session data stored under `pcioasis.com` domain
- Accessible to all subdomains (`www.pcioasis.com`, `labs.pcioasis.com`)
- Both sites can access the same authentication state

#### Staging (`stg.pcioasis.com` and `labs.stg.pcioasis.com`)

```javascript
firebase.initializeApp({
  authDomain: "stg.pcioasis.com",
  // ... other config
})
```

- Session data stored under `stg.pcioasis.com` domain
- Accessible to all staging subdomains
- Isolated from production authentication state

#### Localhost Development

- Each port (`localhost:3000`, `localhost:3001`) stores session data separately
- No automatic SSO between different ports
- Use same `authDomain` configuration for testing

## Access Control Strategy

### Custom Claims

Custom claims are key-value pairs embedded in the user's Firebase ID token. They enable granular access control:

**Example Custom Claims:**
- `sign_up_domain: "labs.pcioasis.com"` - Tracks where user signed up
- `websiteAccess: ["primary", "secondary"]` - Defines which sites user can access
- `appRole: "primaryUser"` - Role-based access control

**Setting Custom Claims:**
- Only settable server-side using Firebase Admin SDK
- Tamper-proof (cannot be modified client-side)
- Automatically included in ID tokens

### Firestore Security Rules

Security rules inspect custom claims via `request.auth.token`:

**Primary Site Collections (www.pcioasis.com only):**
```javascript
match /primarySiteCollection/{document} {
  allow read, write: if request.auth.token.websiteAccess != null 
    && request.auth.token.websiteAccess.hasAny(['primary']);
}
```

**Labs Collections (labs.pcioasis.com only):**
```javascript
match /labsCollection/{document} {
  allow read, write: if request.auth.token.sign_up_domain == 'labs.pcioasis.com';
}
```

**Shared Collections (both sites):**
```javascript
match /sharedCollection/{document} {
  allow read, write: if request.auth != null;
}
```

## Service Account Security

### Problem

By default, Firebase Admin SDK uses a service account with broad administrative access, bypassing Firestore Security Rules. This would allow `labs.pcioasis.com` to access all Firestore collections, including those meant only for `www.pcioasis.com`.

### Solution: Restricted Service Account

Create a dedicated service account for labs with minimal required permissions:

**Required Permissions:**
- `firebaseauth.users.update` - To set custom claims on user tokens

**Restricted Permissions:**
- **No** broad Firestore permissions (`datastore.entities.*`)
- **Only** specific Firestore permissions for labs-specific collections (if needed)

**Implementation:**
1. Create custom IAM role with minimal permissions
2. Create new service account with this custom role
3. Initialize Admin SDK with restricted service account credentials

## Implementation Plan

### 1. Create Restricted Service Account

**Service Account Name:** `labs-auth-validator`

**Custom IAM Role:** `labs.firebase.authValidator`

**Permissions:**
- `firebaseauth.users.update` - Set custom claims
- `firebaseauth.users.get` - Read user information (optional, for validation)

**No Firestore Permissions** (unless specifically needed for labs collections)

### 2. Set Custom Claims

After user signs up or signs in on `labs.pcioasis.com`:

```javascript
// Cloud Function or backend service
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(restrictedServiceAccount),
  projectId: 'ui-firebase-pcioasis-prd'
});

await admin.auth().setCustomUserClaims(userId, {
  sign_up_domain: 'labs.pcioasis.com',
  websiteAccess: ['labs']
});
```

### 3. Firestore Security Rules

Update Firestore security rules to check custom claims:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Primary site collections
    match /primarySiteCollection/{document} {
      allow read, write: if request.auth != null 
        && request.auth.token.websiteAccess != null
        && 'primary' in request.auth.token.websiteAccess;
    }
    
    // Labs collections
    match /labsCollection/{document} {
      allow read, write: if request.auth != null
        && request.auth.token.sign_up_domain == 'labs.pcioasis.com';
    }
    
    // Shared collections
    match /sharedCollection/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Deployment Steps

1. **Create Custom IAM Role** - Define minimal permissions
2. **Create Service Account** - With restricted role
3. **Download Service Account Key** - Store securely
4. **Update Firestore Rules** - Add custom claim checks
5. **Deploy Cloud Function** - To set custom claims on sign-up/sign-in
6. **Update Client Apps** - Configure `authDomain` correctly

## Security Considerations

- **Least Privilege**: Service account has only minimum required permissions
- **Tamper-Proof**: Custom claims can only be set server-side
- **Domain Isolation**: Firestore rules prevent cross-domain data access
- **Token Validation**: All tokens validated server-side before granting access

## Testing

1. **Sign up on labs.pcioasis.com** → Verify custom claim is set
2. **Access labs collections** → Should succeed
3. **Access primary site collections** → Should fail (403)
4. **Sign in on www.pcioasis.com** → Should have different custom claims
5. **SSO between sites** → Should work seamlessly

## Troubleshooting

- **Custom claims not appearing**: Check token refresh (may need to sign out/in)
- **Access denied**: Verify Firestore security rules match custom claims
- **SSO not working**: Check `authDomain` configuration matches parent domain
- **Service account errors**: Verify IAM role permissions are correct
