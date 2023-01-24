import movingpandas as mpd
import geopandas as gpd
import pandas as pd

csv = pd.read_csv('/tmp/artifacts/buffer.csv')
with open('/tmp/artifacts/projection.txt') as f:
    projection = f.readline().strip('\n')

move = mpd.TrajectoryCollection(csv, traj_id_col='individual.id', crs=projection, t='timestamp', x='location.long', y='location.lat')

pd.to_pickle(move, '/tmp/output_file')
