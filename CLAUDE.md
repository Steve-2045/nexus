# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.4 game implementing a visual rock-paper-scissors simulation called "piedra_papel_tijera". The game features autonomous entities that move around the screen, collide with each other, and transform based on rock-paper-scissors rules.

## Architecture

### Core Game Logic
- **Main Scene**: `espacio/mundo.tscn` - Contains the game world with camera and entity instances
- **Character Scripts**: Three identical behavior scripts in `personajes/` directory:
  - `angry.gd` - Represents "Papel" (Paper) emotion
  - `happy.gd` - Represents "Piedra" (Rock) emotion  
  - `sad.gd` - Represents "Tijera" (Scissors) emotion

### Game Rules (Rock-Paper-Scissors)
- **Happy (Piedra/Rock)** beats **Sad (Tijera/Scissors)**
- **Sad (Tijera/Scissors)** beats **Angry (Papel/Paper)**
- **Angry (Papel/Paper)** beats **Happy (Piedra/Rock)**

### Entity Behavior System
Each character script extends `RigidBody2D` and implements:
- Constant velocity movement with screen boundary collision
- Collision detection and emotion transformation logic
- Dynamic sprite texture switching based on current emotion
- Physics-based bouncing with velocity maintenance

## Key Components

### Character Scripts Structure
All three scripts (`angry.gd`, `happy.gd`, `sad.gd`) share identical structure:
- `emotion_type` - String identifier ("angry", "happy", "sad")
- `speed_min/speed_max` - Configurable velocity range (150-250)
- `get_emotion_type()` - Returns current emotion type
- `change_to(new_type)` - Transforms entity to new emotion
- `process_collision(other_body)` - Handles game rule logic
- `maintain_constant_speed()` - Ensures consistent movement

### Asset Organization
- `sprites/` - Contains emotion face textures (PNG format)
- `personajes/` - Character scripts and scene files (.tscn)
- `espacio/` - World/level scenes

## Development Commands

### Running the Game
```bash
# Run from Godot Editor or
godot --path . espacio/mundo.tscn
```

### Project Structure
- Main scene: `espacio/mundo.tscn`
- Project config: `project.godot`
- Assets: All resources use Godot's `res://` path system

## Technical Notes

- Uses Godot 4.4 with "Forward Plus" rendering
- Physics system: RigidBody2D with disabled gravity and rotation lock
- Collision system: Contact monitoring with up to 10 contacts per body
- All entities maintain constant velocity (150-250 units) with normalized direction vectors
- Screen boundary detection uses viewport visible rect calculations