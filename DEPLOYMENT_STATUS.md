# E-Skimming Labs - Deployment Status

## Production Deployment URLs

### Home Services (labs-home-prd)
- **Index**: https://home-index-prd-hbqgpdhiza-uc.a.run.app
- **SEO Service**: https://home-seo-prd-hbqgpdhiza-uc.a.run.app

### Labs Services (labs-prd)
- **Index**: https://labs-index-prd-mmwwcfi5za-uc.a.run.app
- **Analytics**: https://labs-analytics-prd-mmwwcfi5za-uc.a.run.app
- **Lab 1 - Basic Magecart**: https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app
- **Lab 2 - DOM Skimming**: https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app
- **Lab 3 - Extension Hijacking**: https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app

## C2 Servers
Each lab has a built-in C2 server accessible at:
- **Lab 1**: https://lab-01-basic-magecart-prd-mmwwcfi5za-uc.a.run.app/stolen
- **Lab 2**: https://lab-02-dom-skimming-prd-mmwwcfi5za-uc.a.run.app/stolen-data
- **Lab 3**: https://lab-03-extension-hijacking-prd-mmwwcfi5za-uc.a.run.app/data-exfil

## Status
✅ All services deployed successfully
✅ Artifact Registry repositories created
✅ Service accounts configured
✅ GitHub Actions workflow running automatically on push
✅ Lab URLs now point to actual Cloud Run service URLs
✅ C2 servers working correctly

## How It Works
1. Home page (labs-index-prd) generates lab URLs using environment variables
2. Each lab is deployed as a separate Cloud Run service
3. C2 servers are built into each lab service at different endpoints
4. Navigation buttons detect Cloud Run hostnames and use correct URLs
