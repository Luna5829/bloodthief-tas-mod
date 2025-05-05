# Bloodthief TAS Mod Documentation
# Installation
0. make sure you're on the latest version of the mod loader
1. [download](https://github.com/Luna5829/bloodthief-tas-mod/archive/refs/heads/main.zip) the TAS mod
2. either extract the zip file and move the folder inside into `mods-unpacked` or just put the zip file into `mods`
3. open the game
4. after the game is open load up a level
5. open the bloodthief settings, then navigate to the settings of the mod
6. click the 4 buttons and set each individual thing, TAS file path is the inputs.tas, keybinds file path is the keybinds.json
7. press [the keybind](#keybinds) to start the tas (the inputs file provided in the zip moves forwards at ~20 speed using "precise" joystick inputs to zigzag perfectly)
***
# Keybinds
- `[ (Left Bracket)`: advances a single frame (pauses if not already paused).
- `] (Right Bracket)`: resumes the game from a paused state
- `\ (Backslash)`: starts the TAS
- `; (Semicolon)`: stops the TAS
- `' (Apostrophe)`: refreshes the inputs.tas file (which lets you make changes while it's paused without having to replay everything)
***
# Syntax
## Basic Inputs
basic inputs are in the format `duration,inputs`
ex.
```lua
1,F
1,F,J
1
100,F
```
will hold forwards for 1 frame, then will hold forwards and jump (forwards is being continuously held for both frames), then it will wait 1 frame, then it will hold forwards for 100 frames
frames are determined by your tickrate, so 90 tickrate = 90 frames in 1 second

comments are done using the # symbol
this can be done either in it's own line or on a line with inputs
ex.
```lua
# comment on empty line
1,J # comment on regular line
```
## Functions
assings a name to some list of inputs
ex.
```lua
Func slam
    1,J
    2
    1,D
EndFunc
slam()
100
slam()
```
will slam, wait 100 frames, and slam again
functions, as you can see, are called via func_name()
but functions can also be enabled as background functions
ex.
```lua
Func spamSlide
    1,S
    10
EndFunc
spamSlide,on
100,F
spamSlide,off
```
will spam slide while going forwards for 100 frames
note: these are not optimal slam slide timings, they're just for example
## Repetition
repeats the inputs between `Repeat` and `EndRepeat` several times
ex.
```lua
Repeat, 10
1,Q,P
1
EndRepeat
```
will shoot and parry 10 times in a row
## Camera Control
note: "pitch" and "yaw" are the 2 numbers you can see in the mod's info hud under "camera"
pitch is vertical camera movement (up & down), yaw is horizontal camera movement (left & right)
`Camera,pitch,yaw` - moves the camera's absolute position to the provided pitch and yaw
`CameraRel,pitch,yaw` - moves the camera relatively by the provided pitch and yaw (ex. CameraRel,10,0 adds +10 to the camera's pitch)
`duration,CameraSmooth,pitch,yaw` - moves the camera smoothly (also relative) (ex. 10,CameraSmooth,10,0 will move +10 pitch over 10 frames)
## Joystick Inputs
`duration,Joystick,angle` - sends a joystick input that lasts for `duration` at the angle of `angle`
angle goes clockwise starting from where you are facing, and the range is 0-360 (0 = 360)
it also supports decimals (as you can see in the test file provided)
## Extra Stuff
in logging, `print` and `log` do the same thing
you can also print position and velocity in their own arguments
ex.
```lua
print,position:,pos,\n,velocity:,velocity
log,position:,position,\n,velocity:,vel
```
both of these lines do the exact same thing, which is they print position: (x, y, z)\nvelocity: (x, y, z) (the \n is a literal new line)

you can pause the game via `pause` on it's own line
to resume the TAS you can either press the resume key, or start frame advancing

you can set the tickrate via `tickrate,90` or `tickrate,60` on it's own line
any values other than 90 and 60 won't work

you can do any of these in functions, or repeat blocks, even with nesting, it **should** work, and if it doesn't ping me (@emma.5829)
***
# Extra Notes (this is also important pls read it as well)
- to make the tas more deterministic put bloodthief on an SSD and launch the game using `bloodthief.exe --fixed-fps 90`
- `, ` works as well as `,`, so you can do `1, J` as well as `1,J` and it'll essentially be the same thing
- every single thing is case insensitive, that means `CaMeRaReL,1,0` is just as valid as `CameraRel,1,0` (but for everyone's sake, just don't)
- any commas can be replaced with spaces (as long as you replace every single comma on the same line), so `CameraRel 1 0` works the same as `CameraRel,1,0`, but `CameraRel 1,0` will not work
- the keys in keybinds.json don't have to be one letter, so you can do "jump": "jump" if you really want to, and then you'd have to do 1,Jump
- the inputs in keybinds.json don't have to only have one mapping either, so you can map multiple letters to the same action if you really want to
- if anything doesnt work or you get errors in the console please send the exact issue/error and ping me (@emma.5829)
- inputs are disabled while a TAS is playing, if you want inputs to not be disabled you can edit "playback.gd" and change the 4th line variable equal to true
***
[vscode .tas syntax highlighting extension](https://github.com/Luna5829/bloodthief-tas-mod/releases/download/v1.1.0/bloodtas-1.1.0.vsix)
alternatively you can use something with similar syntax (and no language server), like ahk v1 or csv (but it won't look as good)
