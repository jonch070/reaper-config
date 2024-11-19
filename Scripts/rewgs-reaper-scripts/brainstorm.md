Multiple namespaces:
- Project
    - project-specific data (project name, path, etc)
    - state, which includes...
    - tracks (multiple, as objects)
- Track
    - track properties such as name, mute state, etc
    - media items
- Item
    - item properties such as location, mute state, etc

Eventually split "modules" and "scripts" into two repos
- modules: "reaify" - **R**ewgs' **E**xtension for the Reaper **A**PI. 
    - Provides a more object-oriented approach for interacting with the Reaper API. 
    - The name is a play on the word "reify," which is adjacent to "objectify," as well as a play on the fact that nearly every extension made for Reaper starts with the letters "rea."
- scripts: Rewgs' Composer Toolbox, or rct.

The files `modules/Some_Namespace.lua` and `.tests/namespaces_test.lua` show how to go about collecting everything into proper namespaces.
Some good info:
- https://stackoverflow.com/questions/4394303/how-to-make-namespace-in-lua
- https://www.lua.org/pil/15.2.html
