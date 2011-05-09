; add model procedures here

;
; Adopt for the n-queens problem
; by
; Jose M Vidal
;
breed [ queens ]


globals [no-more-messages tmp]

;rows, and cols go from [0..num-queens-1]
;
;message-queue contains the incoming messages. We take new ones out from the head
;col is the column. This is the variable it is trying to find a value in [0..num-queens-1]
;c is c(d), it is a list [c(0) c(1) c(2)...]
;current-view is a list indexed by queen number [col0 col1 col2...] col = -1 if unknown.
;context a list of current-views where the position is the d value.
;threshold
queens-own [message-queue col c current-view context threshold messages-received]

to setup-patches
  ask patches with [(abs (pxcor + pycor)) mod 2 = 0 and
                    pxcor < num-queens + min-pxcor and
                    pycor > max-pycor - num-queens] [
    set pcolor 8] 
end

; n is length of list
; el is the element
to-report get-list [n el]
  let i 0
  let lst 0
  
  set i 0
  set lst []
  while [i < n] [
    set lst fput el lst
    set i i + 1]
  report lst
end

to setup-queens
  create-queens num-queens [
    set col 0 ;initial value is 0 for all.
    setxy (col + min-pxcor) (max-pycor - who)
;    set color red
    set heading 0
    set messages-received 0
    set c get-list num-queens 0
    set current-view get-list num-queens -1
    set context get-list num-queens (get-list num-queens -1)
    set message-queue []
    create-temporary-plot-pen (word "q" who)
    set-current-plot-pen (word "q" who)
    set-plot-pen-color color]
end

to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
  setup-patches
  setup-queens
  ask queens [initialize]
end

to update
  set no-more-messages true
  ask queens [
    if (not empty? message-queue)[
      set no-more-messages false]]
  if (no-more-messages) [stop]
  ask queens [handle-message]
  ask queens [
    create-temporary-plot-pen (word "q" who)
    plot messages-received]
  if (show-trace)[
    print "=============="
    ask queens [
      show (word "view=" current-view)
      show (word "c="  c)]]
end

;;;;
;;queens functions
;;

to receive-message [msg]
  without-interruption [
    set message-queue lput msg message-queue]
end

to-report retrieve-message
  let msg 0
  
  without-interruption [
    set msg first message-queue
    set message-queue butfirst message-queue]
  report msg
end

to initialize
  ask queens with [who > [who] of myself]
    [set message-queue lput (list "value" (list (list ([who] of myself) ([col] of myself)) 0)) message-queue]
end

; assignment is a list [queen value]
; return a new view which results from adding assignement to current-view
; does not change current-view
to-report add-to-current-view [assignment]
  report replace-item (first assignment) current-view (item 1 assignment)
end

;returns true if view-new is compatible with view orig.
;That is, if view-orig is a subset of view-new
to-report compatible-views [view-orig view-new]
  while [not empty? view-orig][
    if ((first view-orig != -1) and (first view-new != -1) and (first view-orig != first view-new))[
      report false]
    set view-orig butfirst view-orig
    set view-new butfirst view-new]
  report true
end

;Get the msg and dispatch it to the appropiate function
to handle-message
  let msg 0
  
  if (empty? message-queue) [stop]
  set msg retrieve-message
;  show msg
  set messages-received messages-received + 1
  if (first msg = "value")[
    handle-value-message item 1 msg]
  if (first msg = "view")[
    handle-view-message item 1 msg]
end

to handle-value-message [content]
  let newview 0
  let d 0
  let assignment 0
  let limit 0
  
  set assignment first content
  set limit item 1 content
  set newview add-to-current-view assignment
  set d 0
  while [d < num-queens][
    if (not compatible-views (item d context) newview)[
      set c replace-item d c 0
      set context replace-item d context (get-list num-queens -1)]
    set d d + 1]
  set current-view newview
  if (first content = (who - 1))[
    set threshold limit]
  hill-climb
end

to handle-view-message [content]
  let vw 0
  let cost 0
  let d 0
  let old-cd 0
  
  set vw first content
  set cost item 1 content
  set d item who vw
  set old-cd item col c
  ifelse (d != -1)[
    set vw replace-item who vw -1
    if (compatible-views current-view vw and cost > item d c)[
      set c replace-item d c cost
      set context replace-item d context vw]]
  [ ;cv does not contain a value for me (who). Child is not my neighbor
    set d 0
    while [d < num-queens][
      if (compatible-views current-view vw and cost > item d c) [
        set c replace-item d c cost
        set context replace-item d context vw]
      set d d + 1
    ]]
  if (old-cd != item col c)[
    hill-climb]
