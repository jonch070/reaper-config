function render_master_wav(dst_dir, file_naming_convention)
    --Settings of the render table
    local source = 0 -- 0, Master mix(default); 1, Master mix + stems; 3, Stems (selected tracks); 8, Region render matrix; 32, Selected media items; 256, Embed stretch markers/transient guides-checkbox=on; optional, as parameter EmbedStretchMarkers is meant for that
    local bounds = 2 -- 0, Custom time range; 1, Entire project(default); 2, Time selection; 3, Project regions; 4, Selected Media Items(in combination with Source 32); 5, Selected regions; 6, Razor edit areas; 7, All project markers; 8, Selected markers
    local start_pos = 0
    local end_pos = 0
    local tail_flag = 1
    local tail_ms = 0
    local render_dir = dst_dir
    local file_name = "$project - $starttc - mix"
    local file_name = file_naming_convention .. " - mix"
    local sample_rate = 48000
    local channels = 2
    local render_type = 0      -- 0, Full-speed Offline(default); 1, 1x Offline; 2, Online Render; 3, Online Render(Idle); 4, Offline Render(Idle)
    local project_sample_rate_fx_processing = true
    local render_resample = 10 -- 0, Sinc Interpolation: 64pt (medium quality); 1, Linear Interpolation: (low quality); 2, Point Sampling (lowest quality, retro); 3, Sinc Interpolation: 192pt; 4, Sinc Interpolation: 384pt; 5, Linear Interpolation + IIR; 6, Linear Interpolation + IIRx2; 7, Sinc Interpolation: 16pt; 8, Sinc Interpolation: 512pt(slow); 9, Sinc Interpolation: 768pt(very slow); 10, r8brain free (highest quality, fast)
    local keep_mono = true
    local keep_multichannel = true
    local dither = 0 -- 0 = none; &1, dither master mix; &2, noise shaping master mix; &4, dither stems; &8, dither noise shaping stems

    -- args:
    -- (int) bit depth: 0, 8 Bit PCM; 1, 16 Bit PCM; 2, 24 Bit PCM; 3, 32 Bit FP; 4, 64 Bit FP; 5, 4 Bit IMA ADPCM; 6, 2 Bit cADPCM; 7, 32 Bit PCM; 8, 8 Bit u-Law
    -- (int) large files: 0, Auto WAV/Wave64; 1, Auto Wav/RF64; 2, Force WAV; 3, Force Wave64; 4, Force RF64
    -- (int) bwf_chunk (write 'bext' chunk and include project filename in BWF data - checkboxes): 0, unchecked - unchecked; 1, checked - unchecked; 2, unchecked - checked; 3, checked - checked
    -- (int) the "include markers" dropdown list: 0, Do not include markers and regions; 1, Markers + regions; 2, Markers + regions starting with #; 3, Markers only; 4, Markers starting with # only; 5, Regions only; 6, Regions starting with # only
    -- (bool) embed tempo-checkbox; true, checked; false, unchecked
    local render_string = ultraschall.CreateRenderCFG_WAV(24, 2, 1, 0, false)

    local silently_increment_filename = false
    local add_to_proj = false
    local save_copy_of_project = false
    local render_queue_delay = false
    local render_queue_delay_seconds = 0
    local close_after_render = true -- the dialog, not the Reaper project


    master_wav = ultraschall.CreateNewRenderTable(source, bounds, start_pos, end_pos, tail_flag, tail_ms,
        render_dir, file_name, sample_rate, channels, render_type, project_sample_rate_fx_processing,
        render_resample, keep_mono, keep_multichannel, dither, render_string, silently_increment_filename,
        add_to_proj, save_copy_of_project, render_queue_delay, render_queue_delay_seconds, close_after_render)

    set_bounds_to_items {}

    -- This changes the current render settings, but doesn't kick off the render process
    retval, dirty = ultraschall.ApplyRenderTable_Project(master_wav)

    -- This kicks off the render process
    -- args:
    -- optional string project filename_with_path (to the rpp-file that you want to render; nil, to render the current active project)
    -- optional table RenderTable: the RenderTable with all render-settings, that you want to apply; nil, use the project's existing settings
    -- optional boolean AddToProj: true, add the rendered files to the project; nil or false, don't add them; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed only has an effect, when rendering the current active project
    -- optional boolean CloseAfterRender: true or nil, closes rendering to file-dialog after rendering is finished; false, keep it open; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    -- optional boolean SilentlyIncrementFilename; true or nil, silently increment filename, when file already exists; false, ask for overwriting; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    count, media_item_state_chunk_array, file_array = ultraschall.RenderProject_RenderTable(nil, master_wav, false, true,
        false)

    -- Track: Unselect (clear selection of) all tracks
    reaper.Main_OnCommand(40297, 0)
