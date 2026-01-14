

# Dash Mechanic

## Troubleshooting

### Problem 

Before Fix: 
- There was an issue where when dashing, the user could change pos mid dash if they moved their cursor 
- Every frame in `_physics_process()` recalculated `mouse_direction` from the current mouse pos:
```gd
mouse_direction = (mouse_pos - global.position).normalized()
```
- During dashm line 90 use mouse_direction:
```
velocity = mouse_direction * dash speed
```
- Result: the dash direction updated every fram to point at cursor, so player curved to follow it

### Solution

1. Added `dash_direction` to store the direction when the dash starts
2. In `start_dash()`, capture the direction once:
```
dash_direction = mouse_direction.normalized()
```
3. During dash, use the stored `dash_direction`:
```
velocity = dash_direction * dash_speed
```

### Why it works
- `dash_direction` is set once when the dash begins and does not change during the dash
- `mouse_direction` still updates every frame, but the dash uses `dash_direction`, so it does not follow the cursor
- The dash moves in a straight line in the inital direction

Frame by Frame Example:
- Frame 1 (dash starts): Mouse at (100,0) -> `dash_direction = (1,0)` -> dash goes right
- Frame 2: Mouse moves to (0,100) -> `mouse_direction = (0,1)`, but dash still uses `dash_direction = (1,0)` -> continues right
- Frame 3: Mouse at (-50, 50) -> `mouse_direction` changes, but dash still uses `dash_direction = (1,0) -> continues right
- The cursor determines inital direction; dash direction is locked for the duration


# Extra Info

## `.normalized()`
- Is a Vector2 method in godot that returns a unit vector (length 1) pointing in the same direction

### What it does
- Keeps the direction 
- Sets the length to 1.0

### Why use it
Useful for direction vectors where you only need direction, not magnitude. For example:
- Moving at a constant speed in a direction
- Comparing directions
- Calculating angles


