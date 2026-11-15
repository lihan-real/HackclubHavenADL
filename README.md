# BounceBackHaven

A Pong game made in Godot for Hack Club Haven.

## Controls

| Key | Action |
| --- | --- |
| W / Up Arrow | Move paddle up |
| S / Down Arrow | Move paddle down |

## Features

- Smooth paddle movement that speeds up and slows down
- Paddle stays on the screen
- Glowing trail behind the paddle when it moves fast
- Paddle flashes white when it hits the ball
- Choose the left or right side of the screen in the Inspector

## How to run

1. Install [Godot 4](https://godotengine.org/download)
2. Clone this repo
3. Open Godot, click Import, and select `project.godot`
4. Press F5 to play

## Project files

- `project.godot`: project settings and input controls
- `node_2d.tscn`: main scene
- `player.tscn`: the paddle scene
- `player.gd`: paddle script
- `Resume.png`: image used for the paddle

## Settings

Click the player node in Godot to change these in the Inspector:

- **Side:** left or right
- **Edge Margin:** gap between the paddle and the screen edge
- **Paddle Size:** width and height
- **Max Speed, Acceleration, Friction:** how the paddle feels
- **Trail Color:** color of the glow trail

## Status

- [x] Player paddle
- [ ] Ball
- [ ] Second paddle
- [ ] Scoring
