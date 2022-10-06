import kfp

from typing import NamedTuple

from kfp.v2.dsl import pipeline
from kfp.v2.dsl import component
from kfp.v2 import compiler

@component() 
def concat(a: str, b: str) -> str:
  return a + b

@component
def reverse(a: str)->NamedTuple("outputs", [("before", str), ("after", str)]):
  return a, a[::-1]

@pipeline(name="basic-pipeline",
description="A simple intro pipeline", 
              pipeline_root='gs://df-data-science-test-pipeline/basic-pipeine')
def basic_pipeline(a: str='stres', b: str='sed'):
    concat_task = concat(a, b)
    reverse_task = reverse(concat_task.output)

if __name__ == '__main__':
    compiler.Compiler().compile(
        pipeline_func=basic_pipeline, package_path="basic_pipeline.json"
    )
