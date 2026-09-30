import datetime
import os
import tempfile
import unittest
from zoneinfo import ZoneInfo

import pytz

from ..transform_to_pickle import Meta, TransformToPickle


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

    def test_apply_timezone_name_kolkata(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link.csv', time_col_name='timestamp')
        # execute
        # Asia/Kolkata aka UTC+05:30
        actual = self.sut.adjust_timestamps(data, timezone='Asia/Kolkata', time_col_name='timestamp')
        # verify
        # csv value: 2013-08-08 06:47:31
        expected = datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=ZoneInfo('Asia/Kolkata'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())
        # 06:47:31 at UTC+05:30 is 01:17:31 UTC on the same day - India has no DST
        self.assertEqual(datetime.datetime(2013, 8, 8, 1, 17, 31, tzinfo=None), actual['timestamp_utc'][0].to_pydatetime())

    def test_apply_timezone_name_utc(self):
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

    def test_it_should_write_a_gzip_compressed_pickle(self):
        # prepare
        with tempfile.TemporaryDirectory() as tmp:
            output = os.path.join(tmp, 'output_file')

            # execute
            self.sut.convert(
                input_data_file_name='./python/sample/input4/link.csv',
                input_meta_file_name='./python/sample/input4/meta.csv',
                output_file_name=output
            )

            # verify: compressed although the file name carries no extension
            with open(output, 'rb') as written:
                actual = written.read(2)
            self.assertEqual(b'\x1f\x8b', actual)

    def test_it_should_read_the_meta_csv(self):
        # arrange
        file_path = './python/sample/input4/meta.csv'

        # act
        actual = self.sut.read_meta_csv(file_path=file_path)

        # assert
        self.assertEqual(
            Meta(projection='EPSG:4326', timezone='UTC', time_col_name='timestamp', track_id_col_name='individual_name_deployment_id'),
            actual
        )

    def test_it_should_create_one_trajectory_per_track_in_the_crs_of_the_meta_csv(self):
        # arrange
        meta = self.sut.read_meta_csv(file_path='./python/sample/input4/meta.csv')
        data = self.sut.read_data_csv(file_path='./python/sample/input4/link.csv', time_col_name=meta.time_col_name)
        self.sut.adjust_timestamps(data=data, timezone=meta.timezone, time_col_name=meta.time_col_name)

        # act
        actual = self.sut.create_moving_pandas(data=data, projection=meta.projection, track_id_col_name=meta.track_id_col_name)

        # assert: the sample carries three distinct tracks
        self.assertEqual(3, len(actual.trajectories))
        self.assertEqual('EPSG:4326', actual.trajectories[0].df.crs.to_string())

if __name__ == '__main__':
    unittest.main()
