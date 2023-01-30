from transform_to_pickle import TransformToPickle

if __name__ == '__main__':
    TransformToPickle().convert(
        input_data_file_name='./sample/buffer_2-animals.csv',
        input_meta_file_name='./sample/meta.csv',
        output_file_name='./sample/out.pickle'
    )
