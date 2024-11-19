# 2023-11-04

### Additions
- `rewgs - export multitrack - dry.lua`
- `rewgs - export multitrack - wet.lua`
- Updated keymap for macOS

### Known issues
- The two added scripts above are supposed to silently increment up files with duplicate names, but the user is instead still alerted and asked if they want to silently increment.


# 2023-10-30

### Additions
- Added a keymaps folder. Users should be able to simply export the keymap, and the target lua scripts should be accurately pointed to.
- Added the ability to export MIDI tracks marked "to improve" ("IM"), in addition to tracks marked "to orchestrate" ("REC").

### Regressions
- **Had to backtrack/refactor in order to enable the inclusion of silent stems when exporting stems.** At the moment, the only stems-export script is `rewgs - export stems - wide - wet - include silent.lua`, which is needed for mix engineers. 
- Coming ASAP:
    - `rewgs - export stems - skinny - dry - include silent.lua`
    - `rewgs - export stems - skinny - wet - include silent.lua`
    - `rewgs - export stems - wide - dry - include silent.lua`
- Coming shortly after the above:
    - `rewgs - export stems - skinny - dry - exclude silent.lua`
    - `rewgs - export stems - skinny - wet - exclude silent.lua`
    - `rewgs - export stems - wide - dry - exclude silent.lua`
    - `rewgs - export stems - wide - wet - exclude silent.lua`
- Coming after that, TBD:
    - `rewgs - export all assets.lua`
    - `rewgs - export mix-minuses - dry.lua`
    - `rewgs - export mix-minuses - wet.lua`

### Known issues
- `rewgs - export stems - wide - wet - include silent.lua`
    - Issue: Any skinny stems with duplicate names (e.g. Violin I underneath a Ensemble Long folder, and another Violin I underneath a Ensemble Short folder) will be exported as xxx-001 and xxx-002 (e.g. Violin I-001 and Violin I-002 for long and short, respectively).
    - Planned fix: The name of the parent folder will be appended to the resulting stem name (e.g. Violin I Ensemble Long and Violin I Ensemble Short, respectively).
- keymaps
    - Issue: No Windows or Linux keymaps.
    - Planned fix: Will make them if/when requested.

