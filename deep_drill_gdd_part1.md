# Deep Drill — Game Design Document (Part 1/2)

> Endless procedural drilling game — Godot 4.6 — Portrait Mobile

---

## 1. Concept

**Genre:** Endless vertical scroller / resource collector  
**Platform:** Mobile (portrait 1080×1920)  
**Engine:** Godot 4.6.2  
**Input:** Swipe / touch-hold left-right  
**Goal:** Drill as deep as possible, collect resources, avoid game over from overheating or drill breakage.

---

## 2. Game Loop

```
START → Drill auto-descends → Player steers L/R → Hit blocks →
  → Collect resources / take heat+wear →
  → Spend coins on upgrades between depths →
  → Overheated or Broken? → Game Over → Show score + ad hooks → Restart
```

### 2.1 Core Flow
1. Drill starts at surface, auto-moves DOWN at `base_speed`
2. Player taps/holds LEFT or RIGHT to steer horizontally
3. Grid of blocks scrolls upward as drill descends
4. Drilling a block: adds resources, adds heat, adds wear
5. Heat & wear increase with depth and block hardness
6. Player can buy upgrades at milestone depths (every 100m)
7. Game ends when `heat >= max_heat` OR `durability <= 0`

---

## 3. Block System

### 3.1 Block Types

| Block | Color | Hardness | Heat | Wear | Coins | Spawn% (0-100m) | Spawn% (500m+) |
|-------|-------|----------|------|------|-------|------------------|-----------------|
| Dirt | `#8B6914` | 1 | 1 | 1 | 1 | 60% | 20% |
| Stone | `#808080` | 3 | 3 | 2 | 3 | 25% | 30% |
| Granite | `#4A4A4A` | 5 | 5 | 4 | 5 | 10% | 25% |
| Gold | `#FFD700` | 2 | 2 | 1 | 15 | 4% | 12% |
| Diamond | `#00FFFF` | 4 | 6 | 3 | 50 | 1% | 8% |
| Lava | `#FF4500` | 0 | 25 | 0 | 0 | 0% | 5% |
| Empty | transparent | 0 | 0 | 0 | 0 | — | — |

### 3.2 Block Sprites (32×32 px)
Each block is a 32×32 pixel sprite with:
- **Base fill** color from table above
- **4-pixel dark border** for depth
- **Texture overlay**: cracks (stone/granite), sparkles (gold/diamond), bubbles (lava)
- **Break animation**: 4 frames, particles flying outward

### 3.3 Grid Layout
- Grid width: **7 columns** (each 32px × scale to fit screen)
- Visible rows: **20 rows** on screen
- Buffer: **10 rows** generated below viewport
- Generation: rows generated procedurally as drill descends

---

## 4. Drill (Player)

### 4.1 Properties
```
position: Vector2          # grid-aligned X, continuous Y
speed: float = 60.0        # pixels/sec, increases with depth
horizontal_speed: float = 200.0
heat: float = 0.0          # 0 to max_heat
max_heat: float = 100.0
durability: float = 100.0  # 0 to max_durability  
max_durability: float = 100.0
cooling_rate: float = 2.0  # heat lost per second passively
coins: int = 0
depth: float = 0.0         # meters drilled (score)
```

### 4.2 Sprite
- **Size:** 48×64 px
- **States:** idle, drilling, overheating (red glow), damaged (sparks)
- **Animation:** drill bit rotation (4 frames, 0.1s each)
- **Trail:** particle effect behind drill showing sparks

### 4.3 Movement
- Auto-descend at `speed` (increases +5% every 50m)
- Horizontal: touch left half → move left, right half → move right
- Clamped to grid boundaries (columns 0-6)
- Smooth lerp between columns: `position.x = lerp(position.x, target_col * col_width, 10 * delta)`

---

## 5. Heat System

### 5.1 Mechanics
- Each block drilled adds `block.heat_value` to `drill.heat`
- Passive cooling: `-cooling_rate * delta` per frame
- If `heat >= max_heat` → **OVERHEAT** → game over
- Visual: heat bar changes color green→yellow→orange→red
- At 80% heat: screen edges glow red, drill shakes

