library(move)
data <- readRDS("/tmp/source_file") # .rds

data.csv <- as.data.frame(data)
names(data.csv) <- make.names(names(data.csv),allow_=FALSE)
# use for geopandas: trackId, timestamps, location.lat and location.long (plus all the attributes as a table)
write.csv(data.csv,"/tmp/artifacs/buffer.csv",row.names=FALSE) 

projection <- raster::projection(data) # for move2 this will be st_crs()
cat(projection,file="/tmp/artifacs/projection.txt")
