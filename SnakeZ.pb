EnableExplicit

UseZipPacker()
InitSprite()
InitKeyboard()
InitMouse()
InitSound()
UseOGGSoundDecoder()
UsePNGImageDecoder()
UsePNGImageEncoder()

#DEBUGMODE = 0

#Brightness = 1.0
#FieldWidth = 100
#FieldHeight = 50
#FieldSize = 100
#SpriteSize  = 128
#SpriteSizeH  = #SpriteSize * 0.5
#AreaWidth = #FieldWidth * #FieldSize
#AreaHeight = #FieldHeight * #FieldSize
#MaxSnakes = 1000
#FoodScore = 1
#SuperFoodScore = 10
#StartRadius = 25
#StartLength = 5
#FoodRadius = 15
#UpdateTime = 150
#RaceTime = #UpdateTime / 3
#Speed = 30
#RotationSpeed = 3.0
#RespawnTime = 3000
#ExplosionTime = 1000
#PI2 = #PI * 2

Enumeration
	#Snake_Respwawning
	#Snake_Alive
	#Snake_Crashed
EndEnumeration

;sprite numbers
Enumeration
	#Sprite_Egg
	#Sprite_Eye
	#Sprite_EyeClosed
	#Sprite_Explosion
	#Sprite_Floor
	#Sprite_Food
	#Sprite_FoodLast = #Sprite_Food + 31
	#Sprite_SuperFood
	#Sprite_SuperFoodLast = #Sprite_SuperFood + 31
	#Sprite_FirstSnake
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
EndEnumeration

Structure Body
	index.w
	x.l
	y.l
	isVisible.b
EndStructure

Structure Snake
	index.l
	style.b
	
	state.b
	
	nextTime.i
	updateTime.i
	nextUpdateTime.i
	delta.d	
	
	respawnTime.i
	eyeBlinkTime.i
	shrinkTime.i
	
	radius.d
	direction.d
	angle.d
	scoreCount.i
	score.i
	
	List body.Body()
	List *food.Body()
EndStructure

Structure StyleData
	sprite.i
	color.l
EndStructure

Structure SnakeStyle
	sprite.i
	color.l
EndStructure

Structure FieldEntry
	Map *body.Body()
	Map *food.Body()
EndStructure

Structure Explosion
	x.l
	y.l
	time.i
EndStructure

Structure Spark
	sprite.i
	x.d
	y.d
	angle.d
	speed.d
EndStructure

Global ScreenW = 1024, ScreenH = 768

Global FullScreen = #False;True
Global SoundOn = #True

