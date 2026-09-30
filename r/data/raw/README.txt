Set of input data to test apps.

Source: github.com/movestore/Template_R_Function_App, data/raw at commit
e00af0d779f9756c40161bffd8d6f0a5ebc77ced (2026-09-28), the move2_loc files only - the
telemetry.list files are no input type of the translators.
input_move2loc_List.rds is this repository's own: the only input with list columns in its
track data.

*Content*
- input1: 1 goat, median fix rate = 30mins, tracking duration 7.5 month, gps, local movement
- input2: 3 storks, median fix rate = 1sec, tracking duration 2 weeks, gps, local movement
- input3: 1 stork, one track per deployment, median fix rate = 1h | 1day | 1 week, tracking duration 11.5 years, argos, includes migration
- input4: 3 geese, median fix rate = 1h | 4h, tracking duration 1.5 years, gps, includes migration
- input_move2loc_List: 5 locations in 4 tracks, three of them with a single fix

*Projection*
- data are provided in "lat/long" (EPSG:4326) and projected to "Mollweide" (ESRI:54009) in order to test your app accordingly for not projected and projected data.

*File names*
input1_move2loc_LatLon.rds
input1_move2loc_Mollweide.rds

input2_move2loc_LatLon.rds
input2_move2loc_Mollweide.rds

input3_move2loc_LatLon.rds
input3_move2loc_Mollweide.rds

input4_move2loc_LatLon.rds
input4_move2loc_Mollweide.rds

input_move2loc_List.rds
