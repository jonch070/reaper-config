-- @description Show export status for the selected sub-project items (or all sub-projects in the session)
-- @author Jonathan Kawchuk (generated with Claude)
local script_path = ({ reaper.get_action_context() })[2]:match('^(.*[\\/])')
local export = dofile(script_path .. "jk_export.lua")

local COLUMNS = { { "PROX", "PROX" }, { "IMPROVE", "IMPROVE" }, { "ORCH", "ORCH" }, { "DRY", "multitrack dry" }, { "WET", "multitrack wet" } }
local GREEN, AMBER, RED, GREY, WHITE = 0x6FCF7FFF, 0xF0B050FF, 0xE5645CFF, 0x8A8A8AFF, 0xE8E8E8FF

local rows, selected = {}, false
local function load()
    local paths
    paths, selected = export.subproject_paths()
    rows = {}
    for _, path in ipairs(paths) do
        local result, why = export.export_status_for_rpp(path)
        local row = { path = path, name = path:match("([^\\/]*)$"):gsub("%.[Rr][Pp][Pp]$", ""), why = why, cells = {} }
        if result then
            row.name = result.project
            for _, r in ipairs(result.rows) do row.cells[r.label] = r end
        end
        rows[#rows + 1] = row
    end
end

local function plain_text()
    local lines = { selected and "Selected sub-projects" or "All sub-projects (none selected)", "" }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = row.name
        if row.why then lines[#lines + 1] = "  " .. row.why end
        for _, col in ipairs(COLUMNS) do
            local r = row.cells[col[2]]
            if r and r.state ~= "n/a" then
                lines[#lines + 1] = string.format("  %-16s %s%s", r.label, r.state:upper(), r.detail ~= "" and ("  " .. r.detail) or "")
            end
        end
        lines[#lines + 1] = ""
    end
    reaper.ShowMessageBox(table.concat(lines, "\n"), "Export status", 0)
end

load()
if #rows == 0 then return reaper.ShowMessageBox("No sub-project items found.", "Export status", 0) end
if not reaper.ImGui_CreateContext then return plain_text() end

local function tally()
    local done, total, bad, trouble = 0, 0, 0, 0
    for _, row in ipairs(rows) do
        for _, r in pairs(row.cells) do
            if r.state ~= "n/a" then
                total = total + 1
                if r.state == "complete" then done = done + 1 end
                if r.state == "interrupted" or r.state == "failed" then trouble = trouble + 1 end
            end
        end
        if row.why then bad = bad + 1 end
    end
    return done, total, bad, trouble
end

local ctx = reaper.ImGui_CreateContext("JK Export Status")
local function loop()
    reaper.ImGui_SetNextWindowSize(ctx, 640, 0, reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, "Export status: sub-projects", true)
    if visible then
        local done, total, bad, trouble = tally()
        reaper.ImGui_TextColored(ctx, done == total and GREEN or AMBER, string.format("%d of %d packages complete", done, total))
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, GREY, selected and "  (selected items)" or "  (all sub-projects, none selected)")
        if trouble > 0 then reaper.ImGui_TextColored(ctx, 0xE5645CFF, trouble .. " package(s) interrupted or failed: hover for what finished") end
        if bad > 0 then reaper.ImGui_TextColored(ctx, RED, bad .. " project file(s) could not be read") end
        reaper.ImGui_Spacing(ctx)
        local flags = reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_BordersInnerH() | reaper.ImGui_TableFlags_SizingStretchProp()
        if reaper.ImGui_BeginTable(ctx, "status", 1 + #COLUMNS, flags) then
            reaper.ImGui_TableSetupColumn(ctx, "Project", reaper.ImGui_TableColumnFlags_WidthStretch(), 3)
            for _, col in ipairs(COLUMNS) do reaper.ImGui_TableSetupColumn(ctx, col[1], reaper.ImGui_TableColumnFlags_WidthStretch(), 1) end
            reaper.ImGui_TableHeadersRow(ctx)
            for _, row in ipairs(rows) do
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_TextColored(ctx, row.why and RED or WHITE, row.name)
                if row.why and reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, row.why) end
                for _, col in ipairs(COLUMNS) do
                    reaper.ImGui_TableNextColumn(ctx)
                    local r = row.cells[col[2]]
                    if not r or r.state == "n/a" then
                        reaper.ImGui_TextColored(ctx, GREY, "none")
                        if r and r.detail ~= "" and reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, r.detail) end
                    else
                        local ui = export.STATE_UI[r.state] or export.STATE_UI.missing
                        reaper.ImGui_TextColored(ctx, ui[2], ui[1])
                        if r.detail ~= "" and reaper.ImGui_IsItemHovered(ctx) then reaper.ImGui_SetTooltip(ctx, r.detail) end
                    end
                end
            end
            reaper.ImGui_EndTable(ctx)
        end
        reaper.ImGui_Spacing(ctx)
        if reaper.ImGui_Button(ctx, "Refresh") then load() end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Close") then open = false end
        reaper.ImGui_TextColored(ctx, GREY, "Hover a cell for what is missing.")
    end
    reaper.ImGui_End(ctx)
    if open then reaper.defer(loop) end
end
reaper.defer(loop)
