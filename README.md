# Bloodthief TAS Mod Documentation
# Installation
1. Make sure you're on the latest version of the mod loader.
2. [Download the mod](https://github.com/Luna5829/bloodthief-tas-mod/archive/refs/heads/main.zip).
3. Either:
   - Extract the zip file and place the folder into `mods-unpacked`, or
   - Place the zip file directly into `mods`.
4. Launch the game and load any level
5. Open bloodthief settings -> Mods -> TAS mod
6. Modify the settings to your liking
    - TAS file path: `inputs.tas`
    - Keybinds path: `keybinds.json`
7. Press [the start keybind](#keybinds) to start the tas.
***
# Keybinds
- `[ (Left Bracket)`: Step forward one frame
- `] (Right Bracket)`: Resume from pause
- `\ (Backslash)`: Start TAS
- `; (Semicolon)`: Stop TAS
- `' (Apostrophe)`: Reload `inputs.tas` mid run (lets you make changes without having to restart)
***
# Syntax
## Basic Inputs
`duration,input1,input2,...`
Example:
```
1,F  # Hold forward for 1 frame
1,F,J  # Hold forward + jump for 1 frame
1  # Do nothing for 1 frame (lets go of both forward and jump, because they are no longer pressed)
100,F  # Hold forward for 100 frames
```
## Comments
Use `#` for comments:
```
# this is a comment
1,J # comment after input
```
## Functions
```
Func slam
    1,J
    2
    1,D
EndFunc

slam()
100
slam()
```
### Background functions
```
Func spamSlide
    1,S
    10
EndFunc

spamSlide,on
100,F
spamSlide,off
```
Note: These are not optimal timings. (Most of these aren't)
## Repeats
Repeat the inputs between `Repeat` and `EndRepeat` a set amount of times
```
Repeat, 10
    1,Q,P
    1
EndRepeat
```
## Camera Control
pitch: Vertical camera movement (up & down)
yaw: Horizontal camera movement (left & right)
`Camera,pitch,yaw` - Set camera
`CameraRel,pitch,yaw` - Relative camera move
`duration,CameraSmooth,pitch,yaw` - Smooth move (relative)
## Joystick
```
duration,Joystick,angle
```
0-360°, Decimals allowed.
## Logging
`print` = `log` (identical)
allowed aliases: `position`/`pos`, `velocity`/`vel`
```
print,player position: ,pos
log,player velocity: ,velocity
```
## Other
`pause` - Pauses the game
`tickrate,90` or `tickrate,60` - set tickrate
***
# Notes
- For better determinism launch the game with `bloodthief.exe --fixed-fps 90`
- Whitespace flexibility:
    - `1, J` = `1,J`
    - `cameraRel 1 0` = `cameraRel,1,0`
- All syntax is case-insensitive. `CaMeRaRel,1,0` = `cameraRel,1,0`
- keybinds in keybinds.json don't have to be just one letter
- TAS disables all inputs unless you modify playback.gd (4th line -> `true`)
- Report issues or bugs to *@emma.5829*
***
# VSCode Syntax Highlighting
[Extension download](https://github.com/Luna5829/bloodthief-tas-mod/releases/download/v1.1.0/bloodtas-1.1.0.vsix)
Alternatives: AHK v1, CSV, essentially anything without a language server
