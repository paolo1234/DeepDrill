# Deep Drill — GDD Part 2: Implementation Tasks

## 15. Project Structure

```
res://
├── project.godot
├── scenes/
│   ├── main_menu.tscn
│   ├── game.tscn
│   ├── game_over.tscn
│   ├── upgrade_shop.tscn
│   └── permanent_shop.tscn
├── scripts/
│   ├── autoloads/
│   │   ├── game_manager.gd       # Global state, score, coins
│   │   ├── ad_manager.gd         # Ad hooks stub
│   │   └── save_manager.gd       # Persistent data
│   ├── drill.gd                  # Player controller
│   ├── block.gd                  # Block resource/data
│   ├── grid_manager.gd           # Procedural grid generation
│   ├── heat_system.gd            # Heat logic
│   ├── wear_system.gd            # Durability logic
│   ├── upgrade_manager.gd        # Run upgrades
│   └── ui/
│       ├── hud.gd
│       ├── heat_bar.gd
│       ├── durability_bar.gd
│       ├── game_over_ui.gd
│       ├── upgrade_shop_ui.gd
│       └── main_menu_ui.gd
├── assets/
│   ├── sprites/
│   │   ├── drill.png (48×64, 4 frames)
│   │   ├── blocks.png (32×32 atlas, 7 types × 4 break frames)
│   │   └── particles/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/
│       └── main_font.tres
└── resources/
    ├── block_data.tres
    └── upgrade_data.tres
```

---

## 16. Scene Tree Architecture

### 16.1 Game Scene (`game.tscn`)
```
Game (Node2D)
├── Background (ParallaxBackground)
│   └── ParallaxLayer
│       └── ColorRect
├── GridManager (Node2D)
│   └── [BlockRows generated at runtime]
├── Drill (CharacterBody2D)
│   ├── DrillSprite (AnimatedSprite2D)
│   ├── CollisionShape2D
│   ├── DrillParticles (GPUParticles2D)
│   ├── HeatSystem (Node) — script: heat_system.gd
│   └── WearSystem (Node) — script: wear_system.gd
├── Camera2D (follows drill Y)
├── CanvasLayer (UI)
│   ├── HUD (Control)
│   │   ├── TopBar (HBoxContainer)
│   │   │   ├── DepthLabel
│   │   │   └── CoinLabel
│   │   ├── HeatBar (TextureProgressBar)
│   │   ├── DurabilityBar (TextureProgressBar)
│   │   └── CoolDownAdButton (TextureButton)
│   └── HeatOverlay (ColorRect, red vignette)
└── AudioManager (Node)
    ├── DrillSFX (AudioStreamPlayer)
    ├── CollectSFX (AudioStreamPlayer)
    └── BGM (AudioStreamPlayer)
```

---

## 17. Implementation Tasks

### Phase 1: Foundation (Tasks 1-6)

#### Task 1 — Project Setup
- Create new Godot 4.6 project "DeepDrill" in `c:\Users\calam\Documents\Games\DeepDrill\`
- Set display: 1080×1920, portrait, stretch mode `canvas_items`, aspect `keep_width`
- Create all directories from project structure
- Register autoloads: GameManager, AdManager, SaveManager
- Set background color to `#1a1a2e`

#### Task 2 — Block System
- Create `block.gd` as a Resource class with: `type: BlockType`, `hardness`, `heat_value`, `wear_value`, `coin_value`, `color`
- Define `BlockType` enum: EMPTY, DIRT, STONE, GRANITE, GOLD, DIAMOND, LAVA
- Create block data dictionary with all values from GDD table
- Generate placeholder block sprites (32×32 colored rects with procedural textures via `_draw()`)
- Implement break animation: scale tween 1.0→0.0 over 0.15s + spawn 4 particle dots

#### Task 3 — Grid Manager
- Create `grid_manager.gd` extending Node2D
- Implement chunk-based generation (10 rows per chunk)
- Grid: 7 columns, rows scroll upward as drill descends
- Implement `generate_row(depth, rng)` with tier-based weight tables
- Path guarantee: min 2 soft/empty blocks per row, no fully blocked rows
- Object pooling: reuse block nodes, max 30 rows active
- Gold/diamond cluster every 5 rows guaranteed

