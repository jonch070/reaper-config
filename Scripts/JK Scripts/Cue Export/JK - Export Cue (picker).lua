-- @description Pick which cue exports to run (Improve, Orch, multitrack dry/wet), render now or queue
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local export = dofile(script_path .. "jk_export.lua")

local SECTION = "JK_ExportCue"
local OPTIONS = {
    { key = "prox", label = "PROX  (subproject proxy: save + render RPP-PROX)" },
    { key = "improve", label = "IMPROVE  (IM tracks: stems, master, mix minus, MIDI)" },
    { key = "orch", label = "ORCH  (REC / TR tracks: stems, master, mix minus, MIDI)" },
    { key = "multitrack_dry", label = "Multitrack DRY  (all lowest tracks via master, Effects muted)" },
    { key = "multitrack_wet", label = "Multitrack WET  (all lowest tracks via master)" },
}

local function load_flag(key, default)
    local v = reaper.GetExtState(SECTION, key)
    if v == "" then return default end
    return v == "1"
end
local function save_flag(key, value) reaper.SetExtState(SECTION, key, value and "1" or "0", true) end

local picked = {}
for _, o in ipairs(OPTIONS) do picked[o.key] = load_flag(o.key, false) end
local queue, midi = load_flag("queue", false), load_flag("midi", true)
local midi_only = load_flag("midi_only", false)
local resume = load_flag("resume", false)
local replace = load_flag("replace", false)
local remove_click = load_flag("remove_click", false)
local archive_first = load_flag("archive_first", false)
local freeze_ui = load_flag("freeze_ui", false)
local slow_stems = load_flag("slow_stems", false)
local delay = tonumber(reaper.GetExtState(SECTION, "delay")) or 0
local open_queue = load_flag("open_queue", false)
local queue_action = reaper.GetExtState(SECTION, "queue_action") -- ID of the "show render queue" action

local ctx = reaper.ImGui_CreateContext("JK Export Cue")

local status = {} -- job key -> { state, detail }
local function refresh_status()
    status = {}
    local rows = export.export_status()
    for _, r in ipairs(rows or {}) do status[r.key] = r end
end
refresh_status()

local function summary()
    local region = export.cue_region()
    local range = region and string.format("%s  %.2f - %.2f s", region.name, region.start, region.finish)
        or "NO CUE: add =START and =END markers or set a time selection"
    return range, #export.marked_tracks(export.jobs.improve.marks), #export.marked_tracks(export.jobs.orch.marks)
end

