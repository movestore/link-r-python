import datetime
import unittest
from zoneinfo import ZoneInfo

import pytz

from ..transform_to_pickle import TransformToPickle


class TransformToPickleTestCase(unittest.TestCase):
    sut = TransformToPickle()

    def test_apply_timezone_plusOffset(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link.csv', time_col_name='timestamp')
        # execute
        actual = self.sut.adjust_timestamps(data, timezone='+02:00', time_col_name='timestamp')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('Europe/Berlin'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2013, 8, 8, 4, 47, 31, tzinfo=None), actual['timestamp_utc'][0].to_pydatetime())

    def test_apply_timezone_name(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link.csv', time_col_name='timestamp')
        # execute
        # Asia/Kolkata aka UTC+05:30
        actual = self.sut.adjust_timestamps(data, timezone='Asia/Kolkata', time_col_name='timestamp')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('Asia/Kolkata'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2013, 8, 7, 23, 17, 31, tzinfo=None), actual['timestamp_utc'][0].to_pydatetime())

    def test_apply_timezone_name(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link.csv', time_col_name='timestamp')
        # execute
        actual = self.sut.adjust_timestamps(data, timezone='UTC', time_col_name='timestamp')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('UTC'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=None), actual['timestamp_utc'][0].to_pydatetime())

    def test_ambiguous_dst_timestamp_should_raise_error(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link-dst-ambiguous.csv', time_col_name='timestamp')
        # execute & verify
        # pytz.exceptions.AmbiguousTimeError: Cannot infer dst time from 2013-10-27 01:16:03, try using the 'ambiguous' argument
        self.assertRaises(pytz.exceptions.AmbiguousTimeError, self.sut.adjust_timestamps, data, timezone='Europe/London', time_col_name='timestamp')

    def test_non_existent_timestamp_should_raise_error(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link-dst-nonexistent.csv', time_col_name='timestamp')
        # execute & verify
        # pytz.exceptions.NonExistentTimeError: 2014-03-30 01:24:20
        self.assertRaises(pytz.exceptions.NonExistentTimeError, self.sut.adjust_timestamps, data, timezone='Europe/London', time_col_name='timestamp')

if __name__ == '__main__':
    unittest.main()
