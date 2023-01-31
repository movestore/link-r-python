import os

import movingpandas as mpd
import pandas as pd
from dataclasses import dataclass


@dataclass
class Meta:
    projection: str
    timezone: str


class TransformToPickle:

    def read_meta_csv(self, file_path):
        meta_csv = pd.read_csv(file_path)
        projection = meta_csv['crs'][0]
        tzone = meta_csv['tzone'][0]
        meta = Meta(projection=projection, timezone=tzone)
        print(meta)
        return meta

    def read_data_csv(self, file_path):
        print(os.getcwd())
        csv = pd.read_csv(
            file_path,
            parse_dates=['timestamp'],
        )
        print(csv.info())
        return csv

    def adjust_timestamps(self, data, timezone):
        # kudos: https://stackoverflow.com/a/18912631/810944
        data['timestamp_tz'] = data['timestamp'].apply(lambda x: x.tz_localize(timezone))
        print('applied timezone', timezone)
        print(data.head())
        return data

    def create_moving_pandas(self, data, projection):
        move = mpd.TrajectoryCollection(
            data,
            traj_id_col='individual.local.identifier',
            crs=projection,
            t='timestamp_tz',  # use our converted timezone column
            x='location.long',
            y='location.lat'
        )
        print(move)
        return move

    def write_result(self, file_name, data):
        print(type(data))
        pd.to_pickle(data, file_name)

    def convert(self, input_data_file_name, input_meta_file_name, output_file_name):
        meta = self.read_meta_csv(input_meta_file_name)
        data = self.read_data_csv(input_data_file_name)
        self.adjust_timestamps(data=data, timezone=meta.timezone)
        movingpandas = self.create_moving_pandas(data=data, projection=meta.projection)
        self.write_result(file_name=output_file_name, data=movingpandas)
