-- @description Song Architect Module for Reanspiration
-- @version 1.0
-- @author Hosi

local Architect = {}

-- ============================================================================
-- 1. DATA STRUCTURES (COLORS & TEMPLATES)
-- ============================================================================

-- Helper to map color names to strings (matches Dev script structure)
local colors = {
    cyan   = "cyan",    -- Intro
    green  = "green",   -- Verse
    yellow = "yellow",  -- Pre-Chorus / Solo Improv
    red    = "red",     -- Chorus / Hook / Drop
    purple = "purple",  -- Bridge / Solo / Middle 8
    grey   = "grey",    -- Outro
    blue   = "blue",    -- Breakdown / Part B / Deconstruct
    orange = "orange",  -- Build-up / Rise
    pink   = "pink",    -- Special / Opera / Post-Chorus / Ear Candy
    teal   = "teal",    -- Head / Instrumental
    brown  = "brown",   -- Movement / Refrain / Turnaround
    
    -- Track Specific Colors
    tr_drums   = "tr_drums",
    tr_bass    = "tr_bass",
    tr_gtr     = "tr_gtr",
    tr_acous   = "tr_acous",
    tr_keys    = "tr_keys",
    tr_vox     = "tr_vox",
    tr_fx      = "tr_fx",
    tr_orch_str= "tr_orch_str",
    tr_orch_brs= "tr_orch_brs",
    tr_orch_ww = "tr_orch_ww"
}

-- RGB Values for Region Coloring
Architect.colors_rgb = {
    cyan={0,255,255}, green={0,255,0}, yellow={255,255,0}, red={255,0,0}, 
    purple={128,0,128}, grey={128,128,128}, blue={0,0,255}, orange={255,165,0},
    pink={255,105,180}, teal={0,128,128}, brown={165,42,42},
    tr_drums={200,150,50}, tr_bass={100,100,255}, tr_gtr={20,100,200}, tr_acous={200,200,100}, tr_keys={50,200,150},
    tr_vox={255,100,200}, tr_fx={200,0,200}, tr_orch_str={180,180,100}, tr_orch_brs={200,100,50}, tr_orch_ww={100,200,100}
}

-- AK Height Map (Configurable)
-- Height = MaxPitch - MinPitch
-- Tolerance: +/- 1 semitone
Architect.ak_height_map = {
    [36] = {col="cyan", name="Intro"},
    [54] = {col="green", name="Verse"},
    [73] = {col="yellow", name="Link"}, -- or Interlude
    [91] = {col="purple", name="Bridge"},
    [109] = {col="orange", name="Pre-Chorus"},
    [127] = {col="red", name="Chorus"} -- High Energy
}