### 5.2 Heat Formula
```
heat_gain = block.heat * (1 + depth/500) * (1 - heat_resist_upgrade * 0.1)
cooling = cooling_rate * (1 + cooling_upgrade * 0.15) * delta
heat = clamp(heat + heat_gain - cooling, 0, max_heat)
```

---

## 6. Wear / Durability System

### 6.1 Mechanics
- Each block drilled reduces `durability` by `block.wear_value`
- If `durability <= 0` → **DRILL BROKEN** → game over
- No passive repair (only via upgrades or pickups)
- Visual: durability bar, drill sprite gets progressively cracked

### 6.2 Wear Formula
```
wear = block.wear * (1 + depth/800) * (1 - armor_upgrade * 0.12)
durability = clamp(durability - wear, 0, max_durability)
```

---

## 7. Upgrade System

### 7.1 Upgrade Shop
Opens every **100m** depth. Pause game, show 3 random upgrades to pick ONE (free). Additional upgrades cost coins.

### 7.2 Upgrade List

| Upgrade | Max Lvl | Effect | Cost (base) | Cost scaling |
|---------|---------|--------|-------------|--------------|
| Heat Shield | 5 | -10% heat per block per lvl | 50 | ×1.8 |
| Cooling Fan | 5 | +15% cooling rate per lvl | 40 | ×1.6 |
| Reinforced Bit | 5 | -12% wear per block per lvl | 60 | ×2.0 |
| Speed Boost | 3 | +10% drill speed per lvl | 30 | ×1.5 |
| Coin Magnet | 3 | +20% coin value per lvl | 45 | ×1.7 |
| Deep Scanner | 3 | Shows blocks 5 rows ahead per lvl | 80 | ×2.0 |
| Emergency Repair | 2 | Restores 30 durability | 100 | ×2.5 |
| Heat Vent | 2 | Instantly removes 40 heat | 80 | ×2.0 |

### 7.3 Upgrade Cost Formula
```
cost = base_cost * (cost_scaling ^ current_level)
```

---

## 8. Monetization (Ad Hooks)

### 8.1 Instant Cooling (Rewarded Ad)
- **Trigger:** Heat bar reaches 70%+, pulsing "COOL DOWN" button appears
- **Action:** Watch 30s rewarded ad
- **Reward:** Heat reset to 0, +5s invulnerability to heat
- **Cooldown:** Once per run
- **Implementation:** `AdManager.show_rewarded("instant_cool", callback)`

### 8.2 Double Loot (Rewarded Ad)  
- **Trigger:** Game Over screen
- **Action:** Watch 30s rewarded ad
- **Reward:** All coins earned in run are doubled
- **Limit:** Once per game over
- **Implementation:** `AdManager.show_rewarded("double_loot", callback)`

### 8.3 Continue Run (Rewarded Ad)
- **Trigger:** Game Over screen
- **Action:** Watch 30s rewarded ad
- **Reward:** Revive with 50% heat reset, 30 durability restored
- **Limit:** Once per run
- **Implementation:** `AdManager.show_rewarded("continue_run", callback)`

### 8.4 Banner Ad
- **Position:** Bottom 50px of screen (always visible during gameplay)
- **Type:** Adaptive banner
- **Implementation:** `AdManager.show_banner()`

### 8.5 Interstitial Ad
- **Trigger:** Every 3rd game over
- **Implementation:** `AdManager.show_interstitial()`

