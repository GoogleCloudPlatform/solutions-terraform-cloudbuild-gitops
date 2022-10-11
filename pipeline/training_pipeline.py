from kfp import dsl, compiler
import kfp

@dsl.component(base_image="gcr.io/deeplearning-platform-release/tf2-gpu.2-10")
def train():
    import tensorflow as tf
    print(tf.__version__)
    print(tf.config.list_physical_devices())

    return 42

@dsl.pipeline(
    name='training-pipeline',
    description='Learning to make a training pipeline',
    pipeline_root="gs://df-data-science-test-pipelines/out")
def pipeline():
    '''
    result = (train().
        set_cpu_limit('4').
        set_memory_limit('64G').
        add_node_selector_constraint('NVIDIA_TESLA_P100').
        set_gpu_limit('1'))
    '''

    result = train()


compiler.Compiler().compile(pipeline, 'pipeline.json')
