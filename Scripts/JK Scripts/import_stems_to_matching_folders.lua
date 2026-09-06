local function splitLines(content)
  content = content:gsub('\r\n', '\n'):gsub('\r', '\n')
  local lines = {}
  for line in (content .. '\n'):gmatch('(.-)\n') do
    lines[#lines + 1] = line
  end
  return lines
end

local function parseTrackChunk(chunkLines)
  local name, guid, mute, folderdepth = '', nil, 0, 0
  local itemCount, recvCount = 0, 0
  local seenItem = false
  for _, l in ipairs(chunkLines) do
    if l:match('^%s*<ITEM') then
      seenItem = true
      itemCount = itemCount + 1
    elseif not seenItem then
      local nm = l:match('^%s*NAME%s+"(.-)"%s*$')
      if nm then name = nm end
      local g = l:match('^%s*GUID%s+(%b{})')
      if g then guid = g end
      local m = l:match('^%s*MUTE%s+(%d+)')
      if m then mute = tonumber(m) end
      local fd = l:match('^%s*I_FOLDERDEPTH%s+(%-?%d+)')
      if fd then folderdepth = tonumber(fd) end
    end
    if l:match('AUXRECV') then recvCount = recvCount + 1 end
  end
  return {
    name = name, guid = guid, mute = mute, folderdepth = folderdepth,
    itemCount = itemCount, recvCount = recvCount, lines = chunkLines,
    parent = nil,
  }
end

local function parseAllTracks(lines)
  local tracks = {}
  local n = #lines
  local i = 1
  while i <= n do
    if lines[i]:match('^%s*<TRACK%s*$') then
      local startIdx = i
      local level = 1
      i = i + 1
      while i <= n and level > 0 do
        local l = lines[i]
        local hasOpen = l:find('<') ~= nil
        local hasClose = l:find('>') ~= nil
        local balanced = l:find('%b<>') ~= nil
        if hasOpen and not balanced then level = level + 1 end
        if hasClose and not balanced then level = level - 1 end
        i = i + 1
      end
      local endIdx = i - 1
      local chunkLines = {}
      for k = startIdx, endIdx do chunkLines[#chunkLines + 1] = lines[k] end
      tracks[#tracks + 1] = parseTrackChunk(chunkLines)
    else
      i = i + 1
    end
  end
  return tracks
end

local function computeSourceTree(tracks)
  local stack = {}
  for _, t in ipairs(tracks) do
    t.parent = stack[#stack]
    if t.folderdepth == 1 then
      stack[#stack + 1] = t
    elseif t.folderdepth < 0 then
      local pop = -t.folderdepth
      for _ = 1, pop do
        if #stack > 0 then table.remove(stack) end
      end
    end
  end
end

local function ancestorChainMuted(t)
  local p = t.parent
  while p do
    if p.mute == 1 then return true end
    p = p.parent
  end
  return false
end

local function isAbsolutePath(p)
  if p:match('^/') then return true end
  if p:match('^%a:[\\/]') then return true end
  if p:match('^\\\\') then return true end
  return false
end

local function resolvePath(path, sourceDir)
  local p = path:gsub('\\', '/')
  if isAbsolutePath(p) then return p end
  local base = sourceDir:gsub('\\', '/')
  if base:sub(-1) ~= '/' then base = base .. '/' end
  return base .. p
end

local function buildDestChunk(t, sourceDir)
  local out = {}
  local seenItem = false
  for _, l in ipairs(t.lines) do
    if l:match('^%s*<ITEM') then seenItem = true end
    local fileMatch = l:match('^%s*FILE%s+"(.-)"%s*$')
    if fileMatch then
      local indent = l:match('^(%s*)FILE') or ''
      out[#out + 1] = indent .. 'FILE "' .. resolvePath(fileMatch, sourceDir) .. '"'
    elseif not seenItem and l:match('^%s*GUID%s+%b{}%s*$') then
      local prefix = l:match('^(%s*GUID%s+)')
      out[#out + 1] = prefix .. reaper.genGuid()
    elseif not seenItem and (l:match('^%s*TRACKID%s') or l:match('^%s*IDX%s')) then
      -- skip: identity lines regenerated separately
    else
      out[#out + 1] = l
    end
  end
  return table.concat(out, '\n')
end

local function findExistingLastChild(mountTr)
  local n = reaper.CountTracks(0)
  local mountIdx = -1
  for i = 0, n - 1 do
    if reaper.GetTrack(0, i) == mountTr then mountIdx = i break end
  end
  if mountIdx < 0 then return nil end
  local depth = 1
  local lastChild = nil
  for i = mountIdx + 1, n - 1 do
    if depth <= 0 then break end
    local tr = reaper.GetTrack(0, i)
    if depth == 1 then lastChild = tr end
    local fd = reaper.GetMediaTrackInfo_Value(tr, 'I_FOLDERDEPTH')
    depth = depth + fd
  end
  return lastChild
end

local function resolveMountFolder(parentName, ctx)
  local key = parentName:lower()
  local cached = ctx.destFolderCache[key]
  if cached then return cached end
  local n = reaper.CountTracks(0)
  for i = 0, n - 1 do
    local tr = reaper.GetTrack(0, i)
    local _, nm = reaper.GetSetMediaTrackInfo_String(tr, 'P_NAME', '', false)
    local fd = reaper.GetMediaTrackInfo_Value(tr, 'I_FOLDERDEPTH')
    if fd == 1 and nm ~= '' and nm:lower() == key then
      ctx.destFolderCache[key] = tr
      return tr
    end
  end
  if ctx.optCreate then
    local idx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(idx, false)
    local tr = reaper.GetTrack(0, idx)
    reaper.GetSetMediaTrackInfo_String(tr, 'P_NAME', parentName, true)
    reaper.SetMediaTrackInfo_Value(tr, 'I_FOLDERDEPTH', 1)
    ctx.destFolderCache[key] = tr
    ctx.createdFolders[#ctx.createdFolders + 1] = parentName
    return tr
  end
  return nil
end

local function importTrack(t, mountTr, ctx)
  local insertIdx
  if mountTr == nil then
    insertIdx = reaper.CountTracks(0)
  else
    local anchor = ctx.folderLastChild[mountTr]
    if not anchor then anchor = findExistingLastChild(mountTr) end
    local anchorTr = anchor or mountTr
    local anchorIdx = math.floor(reaper.GetMediaTrackInfo_Value(anchorTr, 'IP_TRACKNUMBER')) - 1
    insertIdx = anchorIdx + 1
  end

  reaper.InsertTrackAtIndex(insertIdx, false)
  local newTr = reaper.GetTrack(0, insertIdx)
  local chunk = buildDestChunk(t, ctx.sourceDir)
  reaper.GetSetObjectState(newTr, chunk)

  if mountTr == nil then
    reaper.SetMediaTrackInfo_Value(newTr, 'I_FOLDERDEPTH', 0)
  else
    local prev = ctx.folderLastChild[mountTr]
    if prev then
      local pd = reaper.GetMediaTrackInfo_Value(prev, 'I_FOLDERDEPTH')
      if pd < 0 then
        reaper.SetMediaTrackInfo_Value(prev, 'I_FOLDERDEPTH', pd + 1)
      end
    end
    reaper.SetMediaTrackInfo_Value(newTr, 'I_FOLDERDEPTH', -1)
    ctx.folderLastChild[mountTr] = newTr
  end
end

local function processTrack(t, ctx)
  if t.folderdepth == 1 then return nil end
  if ctx.optUnmuted and (t.mute == 1 or ancestorChainMuted(t)) then
    return 'muted'
  end
  if ctx.optContent and t.itemCount == 0 and t.recvCount == 0 then
    return 'nocontent'
  end
  local parentName = (t.parent and t.parent.name) or ''
  local mountTr = nil
  if parentName ~= '' then
    mountTr = resolveMountFolder(parentName, ctx)
    if not mountTr then return 'nofolder' end
  end
  importTrack(t, mountTr, ctx)
  return 'imported'
end

local function main()
  local fok, srcPath = reaper.GetUserFileNameForRead('', 'Select source project', 'rpp')
  if not fok or srcPath == '' then return end

  local uok, csv = reaper.GetUserInputs('Import Stems To Matching Folders', 3,
    'Only unmuted (no self or upstream folder mute) (1=yes):,Require items OR receive (send into track) (1=yes):,Create missing destination folders (1=yes):',
    '1,1,1')
  if not uok then return end
  local a, b, c = csv:match('^([^,]*),([^,]*),([^,]*)$')
  if not a then return end
  local optUnmuted = tonumber(a) == 1
  local optContent = tonumber(b) == 1
  local optCreate = tonumber(c) == 1

  local f = io.open(srcPath, 'r')
  if not f then
    reaper.MB('Could not open source file:\n' .. srcPath, 'Import Stems To Matching Folders', 0)
    return
  end
  local content = f:read('*a')
  f:close()

  local sourceDir = srcPath:match('^(.*)[/\\][^/\\]*$') or '.'
  local tracks = parseAllTracks(splitLines(content))
  computeSourceTree(tracks)

  if #tracks == 0 then
    reaper.MB('No tracks found in source project:\n' .. srcPath, 'Import Stems To Matching Folders', 0)
    return
  end

  local ctx = {
    optUnmuted = optUnmuted,
    optContent = optContent,
    optCreate = optCreate,
    sourceDir = sourceDir,
    destFolderCache = {},
    folderLastChild = {},
    createdFolders = {},
  }

  local imported, skippedMuted, skippedNoContent, skippedNoFolder = 0, 0, 0, 0

  reaper.Undo_BeginBlock2(0)
  reaper.PreventUIRefresh(1)

  for _, t in ipairs(tracks) do
    local status = processTrack(t, ctx)
    if status == 'imported' then
      imported = imported + 1
    elseif status == 'muted' then
      skippedMuted = skippedMuted + 1
    elseif status == 'nocontent' then
      skippedNoContent = skippedNoContent + 1
    elseif status == 'nofolder' then
      skippedNoFolder = skippedNoFolder + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock2(0, 'Import stems to matching folders', -1)
  reaper.UpdateArrange()

  local msg = {}
  msg[#msg + 1] = string.format('Imported: %d track(s)', imported)
  msg[#msg + 1] = string.format('Skipped (muted): %d', skippedMuted)
  msg[#msg + 1] = string.format('Skipped (no items/receive): %d', skippedNoContent)
  msg[#msg + 1] = string.format('Skipped (no matching folder, create off): %d', skippedNoFolder)
  if #ctx.createdFolders > 0 then
    msg[#msg + 1] = ''
    msg[#msg + 1] = 'Created folders: ' .. table.concat(ctx.createdFolders, ', ')
  end
  reaper.MB(table.concat(msg, '\n'), 'Import Stems To Matching Folders - Summary', 0)
end

main()
