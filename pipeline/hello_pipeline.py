from typing import NamedTuple

import google.cloud.aiplatform as aip
from kfp import dsl
from kfp.v2 import compiler
from kfp.v2.dsl import component

@component(output_component_file="hw.yaml", base_image="python:3.9")
def hello_world(text: str) -> str:
    print(text)
    return text

@component(packages_to_install=["google-cloud-storage"])
def two_outputs(
    text: str,
) -> NamedTuple(
    "Outputs",
    [
        ("output_one", str),  # Return parameters
        ("output_two", str),
    ],
):
    # the import is not actually used for this simple example, but the import
    # is successful, as it was included in the `packages_to_install` list.
    from google.cloud import storage  # noqa: F401

    o1 = f"output one from text: {text}"
    o2 = f"output two from text: {text}"
    print("output one: {}; output_two: {}".format(o1, o2))
    return (o1, o2)

@component
def consumer(text1: str, text2: str, text3: str):
    print(f"text1: {text1}; text2: {text2}; text3: {text3}")

@dsl.pipeline(
    name="hello-world-v2",
    description="A simple intro pipeline",
    pipeline_root="gs://df-data-science-test-pipelines/out",
)

def pipeline(text: str = "hi there"):
    hw_task = hello_world(text)
    two_outputs_task = two_outputs(text)
    consumer_task = consumer(  # noqa: F841
        hw_task.output,
        two_outputs_task.outputs["output_one"],
        two_outputs_task.outputs["output_two"],
    )

compiler.Compiler().compile(pipeline_func=pipeline, package_path="intro_pipeline.json")
