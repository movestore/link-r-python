import os

import movingpandas as mpd
import pandas as pd
from dataclasses import dataclass


@dataclass
class Meta:
    projection: str
    timezone: str
    time_col_name: str
    track_id_col_name: str


class TransformToPickle:

    def read_meta_csv(self, file_path):
        meta_csv = pd.read_csv(file_path)
        projection = meta_csv['crs'][0]
        tzone = meta_csv['tzone'][0]
        time_col_name = meta_csv['timeColName'][0]
        track_id_col_name = meta_csv['trackIdColName'][0]
        
        meta = Meta(projection=projection, timezone=tzone, time_col_name=time_col_name, track_id_col_name=track_id_col_name)
        print(meta)
        return meta

    def read_data_csv(self, file_path, time_col_name):
        deserialized = pd.read_csv(
            file_path,
            parse_dates=[time_col_name],
        )
        print(deserialized.info())
        return deserialized

    def adjust_timestamps(self, data, timezone, time_col_name):
        # kudos: https://stackoverflow.com/a/18912631/810944
        data['timestamp_tz'] = data[time_col_name].apply(lambda x: x.tz_localize(timezone))
        print('applied timezone', timezone)
        print(data.head())
        return data

    def create_moving_pandas(self, data, projection, track_id_col_name):
        move = mpd.TrajectoryCollection(
            data,
            traj_id_col=track_id_col_name,
            crs=projection,
            t='timestamp_tz',  # use our converted timezone column
            x='coords_x',
            y='coords_y'
        )
        print(move)
        return move

    def write_result(self, file_name, data):
        print(type(data))
        pd.to_pickle(data, file_name)

    def convert(self, input_data_file_name, input_meta_file_name, output_file_name):
        meta = self.read_meta_csv(input_meta_file_name)
        data = self.read_data_csv(input_data_file_name, time_col_name=meta.time_col_name)
        self.adjust_timestamps(data=data, timezone=meta.timezone, time_col_name=meta.time_col_name)
        movingpandas = self.create_moving_pandas(data=data, projection=meta.projection, track_id_col_name=meta.track_id_col_name)
        self.write_result(file_name=output_file_name, data=movingpandas)


# just for dev
if __name__ == '__main__':
    TransformToPickle().convert(
        input_data_file_name='./sample/input4/link.csv',
        input_meta_file_name='./sample/input4/meta.csv',
        output_file_name='./sample/csv-to-pickle/out.pickle'
    )
