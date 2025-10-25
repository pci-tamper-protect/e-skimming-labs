# Deployment for Labs

We wish to deploy the labs for users to learn the attack techniques.

The labs should deploy to the following domains triggered by a merge to the
branch (main or stg).

- labs.pcioasis.com/lab<n>-shortname
- labs.stg.pcioasis.com/lab<n>-shortname

## index.html

A landing page with instructions for the lab. Selecting the variant. Link to the
github repository pcioasis/e-skimming-labs.

Deploy to CloudRun using github actions.
