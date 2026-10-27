# Crash sweep — Cue Export, October 2026

Investigation of why the REAPER "Cue Export" scripts keep crashing. Everything
below is derived from the actual crash reports on this machine
(`~/Library/Logs/DiagnosticReports/REAPER*.ips`, 48 of them) and the 60 JVM
`hs_err_pid*.log` files in `~/Library/Application Support/REAPER/UserPlugins/`,
correlated with `JK_export_trace.log`, `_export_log.tsv` and the project
`1M04 - The Birds - v03.01.07.RPP`.

**Short version:** there are four unrelated crash families, not one. Only two of
them have anything to do with the export. One (render dialog + muted track) is
already fixed by the uncommitted change in `jk_export.lua`. The one that killed
the 19:43 run is a **stack overflow inside iZotope Neutron 3 on REAPER's 512 KB
render worker thread**, triggered by the ORCH stem set. The rest is plug-in
teardown noise that happens with or without the script.

---

## 1. Census

### 1.1 macOS crash reports (48: 29 `SIGABRT`, 19 `SIGILL`)

| # | top frame after `_sigtramp` | when | verdict |
|---|---|---|---|
| 8 | `RenderProcessDialog_InitialSetup` → `CalcChannelCountForTrack` | Oct 23 07:12, 18:06–19:02 | **export family A** |
| 8 | `RenderProcessDialog_InitRenderRange` → `CalcChannelCountForTrack` | Oct 18 15:08, Oct 26 14:44–15:11 | **export family A** |
| 1 | `iZNeutron3` (stack guard page) | Oct 26 19:43 | **export family B** |
| 1 | `libsystem_malloc` `___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED` | Oct 26 17:03 | **family C** heap corruption |
| 1 | `SINE Player` | Oct 23 21:24 | family C |
| 5 | `__pthread_kill` with no deeper frame | Oct 20–26 | family C / handler |
| 4 | `libjvm` `LogConfiguration::describe_current_configuration` (thread `Java: VM Thread`) | Oct 20, 23 | family C / handler |
| **19** | **`SIGILL`** at wildly different frames: `LICE_FillRect`, `LICE_DrawGlyphEx`, `_LICE_Template_Blit*`, `CoreGraphics RGBAf16_image_mark` / `x_list_remove` / `log_buffer_check_in_crash_reporter`, `_platform_memmove`, `vImage`, `small_free_list_remove_ptr`, `objc_retain` / `objc_msgSend` / `weak_resize`, `__CFBasicHashAddValue`, `CFArrayContainsValue`, `probeGC`, `NSCoreTypesetter`, `kevent_id` ×3 | Oct 20–26, bunched Oct 23 19:09–21:51 | **almost all are the crash handler faulting while unwinding an earlier crash** — secondary reports |

(All 48 `.ips` files are from Oct 20 onward — macOS rotates older ones — so the
Aug/Sep history only survives in the `hs_err` logs.)

### 1.2 JVM `hs_err` files (60)

These are not Java bugs. Reaper has a full **Temurin 25 JRE loaded in-process**
(`~/Library/Application Support/REAPER/UserPlugins/java-runtime/…/libjvm.dylib`)
because **DrivenByMoss** is installed. That JVM installs process-wide signal
handlers, so *any* fatal signal in REAPER gets caught by `JVM_handle_bsd_signal`,
written out as `hs_err_pid<pid>.log`, and then turned into `abort()` →
`SIGABRT`.

That explains three misleading things in every report:

