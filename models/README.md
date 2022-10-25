# Model directory

Each folder in this directory contains a model.

When you create a folder here it will generate a workbench, a training pipeline scheduled training.

## Basic model

In the basic model version you add a config.yaml containing schedule and (optionally) machine hardware details. Then you add a Dockerfile which will be built on commit time and run on schedule time.

## Advanced model

In the advanced model version you add a config.yaml as before, but instead of a Dockerfile you specify your own clouldbuild.yaml (which will trigger on commit time) and your own requirements.txt+pipeline.py (which will trigger on schedule time). This allows you to build training pipelines with data, training, validation and hosting.

## `config.yaml`

```
gpu_count=0


## TODO document:
- default cloudbuild.yaml
- config.yaml
- separation of workbench and pipeline?
- pipeline.py
