from transform_to_csv import TransformToCsv
import os

if __name__ == '__main__':
    TransformToCsv().convert(
        input_data_file_name=os.environ['SOURCE_FILE'],
        output_file_name=os.environ.get('LINK_R_PYTHON_BUFFER', '/tmp/link.csv'),
        output_meta_file_name=os.environ.get('LINK_R_PYTHON_META', '/tmp/artifacts/meta.csv')
    )