* the signal always looks like `SIGABRT`, and frames 3–7 are always `libjvm`;
* `hs_err_pid<pid>.log` is written into `UserPlugins/` (REAPER's cwd);
* the *real* faulting module only appears below `_sigtramp` (in the `.ips`) or as
  `# Problematic frame` (in `hs_err`).

Tally of the 60 `hs_err` files by real frame:

| # | frame | notes |
|---|---|---|
| 19 | `CalcChannelCountForTrack(int,int,MediaTrack*,RenderRange*)` | Sep 24, Oct 18, Oct 23 (9), Oct 26 (8) |
| 15 | `libobjc` `lookUpImpOrForward+0x54` | dangling ObjC object |
| 7 | `DecentSampler` `GetPluginFactory+0xe6570` | |
| 4 | `REAPER GetRulerMarks_Beats` | |
| 4 | `libobjc` `class_rw_t::ro()` | |
| 3 | `WDL_VWnd::IsDescendent` | UI |
| 3 | `Kontakt 7` | |
| 2 | `vst3ContextState::run` | |
| 1 | `___chkstk_darwin` | Oct 26 19:43 — the stack overflow |
| 1 | `pthread_mutex_lock` | |
| 1 | `getIvar` | |

`CalcChannelCountForTrack` appears under two different `REAPER+0x…` offsets
(`0x4aab08` and `0x4b23e0`), i.e. it spans a REAPER update — this crash predates
and outlives the script.

---

## 2. Family A — render dialog + a **muted** track (**proven, already fixed**)

`jk_export.lua` drives renders with action **42230**, which *does* construct
REAPER's render dialog (`RenderDialog` → `SWELL_DialogBox` → `RenderWavProc` →
`RenderProcessDialog_InitRenderRange`). The script's own comment at
`render_pass()` says as much ("Every render action opens REAPER's render
dialog").

The crash stack is unambiguous (`Retired/REAPER-2026-10-26-151109.ips`):

```
lua_pcallk → Main_OnCommand(42230) → OnRenderCommand → RenderDialog
→ SWELL_DialogBox → RenderWavProc → RenderProcessDialog_InitRenderRange
→ CalcChannelCountForTrack(...)          SIGSEGV, KERN_INVALID_ADDRESS at 0x1208
```

`0x1208` is a field offset on a **NULL `MediaTrack*`**. So: the render source is
"selected tracks (stems)", the dialog walks the selection, and something in the
selection has no track behind it.

### The bisect already proved which selection

`JK_export_trace.log`:

```
15:07:02  BISECT stage 2: nothing changed ... + source 524416, bounds time selection
15:07:16  BISECT stage 2 returned                      ← OK
15:07:26  BISECT stage 3: nothing changed ... + marked tracks selected
15:07:26  BISECT stage 3 about to open render          ← crash (hs_err 15:07:26)

15:10:19  BISECT stage 1: render source 524416 + time selection, NO tracks selected
15:10:32  BISECT stage 1 returned                      ← OK
15:10:37  BISECT stage 2: + the UNMUTED marked tracks selected
15:10:57  BISECT stage 2 returned                      ← OK
15:11:04  BISECT stage 3: + the MUTED marked tracks selected too
15:11:04  BISECT stage 3 about to open render          ← crash (hs_err 15:11:05)
```

Zero tracks selected: fine. Unmuted marked tracks selected: fine. **Add one
muted marked track: instant null-deref in the render dialog.** Reproduced twice,
30 s apart, with nothing else changed.

### Status

The uncommitted `marked_tracks()` change (line 91, plus the comment at line 94)
filters `t.muted`, and `leaf_tracks()` (line 1045) does the same for multitrack.
That is the correct workaround and the bisect validates it: the very next run
(`15:15:31`, 3 marked tracks instead of 5) completed stems + master + mix minus
+ click end to end.

Two follow-ups worth knowing:

1. **It is a REAPER bug, not a script bug.** Anyone opening the render dialog by
   hand with a muted track selected can hit it — the 19 `CalcChannelCountForTrack`
   `hs_err` files since Sep 24 include times when no export was running.
   Worth reporting to Cockos with this stack.
2. **The filter must be re-evaluated at the moment of selection, not at scan
   time.** `stems_job` mutes the marked tracks for the mix-minus pass and
   `multitrack_job` mutes the `Effects` folder for the dry pass. Today every
   subsequent `render_pass` that uses a selection happens either before those
   mutes or with `settings = 0` (master, no selection), so it is safe — but it is
   one refactor away from re-introducing the crash. A guard inside `select_only()`
   that drops muted tracks (and logs it) would make it structural.

---

## 3. Family B — the actual 19:43 crash: **stack overflow in Neutron 3**

Files: `REAPER-2026-10-26-194406.ips` (captured **19:43:16**, 15 s after the
render started; the filename is 50 s later, when the report was written) and
`UserPlugins/hs_err_pid57345.log`.

```
Thread 671  "*/mediaafx"   (REAPER worker: WorkerThreadInst::threadProc)
  ... 49 × MediaTrack::RenderSamples_nocache / RenderSamples  (~100 frames)
  FxChain::ProcessChain → FxDsp::processFxDsp → VST_HostedPlugin::ProcessSamples
  VST_HostedPlugin::VST3_Process<float> → PluginHooksVST3 → iZNeutron3 ×5
  ___chkstk_darwin + 0x3c          ← fault
  _sigtramp → JVM_handle_bsd_signal → VMError → abort
```

`hs_err_pid57345.log`:

```
Stack: [0x0000000a85c04000, 0x0000000a85c87000], sp=0x0000000a85c120e0, free space=56k
siginfo: SIGBUS, BUS_ADRALN, si_addr = 0x0000000a85c03ff8
```

### What that means, exactly

* The stack region is `0x83000` bytes = **524 KB**. That is REAPER's worker-thread
  stack size, not a plug-in's.
* `sp` is 56 KB above the bottom, i.e. **89 % of the stack was already gone**.
* `si_addr` is `0x…3ff8`, **8 bytes below the stack base** — the guard page.
* The faulting instruction is `___chkstk_darwin`, the compiler's stack-probe
  helper: Neutron 3 was growing a large stack frame when it walked off the end.

So this is not a Neutron DSP bug and not bad audio data. It is
**"render thread stack too small for this graph + this plug-in"**, and Neutron 3's
large frame is what tips it over. The `.ips` also shows why the frame probe had
so little room: ~49 nested track-render frames below it.

### Why *this* track

The failing render is the ORCH stem pass of `v03.01.07`. Marked tracks are the
leading all-caps `REC`/`TR` tokens → **14 tracks**, which matches the 14 zero-byte
wavs written at 19:43 in
`exports/1M04 - The Birds - v03.01.07/1M04 - The Birds - v03.01.07 ORCH/`:

```
REC SampledOrgan.wav          ← track 97, the one with Neutron 3 VST3
REC partials_Track 4-001/002/003.wav
REC partials_Track 4 [C3]/[D3]/[A3]/[B3].wav
REC partials_Track 4 [F#3]-001/-002.wav
REC partials_Track 4 [G3]-001/-002.wav
REC partials_Track 6-001/-002.wav
```

Track 97 `REC SampledOrgan` carries, in order, **SINE Player → Neutron 3 (VST3)**
and has 2 items in the cue. It is one of only 6 Neutron 3 instances in the
project:

| track | name | instance | muted |
|---|---|---|---|
| 22 | fujara | AU | no |
| 82 | church bell | AU | no |
| 83 | church bell | AU | no |
| **97** | **REC SampledOrgan** | **VST3** | **no — in the ORCH set** |
| 98 | partials | VST3 | no (folder) |
| 114 | SampledOrgan | VST3 | no |

Only 97 is marked, so only 97 is in the crash pass. The crashing instance is the
**VST3** one; the three AU instances are outside the ORCH set, so this run says
nothing about them either way.

### Why 49 nested frames

There is no send loop to blame: the project has **6 `AUXRECV` and 0 `AUXSEND`,
longest routing chain = 2**, max folder depth 5. So the depth is REAPER's own
per-pass track walk in the "fast" mode used by the Film ORCH preset
(`RENDER_SETTINGS = 524416` = selected-tracks-via-master **+ "fast", all stems in
one pass**). 14 selected tracks, several of them folder parents that contain other
selected tracks, rendered simultaneously in a single recursive pass. That is the
one setting that differs between "works" and "stack overflow".

### What to do (in order)

1. **Prove it in 2 minutes.** `M.run{ jobs={"orch"}, slow_stems=true }` (already
   supported, `STEMS_SETTINGS_SLOW = 128`, line 14) renders one track at a time.
   Use the picker, or a two-line test script. If it completes, the crash is the
   fast multi-track pass, full stop.
2. **Get Neutron 3 out of the stem path** — the only permanent fix. Either freeze /
   render that track, move Neutron to a bus, or replace it with Neutron 4/5.
   Neutron 3 is a 2019 plug-in and the stack footprint is the problem, not the
   algorithm.
3. **A script-level guard** (choose deliberately, it changes the audio): during
   render, set `B_PASS` / FX bypass on any FX whose name matches
   `Neutron 3 (iZotope)` on the rendered tracks, restore afterwards, and warn in
   the summary. Do **not** do this silently — the stem would no longer match the
   master.
4. There is no way to enlarge REAPER's worker stack from a script, so "raise the
   limit" is not an option.

---

## 4. Family C — everything else

These are not export bugs; they are the project's plug-in estate.

* **`libobjc lookUpImpOrForward` (15 logs)** — an Objective-C message to a
  deallocated object. Classic plug-in UI teardown / dangling timer. Always the
  same address under the same build, so it is one specific plug-in, not random.
* **`DecentSampler GetPluginFactory+0xe6570` (7 logs, Aug 20–Sep 10)** — inside
  the plug-in's own factory code.
* **`Kontakt 7 QApplication::~QApplication` (3 logs)** — crashing *while
  destroying* Kontakt's Qt app object, i.e. on quit/instance destruction only.
* **`___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED`**
  (Oct 26 17:03, `SkyLight displayWillConfigNotifyProc`) — heap corruption
  surfacing in a CoreGraphics display callback. Real corruption from some plug-in,
  just detected late.
* **The `SIGILL` burst on Oct 23 19:09–21:51** — `LICE_FillRect`,
  `CoreGraphics RGBAf16_image_mark`, `objc_retain`, `CFBasicHashAddValue`,
  `UIFoundation …typeset`, with the process thread count falling 602 → 60 across
  the burst. These are the JVM crash handler faulting while it is already
  unwinding/writing a report for an earlier crash — secondary reports, not
  separate bugs. Their thread counts and timestamps interleave with the primary
  ones.

Practical consequence: **the October 23 "8 crashes in an hour" was mostly one
crash family plus its handler's aftershocks**, not 8 independent failures.

---

## 5. Project-level risk factors (`v03.01.07`)

These are what make this project, specifically, the one that crashes:

| | |
|---|---|
| tracks | **255** |
| muted | **92** (73 named `*** archived ***`) |
| tracks with no items | **197** |
| tracks with FX | 209 |
| plug-in instances | **293**, incl. **33 Kontakt 7**, 8 DecentSampler, 8 Serum 2, 7 SINE Player, 3 VSL Synchron Player, 6 Neutron 3, 2 UVI Workstation |
| threads at crash | **680** (8-core / 16 GB machine) |

680 threads is extreme. 351 of them are 39 identical nine-thread worker sets
(`AuxProcess #1–7`, `DB3ScanThread`, `InfoPaneManager Worker`) — one per loaded
instance of an NI-family instrument. Add 64 `WavePlayers`, 17 `Renderer`,
8 `Sample Loading Thread`, 8 `OnlineManager TaskRunner`, and ~22 Java threads
from DrivenByMoss.

Nothing here is wrong with the script, but it means every render pass has 293
plug-ins resident and only 512 KB of stack per worker. Archiving tracks (the
`JK - Select unused tracks and archive them.lua` flow) is not cosmetic — it
directly reduces the crash surface. The 73 archived tracks are still fully
loaded with instruments because their *tracks* are muted, not their *FX*.

---

## 6. Script-level bugs found while sweeping

Not crash causes, but real and cheap to fix.

### 6.1 Export timecode is one frame behind REAPER's (confirmed on disk)

`_export_log.tsv` records the cue start as **`10.07.23.06`**; every file REAPER
wrote at 19:43 is named **`… - 10.07.23.05 - …`**. Same run, same region
(`0.000000`), one frame apart.

`start_timecode()` (line 484) is
`reaper.format_timestr_pos(region.start, "", 5)`. REAPER's own `$starttc`
pattern variable is computed on a different code path, and the two disagree by a
frame here. The precondition is present: the project's offset is
`PROJOFFS 36479.693350000001`, i.e. deliberately *not* frame-aligned, so
round-to-nearest and floor-to-frame cannot agree.

Consequence: `expected_tc` never matches the files REAPER actually writes, so

* `have(...)` (line 972 etc.) always reports the stems as missing →
  `clear_old(...)` deletes and re-renders them every run, and
* `--resume` can never keep a stem step.

This is the same one-frame offset `tools/NOTES.md` §1.1 records for the click
(`10.01.05.17` vs `.18`) — it is not a click bug, it is this mismatch, and it
also affects `smpte_offset()`.

Fix: stop pre-computing the expected timecode. The stems pass already recovers
the true `tc` from the first rendered filename (line 986); do the same for the
reference passes, or add a small floor-consistent epsilon, or read `PROJOFFS`
and format it the way the render dialog does.

Related: `smpte_offset()` (line 320) ignores the `dropFrame` return of
`TimeMap_curFrameRate` and never sets the drop-frame bit in the MIDI SMPTE
offset meta event. On 29.97 projects the timecode in the `.mid` will drift from
the wav names. Signature confirmed against the ReaScript docs:
`number retval, boolean dropFrame = reaper.TimeMap_curFrameRate(proj)`.

(For the record: `reaper.TimeMap_GetTimeSigAtTime` at line 337 *is* correct —
Lua returns `timesig_num, timesig_denom, tempo` with no leading retval:
`integer timesig_num, integer timesig_denom, number tempo = …`. No bug there.)

### 6.2 Duplicate stem names → silent overwrite

Three marked tracks are all called `REC partials_Track 4` (tracks **99, 105,
110**), and two pairs share `[F#3]` (101/107) and `[G3]` (102/108). REAPER
disambiguates with `-001`, `-002`, `-003`, so all 14 files exist — but
`_… - REC partials_Track 4-001.wav` is a *folder parent* and `-003` is a leaf,
and nothing downstream can tell them apart. The stem checker's
`<folders>_<track>` contract can't map them either. Either refuse to export
duplicate-marked names (with a message box naming the tracks) or append the
track number.

### 6.3 Double-counting: folder parents are marked as stems

Tracks **99** and **105** are folder parents *and* carry the `REC` token, and
their children (100–103, 106–109) are marked too. A folder-parent stem already
contains its children, so `sum(stems) + MIX MINUS != MASTER` — the null test in
`tools/SPEC.md` §2.6 cannot pass on this cue by construction. `marked_tracks()`
should drop a marked track when an ancestor is also marked (keep the ancestor,
or keep the children, but not both).

### 6.4 `pause()` busy-waits the main thread

`pause()` (line 749) is `while reaper.time_precise() - t0 < ctx.delay do end`.
It blocks the SWELL message loop entirely — the opposite of what you want around
a render dialog. It is a no-op by default (`delay = 0`), but if it is ever turned
on, use `reaper.defer` between passes, not a spin.

### 6.5 `msg()` is a no-op

Line 23: `local function msg() end`. All the progress/`describe_render` output
(line 232) is discarded, so the export is completely silent until it finishes or
dies. During a crash investigation that is the worst possible default — the trace
file is the only witness.

### 6.6 `I_FOLDERDEPTH == 1` is not a safe "is a folder parent" test

`scan_tracks()` (line 78) pushes the folder stack only when
`depth == 1`, and pops `-depth` levels otherwise. It works for this project (all
parents are `ISBUS 1 1`), but a track that both opens a folder and closes
previous ones has `I_FOLDERDEPTH` 0 (the two deltas cancel), so it would be
neither pushed nor popped and `stack` / `mutes` / `level` would silently drift.
`leaf_tracks()` makes the same assumption with `t.depth ~= 1`. Cheap hardening:
walk the list with an explicit `opens_folder` flag derived from the RPP
`ISBUS`/`I_FOLDERDEPTH` pair, and pop `max(0, -depth)` levels independently of
the push.

---

## 7. Test plan

1. `slow_stems = true` on `v03.01.07` ORCH → confirm family B disappears.
2. Re-run ORCH with track 97's Neutron bypassed → confirm.
3. Re-run ORCH on `penny_003` (the project the bisect used) → should still pass;
   it has no Neutron.
4. After 6.1: check `_export_log.tsv` timestamp == stem filename timestamp, and
   that a second run reports `stems (kept)`.
5. After 6.3: re-check the null test in `tools/check_stems.py` on a small cue.

## 8. TL;DR for the next session

* **Muted tracks + render dialog = REAPER null-deref.** Already worked around;
  keep it, and move the guard into `select_only()`.
* **The 19:43 crash is a 512 KB-stack overflow in the render worker, made fatal by
  Neutron 3 VST3 on track 97 `REC SampledOrgan`, in the "fast" all-stems-in-one-pass
  ORCH render.** Not the Lua. Test with `slow_stems`, fix by removing Neutron 3
  from the marked set.
* Everything else in the 60 `hs_err` files is plug-in teardown noise, and every
  crash looks like a Java crash because DrivenByMoss's JVM hijacks the signal
  handler.
* Two real export bugs independent of the crashes: the **one-frame timecode**
  mismatch (breaks resume/keep) and **duplicate stem names / double-counted folder
  parents** (breaks the checker's contract).

### Appendix — how to re-derive this

```sh
# crash census
python3 - <<'EOF'
import glob,json,os
for f in glob.glob(os.path.expanduser('~/Library/Logs/DiagnosticReports/**/REAPER*.ips'), recursive=True):
    d=json.loads(open(f).read().split('\n',1)[1])
    th=d['threads'][d['faultingThread']]; imgs=d['usedImages']
    fr=[f"{imgs[x['imageIndex']]['name']} {x.get('symbol','')}" for x in th['frames']]
    i=next((n for n,s in enumerate(fr) if 'sigtramp' in s),0)
    print(d['captureTime'][:19], d['exception'].get('signal'), fr[i+1][:80])
EOF

# hs_err census
grep -A1 "# Problematic frame:" ~/Library/Application\ Support/REAPER/UserPlugins/hs_err_pid*.log

# what the script was doing when it died
tail -20 ~/Library/Application\ Support/REAPER/JK_export_trace.log

# which tracks carry Neutron / are marked REC|TR
grep -n "Neutron" "…/1M04 - The Birds - v03.01.07.RPP"
```
