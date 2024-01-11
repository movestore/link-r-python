import pandas as pd
import geopandas as gpd
import movingpandas as mpd
from pyproj import CRS


class TransformToCsv:

    def read_data_pickle(self, file_path) -> mpd.TrajectoryCollection:
        deserialized = pd.read_pickle(file_path)
        return deserialized

    def create_geopandas(self, data) -> gpd.GeoDataFrame:
        geopandas = data.to_point_gdf()
        geopandas['coords_x'] = geopandas['geometry'].apply(lambda p: p.x)
        geopandas['coords_y'] = geopandas['geometry'].apply(lambda p: p.y)

        print(geopandas.info())
        return geopandas

    def get_projection(self, data: gpd.GeoDataFrame) -> CRS:
        crs = data.crs
        print(crs)
        return crs

    def get_timezone(self, data: gpd.GeoDataFrame) -> str:
        print(data.index)
        if data.index.tz is None:
            return 'UTC'
        else:
            # this is untested for now
            return data.index.tz

    def get_time_col_name(self, data: gpd.GeoDataFrame) -> str:
        return data.index.name

    def get_track_id_col_name(self, data: mpd.TrajectoryCollection) -> str:
        return data.get_traj_id_col()

    def write_meta_csv(self, geopanda: gpd.GeoDataFrame, movingpanda: mpd.TrajectoryCollection, file_path):
        projection: CRS = self.get_projection(data=geopanda)
        tzone = self.get_timezone(data=geopanda)
        time_col_name = self.get_time_col_name(data=geopanda)
        track_id_col_name = self.get_track_id_col_name(data=movingpanda)
        meta = {
            "crs": [projection.srs],
            "tzone": [tzone],
            "timeColName": [time_col_name],
            "trackIdColName": [track_id_col_name]
        }
        df = pd.DataFrame(meta)
        df.to_csv(file_path, index=False)

    def write_result(self, file_name, data: gpd.GeoDataFrame):
        print(type(data))
        data.to_csv(file_name, index=True)

    def convert(self, input_data_file_name, output_file_name, output_meta_file_name):
        data = self.read_data_pickle(file_path=input_data_file_name)
        geopandas = self.create_geopandas(data=data)
        self.write_result(file_name=output_file_name, data=geopandas)
        self.write_meta_csv(geopanda=geopandas, movingpanda=data, file_path=output_meta_file_name)


# just for dev
if __name__ == '__main__':
    TransformToCsv().convert(
        input_data_file_name='./sample/csv-to-pickle/out.pickle',
        output_file_name='sample/pickle-to-csv/link.csv',
        output_meta_file_name='./sample/pickle-to-csv/meta.csv'
    )
