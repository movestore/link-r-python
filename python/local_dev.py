import transform_to_pickle

if __name__ == '__main__':
    transform_to_pickle.convert(
        input_data_file_name='./sample/buffer.csv',
        input_meta_file_name='./sample/meta.csv',
        output_file_name='./sample/out.pickle'
    )