-- Builds the run options (and asks before overwriting); nil means "don't run"
local function prepare_run()
    local jobs = {}
    for _, o in ipairs(OPTIONS) do
        save_flag(o.key, picked[o.key])
        if picked[o.key] then jobs[#jobs + 1] = o.key end
    end
    local done = {}
    for _, o in ipairs(OPTIONS) do
        local st = status[o.key]
        if picked[o.key] and st and st.state == "complete" then done[#done + 1] = o.label:match("^(.-)%s%s") or o.label end
    end
    if #done > 0 and not midi_only and not resume and not replace then
        local answer = reaper.ShowMessageBox("A complete export of this version already exists for:\n\n" ..
            table.concat(done, "\n") .. "\n\nRender again and overwrite it?", "Cue export", 4)
        if answer ~= 6 then return nil end
    end
    save_flag("queue", queue)
    save_flag("midi", midi)
    save_flag("midi_only", midi_only)
    save_flag("resume", resume)
    save_flag("replace", replace)
    save_flag("remove_click", remove_click)
    save_flag("archive_first", archive_first)
    save_flag("freeze_ui", freeze_ui)
    save_flag("slow_stems", slow_stems)
    reaper.SetExtState(SECTION, "delay", tostring(delay), true)
    save_flag("open_queue", open_queue)
    reaper.SetExtState(SECTION, "queue_action", queue_action, true)
    if #jobs == 0 then return nil end
    return { jobs = jobs, queue = queue and not midi_only, midi = midi, midi_only = midi_only, resume = resume,
        replace = replace, remove_click = remove_click, freeze_ui = freeze_ui, slow_stems = slow_stems, delay = delay,
        archive_first = archive_first and not midi_only,
        open_queue_action = (queue and open_queue) and queue_action or nil }
end

-- Archive the unused tracks (HeDa, External) and wait until HeDa has marked every one of
-- them archived. HeDa's Track Inspector is another script, so waiting must go through
-- defer: a busy wait here would stop it from ever running. on_done(ok, pending_count)
local function archive_unused(on_done)
    local region = export.cue_region()
    if not region then return on_done(true, 0) end
    local unused = export.unused_tracks(region, false)
    if #unused == 0 then return on_done(true, 0) end
    local names, guids = {}, {}
    for i, tr in ipairs(unused) do
        guids[#guids + 1] = reaper.GetTrackGUID(tr)
        if i <= 15 then local _, name = reaper.GetTrackName(tr) names[#names + 1] = "  " .. name end
    end
    if #unused > 15 then names[#names + 1] = string.format("  ... and %d more", #unused - 15) end
    local answer = reaper.ShowMessageBox(string.format("Archive these %d unused tracks before exporting?\n\n%s\n\nTheir plugins are unloaded and the tracks are muted. This stays in the project once you save it, so save as a new version first if you want to keep the full session. HeDa's Track Inspector must be running.",
        #unused, table.concat(names, "\n")), "Archive unused tracks", 4)
    if answer ~= 6 then return on_done(true, 0) end
    reaper.Main_OnCommand(40297, 0)
    for _, tr in ipairs(unused) do reaper.SetTrackSelected(tr, true) end
    reaper.UpdateArrange()
    export.heda_archive("external")
    local started = reaper.time_precise()
    local function poll()
        local pending = 0
        local by_guid = {}
        for i = 0, reaper.CountTracks(0) - 1 do
            local tr = reaper.GetTrack(0, i)
            by_guid[reaper.GetTrackGUID(tr)] = tr
        end
        for _, g in ipairs(guids) do
            local tr = by_guid[g]
            if tr and not export.is_archived(tr) then pending = pending + 1 end
        end
        if pending == 0 then return on_done(true, 0) end
        if reaper.time_precise() - started > 90 then return on_done(false, pending) end
        reaper.defer(poll)
    end
    reaper.defer(poll)
end

-- The whole run: PROX first (it should see the full session), then the optional archive step,
-- then everything else
local function start_run(opts)
    local rest = {}
    for _, key in ipairs(opts.jobs) do rest[#rest + 1] = key end
    local function run(jobs)
        local o = {}
        for k, v in pairs(opts) do o[k] = v end
        o.jobs = jobs
        export.run(o)
    end
    if opts.archive_first then
        local first, others = {}, {}
        for _, key in ipairs(rest) do
            if key == "prox" then first[#first + 1] = key else others[#others + 1] = key end
        end
        if #first > 0 then run(first) end
        if #others == 0 then return end
        archive_unused(function(ok, pending)
            if not ok then
                local answer = reaper.ShowMessageBox(string.format("%d tracks were not archived within 90 seconds. Is HeDa's Track Inspector running?\n\nExport anyway?", pending), "Archive unused tracks", 4)
                if answer ~= 6 then return end
            end
            run(others)
        end)
    else
        run(rest)
    end
end

local function loop()
    local visible, open = reaper.ImGui_Begin(ctx, "Export cue", true, reaper.ImGui_WindowFlags_AlwaysAutoResize())
    local run = false
    if visible then
        local range, n_im, n_rec = summary()
        reaper.ImGui_Text(ctx, "Cue: " .. range)
        reaper.ImGui_Text(ctx, string.format("Marked tracks:  IM %d   REC/TR %d", n_im, n_rec))
        reaper.ImGui_Separator(ctx)
        for _, o in ipairs(OPTIONS) do
            local _, v = reaper.ImGui_Checkbox(ctx, o.label, picked[o.key])
            picked[o.key] = v
            local st = status[o.key]
            if st then
                reaper.ImGui_SameLine(ctx)
                local ui = export.STATE_UI[st.state] or export.STATE_UI.missing
                reaper.ImGui_TextColored(ctx, ui[2], "[" .. ui[1] .. "]")
                if st.detail ~= "" and reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, st.detail) end
                if st.detail ~= "" and st.state ~= "missing" and st.state ~= "n/a" and st.state ~= "complete" then
                    reaper.ImGui_TextColored(ctx, 0x9A9A9AFF, "      " .. st.detail:sub(1, 110))
                end
            end
        end
        reaper.ImGui_Separator(ctx)
        local _
        _, midi = reaper.ImGui_Checkbox(ctx, "Write MIDI (IMPROVE / ORCH / multitrack)", midi)
        _, resume = reaper.ImGui_Checkbox(ctx, "Resume: skip steps an interrupted run already finished", resume)
        _, replace = reaper.ImGui_Checkbox(ctx, "Replace existing files (old ones are deleted first, no overwrite prompt)", replace)
        _, remove_click = reaper.ImGui_Checkbox(ctx, "Remove the click track when done (instead of leaving it muted)", remove_click)
        _, archive_first = reaper.ImGui_Checkbox(ctx, "Archive unused tracks first (HeDa External, permanent once saved)", archive_first)
        _, slow_stems = reaper.ImGui_Checkbox(ctx, "Slow stems: not 'fast via master' (crash test, one track at a time)", slow_stems)
        _, freeze_ui = reaper.ImGui_Checkbox(ctx, "Freeze the screen while exporting (try both if REAPER crashes)", freeze_ui)
        reaper.ImGui_SetNextItemWidth(ctx, 90)
        local changed
        changed, delay = reaper.ImGui_InputInt(ctx, "Pause between steps (seconds; REAPER looks frozen while it waits, 0 = none)", delay)
        if delay < 0 then delay = 0 end
        _, midi_only = reaper.ImGui_Checkbox(ctx, "MIDI only (no rendering; IMPROVE / ORCH)", midi_only)
        if not midi_only then
            _, queue = reaper.ImGui_Checkbox(ctx, "Add to render queue instead of rendering now", queue)
        end
        if queue and not midi_only then
            _, open_queue = reaper.ImGui_Checkbox(ctx, "Open the render queue afterwards", open_queue)
            if open_queue then
                reaper.ImGui_SetNextItemWidth(ctx, 220)
                _, queue_action = reaper.ImGui_InputText(ctx, "action ID (Actions list > Copy command ID)", queue_action)
            end
        end
        if reaper.ImGui_Button(ctx, midi_only and "Write MIDI" or (queue and "Queue" or "Export")) then run = true end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Refresh status") then refresh_status() end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Close") then open = false end
    end
    reaper.ImGui_End(ctx)
    if run then
        local opts = prepare_run()
        if opts then
            -- Export from outside the window: destroy it first and start a couple of cycles later, so no
            -- ReaImGui window is alive while REAPER opens its modal render dialog
            if reaper.ImGui_DestroyContext then pcall(reaper.ImGui_DestroyContext, ctx) end
            reaper.defer(function() reaper.defer(function() start_run(opts) end) end)
            return
        end
    end
    if open then reaper.defer(loop) end
end

if reaper.ImGui_CreateContext then
    reaper.defer(loop)
else
    reaper.ShowMessageBox("ReaImGui is required for the picker.", "Export cue", 0)
end