### 8.6 AdManager Singleton Pattern
```gdscript
# res://scripts/ad_manager.gd
extends Node

signal ad_completed(ad_type: String, success: bool)

var _ad_cooldowns: Dictionary = {}
var _game_over_count: int = 0

func show_rewarded(ad_type: String, callback: Callable) -> void:
    # Hook: integrate with AdMob/IronSource plugin
    print("[AD] Rewarded ad requested: ", ad_type)
    # Simulate success for development
    callback.call(true)
    ad_completed.emit(ad_type, true)

func show_banner() -> void:
    print("[AD] Banner shown")

func hide_banner() -> void:
    print("[AD] Banner hidden")

func show_interstitial() -> void:
    _game_over_count += 1
    if _game_over_count % 3 == 0:
        print("[AD] Interstitial shown")

func can_use_rewarded(ad_type: String) -> bool:
    return not _ad_cooldowns.has(ad_type)

func mark_used(ad_type: String) -> void:
    _ad_cooldowns[ad_type] = true

func reset_cooldowns() -> void:
    _ad_cooldowns.clear()
```

---

## 9. UI Layout (Portrait 1080×1920)

### 9.1 HUD (During Gameplay)
```
┌──────────────────────────┐
│  DEPTH: 234m    $: 1250  │  ← Top bar (80px)
├──────────────────────────┤
│  [HEAT BAR ██████░░░░]   │  ← Heat bar (40px) 
│  [DURA BAR ████████░░]   │  ← Durability bar (40px)
├──────────────────────────┤
│                          │
│     GAME GRID (7 cols)   │  ← Main play area
│     ████ ▼ ████          │
│     ████ ▼ ████          │
│     ████   ████          │
│                          │
├──────────────────────────┤
│  [🔥COOL DOWN - Watch Ad]│  ← Ad button (shows at 70%+ heat)
├──────────────────────────┤
│  [    BANNER AD 320x50  ]│  ← Bottom banner
└──────────────────────────┘
```

### 9.2 Upgrade Shop Screen
```
┌──────────────────────────┐
│     UPGRADE STATION      │
│     Depth: 200m          │
├──────────────────────────┤
│  ┌────────────────────┐  │
│  │ 🛡 Heat Shield Lv2 │  │
│  │ -10% heat/block    │  │
│  │ [BUY - 90 coins]   │  │
│  └────────────────────┘  │
│  ┌────────────────────┐  │
│  │ ❄ Cooling Fan Lv1  │  │
│  │ +15% cooling       │  │
│  │ [FREE - Pick One!] │  │
│  └────────────────────┘  │
│  ┌────────────────────┐  │
│  │ 🔧 Reinforced Lv1  │  │
│  │ -12% wear          │  │
│  │ [BUY - 60 coins]   │  │
│  └────────────────────┘  │
├──────────────────────────┤
│  [CONTINUE DRILLING ▶]   │
└──────────────────────────┘
```

### 9.3 Game Over Screen
```
┌──────────────────────────┐
│      GAME OVER           │
│   ⚠ DRILL OVERHEATED ⚠  │
├──────────────────────────┤
│   Depth: 1234m           │
│   Coins: 3450            │
│   Best: 2100m            │
├──────────────────────────┤
│ [▶ CONTINUE - Watch Ad]  │
│ [×2 DOUBLE LOOT - Ad]    │
│ [🔄 RESTART]             │
│ [🏠 MAIN MENU]           │
└──────────────────────────┘
```

### 9.4 Main Menu
```
┌──────────────────────────┐
│                          │
│      🔩 DEEP DRILL 🔩    │
│                          │
│   Best Depth: 2100m      │
│   Total Coins: 12500     │
├──────────────────────────┤
│   [▶ START DRILLING]     │
│   [🏪 PERMANENT SHOP]    │
│   [🏆 LEADERBOARD]       │
│   [⚙ SETTINGS]           │
└──────────────────────────┘
```

---

## 10. Procedural Generation

### 10.1 Chunk System
- Generate in chunks of **10 rows**
- Each chunk: `depth_tier` determines spawn weights
- Seed-based RNG for reproducibility: `rng.seed = run_seed + chunk_index`

### 10.2 Depth Tiers

