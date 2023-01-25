import movingpandas as mpd
import geopandas as gpd
import pandas as pd
from dataclasses import dataclass


@dataclass
class Meta:
    projection: str
    timezone: str


def read_meta_csv(file_path):
    meta_csv = pd.read_csv(file_path)  # pd.read_csv('/tmp/artifacts/meta.csv')
    projection = meta_csv['crs'][0]
    tzone = meta_csv['tzone'][0]
    meta = Meta(projection=projection, timezone=tzone)
    print(meta)
    return meta


def read_data_csv(file_path):
    csv = pd.read_csv(
        file_path,
        parse_dates=['timestamp'],
    )
    print(csv.info())
    return csv


def adjust_timestamps(data, timezone):
    data['timestamp_tz'] = data['timestamp'].apply(lambda x: x.tz_localize('UTC').tz_convert(timezone))
    print('applied timezone', timezone)
    print(data.head())
    return data


def create_moving_pandas(data, projection):
    move = mpd.TrajectoryCollection(
        data,
        traj_id_col='individual.id',
        crs=projection,
        t='timestamp_tz', # use our converted timezone column
        x='location.long',
        y='location.lat'
    )
    print(move)
    return move


def write_result(file_name, data):
    pd.to_pickle(data, file_name)  # pd.to_pickle(move, '/tmp/output_file')


# pd.read_csv('/tmp/artifacts/buffer.csv')

def convert(input_data_file_name, input_meta_file_name, output_file_name):
    meta = read_meta_csv(input_meta_file_name)
    data = read_data_csv(input_data_file_name)
    adjust_timestamps(data=data, timezone=meta.timezone)
    create_moving_pandas(data=data, projection=meta.projection)
    write_result(file_name=output_file_name, data=data)


convert(
    input_data_file_name='./sample/buffer.csv',
    input_meta_file_name='./sample/meta.csv',
    output_file_name='./sample/out.pickle'
)
