# Modeling Prejudice
Our project aims to use [NetLogo](http://ccl.northwestern.edu/netlogo/) to create an agent based model(ABM) of racially restrictive covenants in the early 20th century in Minneapolis. 
The model will replicate and predict the pattern and spread of covenants, as shown by the research of the Mapping Prejudice project(MP). 
And the ABM strives to reaffirm and strengthen MP’s claim that covenants had a powerful segregative power on the urban landscape by replicating their emergence in a reproducible and extendable model. 
We believe that through this model we can validate the robustness of MP’s research.

## Included parameters
Agent based modeling can produce sophisticated outputs of emergent behavior with simple inputs and few parameters. 
Our model would include measures of:
- Demography
- Rate of natural increase and immigration
- Propagation rate 
- Distance to amenities

## Get started

### Installation
Download and install the [NetLogo](http://ccl.northwestern.edu/netlogo/) to run the model. 

### Clone
- Clone this repo to your local machine using `https://github.com/Ziiiiing/netlogo-GIS8501.git`
- Run the `ModelingPrejuce.nlogo` in NetLogo

### Run 
- Move the `cov_rate` slider to change the rate of covenants.
  - **💁‍♀️(picture/gif of slider will go here)**

- Click `setup` button to create both majority and minority turtles based on the actual ratio in 1910. 
The inital location of turtles will be gathered around the central land of canvas and they will not pass or set home on water as well. 
The ability of breeding increases the amount of turtles as tick goes up, and the birth rate also based on the actual pattern in the urban area.
  - **💁‍♀️(picture of setup button/gif of setup will go here)**

- Click `go` button to see the dynamic changes of turtle movement and patch development. 
The tick window showed on the model will represent the year.
  - **💁‍♀️(gif of dynamic changes and picture of tick window will go here)**

- Once the model stops, the output will be exported as a raster file in your local machine called `ABM_Output.asc`. 

- Add this raster file in ArcGIS Pro or ArcGIS Desktop ,and compare it with the actual raster result `rrc_density.asc`.
  - **💁‍♀️(picture of output raster in Pro will go here)**






## Authors
- Marguerite Mills
- Travis Ormsby
- Ziying Cheng