Architect.templates = {
    {
        name = "Pop Standard (Verse-Chorus)",
        category = "Pop & Ballad",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan, timesig="4/4"},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 16, col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 16, col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Modern Pop (Chorus Start / TikTok)",
        category = "Pop & Ballad",
        structure = {
            {name = "Chorus (Hook)", bars = 8,  col = colors.red},
            {name = "Verse 1",       bars = 8,  col = colors.green},
            {name = "Pre-Chorus",    bars = 4,  col = colors.yellow},
            {name = "Chorus",        bars = 8,  col = colors.red},
            {name = "Verse 2",       bars = 8,  col = colors.green},
            {name = "Bridge",        bars = 8,  col = colors.purple},
            {name = "Chorus",        bars = 16, col = colors.red},
            {name = "Outro",         bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Streaming Era (Skip-Rate Optimized)",
        category = "Pop & Ballad",
        structure = {
            {name = "Intro (Micro)",    bars = 2,  col = colors.cyan},
            {name = "Hook (Ear Candy)", bars = 4,  col = colors.pink},
            {name = "Verse 1",          bars = 8,  col = colors.green},
            {name = "Chorus",           bars = 8,  col = colors.red},
            {name = "Post-Chorus",      bars = 8,  col = colors.pink},
            {name = "Verse 2",          bars = 8,  col = colors.green},
            {name = "Chorus",           bars = 16, col = colors.red},
            {name = "Outro (Short)",    bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Pop Ballad (Slow Build)",
        category = "Pop & Ballad",
        structure = {
            {name = "Intro (Piano)", bars = 4,  col = colors.cyan},
            {name = "Verse 1",       bars = 8,  col = colors.green},
            {name = "Verse 2",       bars = 8,  col = colors.green},
            {name = "Chorus",        bars = 8,  col = colors.red},
            {name = "Verse 3",       bars = 8,  col = colors.green},
            {name = "Chorus",        bars = 16, col = colors.red},
            {name = "Bridge (Climax)",bars = 8, col = colors.purple},
            {name = "Chorus (Soft)", bars = 8,  col = colors.red},
            {name = "Outro",         bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Pop Shape Shifter (Shape of You Style)",
        category = "Pop & Ballad",
        structure = {
            {name = "Intro",      bars = 8,  col = colors.cyan},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Drop (Vocal Chops)", bars = 8, col = colors.orange},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Drop",       bars = 8,  col = colors.orange},
            {name = "Middle 8",    bars = 8,  col = colors.purple},
            {name = "Chorus",      bars = 8,  col = colors.red},
            {name = "Drop (Outro)",bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Synth Pop Classic (Sweet Dreams Style)",
        category = "Pop & Ballad",
        structure = {
            {name = "Intro (Riff)", bars = 8,  col = colors.cyan},
            {name = "Verse 1",      bars = 16, col = colors.green},
            {name = "Break/Bridge", bars = 6,  col = colors.purple},
            {name = "Verse 2",      bars = 16, col = colors.green},
            {name = "Break/Bridge", bars = 6,  col = colors.purple},
            {name = "Verse 3",      bars = 16, col = colors.green},
            {name = "Outro (Fade)", bars = 16, col = colors.grey}
        }
    },
    {
        name = "Classic Anthem (We Are The World Style)",
        category = "Pop & Ballad",
        structure = {
            {name = "Intro (Atmosphere)", bars = 6,  col = colors.cyan},
            {name = "Verse 1",            bars = 8,  col = colors.green},
            {name = "Chorus (Anthem)",    bars = 9,  col = colors.red},
            {name = "Verse 2",            bars = 8,  col = colors.green},
            {name = "Bridge (Climax)",    bars = 8,  col = colors.purple},
            {name = "Chorus (Repeat)",    bars = 18, col = colors.red},
            {name = "Outro (Fade)",       bars = 8,  col = colors.grey}
        }
    },
    {
        name = "AABA Standard (Early Pop/Jazz)",
        category = "Pop & Ballad",
        structure = {
            {name = "Section A (Verse)",  bars = 8,  col = colors.green},
            {name = "Section A (Repeat)", bars = 8,  col = colors.green},
            {name = "Section B (Bridge)", bars = 8,  col = colors.purple},
            {name = "Section A (Return)", bars = 8,  col = colors.green}
        }
    },
    {
        name = "EDM Extended Mix (Club)",
        category = "EDM & Electronic",
        structure = {
            {name = "DJ Intro",   bars = 32, col = colors.cyan},
            {name = "Breakdown",  bars = 16, col = colors.blue},
            {name = "Build-up",   bars = 8,  col = colors.orange},
            {name = "Drop 1",     bars = 16, col = colors.red},
            {name = "Breakdown 2",bars = 16, col = colors.blue},
            {name = "Build-up",   bars = 8,  col = colors.orange},
            {name = "Drop 2",     bars = 32, col = colors.red},
            {name = "Outro",      bars = 16, col = colors.grey}
        }
    },
    {
        name = "EDM Radio Edit",
        category = "EDM & Electronic",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Build-up",   bars = 8,  col = colors.orange},
            {name = "Drop 1",     bars = 16, col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Drop 2",     bars = 16, col = colors.red},
            {name = "Outro",      bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Trance Uplifting (138 BPM Standard)",
        category = "EDM & Electronic",
        structure = {
            {name = "Intro (Mix)",     bars = 32, col = colors.cyan, bpm=138},
            {name = "Small Break",     bars = 16, col = colors.blue},
            {name = "Build-up 1",      bars = 16, col = colors.orange},
            {name = "Main Break",      bars = 32, col = colors.purple}, 
            {name = "Main Build",      bars = 16, col = colors.orange},
            {name = "Drop (Hook)",     bars = 32, col = colors.red},
            {name = "Outro (Decon)",   bars = 32, col = colors.grey}
        }
    },
    {
        name = "Techno / House (Linear)",
        category = "EDM & Electronic",
        structure = {
            {name = "Intro",        bars = 16, col = colors.cyan},
            {name = "Groove A",     bars = 16, col = colors.green},
            {name = "Groove B",     bars = 16, col = colors.green},
            {name = "Breakdown",    bars = 8,  col = colors.blue},
            {name = "Build",        bars = 8,  col = colors.orange},
            {name = "Main Drop",    bars = 32, col = colors.red},
            {name = "Deconstruct",  bars = 16, col = colors.blue},
            {name = "Outro",        bars = 16, col = colors.grey}
        }
    },
    {
        name = "Modern Club Pop (One Kiss Style)",
        category = "EDM & Electronic",
        structure = {
            {name = "Intro",        bars = 8,  col = colors.cyan},
            {name = "Verse 1",      bars = 8,  col = colors.green},
            {name = "Pre-Chorus",   bars = 8,  col = colors.yellow},
            {name = "Chorus",       bars = 8,  col = colors.red},
            {name = "Drop (Hook)",  bars = 8,  col = colors.orange},
            {name = "Verse 2",      bars = 8,  col = colors.green},
            {name = "Pre-Chorus",   bars = 8,  col = colors.yellow},
            {name = "Chorus",       bars = 8,  col = colors.red},
            {name = "Drop (Hook)",  bars = 8,  col = colors.orange},
            {name = "Middle 8",      bars = 8,  col = colors.purple},
            {name = "Chorus",        bars = 8,  col = colors.red},
            {name = "Drop (Outro)",  bars = 16, col = colors.orange}
        }
    },
    {
        name = "Modern Trap/Dubstep (Build-Drop)",
        category = "EDM & Electronic",
        structure = {
            {name = "Intro",        bars = 8,  col = colors.cyan, bpm=140},
            {name = "Build-up",     bars = 8,  col = colors.orange},
            {name = "Drop 1 (Intro)",bars = 16, col = colors.red},
            {name = "Break (Half)", bars = 16, col = colors.blue},
            {name = "Build-up",     bars = 8,  col = colors.orange},
            {name = "Drop 2 (Main)",bars = 16, col = colors.red}, 
            {name = "Outro",        bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Hip Hop / Trap Standard",
        category = "Hip Hop & R&B",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Hook",       bars = 8,  col = colors.red},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Hook",       bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Hook",       bars = 8,  col = colors.red},
            {name = "Outro",      bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Golden Era Boom Bap (90s 16-Bar)",
        category = "Hip Hop & R&B",
        structure = {
            {name = "Intro (Sample)", bars = 4,  col = colors.cyan, bpm=90},
            {name = "Verse 1",        bars = 16, col = colors.green},
            {name = "Hook (Scratch)", bars = 8,  col = colors.red},
            {name = "Verse 2",        bars = 16, col = colors.green},
            {name = "Hook",           bars = 8,  col = colors.red},
            {name = "Verse 3",        bars = 16, col = colors.green},
            {name = "Outro",          bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Modern Trap (Vibe-First)",
        category = "Hip Hop & R&B",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Hook",       bars = 8,  col = colors.red},
            {name = "Verse 1",    bars = 12, col = colors.green},
            {name = "Hook",       bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 12, col = colors.green},
            {name = "Hook",       bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "R&B / Neo-Soul",
        category = "Hip Hop & R&B",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus x2",  bars = 16, col = colors.red},
            {name = "Outro",      bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Hip Hop Anthem (In Da Club Style)",
        category = "Hip Hop & R&B",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Chorus (Hook)",bars = 8, col = colors.red},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Chorus (Hook)",bars = 8, col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Chorus (Hook)",bars = 8, col = colors.red},
            {name = "Bridge",     bars = 4,  col = colors.purple},
            {name = "Chorus (Hook)",bars = 8, col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Modern Trap Suite (Sicko Mode Style)",
        category = "Hip Hop & R&B",
        structure = {
            {name = "Part 1 (Intro)", bars = 16, col = colors.cyan, bpm=150},
            {name = "Part 1 (Verse)", bars = 16, col = colors.green},
            {name = "Part 2 (Switch)",bars = 24, col = colors.blue, bpm=130},
            {name = "Part 2 (Verse)", bars = 16, col = colors.green},
            {name = "Part 3 (Switch)",bars = 32, col = colors.orange, bpm=155},
            {name = "Outro",          bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Rock Standard",
        category = "Rock, Jazz & Folk",
        structure = {
            {name = "Intro",      bars = 8,  col = colors.cyan},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 16, col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Guitar Solo",bars = 16, col = colors.pink},
            {name = "Chorus",     bars = 16, col = colors.red},
            {name = "Outro",      bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Rock Ballad (AABA)",
        category = "Rock, Jazz & Folk",
        structure = {
            {name = "Intro",      bars = 8,  col = colors.cyan},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 16, col = colors.red},
            {name = "Solo",       bars = 16, col = colors.purple},
            {name = "Chorus",     bars = 16, col = colors.red},
            {name = "Outro",      bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Blues (12-Bar Standard)",
        category = "Rock, Jazz & Folk",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 12, col = colors.green, timesig="4/4"},
            {name = "Verse 2",    bars = 12, col = colors.green},
            {name = "Chorus",     bars = 12, col = colors.red},
            {name = "Solo",       bars = 12, col = colors.purple},
            {name = "Verse 3",    bars = 12, col = colors.green},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Jazz Standard (Head-Solo-Head)",
        category = "Rock, Jazz & Folk",
        structure = {
            {name = "Intro",      bars = 8,  col = colors.cyan},
            {name = "Head (Theme)",bars = 32, col = colors.teal},
            {name = "Solo 1 (Piano)",bars = 32, col = colors.yellow},
            {name = "Solo 2 (Sax)",  bars = 32, col = colors.yellow},
            {name = "Trading 4s",    bars = 16, col = colors.orange},
            {name = "Head Out",      bars = 32, col = colors.teal},
            {name = "Tag/Ending",    bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Classic Rock Opera (Bohemian Style)",
        category = "Rock, Jazz & Folk",
        structure = {
            {name = "Intro (A Cappella)", bars = 4,  col = colors.cyan, bpm=72},
            {name = "Ballad Verse 1",     bars = 10, col = colors.green},
            {name = "Ballad Verse 2",     bars = 10, col = colors.green},
            {name = "Guitar Solo",        bars = 8,  col = colors.purple},
            {name = "Opera Section",      bars = 24, col = colors.pink, bpm=144},
            {name = "Hard Rock Section",  bars = 16, col = colors.red, bpm=138},
            {name = "Outro (Rubato)",     bars = 10, col = colors.grey, bpm=80}
        }
    },
    {
        name = "Folk Strophic (AAA)",
        category = "Rock, Jazz & Folk",
        structure = {
            {name = "Intro (Acoustic)",bars = 4, col = colors.cyan},
            {name = "Verse 1",       bars = 16, col = colors.green},
            {name = "Refrain",       bars = 2,  col = colors.brown},
            {name = "Interlude",     bars = 4,  col = colors.teal},
            {name = "Verse 2",       bars = 16, col = colors.green},
            {name = "Refrain",       bars = 2,  col = colors.brown},
            {name = "Interlude",     bars = 4,  col = colors.teal},
            {name = "Verse 3",       bars = 16, col = colors.green},
            {name = "Refrain",       bars = 4,  col = colors.brown},
            {name = "Outro",          bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Prog Rock Suite (Multi-Movement)",
        category = "Rock, Jazz & Folk",
        structure = {
            {name = "Overture",       bars = 16, col = colors.cyan, timesig="4/4", bpm=120},
            {name = "Mvmt I: Theme A",bars = 24, col = colors.brown, timesig="7/8", bpm=130},
            {name = "Mvmt II: Ballad",bars = 24, col = colors.green, timesig="4/4", bpm=90},
            {name = "Mvmt III: Chaos",bars = 32, col = colors.blue, timesig="5/4", bpm=150},
            {name = "Grand Solo",     bars = 24, col = colors.purple, timesig="6/8"},
            {name = "Recapitulation", bars = 24, col = colors.red, timesig="4/4", bpm=120},
            {name = "Coda (Finale)",  bars = 16, col = colors.grey}
        }
    },
    {
        name = "Cinematic Score (Action)",
        category = "Cinematic",
        structure = {
            {name = "Intro (Atmosphere)", bars = 8,  col = colors.cyan, bpm=120},
            {name = "Build Up (Tension)", bars = 16, col = colors.orange},
            {name = "Action Theme A",     bars = 16, col = colors.red},
            {name = "Bridge (Suspense)",  bars = 8,  col = colors.purple},
            {name = "Action Theme B",     bars = 16, col = colors.red},
            {name = "Climax (Epic)",      bars = 16, col = colors.red},
            {name = "Outro (Fade)",       bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Pop Standard (Main Example)",
        category = "Pop (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan, timesig="4/4"},
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Pop Variation (Short Pre-Chorus)",
        category = "Pop (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Pop (No Intro)",
        category = "Pop (New)",
        structure = {
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 8,  col = colors.red}
        }
    },
    {
        name = "Pop Extended (Post-Chorus)",
        category = "Pop (New)",
        structure = {
            {name = "Intro",       bars = 4,  col = colors.cyan},
            {name = "Verse 1",     bars = 8,  col = colors.green},
            {name = "Pre-Chorus",  bars = 8,  col = colors.yellow},
            {name = "Chorus",      bars = 8,  col = colors.red},
            {name = "Post-Chorus", bars = 4,  col = colors.pink},
            {name = "Verse 2",     bars = 8,  col = colors.green},
            {name = "Pre-Chorus",  bars = 4,  col = colors.yellow},
            {name = "Chorus",      bars = 8,  col = colors.red},
            {name = "Bridge",      bars = 8,  col = colors.purple},
            {name = "Chorus",      bars = 8,  col = colors.red},
            {name = "Outro",       bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Pop with Turnaround",
        category = "Pop (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Turnaround", bars = 2,  col = colors.brown},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "R&B Standard",
        category = "R&B (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "R&B Simple (No Bridge)",
        category = "R&B (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "R&B Long Verse (12 Bars)",
        category = "R&B (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 12,  col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 12,  col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "R&B Vibe (Post-Chorus Heavy)",
        category = "R&B (New)",
        structure = {
            {name = "Intro",       bars = 4,  col = colors.cyan},
            {name = "Verse 1",     bars = 8,  col = colors.green},
            {name = "Pre-Chorus",  bars = 8,  col = colors.yellow},
            {name = "Chorus",      bars = 8,  col = colors.red},
            {name = "Post-Chorus", bars = 8,  col = colors.pink},
            {name = "Verse 2",     bars = 8,  col = colors.green},
            {name = "Pre-Chorus",  bars = 8,  col = colors.yellow},
            {name = "Chorus",      bars = 8,  col = colors.red},
            {name = "Post-Chorus", bars = 8,  col = colors.pink}
        }
    },
    {
        name = "Rap Standard (3 Verses)",
        category = "Rap & Hip-Hop (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 3",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Rap Melodic (12-Bar Verses)",
        category = "Rap & Hip-Hop (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 12, col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 12, col = colors.green},
            {name = "Pre-Chorus", bars = 4,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Rap Dynamic (With Breakdown)",
        category = "Rap & Hip-Hop (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 3",    bars = 16, col = colors.green},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Breakdown",  bars = 8,  col = colors.blue},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "Rap Freestyle / Lyrical",
        category = "Rap & Hip-Hop (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse (Long)",bars = 32, col = colors.green},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    },
    {
        name = "EDM Festival (Build-Drop)",
        category = "EDM & Electronic (New)",
        structure = {
            {name = "Intro",        bars = 8,  col = colors.cyan},
            {name = "Verse",        bars = 16, col = colors.green},
            {name = "Build-up",     bars = 8,  col = colors.orange},
            {name = "Drop (Chorus)",bars = 16, col = colors.red},
            {name = "Breakdown",    bars = 8,  col = colors.blue},
            {name = "Build-up",     bars = 8,  col = colors.orange},
            {name = "Drop (Chorus)",bars = 16, col = colors.red},
            {name = "Outro",        bars = 8,  col = colors.grey}
        }
    },
    {
        name = "EDM Radio Edit (New)",
        category = "EDM & Electronic (New)",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 16, col = colors.green},
            {name = "Build-up",   bars = 8,  col = colors.orange},
            {name = "Drop 1",     bars = 16, col = colors.red},
            {name = "Verse 2",    bars = 16, col = colors.green},
            {name = "Drop 2",     bars = 16, col = colors.red},
            {name = "Outro",      bars = 8,  col = colors.grey}
        }
    },
    {
        name = "Country Standard",
        category = "Country",
        structure = {
            {name = "Intro",      bars = 4,  col = colors.cyan},
            {name = "Verse 1",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Verse 2",    bars = 8,  col = colors.green},
            {name = "Pre-Chorus", bars = 8,  col = colors.yellow},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Bridge",     bars = 8,  col = colors.purple},
            {name = "Chorus",     bars = 8,  col = colors.red},
            {name = "Outro",      bars = 4,  col = colors.grey}
        }
    }
}

-- ============================================================================
-- 2. APPLY STRUCTURE (Create Regions)
-- ============================================================================

Architect.last_gen_pos = 0

function Architect.applyStructure(template_index, clear_existing)
    local template = Architect.templates[template_index]
    if not template then return end

    local cursor_pos = reaper.GetCursorPosition()
    Architect.last_gen_pos = cursor_pos -- Store for preview alignment
    
    local bpm = reaper.Master_GetTempo()
    local qn_dur = 60 / bpm 
    
    reaper.Undo_BeginBlock()
    
    -- Clear Existing Regions if requested
    if clear_existing then
        local ret, num_markers, num_regions = reaper.CountProjectMarkers(0)
        -- Delete in reverse order to avoid index shifting issues
        for i = num_markers + num_regions - 1, 0, -1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
            if isrgn then
                reaper.DeleteProjectMarker(0, markrgnindexnumber, true)
            end
        end
    end
    
    for i, section in ipairs(template.structure) do
        -- Calculate length in seconds: bars * 4 beats * qn_dur
        -- Assuming 4/4 for simplicity, or we could support time sigs later
        local sec_dur = section.bars * 4 * qn_dur
        
        -- Add Region
        -- Resolves color ("cyan" -> {0,255,255}) using Architect.colors_rgb
        -- section.col is now the string key "cyan"
        local r, g, b = table.unpack(Architect.colors_rgb[section.col] or {255,255,255})
        local native_color = reaper.ColorToNative(r, g, b)
        
        local final_color = native_color | 0x1000000
        if r == 0 and g == 0 and b == 0 then final_color = 0 end -- Keep default if black/undefined

        reaper.AddProjectMarker2(0, true, cursor_pos, cursor_pos + sec_dur, section.name, -1, final_color)
        
        cursor_pos = cursor_pos + sec_dur
    end
    
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Apply Song Structure", -1)
end

-- ============================================================================
-- 3. GENERATE FULL SONG (The Magic Button)
-- ============================================================================


function Architect.getRegionProfile(name, color)
    local profile = { energy = 50, type = "Section" }
    
    local lower_name = string.lower(name)
    if string.find(lower_name, "chorus") or string.find(lower_name, "drop") then
        profile.energy = 90
        profile.type = "Chorus"
    elseif string.find(lower_name, "verse") then
        profile.energy = 50
        profile.type = "Verse"
    elseif string.find(lower_name, "intro") or string.find(lower_name, "outro") then
        profile.energy = 30
        profile.type = "Intro"
    elseif string.find(lower_name, "bridge") then
        profile.energy = 70
        profile.type = "Bridge" 
    elseif string.find(lower_name, "build") or string.find(lower_name, "rise") then
        profile.energy = 80
        profile.type = "Build"
    end
    
    return profile
end

function Architect.generateFullSong(Generators, Library, Theory, Utils, clear_tracks, root_note_idx, scale_name_str, regions_list, use_existing_chords, create_automation)
    reaper.Undo_BeginBlock()
    
    -- 1. Identify Regions (from Argument or Project)
    local regions = {}
    
    if regions_list then
        for _, r in ipairs(regions_list) do
            local start_p = r.start_pos
            local end_p = r.end_pos
            if not end_p and r.length then end_p = start_p + r.length end
            
            table.insert(regions, {
                start_pos = start_p,
                end_pos = end_p,
                name = r.name,
                color = r.color,
                energy = r.energy or 50
            })
        end
    else    
        local ret, num_markers, num_regions = reaper.CountProjectMarkers(0)
        for i = 0, num_markers + num_regions - 1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
            if isrgn then
                table.insert(regions, {
                    start_pos = pos,
                    end_pos = rgnend,
                    name = name,
                    color = color,
                    energy = Architect.GetEnergyLevel and Architect.GetEnergyLevel({name=name}) or 50
                })
            end
        end
    end
    
    if #regions == 0 then
        reaper.ShowMessageBox("No structure regions found! Please Sync from Project or Create Structure.", "Error", 0)
        reaper.Undo_EndBlock("Generate Full Song (Failed)", -1)
        return
    end
    
    -- Helper to delete tracks
    local function deleteTrackByName(name)
        local num_tracks = reaper.CountTracks(0)
        -- Iterate backwards to safely delete
        for i = num_tracks - 1, 0, -1 do
            local tr = reaper.GetTrack(0, i)
            local retval, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            if tr_name == name then
                reaper.DeleteTrack(tr)
            end
        end
    end

    -- 1.5. Prepare Tracks (Handle Existing Chords)
    local user_chords_track = nil
    if use_existing_chords then
        -- Find the FIRST track named "Chords" to keep
        local num_tracks = reaper.CountTracks(0)
        for i = 0, num_tracks - 1 do
            local tr = reaper.GetTrack(0, i)
            local retval, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            if tr_name == "Chords" then
                user_chords_track = tr
                break
            end
        end
        if not user_chords_track then
            reaper.ShowMessageBox("Use Existing Chords is checked, but no track named 'Chords' was found!", "Error", 0)
            reaper.Undo_EndBlock("Generate Full Song (Failed)", -1)
            return
        end
    end

    if clear_tracks then
        local num_tracks = reaper.CountTracks(0)
        for i = num_tracks - 1, 0, -1 do
            local tr = reaper.GetTrack(0, i)
            
            -- If keeping chords, skip the SPECIFIC user track
            if use_existing_chords and tr == user_chords_track then
                -- Do nothing
            else
                reaper.DeleteTrack(tr)
            end
        end
    end
    
    -- 2. Setup Tracks
    local template_path = reaper.GetResourcePath() .. "/TrackTemplates/Reanspiration/Gen Full Song.RTrackTemplate"
    local template_loaded = false
    
    -- Check if template exists and load it
    -- Note: Main_openProject can load track templates if extension is RTrackTemplate
    if reaper.file_exists(template_path) then
        reaper.Main_openProject(template_path)
        template_loaded = true
    end

    -- Cleanup Template Duplicates
    if use_existing_chords and user_chords_track then
         local num_tracks = reaper.CountTracks(0)
         for i = num_tracks - 1, 0, -1 do
             local tr = reaper.GetTrack(0, i)
             local retval, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
             -- If we find a "Chords" track that isn't our preserved user track, delete it (it's from the template)
             if tr_name == "Chords" and tr ~= user_chords_track then
                 reaper.DeleteTrack(tr)
             end
         end
    end

    local function getOrCreateTrack(name, color_int, existing_ref)
        if existing_ref then return existing_ref end
        
        -- Find existing track by name
        local num_tracks = reaper.CountTracks(0)
        for i = 0, num_tracks - 1 do
            local tr = reaper.GetTrack(0, i)
            local retval, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            if tr_name == name then return tr end
        end
        
        -- Fallback: Create New if not found in template or template failed
        reaper.InsertTrackAtIndex(num_tracks, true)
        local new_tr = reaper.GetTrack(0, num_tracks)
        reaper.GetSetMediaTrackInfo_String(new_tr, "P_NAME", name, true)
        if color_int then reaper.SetTrackColor(new_tr, color_int) end
        return new_tr
    end

    -- Attempt to find tracks (either loaded from template or created new)
    -- We assume the template uses these exact names.
    local track_chords = getOrCreateTrack("Chords", reaper.ColorToNative(0, 100, 255), user_chords_track)
    local track_melody = getOrCreateTrack("Melody", reaper.ColorToNative(255, 100, 200))
    local track_bass = getOrCreateTrack("Bass", reaper.ColorToNative(255, 150, 0))
    local track_drums = getOrCreateTrack("Drums", reaper.ColorToNative(200, 200, 200))

    -- Channel definitions
    local CH_CHORDS = 0
    local CH_MELODY = 0 
    local CH_BASS = 0
    local CH_DRUMS = 9 -- General MIDI Drums

    -- 3. Iterate Regions & Generate
    for _, rgn in ipairs(regions) do
        -- Calculate length in seconds first
        local length_sec = rgn.end_pos - rgn.start_pos
        
         if length_sec > 0 then
             local profile = Architect.getRegionProfile(rgn.name, rgn.color)
             
             -- DEBUG: Print params
             if i == 0 then -- only print once? But 'i' is marker index, loop uses ipairs index logic?
                 -- Let's just print for each region for now, or use a flag.
             end
             
             -- A. CHORDS: Create first to get PPQ reference
             local chord_item = reaper.CreateNewMIDIItemInProj(track_chords, rgn.start_pos, rgn.end_pos, false)
             local chord_take = reaper.GetActiveTake(chord_item)
             
             -- Now we can get PPQ range using this valid take
             -- New MIDI item starts at 0 PPQ relative to itself usually, but let's be safe
             local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(chord_take, rgn.start_pos)
             local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(chord_take, rgn.end_pos)
             local length_ppq = end_ppq - start_ppq

             -- Resolve Scale
             local scale_intervals = {0, 2, 4, 5, 7, 9, 11} -- Default Major
             
             -- Map scale name from string to simple interval table
             local scales_map = {
                 ["Major"] = {0, 2, 4, 5, 7, 9, 11},
                 ["Natural Minor"] = {0, 2, 3, 5, 7, 8, 10},
                 ["Harmonic Minor"] = {0, 2, 3, 5, 7, 8, 11},
                 ["Melodic Minor"] = {0, 2, 3, 5, 7, 9, 11},
                 ["Dorian"] = {0, 2, 3, 5, 7, 9, 10},
                 ["Phrygian"] = {0, 1, 3, 5, 7, 8, 10},
                 ["Lydian"] = {0, 2, 4, 6, 7, 9, 11},
                 ["Mixolydian"] = {0, 2, 4, 5, 7, 9, 10},
                 ["Locrian"] = {0, 1, 3, 5, 6, 8, 10}
             }
             
             local selected_intervals = scales_map[scale_name_str] or scales_map["Major"]
             local root = root_note_idx or 0
             local scale = {}
             for _, interval in ipairs(selected_intervals) do
                 table.insert(scale, (root + interval) % 12)
             end
             -- DO NOT SORT 'scale' HERE. We need scale[1] to equal Root Note for Chord Progression logic.
             
             -- Create a sorted version for Melody/Scale snapping functions which likely expect it
             local sorted_scale = {table.unpack(scale)}
             table.sort(sorted_scale)
             
             -- DEBUG OUTPUT (Updated to show both)
             local notes_str = ""
             for _, n in ipairs(scale) do notes_str = notes_str .. n .. " " end
             -- reaper.ShowConsoleMsg(string.format("Region: %s | Energy: %s | Root: %d | Scale: %s | Notes (Ordered): %s\n", rgn.name, profile.energy, root, scale_name_str, notes_str))
             
             local chords_data_list = {}
             
             if use_existing_chords then
                  -- === EXTRACT CHORDS FROM EXISTING TRACK ===
                  if track_chords then
                      local t_start = rgn.start_pos
                      local t_end = rgn.end_pos
                      
                      -- Iterate items in Chords track
                      local item_count = reaper.CountTrackMediaItems(track_chords)
                      for i = 0, item_count - 1 do
                           local src_item = reaper.GetTrackMediaItem(track_chords, i)
                           local s_pos = reaper.GetMediaItemInfo_Value(src_item, "D_POSITION")
                           local s_len = reaper.GetMediaItemInfo_Value(src_item, "D_LENGTH")
                           local s_end_pos = s_pos + s_len
                           
                           -- Check overlap
                           if s_pos < t_end and s_end_pos > t_start then
                                local tk = reaper.GetActiveTake(src_item)
                                if tk and reaper.TakeIsMIDI(tk) then
                                     -- Get Chords (uses Theory module usually available in global scope or via Generators?)
                                     -- Architect doesn't have direct access to 'Theory' unless it's global? 
                                     -- 'Theory' is usually Global in this script structure.
                                     if Theory and Theory.analyzeChordsAndScale then
                                          local c_list, _ = Theory.analyzeChordsAndScale(tk)
                                          
                                          -- Convert PPQ to Project Time relative to region start
                                          -- c_list has .startppq in item context.
                                          local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(tk, s_pos)
                                          local rgn_start_ppq_in_take = reaper.MIDI_GetPPQPosFromProjTime(tk, t_start)
                                          
                                          -- We want chords relative to Region Start (0 based for generation)
                                          -- Project PPQ of Chord = item_start_ppq + ch.startppq
                                          -- We need relative to Region Start PPQ.
                                          
                                          -- Simpler:
                                          -- Region Start PPQ (absolute)
                                          -- Chord Start PPQ (absolute)
                                          -- relative = Chord Abs - Region Abs
                                          
                                          -- But we need a reference take for Region Start PPQ? We can use tk.
                                          local rgn_start_abs_ppq = reaper.MIDI_GetPPQPosFromProjTime(tk, t_start)
                                          local rgn_end_abs_ppq = reaper.MIDI_GetPPQPosFromProjTime(tk, t_end)
                                          
                                          for _, ch in ipairs(c_list) do
                                               local ch_abs_start = item_start_ppq + ch.startppq
                                               local ch_abs_end = item_start_ppq + ch.endppq
                                               
                                               -- Clip to Region
                                               local use_start = math.max(ch_abs_start, rgn_start_abs_ppq)
                                               local use_end = math.min(ch_abs_end, rgn_end_abs_ppq)
                                               
                                               if use_end > use_start then
                                                    -- Valid chord in region
                                                    local new_ch = Utils.deepCopy(ch) -- Deep copy safety
                                                    new_ch.startppq = use_start - rgn_start_abs_ppq
                                                    new_ch.endppq = use_end - rgn_start_abs_ppq
                                                    new_ch.duration_multiplier = 4.0 -- default
                                                    table.insert(chords_data_list, new_ch)
                                               end
                                          end
                                     end
                                end
                           end
                      end
                      -- Sort by startppq
                      table.sort(chords_data_list, function(a,b) return a.startppq < b.startppq end)
                  end
             else
                  -- === GENERATE RANDOM CHORDS (Old Logic) ===
                  local ppq_per_bar = 960 * 4 -- Default 4/4
                 
                  -- Get actual QN from project to be precise
                  local start_qn = reaper.TimeMap2_timeToBeats(0, rgn.start_pos)
                  local end_qn = reaper.TimeMap2_timeToBeats(0, rgn.end_pos)
                  local qn_len = end_qn - start_qn
                  local ppq_per_qn = 960 -- Standard
                  if chord_take then ppq_per_qn = reaper.MIDI_GetPPQPosFromProjQN(chord_take, start_qn + 1) - reaper.MIDI_GetPPQPosFromProjQN(chord_take, start_qn) end
                 
                  ppq_per_bar = ppq_per_qn * 4
                  local num_bars = math.ceil(length_ppq / ppq_per_bar)
                  -- CRITICAL FIX: Use Relative PPQ (0 based) for chords generation
                  -- MIDI_InsertNote writes relative to Item Start.
                  local current_bar_ppq = 0 
                 
                  -- Generate a simple diatonic progression based on Scale Degrees
                  -- I - V - vi - IV (1 - 5 - 6 - 4)
                  local progression_degrees = {1, 5, 6, 4} 
                  if profile.energy < 40 then progression_degrees = {1, 5} end -- Simpler for intro
                  if profile.energy > 80 then progression_degrees = {1, 5, 6, 4} end -- Power loop (same as default for now)
                 
                  for b = 1, num_bars do
                      -- ... (existing loop content) ... 
                      local degree_idx = ((b-1) % #progression_degrees) + 1
                      local degree = progression_degrees[degree_idx]
                      local root_pc = scale[degree] or scale[1] or 0
                      
                      local third_pc = scale[((degree + 2 - 1) % #scale) + 1]
                      local fifth_pc = scale[((degree + 4 - 1) % #scale) + 1]
                      
                      local chord_obj = {
                          root_note_pc = root_pc,
                          chord_tones_pc = {[root_pc]=true, [third_pc]=true, [fifth_pc]=true}, 
                          chord = {root_pc, third_pc, fifth_pc},
                          startppq = current_bar_ppq,
                          endppq = current_bar_ppq + ppq_per_bar,
                          duration_multiplier = 4.0,
                          is_major = (third_pc - root_pc) == 4 or (third_pc - root_pc) == -8
                      }
                      table.insert(chords_data_list, chord_obj)
                      current_bar_ppq = current_bar_ppq + ppq_per_bar
                  end
                  
                  -- Voicing Type based on energy (Apply only when generating)
                  local voicing = "Closed"
                  if profile.energy > 60 then voicing = "Drop 2" end
                  if #chords_data_list > 0 then
                       Generators.createMIDIChords(chord_take, chords_data_list, start_ppq, length_ppq, CH_CHORDS, 0.5, voicing)
                  end
             end
             
             -- DEBUG CHORDS
             local chord_roots_str = ""
             for _, c in ipairs(chords_data_list) do chord_roots_str = chord_roots_str .. c.root_note_pc .. " " end


             local analyzed_chords = chords_data_list 

             if #analyzed_chords > 0 then
                 -- B. BASS
                 local bass_item = reaper.CreateNewMIDIItemInProj(track_bass, rgn.start_pos, rgn.end_pos, false)
                 local bass_take = reaper.GetActiveTake(bass_item)
                 Generators.generateBass(bass_take, analyzed_chords, scale, start_ppq, length_ppq, CH_BASS, profile.energy)
                 
                 -- C. DRUMS
                 local drum_item = reaper.CreateNewMIDIItemInProj(track_drums, rgn.start_pos, rgn.end_pos, false)
                 local drum_take = reaper.GetActiveTake(drum_item)
                 
                 local drum_p_idx = 1
                 if profile.energy > 80 then drum_p_idx = math.min(3, #Library.drum_patterns)
                 elseif profile.energy > 50 then drum_p_idx = 1 
                 else drum_p_idx = 2 end 
                 
                 if Library and Library.drum_patterns and Library.drum_patterns[drum_p_idx] then
                     local p_data = Library.drum_patterns[drum_p_idx].pattern
                     Generators.generateAndInsertDrums(drum_take, start_ppq, length_ppq, p_data, CH_DRUMS)
                 end

                 -- D. MELODY
                 if profile.energy > 40 then
                     local mel_item = reaper.CreateNewMIDIItemInProj(track_melody, rgn.start_pos, rgn.end_pos, false)
                     local mel_take = reaper.GetActiveTake(mel_item)
                     
                     local den = 4
                     if profile.energy > 70 then den = 7 end
                     local oct_min = 4
                     if profile.energy < 50 then oct_min = 3 end
                     
                     local melody_events = Generators.generateMelody(mel_take, chords_data_list, scale, den, oct_min, oct_min+1, start_ppq, length_ppq, "Arch", nil, nil)
                     
                     if melody_events then
                         for _, ev in ipairs(melody_events) do
                             reaper.MIDI_InsertNote(mel_take, false, false, ev.pos, ev.pos + ev.length, CH_MELODY, ev.note, ev.velocity, true)
                         end
                     end
                     reaper.MIDI_Sort(mel_take)
                 end
                 
                 reaper.MIDI_Sort(bass_take)
                 reaper.MIDI_Sort(drum_take)
             end
        end
    end
    
    reaper.UpdateArrange()

    -- 4. Post-Generation Actions
    if track_drums then
        -- Count tracks BEFORE loading template to know which ones are new
        local track_count_before = reaper.CountTracks(0)
        
        reaper.SetOnlyTrackSelected(track_drums)
        local base_path = reaper.GetResourcePath() .. "/TrackTemplates"
        local final_template_path = base_path .. "/Reanspiration/Reanspiration_Ex_Song_Track.RTrackTemplate"
        if not reaper.file_exists(final_template_path) then
             final_template_path = base_path .. "/Reanspiration_Ex_Song_Track.RTrackTemplate"
        end
        
        if reaper.file_exists(final_template_path) then
            reaper.Main_openProject(final_template_path)
            
            -- Fill Empty MIDI Items for NEW tracks
            local track_count_after = reaper.CountTracks(0)
            
            -- Iterate through newly added tracks
            for t_idx = track_count_before, track_count_after - 1 do
                local tr = reaper.GetTrack(0, t_idx)
                if tr then
                     -- Iterate Regions to create empty items matching structure
                     for _, rgn in ipairs(regions) do
                         local length_sec = rgn.end_pos - rgn.start_pos
                         if length_sec > 0 then
                             local item = reaper.CreateNewMIDIItemInProj(tr, rgn.start_pos, rgn.end_pos, false)
                             -- Optional: Set item name to region name? 
                             -- reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(item), "P_NAME", rgn.name, true)
                         end
                     end
                end
            end
        end
    end

    -- Helper to apply automation
    local function applyAutomation(track)
        if not track or not create_automation then return end
        
        -- Check if envelope exists first
        local env = reaper.GetTrackEnvelopeByName(track, "Volume")
        
        if not env then
             -- Select ONLY this track to ensure toggle applies to it
             reaper.SetOnlyTrackSelected(track)
             reaper.Main_OnCommand(40406, 0) -- Track: Toggle track volume envelope visible
             env = reaper.GetTrackEnvelopeByName(track, "Volume")
        end
        
        if not env then return end
        
        -- Clean existing points in song range (or all)
        local end_time = 0
        if regions and #regions > 0 then end_time = regions[#regions].end_pos + 10 end
        reaper.DeleteEnvelopePointRange(env, 0, end_time)
        
        for _, rgn in ipairs(regions) do
            local e = rgn.energy or 50
            
            -- Map Energy to dB
            -- Energy 90 -> 0dB
            -- Energy 50 -> -6dB
            -- Energy 30 -> -12dB
            
            local target_db = -6.0 -- Default
            if e >= 90 then target_db = 0.0
            elseif e >= 70 then target_db = -3.0
            elseif e >= 50 then target_db = -6.0
            elseif e >= 30 then target_db = -12.0
            else target_db = -24.0
            end
            
            -- Convert dB to Linear Gain (1.0 = 0dB)
            local linear_val = 10 ^ (target_db / 20)

            -- Convert Linear Gain to Fader Scaling Value
            local scaling_mode = reaper.GetEnvelopeScalingMode(env)
            local pt_val = reaper.ScaleToEnvelopeMode(scaling_mode, linear_val)
            
            -- Shape 1 = Square (Hold value until next point)
            reaper.InsertEnvelopePoint(env, rgn.start_pos, pt_val, 1, 0, false, true)
        end
        reaper.Envelope_SortPoints(env)
    end

    -- Apply Automation if requested
    if create_automation then
        applyAutomation(track_chords)
        applyAutomation(track_bass)
        applyAutomation(track_melody)
        applyAutomation(track_drums)
    end

    reaper.Undo_EndBlock("Generate Full Song", -1)
end


-- ============================================================================
-- 5. ARRANGER KING BRIDGE
-- ============================================================================

-- ============================================================================
-- 5. ARRANGER KING BRIDGE
-- ============================================================================

function Architect.ScanArrangerKingGuideTrack(guide_item)
    if not guide_item then return false, "No item selected" end
    local take = reaper.GetActiveTake(guide_item)
    
    if not (take and reaper.TakeIsMIDI(take)) then
        return false, "Selected item is not MIDI"
    end
    
    local item_start_pos = reaper.GetMediaItemInfo_Value(guide_item, "D_POSITION")
    local ret, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    
    local detected_sections = {}
    local section_map = {
        ["verse"] = {col="green", name="Verse"},
        ["chorus"] = {col="red", name="Chorus"},
        ["drop"] = {col="red", name="Drop"},
        ["hook"] = {col="red", name="Hook"},
        ["intro"] = {col="cyan", name="Intro"},
        ["outro"] = {col="grey", name="Outro"},
        ["bridge"] = {col="purple", name="Bridge"},
        ["pre"] = {col="yellow", name="Pre-Chorus"},
        ["solo"] = {col="yellow", name="Solo"},
        ["build"] = {col="orange", name="Build-up"},
        ["break"] = {col="blue", name="Breakdown"},
        ["air"] = {col="grey", name="Air"}
        -- Add more mappings based on AK standard
    }
    
    -- MODE A: Scan for Text Events (Strict Mode)
    for i = 0, textsyxevtcnt - 1 do
        local retval, selected, muted, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, i, nil, nil, 0, 0, "")
        if type >= 1 and type <= 7 then -- Text events
            -- Use pattern match to trim whitespace
            local name = msg:gsub("[\r\n]", ""):match("^%s*(.-)%s*$")
            local lower_name = name:lower()
            -- Strict Match Check
            local best_match = nil
            for key, data in pairs(section_map) do
                if lower_name:find(key) then best_match = data; break end
            end
            
            -- Only add if it strictly matches a known section type
            if best_match then
                local proj_pos = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
                table.insert(detected_sections, {
                    pos = proj_pos,
                    name = best_match.name,
                    col = best_match.col
                })
            end
        end
    end
    
    -- MODE B: Smart Height Analysis (Fallback)
    if #detected_sections == 0 and notecnt > 0 then
        -- 1. Cluster Notes into Sections
        local clusters = {}
        local current_cluster = nil
        local time_tolerance = 0.1 -- 100ms
        
        for i = 0, notecnt - 1 do
            local _, _, _, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
            local start_t = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
            local end_t = reaper.MIDI_GetProjTimeFromPPQPos(take, end_ppq)
            
            if current_cluster and math.abs(start_t - current_cluster.start_t) <= time_tolerance then
                -- Add to current cluster
                if pitch < current_cluster.min_p then current_cluster.min_p = pitch end
                if pitch > current_cluster.max_p then current_cluster.max_p = pitch end
                if end_t > current_cluster.end_t then current_cluster.end_t = end_t end
                current_cluster.note_count = current_cluster.note_count + 1
            else
                -- Finalize previous
                if current_cluster then table.insert(clusters, current_cluster) end
                -- Start new
                current_cluster = {
                    start_t = start_t,
                    end_t = end_t,
                    min_p = pitch,
                    max_p = pitch,
                    note_count = 1
                }
            end
        end
        if current_cluster then table.insert(clusters, current_cluster) end
        
        -- 2. Map Clusters to Sections
        for i, c in ipairs(clusters) do
            local height = c.max_p - c.min_p
            
            -- FILTER: Ignore clusters smaller than 2 octaves (24 st)
            -- This filters out single notes (Height 0) or small intervals 
            -- which cause fragmentation errors (as seen in user issue).
            if height >= 24 then
                local matched_section = nil
                
                -- Check map with tolerance
                for h_val, data in pairs(Architect.ak_height_map) do
                    if math.abs(height - h_val) <= 1 then
                        matched_section = data
                        break
                    end
                end
                
                local sec_name = "Unknown"
                local sec_col = "grey"
                
                if matched_section then
                    sec_name = matched_section.name
                    sec_col = matched_section.col
                else
                    sec_name = "Section (H:" .. height .. ")"
                end
                
                table.insert(detected_sections, {
                    pos = c.start_t,
                    end_pos = c.end_t,
                    name = sec_name,
                    col = sec_col,
                    is_note = true
                })
            end
        end
    end
    
    table.sort(detected_sections, function(a,b) return a.pos < b.pos end)
    
    if #detected_sections == 0 then
        return false, T("ak_scan_failed_no_markers") or "No markers found"
    end
    
    -- 3. Create Regions
    reaper.Undo_BeginBlock()
    
    -- CLEAR EXISTING REGIONS: Prevent overlap when rescanning
    local r_idx = 0
    while true do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(r_idx)
        if retval == 0 then break end
        if isrgn then
            reaper.DeleteProjectMarker(0, markrgnindexnumber, true)
            -- List shifted, so check index 0 again (or current index)
        else
            r_idx = r_idx + 1
        end
    end
    
    local item_end_pos = item_start_pos + reaper.GetMediaItemInfo_Value(guide_item, "D_LENGTH")
    
    for i, sec in ipairs(detected_sections) do
        local start_p = sec.pos
        local end_p = item_end_pos
        
        -- BRIDGE GAPS: Always extend to next section start to prevent holes
        if i < #detected_sections then
            end_p = detected_sections[i+1].pos
        else
            -- Last section: Use actual end (for notes) or item end
            if sec.is_note then end_p = sec.end_pos end
        end
        
        -- Add Region
        local r, g, b = table.unpack(Architect.colors_rgb[sec.col] or {200,200,200})
        local native_color = reaper.ColorToNative(r, g, b) | 0x1000000
        
        reaper.AddProjectMarker2(0, true, start_p, end_p, sec.name, -1, native_color)
    end
    
    reaper.Undo_EndBlock("Sync with Arranger King", -1)
    reaper.UpdateArrange()
    
    return true, "Synced " .. #detected_sections .. " sections."
end

return Architect
