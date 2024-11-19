# TODO
- Make export-audio.lua work with Jon's folder heirarchy as described below...
    ```
    - FilmCode - CueNumber - CueName/
        - FilmCode - CueNumber - CueName - v01.00.00 [- MORE STUFF].rpp
        - FilmCode - CueNumber - CueName - v02.00.00 [- MORE STUFF].rpp
        - exports/
            - FilmCode - CueNumber - CueName - v01.00.00/
                - renders/
                    - mixes/
                        - .wav
                        - .mp3
                    - stems/
                        - skinny/...
                        - wide/...
                - deliverables
                    - FilmCode - CueNumber - CueName - v01.00.00 - for mx edit/
                    - FilmCode - CueNumber - CueName - v01.00.00 - for orch/
                    - FilmCode - CueNumber - CueName - v01.00.00 - for review/
                    - FilmCode - CueNumber - CueName - v01.00.00 - for collaborators/
                    - FilmCode - CueNumber - CueName - v01.00.00 - for mixer/
                    - FilmCode - CueNumber - CueName - v01.00.00 - for scoring stage/
            - FilmCode - CueNumber - CueName - v02.00.00/
                - all-renders
                - deliverables
    ```
    - To achieve that, either diff each .rpp in a cue's folder and lose anything after the version number; and/or whatever else
    - ALSO: make it so that when zipping the deliverables folders
- Edit Export Audio: Jon's main music bus has FX, volume automation, etc; THESE ALL NEED TO BE BYPASSED WHEN EXPORTING AUDIO.

# Mix minus brainstorm

```lua
-- no mark = no one touches/works on it
-- REPLACEMENTS:
-- to_record_ens = "RE"
-- to_record_soloist = "RS"
-- to_orch_trans = "TR" -- and then of course record it
-- to_improve = "IM" -- has producer, writer, engineer, etc making it better in some way
function render_mix_minus(mark) -- recipient is the mark
    -- select track(s) with mark
    -- export only those tracks
    -- export everything but those tracks
end
```
