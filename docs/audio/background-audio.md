# Background Audio System Documentation

## Overview

The background audio system provides continuous atmospheric audio that loops indefinitely and persists across all scene changes. It is implemented as an autoload singleton using Godot's autoload system, ensuring the audio remains active regardless of which scene is currently loaded.

## What It Does

The background audio system:
- **Plays atmospheric audio automatically** when the game starts
- **Loops continuously** without interruption or gaps
- **Persists across scene changes** - the audio continues playing when loading new scenes
- **Runs independently** of any specific scene or game state
- **Is globally accessible** from any script in the project

### Key Components

1. **Scene File**: `res://scenes/atmosphere_audio_singleton.tscn`
   - Root node: `AtmosphereAudio` (Node type)
   - Child node: `AudioStreamPlayer` (handles audio playback)
   - Script: `res://scripts/atmosphere_loop.gd` (handles looping logic)

2. **Script File**: `res://scripts/atmosphere_loop.gd`
   - Manages audio playback and looping
   - Handles the `finished` signal to restart playback
   - Provides backup playback restart via `_process()`

3. **Audio Asset**: `res://assets/audio/atmospheres/atmosphere_1.wav`
   - Source audio file for atmospheric background audio
   - Imported with loop mode enabled (`loop_mode=1`)

4. **Configuration**: `project.godot` (autoload section)
   - Registered as autoload singleton with `*` prefix
   - Accessible globally as `AtmosphereAudio`

## Why This Implementation?

### Why Singleton/Autoload?

**Problem**: Regular scene nodes are destroyed when changing scenes, which would stop audio playback.

**Solution**: Using Godot's autoload singleton system ensures:
- **Persistence**: The node remains alive across scene changes
- **Global Access**: Can be accessed from any script without scene tree traversal
- **Single Instance**: Only one instance exists (singleton pattern)
- **Lifecycle Management**: Godot handles creation and cleanup automatically

### Why Separate Scene File?

**Separation of Concerns**: 
- Keeps audio system independent from game scenes
- Makes it easy to configure audio settings in the editor
- Allows for version control of audio configuration
- Enables visual inspection of audio node properties in the inspector

### Why Script-Based Looping?

**Redundancy and Reliability**:
- Import file loop mode may not always work reliably
- Script-based looping provides a fallback mechanism
- Signal-based restart (`finished` signal) is more efficient than polling
- Backup `_process()` check ensures audio never stops unintentionally

### Why Node + AudioStreamPlayer Structure?

**Flexibility**:
- Root Node provides a container for the script
- AudioStreamPlayer as child node allows inspector access to audio properties
- Enables future expansion (multiple audio players, fade effects, etc.)
- Script can reference the player via `@onready` for clean initialization

## How It Works

### Architecture Overview

```
project.godot (autoload configuration)
    └─> atmosphere_audio_singleton.tscn (singleton scene)
        └─> AtmosphereAudio (Node, root)
            ├─> Script: atmosphere_loop.gd
            └─> AudioStreamPlayer (child node)
                └─> Stream: atmosphere_1.wav
```

### Initialization Sequence

1. **Game Start**: Godot reads `project.godot` and identifies autoload singletons
2. **Scene Loading**: `atmosphere_audio_singleton.tscn` is loaded and instantiated
3. **Node Creation**: 
   - Root `AtmosphereAudio` Node is created
   - `AudioStreamPlayer` child node is created
   - Script `atmosphere_loop.gd` is attached to root node
4. **Script Execution**: `_ready()` is called:
   - `@onready` variable resolves to `$AudioStreamPlayer`
   - Stream is set to not paused
   - `finished` signal is connected to `_on_finished()` callback
5. **Audio Playback**: AudioStreamPlayer starts playback (autoplay=true)

### Looping Mechanism

The system uses a **multi-layered approach** to ensure continuous looping:

#### Layer 1: Import File Loop Mode
```
assets/audio/atmospheres/atmosphere_1.wav.import
edit/loop_mode=1  (LOOP_FORWARD)
```
- AudioStreamWAV resource has loop mode set to forward loop
- When loop mode works correctly, audio loops automatically
- The `finished` signal should NOT fire when loop mode works properly

#### Layer 2: Signal-Based Restart (Primary Backup)
```gdscript
audio_stream_player.finished.connect(_on_finished)

func _on_finished():
    if audio_stream_player:
        audio_stream_player.play()
```
- If the audio finishes (loop mode failed), `finished` signal fires
- Handler immediately calls `play()` to restart playback
- This creates seamless looping even if import loop mode doesn't work

