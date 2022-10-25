import sys
import kfp
from kfp.v2 import compiler, dsl

MODEL_NAME = sys.argv[1]

component_text = """
name: {model_name}
description: Default Dockerfile based pipeline for {model_name}

implementation:
  container:
    image: europe-west4-docker.pkg.dev/df-data-science-test/df-ds-repo/{model_name}:latest
""".format(
  model_name = MODEL_NAME
)

default_op = kfp.components.load_component_from_text(component_text)

@dsl.pipeline(
    name=MODEL_NAME,
    description="Default training pipeline for model",
    pipeline_root="gs://df-data-science-test-pipelines/out")
def pipeline():
  default_op()


compiler.Compiler().compile(pipeline_func=pipeline, package_path='pipeline.json')
