import datetime
import unittest
from zoneinfo import ZoneInfo
from ..transform_to_pickle import TransformToPickle


class TransformToPickleTestCase(unittest.TestCase):
    sut = TransformToPickle()

    def test_apply_timezone_plusOffset(self):
        data = self.sut.read_data_csv(file_path='./python/sample/buffer.csv')
        actual = self.sut.adjust_timestamps(data, '+02:00')
        print(actual['timestamp_tz'][0])

        expected = datetime.datetime(2013, 8, 8, 8, 47, 31, tzinfo=ZoneInfo('Europe/Berlin'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())

    def test_apply_timezone_name(self):
        data = self.sut.read_data_csv(file_path='./python/sample/buffer.csv')
        actual = self.sut.adjust_timestamps(data, 'Asia/Kolkata')
        print(actual['timestamp_tz'][0])

        # 2013-08-08 06:47:31 +5:30:00
        expected = datetime.datetime(2013, 8, 8, 12, 17, 31, tzinfo=ZoneInfo('Asia/Kolkata'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())

    def test_apply_timezone_name(self):
        data = self.sut.read_data_csv(file_path='./python/sample/buffer.csv')
        actual = self.sut.adjust_timestamps(data, 'UTC')
        print(actual['timestamp_tz'][0])

        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('UTC'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())


if __name__ == '__main__':
    unittest.main()
