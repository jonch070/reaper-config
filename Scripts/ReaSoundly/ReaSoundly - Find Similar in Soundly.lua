local cur_os = reaper.GetOS()

if cur_os == "Win32" or cur_os == "Win64" then
  cur_os = "Windows"
elseif cur_os == "OSX64" or cur_os == "OSX32" or cur_os == "macOS-arm64" then
  cur_os = "Mac"
end

local commands = {}

local count = reaper.CountSelectedMediaItems(0)

if count == 0 then
  reaper.ShowMessageBox("Please select at least one media item to perform Find Similar in Soundly!",
    "ReaSoundly - Find Similar", 0)
elseif count > 5 then
  reaper.ShowMessageBox("More than five items have been selected. Only the first five will be used for Find Similar.",
    "ReaSoundly - Find Similar", 0)
  count = 5
end

if count > 0 then
  for i = 0, count - 1 do
    local item                = reaper.GetSelectedMediaItem(0, i)
    local take                = reaper.GetActiveTake(item)
    local source              = reaper.GetMediaItemTake_Source(take)
    local file_path           = reaper.GetMediaSourceFileName(source)
    local rate                = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    local _, _, start, length = reaper.BR_GetMediaSourceProperties(take)
    local file_length         = reaper.GetMediaSourceLength(source)
    local start_percent       = math.max((start) / file_length, 0)
    local end_percent         = math.min((start + (length * rate)) / file_length, 1)


    -- file-path=X&start-percent=0.05&end-percent=0.80
    local params = ("?file-path=%s&start-percent=%s&end-percent=%s"):format(file_path, start_percent,
      end_percent)

    local cmd    = (("soundly://sonic/%s"):format(reaper.NF_Base64_Encode(params, true)))
    table.insert(commands, cmd)
  end

  for _, cmd in ipairs(commands) do
    if cur_os == "Windows" then
      reaper.CF_ShellExecute(cmd)
    elseif cur_os == "Mac" then
      os.execute(("open %s"):format(cmd))
    end
  end
end
