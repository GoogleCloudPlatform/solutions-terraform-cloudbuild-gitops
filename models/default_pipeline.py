import sys
from kfp.v2 import compiler, dsl

MODEL_NAME = sys.argv[1]

component_text = """
name: {model_name}
description: Default Dockerfile based pipeline for {model_name}

#inputs:
#- {name: input_1, type: String, description: 'Data for input_1'}
#- {name: parameter_1, type: Integer, default: '100', description: 'Number of lines to copy'}
#
#outputs:
#- {name: output_1, type: String, description: 'output_1 data.'}

implementation:
  container:
    image: europe-west4-docker.pkg.dev/df-data-science-test/df-ds-repo/{model_name}:latest
""".format(
  model_name = MODEL_NAME
)

default_op = dls.component.load_component_from_text(component_text)

@dsl.pipeline(
    name=MODEL_NAME,
    description="Default training pipeline for model"
)
def pipeline():
  default_op()


compiler.Compiler().compile(pipeline_func=pipeline, package_path='pipeline.json')
