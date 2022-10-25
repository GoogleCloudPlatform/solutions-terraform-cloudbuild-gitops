# Machine learning platform experiment

Investigations into managing vertex.ai with terraform to get a proper CI/CD workflow and make suitable abstractions for easy developer experience.

## Goals:
- A personal workbench with jupyter labs and flexible hardware/framework/versions for model development
- Scheduled pipelines for periodically training (and versionning) machine learning models
- Hosting models with cloud run to make experimentation cheaper

## TODO:
- Move google cloud project to Schibsted owned GCP
- Move Github project to GHE
- Specify least access service accounts
- Access to data lake buckets and postgres databases
- Read schedule param
- Cloud run model hosting in pipeline
- Dockerfile "pipeline"

All done "automagically" according to our chosen development flow
