from kfp.v2 import compiler, dsl
from kfp.v2.dsl import (Artifact,
                        Dataset,
                        Input,
                        Model,
                        Output,
                        Metrics,
                        ClassificationMetrics,
                        component, 
                        OutputPath, 
                        InputPath)

@component(
    packages_to_install=['google-cloud-secret-manager', 'requests'],
    base_image="python:3.9")
def trigger_cloudbuild():
    import requests
    from google.cloud import secretmanager

    secret_client = secretmanager.SecretManagerServiceClient()
    secret_name = f'projects/364866568815/secrets/webhook_trigger-secret-key-1/versions/2'
    response = secret_client.access_secret_version(request={"name": secret_name})
    payload = response.payload.data.decode("UTF-8")

    url = "https://cloudbuild.googleapis.com/v1/projects/df-data-science-test/triggers/webhook-trigger:webhook?key=AIzaSyBsvZCHfGKRyQUILboAp4q70yCpDGDYp8I&secret=" + payload

    myobj = {}
    x = requests.post(url, json = myobj)
    print(x.text)
    
    print(payload)

@component(
    packages_to_install=["pandas", "fsspec", "gcsfs"],
    base_image="python:3.9",
)
def get_dataset(
    url: str,
    train_ds: Output[Dataset],
):
    import pandas as pd

    df = pd.read_csv('gs://df-data-science-test-data/vt_data.csv')
    df.to_csv(train_ds.path + '/data.csv', index=False)
    print('hola')


@component(base_image="gcr.io/deeplearning-platform-release/tf2-gpu.2-10", output_component_file="component.yaml")
def train(
        dataset: Input[Dataset],
        model: Output[Model]
    ):

    import tensorflow as tf
    print(tf.__version__)
    print(tf.config.list_physical_devices())

    print(dataset)
    print(model)

@dsl.pipeline(
    name='training-pipeline',
    description='Learning to make a training pipeline',
    pipeline_root="gs://df-data-science-test-pipelines/out")
def pipeline(
    url: str = "gs://df-data-science-test-data/vt_data.csv"
):
    trigger_cloudbuild()
    data = get_dataset(url)

    result = (train(
            dataset=data.outputs["train_ds"]
        ).
        set_cpu_limit('4').
        set_memory_limit('64G').
        add_node_selector_constraint('cloud.google.com/gke-accelerator', 'NVIDIA_TESLA_T4').
        set_gpu_limit('1'))

    return result


compiler.Compiler().compile(pipeline_func=pipeline, package_path='pipeline.json')
