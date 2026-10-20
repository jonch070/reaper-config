-- @description Pick which cue exports to run (Improve, Orch, multitrack dry/wet), render now or queue
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local export = dofile(script_path .. "jk_export.lua")

local SECTION = "JK_ExportCue"
local OPTIONS = {
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
local open_queue = load_flag("open_queue", false)
local queue_action = reaper.GetExtState(SECTION, "queue_action") -- ID of the "show render queue" action

local ctx = reaper.ImGui_CreateContext("JK Export Cue")

local function summary()
    local region = export.cue_region()
    local range = region and string.format("%s  %.2f - %.2f s", region.name, region.start, region.finish)
        or "NO CUE: add =START and =END markers or set a time selection"
    return range, #export.marked_tracks(export.jobs.improve.marks), #export.marked_tracks(export.jobs.orch.marks)
end

local function go()
    local jobs = {}
    for _, o in ipairs(OPTIONS) do
        save_flag(o.key, picked[o.key])
        if picked[o.key] then jobs[#jobs + 1] = o.key end
    end
    save_flag("queue", queue)
    save_flag("midi", midi)
    save_flag("midi_only", midi_only)
    save_flag("open_queue", open_queue)
    reaper.SetExtState(SECTION, "queue_action", queue_action, true)
    if #jobs > 0 then export.run { jobs = jobs, queue = queue and not midi_only, midi = midi, midi_only = midi_only,
            open_queue_action = (queue and open_queue) and queue_action or nil } end
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
        end
        reaper.ImGui_Separator(ctx)
        local _
        _, midi = reaper.ImGui_Checkbox(ctx, "Write MIDI (IMPROVE / ORCH / multitrack)", midi)
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
        if reaper.ImGui_Button(ctx, "Close") then open = false end
    end
    reaper.ImGui_End(ctx)
    if run then
        go()
        return
    end
    if open then reaper.defer(loop) end
end

if reaper.ImGui_CreateContext then
    reaper.defer(loop)
else
    reaper.ShowMessageBox("ReaImGui is required for the picker.", "Export cue", 0)
end