#### Task 4 — Drill Controller
- Create `drill.gd` extending CharacterBody2D
- Auto-descend at `speed` px/s
- Touch input: left half screen → move left, right half → move right
- Keyboard fallback: A/D or Left/Right arrows
- Clamp to grid bounds (columns 0-6)
- Smooth horizontal lerp: `lerp(pos.x, target, 10 * delta)`
- Collision with blocks: call `drill_block(block)` on contact
- Drill animation: 4-frame rotation loop

#### Task 5 — Heat System
- Create `heat_system.gd`
- Properties: `heat`, `max_heat=100`, `cooling_rate=2.0`
- `add_heat(value, depth)`: apply formula with depth scaling and upgrade reduction
- `_process(delta)`: passive cooling
- Signals: `heat_changed(value, max)`, `overheated()`
- At 80%: emit `heat_warning()` signal

#### Task 6 — Wear System
- Create `wear_system.gd`
- Properties: `durability=100`, `max_durability=100`
- `add_wear(value, depth)`: apply formula with depth scaling and upgrade reduction
- Signal: `durability_changed(value, max)`, `drill_broken()`

---

### Phase 2: Gameplay (Tasks 7-11)

#### Task 7 — Camera & Scrolling
- Camera2D follows drill Y position with slight offset (drill at 30% from bottom)
- Smooth follow: `camera.position.y = lerp(camera.position.y, drill.position.y - offset, 5 * delta)`
- Grid manager listens to camera position: generate new chunks below, free chunks above

#### Task 8 — Block Interaction
- When drill overlaps a block cell:
  1. Get block type from grid
  2. `heat_system.add_heat(block.heat_value, depth)`
  3. `wear_system.add_wear(block.wear_value, depth)`
  4. `GameManager.add_coins(block.coin_value * coin_multiplier)`
  5. Play appropriate SFX
  6. Trigger block break animation
  7. Remove block from grid (set to EMPTY)
- Speed reduction when drilling hard blocks: `speed *= 1.0 / block.hardness` temporarily

#### Task 9 — Depth & Scoring
- `depth = drill.position.y / pixels_per_meter` (1 meter = 32px)
- `GameManager.depth` updated each frame
- `GameManager.best_depth` persisted via SaveManager
- Depth milestones trigger upgrade shop

#### Task 10 — Difficulty Scaling
- Every frame, update: `speed = base_speed * (1 + depth/1000)`
- Heat multiplier: `1 + depth/500`
- Wear multiplier: `1 + depth/800`
- Tier transitions change background color with tween (2s)

#### Task 11 — Game Over
- Triggered by `overheated` or `drill_broken` signal
- Freeze gameplay, show game over UI overlay
- Display: depth, coins earned, best depth
- Show "Continue (Ad)", "Double Loot (Ad)", "Restart" buttons
- `AdManager.show_interstitial()` every 3rd game over

---

### Phase 3: Upgrades & Economy (Tasks 12-14)

#### Task 12 — Run Upgrade System
- Create `upgrade_manager.gd`
- Store current run upgrades as Dictionary: `{upgrade_id: level}`
- 8 upgrade types with effects, max levels, costs from GDD
- `apply_upgrade(id)`: increment level, deduct coins
- `get_heat_reduction()`, `get_cooling_bonus()`, `get_wear_reduction()`, `get_coin_multiplier()`

#### Task 13 — Upgrade Shop UI
- Pause game at 100m intervals
- Show 3 random upgrades: 1 free pick + 2 purchasable
- Card layout: icon, name, level, effect description, cost/FREE
- "Continue Drilling" button resumes game
- Animate cards sliding in from bottom

#### Task 14 — Permanent Shop & Save System
- `save_manager.gd`: save/load via `FileAccess` to `user://save.json`
- Persist: `total_coins`, `best_depth`, `permanent_upgrades`, `settings`
- Permanent shop: 5 upgrades (from GDD table), costs deducted from total coins
- Apply permanent upgrades at run start

