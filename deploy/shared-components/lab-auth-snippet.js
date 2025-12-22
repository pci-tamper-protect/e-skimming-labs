// Lab Authentication Snippet
// Include this in lab HTML pages to add Firebase authentication
// Usage: 
//   <script src="http://localhost:3000/static/js/auth.js"></script>
//   <script>
//     initLabsAuth({
//       authRequired: true,
//       mainAppURL: 'http://localhost:3000',
//       firebaseProjectID: 'your-project-id',
//       authServiceURL: 'http://localhost:3000'  // home-index service URL
//     });
//   </script>
//
// Or use the auto-detection version:
//   <script src="http://localhost:3000/api/auth/config"></script>
//   <script src="http://localhost:3000/static/js/auth.js"></script>
//   <script>
//     // Auto-detect auth config from home-index service
//     fetch('http://localhost:3000/api/auth/config')
//       .then(res => res.json())
//       .then(config => {
//         if (config.authEnabled) {
//           initLabsAuth({
//             authRequired: config.authRequired,
//             mainAppURL: config.mainAppURL,
//             firebaseProjectID: config.firebaseProjectID,
//             authServiceURL: 'http://localhost:3000'
//           });
//         }
//       })
//       .catch(err => {
//         console.log('🔓 Auth not available, running without authentication');
//       });
//   </script>