end


function render_master_mp3(dst_dir, file_naming_convention)
    --Settings of the render table
    local source = 0 -- 0, Master mix(default); 1, Master mix + stems; 3, Stems (selected tracks); 8, Region render matrix; 32, Selected media items; 256, Embed stretch markers/transient guides-checkbox=on; optional, as parameter EmbedStretchMarkers is meant for that
    local bounds = 2 -- 0, Custom time range; 1, Entire project(default); 2, Time selection; 3, Project regions; 4, Selected Media Items(in combination with Source 32); 5, Selected regions; 6, Razor edit areas; 7, All project markers; 8, Selected markers
    local start_pos = 0
    local end_pos = 0
    local tail_flag = 1
    local tail_ms = 0
    local render_dir = dst_dir
    -- local file_name = "$project - $starttc - mix"
    local file_name = file_naming_convention .. " - mix"
    local sample_rate = 48000
    local channels = 2
    local render_type = 0      -- 0, Full-speed Offline(default); 1, 1x Offline; 2, Online Render; 3, Online Render(Idle); 4, Offline Render(Idle)
    local project_sample_rate_fx_processing = true
    local render_resample = 10 -- 0, Sinc Interpolation: 64pt (medium quality); 1, Linear Interpolation: (low quality); 2, Point Sampling (lowest quality, retro); 3, Sinc Interpolation: 192pt; 4, Sinc Interpolation: 384pt; 5, Linear Interpolation + IIR; 6, Linear Interpolation + IIRx2; 7, Sinc Interpolation: 16pt; 8, Sinc Interpolation: 512pt(slow); 9, Sinc Interpolation: 768pt(very slow); 10, r8brain free (highest quality, fast)
    local keep_mono = true
    local keep_multichannel = true
    local dither = 0 -- 0 = none; &1, dither master mix; &2, noise shaping master mix; &4, dither stems; &8, dither noise shaping stems
    local render_string = ultraschall.CreateRenderCFG_MP3MaxQuality()
    local silently_increment_filename = false
    local add_to_proj = false
    local save_copy_of_project = false
    local render_queue_delay = false
    local render_queue_delay_seconds = 0
    local close_after_render = true -- the dialog, not the Reaper project


    master_mp3 = ultraschall.CreateNewRenderTable(source, bounds, start_pos, end_pos, tail_flag, tail_ms,
        render_dir, file_name, sample_rate, channels, render_type, project_sample_rate_fx_processing,
        render_resample, keep_mono, keep_multichannel, dither, render_string, silently_increment_filename,
        add_to_proj, save_copy_of_project, render_queue_delay, render_queue_delay_seconds, close_after_render)

    set_bounds_to_items {}

    -- This changes the current render settings, but doesn't kick off the render process
    -- retval, dirty = ultraschall.ApplyRenderTable_Project(master_mp3)


    -- This kicks off the render process
    -- args:
    -- optional string project filename_with_path (to the rpp-file that you want to render; nil, to render the current active project)
    -- optional table RenderTable: the RenderTable with all render-settings, that you want to apply; nil, use the project's existing settings
    -- optional boolean AddToProj: true, add the rendered files to the project; nil or false, don't add them; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed only has an effect, when rendering the current active project
    -- optional boolean CloseAfterRender: true or nil, closes rendering to file-dialog after rendering is finished; false, keep it open; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    -- optional boolean SilentlyIncrementFilename; true or nil, silently increment filename, when file already exists; false, ask for overwriting; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    count, media_item_state_chunk_array, file_array = ultraschall.RenderProject_RenderTable(nil, master_mp3, false, true,
        false)

    -- Track: Unselect (clear selection of) all tracks
    reaper.Main_OnCommand(40297, 0)
