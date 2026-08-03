import datetime
import os
import tempfile
import unittest
from zoneinfo import ZoneInfo
from ..transform_to_pickle import TransformToPickle


class TransformToPickleTestCase(unittest.TestCase):
    sut = TransformToPickle()

    def test_apply_timezone_plusOffset(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/sample/link.csv')
        # execute
        actual = self.sut.adjust_timestamps(data, '+02:00')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('Europe/Berlin'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())

    def test_apply_timezone_name_kolkata(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/sample/link.csv')
        # execute
        actual = self.sut.adjust_timestamps(data, 'Asia/Kolkata')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('Asia/Kolkata'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())

    def test_apply_timezone_name_utc(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/sample/link.csv')
        # execute
        actual = self.sut.adjust_timestamps(data, 'UTC')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('UTC'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())

    def test_it_should_write_a_gzip_compressed_pickle(self):
        # prepare
        with tempfile.TemporaryDirectory() as tmp:
            output = os.path.join(tmp, 'output_file')

            # execute
            self.sut.convert(
                input_data_file_name='./python/sample/input3/link.csv',
                input_meta_file_name='./python/sample/input3/meta.csv',
                output_file_name=output
            )

            # verify: compressed although the file name carries no extension
            with open(output, 'rb') as written:
                actual = written.read(2)
            self.assertEqual(b'\x1f\x8b', actual)


if __name__ == '__main__':
    unittest.main()