#### Layer 3: Process-Based Check (Secondary Backup)
```gdscript
func _process(_delta: float) -> void:
    if audio_stream_player:
        if not audio_stream_player.playing and not audio_stream_player.stream_paused:
            audio_stream_player.play()
```
- Checks every frame if audio has stopped playing
- Only restarts if not paused (prevents interfering with manual pause)
- Provides ultimate fallback if signal-based restart fails

### Technical Details

#### Scene File Structure (`atmosphere_audio_singleton.tscn`)

```gd
[gd_scene load_steps=3 format=3 uid="uid://6fxquqxbfjf2"]

[ext_resource type="Script" uid="uid://d2mv7mcf3lt6k" path="res://scripts/atmosphere_loop.gd" id="1_script"]
[ext_resource type="AudioStream" uid="uid://bm1s1eonpquav" path="res://assets/audio/atmospheres/atmosphere_1.wav" id="2_atmosphere"]

[node name="AtmosphereAudio" type="Node"]
script = ExtResource("1_script")

[node name="AudioStreamPlayer" type="AudioStreamPlayer" parent="."]
stream = ExtResource("2_atmosphere")
volume_db = -8.587
autoplay = true
```

**What it does:**
- Defines a scene with 3 load steps (script, audio stream, scene structure)
- Root node is a simple Node (not AudioStreamPlayer) to allow script attachment
- AudioStreamPlayer is a child node for inspector access
- Autoplay is enabled to start playback immediately
- Volume is set to -8.587 dB (configurable in inspector)

**Why this structure:**
- Root Node allows script to be attached while keeping audio player accessible
- Child AudioStreamPlayer provides editor integration (inspector properties)
- External resources are referenced via UID for reliable loading

#### Script Implementation (`atmosphere_loop.gd`)

```gdscript
extends Node

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
    audio_stream_player.stream_paused = false
    audio_stream_player.finished.connect(_on_finished)

func _on_finished():
    if audio_stream_player:
        audio_stream_player.play()

func _process(_delta: float) -> void:
    if audio_stream_player:
        if not audio_stream_player.playing and not audio_stream_player.stream_paused:
            audio_stream_player.play()
```

**Key Features:**

1. **@onready Variable**:
   - `@onready` ensures the node path is resolved after the scene tree is ready
   - `$AudioStreamPlayer` uses shorthand node path syntax
   - Provides safe reference to the AudioStreamPlayer child node

2. **_ready() Function**:
   - Runs once when the node enters the scene tree
   - Explicitly sets `stream_paused = false` (defensive programming)
   - Connects the `finished` signal to restart handler

3. **_on_finished() Callback**:
   - Triggered when AudioStreamPlayer emits `finished` signal
   - Immediately restarts playback by calling `play()`
   - Includes null check for safety

4. **_process() Function**:
   - Runs every frame (60 FPS by default)
   - Checks if audio has stopped playing
   - Only restarts if not paused (respects manual pause state)
   - Provides final fallback for continuous playback

#### Autoload Configuration (`project.godot`)

```
[autoload]

AtmosphereAudio="*res://scenes/atmosphere_audio_singleton.tscn"
```

**What it does:**
- Registers the scene as an autoload singleton
- `*` prefix makes it a singleton (persists across scenes)
- Name `AtmosphereAudio` becomes the global access path

**How to access:**
- From any script: `AtmosphereAudio` (directly accessible)
- Example: `AtmosphereAudio.audio_stream_player.volume_db = -5.0`

**Why `*` prefix:**
- Without `*`: Scene is recreated each time (not what we want)
- With `*`: Scene persists across scene changes (singleton behavior)

#### Audio Import Settings (`atmosphere_1.wav.import`)

```
[params]
edit/loop_mode=1
edit/loop_begin=0
edit/loop_end=-1
```

**What it does:**
- `loop_mode=1`: Sets loop mode to LOOP_FORWARD
- `loop_begin=0`: Loop starts at the beginning
- `loop_end=-1`: Loop ends at the end of the file (full file loops)

**Loop Mode Values:**
- `0`: No loop (play once)
- `1`: Forward loop (loop from beginning to end)
- `2`: Ping-pong loop (forward then backward)

### Signal Flow

```
AudioStreamPlayer (playing)
    └─> [audio finishes]
        └─> emits finished signal
            └─> _on_finished() callback
                └─> audio_stream_player.play()
                    └─> [audio starts again]
                        └─> [cycle repeats]
```

### Scene Change Persistence

When a scene change occurs:

1. **Regular Scene Nodes**: All nodes in the current scene are freed
2. **Autoload Singletons**: Remain in the scene tree (in the root)
3. **AudioStreamPlayer**: Continues playing because it's in the singleton
4. **New Scene**: Loads and becomes current scene, singleton persists

