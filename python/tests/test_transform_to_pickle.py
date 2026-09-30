import contextlib
import datetime
import io
import os
import tempfile
import unittest
from zoneinfo import ZoneInfo

import pandas as pd

from ..transform_to_pickle import Meta, TransformToPickle


class TransformToPickleTestCase(unittest.TestCase):
    sut = TransformToPickle()

    def test_apply_timezone_plusOffset(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link.csv', time_col_name='timestamp')
        # execute
        actual = self.sut.adjust_timestamps(data, timezone='+02:00', time_col_name='timestamp')
        # verify
        # csv value: 2013-08-08 06:47:31, a UTC instant
        expected = datetime.datetime(2013, 8, 8, 8, 47, 31, tzinfo=ZoneInfo('Europe/Berlin'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=None), actual['timestamp_utc'][0].to_pydatetime())

    def test_apply_timezone_name_kolkata(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link.csv', time_col_name='timestamp')
        # execute
        # Asia/Kolkata aka UTC+05:30
        actual = self.sut.adjust_timestamps(data, timezone='Asia/Kolkata', time_col_name='timestamp')
        # verify
        # csv value: 2013-08-08 06:47:31, a UTC instant
        # 06:47:31 UTC is 12:17:31 at UTC+05:30 on the same day - India has no DST
        expected = datetime.datetime(2013, 8, 8, 12, 17, 31, tzinfo=ZoneInfo('Asia/Kolkata'))
        self.assertEqual(expected, actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2013, 8, 8, 6, 47, 31, tzinfo=None), actual['timestamp_utc'][0].to_pydatetime())

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

    def test_an_instant_in_the_repeated_dst_hour_should_convert(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link-dst-ambiguous.csv', time_col_name='timestamp')
        # execute
        actual = self.sut.adjust_timestamps(data, timezone='Europe/London', time_col_name='timestamp')
        # verify: 01:16:03 UTC is 01:16:03 GMT, just after British Summer Time ended at 01:00 UTC
        self.assertEqual(datetime.datetime(2013, 10, 27, 1, 16, 3, tzinfo=datetime.timezone.utc), actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2013, 10, 27, 1, 16, 3), actual['timestamp_utc'][0].to_pydatetime())

    def test_an_instant_in_the_skipped_dst_hour_should_convert(self):
        # prepare
        data = self.sut.read_data_csv(file_path='./python/tests/data/link-dst-nonexistent.csv', time_col_name='timestamp')
        # execute
        actual = self.sut.adjust_timestamps(data, timezone='Europe/London', time_col_name='timestamp')
        # verify: 01:24:20 UTC is 02:24:20 BST, British Summer Time began at 01:00 UTC
        self.assertEqual(datetime.datetime(2014, 3, 30, 1, 24, 20, tzinfo=datetime.timezone.utc), actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2014, 3, 30, 1, 24, 20), actual['timestamp_utc'][0].to_pydatetime())

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

    def test_it_should_warn_about_every_track_movingpandas_drops(self):
        # arrange: track `a` has one fix, movingpandas needs two for a trajectory
        data = pd.DataFrame({
            'track': ['a', 'b', 'b'],
            'timestamp_utc': pd.to_datetime(['2021-07-01 06:40', '2021-07-01 06:40', '2021-07-01 06:46']),
            'coords_x': [1.0, 2.0, 2.1],
            'coords_y': [1.0, 2.0, 2.1],
        })
        output = io.StringIO()

        # act
        with contextlib.redirect_stdout(output):
            self.sut.create_moving_pandas(data=data, projection='EPSG:4326', track_id_col_name='track')

        # assert
        actual = [line for line in output.getvalue().splitlines() if line.startswith('[WARN]')]
        self.assertEqual(['[WARN] track a dropped: a trajectory needs at least two fixes, it has 1'], actual)

if __name__ == '__main__':
    unittest.main()
