extensions [gis]

breed [Bs B]
breed [Ws W]



globals [
  ; random value generated for each patch, checks against the covenant propogation rate to see if a developed patch has a covenant or not.
  cov_score

  ; raster dataset of how far to amenities - only modeling non-Mississippi water bodies here
  DistToWater

  ; raster dataset with developed parcels in 1910
  devstart

  export_raster ; output raster of patch color value
  loop-count ; how many times the model has run

  ; parcels at the start that are already developed
  available-parcels

  ; start and end values for each subgroup population
  w-pop-start
  b-pop-start

  ; annual growth rates for each subgroup
  w-pop-rate
  b-pop-rate

  ; file name for the output raster
  file-name
]

patches-own [waterDistance
             deved-at-start
             covMultiplier
             restrictive-covenant] ; raster values applied to patches


; define two variables belonging to each turtle
turtles-own [
  home?                ; for each turtle, indicates whether turtles find a proper place to settle down
  other-nearby-2       ; how many two-patch away turtles with different color
  move-speed           ; how far a turtle moves
]




to setup
  clear-all
  ;reset-ticks
  set loop-count 1
  ask patches [set restrictive-covenant 0]
    ; count the number of patches that are developed at the start

  loop-setup
end

to loop-setup
  clear-turtles
  ;clear-patches
  patch-setup
  turtle-setup
  reset-ticks
  clear-plot
end

to loop-model
  move-homeless-turtles
  update-turtles

  if count turtles with [home? = FALSE] = 0 or ticks = 50 [
    ask patches with [pcolor = red]
      [set restrictive-covenant restrictive-covenant + 1]

    if loop-count = num-loops [
      set file-name "ABM_Output_Mean"
      output-raster
      stop
      ]

    if loop-count = 1 [
      set file-name "ABM_Output_Single_Sample"
      output-raster
    ]

    loop-setup
    set loop-count loop-count + 1]

  ask Ws [ reproduce-Ws ]
  ask Bs [ reproduce-Bs ]
  tick
end

; use the raster data from Minneapolis to initialize patch values
to patch-setup
  set DistToWater gis:load-dataset "DistToWater/disttowater.asc"
  gis:apply-raster DistToWater waterDistance

  set devstart gis:load-dataset "parcels_1910/parcels_1910.asc"
  gis:apply-raster devstart deved-at-start

  gis:set-world-envelope (gis:envelope-union-of ;(gis:envelope-of: DistToWater)
                                                (gis:envelope-of: devstart)
  )




  ; b/c the raster represents distance to water in 250m cell increments,
  ; any cell that has a value less than 250 must be water itself

  ask patches [set pcolor green]
  ask patches with [deved-at-start = 1] [set pcolor blue]
  ask patches with [waterDistance < 250] [set pcolor black]

  set available-parcels count patches with [pcolor = blue] * 0.75
  ;set available-parcels 100
  set b-pop-start available-parcels * percent-minority-start / 100
  set w-pop-start available-parcels - b-pop-start

  ask patches [
    if waterDistance <= 250 [set covMultiplier 1 / amenity-import]
    if 250 < waterDistance and waterDistance <= 500 [set covMultiplier 1 / amenity-import ^ (1 / 2)]
    if 500 < waterDistance and waterDistance <= 750 [set covMultiplier 1 / amenity-import ^ (1 / 3)]
    if 750 < waterDistance and waterDistance <= 1000 [set covMultiplier 1 / amenity-import ^ (1 / 4)]
    if 1000 < waterDistance [set covMultiplier 1]
  ]

end


; create turtles
; they are not allowed to overlap
; they are not allowed to be set in water

to turtle-setup

  ask n-of w-pop-start patches with [pcolor = blue and not any? other turtles-here] [sprout-Ws 1 [set color white set home? FALSE set move-speed w-move-speed]]
  ask n-of b-pop-start patches with [pcolor = blue and not any? other turtles-here] [sprout-Bs 1 [set color black set home? FALSE set move-speed b-move-speed]]
end


; run the model
; all initial turtles are homeless
to go
  update-turtles
  move-homeless-turtles
  if ticks = 50 [
    set file-name "ABM_Output_Single_Sample"
    output-raster
    stop]
  ask Ws [ reproduce-Ws ]
  ask Bs [ reproduce-Bs ]
  tick
end

to reproduce-Ws  ; white agent procedure
  if random 10000 < w-growth-rate * 100 [  ; throw "dice" to see if you will reproduce
    hatch 1 [ set home? False set move-speed w-move-speed rt random-float 360 fd move-speed ]   ; hatch an offspring and move it forward 1 step
  ]
end

to reproduce-Bs  ; black agent procedure
  if random 10000 < b-growth-rate * 100 [  ; throw "dice" to see if you will reproduce
    hatch 1 [ set home? False set move-speed b-move-speed rt random-float 360 fd move-speed ]  ; hatch an offspring and move it forward 1 step
  ]
end

to output-raster

  ask patches  [
    set restrictive-covenant restrictive-covenant / loop-count
    set export_raster gis:patch-dataset restrictive-covenant
  ]
  gis:store-dataset export_raster file-name
end



; homeless turtles try a new spot
to move-homeless-turtles
  ask turtles with [home? = FALSE]
  [find-new-spot]
  develop-parcel
