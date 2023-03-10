# Link R and Python (R to Python, Python to R)
MoveApps

Github repository: *github.com/movestore/link-r-python*

## Description
This repository contains the code for both Apps that link R and Python (R to Python and Python to R). These Apps are special as they run two programming languages, thus allowing to link R Apps and Python Apps. They work with moveStack on the R side and MovingPandas TrajectoryCollection on the Python side.

## Documentation
Both Apps create out of the input data two .csv files `link.csv`and `meta.csv`. The former contains the data frame of the complete set of locations with all attributes, the latter transfers information about timezone and data projection between the two languages. The two csv files will then be used in the receiving language to create the proper data object.

R to Python: This App reads as input moveStack in R, there transfers the data to csv files (see above), reads the information from those files into Python and creates a MovingPandas TrajectoryCollection as output. This output can then be used as input in Python Apps (of that IO type).

Python to R: This App reads as input a MovingPandas TrajectoryCollection in Python, there transfers the data to csv files (see above), reads the information from those files into R and creates a moveStack as output. This output can then be used as input in R Apps (of that IO type).

## Null or error handling:
Empty MovingPandas TrajectoryCollections will be transferred to a NULL object. An appropriate error will be shown in any following R App.
Null objects from the R world will cause an error in the R to Python App.
