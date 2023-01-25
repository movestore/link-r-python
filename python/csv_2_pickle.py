import transform_to_pickle
import os

if __name__ == '__main__':
    transform_to_pickle.convert(
        input_data_file_name=os.environ['LINK_R_PYTHON_BUFFER'] or '/tmp/artifacts/buffer.csv',
        input_meta_file_name=os.environ['LINK_R_PYTHON_META'] or '/tmp/artifacts/meta.csv',
        output_file_name=os.environ['OUTPUT_FILE']
    )
