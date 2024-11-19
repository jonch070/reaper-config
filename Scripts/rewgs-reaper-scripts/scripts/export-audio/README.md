# NOTES: 
- This is a really helpful function!
    - `integer reaper.PromptForAction(integer session_mode, integer init_id, integer section_id)`
    - Uses the action list to choose an action. Call with session_mode=1 to create a session (init_id will be the initial action to select, or 0), then poll with session_mode=0, checking return value for user-selected action (will return 0 if no action selected yet, or -1 if the action window is no longer available). When finished, call with session_mode=-1.

# TODO:
- split out render-tables.lua into *just* the render tables, and then render-functions.lua
- print individual tracks both wet and dry
- add audio click for stems export
   -- BUGS: Running this # of times causes these effects (circular, can start anywhere)...
       -- 1. Seemingly works, but actually adds another Click track with no media items at second-to-last-index
       -- 2. Deletes all Click tracks
- give option or new function to spit out dialogue (only the engineer needs this)
   -- maybe spit out 2mix + dx track as well? need that for client, too...
- (not urgent): work on an export job that exports all individual audio items within the time locators (for mx edit). Include a mix of that as well so that the editor has reference.
- to check: is it possible to, when saving out a new version of the Reaper project with media files copied over, ignore video files and only copy audio files?
- midi_all_tracks          -- maybe not this script
- midi_orch_tracks_only    -- maybe not this script
- midi_tempo_track_only    -- maybe not this script

# Brainstorm
- NOTES TO SELF: 
   - remember that we are "marking" tracks for orchestration!
- export for everyone: midi, mix, picture, audio click track, and stems...
   - orchestrators (skinny stems)
   - music editors (wide stems)
   - engineers (wide stems)
   - session musicians (skinny stems)
- So, need multiple small functions for...
   - "basic export" (items for all people)
       - create and export audio click track
       - export mix wav
       - export mix mp3
   - export midi options
       - export full project MIDI (only tracks with data, etc)
       - export midi for orchestrators (this script)
   - export picture (2mix and dx)
   - export stems
       - skinny
       - wide
- So, functions per group
   - all: 
       - create and export audio click track
       - export mix wav
       - export mix mp3
   - orchestrators
       - export midi for orchestrators (this script)
       - export picture (2mix and dx)
       - export skinny stems
   - music editors
   - engineers
   - session musicians
- Export folder fierarchy:
- Project/Cue/exports
   - version number (this is made at export time/is the "root" of the export function; get from project name)
       - 2mix.mp3
       - 2mix.wav
       - click.wav
       - cue.midi
       - cue.mp4
       - stems (note: skipping "individual tracks" folder for now)
           - skinny
           - wide
- NOTE: This assumes that track and item mute states are correct. If something that shouldn't be muted is, that's on you.
- steps:
1. SWS: Show All Tracks in TCP
2. Action #40035: 'Select all items/tracks/envelope points (depending on focus)'.
    - Maybe shouldn't select envelope points? Action #40182 'Item: Select all items' might be better.
3. Action #41039: 'Loop points: Set loop points to items'
    - Maybe Action #40290 'Time selection: Set time selection to items' is more appropriate/explicit.
4. Script: Track Visibility - Show only tracks with items.lua
5. set folder location?
6. export midi (`File: Export project MIDI...`)
    - Probably can't do this unattended...?