| Tier | Depth | Name | Background | New blocks |
|------|-------|------|-----------|------------|
| 1 | 0-99m | Topsoil | Brown `#5C3317` | Dirt, Stone |
| 2 | 100-299m | Bedrock | Dark gray `#3A3A3A` | +Granite |
| 3 | 300-499m | Gold Vein | Amber tint `#6B4F1D` | +Gold increased |
| 4 | 500-799m | Crystal Cave | Blue tint `#1A2A4A` | +Diamond increased |
| 5 | 800m+ | Magma Core | Red tint `#3A1010` | +Lava |

### 10.3 Row Generation Algorithm
```
func generate_row(depth: float, rng: RandomNumberGenerator) -> Array:
    var tier = get_tier(depth)
    var weights = TIER_WEIGHTS[tier]
    var row = []
    for col in 7:
        # Guarantee at least 1 empty per row for path
        if col == guaranteed_empty_col:
            row.append(BlockType.EMPTY)
            continue
        var roll = rng.randf()
        var cumulative = 0.0
        for type in weights:
            cumulative += weights[type]
            if roll <= cumulative:
                row.append(type)
                break
    # Ensure path connectivity: at least 2 adjacent empties or soft blocks
    ensure_path(row, rng)
    return row
```

### 10.4 Path Guarantee
- Always ensure at least **2 drillable** columns per row (empty or dirt)
- No fully blocked rows
- Every 5 rows: guaranteed gold or diamond cluster (2-3 blocks)

---

## 11. Balancing

### 11.1 Difficulty Curve
```
speed(depth) = base_speed * (1 + depth / 1000)  # +100% at 1000m
heat_mult(depth) = 1 + depth / 500               # +100% at 500m  
wear_mult(depth) = 1 + depth / 800               # +100% at 800m
```

### 11.2 Target Session Length
- **Casual player (no upgrades):** 2-3 minutes, ~150m depth
- **Skilled player (some upgrades):** 5-8 minutes, ~500m depth
- **Expert (max upgrades + ads):** 10-15 minutes, ~1200m depth

### 11.3 Economy Balance
- Average coins/meter: ~3 (early), ~8 (mid), ~15 (late)
- First upgrade affordable by: ~50m depth
- Full upgrade set cost: ~5000 coins total
- Double loot ad value: averages ~500-2000 coins

---

## 12. Permanent Shop (Meta-Progression)

Coins persist between runs. Permanent upgrades:

| Upgrade | Max | Effect | Cost |
|---------|-----|--------|------|
| Starting Heat Shield | 3 | Start with Heat Shield Lv(n) | 200/500/1200 |
| Starting Durability+ | 3 | +20 max durability per lvl | 150/400/1000 |
| Starting Cooling+ | 3 | +10% base cooling per lvl | 180/450/1100 |
| Lucky Drill | 3 | +5% rare block chance per lvl | 300/800/2000 |
| Coin Boost | 3 | +10% all coins per lvl | 250/600/1500 |

---

## 13. Audio Design

| Event | Sound | Type |
|-------|-------|------|
| Drill dirt | Soft crunch | SFX |
| Drill stone | Hard impact | SFX |
| Drill gold | Sparkle chime | SFX |
| Drill diamond | Crystal ring | SFX |
| Hit lava | Sizzle + alarm | SFX |
| Overheat warning | Beeping (80%+) | SFX loop |
| Drill break | Metal snap | SFX |
| Background | Mechanical ambient | Music loop |
| Menu | Calm electronic | Music loop |
| Upgrade pick | Level-up jingle | SFX |
| Coin collect | Coin clink | SFX |

---

## 14. Visual Effects

| Effect | Description |
|--------|-------------|
| Block break | 4-6 colored particles fly out |
| Drill sparks | Continuous particle trail from drill bit |
| Heat glow | Red vignette overlay at 80%+ heat |
| Depth fog | Background darkens progressively |
| Gold shimmer | Gold blocks have animated sparkle |
| Diamond pulse | Diamond blocks pulse with light |
| Lava glow | Lava blocks have animated orange glow |
| Screen shake | On hard block hit, on damage |
| Speed lines | Side lines when speed > 150% base |
