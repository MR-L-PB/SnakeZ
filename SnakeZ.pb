EnableExplicit

InitSprite()
InitKeyboard()
InitMouse()
InitSound()
UsePNGImageDecoder()
UseOGGSoundDecoder()

#DEBUGMODE = 0

#FieldWidth = 100
#FieldHeight = 50
#CellSize = 100
#AreaWidth = #FieldWidth * #CellSize
#AreaHeight = #FieldHeight * #CellSize

#SpriteQuality = #PB_Sprite_NoFiltering; #PB_Sprite_BilinearFiltering
#SpriteSize = 128
#SpriteSizeH = #SpriteSize * 0.5

#FoodPerCellMax = 10
#FoodScore = 1
#SuperFoodScore = 10

#MaxSnakes = 255
#MaxRadius = 100
#MaxStyles = 255
#MaxColors = 32

#StartRadius = 15
#StartLength = 5
#FoodRadius = 15

#UpdateTime = 150
#RaceTime = #UpdateTime / 3
#Speed = 25
#RotationSpeed = 0.85
#RespawnTime = 3000
#ExplosionTime = 1000
#ExplosionDistance = 2000

#PI2 = #PI * 2

Enumeration
	#Snake_Respawning
	#Snake_Alive
	#Snake_Crashed
EndEnumeration

Enumeration
	#Sprite_FirstSnake
	#Sprite_LastSnake = #Sprite_FirstSnake + #MaxSnakes
	#Sprite_Food
	#Sprite_FoodLast = #Sprite_Food + #MaxColors - 1
	#Sprite_SuperFood
	#Sprite_SuperFoodLast = #Sprite_SuperFood + #MaxColors - 1
	#Sprite_Egg
	#Sprite_Eye
	#Sprite_EyeClosed
	#Sprite_Explosion
	#Sprite_Floor
EndEnumeration

Enumeration
	#Sound_music
	#Sound_start
	#Sound_respawn
	#Sound_eat1
	#Sound_eat2
	#Sound_eatEgg
	#Sound_explosion1
	#Sound_explosion2
	#Sound_speedUp
	#Sound_grow
EndEnumeration

Structure Body
	index.a
	snakeIndex.a
	isVisible.a
	x.l
	y.l
EndStructure

Structure Food
	index.a
	x.l
	y.l
EndStructure

Structure Snake
	index.a
	*style.SnakeStyle
	
	state.a
	
	nextTime.i
	updateTime.i
	nextUpdateTime.i
	delta.d	
	
	respawnTime.i
	eyeBlinkTime.i
	shrinkTime.i
	reduction.d
	
	radius.d
	direction.d
	angle.d
	scoreCount.i
	score.i
	
	wobbleTime.l
	
	List body.Body()
	List food.Food()
EndStructure

