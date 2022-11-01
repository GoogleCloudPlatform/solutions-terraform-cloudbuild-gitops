# Machine learning platform experiment

Investigations into managing vertex.ai with terraform to get a proper CI/CD workflow and make suitable abstractions for easy developer experience.

## Goals:
- A personal workbench with jupyter labs and flexible hardware/framework/versions for model development
- Scheduled training pipelines for periodically training (and versionning) machine learning models
- Hosting models with cloud run to make hosting experimental and low traffic models easier and cheaper

All done "automagically" according to our chosen development flow

## TODO:
- Move google cloud project to Schibsted owned GCP
- Move Github project to GHE
- Specify least access service accounts
- Access to data lake buckets, postgres databases, pulse
- Cloud run model hosting in pipeline (in progress)

