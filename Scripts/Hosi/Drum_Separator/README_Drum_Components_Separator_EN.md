# 🥁 Hosi Drum Components Separator (MDX23C)

An advanced AI-powered tool running natively inside REAPER that decomposes your mixed Drum Loops or stems into isolated, studio-quality components (Kick, Snare, Toms, Hi-Hat, Cymbals).

Powered by the robust **MDX23C DrumSep** neural network architecture (utilized by Ultimate Vocal Remover), this script operates seamlessly within your workflow without requiring complex setups.

---

## 🛠 1. System Requirements
- **REAPER** v6.0 or higher.
- **ReaImGui v0.10** Extension (Installable via ReaPack).
- **Python 3.9+**.

## ⚙️ 2. Installation Guide

### Step 1: Ensure Python is Installed
If Python is not installed on your system, download the latest version at [python.org](https://www.python.org/downloads/). 
> 🚨 **CRITICAL:** During the Python installation setup, you **MUST** check the `Add Python to PATH` box at the bottom before clicking Install.

### Step 2: Auto-Install AI Libraries (1-Click Setup)
Locate the `Install_Drum_Separator_EN.bat` file provided with this script and double-click to run it.
- A Command Prompt window will open.
- Wait for the system to download and configure the `audio-separator` and `onnxruntime` libraries (Takes 1-2 minutes depending on your internet connection).
- Once you see green text saying "INSTALLATION COMPLETE!", press any key to close the window.

### Step 3: Load Script into REAPER
1. Open REAPER.
2. In the top menu, navigate to `Actions` -> `Show action list...`
3. Click the `New action...` button -> `Load ReaScript...`
4. Select the `Hosi_Drum_Components_Separator.lua` file and click Open.
5. Done! You can now assign a keyboard shortcut to it if desired.

---

## 🚀 3. How to Use
1. Double-click the newly added script in your Action List to launch the UI.
2. In your REAPER arrangement view, **click to highlight 1 Audio Item** that contains the drum audio you want to separate.
3. Bring up the script UI and click the yellow **SPLIT DRUM COMPONENTS** button.

> ⚠️ *Important Note: THE FIRST TIME you run this process, the progress bar will remain at 0% for a while (5-10 minutes) depending on your internet speed. Do not close REAPER! The Audio-Separator engine is downloading the heavy AI model (`MDX23C-DrumSep` ~100MB) from the cloud. Subsequent runs will be completely OFFLINE and blazing fast.*

4. Once the loading hits 100%, 5 separated audio stems (Kick, Snare, Toms, Hi-hat, Cymbals) will automatically be inserted as new tracks directly below the original, perfectly synchronized with your timeline. The original track will be muted.

Enjoy your world-class separated mixes!