Structure SnakeStyle
	nrColors.a
	Array color.a(#MaxColors)
EndStructure

Structure Cell
	Map *body.Body()
	Map *food.Food()
EndStructure

Structure Spark
	sprite.i
	x.d
	y.d
	xd.d
	yd.d
	angle.d
	time.i
	duration.d
EndStructure

Global ScreenW = 1024, ScreenH = 768

Global FullScreen = #False;True
Global PlaySounds = #True
Global MaxVolume = 5

Global Dim Field.Cell(#FieldWidth * #FieldHeight)
Global Dim Sprite(1000)
Global Dim SnakeStyle.SnakeStyle(#MaxStyles)
Global Dim *SnakeList.Snake(1000)
Global NewList Snake.Snake()
Global NewList Food.Food()
Global NewList Explosion.Spark()
Global NewList Spark.Spark()
Global.d ScrollX, ScrollY, Zoom = 1.0, OldZoom = Zoom, CameraShake
Global FPS, FPSTime, FPSCount, Time, RedrawTime, DeltaTime.d
Global FoodCountStart
Global MousePosX, MousePosY, MouseDx, MouseDy, LeftButton, MouseReleased, DrawCursor = 0
Global LongestSnake
Global GamePaused

Macro RGBA2(r_, g_, b_, a_ = 255)	
	RGBA(Clamp((r_) * #Brightness, 0, 255), Clamp((g_) * #Brightness, 0, 255), Clamp((b_) * #Brightness, 0, 255), a_)
EndMacro

Macro Distance(body1_, body2_)
	Sqr((body1_\x - body2_\x) * (body1_\x - body2_\x) + (body1_\y - body2_\y) * (body1_\y - body2_\y))
EndMacro


Macro Field_Set(map_, type_)
	Define fx_ = type_\x / #CellSize
	Define fy_ = type_\y / #CellSize
	Field(fx_ + fy_ * #FieldWidth)\map_(Str(type_)) = type_
EndMacro

Macro Field_Unset(map_, type_)
	Define fx_ = type_\x / #CellSize
	Define fy_ = type_\y / #CellSize
	DeleteMapElement(Field(fx_ + fy_ * #FieldWidth)\map_(), Str(type_))
EndMacro

Procedure.d Rnd(min.d, max.d)
	ProcedureReturn min + Random(Int((max - min) * 100000)) / 100000.0
EndProcedure

Procedure.d Min(a.d, b.d)
	If a < b
		ProcedureReturn a
	EndIf
	ProcedureReturn b
EndProcedure

Procedure.d Max(a.d, b.d)
	If a > b
		ProcedureReturn a
	EndIf
	ProcedureReturn b
EndProcedure

Procedure.d Clamp(v.d, a.d, b.d)
	If v < a
		ProcedureReturn a
	ElseIf v > b
		ProcedureReturn b
	Else
		ProcedureReturn v
	EndIf
EndProcedure

Procedure.d AngleDifference(angle1.d, angle2.d)
	angle1 = Mod(angle1, #PI2)
	angle2 = Mod(angle2, #PI2)
	ProcedureReturn Mod(((angle1 - angle2) + #PI + #PI2), #PI2) - #PI
EndProcedure

Procedure Sprites_Load(path.s)
	Protected i
	
	For i = 0 To #MaxColors - 1
		Sprite(#Sprite_FirstSnake + i) = LoadSprite(#PB_Any, path + "snake_" + Str(i) + ".png", #PB_Sprite_AlphaBlending)
		Sprite(#Sprite_Food + i) = LoadSprite(#PB_Any, path + "food_" + Str(i) + ".png", #PB_Sprite_AlphaBlending)
		Sprite(#Sprite_SuperFood + i) = LoadSprite(#PB_Any, path + "superfood_" + Str(i) + ".png", #PB_Sprite_AlphaBlending)
	Next	
	
	Sprite(#Sprite_Eye) = LoadSprite(#PB_Any, path + "eye.png", #PB_Sprite_AlphaBlending)
	Sprite(#Sprite_EyeClosed) = LoadSprite(#PB_Any, path + "eyeclosed.png", #PB_Sprite_AlphaBlending)
	
	Sprite(#Sprite_Egg) = LoadSprite(#PB_Any, path + "egg.png", #PB_Sprite_AlphaBlending)
	Sprite(#Sprite_Explosion) = LoadSprite(#PB_Any, path + "explosion.png", #PB_Sprite_AlphaBlending)
	Sprite(#Sprite_Floor) = LoadSprite(#PB_Any, path + "floor.png", #PB_Sprite_AlphaBlending)
EndProcedure

Procedure Sounds_Load(path.s)
	Protected error
	
; 	error + Bool(LoadSound(#Sound_start, path + "sound_music.ogg") = 0)
	error + Bool(LoadSound(#Sound_start, path + "sound_start.ogg") = 0)
	error + Bool(LoadSound(#Sound_respawn, path + "sound_respawn.ogg") = 0)
	error + Bool(LoadSound(#Sound_eat1, path + "sound_eat1.ogg") = 0)
	error + Bool(LoadSound(#Sound_eat2, path + "sound_eat2.ogg") = 0)
	error + Bool(LoadSound(#Sound_eatEgg, path + "sound_eatEgg.ogg") = 0)
	error + Bool(LoadSound(#Sound_explosion1, path + "sound_explosion1.ogg") = 0)
	error + Bool(LoadSound(#Sound_explosion2, path + "sound_explosion2.ogg") = 0)
	error + Bool(LoadSound(#Sound_speedUp, path + "sound_speedUp.ogg") = 0)
	error + Bool(LoadSound(#Sound_grow, path + "sound_grow.ogg") = 0)
	
	If error
		PlaySounds = 0
	Else
		SoundVolume(#Sound_eat1, 7)
		SoundVolume(#Sound_eat2, 10)
	EndIf
EndProcedure

Procedure Sound_Play(sound, volume = 100, flags = 0)
	If PlaySounds And IsSound(sound)
		PlaySound(sound, flags, Min(volume, MaxVolume))
	EndIf
EndProcedure


Procedure Food_Add(x, y, index.a)
	If x < 0 Or x >= #AreaWidth Or y < 0 Or y >= #AreaHeight
		ProcedureReturn #Null
	EndIf
	
	Protected fx = x / #CellSize
	Protected fy = y / #CellSize
	
	If MapSize(Field(fx + #FieldWidth * fy)\food()) < #FoodPerCellMax
		Protected *food.Food = AddElement(Food())
		If *food
			*food\x = x
			*food\y = y
			*food\index = index
			
			Field_Set(food, *food)
		EndIf
	EndIf
	
	ProcedureReturn *food
EndProcedure

Procedure Spark_Add(x, y, sprite.l, count = 0)
	If count = 0
		count = Random(3, 1)
	EndIf
	
	While count > 0
		Protected angle.d = Rnd(0, #PI * 4)
		Protected speed.d = Rnd(0.5, 10)
		If AddElement(Spark())
			Spark()\x = x
			Spark()\y = y
			Spark()\xd = Sin(angle) * speed
			Spark()\yd = Cos(angle) * speed
			Spark()\duration = Random(500, 250)
			Spark()\time = Time + Spark()\duration
			Spark()\sprite = Sprite(sprite)
		EndIf
		count - 1
	Wend	
EndProcedure

Procedure Snake_AddBody(*snake.Snake, x, y, index.a)
	If x < 0 Or x >= #AreaWidth Or y < 0 Or y >= #AreaHeight
		ProcedureReturn #Null
	EndIf

	Protected *body.Body
	
	*body = AddElement(*snake\body())
	If *body
		*body\x = x
		*body\y = y
		*body\snakeIndex = *snake\index
		*body\index = index
 		
		Field_Set(body, *body)
		
 		*snake\wobbleTime = Time + 1000
	EndIf
	
	ProcedureReturn *body
EndProcedure

Procedure Snake_Add(index, length = #StartLength, radius = #StartRadius, respawnTime = #RespawnTime)
	Protected *snake.Snake 
	Protected *body.Body
	Protected i, fx, fy, x, y, x1, y1, empty
	Protected try = 100, n = 1
	
	If ListSize(Snake()) >= #MaxSnakes
		ProcedureReturn #Null
	EndIf
	
	Repeat
		x = Rnd(radius * 10, #AreaWidth - radius * 10)
		y = Rnd(radius * 10, #AreaHeight - radius * 10)
		fx = x / #CellSize * 1.0
		fy = y / #CellSize * 1.0
		
		empty = #True
		For y1 = fy - n To fy + n
			If y1 >= 0 And y1 < #FieldHeight
				For x1 = fx - n To fx + n
					If x1 >= 0 And x1 < #FieldWidth
						If MapSize(Field(x1 + y1 * #FieldWidth)\body())
							empty = #False
							Break 2
						EndIf
					EndIf
				Next
			EndIf
		Next
		
		try - 1
	Until empty Or try < 0
	
	If empty
		*snake = AddElement(Snake())
		If *snake
			With *snake
				\style = @SnakeStyle(Random(#MaxStyles - 1))
				\index = index
				\state = #Snake_Respawning
				\angle = Radian(180)
				\direction = \angle
				\radius = radius
				\updateTime = #UpdateTime + 50
				\nextUpdateTime = #UpdateTime
				\nextTime = 0
				\respawnTime = Time + #RespawnTime
				\reduction = 1
				
				For i = 0 To #StartLength - 1
					Snake_AddBody(*snake, x, y, \style\color(i % \style\nrColors))
				Next
				
				*SnakeList(index) = *snake
			EndWith
			
		EndIf
	EndIf
	
	ProcedureReturn *snake
EndProcedure

Procedure Snake_Crash(*snake.Snake, size.d = 0.85)
	Protected x, y, distance, scale.d
	Protected *player.Snake = *SnakeList(#Sprite_FirstSnake)
	
	If FirstElement(*snake\body())
		x = (ScreenW * 0.5 - ScrollX) - *snake\body()\x
		y = (ScreenH * 0.5 - ScrollY) - *snake\body()\y
		distance = Sqr(x * x + y * y)
		
		If distance < #ExplosionDistance
			If AddElement(Explosion())
				Explosion()\x = *snake\body()\x
				Explosion()\y = *snake\body()\y
				Explosion()\time = (Time - 250) + #ExplosionTime * size
				
				scale = (#ExplosionDistance - distance) / #ExplosionDistance * 1.0
				CameraShake = Time + 2000 * scale
				
				If *snake = *player
					Sound_Play(#Sound_explosion1)
				Else
					Sound_Play(#Sound_explosion2, Max(10, scale * 100))
				EndIf
			EndIf			
		EndIf
	EndIf
	
	*snake\state = #Snake_Crashed
EndProcedure


Procedure Snake_Kill(*snake.Snake)
	ForEach *snake\body()
		Field_Unset(body, *snake\body())
	Next
	
	ClearList(*snake\body())
	ClearList(*snake\food())
	
	*SnakeList(*snake\index) = #Null
	
	If *snake\index <> #Sprite_FirstSnake
		Snake_Add(*snake\index)
	EndIf
	
	ChangeCurrentElement(Snake(), *snake)
	DeleteElement(Snake())
EndProcedure 

Procedure Game_Update(dTime.d)
	Protected.d x, y, angle, radius, dist, dirX, dirY
	Protected fx, fy
	Protected count, i, index, snakeIsVisible
	Protected.Snake *snake, *collisionSnake
	Protected.Body *head, *body, *tail
	Protected.Food *food
	Protected *cell.Cell
	Protected width = ScreenW
	Protected height = ScreenH
	
	If GamePaused
		ProcedureReturn
	EndIf
	
	If FullScreen = #False
		width = DesktopScaledX(width)
		height = DesktopScaledY(height)
	EndIf
	
	FPSCount + 1
	If Time > FPSTime
		FPS = FPSCount
		FPSCount = 0
		FPSTime = Time + 1000
	EndIf
	
	
	If Random(50) = 0
		i = Random(200, 100)		
		While (ListSize(Food()) < FoodCountStart) And (i > 0)
			x = Random(#AreaWidth - 1)
			y = Random(#AreaHeight - 1)
			Food_Add(x, y, Random(#MaxColors - 1))
			i - 1
		Wend
	EndIf
	
	If *SnakeList(#Sprite_FirstSnake) = 0
		Zoom + (DesktopScaledX(150) / (#StartRadius + 100) - Zoom) * 0.2
	EndIf
	
	ForEach Snake()
		*snake = @Snake()
		
		*head = FirstElement(*snake\body())
		If *head
			radius = Min(#MaxRadius, #StartRadius + *snake\score * 0.01)
			
			*snake\radius = radius
			
			If (*snake\index = #Sprite_FirstSnake) And (*snake\state <> #Snake_Crashed)
				Zoom + (Max(0.001, DesktopScaledX(150) / (radius + 100)) - Zoom) * 0.2
				ScrollX + (((width * 0.5) / Zoom - *head\x) - ScrollX) * 0.35
				ScrollY + (((height * 0.5) / Zoom - *head\y) - ScrollY) * 0.35
			EndIf
		EndIf
				
		
		If *snake\state = #Snake_Respawning
			; snake is respawning
			
			If Time > *snake\respawnTime
				*snake\state = #Snake_Alive
				*snake\respawnTime = 0
				*snake\nextTime = 0
				If *snake\index = #Sprite_FirstSnake
					Sound_Play(#Sound_start)
				EndIf
			EndIf
			
		ElseIf *snake\state = #Snake_Crashed
			; snake "crashed"
			
			x = (*head\x + ScrollX) * Zoom
			y = (*head\y + ScrollY) * Zoom
			
			*snake\reduction + 0.25
			i = *snake\reduction
			While (i > 1) And FirstElement(*snake\body())
				index = *snake\style\color(*snake\body()\index % *snake\style\nrColors)
				
				If x > 0 And x < width And y > 0 And y < height
					Spark_Add(*snake\body()\x, *snake\body()\y, #Sprite_Food + index)
				EndIf
				
				Food_Add(*snake\body()\x, *snake\body()\y, index + #MaxColors)
				Field_Unset(body, *snake\body())
				
				DeleteElement(*snake\body())
				i - 1
			Wend
			
			If ListSize(*snake\body()) = 0
				Snake_Kill(*snake)
			EndIf
			
		ElseIf *snake\state = #Snake_Alive
			
			If ListSize(*snake\body()) <= #StartLength
				*snake\nextUpdateTime = #UpdateTime
			EndIf
			
			If *head
				radius = Min(100, #StartRadius + *snake\score * 0.01)
				
				*snake\radius = radius
				
				If *snake\index <> #Sprite_FirstSnake
					If *snake\nextUpdateTime = #UpdateTime
						If Random(100) = 0
							*snake\nextUpdateTime = #RaceTime
						EndIf
					Else
						If Random(200) = 0
							*snake\nextUpdateTime = #UpdateTime
						EndIf
					EndIf
				EndIf
				
				If Time >= *snake\nextTime
					; move the last snake part to the first
					*head = FirstElement(*snake\body())
					x = *head\x
					y = *head\y
					
					*tail = LastElement(*snake\body())
					Field_Unset(body, *tail)
					
					MoveElement(*snake\body(), #PB_List_First)
					
					*snake\nextTime = Time + *snake\updateTime - dTime
				EndIf				

				*snake\delta = 1 - (*snake\nextTime - Time) / *snake\UpdateTime
				
				*head = FirstElement(*snake\body())
				*body = NextElement(*snake\body())
				Field_Unset(body, *head)
				
				dirX = Sin(*snake\angle) * #Speed
				dirY = Cos(*snake\angle) * #Speed
				*head\x = *body\x + dirX * *snake\delta
				*head\y = *body\y + dirY * *snake\delta
				
				
				*snake\updateTime + (*snake\nextUpdateTime - *snake\updateTime) * 0.15
				
				angle = Clamp(AngleDifference(*snake\direction, *snake\angle) / (radius * 0.3) * #RotationSpeed, -#RotationSpeed, #RotationSpeed)

				*snake\angle = Mod(*snake\angle + angle + #PI2, #PI2)					
			EndIf
			
			*head = FirstElement(*snake\body())
			
			If *head And (*head\x < radius Or *head\x >= #AreaWidth - radius Or *head\y < radius Or *head\y >= #AreaHeight - radius)
				
				; snake crashed into border
				Snake_Crash(*snake)
				
			ElseIf *head
				
				Field_Set(body, *head)
				
				x = (*head\x + ScrollX) * Zoom
				y = (*head\y + ScrollY) * Zoom
				If x < 0 Or x > width Or y < 0 Or y > height
					snakeIsVisible = #False
					ClearList(*snake\food())
				Else
					snakeIsVisible = #True
				EndIf
					
				
				*tail = LastElement(*snake\body())
				If *tail				
					
					; the 'food sucking' animation
					ForEach *snake\food()
						*food = *snake\food()
						x = (*head\x - *food\x)
						y = (*head\y - *food\y)
						If Sqr(x * x + y * y) < (*snake\radius + #FoodRadius)
							If *snake\index = #Sprite_FirstSnake
								If *food\index < #MaxColors
									Sound_Play(#Sound_eat1)
								Else
									Sound_Play(#Sound_eat2)
								EndIf
							EndIf
							DeleteElement(*snake\food())
						Else
							*food\x + x * 0.25 + dirX * 0.25
							*food\y + y * 0.25 + dirY * 0.25
						EndIf
					Next
					
					fx = *head\x / #CellSize * 1.0
					fy = *head\y / #CellSize * 1.0
					
					Protected fxa, fya
					Protected xd, yd, x1, y1, x2, y2
					
					Protected g = Max(2, radius * 2 / #CellSize)
					Select Degree(*snake\angle)
						Case 45 To 135
							x1 = fx : x2 = fx + g
							y1 = fy - g : y2 = fy + g
						Case 136 To 225
							x1 = fx - g : x2 = fx + g
							y1 = fy - g : y2 = fy
						Case 226 To 315
							x1 = fx - g : x2 = fx
							y1 = fy - g : y2 = fy + g
						Default
							x1 = fx - g : x2 = fx + g
							y1 = fy : y2 = fy + g
					EndSelect
					
					Protected nCollision, nFood, nSuperFood
					Protected.d collisionX, collisionY, foodX, foodY, foodMinDist
					
					nCollision = 0
					collisionX = 0
					collisionY = 0
					nFood = 0
					nSuperFood = 0
					foodX = 0
					foodY = 0
					foodMinDist = 999999
					
					If *head\x > #AreaWidth - radius - 100
						nCollision + 1
						collisionX + #AreaWidth
						collisionY + *head\y
					ElseIf *head\x < radius + 100
						nCollision + 1
						collisionY + *head\y
					EndIf
					
					If *head\y > #AreaHeight - radius - 100
						nCollision + 1
						collisionX + *head\x
						collisionY + #AreaHeight
					ElseIf *head\y < radius + 100
						nCollision + 1
						collisionX + *head\x
					EndIf
					
					For fya = y1 To y2
						For fxa = x1 To x2
							
							If fxa >= 0 And fxa < #FieldWidth And fya >= 0 And fya < #FieldHeight
								*cell = @Field(fxa + fya * #FieldWidth)
								
								ForEach *cell\body()
									*body = *cell\body()
									If *body And (*body\snakeIndex <> *snake\index) ; <- make sure that the snake is not colliding with itself
										
										*collisionSnake = *SnakeList(*body\snakeIndex)
										If *collisionSnake And (Distance(*head, *body) < (radius + *collisionSnake\radius))
											
											If *collisionSnake\state = #Snake_Respawning
												Snake_Crash(*collisionSnake)
												Snake_Kill(*collisionSnake)
												
												*snake\scoreCount + #SuperFoodScore
												
												If *snake\index = #Sprite_FirstSnake
													Sound_Play(#Sound_eatEgg)
												EndIf
												
											Else
												Snake_Crash(*snake)
												Break 3
											EndIf
											
										EndIf
										
										collisionX + *body\x
										collisionY + *body\y
										nCollision + 1
									EndIf
								Next
								
								ForEach *cell\food()
									*food = *cell\food()
									
									dist = Distance(*head, *food)
									If dist < (radius + #FoodRadius + 30)
										
										If *food\index < #MaxColors
											*snake\scoreCount + #FoodScore
										Else
											nSuperFood + 1
											*snake\scoreCount + #SuperFoodScore
										EndIf
										
										If snakeIsVisible
											; add this food to the snakes food list (for the 'food suck' animation)
											If AddElement(*snake\food())
												CopyStructure(*food, *snake\food(), Food)
											EndIf
										EndIf
										
										ChangeCurrentElement(Food(), *food)
										DeleteElement(Food())
										
										DeleteMapElement(*cell\food())
										
									ElseIf dist < foodMinDist
										
										foodMinDist = dist
										foodX = *food\x
										foodY = *food\y
										nFood + 1
										
									EndIf
								Next
								
							EndIf
							
						Next
					Next
					
					If *snake\state = #Snake_Alive And *snake\index <> #Sprite_FirstSnake
						If nCollision
							*snake\nextUpdateTime = #UpdateTime
						EndIf
						If nCollision And Random(1) = 0
							collisionX / nCollision
							collisionY / nCollision
							*snake\direction + AngleDifference(ATan2(*head\y - collisionY, *head\x - collisionX), *snake\direction) * 0.5
						ElseIf nFood
							*snake\direction + AngleDifference(ATan2(foodY - *head\y, foodX - *head\x), *snake\direction) * 0.25
							If nSuperFood > 1
								*snake\nextUpdateTime = #RaceTime
							EndIf
						Else
							*snake\direction + Rnd(-0.05, 0.05)
						EndIf
					EndIf
					
				EndIf
				
			EndIf
			
			If *snake\state = #Snake_Alive
				
				If (*snake\nextUpdateTime = #RaceTime) And (Time > *snake\shrinkTime) And (Random(2) = 0)
					; speeding snake -> release some food
					
					If LastElement(*snake\body())
						*snake\shrinkTime = Time + 50
						*snake\score = Max(0, *snake\score - 1)
						
						Food_Add(*snake\body()\x, *snake\body()\y, *snake\style\color(*snake\body()\index % *snake\style\nrColors))
						
						While LastElement(*snake\body()) And (ListSize(*snake\body()) > (#StartLength + *snake\score / 10))
							; shrink snake
							Spark_Add(*snake\body()\x, *snake\body()\y, #Sprite_Food + *snake\style\color(*snake\body()\index % *snake\style\nrColors), 15)
							
							Field_Unset(body, *snake\body())
							
							DeleteElement(*snake\body())
						Wend
					EndIf
				Else
					
					count = *snake\scoreCount / #SuperFoodScore
					If count > 0
						; snake is growing
						
						*snake\scoreCount = 0
						*snake\score + count * #SuperFoodScore
						
						*body = LastElement(*snake\body())
						If *body
							index = *snake\body()\index
							For i = 1 To count
								Snake_AddBody(*snake, *body\x, *body\y, (index + i) % *snake\style\nrColors)
								If *snake\index = #Sprite_FirstSnake
									Sound_Play(#Sound_grow)
								EndIf
							Next
						EndIf
					EndIf
					
				EndIf
				
				If (*snake\index = #Sprite_FirstSnake) And (ListSize(*snake\body()) > LongestSnake)
					LongestSnake = ListSize(*snake\body()) - 1
				EndIf
				
			EndIf
		EndIf
	Next
EndProcedure

Procedure Game_Draw()
	Protected index, tailIndex, snakeNr
	Protected x.l, y.l, xo, yo
	Protected.l x1, y1, x2, y2, incr
	Protected radius.d
	Protected fx, fy
	Protected.Body *head, *tail, *body, *previous
	Protected.Food *food
	Protected *cell.Cell
	Protected.d minX, minY, maxX, maxY
	Protected width = ScreenW
	Protected height = ScreenH
	Protected gridX.d = 500 * Zoom
	Protected gridY.d = gridX * 0.75
	Protected sprite, spriteW, spriteH
	Protected *player.Snake = *SnakeList(#Sprite_FirstSnake)
	Protected *snake.Snake
	Protected NewMap visibleSnake()
	
	If FullScreen = #False
		width = DesktopScaledX(ScreenW)
		height = DesktopScaledY(ScreenH)
	EndIf
	
	If (GamePaused = #False) And CameraShake > Time
		ScrollY + Sin(Time * 0.04) * ((Time - CameraShake) / 2000.0) * 15
	EndIf
	
 	ClearScreen(RGB(0,0,0))
	
	SpriteQuality(#SpriteQuality)
 	
 	If gridX > 5
 		minX = Max(0, ScrollX * Zoom) - gridX
 		minY = Max(0, ScrollY * Zoom) - gridY
 		maxX = Min(width, (#AreaWidth + ScrollX) * Zoom) + gridX
 		maxY = Min(height, (#AreaHeight + ScrollY) * Zoom) + gridY
 		
 		sprite = Sprite(#Sprite_Floor)
 		ZoomSprite(sprite, gridX + 1, gridY + 1)
 		
 		y = Mod(ScrollY * Zoom, gridY) - gridY
 		While y < maxY
 			If y >= minY
 				x = Mod(ScrollX * Zoom, gridX) - gridX
 				While x < maxX
 					If x >= minX
 						DisplaySprite(sprite, x, y)
 					EndIf
 					x + gridX
 				Wend
 			EndIf
 			y + gridY
 		Wend
 	EndIf
 	
 	; determine which snake body parts are visible
	incr = #CellSize	
	maxX = (width / Zoom) + #CellSize * 2
	maxY = (height / Zoom) + #CellSize * 2
	y1 = -#CellSize * 2
	While (y1 < maxY)
		fy = (y1 - ScrollY) / #CellSize * 1.0
		If fy >= 0 And fy < #FieldHeight
			x1 = -#CellSize * 2
			While x1 < maxX
				fx = (x1 - ScrollX) / #CellSize * 1.0
				If fx >= 0 And fx < #FieldWidth
					*cell = @Field(fx + fy * #FieldWidth)
					
					ForEach *cell\body()
						*cell\body()\isVisible = 1
						visibleSnake(Chr(*cell\body()\snakeIndex)) = *cell\body()\snakeIndex
					Next
					
				EndIf
				x1 + incr
			Wend
		EndIf
		y1 + incr
	Wend
	
	ForEach visibleSnake()
		*snake = *SnakeList(visibleSnake())
		
		If ListSize(*snake\body()) > 0
			
			; draw sucked in food
			ForEach *snake\food()
				*food = *snake\food()
				sprite = Sprite(#Sprite_Food + *food\index)
				radius = Max(#FoodRadius, #FoodRadius + Sin((*food + Time) * 0.004) * 5) * Zoom
				If *food\index >= #MaxColors
					radius * 3
				EndIf
				ZoomSprite(sprite, radius, radius)
				DisplayTransparentSprite(sprite, (*food\x + ScrollX) * Zoom - radius * 0.5, (*food\y + ScrollY) * Zoom - radius * 0.5)
			Next
			
			; draw the snake
			*head = FirstElement(*snake\body())
			*body = LastElement(*snake\body())
			index = ListSize(*snake\body()) - 1
			tailIndex = Max(0, index - 3)
			radius = *snake\radius * 2 * Zoom
			
			While PreviousElement(*snake\body())
				*previous = *body
				*body = *snake\body()
				
				If *body\isVisible
					*body\isVisible = 0					
					
					If *body <> *head
						
						sprite = Sprite(#Sprite_FirstSnake + *snake\style\color(index % *snake\style\nrColors))
						
						radius = *snake\radius * 4 * Zoom
						
						If index > tailIndex
							radius * (1 - (index - tailIndex) / 6.0)
						EndIf
						
						; body
						x = *previous\x + (*body\x - *previous\x) * *snake\delta
						y = *previous\y + (*body\y - *previous\y) * *snake\delta
						
; 						If (index >= tailIndex) And (*snake\wobbleTime > Time)
						If (*snake\wobbleTime > Time)
							; snake wobble effect
							Protected fade.d = (*snake\wobbleTime - Time) / 1000.0
							radius + Sin(Time * 0.025 - index) * (fade * 15)

							ZoomSprite(sprite, radius, radius)
							DisplayTransparentSprite(sprite,
							                         (x + ScrollX) * Zoom - radius * 0.5,
							                         (y + ScrollY) * Zoom - radius * 0.5)
							
							
							sprite = Sprite(#Sprite_SuperFood + *snake\style\color(index % *snake\style\nrColors))
							radius * 1.5
							ZoomSprite(sprite, radius, radius)
							DisplayTransparentSprite(sprite,
							                         (x + ScrollX) * Zoom - radius * 0.5,
							                         (y + ScrollY) * Zoom - radius * 0.5, fade * 255)
						Else
							ZoomSprite(sprite, radius, radius)
							DisplayTransparentSprite(sprite,
							                         (x + ScrollX) * Zoom - radius * 0.5,
							                         (y + ScrollY) * Zoom - radius * 0.5)
						EndIf

					ElseIf *snake\state <> #Snake_Crashed

						; head
						sprite = Sprite(#Sprite_FirstSnake + *snake\style\color(0))
						radius = *snake\radius * 4 * Zoom
						
						ZoomSprite(sprite, radius, radius)
						DisplayTransparentSprite(sprite, 
						                         (*head\x + ScrollX) * Zoom - radius * 0.5,
						                         (*head\y + ScrollY) * Zoom - radius * 0.5)
						
						; eyes
						If *snake\eyeBlinkTime= 0 And Random(50) = 0
							*snake\eyeBlinkTime = Time + 150
						EndIf
						If Time > *snake\eyeBlinkTime
							*snake\eyeBlinkTime = 0
							sprite = Sprite(#Sprite_Eye)
						Else
							sprite = Sprite(#Sprite_EyeClosed)
						EndIf
						
						radius = *snake\radius * 0.65
						x = *head\x + ScrollX - radius
						y = *head\y + ScrollY - radius
						
						ZoomSprite(sprite, radius * 2 * Zoom, radius * 2 * Zoom)
						RotateSprite(sprite, -Degree(*snake\angle), #PB_Absolute)
						
						DisplayTransparentSprite(sprite,
						                         (x + Sin(*snake\angle - Radian(35)) * radius * 1.15) * Zoom,
						                         (y + Cos(*snake\angle - Radian(35)) * radius * 1.15) * Zoom)
						
						DisplayTransparentSprite(sprite,
						                         (x + Sin(*snake\angle + Radian(35)) * radius * 1.15) * Zoom,
						                         (y + Cos(*snake\angle + Radian(35)) * radius * 1.15) * Zoom)
						
						
						; draw egg if snake is respawning
						If *snake\state = #Snake_Respawning
							radius = Zoom * ((*snake\radius * 5) + Sin(Time * 0.01) * 10) + 25
							If Time > *snake\respawnTime - 250
								fade = (*snake\respawnTime - Time) / 250.0
								radius * (1 - fade) * 2
							Else
								fade = 1
							EndIf
							x = (*head\x + ScrollX) * Zoom - radius * 0.5
							y = (*head\y + ScrollY) * Zoom - radius * 0.6
							ZoomSprite(Sprite(#Sprite_Egg), radius, radius)
							DisplayTransparentSprite(Sprite(#Sprite_Egg), x, y, fade * 255)
						EndIf
						
					EndIf
					
				EndIf
				
				index - 1
			Wend
						
		EndIf
	Next
	
	; draw food and superfood
	If (#FoodRadius * Zoom) > 5
		y1 = -#CellSize * 2
		While (y1 < maxY)
			fy = (y1 - ScrollY) / #CellSize * 1.0
			If fy >= 0 And fy < #FieldHeight
				x1 = -#CellSize * 2
				While x1 < maxX
					fx = (x1 - ScrollX) / #CellSize * 1.0
					If fx >= 0 And fx < #FieldWidth
						*cell = @Field(fx + fy * #FieldWidth)
						
						ForEach *cell\food()
							*food = *cell\food()
							sprite = Sprite(#Sprite_Food + *food\index)
							
							If *food\index < #MaxColors
								radius = Max(#FoodRadius, #FoodRadius + Sin((*food + Time) * 0.004) * 10) * Zoom
							Else
								radius = Max(#FoodRadius, #FoodRadius + Sin((*food + Time) * 0.004) * 10) * Zoom * 3
							EndIf
							
							If sprite
								x = *food\x + Sin((*food + Time) * 0.0005) * radius * 0.2
								y = *food\y + Cos((*food + Time) * 0.0005) * radius * 0.2
								
								ZoomSprite(Sprite, radius, radius)
								DisplayTransparentSprite(sprite,
								                         (x + ScrollX) * Zoom - radius * 0.5,
								                         (y + ScrollY) * Zoom - radius * 0.5)
							EndIf
						Next
						
					EndIf
					x1 + incr
				Wend
			EndIf
			y1 + incr
		Wend
	EndIf
 	ForEach Spark()
 		If Time > Spark()\time
 			DeleteElement(Spark())
 		Else
 			fade = (Spark()\time - Time) / Spark()\duration
 			
 			Spark()\x + Spark()\xd * fade
 			Spark()\y + Spark()\yd * fade
 			
 			sprite = Spark()\sprite
 			radius = (5 + fade * 25) * Zoom
 			
 			x = (Spark()\x + ScrollX) * Zoom - radius * 0.5
			y = (Spark()\y + ScrollY) * Zoom - radius * 0.5
			
			ZoomSprite(sprite, radius, radius)
 			DisplayTransparentSprite(sprite, x, y, fade * 255)
 		EndIf
 	Next
 	
	ForEach Explosion()
		If Time > Explosion()\time
			DeleteElement(Explosion())
		Else
			radius = Pow(1 - (Explosion()\time - Time) / #ExplosionTime, 2)
			x = (Explosion()\x + ScrollX) * Zoom
			y = (Explosion()\y + ScrollY) * Zoom
			ZoomSprite(Sprite(#Sprite_Explosion), radius * #ExplosionDistance, radius * #ExplosionDistance)
			DisplayTransparentSprite(Sprite(#Sprite_Explosion), x - radius * #ExplosionDistance * 0.5, y - radius * #ExplosionDistance * 0.5, 255 * (1 - radius))
		EndIf	
	Next
	
	; draw cursor if mouse moved
	If DrawCursor > Time
		If *SnakeList(#Sprite_FirstSnake)
			sprite = Sprite(#Sprite_SuperFood + *SnakeList(#Sprite_FirstSnake)\style\color(0))
			ZoomSprite(sprite, 64, 64)
			DisplayTransparentSprite(sprite, MousePosX - SpriteWidth(sprite), MousePosY - SpriteHeight(sprite), (DrawCursor - Time) * (255 / 1000.0))
		EndIf
	EndIf
	
	
	If StartDrawing(ScreenOutput())
		; draw borders
		minX = Max(0, ScrollX * Zoom)
		minY = Max(0, ScrollY * Zoom)
		maxX = Min(width, (#AreaWidth + ScrollX) * Zoom)
		maxY = Min(height, (#AreaHeight + ScrollY) * Zoom)
		
		FrontColor(RGB(16,45,65))
		Box(0, 0, width, minY)
		Box(0, maxY, width, height - maxY)
		Box(0, minY, minX, maxY - minY)
		Box(maxX, minY, width - maxX, maxY - minY)
		
		FrontColor(RGB(128,150,200))
		Box(minX - 10, minY - 10, maxX - minX + 20, 10)
		Box(minX - 10, maxY, maxX - minX + 20, 10)
		Box(minX - 10, minY, 10, maxY - minY)
		Box(maxX, minY, 10, maxY - minY)
		
		CompilerIf #DEBUGMODE			
			DrawingMode(#PB_2DDrawing_Outlined | #PB_2DDrawing_Transparent)
			FrontColor(RGB(0,0,0))
			minX = (width / Zoom) + #CellSize
			minY = (height / Zoom) + #CellSize
			y1 = Mod(ScrollY, #CellSize)
			While y1 < minY
				fy = (y1 - ScrollY) / #CellSize * 1.0
				If fy >= 0 And fy < #FieldHeight
					x1 = Mod(ScrollX, #CellSize)
					While x1 < minX
						fx = (x1 - ScrollX) / #CellSize * 1.0
						If fx >= 0 And fx < #FieldWidth
							x = x1 * Zoom
							y = y1 * Zoom
							Box(x, y, #CellSize * Zoom + 1, #CellSize * Zoom + 1)
							DrawText(x + 2, y + 2, Str(MapSize(Field(fx, fy)\body())), RGB(255,255,0))
							DrawText(x + 2, y + 22, Str(MapSize(Field(fx, fy)\food())), RGB(0,255,255))
						EndIf
						x1 + #CellSize
					Wend
				EndIf
				y1 + #CellSize
			Wend
				
			ForEach Snake()
				*snake = @Snake()
				*head = FirstElement(*snake\body())
				If *head
					x1 = (*head\x + ScrollX) * Zoom
					y1 = (*head\y + ScrollY) * Zoom
					x2 = x1 + Sin(*snake\direction) * 50 
					y2 = y1 + Cos(*snake\direction) * 50 
					LineXY(x1, y1, x2, y2, RGB(255,0,0))
				EndIf
				
				ForEach *snake\body()
					x = (*snake\body()\x + ScrollX) * Zoom
					y = (*snake\body()\y + ScrollY) * Zoom
					If x > 0 And x < ScreenW And y > 0 And y < ScreenH
						Circle(x, y, 5, #Black)
						Circle(x, y, 4, #White)
					EndIf
				Next
			Next
			
		CompilerEndIf
		
		DrawingFont(FontID(0))
		DrawingMode(#PB_2DDrawing_Transparent)
		
		Protected text.s
		
		CompilerIf #DEBUGMODE
			text = "FPS:  " + Str(FPS)
			DrawText(20, 30, text, RGB(128,128,128))
			text = "SNAKES:  " + Str(ListSize(Snake()))
			DrawText(20, 90, text, RGB(128,128,128))
			text = "FOOD:  " + Str(ListSize(Food()))
			DrawText(20, 150, text, RGB(128,128,128))
			If *player
				text = "RADIUS:  " + StrD(*player\radius, 1)
				DrawText(10, 210, text, RGB(128,128,128))
			EndIf
		CompilerEndIf
		
		If GamePaused
			text = "- PAUSED -"
			DrawText((width - TextWidth(text)) * 0.5, (height - TextHeight(text)) * 0.5, text, RGB(128 + Sin(ElapsedMilliseconds() * 0.005) * 127,0,0))
		EndIf

		text = "BEST: " + Str(LongestSnake)
		DrawText(width - (TextWidth(text) + 30), 30, text, RGB(255,255,128))
		
		If *player
			text = "SIZE: " + Str(ListSize(*player\body()) - 1)
			DrawText(width - (TextWidth(text) + 30), 90, text, RGB(255,255,255))
		ElseIf GamePaused = #False
			text = "- PRESS 'LEFT CONTROL' TO START -"
			DrawText((width - TextWidth(text)) * 0.5, (height - TextHeight(text)) * 0.5 - 60, text, RGB(128 + Sin(Time * 0.005) * 127,0,0))
			text = "CURSOR KEYS = DIRECTION | LEFT-CONTROL-KEY = SPEED UP"
			DrawText((width - TextWidth(text)) * 0.5, (height - TextHeight(text)) * 0.5, text, RGB(64,64,64))
			text = "...OR USE MOUSE"
			DrawText((width - TextWidth(text)) * 0.5, (height- TextHeight(text)) * 0.5 + 60, text, RGB(64,64,64))
		EndIf
		
		StopDrawing()
	EndIf
	
	FlipBuffers()
EndProcedure

Procedure Game_TestEvents()
	Protected event
	Protected *player.Snake
	Protected dx, dy, oldMouseX = MousePosX, oldMouseY = MousePosY
	
	ExamineMouse()
	ExamineKeyboard()
	
	
	If FullScreen
		MousePosX = MouseX()
		MousePosY = MouseY()
	Else
		MousePosX = WindowMouseX(0)
		MousePosY = WindowMouseY(0)
	EndIf
	
	If MousePosX <> oldMouseX Or MousePosY <> oldMouseY
		DrawCursor = Time + 1000
	EndIf

	If KeyboardPushed(#PB_Key_Escape)
		End
	EndIf
	
	If KeyboardReleased(#PB_Key_S)
		PlaySounds = Bool(Not PlaySounds)
	EndIf
	
	If KeyboardReleased(#PB_Key_P)
		GamePaused = Bool(Not GamePaused)
		If GamePaused = #False
			DeltaTime = 0
			Time = ElapsedMilliseconds()
			If IsSound(#Sound_music)
				ResumeSound(#Sound_music)
			EndIf
		Else
			PauseSound(#PB_All)
		EndIf
	EndIf	
	
	If GamePaused = #False
		
		If LeftButton And (MouseButton(#PB_MouseButton_Left) = 0)
			LeftButton & %10
		EndIf
		If KeyboardReleased(#PB_Key_LeftControl)
			LeftButton & %01
		EndIf
		
		*player = *SnakeList(#Sprite_FirstSnake)
		If *player = #Null
			If (LeftButton = 0) And (KeyboardPushed(#PB_Key_LeftControl) Or MouseButton(#PB_MouseButton_Left))
				Snake_Add(#Sprite_FirstSnake)
				Sound_Play(#Sound_respawn)
				CameraShake = 0
			EndIf
		ElseIf *player\state = #Snake_Alive
			If MouseDeltaX() Or MouseDeltaY()
				If FirstElement(*player\body())
					MouseDx = MousePosX- (*player\body()\x + ScrollX) * Zoom
					MouseDy = MousePosY - (*player\body()\y + ScrollY) * Zoom
					If Sqr(MouseDx * MouseDx + MouseDy * MouseDy) > 50
						*player\direction = ATan2(MouseDy, MouseDx)
					EndIf
				EndIf
			EndIf
			
			If MouseButton(#PB_MouseButton_Left)
				LeftButton | %01
			EndIf
			If (LeftButton = 0) And KeyboardPushed(#PB_Key_LeftControl)
				LeftButton | %10
			EndIf
			
			If LeftButton
				*player\nextUpdateTime = #RaceTime
			Else
				*player\nextUpdateTime = #UpdateTime
			EndIf
			
; 			If KeyboardPushed(#PB_Key_Subtract)
; 				Zoom * 0.5
; 			EndIf
			If KeyboardPushed(#PB_Key_Left)
				dx = -1
			ElseIf KeyboardPushed(#PB_Key_Right)
				dx = 1
			EndIf
			If KeyboardPushed(#PB_Key_Up)
				dy = -1
			ElseIf KeyboardPushed(#PB_Key_Down)
				dy = 1
			EndIf			
			If dx Or dy
				*player\direction = ATan2(dy,dx)
			EndIf
			
		EndIf
	EndIf
	
	If FullScreen = #False
		Repeat 
			event = WindowEvent()
			Select event
				Case #PB_Event_CloseWindow
					End
			EndSelect
		Until event = 0
		
		If (MouseReleased = #False) And (MousePosX <= 0 Or MousePosY <= 0)
			MouseReleased = #True
			ReleaseMouse(#True)
		ElseIf MouseReleased And (MousePosX > 0 And MousePosY > 0)
			MouseReleased = #False
			ReleaseMouse(#False)
			MouseLocate(MousePosX, MousePosY)
		EndIf
	EndIf
EndProcedure

Procedure Game_Free()
	Protected x, y, index
	
	ClearList(Food())
	ClearList(Snake())
	ClearList(Explosion())
	
	For y = 0 To #FieldHeight - 1
		For x = 0 To #FieldWidth - 1
			ClearMap(Field(index)\body())
			ClearMap(Field(index)\food())
			index + 1
		Next
	Next	
EndProcedure

Procedure Game_New()
	Protected i, s, index, startColor, colIncr, foodCount, foodPerCell = 2
	
	Game_Free()
	
	Dim Field.Cell(#FieldWidth * #FieldHeight)
	Dim Sprite(1000)
	Dim SnakeStyle.SnakeStyle(#MaxStyles)
	Dim *SnakeList.Snake(1000)
	
	LoadFont(0, "Consolas", 24)
	Sounds_Load(#PB_Compiler_FilePath + "sound\")
	Sprites_Load(#PB_Compiler_FilePath + "image\")
	
	Zoom = DesktopScaledX(150) / (#StartRadius + 100)
	
	For i = 0 To #MaxStyles - 1
		SnakeStyle(i)\nrColors = Random(#MaxColors / 4, 1)
		
		startColor = Random(#MaxColors - 1)
		colIncr = Random(SnakeStyle(i)\nrColors, 1)

		For s = 0 To SnakeStyle(i)\nrColors - 1
			If Random(5) = 0
				index + 5
			Else
				index = Mod(startColor + Abs(SnakeStyle(i)\nrColors * 0.5 - s * colIncr), #MaxColors)
			EndIf
			If index < 0 
				index + #MaxColors
			EndIf
			SnakeStyle(i)\color(s) = Clamp(index, 0, #MaxColors - 1)
		Next
	Next
		
	For i = 1 To 50
 		Snake_Add(#Sprite_FirstSnake + i)
 	Next
 	
	foodCount = ((#AreaWidth * #AreaHeight) / (#CellSize * #CellSize)) * foodPerCell
	For i = 1 To foodCount
		Food_Add(Rnd(#FoodRadius, #AreaWidth - #FoodRadius), Rnd(#FoodRadius, #AreaHeight - #FoodRadius), Random(#MaxColors - 1, 1))
	Next
	
	FoodCountStart = ListSize(Food())
	LongestSnake = 0
	
 	Sound_Play(#Sound_music, 100, #PB_Sound_Loop)
EndProcedure

If FullScreen
	If OpenScreen(ScreenW, ScreenH, 32, "SnakeZ") = 0
		MessageRequester("", "Couldn't open screen")
		End
	EndIf
Else
	If OpenWindow(0, 0, 0, ScreenW, ScreenH, "SnakeZ", #PB_Window_SystemMenu | #PB_Window_Maximize) = 0
		MessageRequester("", "Couldn't open window")
		End
	EndIf
	ScreenW = WindowWidth(0)
	ScreenH = WindowHeight(0)
	If OpenWindowedScreen(WindowID(0), 0, 0, DesktopScaledX(ScreenW), DesktopScaledY(ScreenH), 0, 0, 0, #PB_Screen_NoSynchronization) = 0
		MessageRequester("", "Couldn't open screen")
		End
	EndIf
EndIf

Game_New()

SetFrameRate(30)

Repeat
	If GamePaused = #False
		DeltaTime = ElapsedMilliseconds() - Time
		Time = ElapsedMilliseconds()
	EndIf
	
	Game_TestEvents()
	Game_Update(DeltaTime)
 
	Game_Draw()
	
 	Delay(5)
ForEver
; IDE Options = PureBasic 6.00 LTS (Windows - x64)
; CursorPosition = 981
; FirstLine = 954
; Folding = -----
; Optimizer
; EnableXP
; DPIAware
; UseIcon = icon\SnakeZ.ico
; Executable = SnakeZ.exe
; DisableDebugger
; Compiler = PureBasic 6.00 LTS - C Backend (Windows - x64)
; DisablePurifier = 1,1,1,1