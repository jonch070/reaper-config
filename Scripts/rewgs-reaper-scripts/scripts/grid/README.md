Both sets of scripts set the grid for both the main window and MIDI editor; the difference between the two sets is what precisely they're doing.

Those in `main window/` set the grid in the main window, and set the grid in *any* MIDI editor. This way, any MIDI editor that is opened will, when it's opened, have the same grid as the main window.
Those in `midi editor/` set the grid in the main window, and set the grid in the *currently-open/active* MIDI editor. This way, the currently active MIDI will stay in sync with the main window.