end

-- FIXME: not yet working, always setting to wav, not video...the problem probably lies in the render string
function render_video(dst_dir)
    framerate, has_drop_frame = reaper.TimeMap_curFrameRate(0)

    --Settings of the render table
    local source = 0 -- 0, Master mix(default); 1, Master mix + stems; 3, Stems (selected tracks); 8, Region render matrix; 32, Selected media items; 256, Embed stretch markers/transient guides-checkbox=on; optional, as parameter EmbedStretchMarkers is meant for that
    local bounds = 2 -- 0, Custom time range; 1, Entire project(default); 2, Time selection; 3, Project regions; 4, Selected Media Items(in combination with Source 32); 5, Selected regions; 6, Razor edit areas; 7, All project markers; 8, Selected markers
    local start_pos = 0
    local end_pos = 0
    local tail_flag = 1
    local tail_ms = 0
    local render_dir = dst_dir
    local file_name = "$project"
    local sample_rate = 48000
    local channels = 2
    local render_type = 0      -- 0, Full-speed Offline(default); 1, 1x Offline; 2, Online Render; 3, Online Render(Idle); 4, Offline Render(Idle)
    local project_sample_rate_fx_processing = true
    local render_resample = 10 -- 0, Sinc Interpolation: 64pt (medium quality); 1, Linear Interpolation: (low quality); 2, Point Sampling (lowest quality, retro); 3, Sinc Interpolation: 192pt; 4, Sinc Interpolation: 384pt; 5, Linear Interpolation + IIR; 6, Linear Interpolation + IIRx2; 7, Sinc Interpolation: 16pt; 8, Sinc Interpolation: 512pt(slow); 9, Sinc Interpolation: 768pt(very slow); 10, r8brain free (highest quality, fast)
    local keep_mono = true
    local keep_multichannel = true
    local dither = 0 -- 0 = none; &1, dither master mix; &2, noise shaping master mix; &4, dither stems; &8, dither noise shaping stems

    -- args:
    -- integer the videocodec used for the video:
    -- 1, MJPEG
    -- 2, H.264(needs FFMPEG 4.1.3 installed)
    -- 3, MPEG-2(needs FFMPEG 4.1.3 installed)
    -- 4, NONE
    --
    -- integer MJPEG_quality:
    -- set here the MJPEG-quality in percent
    --
    -- integer AudioCodec
    -- the audiocodec to use for the video
    -- 1, 16 bit PCM
    -- 2, 24 bit PCM
    -- 3, 32 bit FP
    -- 4, AAC(needs FFMPEG 4.1.3 installed)
    -- 5, MP3(needs FFMPEG 4.1.3 installed)
    -- 6, NONE
    --
    -- integer WIDTH
    -- the width of the video in pixels; 1 to 2147483647; only even values(2,4,6,etc) will be accepted by Reaper, uneven will be rounded up!
    --
    -- integer HEIGHT
    -- the height of the video in pixels; 1 to 2147483647; only even values(2,4,6,etc) will be accepted by Reaper, uneven will be rounded up!
    --
    -- number FPS
    -- the fps of the video; must be a double-precision-float value (e.g. 9.09 or 25.00); 0.01 to 2000.00
    --
    -- boolean AspectRatio
    -- the aspect-ratio; true, keep source aspect ratio; false, don't keep source aspect ratio
    --
    -- optional integer VIDKBPS
    -- the video-bitrate of the video in kbps; 1 to 2147483647(default 2048)
    --
    -- optional integer AUDKBPS
    -- the video-bitrate of the video in kbps; 1 to 2147483647(default 128)
    --
    -- optional string VideoOptions
    -- additional FFMPEG-options for rendering the video; examples:
    -- g=1 ; all keyframes
    -- crf=1  ; h264 high quality
    -- crf=51 ; h264 small size
    --
    -- optional string AudioOptions
    -- additional FFMPEG-options for rendering the video; examples:
    -- q=0 ; mp3 VBR highest
    -- q=9 ; mp3 VBR lowest
    local render_string = ultraschall.CreateRenderCFG_QTMOVMP4_Video(2, 100, 2, 1920, 1080, frame_rate, true)

    local silently_increment_filename = false
    local add_to_proj = false
    local save_copy_of_project = false
    local render_queue_delay = false
    local render_queue_delay_seconds = 0
    local close_after_render = true -- the dialog, not the Reaper project


    video = ultraschall.CreateNewRenderTable(source, bounds, start_pos, end_pos, tail_flag, tail_ms,
        render_dir, file_name, sample_rate, channels, render_type, project_sample_rate_fx_processing,
        render_resample, keep_mono, keep_multichannel, dither, render_string, silently_increment_filename,
        add_to_proj, save_copy_of_project, render_queue_delay, render_queue_delay_seconds, close_after_render)

    set_bounds_to_items {}

    -- This changes the current render settings, but doesn't kick off the render process
    retval, dirty = ultraschall.ApplyRenderTable_Project(video)


    -- This kicks off the render process
    -- args:
    -- optional string project filename_with_path (to the rpp-file that you want to render; nil, to render the current active project)
    -- optional table RenderTable: the RenderTable with all render-settings, that you want to apply; nil, use the project's existing settings
    -- optional boolean AddToProj: true, add the rendered files to the project; nil or false, don't add them; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed only has an effect, when rendering the current active project
    -- optional boolean CloseAfterRender: true or nil, closes rendering to file-dialog after rendering is finished; false, keep it open; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    -- optional boolean SilentlyIncrementFilename; true or nil, silently increment filename, when file already exists; false, ask for overwriting; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    -- count, media_item_state_chunk_array, file_array = ultraschall.RenderProject_RenderTable(nil, video, false, true, false)

    -- Track: Unselect (clear selection of) all tracks
    reaper.Main_OnCommand(40297, 0)