end

to hill-climb
  let estimate 0
  let best-estimate 0
  let d 0
  let pos 0
  let newview 0
  let local-cost 0
  let child-limit 0
  let msg 0
  
  set estimate get-list num-queens 0
  set pos 0
  while [pos < num-queens][
    set newview add-to-current-view list who pos
    set local-cost (get-local-cost newview) + item pos c
    set estimate replace-item pos estimate local-cost
    set pos pos + 1]
  set best-estimate min estimate
  ifelse (best-estimate = item col estimate)[;only change it if the best one is not the current one
    set d col]
  [
    set d position best-estimate estimate]
  if (item col estimate > threshold) [ 
    set col d]
  setxy (col + min-pxcor) (max-pycor - who)
  set child-limit max list (item who c) (threshold - get-local-cost add-to-current-view list who col)
  ;send value messages
  set msg list "value" (list (list who col) child-limit)
  ask queens with [who > [who] of myself][
    receive-message msg]
  ;send view messages
  ;Since all the queens are neighbors it seems that we will always send the current-view, but
  ; the algorithm is unclear
  set msg list "view" (list current-view best-estimate)
  ask queens with [who = ([who] of myself - 1)][
    receive-message msg]
end

;reports the local cost to this queen assuming it is on the world given by vw
;It is the total number of other queens in vw who can attack this queen
;Requires that (item who vw != -1)
to-report get-local-cost [vw]
  let cost 0
  let queen 0
  let mycol 0
  
  set cost 0
  set queen 0
  set mycol item who vw
  if (mycol = -1) [
    show "ERROR: view does not have my position."]
  while [queen < num-queens][
    if ((item queen vw != -1 and queen != who) and ; queen's pos is known and its not me
        ((abs (who - queen) = abs (mycol - item queen vw)) or ;diagonal match
          mycol = item queen vw))[ ;vertical match
      set cost cost + 1]
    set queen queen + 1]
  report cost
end
@#$#@#$#@
GRAPHICS-WINDOW
246
29
586
390
5
5
30.0
1
10
1
1
1
0
1
1
1
-5
5
-5
5
0
0
1
ticks
30.0

BUTTON
2
42
83
75
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

SLIDER
2
75
174
108
num-queens
num-queens
0
11
11
1
1
NIL
HORIZONTAL

BUTTON
84
42
165
75
NIL
update
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
164
42
245
75
NIL
update
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
2
109
134
142
show-trace
show-trace
1
1
-1000

PLOT
2
143
245
332
Messages
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
175
74
232
119
Msgs
sum ([messages-received] of queens)
0
1
11

@#$#@#$#@
# NQueens Adopt  

