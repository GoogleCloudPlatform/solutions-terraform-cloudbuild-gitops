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
    packages_to_install=["pandas", "numpy", "fsspec", "gcsfs"],
    base_image="python:3.9",
)
def get_dataset(
    url: str,
    train_ds: Output[Dataset],
):
    import pandas as pd
    import numpy as np

    input_data = pd.DataFrame(np.random.random((128, 32)))
    target_data = pd.DataFrame(np.random.random((128, 1)))

    df.to_csv(train_ds.path + '/input.csv', header=None, index=False)
    df.to_csv(train_ds.path + '/target.csv', header=None, index=False)


@component(
    base_image="gcr.io/deeplearning-platform-release/tf2-gpu.2-10",
    packages_to_install=["pandas", "numpy", "fsspec", "gcsfs"])
def train(
        dataset: Input[Dataset],
        model: Output[Model]
    ):

    import pandas as pd
    import tensorflow as tf
    print(tf.__version__)
    print(tf.config.list_physical_devices())

    def get_model():
        # Create a simple model.
        inputs = keras.Input(shape=(32,))
        outputs = keras.layers.Dense(1)(inputs)
        model = keras.Model(inputs, outputs)
        model.compile(optimizer="adam", loss="mean_squared_error")

        return model


    my_model = get_model()
    
    # Train the model.
    test_input = pd.read_csv(dataset.path + '/input.csv').values
    test_input = pd.read_csv(dataset.path + '/target.csv').values
    # test_input = np.random.random((128, 32))
    # test_target = np.random.random((128, 1))
    my_model.fit(test_input, test_target)

    my_model.save(model.path + '/my_model')


@component(
    packages_to_install=['google-cloud-secret-manager', 'requests'],
    base_image="python:3.9")
def serve(
    model: Input[Model]
):
    import requests
    from google.cloud import secretmanager

    print(model.path)

    secret_client = secretmanager.SecretManagerServiceClient()
    secret_name = f'projects/364866568815/secrets/webhook_trigger-secret-key-1/versions/2'
    response = secret_client.access_secret_version(request={"name": secret_name})
    payload = response.payload.data.decode("UTF-8")

    url = "https://cloudbuild.googleapis.com/v1/projects/df-data-science-test/triggers/webhook-trigger:webhook?key=AIzaSyBsvZCHfGKRyQUILboAp4q70yCpDGDYp8I&secret=" + payload

    myobj = {}
    x = requests.post(url, json = myobj)
    print(x.text)
    
    print(payload)


@dsl.pipeline(
    name='training-pipeline',
    description='Learning to make a training pipeline',
    pipeline_root="gs://df-data-science-test-pipelines/out")
def pipeline(
    url: str = "gs://df-data-science-test-data/vt_data.csv"
):
    data_op = get_dataset(url)

    train_op = (train(
            dataset=data_op.outputs["train_ds"]
        ).
        set_cpu_limit('4').
        set_memory_limit('64G').
        add_node_selector_constraint('cloud.google.com/gke-accelerator', 'NVIDIA_TESLA_T4').
        set_gpu_limit('1'))

    serve(train_op.outputs["model"])


compiler.Compiler().compile(pipeline_func=pipeline, package_path='pipeline.json')