end


function render_skinny_stems(recipient, dst_dir, file_naming_convention)
    local skinny_stems = get_skinny_stems()

    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track)
        for i, stem in ipairs(skinny_stems) do
            if track_name == stem then
                -- FIXME: need to check if children have media items; if not, do not select
                reaper.SetTrackSelected(track, true)
            end
        end
    end


    --Settings of the render table
    local source = 128 -- 0, Master mix;
    -- 1, Master mix + stems;
    -- 3, Stems (selected tracks);
    -- 8, Region render matrix;
    -- 16, Tracks with only Mono-Media to Mono Files;
    -- 32, Selected media items; 64, selected media items via master;
    -- 128, selected tracks via master
    -- 4096, Razor edit areas
    -- 4224, Razor edit areas via master
    local bounds = 2 -- 0, Custom time range; 1, Entire project(default); 2, Time selection; 3, Project regions; 4, Selected Media Items(in combination with Source 32); 5, Selected regions; 6, Razor edit areas; 7, All project markers; 8, Selected markers
    local start_pos = 0
    local end_pos = 0
    local tail_flag = 1
    local tail_ms = 0
    local render_dir = dst_dir
    local file_name = file_naming_convention .. " - $track"
    local sample_rate = 48000
    local channels = 2
    local render_type = 0      -- 0, Full-speed Offline(default); 1, 1x Offline; 2, Online Render; 3, Online Render(Idle); 4, Offline Render(Idle)
    local project_sample_rate_fx_processing = true
    local render_resample = 10 -- 0, Sinc Interpolation: 64pt (medium quality); 1, Linear Interpolation: (low quality); 2, Point Sampling (lowest quality, retro); 3, Sinc Interpolation: 192pt; 4, Sinc Interpolation: 384pt; 5, Linear Interpolation + IIR; 6, Linear Interpolation + IIRx2; 7, Sinc Interpolation: 16pt; 8, Sinc Interpolation: 512pt(slow); 9, Sinc Interpolation: 768pt(very slow); 10, r8brain free (highest quality, fast)
    local keep_mono = true
    local keep_multichannel = true
    local dither = 0 -- 0 = none; &1, dither master mix; &2, noise shaping master mix; &4, dither stems; &8, dither noise shaping stems

    -- args:
    -- (int) bit depth: 0, 8 Bit PCM; 1, 16 Bit PCM; 2, 24 Bit PCM; 3, 32 Bit FP; 4, 64 Bit FP; 5, 4 Bit IMA ADPCM; 6, 2 Bit cADPCM; 7, 32 Bit PCM; 8, 8 Bit u-Law
    -- (int) large files: 0, Auto WAV/Wave64; 1, Auto Wav/RF64; 2, Force WAV; 3, Force Wave64; 4, Force RF64
    -- (int) bwf_chunk (write 'bext' chunk and include project filename in BWF data - checkboxes): 0, unchecked - unchecked; 1, checked - unchecked; 2, unchecked - checked; 3, checked - checked
    -- (int) the "include markers" dropdown list: 0, Do not include markers and regions; 1, Markers + regions; 2, Markers + regions starting with #; 3, Markers only; 4, Markers starting with # only; 5, Regions only; 6, Regions starting with # only
    -- (bool) embed tempo-checkbox; true, checked; false, unchecked
    local render_string = ultraschall.CreateRenderCFG_WAV(24, 2, 1, 0, false)

    local silently_increment_filename = false
    local add_to_proj = false
    local save_copy_of_project = false
    local render_queue_delay = false
    local render_queue_delay_seconds = 0
    local close_after_render = true -- the dialog, not the Reaper project


    skinny_stems = ultraschall.CreateNewRenderTable(source, bounds, start_pos, end_pos, tail_flag, tail_ms,
        render_dir, file_name, sample_rate, channels, render_type, project_sample_rate_fx_processing,
        render_resample, keep_mono, keep_multichannel, dither, render_string, silently_increment_filename,
        add_to_proj, save_copy_of_project, render_queue_delay, render_queue_delay_seconds, close_after_render)

    set_bounds_to_items {}

    -- This changes the current render settings, but doesn't kick off the render process
    -- retval, dirty = ultraschall.ApplyRenderTable_Project(skinny_stems)

    -- This kicks off the render process
    -- args:
    -- optional string project filename_with_path (to the rpp-file that you want to render; nil, to render the current active project)
    -- optional table RenderTable: the RenderTable with all render-settings, that you want to apply; nil, use the project's existing settings
    -- optional boolean AddToProj: true, add the rendered files to the project; nil or false, don't add them; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed only has an effect, when rendering the current active project
    -- optional boolean CloseAfterRender: true or nil, closes rendering to file-dialog after rendering is finished; false, keep it open; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    -- optional boolean SilentlyIncrementFilename; true or nil, silently increment filename, when file already exists; false, ask for overwriting; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    -- count, media_item_state_chunk_array, file_array = ultraschall.RenderProject_RenderTable(nil, skinny_stems false, true, false)

    -- Track: Unselect (clear selection of) all tracks
    -- reaper.Main_OnCommand(40297, 0)
