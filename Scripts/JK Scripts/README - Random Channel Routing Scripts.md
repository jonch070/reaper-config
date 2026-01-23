# Random Channel Routing Scripts

Scripts for creating folder structures with children routed to random multichannel outputs. Useful for spatial audio, immersive mixing, and surround sound design.

## Current Scripts (with channel selection dialog)

These are the recommended scripts. They prompt for channels to include/exclude.

### 7.1.4 Format (12 channels)
- `714 create children from tracks and assign to random channels with selection (multiple folders).lua`
- `714 create children from tracks and assign to random channels with selection (one folder).lua`

### 9.1.6 Format (16 channels)
- `916 create children from tracks and assign to random channels with selection (multiple folders).lua`
- `916 create children from tracks and assign to random channels with selection (one folder).lua`

### General/Unlimited (numbers only)
- `create children from tracks and assign to random channels with selection (multiple folders).lua`
- `create children from tracks and assign to random channels with selection (one folder).lua`

## Usage

1. Select 2+ tracks (first track becomes parent folder, rest become children)
2. Run the script
3. Enter channels in the dialog:
   - **Include**: channels to randomize between
   - **Exclude**: channels to skip (defaults to 4/LFE for 714/916)
   - **Fill all channels before repeating?**: y/n (defaults to y)

### Input Formats

| Format | Example | Result |
|--------|---------|--------|
| Single number | `5` | Channel 5 |
| Range | `1-8` | Channels 1, 2, 3, 4, 5, 6, 7, 8 |
| List | `1, 5, 9` | Channels 1, 5, 9 |
| Mixed | `1-3, 7, 9-12` | Channels 1, 2, 3, 7, 9, 10, 11, 12 |

### Fill First Mode

When "Fill all channels before repeating" is set to **y** (default):
- Each available channel is used once before any channel repeats
- Prevents scenarios like channel 5 being used 3 times while channel 12 is never used
- Example: With 15 available channels and 20 tracks, all 15 channels get used once, then 5 more are randomly selected

When set to **n**:
- Pure random selection - any channel can be picked at any time
- May result in uneven distribution

### Channel Names (714 & 916 only)

The 714 and 916 scripts accept channel names (case insensitive, letter order flexible):

**7.1.4 Channel Order (SMPTE/Dolby)**
| Ch | Name | Accepts |
|----|------|---------|
| 1 | L | `l`, `left` |
| 2 | R | `r`, `right` |
| 3 | C | `c`, `center`, `centre` |
| 4 | LFE | `lfe`, `elf`, `fel`, `sub`, `subwoofer` |
| 5 | Lss | `lss`, `ssl`, `sls` |
| 6 | Rss | `rss`, `ssr`, `srs` |
| 7 | Lrs | `lrs`, `lsr`, `rls`, `rsl`, `slr`, `srl` |
| 8 | Rrs | `rrs`, `rsr`, `srr` |
| 9 | Ltf | `ltf`, `lft`, `tlf`, `tfl`, `flt`, `ftl` |
| 10 | Rtf | `rtf`, `rft`, `trf`, `tfr`, `frt`, `ftr` |
| 11 | Ltr | `ltr`, `lrt`, `tlr`, `trl`, `rlt`, `rtl`, `ltb`, `lbt`, `tlb`, `tbl`, `blt`, `btl` |
| 12 | Rtr | `rtr`, `rrt`, `trr`, `rtb`, `rbt`, `trb`, `tbr`, `brt`, `btr` |

**Note:** `Ltb`/`Rtb` (Top Back) are aliases for `Ltr`/`Rtr` (Top Rear) - same channels, different naming conventions.

**9.1.6 Channel Order (SMPTE/Dolby)**
| Ch | Name | Notes |
|----|------|-------|
| 1-8 | Same as 7.1.4 | L, R, C, LFE, Lss, Rss, Lrs, Rrs |
| 9 | Lw | Left Wide |
| 10 | Rw | Right Wide |
| 11 | Ltf | Left Top Front |
| 12 | Rtf | Right Top Front |
| 13 | Ltm | Left Top Middle |
| 14 | Rtm | Right Top Middle |
| 15 | Ltr | Left Top Rear (also: Ltb) |
| 16 | Rtr | Right Top Rear (also: Rtb) |

### Examples

```
Include: 1-12      Exclude: 4         -> All 7.1.4 except LFE
Include: L-C, Lss-Rss   Exclude:      -> Front 3 + side surrounds only
Include: ltf-rtr   Exclude:           -> Top layer only (714: 9-12, 916: 11-16)
Include: ltf-rtb   Exclude:           -> Same as above (rtb = rtr)
Include: 1, 5, 6   Exclude:           -> L, Lss, Rss only
Include: 1-16      Exclude: lfe, lw-rw -> 9.1.6 minus LFE and wides
```

## Multiple Folders vs One Folder

- **Multiple folders**: Each run creates a new folder structure
- **One folder**: Same behavior (naming is historical)

Both variants function identically - select tracks, run script, get folder with random routing.

---

## Outdated Scripts

The following scripts are superseded by the "with selection" versions above and can be removed:

### Track-based (replaced by selection versions)
- `714 create children from tracks and assign to random channels (multiple folders).lua`
- `714 create children from tracks and assign to random channels (one folder).lua`
- `916 create children from tracks and assign to random channels (multiple folders).lua`
- `916 create children from tracks and assign to random channels (one folder).lua`

### Test/development scripts (can be removed)
- `test random channel 714.lua`
- `test random channel 916.lua`
- `test input set 16.lua`

### Possibly outdated (review before removing)
- `Random_Channel_Mode_Selection_No_LFE.lua`
- `Randomize item output channel (skip channel 4).lua`
- `subproject_random_channels.lua`
- `step1_add_channel_mapper.lua`
- `step2_apply_random_presets.lua`

---

## Still Current (different functionality)

These item-based scripts work on items rather than tracks and are NOT replaced:

- `916 create children from items and assign to random channels (multiple folders).lua`
- `916 create children from items and assign to random channels (one folder).lua`
- `714 create children from items and assign to random channels (multiple folders).lua`
- `714 create children from items and assign to random channels (one folder).lua`

If you want channel selection dialogs for the item-based scripts too, those would need to be created separately.