## WHAT IS IT?  
This program solves the n-queens problem using the Adopt algorith.  
The Adopt algorithm appears in  

 * Pragnesh Jay Modi, Wei-Min Shen, Milind Tambe, and Makoto Yokoo. [An Asynchronous Complete Method for General Distributed Constraint Optimization](http://jmvidal.cse.sc.edu/library/index.html#modi02a). In _Proceedings of Autonomous Agents and Multi-Agent Systems Workshop on Distributed Constraint Reasoning_, p. 104--118, 2002.

## CREDITS

Jose M Vidal

## CHANGES

20100623
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bee
true
0
Polygon -1184463 true false 151 152 137 77 105 67 89 67 66 74 48 85 36 100 24 116 14 134 0 151 15 167 22 182 40 206 58 220 82 226 105 226 134 222
Polygon -16777216 true false 151 150 149 128 149 114 155 98 178 80 197 80 217 81 233 95 242 117 246 141 247 151 245 177 234 195 218 207 206 211 184 211 161 204 151 189 148 171
Polygon -7500403 true true 246 151 241 119 240 96 250 81 261 78 275 87 282 103 277 115 287 121 299 150 286 180 277 189 283 197 281 210 270 222 256 222 243 212 242 192
Polygon -16777216 true false 115 70 129 74 128 223 114 224
Polygon -16777216 true false 89 67 74 71 74 224 89 225 89 67
Polygon -16777216 true false 43 91 31 106 31 195 45 211
Line -1 false 200 144 213 70
Line -1 false 213 70 213 45
Line -1 false 214 45 203 26
Line -1 false 204 26 185 22
Line -1 false 185 22 170 25
Line -1 false 169 26 159 37
Line -1 false 159 37 156 55
Line -1 false 157 55 199 143
Line -1 false 200 141 162 227
Line -1 false 162 227 163 241
Line -1 false 163 241 171 249
Line -1 false 171 249 190 254
Line -1 false 192 253 203 248
Line -1 false 205 249 218 235
Line -1 false 218 235 200 144

bird1
false
0
Polygon -7500403 true true 2 6 2 39 270 298 297 298 299 271 187 160 279 75 276 22 100 67 31 0

bird2
false
0
Polygon -7500403 true true 2 4 33 4 298 270 298 298 272 298 155 184 117 289 61 295 61 105 0 43

boat1
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 33 230 157 182 150 169 151 157 156
Polygon -7500403 true true 149 55 88 143 103 139 111 136 117 139 126 145 130 147 139 147 146 146 149 55

boat2
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 157 54 175 79 174 96 185 102 178 112 194 124 196 131 190 139 192 146 211 151 216 154 157 154
Polygon -7500403 true true 150 74 146 91 139 99 143 114 141 123 137 126 131 129 132 139 142 136 126 142 119 147 148 147

boat3
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 37 172 45 188 59 202 79 217 109 220 130 218 147 204 156 158 156 161 142 170 123 170 102 169 88 165 62
Polygon -7500403 true true 149 66 142 78 139 96 141 111 146 139 148 147 110 147 113 131 118 106 126 71

box
true
0
Polygon -7500403 true true 45 255 255 255 255 45 45 45

butterfly1
true
0
Polygon -16777216 true false 151 76 138 91 138 284 150 296 162 286 162 91
Polygon -7500403 true true 164 106 184 79 205 61 236 48 259 53 279 86 287 119 289 158 278 177 256 182 164 181
Polygon -7500403 true true 136 110 119 82 110 71 85 61 59 48 36 56 17 88 6 115 2 147 15 178 134 178
Polygon -7500403 true true 46 181 28 227 50 255 77 273 112 283 135 274 135 180
Polygon -7500403 true true 165 185 254 184 272 224 255 251 236 267 191 283 164 276
Line -7500403 true 167 47 159 82
Line -7500403 true 136 47 145 81
Circle -7500403 true true 165 45 8
Circle -7500403 true true 134 45 6
Circle -7500403 true true 133 44 7
Circle -7500403 true true 133 43 8

circle
false
0
Circle -7500403 true true 35 35 230

person
false
0
Circle -7500403 true true 155 20 63
Rectangle -7500403 true true 158 79 217 164
Polygon -7500403 true true 158 81 110 129 131 143 158 109 165 110
Polygon -7500403 true true 216 83 267 123 248 143 215 107
Polygon -7500403 true true 167 163 145 234 183 234 183 163
Polygon -7500403 true true 195 163 195 233 227 233 206 159

sheep
false
15
Rectangle -1 true true 90 75 270 225
Circle -1 true true 15 75 150
Rectangle -16777216 true false 81 225 134 286
Rectangle -16777216 true false 180 225 238 285
Circle -16777216 true false 1 88 92

spacecraft
true
0
Polygon -7500403 true true 150 0 180 135 255 255 225 240 150 180 75 240 45 255 120 135

thin-arrow
true
0
Polygon -7500403 true true 150 0 0 150 120 150 120 293 180 293 180 150 300 150

truck-down
false
0
Polygon -7500403 true true 225 30 225 270 120 270 105 210 60 180 45 30 105 60 105 30
Polygon -8630108 true false 195 75 195 120 240 120 240 75
Polygon -8630108 true false 195 225 195 180 240 180 240 225

truck-left
false
0
Polygon -7500403 true true 120 135 225 135 225 210 75 210 75 165 105 165
Polygon -8630108 true false 90 210 105 225 120 210
Polygon -8630108 true false 180 210 195 225 210 210

truck-right
false
0
Polygon -7500403 true true 180 135 75 135 75 210 225 210 225 165 195 165
Polygon -8630108 true false 210 210 195 225 180 210
Polygon -8630108 true false 120 210 105 225 90 210

turtle
true
0
Polygon -7500403 true true 138 75 162 75 165 105 225 105 225 142 195 135 195 187 225 195 225 225 195 217 195 202 105 202 105 217 75 225 75 195 105 187 105 135 75 142 75 105 135 105

wolf
false
0
Rectangle -7500403 true true 15 105 105 165
Rectangle -7500403 true true 45 90 105 105
Polygon -7500403 true true 60 90 83 44 104 90
Polygon -16777216 true false 67 90 82 59 97 89
Rectangle -1 true false 48 93 59 105
Rectangle -16777216 true false 51 96 55 101
Rectangle -16777216 true false 0 121 15 135
Rectangle -16777216 true false 15 136 60 151
Polygon -1 true false 15 136 23 149 31 136
Polygon -1 true false 30 151 37 136 43 151
Rectangle -7500403 true true 105 120 263 195
Rectangle -7500403 true true 108 195 259 201
Rectangle -7500403 true true 114 201 252 210
Rectangle -7500403 true true 120 210 243 214
Rectangle -7500403 true true 115 114 255 120
Rectangle -7500403 true true 128 108 248 114
Rectangle -7500403 true true 150 105 225 108
Rectangle -7500403 true true 132 214 155 270
Rectangle -7500403 true true 110 260 132 270
Rectangle -7500403 true true 210 214 232 270
Rectangle -7500403 true true 189 260 210 270
Line -7500403 true 263 127 281 155
Line -7500403 true 281 155 281 192

wolf-left
false
3
Polygon -6459832 true true 117 97 91 74 66 74 60 85 36 85 38 92 44 97 62 97 81 117 84 134 92 147 109 152 136 144 174 144 174 103 143 103 134 97
Polygon -6459832 true true 87 80 79 55 76 79
Polygon -6459832 true true 81 75 70 58 73 82
Polygon -6459832 true true 99 131 76 152 76 163 96 182 104 182 109 173 102 167 99 173 87 159 104 140
Polygon -6459832 true true 107 138 107 186 98 190 99 196 112 196 115 190
Polygon -6459832 true true 116 140 114 189 105 137
Rectangle -6459832 true true 109 150 114 192
Rectangle -6459832 true true 111 143 116 191
Polygon -6459832 true true 168 106 184 98 205 98 218 115 218 137 186 164 196 176 195 194 178 195 178 183 188 183 169 164 173 144
Polygon -6459832 true true 207 140 200 163 206 175 207 192 193 189 192 177 198 176 185 150
Polygon -6459832 true true 214 134 203 168 192 148
Polygon -6459832 true true 204 151 203 176 193 148
Polygon -6459832 true true 207 103 221 98 236 101 243 115 243 128 256 142 239 143 233 133 225 115 214 114

wolf-right
false
3
Polygon -6459832 true true 170 127 200 93 231 93 237 103 262 103 261 113 253 119 231 119 215 143 213 160 208 173 189 187 169 190 154 190 126 180 106 171 72 171 73 126 122 126 144 123 159 123
Polygon -6459832 true true 201 99 214 69 215 99
Polygon -6459832 true true 207 98 223 71 220 101
Polygon -6459832 true true 184 172 189 234 203 238 203 246 187 247 180 239 171 180
Polygon -6459832 true true 197 174 204 220 218 224 219 234 201 232 195 225 179 179
Polygon -6459832 true true 78 167 95 187 95 208 79 220 92 234 98 235 100 249 81 246 76 241 61 212 65 195 52 170 45 150 44 128 55 121 69 121 81 135
Polygon -6459832 true true 48 143 58 141
Polygon -6459832 true true 46 136 68 137
Polygon -6459832 true true 45 129 35 142 37 159 53 192 47 210 62 238 80 237
Line -16777216 false 74 237 59 213
Line -16777216 false 59 213 59 212
Line -16777216 false 58 211 67 192
Polygon -6459832 true true 38 138 66 149
Polygon -6459832 true true 46 128 33 120 21 118 11 123 3 138 5 160 13 178 9 192 0 199 20 196 25 179 24 161 25 148 45 140
Polygon -6459832 true true 67 122 96 126 63 144

@#$#@#$#@
NetLogo 5.0beta2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