end

; move until the homeless turtles find an unoccupied patch
to find-new-spot
  rt random-float 360
  fd move-speed
  if any? other turtles-here [find-new-spot]        ; check whether the new places they found are unoccupied
  if pcolor = black [find-new-spot]
  move-to patch-here                            ; move to center of unoccupied patch
end

to update-turtles
  ask Ws [
    set other-nearby-2 count (turtles in-radius (2 ^ (1 / 2))) with [color != [color] of myself]
    if other-nearby-2 = 0 and not any? other turtles-here [
      if pcolor != black [
      set home? TRUE]
  ]]

  ask Ws with [home? = TRUE] [
    if other-nearby-2 > 0 [set home? FALSE]  ; racist white turtles will move if a black turtle moves into the neighborhood
  ]

   ask Bs [
    if not any? other turtles-here [
      if pcolor != black  and pcolor != red [ ; besides, black turtles cannot set home on red patches
      set home? TRUE]
  ]]
end



; turn an undeveloped parcel into a developed one
; develops a 3x3 set of patch cells around a wandering turtle
; this represents the historical process of creating parcels together as a development
to develop-parcel
  ; change from undeveloped to developed
  ask turtles with [pcolor = green] [ask patches in-radius (dev-size * 2 ^ ( 1 / 2)) [
    if pcolor = green [
      set pcolor grey
    ]
  ]]

  create-covenant

end

; when a parcel is developed as a result of a majority turtle moving to the area
; determine if it will have a restricted covenant.  All parcels developed at the same
; time will have the same designation - either covenented or not.
; grey patches represent developed parcels whose covenant status has not been assigned
; red patches have restrictive covenants
; blue patches have no restrictions
to create-covenant

  ask Ws [
    set cov_score random 100 * covMultiplier
    ask patches in-radius (dev-size * 2 ^ ( 1 / 2)) [  ; multiply the dev-size by sqrt 2 in order to get queen's case radius
      if pcolor = grey [
      ifelse cov_rate > cov_score
        [set pcolor red]
        [set pcolor blue]
      ]
    ]

;    if pcolor = grey [
;      ifelse cov_rate > cov_score
;        [set pcolor red]
;        [set pcolor blue]
;    ]
;    ask neighbors [if pcolor = grey [
;      ifelse cov_rate > cov_score
;        [set pcolor red]
;        [set pcolor blue]
;      ]
;    ]
  ]

  ask Bs [ask patches in-radius (dev-size * 2 ^ ( 1 / 2)) [if pcolor = grey [set pcolor blue]]
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
205
21
541
590
-1
-1
8.0
1
10
1
1
1
0
1
1
1
0
40
0
69
1
1
1
ticks
30.0

BUTTON
15
20
100
55
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
105
20
190
55
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
130
190
163
cov_rate
cov_rate
0
100
5.0
1
1
NIL
HORIZONTAL

BUTTON
15
60
100
125
NIL
loop-model
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
554
23
637
68
NIL
loop-count
17
1
11

INPUTBOX
105
60
190
125
num-loops
20.0
1
0
Number

SLIDER
15
330
190
363
percent-minority-start
percent-minority-start
0
100
1.0
1
1
NIL
HORIZONTAL

INPUTBOX
15
370
190
435
start-pop
301408.0
1
0
Number

INPUTBOX
15
440
190
505
end-pop
482872.0
1
0
Number

SLIDER
15
170
190
203
amenity-import
amenity-import
1
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
15
250
190
283
w-move-speed
w-move-speed
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
15
290
190
323
b-move-speed
b-move-speed
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
15
210
190
243
dev-size
dev-size
0
5
2.0
1
1
NIL
HORIZONTAL

INPUTBOX
105
510
190
575
w-growth-rate
1.83
1
0
Number

INPUTBOX
15
510
100
575
b-growth-rate
3.02
1
0
Number

PLOT
554
84
1003
374
Covenant Growth
Time
Covenants
0.0
50.0
0.0
2500.0
false
true
"" ""
PENS
"Non-Restrictive" 1.0 0 -13345367 true "" "plot count patches with [pcolor = blue]"
"Restrictive" 1.0 0 -2674135 true "" "plot count patches with [pcolor = red]"

PLOT
554
388
980
538
Population Growth
Time
Population
0.0
50.0
0.0
2500.0
false
true
"" ""
PENS
"population" 1.0 0 -16777216 true "" "plot count turtles"

@#$#@#$#@
## WHAT IS IT?

**Modeling Prejudice** is a project that aims to use [NetLogo](http://ccl.northwestern.edu/netlogo/) to create an agent based model to replicate and predict the pattern and spread of covenants, as shown by the research of the [Mapping Prejudice project](https://www.mappingprejudice.org).

This project models the behavior of both white and black agents in the early 20th century in Minneapolis. The two agents get along with each other, but each agent wants to make sure that it lives near some of “its own”, which means each white agent wants to live near at least some white agents, and each black agent wants to live near at least some black agents.

The simulation  will include
- Demography
- Population growth
- Probability of restrictive covenant
- Distance to desirable waterside property

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


## Authors
- [Marguerite Mills](https://github.com/millsm278)
- [Travis Ormsby](https://github.com/travisormsby)
- [Ziying Cheng](https://github.com/Ziiiiing)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