This ensures audio never stops during scene transitions.

### Global Access Pattern

Since it's an autoload singleton, you can access it from any script:

```gdscript
# Get the audio player
var audio_player = AtmosphereAudio.audio_stream_player

# Adjust volume
AtmosphereAudio.audio_stream_player.volume_db = -5.0

# Check if playing
if AtmosphereAudio.audio_stream_player.playing:
    print("Audio is playing")

# Pause/unpause
AtmosphereAudio.audio_stream_player.stream_paused = true  # pause
AtmosphereAudio.audio_stream_player.stream_paused = false # resume
```

## Configuration

### Audio Settings (Inspector)

When you select the `AudioStreamPlayer` node in the inspector, you can adjust:

- **Stream**: The audio file being played
- **Volume dB**: Volume in decibels (default: -8.587 dB)
- **Pitch Scale**: Playback speed/pitch (1.0 = normal)
- **Autoplay**: Start playback automatically (enabled)
- **Stream Paused**: Manual pause state
- **Mix Target**: Audio output type (Stereo)
- **Bus**: Audio bus routing (Master)
- **Max Polyphony**: Maximum simultaneous playback instances

### Audio File Location

- **Path**: `res://assets/audio/atmospheres/atmosphere_1.wav`
- **Import Settings**: `res://assets/audio/atmospheres/atmosphere_1.wav.import`
- **Format**: WAV (uncompressed for low latency)
- **Import Settings**: Loop mode enabled, 44.1kHz sample rate

### Modifying Audio

To change the background audio:

1. Replace `atmosphere_1.wav` with your new audio file
2. Keep the same filename OR update the scene file to reference the new file
3. If changing filename, update the ExternalResource path in `atmosphere_audio_singleton.tscn`
4. Ensure the new audio file has loop mode enabled in import settings

## Troubleshooting

### Audio Not Playing

**Check:**
1. Autoload is configured correctly in `project.godot`
2. Audio file path is correct in scene file
3. Audio file exists at the specified path
4. `autoplay` is enabled on AudioStreamPlayer
5. `stream_paused` is false
6. Volume is not muted (check Master bus)

### Audio Not Looping

**Check:**
1. Import file has `loop_mode=1`
2. Script's `finished` signal is connected
3. `_on_finished()` callback is working (check console)
4. Audio file itself is valid

### Audio Stops on Scene Change

**Solution:**
- Ensure autoload uses `*` prefix in `project.godot`
- Without `*`, the scene is recreated on each scene change
- Verify the scene is listed in autoload section

### Audio Cuts Out or Gaps

**Possible Causes:**
- Audio file doesn't loop cleanly (check audio editing)
- `_process()` check is too slow (shouldn't happen at 60 FPS)
- System audio issues
- Audio buffer underrun (increase buffer size in project settings)

## Performance Considerations

### CPU Usage

- **Signal-Based Looping**: Minimal overhead (only fires when audio finishes)
- **Process-Based Check**: Runs every frame but is lightweight (boolean check)
- **Total Impact**: Negligible (audio playback is handled by audio thread)

### Memory Usage

- **Audio Stream**: Loaded into memory (size depends on audio file)
- **Nodes**: Minimal (Node + AudioStreamPlayer)
- **Script**: Negligible memory footprint

### Best Practices

1. **Keep audio files optimized**: Use appropriate sample rates (44.1kHz is standard)
2. **Avoid very short loops**: Can cause excessive signal firing
3. **Monitor audio bus settings**: Ensure Master bus volume is reasonable
4. **Test across scenes**: Verify audio persists correctly

## Extension Points

The current implementation can be extended for:

1. **Volume Control**: Add functions to fade in/out
2. **Multiple Tracks**: Support crossfading between different atmosphere tracks
3. **Scene-Specific Audio**: Switch tracks based on current scene
4. **User Preferences**: Save/load volume preferences
5. **Audio Effects**: Add reverb, filters, or other effects
6. **Dynamic Mixing**: Adjust volume based on game state

### Example Extension: Volume Control

```gdscript
# Add to atmosphere_loop.gd
func set_volume_db(db: float) -> void:
    if audio_stream_player:
        audio_stream_player.volume_db = db

func fade_volume(target_db: float, duration: float) -> void:
    # Implement fade using Tween node
    pass
```

## Summary

The background audio system provides reliable, persistent atmospheric audio through:
- **Autoload singleton** for scene persistence
- **Multi-layer looping** for reliability
- **Clean architecture** for maintainability
- **Editor integration** for easy configuration

It ensures continuous background audio regardless of scene changes, game state, or other factors, creating a seamless audio experience throughout the game.