end


function render_wide_stems(recipient, dst_dir, file_naming_convention)
    local wide_stems = get_wide_stems()

    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track)

        for i, stem in ipairs(wide_stems) do
            if track_name == stem then
                -- FIXME: need to check if children have media items; if not, do not select
                reaper.SetTrackSelected(track, true)
            end
        end
    end

    -- settings of the render table
    local source = 128 -- 0, Master mix;
    -- 1, Master mix + stems;
    -- 3, Stems (selected tracks);
    -- 8, Region render matrix;
    -- 16, Tracks with only Mono-Media to Mono Files;
    -- 32, Selected media items; 64, selected media items via master;
    -- 128, selected tracks via master
    -- 4096, Razor edit areas
    -- 4224, Razor edit areas via master
    local bounds = 2 -- 0, Custom time range; 1, Entire project(default); 2, Time selection; 3, Project regions; 4, Selected Media Items(in combination with Source 32); 5, Selected regions; 6, Razor edit areas; 7, All project markers; 8, Selected markers
    local start_pos = 0
    local end_pos = 0
    local tail_flag = 1
    local tail_ms = 0
    local render_dir = dst_dir

    local file_name = nil
    if recipient == "engineer" then
        file_name = "$track - " .. file_naming_convention
    elseif recipient == "mx_edit" then
        file_name = file_naming_convention .. " - $track"
    end

    local sample_rate = 48000
    local channels = 2
    local render_type = 0      -- 0, Full-speed Offline(default); 1, 1x Offline; 2, Online Render; 3, Online Render(Idle); 4, Offline Render(Idle)
    local project_sample_rate_fx_processing = true
    local render_resample = 10 -- 0, Sinc Interpolation: 64pt (medium quality); 1, Linear Interpolation: (low quality); 2, Point Sampling (lowest quality, retro); 3, Sinc Interpolation: 192pt; 4, Sinc Interpolation: 384pt; 5, Linear Interpolation + IIR; 6, Linear Interpolation + IIRx2; 7, Sinc Interpolation: 16pt; 8, Sinc Interpolation: 512pt(slow); 9, Sinc Interpolation: 768pt(very slow); 10, r8brain free (highest quality, fast)
    local keep_mono = true
    local keep_multichannel = true
    local dither = 0 -- 0 = none; &1, dither master mix; &2, noise shaping master mix; &4, dither stems; &8, dither noise shaping stems

    -- args:
    -- (int) bit depth: 0, 8 Bit PCM; 1, 16 Bit PCM; 2, 24 Bit PCM; 3, 32 Bit FP; 4, 64 Bit FP; 5, 4 Bit IMA ADPCM; 6, 2 Bit cADPCM; 7, 32 Bit PCM; 8, 8 Bit u-Law
    -- (int) large files: 0, Auto WAV/Wave64; 1, Auto Wav/RF64; 2, Force WAV; 3, Force Wave64; 4, Force RF64
    -- (int) bwf_chunk (write 'bext' chunk and include project filename in BWF data - checkboxes): 0, unchecked - unchecked; 1, checked - unchecked; 2, unchecked - checked; 3, checked - checked
    -- (int) the "include markers" dropdown list: 0, Do not include markers and regions; 1, Markers + regions; 2, Markers + regions starting with #; 3, Markers only; 4, Markers starting with # only; 5, Regions only; 6, Regions starting with # only
    -- (bool) embed tempo-checkbox; true, checked; false, unchecked
    local render_string = ultraschall.CreateRenderCFG_WAV(24, 2, 1, 0, false)

    local silently_increment_filename = false
    local add_to_proj = false
    local save_copy_of_project = false
    local render_queue_delay = false
    local render_queue_delay_seconds = 0
    local close_after_render = true -- the dialog, not the Reaper project


    skinny_stems = ultraschall.CreateNewRenderTable(source, bounds, start_pos, end_pos, tail_flag, tail_ms,
        render_dir, file_name, sample_rate, channels, render_type, project_sample_rate_fx_processing,
        render_resample, keep_mono, keep_multichannel, dither, render_string, silently_increment_filename,
        add_to_proj, save_copy_of_project, render_queue_delay, render_queue_delay_seconds, close_after_render)

    set_bounds_to_items {}

    -- This changes the current render settings, but doesn't kick off the render process
    retval, dirty = ultraschall.ApplyRenderTable_Project(skinny_stems)

    -- This kicks off the render process
    -- args:
    -- optional string project filename_with_path (to the rpp-file that you want to render; nil, to render the current active project)
    -- optional table RenderTable: the RenderTable with all render-settings, that you want to apply; nil, use the project's existing settings
    -- optional boolean AddToProj: true, add the rendered files to the project; nil or false, don't add them; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed only has an effect, when rendering the current active project
    -- optional boolean CloseAfterRender: true or nil, closes rendering to file-dialog after rendering is finished; false, keep it open; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    -- optional boolean SilentlyIncrementFilename; true or nil, silently increment filename, when file already exists; false, ask for overwriting; will overwrite the settings in the RenderTable; will default to true, if no RenderTable is passed
    count, media_item_state_chunk_array, file_array = ultraschall.RenderProject_RenderTable(nil, skinny_stems, false,
        true, false)

    -- Track: Unselect (clear selection of) all tracks
    reaper.Main_OnCommand(40297, 0)
end