Global Dim Field.FieldEntry(#FieldWidth, #FieldHeight)
Global NewList Snake.Snake()
Global NewList Food.Body()
Global NewList Explosion.Explosion()
Global NewList Spark.Spark()
Global.d ScrollX, ScrollY, Zoom = 1.0, OldZoom = Zoom
Global FPS, FPSTime, FPSCount, Time, RedrawTime, DeltaTime.d
Global FoodCountStart
Global MousePosX, MousePosY, MouseDx, MouseDy, LeftButton, MouseReleased, DrawCursor = 0
Global BestScore
Global Dim SnakeStyle.SnakeStyle(31)
Global Dim Sprite(128)
Global Dim *SnakeList.Snake(#MaxSnakes)

Macro RGBA2(r_, g_, b_, a_ = 255)
	RGBA(Min(255, r_ * #Brightness), Min(255, g_ * #Brightness), Min(255, b_ * #Brightness), a_)
EndMacro

Procedure.d Rnd(min.d, max.d)
	ProcedureReturn min + Random(Int((max - min) * 1000000000)) / 1000000000.0
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

Procedure.d AngleDifference(angle1.d, angle2.d)
	angle1 = Mod(angle1,  #PI2)
	angle2 = Mod(angle2,  #PI2)
	ProcedureReturn Mod(((angle1 - angle2) + #PI + #PI2), #PI2) - #PI
EndProcedure

Macro Distance(body1_, body2_)
	Sqr((body1_\x - body2_\x) * (body1_\x - body2_\x) + (body1_\y - body2_\y) * (body1_\y - body2_\y))
EndMacro

Macro Field_Set(map_, type_)
	Define fx_ = type_\x / #FieldSize
	Define fy_ = type_\y / #FieldSize
	If fx_ > -1 And fx_ <= #FieldWidth And fy_ > -1 And fy_ <= #FieldHeight
		CompilerIf #PB_Compiler_Debugger
			If type_\index > #MaxSnakes
				DebuggerError("Macro 'Field_Set' -  Index too high!!!")
			EndIf
		CompilerEndIf
		Field(fx_, fy_)\map_(Str(type_)) = type_
 	EndIf
EndMacro

Macro Field_Unset(map_, type_)
	Define fx_ = type_\x / #FieldSize
	Define fy_ = type_\y / #FieldSize
	If fx_ > -1 And fx_ <= #FieldWidth And fy_ > -1 And fy_ <= #FieldHeight	
		If FindMapElement(Field(fx_, fy_)\map_(), Str(type_))
			DeleteMapElement(Field(fx_, fy_)\map_())
		EndIf
	EndIf
EndMacro

Procedure Sounds_Load()
	Protected *buffer, size.q
	Protected error
	If OpenPack(0, "pack.dat")
		If ExaminePack(0)
			While NextPackEntry(0)
				size = PackEntrySize(0, #PB_Packer_UncompressedSize)
				*buffer = AllocateMemory(size)
				If *buffer
					UncompressPackMemory(0, *buffer, size)
					Select LCase(PackEntryName(0))
						Case "sound_start":			error + Bool(CatchSound(#Sound_start, *buffer, size) = 0)
						Case "sound_respawn":		error + Bool(CatchSound(#Sound_respawn, *buffer, size) = 0)
						Case "sound_eat1":			error + Bool(CatchSound(#Sound_eat1, *buffer, size) = 0)
						Case "sound_eat2":			error + Bool(CatchSound(#sound_eat2, *buffer, size) = 0)
						Case "sound_eategg":		error + Bool(CatchSound(#Sound_eatEgg, *buffer, size) = 0)
						Case "sound_explosion1":	error + Bool(CatchSound(#Sound_explosion1, *buffer, size) = 0)
						Case "sound_explosion2":	error + Bool(CatchSound(#Sound_explosion2, *buffer, size) = 0)
						Case "sound_speedUp":		error + Bool(CatchSound(#Sound_speedUp, *buffer, size) = 0)
						Case "sound_music":			error + Bool(CatchSound(#Sound_music, *buffer, size) = 0)
					EndSelect
					FreeMemory(*buffer)
				EndIf
			Wend
		EndIf
		ClosePack(0)
	Else
		error = 1
	EndIf
	
	If error
		SoundOn = 0
	Else
		SoundVolume(#Sound_eat1, 7)
		SoundVolume(#Sound_eat2, 10)
	EndIf
EndProcedure

Procedure Sound_Play(sound, volume = 100, flags = 0)
	If SoundOn And IsSound(sound)
		PlaySound(sound, flags, volume)
	EndIf
EndProcedure

Procedure Sprite_Sphere(fileName.s, col, darkCol)
	Protected s, i = CreateImage(#PB_Any, #SpriteSize, #SpriteSize, 32, #PB_Image_Transparent)
	
	If IsImage(i)
		If StartDrawing(ImageOutput(i))
 			DrawingMode(#PB_2DDrawing_Gradient | #PB_2DDrawing_AlphaBlend)
			GradientColor(0.00, RGBA2(0,0,0, 128))
			GradientColor(0.50, RGBA2(0,0,0, 128))
			GradientColor(1.00, RGBA2(0,0,0, 0))
			CircularGradient(#SpriteSize * 0.6, #SpriteSize * 0.6, #SpriteSize * 0.4)
			Circle(#SpriteSize * 0.6, #SpriteSize * 0.6, #SpriteSize * 0.4)
			
			ResetGradientColors()
			GradientColor(0.00, RGBA2(255, 255, 255))
			GradientColor(0.15, col)
			GradientColor(0.65, darkCol)
			GradientColor(1.00, RGBA2((Red(col)+Red(darkCol) * 0.8) * 0.3, (Green(col)+Green(darkCol) * 0.8) * 0.3, (Blue(col)+Blue(darkCol)) * 0.3) )
			CircularGradient(#SpriteSizeH * 0.8, #SpriteSizeH * 0.8, #SpriteSizeH * 0.7)
			Circle(#SpriteSizeH, #SpriteSizeH, #SpriteSizeH * 0.5)
			StopDrawing()
		EndIf
		
		SaveImage(i, fileName, #PB_ImagePlugin_PNG)
		s = LoadSprite(#PB_Any, fileName, #PB_Sprite_AlphaBlending)
		
		FreeImage(i)
	EndIf
	ProcedureReturn s
EndProcedure

Procedure Sprite_Food(fileName.s, col)
	Protected s, i = CreateImage(#PB_Any, #SpriteSizeH, #SpriteSizeH, 32, #PB_Image_Transparent)
	
	If IsImage(i)
		If StartDrawing(ImageOutput(i))
			col = RGBA2(Red(col) * 1.25, Green(col) * 1.25, Blue(col) * 1.25)
			
			DrawingMode(#PB_2DDrawing_Gradient | #PB_2DDrawing_AlphaBlend)
			GradientColor(0.00, col)
			GradientColor(0.30, col)
			GradientColor(0.31, RGBA2(Red(col), Green(col), Blue(col), 64))
			GradientColor(1.00, RGBA2(Red(col), Green(col), Blue(col), 0))
			CircularGradient(#SpriteSizeH * 0.5, #SpriteSizeH * 0.5, #SpriteSizeH * 0.5)
			Circle(#SpriteSizeH * 0.5, #SpriteSizeH * 0.5, #SpriteSizeH * 0.5)
			StopDrawing()
		EndIf
		
		SaveImage(i, fileName, #PB_ImagePlugin_PNG)
		s = LoadSprite(#PB_Any, fileName, #PB_Sprite_AlphaBlending)
		
		FreeImage(i)
	EndIf
	ProcedureReturn s
EndProcedure

Procedure Sprite_Egg(fileName.s)
	Protected s, i = CreateImage(#PB_Any, #SpriteSize, #SpriteSize, 32, #PB_Image_Transparent)
	
	If IsImage(i)
		If StartDrawing(ImageOutput(i))
			DrawingMode(#PB_2DDrawing_AlphaBlend)
			
			Box(0, 0, #SpriteSize, #SpriteSize, RGBA2(0, 0, 0, 0))
			Protected.d x, y, t, a = 1.0 / #SpriteSize * 2
			y = -1 : While y < 1
				x = -1 : While x < 1
					t = (Pow(y,2) + Pow(Pow(1.4, y) * (1.25*x), 2))
					If t < 0.8 And t > 0.6
						Box(#SpriteSizeH + x * #SpriteSizeH, #SpriteSizeH - y * #SpriteSizeH, 1, 1, RGBA2(255, 255, 255))
					ElseIf t <= 0.6
						Box(#SpriteSizeH + x * #SpriteSizeH, #SpriteSizeH - y * #SpriteSizeH, 1, 1, RGBA2(255, 255, 255, t * 128))
					EndIf
				x + a:Wend
			y + a:Wend
			StopDrawing()
		EndIf
		
		SaveImage(i, filename, #PB_ImagePlugin_PNG)
		s = LoadSprite(#PB_Any, filename, #PB_Sprite_AlphaBlending)
		
		FreeImage(i)
	EndIf
	
	ProcedureReturn s
EndProcedure

Procedure Sprite_Floor(filename.s)
	Protected s, i = CreateImage(#PB_Any, #SpriteSize, #SpriteSize)
	Protected a, b, rx = #SpriteSizeH * 0.5, ry = rx * 1.125
	
	; create hexgagonal floor tile
	If IsImage(i)
		If StartVectorDrawing(ImageVectorOutput(i))
			For b = 0 To 6
				SaveVectorState()
				
				If b > 0
					TranslateCoordinates(Sin(Radian(b * 60 + 30)) * rx * 2, Cos(Radian(b * 60 + 30)) * ry * 2)
				EndIf
				
				MovePathCursor(#SpriteSizeH + Sin(0) * rx, #SpriteSizeH + Cos(0) * ry)
				For a = 0 To 5
					AddPathLine(#SpriteSizeH + Sin(Radian(a * 60)) * rx, #SpriteSizeH + Cos(Radian(a * 60)) * ry)
				Next
				ClosePath()
				VectorSourceColor(RGBA2(16, 32, 48))
				StrokePath(8, #PB_Path_RoundCorner | #PB_Path_RoundEnd | #PB_Path_Preserve)
				VectorSourceColor(RGBA2(32, 48, 64))
				StrokePath(4, #PB_Path_RoundCorner | #PB_Path_RoundEnd | #PB_Path_Preserve)
				
				VectorSourceCircularGradient(PathCursorX(), PathCursorY(), #SpriteSize)
				VectorSourceGradientColor(RGBA2(8,16,32), 0)
				VectorSourceGradientColor(RGBA2(48,64,96), 1)
				FillPath()
				
				RestoreVectorState()
			Next
			StopVectorDrawing()
		EndIf
		
		SaveImage(i, filename, #PB_ImagePlugin_PNG)
		s = LoadSprite(#PB_Any, filename, #PB_Sprite_AlphaBlending)
		
		FreeImage(i)
	EndIf
	
	ProcedureReturn s
EndProcedure

Procedure Sprite_Explosion(filename.s, col)
	Protected s, i = CreateImage(#PB_Any, #SpriteSize, #SpriteSize, 32, #PB_Image_Transparent) 

	If IsImage(i)
		If StartDrawing(ImageOutput(i))
			DrawingMode(#PB_2DDrawing_Gradient | #PB_2DDrawing_AlphaBlend)
			GradientColor(1.00, 0)
			GradientColor(0.90, col)
			GradientColor(0.35, 0)
			GradientColor(0.00, 0)
			CircularGradient(#SpriteSizeH, #SpriteSizeH, #SpriteSizeH)
			Circle(#SpriteSizeH, #SpriteSizeH, #SpriteSizeH)
			StopDrawing()
		EndIf
		
		SaveImage(i, filename, #PB_ImagePlugin_PNG)
		s = LoadSprite(#PB_Any, filename, #PB_Sprite_AlphaBlending)
	EndIf
	
	ProcedureReturn s
EndProcedure

Procedure Sprites_Create()
	Protected i, col
	Protected path.s = GetTemporaryDirectory()
	
	For i = 0 To 31
		Select (i % 3)
			Case 0: col = RGBA2(Random(185, 128), Random(128, 32), Random(128, 32))
			Case 1: col = RGBA2(Random(128, 32), Random(185, 128), Random(128, 32))
			Case 2: col = RGBA2(Random(128, 32), Random(128, 32), Random(185, 128))
		EndSelect
		Sprite(#Sprite_FirstSnake + i) = Sprite_Sphere(path + "snake_" + Str(i) + ".png", col, RGBA2(Red(col) * 0.5, Green(col) * 0.5, Blue(col) * 0.5))
		Sprite(#Sprite_Food + i) = Sprite_Food(path + "food_" + Str(i) + ".png", col)
		Sprite(#Sprite_SuperFood + i) = Sprite_Food(path + "superfood_" + Str(i) + ".png", col)
	Next	
	
	Sprite(#Sprite_Eye) = Sprite_Sphere(path + "eye.png", RGBA2(255,255,255), RGBA2(200,200,200))
	If IsSprite(Sprite(#Sprite_Eye))
		If StartDrawing(SpriteOutput(Sprite(#Sprite_Eye)))
			Circle(#SpriteSizeH, #SpriteSizeH * 1.25, #SpriteSizeH * 0.15, RGBA2(16, 16, 16))
			Circle(#SpriteSizeH * 0.95, #SpriteSizeH * 0.95, #SpriteSizeH * 0.1, RGBA2(255, 255, 255))
			StopDrawing()
		EndIf
	EndIf
	Sprite(#Sprite_EyeClosed) = Sprite_Sphere(path + "eyeclosed.png", RGBA2(150,150,150), RGBA2(100,100,100))
	
	Sprite(#Sprite_Egg) = Sprite_Egg(path + "egg.png")
	Sprite(#Sprite_Explosion) = Sprite_Explosion(path + "explosion.png", RGBA2(145,185,255))
	Sprite(#Sprite_Floor) = Sprite_Floor(GetTemporaryDirectory() + "floor.png")
EndProcedure

Procedure Food_Add(x.d, y.d, index)
	If x < 0 Or x >= #AreaWidth Or y < 0 Or y >= #AreaHeight
		ProcedureReturn #Null
	EndIf
	
	Protected fx = x / #FieldSize
	Protected fy = y / #FieldSize
	If fx >= 0 And fx < #FieldWidth And fy >= 0 And fy < #FieldHeight
		If MapSize(Field(fx, fy)\food()) < 9
			Protected *food.Body = AddElement(Food())
			If *food
				*food\x = x
				*food\y = y
				*food\index = index
				Field_Set(food, *food)
			EndIf
		EndIf
	EndIf
	
	ProcedureReturn *food
EndProcedure

Procedure Food_Remove(*food.Body)
	ChangeCurrentElement(Food(), *food)
	DeleteElement(Food())
EndProcedure

Procedure Food_RemoveRandom()
	Protected fx, fy
	Protected try, found = #False
	Protected *food.Body
	
	Repeat
		fx = Random(#FieldWidth - 1)
		fy = Random(#FieldHeight - 1)
		ForEach Field(fx, fy)\food()
			*food = Field(fx, fy)\food()
			If *food And *food\index <= #Sprite_FoodLast 
				Food_Remove(*food)
				DeleteMapElement(Field(fx, fy)\food())
				found = #True
			EndIf
		Next
		try + 1
	Until found Or try > 50
EndProcedure

Procedure Spark_Add(x, y, index)
	Protected n = Random(3, 1)
	
	While n > 0
		If AddElement(Spark())
			Spark()\x = x
			Spark()\y = y
			Spark()\angle = Rnd(0, #PI2)
			Spark()\speed = Rnd(5, 10)
			Spark()\sprite = Sprite(index)
		EndIf
		n - 1
	Wend	
EndProcedure

Procedure Snake_AddBody(*snake.Snake, x, y, index)
	If LastElement(*snake\body())
		x = *snake\body()\x
		y = *snake\body()\y
	EndIf
	
	Protected *body.Body = AddElement(*snake\body())
	If *body
		*body\x = x
		*body\y = y
		*body\index = index
		Field_Set(body, *body)
	EndIf
	
	ProcedureReturn *body
EndProcedure

Procedure Snake_Add(index, length = #StartLength, radius = #StartRadius, respawnTime = #RespawnTime)
	Protected *snake.Snake 
	Protected i, fx, fy, x, y, x1, y1, empty
	Protected try = 100, n = 1

	Repeat
		x = Rnd(radius * 10, #AreaWidth - radius * 10)
		y = Rnd(radius * 10, #AreaHeight - radius * 10)
		fx = x / #FieldSize * 1.0
		fy = y / #FieldSize * 1.0
		
		empty = #True
		For y1 = fy - n To fy + n
			If y1 >= 0 And y1 < #FieldHeight
				For x1 = fx - n To fx + n
					If x1 >= 0 And x1 < #FieldWidth
						ForEach Field(x1, y1)\body()
							If Field(x1, y1)\body()\index >= #Sprite_FirstSnake
								empty = #False
								Break
							EndIf
						Next
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
				\style = Random(31)
				\index = index
				\state = #Snake_Respwawning
				\angle = Radian(180)
				\direction = \angle
				\radius = radius
				\updateTime = #UpdateTime + 50
				\nextUpdateTime = #UpdateTime
				\nextTime = 0
				\respawnTime = Time + #RespawnTime
				
				For i = 1 To length
					Snake_AddBody(*snake, x, y, \index)
				Next
				
				*SnakeList(index) = *snake
			EndWith
			
		EndIf
	EndIf
	
	ProcedureReturn *snake
EndProcedure

Procedure Snake_Crash(*snake.Snake, size.d = 1.0)
	Protected x, y, dist
	
	Protected *player.Snake = *SnakeList(#Sprite_FirstSnake)
	If FirstElement(*snake\body())
		If AddElement(Explosion())
			Explosion()\x = *snake\body()\x
			Explosion()\y = *snake\body()\y
			Explosion()\time = (Time - 250) + #ExplosionTime * size
			
			If *snake = *player
				Sound_Play(#Sound_explosion1)
			ElseIf *player And FirstElement(*player\body())
				x = *snake\body()\x - *player\body()\x
				y = *snake\body()\y - *player\body()\y
				dist = Sqr(x * x + y * y)
				If dist < 1000
					Sound_Play(#Sound_explosion2, ((1000 - dist) / 1000.0) * 100)
				EndIf
			EndIf			
		EndIf
	EndIf
	
	*snake\state = #Snake_Crashed
EndProcedure

Procedure Snake_Kill(*snake.Snake)
	ForEach *snake\food()
		Field_Unset(food, *snake\food())
		Food_Remove(*snake\food())
	Next
	
	ForEach *snake\body()
		Field_Unset(body, *snake\body())
	Next
		
	ClearList(*snake\food())
	ClearList(*snake\body())
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
	Protected count, i, index
	Protected.Snake *snake, *collisionSnake
	Protected.Body *head, *body, *tail, *food
	Protected *field.FieldEntry
	Protected width = ScreenW
	Protected height = ScreenH
	
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
	
	
	If Random(25) = 0
		; randomly add food somewhere on the map
		i = 0
		While (ListSize(Food()) < FoodCountStart) And (i < 150)
			x = Rnd(#FoodRadius * 2, #AreaWidth - #FoodRadius * 2)
			y = Rnd(#FoodRadius * 2, #AreaHeight - #FoodRadius * 2)
			fx = x / #FieldSize
			fy = y / #FieldSize
			If MapSize(Field(fx, fy)\food()) < 5
				Food_Add(x, y, Random(#Sprite_FoodLast, #Sprite_Food))
			EndIf
			i + 1
		Wend
	EndIf
	
	If *SnakeList(#Sprite_FirstSnake) = 0
		Zoom + (DesktopScaledX(150) / (#StartRadius + 100) - Zoom) * 0.1
	EndIf
	
	ForEach Snake()
		*snake = @Snake()
		
		*head = FirstElement(*snake\body())
		If *head
			radius = Min(100, #StartRadius + *snake\score * 0.01)
			
			*snake\radius = radius
			
			If (*snake\index = #Sprite_FirstSnake) And (*snake\state <> #Snake_Crashed)
				If Zoom
 					ScrollX + ((width * 0.5 - *head\x * Zoom) / Zoom - ScrollX) * 0.25
 					ScrollY + ((height * 0.5 -*head\y * Zoom) / Zoom - ScrollY) * 0.25
				EndIf
				Zoom + (Max(0.001, DesktopScaledX(150) / (radius + 100)) - Zoom) * 0.25
			EndIf
		EndIf
				
		
		If *snake\state = #Snake_Respwawning
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
			
			i = 5
			While (i > 1) And FirstElement(*snake\body())
				
				If x > 0 And x < width And y > 0 And y < height
					Spark_Add(*snake\body()\x, *snake\body()\y, #Sprite_FirstSnake + SnakeStyle(*snake\style)\color)
				EndIf
				
				Food_Add(*snake\body()\x, *snake\body()\y, #Sprite_SuperFood + SnakeStyle(*snake\style)\color)
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
				
				If Time > *snake\nextTime
					*tail = LastElement(*snake\body())
					Field_Unset(body, *tail)
					
					MoveElement(*snake\body(), #PB_List_First)
					CopyStructure(*head, *tail, Body)
					
					Field_Set(body, *tail)
					
					*snake\nextTime = Time + *snake\updateTime - dTime
				EndIf
				
				*snake\delta = (1 - (*snake\nextTime - Time) / *snake\UpdateTime)
				*snake\updateTime + (*snake\nextUpdateTime - *snake\updateTime) * 0.1
				
				*head = FirstElement(*snake\body())
				*body = NextElement(*snake\body())
				Field_Unset(body, *head)
				
				dirX = Sin(*snake\angle) * #Speed * *snake\delta
				dirY = Cos(*snake\angle) * #Speed * *snake\delta
				*head\x = *body\x + dirX
				*head\y = *body\y + dirY
				Field_Set(body, *head)
				
				angle = AngleDifference(*snake\direction, *snake\angle) / (radius * 0.3) * #RotationSpeed * *snake\delta
				If angle < -#RotationSpeed
					angle = -#RotationSpeed
				ElseIf angle > #RotationSpeed
					angle = #RotationSpeed
				EndIf					
				*snake\angle = Mod(*snake\angle + angle + #PI2, #PI2)					
			EndIf
			
			*head = FirstElement(*snake\body())
			
			If *head And (*head\x < radius Or *head\x >= #AreaWidth - radius Or *head\y < radius Or *head\y >= #AreaHeight - radius)
				
				; snake crashed into border
				Snake_Crash(*snake)
				
			ElseIf *head And *snake\state = #Snake_Alive
				
				*tail = LastElement(*snake\body())
				If *tail				
					
					; the 'food sucking' animation
					ForEach *snake\food()
						*food = *snake\food()
						x = (*head\x + Sin(*snake\angle) * *snake\radius) - *food\x
						y = (*head\y + Cos(*snake\angle) * *snake\radius) - *food\y
						If Sqr(x * x + y * y) < *snake\radius + 10
							Food_Remove(*snake\food())
							DeleteElement(*snake\food())
						Else
							*food\x + (x * 0.2)
							*food\y + (y * 0.2)
						EndIf
					Next
					
					fx = *head\x / #FieldSize * 1.0
					fy = *head\y / #FieldSize * 1.0
					
					Protected fxa, fya
					Protected xd, yd, x1, y1, x2, y2
					
					Protected g = Max(2, radius * 2 / #FieldSize)
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
					
					Protected angleDif.d, nCollision, nFood, nSuperFood
					Protected.d collisionX, collisionY, foodX, foodY, foodMinDist
					
					nCollision = 0
					collisionX = 0
					collisionY = 0
					nFood = 0
					nSuperFood = 0
					foodX = 0
					foodY = 0
					foodMinDist = 999999
					
					If *head\x > #AreaWidth - radius * 5
						nCollision + 1
						collisionX + (*head\x + #AreaWidth) * 0.5
						collisionY + *head\y
					ElseIf *head\x < radius * 5
						nCollision + 1
						collisionX + *head\x * 0.5
						collisionY + *head\y
					EndIf
					
					If *head\y > #AreaHeight - radius * 5
						nCollision + 1
						collisionX + *head\x
						collisionY + (*head\y + #AreaHeight) * 0.5
					ElseIf *head\y < radius * 5
						nCollision + 1
						collisionX + *head\x
						collisionY + *head\y * 0.5
					EndIf
					
					For fya = y1 To y2
						For fxa = x1 To x2
							
							If fxa >= 0 And fxa < #FieldWidth And fya >= 0  And fya < #FieldHeight
								*field = @Field(fxa, fya)
								
								ForEach *field\food()
									*food = *field\food()
									
									dist = Distance(*head, *food)
									If dist < (radius + #FoodRadius + 50)
										
										If *food\index <= #Sprite_FoodLast
											*snake\scoreCount + #FoodScore
											If (*snake\index = #Sprite_FirstSnake)
												Sound_Play(#Sound_eat1)
											EndIf
										ElseIf *food\index <= #Sprite_SuperFoodLast
											nSuperFood + 1
											*snake\scoreCount + #SuperFoodScore
											If *snake\index = #Sprite_FirstSnake
												Sound_Play(#Sound_eat2)
											EndIf
										EndIf
										
										If ListSize(Food()) < FoodCountStart
											; randomly place more food on the map
											If Random(6) = 0
												x = #AreaWidth - *food\x
												y = #AreaHeight - *food\y
												Food_Add(x, y, Random(#Sprite_FoodLast, #Sprite_Food))
											ElseIf Random(2) = 0
												x = Rnd(#FoodRadius * 5, #AreaWidth - #FoodRadius * 5)
												y = Rnd(#FoodRadius * 5, #AreaHeight - #FoodRadius * 5)
												Food_Add(x, y, Random(#Sprite_FoodLast, #Sprite_Food))
											EndIf
										EndIf
										
										Field_Unset(food, *food)
										
 										x = (*head\x + ScrollX) * Zoom
 										y = (*head\y + ScrollY) * Zoom
										If x < 0 Or x > width Or y < 0 Or y > height
											; snake head is not visible - remove this food from the global food list
											Food_Remove(*food)
										Else
											; snake head is visible - add this food to the snakes food list
											; (for the 'food suck' animation)
											If AddElement(*snake\food())
												*snake\food() = *food
											EndIf
										EndIf
										
									ElseIf dist < foodMinDist
										
										foodMinDist = dist
										foodX = *food\x
										foodY = *food\y
										nFood + 1
										
									EndIf
								Next
								
								ForEach *field\body()
									*body = *field\body()
									If *body And (*body\index <> *head\index) ; <-  make sure that the snake is not colliding with itself

										*collisionSnake = *SnakeList(*body\index)										
										If *collisionSnake And (Distance(*head, *body) < (radius + *collisionSnake\radius))
											
											If *collisionSnake\state = #Snake_Respwawning
												Snake_Crash(*collisionSnake, 0.5)
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
							*snake\direction + AngleDifference(ATan2(*head\y - collisionY, *head\x - collisionX), *snake\direction) * 0.25
						ElseIf nFood
							*snake\direction + AngleDifference(ATan2(foodY - *head\y, foodX - *head\x), *snake\direction) * 0.25
							If nSuperFood > 1
								*snake\nextUpdateTime = #RaceTime
							EndIf
						Else
							*snake\direction + Rnd(-0.1, 0.1)
						EndIf
					EndIf
					
				EndIf
				
			EndIf
			
			If *snake\state = #Snake_Alive
; 				Snake_Kill(*snake)
; 			Else
				If (*snake\index = #Sprite_FirstSnake) And ((*snake\score + *snake\scoreCount) > BestScore)
					BestScore = *snake\score + *snake\scoreCount
				EndIf
				
				If (*snake\nextUpdateTime = #RaceTime) And (Time > *snake\shrinkTime) And (Random(2) = 0)
					; speeding snake -> release some food
					If LastElement(*snake\body())
						*snake\shrinkTime = Time + 50
						*snake\score = Max(0, *snake\score - 1)
						
						Food_Add(*snake\body()\x, *snake\body()\y, #Sprite_Food + SnakeStyle(*snake\style)\color)
						
						While LastElement(*snake\body()) And (ListSize(*snake\body()) > (#StartLength + *snake\score / 10))
							Field_Unset(body, *snake\body())
							DeleteElement(*snake\body())
						Wend
					EndIf
				Else
					count = *snake\scoreCount / #SuperFoodScore
					If count > 0
						*snake\scoreCount = 0
						*snake\score + count * #SuperFoodScore
						
						*tail = LastElement(*snake\body())
						*head = FirstElement(*snake\body())
						If *head
							For i = 1 To count
								Snake_AddBody(*snake, *tail\x, *tail\y, *snake\index)
							Next
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
	Next
EndProcedure

Procedure Game_Draw()
	Protected index, snakeNr
	Protected x.l, y.l, xo, yo
	Protected.d x1, y1, x2, y2
	Protected radius.d
	Protected fx, fy
	Protected.Body *head, *tail, *body, *previous, *fieldBody, *food
	Protected *field.FieldEntry
	Protected.d minX, minY, maxX, maxY
	Protected width = ScreenW
	Protected height = ScreenH
	Protected gridX.d = 500 * Zoom
	Protected gridY.d = gridX * 0.75
	Protected sprite, spriteW, spriteH
	Protected *player.Snake = *SnakeList(#Sprite_FirstSnake)
	Protected *snake.Snake
	Protected NewMap drawSnake()
	
	If FullScreen = #False
		width = DesktopScaledX(ScreenW)
		height = DesktopScaledY(ScreenH)
	EndIf
	
 	ClearScreen(RGB(0,0,0))
	
  	;SpriteQuality(#PB_Sprite_BilinearFiltering)
 	
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
 	
	Protected incr.d = #FieldSize
	
	minX = (width / Zoom) + #FieldSize
	minY = (height / Zoom) + #FieldSize
	y1 = -#FieldSize
	While y1 < minY
		fy = (y1 - ScrollY) / #FieldSize * 1.0
		If fy >= 0 And fy < #FieldHeight
			x1 = -#FieldSize
			While x1 < minX
				fx = (x1 - ScrollX) / #FieldSize * 1.0
				If fx >= 0 And fx < #FieldWidth
					*field = @Field(fx, fy)
					
					ForEach *field\body()
						*field\body()\isVisible = 1
						drawSnake(Str(*field\body()\index)) = *field\body()\index
					Next
					
					If (#FoodRadius * Zoom) > 5
						ForEach *field\food()
							*food = *field\food()
							sprite = 0
							
							If *food\index <= #Sprite_FoodLast
								sprite = Sprite(*food\index)
								radius = Max(#FoodRadius, #FoodRadius + Sin((*food + Time) * 0.004) * 10) * Zoom
							ElseIf *food\index <= #Sprite_SuperFoodLast
								sprite = Sprite(*food\index)
								radius = Max(#FoodRadius, #FoodRadius + Sin((*food + Time) * 0.004) * 10) * Zoom * 3
							EndIf
							
							If sprite
								x = Sin((*food + Time) * 0.0005) * radius * 0.2
								y = Cos((*food + Time) * 0.0005) * radius * 0.2
								
								ZoomSprite(sprite, radius, radius)
								DisplayTransparentSprite(sprite,
								                         (*food\x + ScrollX + x) * Zoom - radius * 0.5,
								                         (*food\y + ScrollY + y) * Zoom - radius * 0.5)
							EndIf
						Next
					EndIf
					
				EndIf
				x1 + incr
			Wend
		EndIf
		y1 + incr
	Wend
	
	
	ForEach drawSnake()
		; draw sucked in food
		*snake = *SnakeList(drawSnake())
		
		If *snake And (ListSize(*snake\body()) > 0)
			
			ForEach *snake\food()
				*food = *snake\food()
				radius = Max(#FoodRadius, #FoodRadius + Sin((*food + Time) * 0.004) * 5) * Zoom
				sprite = Sprite(*food\index)
				If sprite
					If *food\index >= #Sprite_SuperFood And *food\index <= #Sprite_SuperFoodLast
						radius * 3
					EndIf
					ZoomSprite(sprite, radius, radius)
					DisplayTransparentSprite(sprite,
					                         (*food\x + ScrollX) * Zoom - SpriteWidth(sprite) * 0.5,
					                         (*food\y + ScrollY) * Zoom - SpriteHeight(sprite) * 0.5)
				EndIf
			Next
			
			; draw the snake
			*head = FirstElement(*snake\body())
			index = Max(0, ListSize(*snake\body()) - 3)
			sprite = SnakeStyle(*snake\style)\sprite
			radius = *snake\radius * 2 * Zoom
			
			*previous = LastElement(*snake\body())
			While PreviousElement(*snake\body()) And ListIndex(*snake\body()) >= index
				*body = *snake\body()
				radius * 1.25
				ZoomSprite(SnakeStyle(*snake\style)\sprite, radius, radius)
				x = (*previous\x + (*body\x - *previous\x) * *snake\delta + ScrollX) * Zoom - radius * 0.5
				y = (*previous\y + (*body\y - *previous\y) * *snake\delta + ScrollY) * Zoom - radius * 0.5
				DisplayTransparentSprite(sprite, x, y)
				*previous = *body
			Wend

			If SelectElement(*snake\body(), index)
				Protected radius1.d = *snake\radius * 4 * Zoom
				Protected radius2.d = radius1 * 0.9
				
				radius = radius1
				
; 				radius = *snake\radius * 4 * Zoom
				
				ZoomSprite(Sprite(#Sprite_FirstSnake + *snake\index % 32), radius2, radius2)
				ZoomSprite(SnakeStyle(*snake\style)\sprite, radius1, radius1)
				
				*previous = #Null
				Repeat
					*body = *snake\body()
					If *previous And *body\isVisible
						If ListIndex(*snake\body()) % 5 = 1
							sprite = Sprite(#Sprite_FirstSnake + *snake\index % 32)
							radius = radius2
						Else
							sprite = SnakeStyle(*snake\style)\sprite
							radius = radius1
						EndIf
						
						If *body = *head
							x = (*body\x + ScrollX) * Zoom - radius * 0.5
							y = (*body\y + ScrollY) * Zoom - radius * 0.5
						Else
							x = (*previous\x + (*body\x - *previous\x) * *snake\delta + ScrollX) * Zoom - radius * 0.5
							y = (*previous\y + (*body\y - *previous\y) * *snake\delta + ScrollY) * Zoom - radius * 0.5
						EndIf
						
						DisplayTransparentSprite(sprite, x, y)
					EndIf
					*previous = *body
					*body\isVisible = 0
				Until PreviousElement(*snake\body()) = 0
			EndIf
			
			; draw snake eyes
			If *snake\state <> #Snake_Crashed
				*head = FirstElement(*snake\body())
				If *head
					*head = *snake\body()
					*tail = LastElement(*snake\body())
					
					If *snake\respawnTime
						radius = Zoom * ((*snake\radius * 5) + Sin(Time * 0.01) * 10) + 25
						x = (*tail\x + ScrollX) * Zoom - radius * 0.5
						y = (*tail\y + ScrollY) * Zoom - radius * 0.6
						ZoomSprite(Sprite(#Sprite_Egg), radius, radius)
						DisplayTransparentSprite(Sprite(#Sprite_Egg), x, y)
					EndIf
					
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
					RotateSprite(sprite,  -Degree(*snake\direction), #PB_Absolute)
					
					DisplayTransparentSprite(sprite,
					                         (x + Sin(*snake\angle - Radian(35)) * radius * 1.15) * Zoom,
					                         (y + Cos(*snake\angle - Radian(35)) * radius * 1.15) * Zoom)
					
					DisplayTransparentSprite(sprite,
					                         (x + Sin(*snake\angle + Radian(35)) * radius * 1.15) * Zoom,
					                         (y + Cos(*snake\angle + Radian(35)) * radius * 1.15) * Zoom)
				EndIf
			EndIf
			
		EndIf
	Next
	
 	ForEach Spark()
 		Spark()\speed * 0.9
 		If Spark()\speed < 1
 			DeleteElement(Spark())
 		Else
 			Spark()\x + Sin(Spark()\angle) * Spark()\speed
 			Spark()\y + Cos(Spark()\angle) * Spark()\speed
 			
 			sprite = Spark()\sprite
 			radius = Spark()\speed * 8
 			
 			x = (Spark()\x + ScrollX) * Zoom - radius
			y = (Spark()\y + ScrollY) * Zoom - radius
			
			ZoomSprite(sprite, radius, radius)
 			DisplayTransparentSprite(sprite, x, y)
 		EndIf
 	Next
 	
	ForEach Explosion()
		If Time > Explosion()\time
			DeleteElement(Explosion())
		Else
			radius = Pow(1 - (Explosion()\time - Time) / #ExplosionTime, 2)
			x = (Explosion()\x + ScrollX) * Zoom
			y = (Explosion()\y + ScrollY) * Zoom
			ZoomSprite(Sprite(#Sprite_Explosion), radius * 1000, radius * 1000)
			DisplayTransparentSprite(Sprite(#Sprite_Explosion), x - radius * 500, y - radius * 500, 255 - radius * 255)
		EndIf	
	Next
	
	; draw cursor if mouse moved
	If DrawCursor > Time
		If *SnakeList(#Sprite_FirstSnake)
			sprite = Sprite(#Sprite_SuperFood + *SnakeList(#Sprite_FirstSnake)\style)
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
			minX = (width / Zoom) + #FieldSize
			minY = (height / Zoom) + #FieldSize
			y1 = Mod(ScrollY, #FieldSize)
			While y1 < minY
				fy = (y1 - ScrollY) / #FieldSize * 1.0
				If fy >= 0 And fy < #FieldHeight
					x1 = Mod(ScrollX, #FieldSize)
					While x1 < minX
						fx = (x1 - ScrollX) / #FieldSize * 1.0
						If fx >= 0 And fx < #FieldWidth
							x = x1 * Zoom
							y = y1 * Zoom
							Box(x, y, #FieldSize * Zoom + 1, #FieldSize * Zoom + 1)
							DrawText(x + 2, y + 2, Str(MapSize(Field(fx, fy)\body())), RGB(255,255,0))
							DrawText(x + 2, y + 22, Str(MapSize(Field(fx, fy)\food())), RGB(0,255,255))
						EndIf
						x1 + #FieldSize
					Wend
				EndIf
				y1 + #FieldSize
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
			Next
			
		CompilerEndIf
		
		DrawingFont(FontID(0))
		DrawingMode(#PB_2DDrawing_Transparent)
		
		Protected text.s
		
		text = "FPS:  " + Str(FPS)
		DrawText(10, 10, text, RGB(128,128,128))
		
		text = "BEST: " + Str(BestScore)
		DrawText(DesktopScaledX(ScreenW - TextWidth(text) - 30), DesktopScaledY(30), text, RGB(255,255,128))
		
		If *player
			text = "SIZE: " + Str(*player\score + *player\scoreCount)
			DrawText(DesktopScaledX(ScreenW - TextWidth(text) - 30), DesktopScaledY(80), text, RGB(255,255,255))
		Else
			text = "- PRESS SPACE TO START -"
			DrawText(DesktopScaledX((ScreenW - TextWidth(text)) * 0.5),  DesktopScaledY((ScreenH - TextHeight(text)) * 0.5), text, RGB(128 + Sin(Time * 0.005) * 127,0,0))
		EndIf
		
		StopDrawing()
	EndIf
	
	FlipBuffers()
EndProcedure

Procedure Game_TestEvents()
	Protected event
	Protected *player.Snake
	Protected dx, dy, oldMouseX = MousePosX, oldMouseY = MousePosY
	Static NewMap KeyPressed.b()
	
	ExamineMouse()
	ExamineKeyboard()
	
	If KeyboardPushed(#PB_Key_Escape)
		End
	EndIf
	
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

	
	If KeyboardPushed(#PB_Key_Subtract)
		Zoom * 0.75
	EndIf

	*player = *SnakeList(#Sprite_FirstSnake)
	If *player = #Null
		If KeyboardPushed(#PB_Key_Space)
			Snake_Add(#Sprite_FirstSnake)
			Sound_Play(#Sound_respawn)
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
			LeftButton = 1
			*player\nextUpdateTime = #RaceTime
		ElseIf LeftButton
			LeftButton = 0
			*player\nextUpdateTime = #UpdateTime
		EndIf
		
		If KeyboardPushed(#PB_Key_LeftControl)
			If KeyPressed(Str(#PB_Key_LeftControl)) = 0
				KeyPressed(Str(#PB_Key_LeftControl)) = 1
				*player\nextUpdateTime = #RaceTime
			EndIf
		ElseIf KeyPressed(Str(#PB_Key_LeftControl))
			KeyPressed(Str(#PB_Key_LeftControl)) = 0
			*player\nextUpdateTime = #UpdateTime
		EndIf
		
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
	Protected x, y
	
	Dim *SnakeList(#MaxSnakes)
	ClearList(Food())
	ClearList(Snake())
	ClearList(Explosion())
	
	For y = 0 To #FieldHeight - 1
		For x = 0 To #FieldWidth - 1
			ClearMap(Field(x, y)\body())
			ClearMap(Field(x, y)\food())
		Next
	Next	
EndProcedure

Procedure Game_New()
	Protected i
	
	Game_Free()
	
	LoadFont(0, "Consolas", 24)
	Sounds_Load()
	Sprites_Create()
	
	Zoom = DesktopScaledX(150) / (#StartRadius + 100)
	
	For i = 0 To 31
		SnakeStyle(i)\sprite = Sprite(#Sprite_FirstSnake + i)
		SnakeStyle(i)\color = i
	Next
		
	For i = 1 To 50
 		Snake_Add(#Sprite_FirstSnake + i)
	Next	
	
	For i = 1 To (#FieldWidth * #FieldSize * #FieldHeight * #FieldSize) / 5000
		Food_Add(Rnd(#FoodRadius, #AreaWidth - #FoodRadius),
		         Rnd(#FoodRadius, #AreaHeight - #FoodRadius),
		         Random(#Sprite_FoodLast, #Sprite_Food))
	Next
	
	FoodCountStart = ListSize(Food())
	BestScore = 0
	
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
	If OpenWindowedScreen(WindowID(0), 0, 0, DesktopScaledX(ScreenW), DesktopScaledY(ScreenH)) = 0
		MessageRequester("", "Couldn't open screen")
		End
	EndIf
EndIf

Game_New()

SetFrameRate(30)

Repeat
	DeltaTime = ElapsedMilliseconds() - Time
	Time = ElapsedMilliseconds()
	
	Game_TestEvents()
	Game_Update(DeltaTime)
 
	Game_Draw()
	
 	Delay(5)
ForEver
; IDE Options = PureBasic 6.00 LTS (Windows - x64)
; CursorPosition = 1071
; FirstLine = 1063
; Folding = ------
; Optimizer
; EnableXP
; UseIcon = icon\SnakeZ.ico
; Executable = SnakeZ.exe
; DisableDebugger
; Compiler = PureBasic 6.00 LTS (Windows - x64)
; DisablePurifier = 1,1,1,1