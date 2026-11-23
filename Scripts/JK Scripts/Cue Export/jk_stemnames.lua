-- Shorter filenames for multitrack stems whose track name is a long source-recording name
-- (e.g. "2026-09-11-250012-1M04 - The Birds (tukan partials)-Ben Botfield-Vocals (English) - Take 1").
-- Pro Tools / interleaver tooling rejected stems at 206+ characters; 165 and under were fine.
--
-- Stem filename: <folders and track, joined by _> <dry|wet> - <project> - <starttc>[-NNN].wav
-- Only the last "_" segment (the track name) is shortened, so folder names stay intact
-- for the mix-session builder.
local M = {}

M.LIMIT = 165    -- names up to this many characters are left alone
M.KEEP_MIN = 24  -- at least this much of the track name is kept (its end: the take number)

-- REAPER recording IDs such as 2026-09-11-250012-
local function strip_ids(s) return (s:gsub("%d%d%d%d%-%d%d%-%d%d%-%d+%-", "")) end

-- Returns the shortened filename, or nil when the name is already short enough / not a stem.
function M.short(file, limit)
    limit = limit or M.LIMIT
    if #file <= limit then return nil end
    local head, tail = file:match("^(.*)( [dD][rR][yY] %- .*)$")
    if not head then head, tail = file:match("^(.*)( [wW][eE][tT] %- .*)$") end
    if not head then return nil end
    local prefix, seg = head:match("^(.*_)([^_]*)$")
    if not prefix then prefix, seg = "", head end
    seg = strip_ids(seg)
    local out = prefix .. seg .. tail
    if #out > limit then
        local excess = #out - limit
        local keep = math.max(M.KEEP_MIN, #seg - excess)
        if keep < #seg then
            local cut = seg:sub(#seg - keep + 1)
            local space = cut:find(" ", 1, true) -- begin at a word boundary
            if space and space < #cut then cut = cut:sub(space + 1) end
            seg = cut
        end
        out = prefix .. seg .. tail
    end
    if out == file then return nil end
    return out
end

M.MAP = "_long_names.tsv" -- in each stem folder: <short name> TAB <original name>

local function q(path) return "'" .. path:gsub("'", "'\\''") .. "'" end

local function copy_file(src, dst)
    -- macOS/APFS: cp -c clones the file instantly and takes no extra space
    if package.config:sub(1, 1) == "/" then
        os.execute("cp -c " .. q(src) .. " " .. q(dst) .. " 2>/dev/null")
        local t = io.open(dst, "rb")
        if t then t:close() return true end
    end
    local i = io.open(src, "rb")
    if not i then return false end
    local o = io.open(dst, "wb")
    if not o then i:close() return false end
    while true do
        local chunk = i:read(4 * 1024 * 1024)
        if not chunk then break end
        o:write(chunk)
    end
    i:close()
    o:close()
    return true
end

-- Original long names listed in a stem folder's map, as a set (the builder skips these).
function M.originals(dir)
    local set = {}
    local f = io.open(dir .. "/" .. M.MAP, "r")
    if f then
        for line in f:lines() do
            local _, orig = line:match("^(.-)\t(.*)$")
            if orig and orig ~= "" then set[orig] = true end
        end
        f:close()
    end
    return set
end

-- Shorten the too-long stems in one folder. mode "copy": write short-named copies and keep the
-- originals (listed in the map file); "rename": rename in place (fresh renders).
-- Returns { made = n, problems = {...}, pairs = { {short, original}, ... } }
function M.shorten_folder(dir, mode, limit)
    local res = { made = 0, problems = {}, pairs = {} }
    local names, taken, i = {}, {}, 0
    while true do
        local f = reaper.EnumerateFiles(dir, i)
        if not f then break end
        i = i + 1
        names[#names + 1] = f
        taken[f] = true
    end
    local done = (mode == "copy") and M.originals(dir) or {}
    local mapf = (mode == "copy") and io.open(dir .. "/" .. M.MAP, "a") or nil
    for _, f in ipairs(names) do
        local s = (not done[f]) and M.short(f, limit) or nil
        if s then
            local n = 1
            while taken[s] do -- never overwrite: add a counter before the dry/wet tag
                n = n + 1
                s = (M.short(f, limit) or f):gsub("( [dDwW][rReE][yYtT] %- )", "~" .. n .. "%1", 1)
            end
            local ok
            if mode == "copy" then ok = copy_file(dir .. "/" .. f, dir .. "/" .. s)
            else ok = os.rename(dir .. "/" .. f, dir .. "/" .. s) end
            if ok then
                taken[s] = true
                res.made = res.made + 1
                res.pairs[#res.pairs + 1] = { s, f }
                if mapf then mapf:write(s, "\t", f, "\n") end
            else
                res.problems[#res.problems + 1] = "could not write " .. s
            end
        end
    end
    if mapf then mapf:close() end
    return res
end

return M
