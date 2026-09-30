import gzip
import os
import shutil
import tempfile
import unittest

from ..transform_to_csv import TransformToCsv
from ..transform_to_pickle import TransformToPickle


class TransformToCsvTestCase(unittest.TestCase):
    """
    MoveApps hands the App a path without a file extension, so none of these cases may rely on the
    file name to tell compressed from uncompressed data.
    """

    sut = TransformToCsv()

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.compressed = os.path.join(self.tmp.name, 'output_file')
        TransformToPickle().convert(
            input_data_file_name='./python/sample/input4/link.csv',
            input_meta_file_name='./python/sample/input4/meta.csv',
            output_file_name=self.compressed
        )

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_it_should_read_a_gzip_compressed_pickle(self):
        # prepare: `setUp` produced it under a name without an extension

        # execute
        actual = self.sut.read_data_pickle(file_path=self.compressed)

        # verify: the sample carries three distinct tracks
        self.assertEqual(3, len(actual.trajectories))

    def test_it_should_read_an_uncompressed_pickle_written_by_an_older_app(self):
        # prepare
        legacy = self.__uncompressed_copy()

        # execute
        actual = self.sut.read_data_pickle(file_path=legacy)

        # verify
        self.assertEqual(3, len(actual.trajectories))

    def test_it_should_detect_gzip_compression(self):
        # prepare: `setUp` produced it

        # execute
        actual = self.sut.detect_compression(file_path=self.compressed)

        # verify
        self.assertEqual('gzip', actual)

    def test_it_should_detect_the_absence_of_compression(self):
        # prepare
        legacy = self.__uncompressed_copy()

        # execute
        actual = self.sut.detect_compression(file_path=legacy)

        # verify: `None` is how pandas is told not to decompress at all
        self.assertIsNone(actual)

    def test_it_should_write_crs_timezone_and_column_names_to_the_meta_csv(self):
        # arrange
        data = self.sut.read_data_pickle(file_path=self.compressed)
        geopandas = self.sut.create_geopandas(data=data)
        meta = os.path.join(self.tmp.name, 'meta.csv')

        # act
        self.sut.write_meta_csv(geopanda=geopandas, movingpanda=data, file_path=meta)

        # assert: the time column is the index movingpandas built from `timestamp_utc`
        with open(meta) as written:
            actual = written.read().splitlines()
        self.assertEqual(
            ['crs,tzone,timeColName,trackIdColName', 'EPSG:4326,UTC,timestamp_utc,individual_name_deployment_id'],
            actual
        )

    def test_it_should_write_the_time_index_and_the_coordinates_to_the_link_csv(self):
        # arrange
        data = self.sut.read_data_pickle(file_path=self.compressed)
        geopandas = self.sut.create_geopandas(data=data)
        link = os.path.join(self.tmp.name, 'link.csv')

        # act
        self.sut.write_result(file_name=link, data=geopandas)

        # assert
        with open(link) as written:
            actual = written.readline().rstrip('\n').split(',')
        self.assertEqual('timestamp_utc', actual[0])
        self.assertIn('coords_x', actual)
        self.assertIn('coords_y', actual)

    def __uncompressed_copy(self) -> str:
        """
        Unpacks the compressed output into what an App on the previous release would have written.

        Copies the pickle payload byte for byte instead of pickling again, so no pandas version
        difference can creep into the fixture.
        """
        target = os.path.join(self.tmp.name, 'legacy_output_file')
        with gzip.open(self.compressed, 'rb') as compressed, open(target, 'wb') as plain:
            shutil.copyfileobj(compressed, plain)
        return target
