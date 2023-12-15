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

    def write_meta_csv(self, data: gpd.GeoDataFrame, file_path):
        projection: CRS = self.get_projection(data=data)
        tzone = self.get_timezone(data=data)
        meta = {
            "crs": [projection.srs],
            "tzone": [tzone]#,
            ## to be done: add names of column containing timestamps and track id
            # "timeColName": [timeColName],
            # "trackIdColName": [trackIdColName]
        }
        df = pd.DataFrame(meta)
        df.to_csv(file_path, index=False)

    def write_result(self, file_name, data: gpd.GeoDataFrame):
        print(type(data))
        data.to_csv(file_name, index=False)

    def convert(self, input_data_file_name, output_file_name, output_meta_file_name):
        data = self.read_data_pickle(file_path=input_data_file_name)
        geopandas = self.create_geopandas(data=data)
        self.write_result(file_name=output_file_name, data=geopandas)
        self.write_meta_csv(data=geopandas, file_path=output_meta_file_name)


# just for dev
if __name__ == '__main__':
    TransformToCsv().convert(
        input_data_file_name='./sample/csv-to-pickle/out.pickle',
        output_file_name='./sample/pickle-to-csv/link.csv',
        output_meta_file_name='./sample/pickle-to-csv/meta.csv'
    )
