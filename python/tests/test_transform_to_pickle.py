import datetime
import unittest
from zoneinfo import ZoneInfo
from ..transform_to_pickle import TransformToPickle


class TransformToPickleTestCase(unittest.TestCase):
    sut = TransformToPickle()

    def test_apply_timezone_plusOffset(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/sample/buffer.csv')
        # execute
        actual = self.sut.adjust_timestamps(data, '+02:00')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('Europe/Berlin'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())

    def test_apply_timezone_name(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/sample/buffer.csv')
        # execute
        actual = self.sut.adjust_timestamps(data, 'Asia/Kolkata')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('Asia/Kolkata'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())

    def test_apply_timezone_name(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/sample/buffer.csv')
        # execute
        actual = self.sut.adjust_timestamps(data, 'UTC')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('UTC'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())


if __name__ == '__main__':
    unittest.main()