---

### Phase 4: UI & Polish (Tasks 15-19)

#### Task 15 — HUD Implementation
- TopBar: DepthLabel (left), CoinLabel (right) — font size 36, white, shadow
- HeatBar: TextureProgressBar, gradient fill green→red, 80% triggers pulse anim
- DurabilityBar: TextureProgressBar, blue fill, shows crack overlay when low
- CoolDownAdButton: only visible when heat > 70%, pulsing glow animation

#### Task 16 — Main Menu
- Title "DEEP DRILL" with metallic gradient text
- Animated drill graphic
- Buttons: Start, Permanent Shop, Settings
- Display best depth and total coins
- Background: slowly scrolling dark terrain

#### Task 17 — Game Over UI
- Overlay with semi-transparent dark background
- Death reason: "OVERHEATED" or "DRILL BROKEN"
- Stats panel with depth, coins, best depth
- "NEW RECORD" animation if best depth beaten
- Ad buttons with clear icons and labels
- Restart/Menu buttons

#### Task 18 — Visual Effects
- Block break particles (GPUParticles2D per block type color)
- Drill spark trail (continuous GPUParticles2D)
- Heat vignette: ColorRect with radial gradient, modulate alpha by heat%
- Screen shake: `camera.offset = random_vector * shake_intensity`
- Speed lines: Line2D nodes on sides when speed > 150%
- Background parallax layers (3 layers, different speeds)
- Tier transition: smooth color tween on background

#### Task 19 — Audio Integration
- Procedural SFX using AudioStreamPlayer with pitch variation
- Drill sounds: vary pitch by block hardness
- Collect chime: pitch up for gold, sparkle for diamond
- Warning beep loop at 80% heat
- Background music: looping ambient track
- Volume control in settings

---

### Phase 5: Monetization & Final (Tasks 20-22)

#### Task 20 — Ad Manager Integration
- Implement `AdManager` singleton (from GDD code)
- Hook into HUD CoolDownAdButton: `on_cool_down_pressed()`
- Hook into GameOver UI: continue button, double loot button
- Interstitial counter on game over
- Banner placeholder at bottom during gameplay
- All ad calls are stubs that `print()` and call success callback
- Document integration points for AdMob/IronSource plugin

#### Task 21 — Sprite Generation
- Generate all sprites programmatically using `_draw()` or Image class:
  - Dirt: brown base + small dot texture
  - Stone: gray base + crack lines
  - Granite: dark gray + diagonal lines
  - Gold: yellow base + sparkle dots
  - Diamond: cyan base + star shape
  - Lava: orange-red base + animated bubble overlay
  - Drill: metallic body + rotating bit + exhaust
- Create AnimatedSprite2D with SpriteFrames for drill (4 frames)
- All sprites are code-generated, no external assets needed

#### Task 22 — Final Polish & Testing
- Test all depth tiers (0-1000m+)
- Verify upgrade formulas balance correctly
- Test game over conditions (heat and wear)
- Test ad hooks trigger at correct moments
- Verify save/load persistence
- Test touch input on mobile viewport
- Profile performance: target 60fps with 30 active rows
- Test edge cases: rapid column switching, simultaneous heat+wear game over

---

## 18. Key Implementation Notes

### Input Mapping (project.godot)
```
[input]
move_left = [Key A, Key Left, TouchScreenButton left_half]
move_right = [Key D, Key Right, TouchScreenButton right_half]
```

### Autoload Registration Order
1. `GameManager` — global state
2. `SaveManager` — persistence
3. `AdManager` — monetization hooks

### Performance Targets
- 60 FPS on mid-range mobile
- Max 30 active block rows (210 blocks)
- Object pooling for blocks and particles
- No `_process` on inactive/off-screen nodes

### Color Palette
```
Background:    #1a1a2e (deep navy)
UI Dark:       #16213e
UI Accent:     #0f3460
Highlight:      #e94560 (red/danger)
Gold:          #ffd700
Diamond:       #00ffff
Text:          #ffffff
Text Shadow:   #000000aa
```
