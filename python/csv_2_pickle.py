from transform_to_pickle import TransformToPickle
import os

if __name__ == '__main__':
    TransformToPickle().convert(
        input_data_file_name=os.environ.get('LINK_R_PYTHON_BUFFER', '/tmp/artifacts/buffer.csv'),
        input_meta_file_name=os.environ.get('LINK_R_PYTHON_META', '/tmp/artifacts/meta.csv'),
        output_file_name=os.environ['OUTPUT_FILE']
    )
