# Modeling Prejudice
(pic)

## WHAT IS IT?

**Modeling Prejudice** is a project that aims to use [NetLogo](http://ccl.northwestern.edu/netlogo/) to create an agent based model **(ABM)** to replicate and predict the pattern and spread of covenants, as shown by the research of the **Mapping Prejudice project(MP)**.

This project models the behavior of both white and black agents in the early 20th century in Minneapolis. The two agents get along with each other, but each agent wants to make sure that it lives near some of “its own”, which means each white agent wants to live near at least some white agents, and each black agent wants to live near at least some black agents.

**The simulation  will include**
- Demography
- Rate of natural increase and immigration
- Propagation rate
- Distance to amenities

## HOW TO USE IT

Click the `SETUP` button to set up the agents. The initial ratio of white agents and black agents are based on the historic demographic patterns in 1910. The agents are set up randomly on the blue patches in central part of the area, and blue patches have no restrictions. No patch has more than one agent as well.

Click `GO` to start the simulation. Red patches are developed by white agents only and are defined as the patches with restrictive covenants, which means the black agents cannot set home on them. If agents don’t find an available place to set home, they will move 1 step towards a random direction.

The `cov_rate` slider controls the restrictive covenant density of the neighborhood. It takes effect only before every time you click GO.

The `num-loops` input controls the number of loops you want the model to run automatically. Input an integer and click `loop-model` button to start running.

## THINGS TO NOTICE

The green patches refer to the land while the black patches represent the water area. Agents can only move and set home on green patches and need to avoid black patches while wandering. 

The `population` of agents will increase based on an artificial inflated growth rate when the model start running.

One `tick` in the model is defined as a year. The maximum tick is 50, which specifically describes the patterns from 1910 to 1960. 

The model will stop when the tick arrives at 50. And `a raster file` will be created automatically in the local machine, which refers to the average result of the patterns of the red patches in the neighborhood after many times loops. You can add the raster file into the ArcGIS Pro to make it visualize.



## NETLOGO FEATURE
`Loop-model` is used to run the model automatically with the specific times. The output of red patches can be more representative and less insignificant when compared with the raster of MP.

`Patch-setup` is used to specify the land and water, which is based on the geographic information in the neighborhood.

When the homeless agent is wandering, `update-turtles` is designed to check the availability of setting home on the current patch.

Authors



## Authors
- [Marguerite Mills](https://github.com/millsm278)
- [Travis Ormsby](https://github.com/travisormsby)
- [Ziying Cheng](https://github.com/Ziiiiing)
