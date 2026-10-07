import os
import tempfile
import unittest

from ..transform_to_csv import TransformToCsv
from ..transform_to_pickle import TransformToPickle

CONTRACT_DIR = './test/contract'


class ContractTestCase(unittest.TestCase):
    """
    The CSV pair between R and python, pinned by golden files the v2.2.0 production images produced:
    R's link.csv and meta.csv go in, and what python hands back to R must equal py/link.csv and
    py/meta.csv byte for byte.
    """

    def test_it_should_hand_back_the_python_csv_pair_of_every_case(self):
        cases = sorted(case for case in os.listdir(CONTRACT_DIR) if os.path.isdir(os.path.join(CONTRACT_DIR, case)))
        self.assertEqual(6, len(cases))

        for case in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as tmp:
                # arrange
                case_dir = os.path.join(CONTRACT_DIR, case)
                pickle = os.path.join(tmp, 'output_file')
                link = os.path.join(tmp, 'link.csv')
                meta = os.path.join(tmp, 'meta.csv')
                TransformToPickle().convert(
                    input_data_file_name=os.path.join(case_dir, 'link.csv'),
                    input_meta_file_name=os.path.join(case_dir, 'meta.csv'),
                    output_file_name=pickle
                )

                # act
                TransformToCsv().convert(input_data_file_name=pickle, output_file_name=link, output_meta_file_name=meta)

                # assert
                self.assertEqual(self.__read(os.path.join(case_dir, 'py', 'meta.csv')), self.__read(meta))
                self.assertEqual(self.__read(os.path.join(case_dir, 'py', 'link.csv')), self.__read(link))

    @staticmethod
    def __read(file_path) -> bytes:
        with open(file_path, 'rb') as file:
            return file.read()
