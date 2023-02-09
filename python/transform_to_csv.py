import pandas as pd
import geopandas as gpd
import movingpandas as mpd


class TransformToCsv:

    def read_data_pickle(self, file_path) -> mpd.TrajectoryCollection:
        deserialized = pd.read_pickle(file_path)
        return deserialized

    def create_geopandas(self, data) -> gpd.GeoDataFrame:
        geopandas = data.to_point_gdf()
        print(geopandas.info())
        return geopandas

    def write_result(self, file_name, data: gpd.GeoDataFrame):
        print(type(data))
        data.to_csv(file_name)

    def convert(self, input_data_file_name, output_file_name):
        data = self.read_data_pickle(file_path=input_data_file_name)
        geopandas = self.create_geopandas(data=data)
        self.write_result(file_name=output_file_name, data=geopandas)


# just for dev
if __name__ == '__main__':
    TransformToCsv().convert(
        input_data_file_name='./sample/out.pickle',
        output_file_name='./sample/out.csv'
    )
