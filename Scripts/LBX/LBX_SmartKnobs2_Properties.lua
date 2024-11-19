-- @version 1.0
-- @author Leon Bradley (LBX)
-- @description LBX SK2 PopUp
-- @website 
-- @changelog
--    1. Initial stable version
        
  local SCRIPT='LBX_SK2_POPUP'
  local SCRIPTDATA='LBX_SK2_POPUPDATA'
  local SKSCRIPT='LBX_SK'
  
  local resource_path = reaper.GetResourcePath().."/Scripts/LBX/SmartKnobs2_DATA/"
  local lvar = {}
  lvar.qfx_faders = 128
  
  lvar.attach = 0
  lvar.fontoffset = 0
  
  lvar.butt_h = 22
  lvar.butth_limit = 40
  lvar.fadjust = 0
  
  lvar.aot = false
  lvar.linkmodes = {'Name','Value'}
  lvar.apply_dirty = false
  
  local colours = {faderborder = '25 25 25',
                   fader = '55 55 55',
                   fader_inactive = '0 80 255',
                   faderbg = '35 35 35',
                   faderbg2 = '15 15 15',
                   ibox = '15 15 15',
                   iboxT = '205 205 205',
                   mainbg = '35 35 35',
                   buttcol = '25 25 25',
                   buttcollit = '205 205 205',
                   faderlit = '87 109 130',
                   faderlitcc = '220 148 52',
                   faderlitcc_chasefail = '180 108 12',
                   faderlittr = '185 86 132',
                   faderlitac = '250 200 52',
                   faderlitint = '0 195 167',
                   pnamelit = '107 129 150',
                   globalfader = '38 165 82',
                   globalfader_txt = '0 0 0',
                   permafader = '205 205 205',
                   permafader_txt = '0 0 0',
                   layerfader = '150 90 190',
                   layerfader_txt = '0 0 0',                   
                   mainfader = '64 64 64',
                   mainfader_txt = '0 0 0',                   
                   devctlname = '64 64 64',
                   devctlunassigned = '25 25 25',
                   devctlassigned = '25 25 25',
                   modebtnhl = '205 205 205',
                   faderunassigned = '255 42 0',
                   faderunassigned_txt = '0 0 0',
                   sectionline = '20 20 20',}

  local tab_xtouch_color_menu = {'Off','Red','Green','Yellow','Blue','Magenta','Cyan','White','Invert Top Line','Invert Bottom Line'}
  local tab_xtouch_colors = {}
  tab_xtouch_colors[0] = {v = 0, c = '0 0 0'}
  tab_xtouch_colors[1] = {v = 1, c = '255 0 0'}
  tab_xtouch_colors[2] = {v = 2, c = '0 255 0'}
  tab_xtouch_colors[3] = {v = 3, c = '255 216 0'}
  tab_xtouch_colors[4] = {v = 4, c = '0 38 255'}
  tab_xtouch_colors[5] = {v = 5, c = '255 0 220'}
  tab_xtouch_colors[6] = {v = 6, c = '0 255 255'}
  tab_xtouch_colors[7] = {v = 7, c = '255 255 255'}
  
  local ptype_cnt = 5                   
  local ptype = {host = 1,
                 cc = 2,
                 track = 3,
                 action = 4,
                 internal = 5}
  local ptype_txt = {'HOST',
                     'CC',
                     'TRK',
                     'ACT',
                     'INT'}
  local ptype_txt2 = {'PLUGIN',
                      'CC',
                      'TRACK',
                      'ACTION',
                      'INTERNAL'}

  local ptype_info = {}
  ptype_info[1] = {idx = 'faderlit', tsz = -4, col = colours.faderlit, btntxt = '0 0 0'}
  ptype_info[2] = {idx = 'faderlitcc', tsz = -1, col = colours.faderlitcc, btntxt = '0 0 0'}
  ptype_info[3] = {idx = 'faderlittr', tsz = -1, col = colours.faderlittr, btntxt = '0 0 0'}
  ptype_info[4] = {idx = 'faderlitac', tsz = -1, col = colours.faderlitac, btntxt = '0 0 0'}
  ptype_info[5] = {idx = 'faderlitint', tsz = -1, col = colours.faderlitint, btntxt = '0 0 0'}
  
  local tab_btntype = {}
  tab_btntype[1] = {t='Single',v=0}
  tab_btntype[2] = {t='Hold/Repeat',v=5}
  tab_btntype[3] = {t='Toggle',v=4}  
  tab_btntype[4] = {t='Hold/Sustain',v=6}
  
  local tab_trparams = {'Vol','Pan','Mute','Solo','Rec','FX Enabled','Selected','Width','Dual Pan L','Dual Pan R','Peak Meter','Peak Meter L','Peak Meter R','Track Name'}
  local tab_trparams_code = {'D_VOL','D_PAN','B_MUTE','I_SOLO','I_RECARM','I_FXEN','I_SELECTED','D_WIDTH','D_DUALPANL','D_DUALPANR','X_PKMETER','X_PKMETERL','X_PKMETERR','X_TRACKNAME'}    
  local tab_trparams_pv = {1, 2}
  local tab_trsnds = {}
  
  local track_info = {}
  track_info['D_VOL'] = {btype = 0, states = 2, min = 0, max = 4, scaling = 12, conv = reaper.mkvolstr}
  track_info['D_PAN'] = {btype = 0, states = 3, min = -1, max = 1, conv = reaper.mkpanstr}
  track_info['B_MUTE'] = {btype = 4, states = 2, min = 0, max = 1, conv = conv_onoff, convval = frombool}
  track_info['I_SOLO'] = {btype = 4, states = 2, min = 0, max = 2, conv = conv_onoff}
  track_info['I_RECARM'] = {btype = 4, states = 2, min = 0, max = 1, conv = conv_onoff}
  track_info['I_FXEN'] = {btype = 4, states = 2, min = 0, max = 1, conv = conv_onoff}
  track_info['I_SELECTED'] = {btype = 4, states = 2, min = 0, max = 1, conv = conv_onoff}
  track_info['D_WIDTH'] = {btype = 0, states = 3, min = -1, max = 1, conv = reaper.mkpanstr}
  track_info['D_DUALPANL'] = {btype = 0, states = 3, min = -1, max = 1, conv = reaper.mkpanstr}
  track_info['D_DUALPANR'] = {btype = 0, states = 3, min = -1, max = 1, conv = reaper.mkpanstr}
  track_info['X_PKMETER'] = {mononly = true, btype = 0, states = 2, min = 0, max = 4, scaling = 12, conv = reaper.mkvolstr}
  track_info['X_PKMETERL'] = {mononly = true, btype = 0, states = 2, min = 0, max = 4, scaling = 12, conv = reaper.mkvolstr}
  track_info['X_PKMETERR'] = {mononly = true, btype = 0, states = 2, min = 0, max = 4, scaling = 12, conv = reaper.mkvolstr}
  track_info['X_TRACKNAME'] = {mononly = true, btype = 0, states = 1, min = 0, max = 1, scaling = 12}
  
  local tracksend_info = {}
  tracksend_info[1] = {btype = 0, states = 2, min = 0, max = 4, scaling = 12, conv = reaper.mkvolstr}
  tracksend_info[2] = {btype = 0, states = 2, min = -1, max = 1, conv = reaper.mkpanstr}
  tracksend_info[3] = {btype = 4, states = 2, min = 0, max = 1, conv = conv_onoff}
    
  local tab_encres = {16,32,64,128,256,512,1024,2048,4096}
  
  local tab_scrubnudge = {}
  tab_scrubnudge[0] = {desc = 'Scrub', val = -1}
  tab_scrubnudge[1] = {desc = 'Frames', val = 18}
  tab_scrubnudge[2] = {desc = 'Seconds', val = 1}
  tab_scrubnudge[3] = {desc = 'Minutes', val = 1}
  tab_scrubnudge[4] = {desc = 'Beats', val = 2}
  tab_scrubnudge[5] = {desc = 'Bars', val = 2}
  tab_scrubnudge[6] = {desc = 'Markers', val = -2}
  tab_scrubnudge[7] = {desc = 'Items', val = -3}
  tab_scrubnudge[8] = {desc = 'Grid', val = -4}
  
  lvar.ic_autocollapse = true
  local ic_secvis = {}
  local ic_secvis_commands
  local internal_commands = {}
  local internal_commands_idx = {}

  local sec = 1
  local idx = 1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Internal track Offset', sec = sec}
  internal_commands[idx+1] = {code = 1, codeval = -1, comm = 'Track offset -1', preventedit = true}
  internal_commands[idx+2] = {code = 1, codeval = 1, comm = 'Track offset +1', preventedit = true}
  internal_commands[idx+3] = {code = 1, codeval = -8, comm = 'Track offset -8', preventedit = true}
  internal_commands[idx+4] = {code = 1, codeval = 8, comm = 'Track offset +8', preventedit = true}
  internal_commands[idx+5] = {code = 1, codeval = -16, comm = 'Track offset -16', preventedit = true}
  internal_commands[idx+6] = {code = 1, codeval = 16, comm = 'Track offset +16', preventedit = true}
  internal_commands[idx+7] = {code = 1, codeval = -24, comm = 'Track offset -24', preventedit = true}
  internal_commands[idx+8] = {code = 1, codeval = 24, comm = 'Track offset +24', preventedit = true}
  internal_commands[idx+9] = {code = 1, codeval = -32, comm = 'Track offset -32', preventedit = true}
  internal_commands[idx+10] = {code = 1, codeval = 32, comm = 'Track offset +32', preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Global Maps', sec = sec}
  internal_commands[idx+1] = {code = 2, codeval = 1, comm = 'Enable/disable global map', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 2, codeval = 2, comm = 'Previous global map', preventedit = true}
  internal_commands[idx+3] = {code = 2, codeval = 3, comm = 'Next global map', preventedit = true}
  internal_commands[idx+4] = {code = 2, codeval = 4, comm = 'Select global map 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+5] = {code = 2, codeval = 5, comm = 'Select global map 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+6] = {code = 2, codeval = 6, comm = 'Select global map 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+7] = {code = 2, codeval = 7, comm = 'Select global map 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+8] = {code = 2, codeval = 8, comm = 'Select global map 5', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+9] = {code = 2, codeval = 9, comm = 'Select global map 6', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+10] = {code = 2, codeval = 10, comm = 'Select global map 7', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+11] = {code = 2, codeval = 11, comm = 'Select global map 8', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+12] = {code = 2, codeval = 12, comm = 'Select global map 9', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+13] = {code = 2, codeval = 13, comm = 'Select global map 10', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+14] = {code = 2, codeval = 14, comm = 'Select global map 11', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+15] = {code = 2, codeval = 15, comm = 'Select global map 12', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+16] = {code = 2, codeval = 16, comm = 'Select global map 13', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+17] = {code = 2, codeval = 17, comm = 'Select global map 14', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+18] = {code = 2, codeval = 18, comm = 'Select global map 15', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+19] = {code = 2, codeval = 19, comm = 'Select global map 16', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Common Functions', sec = sec}
  internal_commands[idx+1] = {code = 3, codeval = 1, comm = 'Flip', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 3, codeval = 2, comm = 'Select track mode', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+3] = {code = 3, codeval = 3, comm = 'Select plugin instance mode', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+4] = {code = 3, codeval = 4, comm = 'Select plugin mode', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+5] = {code = 3, codeval = 5, comm = 'Time/beats display', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+6] = {code = 3, codeval = 6, comm = 'Print CCs to selected items', preventedit = true}
  internal_commands[idx+7] = {code = 3, codeval = 10, comm = 'Retransmit value data', preventedit = true}
  internal_commands[idx+8] = {code = 3, codeval = 12, comm = 'Enable Remapped Controls', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+9] = {code = 3, codeval = 13, comm = 'REC: Enable/disable automap', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  --codeval 14/15/16 reserved for automap - but do not require specific assignable assignments (? what about non XTouch??)
  internal_commands[idx+10] = {code = 3, codeval = 17, comm = 'Enable/disable learn FX', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+11] = {code = 3, codeval = 18, comm = 'Enable/disable REC mode', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+12] = {code = 3, codeval = 19, comm = 'Toggle FB mode', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+13] = {code = 3, codeval = 21, comm = 'Toggle assignment display mode', mon = 1, buttype = 3, toggle = 4, states = {0, 1, 2, 3}, preventedit = true}
  internal_commands[idx+14] = {code = 3, codeval = 20, comm = 'Keep values on scribble strips', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+15] = {code = 3, codeval = 22, comm = 'Toggle multi/single track select', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Reaper Functions', sec = sec}
  internal_commands[idx+1] = {code = 17, codeval = 1, comm = 'TCP Track Height'}
  internal_commands[idx+2] = {code = 17, codeval = 2, comm = 'All Track Envelope Lane Height'}
  internal_commands[idx+3] = {code = 17, codeval = 3, comm = 'Selected Envelope Lane Height'}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Button Groups', sec = sec}
  internal_commands[idx+1] = {code = 3, codeval = 7, comm = 'Highlight group on/off', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 3, codeval = 8, comm = 'Previous button group', preventedit = true}
  internal_commands[idx+3] = {code = 3, codeval = 9, comm = 'Next button group', preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'User Filter Selection', sec = sec}
  internal_commands[idx+1] = {code = 4, codeval = 1, comm = 'Previous filter', preventedit = true}
  internal_commands[idx+2] = {code = 4, codeval = 2, comm = 'Next filter', preventedit = true}
  internal_commands[idx+3] = {code = 4, codeval = 3, comm = 'Enable/disable filter', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+4] = {code = 4, codeval = 4, comm = 'Select user filter 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+5] = {code = 4, codeval = 5, comm = 'Select user filter 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+6] = {code = 4, codeval = 6, comm = 'Select user filter 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+7] = {code = 4, codeval = 7, comm = 'Select user filter 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+8] = {code = 4, codeval = 8, comm = 'Select user filter 5', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+9] = {code = 4, codeval = 9, comm = 'Select user filter 6', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+10] = {code = 4, codeval = 10, comm = 'Select user filter 7', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+11] = {code = 4, codeval = 11, comm = 'Select user filter 8', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Jog/Scrub', sec = sec}
  internal_commands[idx+1] = {code = 5, codeval = 1, comm = 'Scrub'}
  internal_commands[idx+2] = {code = 5, codeval = 2, comm = 'Set scrub time (scrub)'}
  internal_commands[idx+3] = {code = 5, codeval = 3, comm = 'Set nudge time (frames)'}
  internal_commands[idx+4] = {code = 5, codeval = 4, comm = 'Set nudge time (ms)'}
  internal_commands[idx+5] = {code = 5, codeval = 5, comm = 'Set nudge time (grid)'}
  internal_commands[idx+6] = {code = 5, codeval = 6, comm = 'Set scrub/nudge'}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'MIDI Editor CC Lanes', sec = sec}
  internal_commands[idx+1] = {code = 6, codeval = 39, comm = 'Enable/disable auto lanes', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 6, codeval = 40, comm = 'Enable/disable lane preset', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+3] = {code = 6, codeval = 7, comm = 'Velocity lane toggle', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+4] = {code = 6, codeval = 1, comm = 'Fixed slot 1 toggle', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+5] = {code = 6, codeval = 2, comm = 'Fixed slot 2 toggle', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+6] = {code = 6, codeval = 3, comm = 'Fixed slot 3 toggle', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+7] = {code = 6, codeval = 4, comm = 'Fixed slot 4 toggle', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+8] = {code = 6, codeval = 8, comm = 'Show all fixed lanes', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+9] = {code = 6, codeval = 9, comm = 'Hide all auto lanes', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+10] = {code = 6, codeval = 10, comm = 'Zoom/solo lanes', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+11] = {code = 6, codeval = 11, comm = 'Zoom/solo CC assignment 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+12] = {code = 6, codeval = 12, comm = 'Zoom/solo CC assignment 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+13] = {code = 6, codeval = 13, comm = 'Zoom/solo CC assignment 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+14] = {code = 6, codeval = 14, comm = 'Zoom/solo CC assignment 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+15] = {code = 6, codeval = 15, comm = 'Zoom/solo CC assignment 5', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+16] = {code = 6, codeval = 16, comm = 'Zoom/solo CC assignment 6', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+17] = {code = 6, codeval = 17, comm = 'Zoom/solo CC assignment 7', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+18] = {code = 6, codeval = 18, comm = 'Zoom/solo CC assignment 8', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+19] = {code = 6, codeval = 19, comm = 'Zoom/solo active lane 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+20] = {code = 6, codeval = 20, comm = 'Zoom/solo active lane 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+21] = {code = 6, codeval = 21, comm = 'Zoom/solo active lane 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+22] = {code = 6, codeval = 22, comm = 'Zoom/solo active lane 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+23] = {code = 6, codeval = 23, comm = 'Zoom/solo velocity lane', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+24] = {code = 6, codeval = 5, comm = 'Inc. lane viewset/solo', mon = 1, buttype = 1, preventedit = true}
  internal_commands[idx+25] = {code = 6, codeval = 6, comm = 'Dec. lane viewset/solo', mon = 1, buttype = 1, preventedit = true}
  internal_commands[idx+26] = {code = 6, codeval = 24, comm = 'All lane height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+27] = {code = 6, codeval = 25, comm = 'Lane 1 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+28] = {code = 6, codeval = 26, comm = 'Lane 2 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+29] = {code = 6, codeval = 27, comm = 'Lane 3 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+30] = {code = 6, codeval = 28, comm = 'Lane 4 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+31] = {code = 6, codeval = 29, comm = 'Previous lane preset', mon = 1, buttype = 1, preventedit = true}
  internal_commands[idx+32] = {code = 6, codeval = 30, comm = 'Next lane preset', mon = 1, buttype = 1, preventedit = true}
  internal_commands[idx+33] = {code = 6, codeval = 31, comm = 'Select lane preset 1', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+34] = {code = 6, codeval = 32, comm = 'Select lane preset 2', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+35] = {code = 6, codeval = 33, comm = 'Select lane preset 3', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+36] = {code = 6, codeval = 34, comm = 'Select lane preset 4', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+37] = {code = 6, codeval = 35, comm = 'Select lane preset 5', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+38] = {code = 6, codeval = 36, comm = 'Select lane preset 6', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+39] = {code = 6, codeval = 37, comm = 'Select lane preset 7', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+40] = {code = 6, codeval = 38, comm = 'Select lane preset 8', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Additional Layers', sec = sec}
  internal_commands[idx+1] = {code = 7, codeval = 1, comm = 'Toggle additional layer 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 7, codeval = 2, comm = 'Toggle additional layer 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+3] = {code = 7, codeval = 3, comm = 'Toggle additional layer 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+4] = {code = 7, codeval = 4, comm = 'Toggle additional layer 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+5] = {code = 7, codeval = 5, comm = 'Toggle additional layer 5', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+6] = {code = 7, codeval = 6, comm = 'Toggle additional layer 6', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+7] = {code = 7, codeval = 7, comm = 'Toggle additional layer 7', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+8] = {code = 7, codeval = 8, comm = 'Toggle additional layer 8', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+9] = {code = 7, codeval = 9, comm = 'Toggle additional layer 9', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+10] = {code = 7, codeval = 10, comm = 'Toggle additional layer 10', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+11] = {code = 7, codeval = 11, comm = 'Toggle additional layer 11', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+12] = {code = 7, codeval = 12, comm = 'Toggle additional layer 12', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+13] = {code = 7, codeval = 13, comm = 'Additional layer off', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+14] = {code = 7, codeval = 14, comm = 'Previous additional layer', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+15] = {code = 7, codeval = 15, comm = 'Next additional layer', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+16] = {code = 7, codeval = 16, comm = 'Latch additional layer 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+17] = {code = 7, codeval = 17, comm = 'Latch additional layer 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+18] = {code = 7, codeval = 18, comm = 'Latch additional layer 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+19] = {code = 7, codeval = 19, comm = 'Latch additional layer 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+20] = {code = 7, codeval = 20, comm = 'Latch additional layer 5', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+21] = {code = 7, codeval = 21, comm = 'Latch additional layer 6', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+22] = {code = 7, codeval = 22, comm = 'Latch additional layer 7', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+23] = {code = 7, codeval = 23, comm = 'Latch additional layer 8', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+24] = {code = 7, codeval = 24, comm = 'Latch additional layer 9', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+25] = {code = 7, codeval = 25, comm = 'Latch additional layer 10', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+26] = {code = 7, codeval = 26, comm = 'Latch additional layer 11', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+27] = {code = 7, codeval = 27, comm = 'Latch additional layer 12', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Takeover Assignments', sec = sec}
  internal_commands[idx+1] = {code = 9, codeval = 1, comm = 'Toggle takeover 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 9, codeval = 2, comm = 'Toggle takeover 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+3] = {code = 9, codeval = 3, comm = 'Toggle takeover 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+4] = {code = 9, codeval = 4, comm = 'Toggle takeover 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'REC Automation Modes', sec = sec}
  internal_commands[idx+1] = {code = 10, codeval = 1, comm = 'Trim/read', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+2] = {code = 10, codeval = 2, comm = 'Read', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+3] = {code = 10, codeval = 3, comm = 'Touch', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+4] = {code = 10, codeval = 4, comm = 'Write', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+5] = {code = 10, codeval = 5, comm = 'Latch', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+6] = {code = 10, codeval = 6, comm = 'Latch preview', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  --internal_commands[idx+7] = {code = 10, codeval = 7, comm = 'Toggle SK2 REC', mon = 1, buttype = 1, toggle = 2, states = {0, 1}, preventedit = true}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Auto Envelopes', sec = sec}
  internal_commands[idx+1] = {code = 11, codeval = 1, comm = 'Enable/disable auto env\'s', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 11, codeval = 2, comm = 'Prev envelope bank', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+3] = {code = 11, codeval = 3, comm = 'Next envelope bank', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+4] = {code = 11, codeval = 4, comm = 'All env height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+5] = {code = 11, codeval = 5, comm = 'Env 1 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+6] = {code = 11, codeval = 6, comm = 'Env 2 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+7] = {code = 11, codeval = 7, comm = 'Env 3 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+8] = {code = 11, codeval = 8, comm = 'Env 4 height multiplier', mon = 1, buttype = 3, toggle = 2, states = {50, 100}}
  internal_commands[idx+9] = {code = 11, codeval = 9, comm = 'Spread sel track envelopes', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+10] = {code = 11, codeval = 20, comm = 'Solo auto env', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+11] = {code = 11, codeval = 10, comm = 'Solo auto env 1', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+12] = {code = 11, codeval = 11, comm = 'Solo auto env 2', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+13] = {code = 11, codeval = 12, comm = 'Solo auto env 3', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+14] = {code = 11, codeval = 13, comm = 'Solo auto env 4', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+15] = {code = 11, codeval = 14, comm = 'Solo auto env 5', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+16] = {code = 11, codeval = 15, comm = 'Solo auto env 6', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+17] = {code = 11, codeval = 16, comm = 'Solo auto env 7', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+18] = {code = 11, codeval = 17, comm = 'Solo auto env 8', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+19] = {code = 11, codeval = 18, comm = 'Solo prev envelope', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+20] = {code = 11, codeval = 19, comm = 'Solo next envelope', mon = 1, buttype = 1, toggle = 0, preventedit = true}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Automation Items', sec = sec}
  internal_commands[idx+1] = {code = 8, codeval = 6, comm = 'Rescan AI storage track'}
  internal_commands[idx+2] = {code = 8, codeval = 1, comm = 'Insert/replace AI (next)', preventedit = true}
  internal_commands[idx+3] = {code = 8, codeval = 2, comm = 'Insert/replace AI (previous)', preventedit = true}
  internal_commands[idx+4] = {code = 8, codeval = 3, comm = 'AI Amplitude'}
  internal_commands[idx+5] = {code = 8, codeval = 4, comm = 'AI Baseline'}
  internal_commands[idx+6] = {code = 8, codeval = 5, comm = 'AI Play Rate'}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Track Tags', sec = sec}
  internal_commands[idx+1] = {code = 12, codeval = 1, comm = 'Toggle show tag', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+2] = {code = 12, codeval = 2, comm = 'Show tag group 1', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+3] = {code = 12, codeval = 3, comm = 'Show tag group 2', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+4] = {code = 12, codeval = 4, comm = 'Show tag group 3', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+5] = {code = 12, codeval = 5, comm = 'Show tag group 4', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+6] = {code = 12, codeval = 6, comm = 'Show tag group 5', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+7] = {code = 12, codeval = 7, comm = 'Show tag group 6', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+8] = {code = 12, codeval = 8, comm = 'Show tag group 7', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+9] = {code = 12, codeval = 9, comm = 'Show tag group 8', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+10] = {code = 12, codeval = 10, comm = 'Show tag group 9', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+11] = {code = 12, codeval = 11, comm = 'Show tag group 10', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+12] = {code = 12, codeval = 12, comm = 'Show tag group 11', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+13] = {code = 12, codeval = 13, comm = 'Show tag group 12', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+14] = {code = 12, codeval = 14, comm = 'Show tag group 13', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+15] = {code = 12, codeval = 15, comm = 'Show tag group 14', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+16] = {code = 12, codeval = 16, comm = 'Show tag group 15', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+17] = {code = 12, codeval = 17, comm = 'Show tag group 16', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+18] = {code = 12, codeval = 18, comm = 'Show tag group 17', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+19] = {code = 12, codeval = 19, comm = 'Show tag group 18', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+20] = {code = 12, codeval = 20, comm = 'Show tag group 19', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+21] = {code = 12, codeval = 21, comm = 'Show tag group 20', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+22] = {code = 12, codeval = 22, comm = 'Show tag group 21', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+23] = {code = 12, codeval = 23, comm = 'Show tag group 22', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+24] = {code = 12, codeval = 24, comm = 'Show tag group 23', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+25] = {code = 12, codeval = 25, comm = 'Show tag group 24', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+26] = {code = 12, codeval = 26, comm = 'Show tag group 25', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+27] = {code = 12, codeval = 27, comm = 'Show tag group 26', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+28] = {code = 12, codeval = 28, comm = 'Show tag group 27', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+29] = {code = 12, codeval = 29, comm = 'Show tag group 28', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+30] = {code = 12, codeval = 30, comm = 'Show tag group 29', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+31] = {code = 12, codeval = 31, comm = 'Show tag group 30', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+32] = {code = 12, codeval = 32, comm = 'Show tag group 31', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+33] = {code = 12, codeval = 33, comm = 'Show tag group 32', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  
  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Retro Record', sec = sec}
  internal_commands[idx+1] = {code = 13, codeval = 1, comm = 'Quantize after capture', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 13, codeval = 2, comm = 'Set quantize strength', mon = 0, buttype = 3, toggle = 4, states = {25, 50, 75, 100}}
  internal_commands[idx+3] = {code = 13, codeval = 3, comm = 'Toggle selected items', mon = 0, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+4] = {code = 13, codeval = 4, comm = 'Play on fader touch (cc)', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Fader Finetune', sec = sec}
  internal_commands[idx+1] = {code = 14, codeval = 1, comm = 'Toggle finetune mode', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 14, codeval = 2, comm = 'Set finetune range', mon = 0, buttype = 3, toggle = 4, states = {8, 16, 24, 32}}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'FX Selection', sec = sec}
  internal_commands[idx+1] = {code = 15, codeval = 1, comm = 'Select by focused plugin', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+2] = {code = 15, codeval = 2, comm = 'Select FX Slot 1', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+3] = {code = 15, codeval = 3, comm = 'Select FX Slot 2', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+4] = {code = 15, codeval = 4, comm = 'Select FX Slot 3', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+5] = {code = 15, codeval = 5, comm = 'Select FX Slot 4', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+6] = {code = 15, codeval = 6, comm = 'Select FX Slot 5', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+7] = {code = 15, codeval = 7, comm = 'Select FX Slot 6', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+8] = {code = 15, codeval = 8, comm = 'Select FX Slot 7', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+9] = {code = 15, codeval = 9, comm = 'Select FX Slot 8', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+10] = {code = 15, codeval = 10, comm = 'Select FX Slot 9', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+11] = {code = 15, codeval = 11, comm = 'Select FX Slot 10', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+12] = {code = 15, codeval = 12, comm = 'Select FX Slot 11', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+13] = {code = 15, codeval = 13, comm = 'Select FX Slot 12', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+14] = {code = 15, codeval = 14, comm = 'Select FX Slot 13', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+15] = {code = 15, codeval = 15, comm = 'Select FX Slot 14', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+16] = {code = 15, codeval = 16, comm = 'Select FX Slot 15', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+17] = {code = 15, codeval = 17, comm = 'Select FX Slot 16', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+18] = {code = 15, codeval = 20, comm = 'Prev FX Slot', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+19] = {code = 15, codeval = 21, comm = 'Next FX Slot', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+20] = {code = 15, codeval = 22, comm = 'Keep fx type on track change', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'SK2 Data', sec = sec}
  internal_commands[idx+1] = {code = 16, codeval = 1, comm = 'Focused Track/Plugin', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+2] = {code = 16, codeval = 2, comm = 'Save Map', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+3] = {code = 16, codeval = 3, comm = 'Save Global Map', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
  internal_commands[idx+4] = {code = 16, codeval = 4, comm = 'Time/Beats Clock', mon = 1, buttype = 1, toggle = 0, preventedit = true}

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Reset Faders/Encoders', sec = sec}
  local max = 32
  for x = 1, max do
    internal_commands[idx+x] = {code = 20, codeval = x, comm = 'Reset Fader/Encoder '..string.format('%i',x), mon = 1, buttype = 1, toggle = 0, preventedit = true}
  end

  sec = sec + 1
  idx = #internal_commands+1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Write Faders', sec = sec}
  local max = 32
  for x = 1, max do
    internal_commands[idx+x] = {code = 19, codeval = x, comm = 'Write Fader '..string.format('%i',x), mon = 1, buttype = 1, toggle = 0, preventedit = true}
  end
  
  --sec = sec + 1
  
  local cnt = lvar.qfx_faders
  local max = 16
  for s = 0, (cnt/max)-1 do
    idx = #internal_commands+1
    local ii = 0
    sec=sec+1
    internal_commands[idx+ii] = {code = -1, codeval = -1, comm = 'Quick FX Assign ('..string.format('%i',s*max+1)..' - '..string.format('%i',s*max+max)..')', sec = sec}
    ii=ii+1
    for x = 1, max do
      local xx = s*max+x
      internal_commands[idx+ii] = {code = 18, codeval = s*max+x, comm = 'Quick FX Fader '..string.format('%i',xx)}
      internal_commands[idx+ii+max] = {code = 18, codeval = s*max+x+1024, comm = 'QFX F'..string.format('%i',xx)..' Learn', mon = 1, buttype = 1, toggle = 0, preventedit = true}
      internal_commands[idx+ii+max*2] = {code = 18, codeval = s*max+x+2048, comm = 'QFX F'..string.format('%i',xx)..' Clear', mon = 1, buttype = 1, toggle = 0, preventedit = true}
      internal_commands[idx+ii+max*3] = {code = 18, codeval = s*max+x+3072, comm = 'QFX F'..string.format('%i',xx)..' Mode', mon = 1, buttype = 3, toggle = 2, states = {0, 1}, preventedit = true}
      ii=ii+1
    end
  end
  
  sec = sec + 1
  local idx = #internal_commands + 1
  internal_commands[idx] = {code = -1, codeval = -1, comm = 'Quick FX Control', sec = sec}
  internal_commands[idx+1] = {code = 18, codeval = 4097, comm = 'QFX Prev Bank', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+2] = {code = 18, codeval = 4098, comm = 'QFX Next Bank', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+3] = {code = 18, codeval = 4099, comm = 'QFX Learn (last touched)', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+4] = {code = 18, codeval = 4100, comm = 'QFX Clear (last touched)', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+5] = {code = 18, codeval = 4101, comm = 'QFX Mode (last touched)', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+6] = {code = 18, codeval = 4102, comm = 'QFX Color (last touched)', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+7] = {code = 18, codeval = 4103, comm = 'QFX Set Min (last touched)', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+8] = {code = 18, codeval = 4104, comm = 'QFX Set Max (last touched)', mon = 1, buttype = 1, toggle = 0, preventedit = true}
  internal_commands[idx+9] = {code = 18, codeval = 4105, comm = 'QFX Reset Min/Max (lt)', mon = 1, buttype = 1, toggle = 0, preventedit = true}

  local update_gfx = true
  local resize_display = true
  
  local copy
  local paths = {}
  
  local obj, gui
  
  local rsz 
  local tdata = {}
  
  lvar.dev_borderctls = false
  lvar.highlight_perm = true
  
  lvar.foc_fx_trn = -99
  lvar.foc_fx_num = -1
  lvar.foc_fx_guid = ''
  
  lvar.showdevice = true
  lvar.device_img = 20
  
  tdata.trsendcnt = 8
  
  lvar.buttstates = false
  
  lvar.section1_w = 200

  tdata.ptype = 1
  tdata.pname = ''
  tdata.name = ''
  lvar.ctlname = ''
  tdata.cc = false
  tdata.ccchan = -1
  tdata.ccnum = -1
  tdata.pnum = -1
  tdata.track = -1
  tdata.trguid = ''
  tdata.trparam = -1
  tdata.trsend = -1
  tdata.troff = 0
  tdata.actionid = -1
  tdata.actionmon = 0
  tdata.buttype = 4
  tdata.butstates = 2
  tdata.code = -1
  tdata.codeval = 0
  tdata.enc_res = 128
  lvar.devbus = 0
  tdata.ledon = nil
  
  lvar.autonext = true
  lvar.listoff_host = 0
  lvar.listoff_cc = 0
  lvar.listoff_trk_prm = 0
  lvar.listoff_trk_trk = 0
  lvar.listoff_int = 0
  lvar.expandtrackoffs = false
  
  lvar.retainassignname = true
  
  lvar.selfader = ''
  lvar.bsoffs = 0
  
  local mouse = {}
  local contexts = {sbar_trk = 1,
                    sbar_trk2 = 2,
                    min = 3,
                    max = 4,
                    movesplit = 5,
                    resize_l = 6,
                    printval = 7,
                    }
  
  tdata.defcc_val = nil
  lvar.gm_ccstamp = {}
  
  lvar.gm_ccstamp.active = 399999
  lvar.gm_ccstamp.cc_active = 400000
  lvar.gm_ccstamp.cc_val = 400128
  lvar.gm_ccstamp.defcc_val = 400256
  
  lvar.gm_fb = {}
  --lvar.gm_fb.fbutstates_array = 3000000 --; //32*1024 = 32768
  lvar.gm_fb.bsarraytransfer = 3080000
  lvar.gm_fb.bsarraytransferext = 3080032
  lvar.gm_fb.bsarraytransfersscolor = 3080064
  lvar.js_avail = false  
  
  lvar.props = {}
  lvar.props.visible = 13100
  
  --------------------------------------------

  local function GetMW(v)
    local m = 1
    if v < 0 then m = -1 end
    v = math.max(math.floor(math.abs(v/120)),1)
    return v*m
  end

  function table.copy(t)
    if t == nil then return nil end
    local u = { }
    for k, v in pairs(t) do u[k] = v end
    return setmetatable(u, getmetatable(t))
  end
  
  function table.deepcopy(o, seen)
    seen = seen or {}
    if o == nil then return nil end
    if seen[o] then return seen[o] end
  
  
    local no = {}
    seen[o] = no
    setmetatable(no, table.deepcopy(getmetatable(o), seen))
  
    for k, v in next, o, nil do
      k = (type(k) == 'table') and table.deepcopy(k, seen) or k
      v = (type(v) == 'table') and table.deepcopy(v, seen) or v
      no[k] = v
    end
    return no
  end
  
  function Internal_GenIdx()
    for i = 1, #internal_commands do
      if internal_commands[i].code ~= -1 then
        internal_commands_idx[(internal_commands[i].code<<16) + internal_commands[i].codeval] = i
      end
    end
  end

  function InternalMenu()
  
    local ac = ''
    if lvar.ic_autocollapse then
      ac = '!'
    end
    local mstr = ac..'Auto Collapse'
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if res == 1 then
        lvar.ic_autocollapse = not lvar.ic_autocollapse
        IC_SecVis_Init()
        IC_SecVis_OpenSel()
        update_gfx = true
      end
    end
    
  end
  
  function IC_SecVis_Init()
  
    local cnt = 0
    for i = 1, #internal_commands do
      if internal_commands[i].code == -1 then
        cnt = cnt + 1
      end
    end
    ic_seccnt = cnt
    
    for i = 1, cnt do
      if lvar.ic_autocollapse then
        ic_secvis[i] = false
      else
        ic_secvis[i] = true
      end
    end
    
    IC_SecVis_Pop()
    
  end

  function IC_SecVis_OpenSel()

    if lvar.ic_autocollapse then
      for i = 1, ic_seccnt do
        ic_secvis[i] = false
      end
  
      local sec = 0
      for i = 1, #internal_commands do
        if internal_commands[i].code == -1 then
          sec = sec + 1
        else
          if tdata.code ~= -1 and internal_commands[i].code == tdata.code and 
             internal_commands[i].codeval == tdata.codeval then
            ic_secvis[sec] = true 
          end
        end
      end
      IC_SecVis_Pop()
    end
    
  end
  
  function IC_SecVis_Pop()
    
    local tab = {}
    local sec = 0
    for i = 1, #internal_commands do
      if internal_commands[i].code == -1 then
        sec = sec + 1
        tab[#tab+1] = internal_commands[i]
      else
        if ic_secvis[sec] == true then
          tab[#tab+1] = internal_commands[i]
        end
      end
    end
    ic_secvis_commands = tab
    
  end
  
  --------------------------------------------

  ------------------------------------------- --
  -- Pickle.lua
  -- A table serialization utility for lua
  -- Steve Dekorte, http://www.dekorte.com, Apr 2000
  -- (updated for Lua 5.3 by me)
  -- Freeware
  ----------------------------------------------

  function pickle(t)
  return Pickle:clone():pickle_(t)
  end

  Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end
  }

  function Pickle:pickle_(root)
  if type(root) ~= "table" then
  error("can only pickle tables, not ".. type(root).."s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""

  while #self._refToTable > savecount do
  savecount = savecount + 1
  local t = self._refToTable[savecount]
  s = s.."{\n"

  for i, v in pairs(t) do
  s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
  end
  s = s.."},\n"

  end
  return string.format("{%s}", s)
  end

  function Pickle:value_(v)
  local vtype = type(v)
  if vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else error("pickle a "..type(v).." is not supported")
  end
  end

  function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then
  if t == self then error("can't pickle the pickle class") end
  table.insert(self._refToTable, t)
  ref = #self._refToTable
  self._tableToRef[t] = ref
  end
  return ref
  end

  ----------------------------------------------
  -- unpickle
  ----------------------------------------------

  function unpickle(s)
  if s == nil or s == '' then return end
  if type(s) ~= "string" then
  error("can't unpickle a "..type(s)..", only strings")
  end
  local gentables = load("return "..s)
  if gentables then
    local tables = gentables()

    if tables then
      for tnum = 1, #tables do
      local t = tables[tnum]
      local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
      for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
      end
      end
      return tables[1]
    end
  else
    --error
  end
  end

  ------------------------------------------------------------
  
  function SetTrackSendTab()
  
    tab_trsnds = {}
    for s = 1, tdata.trsendcnt do
      tab_trsnds[(s-1)*3+1] = 'Send '..string.format('%i',s)..' Volume'
      tab_trsnds[(s-1)*3+2] = 'Send '..string.format('%i',s)..' Pan'
      tab_trsnds[(s-1)*3+3] = 'Send '..string.format('%i',s)..' Mute'      
    end
    
  end
  
  function MonitorSelectedData()
 
    local force
    lvar.mode = tonumber(reaper.GetExtState(SCRIPT, 'sk2mode')) or 1
    if lvar.mode ~= lvar.omode then
      lvar.omode = lvar.mode
      if lvar.mode == 3 then
        tdata.ptype = 2
        update_gfx = true
      else
        tdata.ptype = 1
        update_gfx = true         
      end
      if not lvar.gflag then
        force = true
      end
    end
    
    if tonumber(reaper.GetExtState(SCRIPT, 'readdirty')) or force then
    
      reaper.SetExtState(SCRIPT, 'UpdateFocFX', 0, false)
      lvar.buttstates = false
    
      local emptyslot = tonumber(reaper.GetExtState(SCRIPT, 'emptyslot'))
      lvar.targetmap = reaper.GetExtState(SCRIPT, 'targetmap')
      lvar.selfader = reaper.GetExtState(SCRIPT, 'selfader') or ''
      lvar.sscolormode = tonumber(reaper.GetExtState(SCRIPT, 'sscolormode'))
      lvar.layer = tonumber(reaper.GetExtState(SCRIPT, 'layer')) or 0
      lvar.device = reaper.GetExtState(SCRIPT, 'device')
      lvar.focusmode = tonumber(reaper.GetExtState(SCRIPT, 'focusmode')) or -1

      --DBG(tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_num')))
      local fxnum = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_num')) or -1
      local trn = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_trn')) or -1
      if trn == -1 or fxnum ~= -1 or lvar.focusmode ~= 3 then
        lvar.foc_fx_trn = trn
        lvar.foc_fx_num = fxnum
        lvar.foc_fx_guid = reaper.GetExtState(SCRIPT, 'foc_fx_guid') or ''
        lvar.foc_fx_itemnum = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_itemnum')) or -1
        lvar.foc_fx_itemguid = reaper.GetExtState(SCRIPT, 'foc_fx_itemguid') or ''
      else
        --if lvar.focusmode == 3 then
          local gflag = tonumber(reaper.GetExtState(SCRIPT, 'gflag'))
          if (gflag == 2 or gflag == 3) and (lvar.foc_fx_trn or -1) < 0 then

            GetFocusedFX()
            
          elseif not (gflag == 2 or gflag == 3) then
            local ffx2 = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_trn2')) or -1
            if lvar.foc_fx_trn ~= ffx2 then
              lvar.foc_fx_trn = ffx2
            end
          end
        --end
        --Write back to stored
        reaper.SetExtState(SCRIPT, 'foc_fx_trn', lvar.foc_fx_trn, false)
        reaper.SetExtState(SCRIPT, 'foc_fx_num', lvar.foc_fx_num, false)
        reaper.SetExtState(SCRIPT, 'foc_fx_guid', lvar.foc_fx_guid, false)
        reaper.SetExtState(SCRIPT, 'foc_fx_itemnum', lvar.foc_fx_itemnum or -1, false)
        reaper.SetExtState(SCRIPT, 'foc_fx_itemguid', lvar.foc_fx_itemguid or '', false)
        reaper.SetExtState(SCRIPT, 'UpdateFocFX', 1, false)
      end
      
      
      
      --DBG('xx'..lvar.foc_fx_trn..'  '..lvar.foc_fx_num..'  '..lvar.foc_fx_guid)
      lvar.sscount = tonumber(reaper.GetExtState(SCRIPT, 'sscount')) or 0
      lvar.ss_colormode = {}
      lvar.ss_info = {}

      for ss_i = 1, lvar.sscount do
        lvar.ss_colormode[ss_i] = tonumber(reaper.GetExtState(SCRIPT, 'ss_colormode_'..string.format('%i',ss_i))) or 0
        lvar.ss_info[ss_i] = {}
        lvar.ss_info[ss_i].devbus = tonumber(reaper.GetExtState(SCRIPT, 'ss_ssnumdev_'..string.format('%i',ss_i))) or -1
        lvar.ss_info[ss_i].ssnum = tonumber(reaper.GetExtState(SCRIPT, 'ss_ssnum_'..string.format('%i',ss_i))) or -1
        --DBG(ss_i..'  '..lvar.ss_info[ss_i].devbus..'  '..lvar.ss_info[ss_i].ssnum)
      end

      if emptyslot == 0 then

        lvar.gflag = tonumber(reaper.GetExtState(SCRIPT, 'gflag'))

        lvar.ctlname = reaper.GetExtState(SCRIPT, 'ctlname')
        lvar.devbus = tonumber(reaper.GetExtState(SCRIPT, 'devbus')) or 0
        lvar.lmode = tonumber(reaper.GetExtState(SCRIPT, 'lmode')) or -1
        
        local tdata_sk2 = reaper.GetExtState(SCRIPT, 'tmpdata_sk2')
        tdata = unpickle(tdata_sk2)

        tdata.pnum = tonumber(tdata.pnum)
        
        --tdata.ptype = tonumber(reaper.GetExtState(SCRIPT, 'ptype')) or 1
        --tdata.pname = reaper.GetExtState(SCRIPT, 'pname') or ''
        lvar.assigned = tdata.pname
        --[[tdata.name = reaper.GetExtState(SCRIPT, 'name')
        tdata.cc = tobool(reaper.GetExtState(SCRIPT, 'cc')) or false
        tdata.cc14bit = tonumber(reaper.GetExtState(SCRIPT, 'cc14bit')) or 0
        tdata.ccchan = tonumber(reaper.GetExtState(SCRIPT, 'ccchan')) or -1
        tdata.ccnum = tonumber(reaper.GetExtState(SCRIPT, 'ccnum')) or -1
        tdata.pnum = tonumber(reaper.GetExtState(SCRIPT, 'pnum')) or -1
        tdata.track = tonumber(reaper.GetExtState(SCRIPT, 'track')) or -1
        tdata.trguid = reaper.GetExtState(SCRIPT, 'trguid') or ''
        tdata.trparam = tonumber(reaper.GetExtState(SCRIPT, 'trparam'))
        tdata.trsend = tonumber(reaper.GetExtState(SCRIPT, 'trsend'))
        tdata.troff = tonumber(reaper.GetExtState(SCRIPT, 'troff')) or -1
        tdata.actionid = reaper.GetExtState(SCRIPT, 'actionid') or -1
        tdata.actionmon = tonumber(reaper.GetExtState(SCRIPT, 'actionmon')) or 0
        tdata.buttype = tonumber(reaper.GetExtState(SCRIPT, 'buttype')) or 4
        tdata.butstates = tonumber(reaper.GetExtState(SCRIPT, 'butstates')) or 2
        tdata.code = tonumber(reaper.GetExtState(SCRIPT, 'code')) or -1
        tdata.codeval = tonumber(reaper.GetExtState(SCRIPT, 'codeval')) or 0
        tdata.enc_res = tonumber(reaper.GetExtState(SCRIPT, 'enc_res')) or 128
        tdata.defcc_val = tonumber(reaper.GetExtState(SCRIPT, 'defcc_val'))
        tdata.sscolor = tonumber(reaper.GetExtState(SCRIPT, 'sscolor')) or 0
        tdata.ledon = tonumber(reaper.GetExtState(SCRIPT, 'ledon'))
        tdata.exauto = tonumber(reaper.GetExtState(SCRIPT, 'exauto')) or 0

        tdata.polarity = tonumber(reaper.GetExtState(SCRIPT, 'polarity')) or 0
        tdata.ss_override = tonumber(reaper.GetExtState(SCRIPT, 'ss_override'))
        tdata.ss_override_sscolor = tonumber(reaper.GetExtState(SCRIPT, 'ss_override_sscolor'))
        tdata.ss_override_name = tonumber(reaper.GetExtState(SCRIPT, 'ss_override_name'))
        tdata.valtime = tonumber(reaper.GetExtState(SCRIPT, 'valtime')) or -1
        
        tdata.linkA = zn(reaper.GetExtState(SCRIPT, 'linkA'))
        tdata.linkA_linkonly = zn(reaper.GetExtState(SCRIPT, 'linkA_linkonly'))
        tdata.linkonly = false]]
        if tdata.linkA then
          tdata.linkA_linkonly = nil
        elseif tdata.linkA_linkonly then
          tdata.linkonly = true
        end
        --tdata.linkB = zn(reaper.GetExtState(SCRIPT, 'linkB'))
        --tdata.linkA_mode = tonumber(reaper.GetExtState(SCRIPT, 'linkA_mode')) or 1
        --tdata.linkB_mode = tonumber(reaper.GetExtState(SCRIPT, 'linkB_mode')) or 1
        
        --[[tdata.butstates_array = {}
        tdata.butstates_array_ext = {}
        tdata.butstates_array_sscolor = {}
        tdata.butstates_array_name = {}]]

        --[[if lvar.lmode == 4 then
          GetButtStates()
        end]]

        --if tdata.actionmon == -1 then tdata.actionmon = 0 end

        if tdata.ptype == ptype.cc and tdata.ccchan ~= -1 and tdata.ccnum ~= -1 then
          lvar.assigned = 'Chan '..string.format('%i',tdata.ccchan+1)..' CC '..string.format('%i',tdata.ccnum)
        end

        if tdata.ptype == ptype.track and tdata.track == -2 then
          lvar.expandtrackoffs = true
        else
          lvar.expandtrackoffs = false        
        end
        
        if tdata.ptype == ptype.internal then
          IC_SecVis_OpenSel()
        end
        
      else

        local selectfadermode = tonumber(nz(reaper.GetExtState(SKSCRIPT, 'selectfadermode'), 0))
        if not lvar.gflag or selectfadermode == 1 then
          lvar.gflag = tonumber(reaper.GetExtState(SCRIPT, 'gflag'))        
        end

        lvar.ctlname = reaper.GetExtState(SCRIPT, 'ctlname')
        lvar.devbus = tonumber(reaper.GetExtState(SCRIPT, 'devbus')) or 0
        lvar.lmode = tonumber(reaper.GetExtState(SCRIPT, 'lmode')) or -1
        
        tdata.pname = ''
        lvar.assigned = ''
        tdata.name = ''
        tdata.ccchan = -1
        tdata.ccnum = -1
        tdata.track = -2
        tdata.trguid = ''
        tdata.trparam = -1
        tdata.trsend = -1
        tdata.troff = -1
        tdata.actionid = -1
        tdata.code = -1
        tdata.codeval = 0
        tdata.pnum = -1
        
        tdata.but_onval_override = -1
        tdata.defcc_val = nil
        tdata.printval = nil
        tdata.printvaldv = nil
        tdata.exauto = 0
        
        tdata.linkonly = false
        tdata.linkA = nil
        tdata.linkA_linkonly = nil
        tdata.linkB = nil
        tdata.linkA_mode = 1
        tdata.linkB_mode = 1
        
        
        tdata.polarity = 0
        tdata.ss_override = nil
        tdata.ss_override_sscolor = nil
        tdata.ss_override_name = nil
        tdata.valtime = -1
        
        --tdata.ledon = nil
        
        --tdata.sscolor = 7
        if tdata.actionmon == -1 then tdata.actionmon = 0 end
        tdata.sscolor = tdata.sscolor or 0
        
        tdata.butstates_array = {}
        tdata.butstates_array_ext = {}
        tdata.butstates_array_sscolor = {}
        tdata.butstates_array_name = {}
        if lvar.lmode == 4 then
          CalcButtStates()
        end
        --lvar.expandtrackoffs = false
      end
      
      if lvar.gflag == 4 and lvar.layer == 0 then
        lvar.gflag = 1
      end
      reaper.DeleteExtState(SCRIPT, 'readdirty', false)
      update_gfx = true
      
      if lvar.device then
        LoadDeviceData(lvar.device)
        ReadDeviceData()
      end
      
      lvar.tdata_copy = table.deepcopy(tdata)
      lvar.apply_dirty = false
      
      CreateHostFilter()
    end
  
    --DBG(lvar.gflag)
  end

  function CompareData()
    --local t = reaper.time_precise()
    
    local tdata_copy = lvar.tdata_copy
    if tdata and tdata_copy then
      for a,b in pairs(tdata) do
        if type(tdata[a]) == "table" then
          for aa,bb in pairs(b) do
            if type(tdata[a][aa]) == "table" then
              --[[for aaa,bbb in pairs(bb) do
                DBG(aaa)
                if type(tdata[a][aa][aaa]) == "table" then
                else
                  if not tdata_copy[a][aa] or tdata_copy[a][aa][aaa] ~= bb then
                    return false
                  end
                end
              end    ]]        
            else
              if tdata_copy[a][aa] ~= bb then
                return false
              end
            end
          end            
        else
          if tdata_copy[a] ~= b then
            --lvar.tdata_copy = table.deepcopy(tdata)
            return false
          end
        end
      end
    end
    
    --DBG(reaper.time_precise()-t)
    return true
  end

  function ReadDeviceData()
    
    local data = lvar.devdata
    local sdata = lvar.sharedata or {}
    if data then
      for a, b in pairs(data) do
        local ptype = tonumber(reaper.GetExtState(SCRIPTDATA,a..'_col'))
        local perm = tobool(reaper.GetExtState(SCRIPTDATA,a..'_perm'))
        
        data[a].perm = perm
        --[[if perm then
          DBG(a)
        end]]
        if ptype and ptype_info[ptype] then
          data[a].bcol = ptype_info[ptype].col
        else
          data[a].bcol = '0 0 0'
          --sdata[a].fader = -1
          --sdata[a].name = tonumber(reaper.GetExtState(SCRIPTDATA,a..'_fader'))
          --sdata[a].lmode = tonumber(reaper.GetExtState(SCRIPTDATA,a..'_lmode'))
        end
      end
    end
    
    local alldevctl_names = {}
    local cnt = tonumber(reaper.GetExtState(SCRIPTDATA,'alldevctl_cnt')) or 0
    if cnt > 0 then
      for i = 1, cnt do
        local a = reaper.GetExtState(SCRIPTDATA,'alldevctl_'..string.format('%i', i))
        sdata[a] = {}
        sdata[a].idx = a
        sdata[a].fader = tonumber(reaper.GetExtState(SCRIPTDATA,a..'_fader'))
        sdata[a].name = reaper.GetExtState(SCRIPTDATA,a..'_name')
        sdata[a].lmode = tonumber(reaper.GetExtState(SCRIPTDATA,a..'_lmode'))
      end
    end
    
    
  end

  function LoadDeviceData(dev)

    if dev ~= lvar.loadeddev then
      --local t = reaper.time_precise()
      lvar.devicetype = nil
      lvar.loadeddev = dev
      local fn = paths.ctemplate_path..dev..'/device_img.png'
      if reaper.file_exists(fn) then
        lvar.device_img = gfx.loadimg(lvar.device_img, fn)
        if lvar.device_img == -1 then
          lvar.showdevice = nil
        else
          
          local fn = paths.ctemplate_path..dev..'/device_data.txt'
          data = {}
          
          for line in io.lines(fn) do
            local idx, val = string.match(line,'%<(.-)%>(.*)') --decipher(line)
            if idx then
              data[idx] = val
            else
              local idx, val = string.match(line,'%[(.-)%](.*)')
              if idx == 'TYPE' then
                lvar.devicetype = tonumber(val)
              end
            end
          end

          lvar.devdata = {}
          lvar.sharedata = {}
          for a, bb in pairs(data) do
            local l,r,t,b,bcol = string.match(bb, '.-(%d+).-(%d+).-(%d+).-(%d+).-%[(.-)%].*')
            local cl, cr, ct, cb, shape
            shape, cl, cr, ct, cb = string.match(bb, '.-%[.-%].-(%d+).-(%-?%d+).-(%-?%d+).-(%-?%d+).-(%-?%d+)')
            if not shape then
              shape = string.match(bb, '.-%[.-%].-(%d+)')
            end
            if not shape then shape = 0 end
            shortname = string.match(bb, '.-%"(.-)%"')
            if shortname == '' then
              shortname = nil
            end
            --local shape = string.match(bb, '.-%[.-%].-(%d+)')
            if bcol == '-' then
              bcol = nil
            end
            lvar.devdata[a] = {l = tonumber(l), r = tonumber(r), t = tonumber(t), b = tonumber(b), bcol = bcol, shape = tonumber(shape),
                               crop_l = tonumber(cl), crop_r = tonumber(cr), crop_t = tonumber(ct), crop_b = tonumber(cb), shortname = shortname}
          end
        
          --draworder
          local dorder = {}
          
          for a, bb in pairs(lvar.devdata) do
            local v
            if bb.shape == 0 then
              v = (bb.r-bb.l)*(bb.b-bb.t)
            elseif bb.shape == 1 then
              v = (3.14*bb.r*bb.r)
            end
            dorder[#dorder+1] = {name = a, vol = v}
          end
          --DBG(reaper.time_precise()-t)
          --local t = reaper.time_precise()
          --lvar.devdata_do = table_slowsort_gen(dorder, 'vol')
          lvar.devdata_do = table_sort(dorder, 'vol')
          --DBG(reaper.time_precise()-t)
          --DBG(reaper.time_precise()-t)
          lvar.showdevice = true
        end
      else
        lvar.showdevice = nil    
      end
      
      obj = GetObjects()
    end
    
  end
  
  function table_sort(tab, key)
    if tab then
      table.sort(tab, function(a,b) return a[key] < b[key] end)
      return tab
    end
  end
  
  function table_slowsort_gen(tbl,idxfield)
  
     local dtbl = {}
     local rtbl
     local cnt = #tbl
     if cnt > 0 then
       for st = 1, cnt do
         if st == 1 then
           --insert
           table.insert(dtbl, tbl[st])
         else
           local inserted = false
           local dcnt = #dtbl
           for dt = 1, dcnt do
             if dtbl[dt][idxfield] then
               if tbl[st] and dtbl[dt] and nz(tonumber(tbl[st][idxfield]),0) > nz(tonumber(dtbl[dt][idxfield]),0) then
                 table.insert(dtbl, dt, tbl[st])
                 inserted = true
                 break
               end
             else
               break
             end
           end
           if inserted == false then
             table.insert(dtbl, tbl[st])
           end
         end
       end
       rtbl = {}
       for dt = #dtbl, 1, -1 do
         rtbl[#dtbl-(dt-1)] = dtbl[dt]
       end
     end
     return rtbl
  end

  --[[function GetButtStates()
    local gmem = reaper.gmem_read
    if tdata.buttype == 4 or tdata.buttype == 6 then
      for i = 1, tdata.butstates do
        tdata.butstates_array[i] = gmem(lvar.gm_fb.bsarraytransfer+(i-1))  
        tdata.butstates_array_ext[i] = gmem(lvar.gm_fb.bsarraytransferext+(i-1))
        local v = gmem(lvar.gm_fb.bsarraytransfersscolor+(i-1))
        if v ~= -1 then
          tdata.butstates_array_sscolor[i] = v
        end
        local key = 'ssvname_'..string.format('%i',i)
        tdata.butstates_array_name[i] = reaper.GetExtState(SCRIPT, key) or ''
      end
      if tdata.butstates_array[1] == -1 then
        local ccmult = 1
        if tdata.ptype == ptype.cc then
          if tdata.cc14bit == 1 then
            ccmult = 16383
          else
            ccmult = 127
          end
        end
        
        for i = 1, tdata.butstates do
          tdata.butstates_array[i] = (1/(tdata.butstates-1))*(i-1)*ccmult
          tdata.butstates_array_ext[i] = 0
          if tdata.ptype == ptype.cc then
            tdata.butstates_array[i] = math.floor(tdata.butstates_array[i])
          end
        end            
      end
    else
      tdata.butstates = 1
      tdata.butstates_array[1] = gmem(lvar.gm_fb.bsarraytransfer)
      tdata.butstates_array_ext[1] = gmem(lvar.gm_fb.bsarraytransferext)
      if tdata.butstates_array[1] == -1 then
        local ccmult = 1
        if tdata.ptype == ptype.cc then
          if tdata.cc14bit == 1 then
            ccmult = 16383
          else
            ccmult = 127
          end
        end
        tdata.butstates_array[1] = 1*ccmult
        tdata.butstates_array_ext[1] = 0
      end
    end
  end]]

  function CalcButtStates()

    local gmem = reaper.gmem_read
    if tdata.buttype == 4 or tdata.buttype == 6 then
      local ccmult = 1
      if tdata.ptype == ptype.cc then
        if tdata.cc14bit == 1 then
          ccmult = 16383
        else
          ccmult = 127
        end
      end
      tdata.butstates = F_limit(tdata.butstates, 2, 32)
      if tdata.buttype == 6 then
        tdata.butstates = 2
      end
      for i = 1, tdata.butstates do
        if tdata.ptype == ptype.internal and tdata.code == 5 then
          tdata.butstates_array[i] = 1
        else
          tdata.butstates_array[i] = (1/(tdata.butstates-1))*(i-1)*ccmult
        end
        tdata.butstates_array_ext[i] = 0
        if tdata.ptype == ptype.cc then
          tdata.butstates_array[i] = math.floor(tdata.butstates_array[i])
        end
      end            
    else
      tdata.butstates = 1
      
      local ccmult = 1
      local dval = 0
      if tdata.ptype == ptype.cc then
        if tdata.cc14bit == 1 then
          ccmult = 16383
        else
          ccmult = 127
        end
      elseif tdata.ptype == ptype.internal and tdata.code == 5 then
        dval = 1
      end
      tdata.butstates_array[1] = dval*ccmult
      tdata.butstates_array_ext[1] = 0
    end
  end

  function CalcButtStates2()

    local gmem = reaper.gmem_read
    if tdata.buttype == 4 or tdata.buttype == 6 then
    
      local ccmult = 1
      if tdata.ptype == ptype.cc then
        if tdata.cc14bit == 1 then
          ccmult = 16383
        else
          ccmult = 127
        end
      end
      tdata.butstates = F_limit(tdata.butstates, 2, 32)
      if tdata.buttype == 6 then
        tdata.butstates = 2
      end
      local dval = 0
      if tdata.ptype == ptype.internal and tdata.code == 5 then
        dval = 1
      end
      for i = 1, tdata.butstates do
        if (tdata.butstates_array[i] or -1) == -1 then
          tdata.butstates_array[i] = dval*ccmult
          tdata.butstates_array_ext[i] = 0
          if tdata.ptype == ptype.cc then
            tdata.butstates_array[i] = math.floor(tdata.butstates_array[i])
          end
        end
      end            
    else
      local ccmult = 1
      if tdata.ptype == ptype.cc then
        if tdata.cc14bit == 1 then
          ccmult = 16383
        else
          ccmult = 127
        end
      end
      tdata.butstates = 1
      
      if (tdata.butstates_array[1] or -1) == -1 then
        local dval = 0
        if tdata.ptype == ptype.internal and tdata.code == 5 then
          dval = 1
        end
        tdata.butstates_array[1] = dval*ccmult
        tdata.butstates_array_ext[1] = 0
        if tdata.ptype == ptype.cc then
          tdata.butstates_array[1] = math.floor(tdata.butstates_array[1])
        end
      end
    end
  end

  function LoadCopy()

    if tonumber(reaper.GetExtState(SCRIPT, 'copystate')) == 1 then
      --DBG('Loading Copy Data')
      --[[copy = {}
      copy.ptype = tonumber(reaper.GetExtState(SCRIPT, 'copy_ptype')) or 1
      copy.pname = reaper.GetExtState(SCRIPT, 'copy_pname') or ''
      --copy.assigned = tdata.pname
      copy.name = reaper.GetExtState(SCRIPT, 'copy_name')
      copy.cc = tobool(reaper.GetExtState(SCRIPT, 'copy_cc')) or false
      copy.cc14bit = tonumber(reaper.GetExtState(SCRIPT, 'copy_cc14bit')) or 0
      copy.ccchan = tonumber(reaper.GetExtState(SCRIPT, 'copy_ccchan')) or -1
      copy.ccnum = tonumber(reaper.GetExtState(SCRIPT, 'copy_ccnum')) or -1
      copy.pnum = tonumber(reaper.GetExtState(SCRIPT, 'copy_pnum')) or -1
      copy.track = tonumber(reaper.GetExtState(SCRIPT, 'copy_track')) or -1
      copy.trguid = reaper.GetExtState(SCRIPT, 'copy_trguid') or ''
      copy.trparam = tonumber(reaper.GetExtState(SCRIPT, 'copy_trparam'))
      copy.trsend = tonumber(reaper.GetExtState(SCRIPT, 'copy_trsend'))
      copy.troff = tonumber(reaper.GetExtState(SCRIPT, 'copy_troff')) or -1
      copy.actionid = reaper.GetExtState(SCRIPT, 'copy_actionid') or -1
      copy.actionmon = tonumber(reaper.GetExtState(SCRIPT, 'copy_actionmon')) or 0
      copy.buttype = tonumber(reaper.GetExtState(SCRIPT, 'copy_buttype')) or 4
      copy.butstates = tonumber(reaper.GetExtState(SCRIPT, 'copy_butstates')) or 2
      copy.code = tonumber(reaper.GetExtState(SCRIPT, 'copy_code')) or -1
      copy.codeval = tonumber(reaper.GetExtState(SCRIPT, 'copy_codeval')) or 0
      copy.enc_res = tonumber(reaper.GetExtState(SCRIPT, 'copy_enc_res')) or 128
      copy.defcc_val = tonumber(reaper.GetExtState(SCRIPT, 'copy_defcc_val'))
      copy.sscolor = tonumber(reaper.GetExtState(SCRIPT, 'copy_sscolor')) or 0
      copy.ledon = tonumber(reaper.GetExtState(SCRIPT, 'copy_ledon'))
      copy.exauto = tonumber(reaper.GetExtState(SCRIPT, 'copy_exauto'))
      copy.polarity = tonumber(reaper.GetExtState(SCRIPT, 'copy_polarity'))

      copy.ss_override = tonumber(reaper.GetExtState(SCRIPT, 'copy_ss_override'))
      copy.ss_override_sscolor = tonumber(reaper.GetExtState(SCRIPT, 'copy_ss_override_sscolor'))
      copy.ss_override_name = tonumber(reaper.GetExtState(SCRIPT, 'copy_ss_override_name'))
      copy.valtime = tonumber(reaper.GetExtState(SCRIPT, 'copy_valtime'))
      
      copy.linkA = zn(reaper.GetExtState(SCRIPT, 'copy_linkA'))
      copy.linkA_linkonly = zn(reaper.GetExtState(SCRIPT, 'copy_linkA_linkonly'))
      copy.linkB = zn(reaper.GetExtState(SCRIPT, 'copy_linkB'))
      copy.linkA_mode = tonumber(reaper.GetExtState(SCRIPT, 'copy_linkA'))
      copy.linkB_mode = tonumber(reaper.GetExtState(SCRIPT, 'copy_linkB_mode'))]]
      copy = reaper.GetExtState(SCRIPT, 'copy_data')
    end    

  end
  
  function StoreCopy()
  
    if copy then
    
      reaper.SetExtState(SCRIPT, 'copy_data', copy, false)
      --[[reaper.SetExtState(SCRIPT, 'copy_ptype', copy.ptype, false)
      reaper.SetExtState(SCRIPT, 'copy_pname', copy.pname, false)
      reaper.SetExtState(SCRIPT, 'copy_name', copy.name or '', false)
      reaper.SetExtState(SCRIPT, 'copy_cc', tostring(copy.cc), false)
      reaper.SetExtState(SCRIPT, 'copy_cc14bit', copy.cc14bit or 0, false)
      reaper.SetExtState(SCRIPT, 'copy_ccchan', copy.ccchan, false)
      reaper.SetExtState(SCRIPT, 'copy_ccnum', copy.ccnum, false)
      reaper.SetExtState(SCRIPT, 'copy_pnum', copy.pnum, false)
      reaper.SetExtState(SCRIPT, 'copy_track', copy.track, false)
      reaper.SetExtState(SCRIPT, 'copy_trguid', copy.trguid, false)
      reaper.SetExtState(SCRIPT, 'copy_trparam', copy.trparam, false)
      reaper.SetExtState(SCRIPT, 'copy_trsend', copy.trsend, false)
      reaper.SetExtState(SCRIPT, 'copy_troff', copy.troff, false)
      reaper.SetExtState(SCRIPT, 'copy_actionid', copy.actionid, false)
      reaper.SetExtState(SCRIPT, 'copy_actionmon', copy.actionmon, false)
      reaper.SetExtState(SCRIPT, 'copy_buttype', copy.buttype, false)
      reaper.SetExtState(SCRIPT, 'copy_butstates', copy.butstates, false)
      reaper.SetExtState(SCRIPT, 'copy_code', copy.code, false)
      reaper.SetExtState(SCRIPT, 'copy_codeval', copy.codeval, false)
      reaper.SetExtState(SCRIPT, 'copy_enc_res', copy.enc_res, false)
      reaper.SetExtState(SCRIPT, 'copy_defcc_val', copy.defcc_val or -1, false)
      if lvar.sscolormode then
        reaper.SetExtState(SCRIPT, 'copy_sscolor', copy.sscolor or 7, false)
      end
      reaper.SetExtState(SCRIPT, 'copy_ledon', copy.ledon or '', false)    
      reaper.SetExtState(SCRIPT, 'copy_exauto', copy.exauto or 0, false)    
      reaper.SetExtState(SCRIPT, 'copy_polarity', copy.polarity or 0, false)    
      reaper.SetExtState(SCRIPT, 'copy_ss_override', copy.ss_override or '', false)    
      reaper.SetExtState(SCRIPT, 'copy_ss_override_sscolor', copy.ss_override_sscolor or 0, false)    
      reaper.SetExtState(SCRIPT, 'copy_ss_override_name', copy.ss_override_name or 0, false)    
      reaper.SetExtState(SCRIPT, 'copy_valtime', copy.valtime or -1, false)

      reaper.SetExtState(SCRIPT, 'copy_linkA', copy.linkA or '', false)
      reaper.SetExtState(SCRIPT, 'copy_linkA_linkonly', copy.linkA_linkonly or '', false)
      reaper.SetExtState(SCRIPT, 'copy_linkB', copy.linkB or '', false)
      reaper.SetExtState(SCRIPT, 'copy_linkA_mode', copy.linkA_mode or 1, false)
      reaper.SetExtState(SCRIPT, 'copy_linkB_mode', copy.linkB_mode or 1, false)]]
      
      reaper.SetExtState(SCRIPT, 'copystate', 1, false)    
      
    end
  
  end

  function Copy()
    
    copy = pickle(tdata)
    --copy = {}
    
    --[[copy.ptype = tdata.ptype
    copy.pname = tdata.pname
   
    copy.name = tdata.name 
    copy.cc = tdata.cc 
    copy.ccchan = tdata.ccchan
    copy.ccnum = tdata.ccnum
    copy.pnum = tdata.pnum
    copy.track = tdata.track
    copy.trguid = tdata.trguid
    copy.trparam = tdata.trparam
    copy.trsend = tdata.trsend
    copy.troff = tdata.troff
    copy.actionid = tdata.actionid
    copy.actionmon = tdata.actionmon
    copy.buttype = tdata.buttype
    copy.butstates = tdata.butstates
    copy.code = tdata.code
    copy.codeval = tdata.codeval
    copy.enc_res = tdata.enc_res
    copy.defcc_val = tdata.defcc_val
    copy.sscolor = tdata.sscolor
    copy.cc14bit = tdata.cc14bit
    copy.ledon = tdata.ledon
    copy.exauto = tdata.exauto
    copy.polarity = tdata.polarity
    copy.valtime = tdata.valtime
    
    copy.linkA = tdata.linkA
    copy.linkA_linkonly = tdata.linkA_linkonly
    copy.linkB = tdata.linkB
    copy.linkA_mode = tdata.linkA_mode
    copy.linkB_mode = tdata.linkB_mode
    
    copy.ss_override = tdata.ss_override
    copy.ss_override_sscolor = tdata.ss_override_sscolor
    copy.ss_override_name = tdata.ss_override_name]]
    StoreCopy()
    
  end

  function Paste()
      
    if copy then
      --[[tdata.ptype = copy.ptype
      tdata.pname = copy.pname
     
      tdata.name = copy.name 
      tdata.cc = copy.cc
      tdata.ccchan = copy.ccchan
      tdata.ccnum = copy.ccnum
      tdata.pnum = copy.pnum
      tdata.track = copy.track
      tdata.trguid = copy.trguid
      tdata.trparam = copy.trparam
      tdata.trsend = copy.trsend
      tdata.troff = copy.troff
      tdata.actionid = copy.actionid
      tdata.actionmon = copy.actionmon
      tdata.buttype = copy.buttype
      tdata.butstates = copy.butstates
      tdata.code = copy.code
      tdata.codeval = copy.codeval
      tdata.enc_res = copy.enc_res
      tdata.defcc_val = copy.defcc_val
      tdata.sscolor = copy.sscolor
      tdata.cc14bit = copy.cc14bit
      tdata.ledon = copy.ledon
      tdata.exauto = copy.exauto
      tdata.polarity = copy.polarity
      tdata.valtime = copy.valtime
      
      tdata.linkA = copy.linkA
      tdata.linkA_linkonly = copy.linkA_linkonly
      tdata.linkB = copy.linkB
      tdata.linkA = copy.linkA_mode
      tdata.linkB = copy.linkB_mode]]
      
      tdata = unpickle(copy)
      
      tdata.linkonly = false
      if tdata.linkA then
        tdata.linkA_linkonly = nil
      elseif tdata.linkA_linkonly then
        tdata.linkonly = true
      end
      --tdata.ss_override = copy.ss_override
      --tdata.ss_override_sscolor = copy.ss_override_sscolor
      --tdata.ss_override_name = copy.ss_override_name
      
      if tdata.actionmon == -1 then tdata.actionmon = 0 end
      
      if tdata.ptype == ptype.cc and tdata.ccchan ~= -1 and tdata.ccnum ~= -1 then
        lvar.assigned = 'Chan '..string.format('%i',tdata.ccchan+1)..' CC '..string.format('%i',tdata.ccnum)
      end

      if tdata.ptype == ptype.track and tdata.track == -2 then
        lvar.expandtrackoffs = true
      else
        lvar.expandtrackoffs = false        
      end
      
      update_gfx = true
      
    end
    
  end

  function Apply()

    GUI_FlashButton(obj, gui, 99, 'APPLY', 0.4, c)
    
    local tdata_sk2 = pickle(tdata)
    reaper.SetExtState(SCRIPT, 'tmpdata_sk2_apply', tdata_sk2, false)
    
    --[[reaper.SetExtState(SCRIPT, 'ptype', tdata.ptype, false)
    reaper.SetExtState(SCRIPT, 'pname', tdata.pname, false)
    reaper.SetExtState(SCRIPT, 'name', tdata.name or '', false)
    reaper.SetExtState(SCRIPT, 'cc', tostring(tdata.cc), false)
    reaper.SetExtState(SCRIPT, 'cc14bit', tdata.cc14bit or 0, false)
    reaper.SetExtState(SCRIPT, 'ccchan', tdata.ccchan, false)
    reaper.SetExtState(SCRIPT, 'ccnum', tdata.ccnum, false)
    reaper.SetExtState(SCRIPT, 'pnum', tdata.pnum, false)
    reaper.SetExtState(SCRIPT, 'track', tdata.track, false)
    reaper.SetExtState(SCRIPT, 'trguid', tdata.trguid, false)
    reaper.SetExtState(SCRIPT, 'trparam', tdata.trparam, false)
    reaper.SetExtState(SCRIPT, 'trsend', tdata.trsend, false)
    
    reaper.SetExtState(SCRIPT, 'troff', tdata.troff, false)
    reaper.SetExtState(SCRIPT, 'actionid', tdata.actionid, false)
    reaper.SetExtState(SCRIPT, 'actionmon', tdata.actionmon, false)
    reaper.SetExtState(SCRIPT, 'buttype', tdata.buttype, false)
    reaper.SetExtState(SCRIPT, 'butstates', tdata.butstates, false)
    reaper.SetExtState(SCRIPT, 'code', tdata.code, false)
    reaper.SetExtState(SCRIPT, 'codeval', tdata.codeval, false)
    reaper.SetExtState(SCRIPT, 'enc_res', tdata.enc_res, false)
    reaper.SetExtState(SCRIPT, 'defcc_val', tdata.defcc_val or -1, false)
    if lvar.sscolormode or tdata.ss_override then
      reaper.SetExtState(SCRIPT, 'sscolor', tdata.sscolor or 7, false)
    end
    reaper.SetExtState(SCRIPT, 'ledon', tdata.ledon or '', false)    
    reaper.SetExtState(SCRIPT, 'exauto', tdata.exauto or 0, false)    
    reaper.SetExtState(SCRIPT, 'polarity', tdata.polarity or 0, false)    
    reaper.SetExtState(SCRIPT, 'ss_override', tdata.ss_override or '', false)    
    reaper.SetExtState(SCRIPT, 'ss_override_sscolor', tdata.ss_override_sscolor or '', false)    
    reaper.SetExtState(SCRIPT, 'ss_override_name', tdata.ss_override_name or '', false)    

    reaper.SetExtState(SCRIPT, 'valtime', tdata.valtime or -1, false)    

    reaper.SetExtState(SCRIPT, 'linkA', tdata.linkA or '', false)    
    reaper.SetExtState(SCRIPT, 'linkA_linkonly', tdata.linkA_linkonly or '', false)    
    reaper.SetExtState(SCRIPT, 'linkB', tdata.linkB or '', false)    
    reaper.SetExtState(SCRIPT, 'linkA_mode', tdata.linkA_mode or 1, false)    
    reaper.SetExtState(SCRIPT, 'linkB_mode', tdata.linkB_mode or 1, false) ]]   
    
    --reaper.SetExtState(SCRIPT, '', lvar.)

    reaper.SetExtState(SCRIPT, 'gflag', lvar.gflag, false)
    reaper.SetExtState(SCRIPT, 'writedirty', 1, false)
    reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
    
    --[[local gmem = reaper.gmem_write
    for i = 1, 32 do
      if lvar.lmode == 4 and tdata.butstates_array[i] then
        gmem(lvar.gm_fb.bsarraytransfer+(i-1), tdata.butstates_array[i])
        gmem(lvar.gm_fb.bsarraytransferext+(i-1), tdata.butstates_array_ext[i])
        gmem(lvar.gm_fb.bsarraytransfersscolor+(i-1), tdata.butstates_array_sscolor[i] or -1)
        local key = 'ssvname_'..string.format('%i',i)
        reaper.SetExtState(SCRIPT, key, tdata.butstates_array_name[i] or '', false)
      else
        gmem(lvar.gm_fb.bsarraytransfer+(i-1), -1)
        gmem(lvar.gm_fb.bsarraytransferext+(i-1), 0)
        gmem(lvar.gm_fb.bsarraytransfersscolor+(i-1), -1)
        local key = 'ssvname_'..string.format('%i',i)
        reaper.SetExtState(SCRIPT, key, '', false)
      end
    end]]
    
    lvar.apply_dirty = false
    update_gfx = true
    
    if lvar.autonext then
      lvar.nextwait = true
    end
  end

  function SelectSlotByName(name, busname)
    if name then
      reaper.SetExtState(SCRIPT, 'selectslotbyname', name, false)  
      reaper.SetExtState(SCRIPT, 'selectslotdev', lvar.devbus, false)  
      reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
    elseif busname then
      local b, n = string.match(busname,'(%d+)|(.*)')
      b = tonumber(b)
      if b then
        reaper.SetExtState(SCRIPT, 'selectslotbyname', n, false)  
        reaper.SetExtState(SCRIPT, 'selectslotdev', b, false)  
        reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
      end
    end
  end
  
  function SelectNextSlot()
    reaper.SetExtState(SCRIPT, 'selectslot', -1, false)  
    reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
  end

  function SelectPrevSlot()
    reaper.SetExtState(SCRIPT, 'selectslot', -2, false)  
    reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
  end

  function SelectNextDevice()
    local b = lvar.devbus+1
    reaper.SetExtState(SCRIPT, 'selectslotdev', b, false)  
    reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
  end

  function SelectPrevDevice()
    local b = lvar.devbus-1
    reaper.SetExtState(SCRIPT, 'selectslotdev', b, false)  
    reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
  end
  
  local function round(num, idp)
    --if tonumber(num) == nil then return num end    
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
  end
  
  function tobool(b)
  
    local ret = false
    if tostring(b) == 'true' then
      ret = true
    end
    return ret
    
  end
  
  function number_to_yn(n)
    if n == 0 then
      return 'No'
    else
      return 'Yes'
    end
  end
  
  --------------------------------------------
        
  function GetTrack(t)
  
    local tr
    if t == nil or t == 0 then
      track = reaper.GetMasterTrack(0)
    else
      track = reaper.GetTrack(0, t-1)
    end
    return track
  
  end
  
  function DBG(str)
    if str==nil then str="nil" end
    reaper.ShowConsoleMsg(tostring(str).."\n")
  end        
  ------------------------------------------------------------
  
  function GetObjects()
    local obj = {}
      
    obj.sections = {}
    
    local pw =  math.floor(gfx1.main_w/2)-10

    butt_h = lvar.butt_h
    local wmult = (butt_h-22) / (lvar.butth_limit - 22) + 1
    lvar.section1_w = math.floor(200 * wmult)
    butt_w = math.floor((lvar.section1_w-40))
    
    butt1_w = butt_w --lvar.section1_w-22
    txt_h = 16
        
    --title
    obj.sections[1] = {x = 0, y = 0, w = gfx1.main_w, h = butt_h*2}
    obj.sections[10] = {x = 80, y = 0, w = 60, h = butt_h*2}
    obj.sections[24] = {x = 210, y = 0, w = gfx1.main_w-240, h = butt_h*2}
    --< > device
    obj.sections[25] = {x = 140, y = 10, w = 30, h = butt_h*2 - 20}
    obj.sections[26] = {x = 172, y = 10, w = 30, h = butt_h*2 - 20}
    
    --glob/pglob/norm
    obj.sections[8] = {x = 20, y = obj.sections[1].y + obj.sections[1].h + 31, w = butt_w, h = butt_h*2}

    --Copy/Paste
    local yy = obj.sections[8].y + obj.sections[8].h + 8
    obj.sections[1000] = {x = 20, y = yy, w = math.floor((lvar.section1_w-42)/2), h = butt_h} 
    obj.sections[1001] = {x = 20+obj.sections[1000].w+2, y = yy, w = obj.sections[1000].w, h = butt_h}    

    --type
    obj.sections[2] = {x = 20, y = obj.sections[1000].y + obj.sections[1000].h + 8, w = butt1_w, h = butt_h}

    --name
    obj.sections[3] = {x = 20, y = obj.sections[2].y + obj.sections[2].h + 6, w = butt1_w, h = butt_h}
    --rename
    obj.sections[4] = {x = 20, y = obj.sections[3].y + obj.sections[3].h + 6, w = butt1_w, h = butt_h}

    --btn type
    obj.sections[5] = {x = 100, y = obj.sections[4].y + obj.sections[4].h + 10, w = lvar.section1_w - 112, h = butt_h}

    --but states + edit
    obj.sections[6] = {x = 100, y = obj.sections[5].y + obj.sections[5].h + 6, w = math.floor(obj.sections[5].w/2)-1, h = butt_h}
    obj.sections[13] = {x = obj.sections[6].x+obj.sections[6].w+2, y = obj.sections[6].y, w = math.floor(obj.sections[5].w/2)-1, h = butt_h}
    
    --mon
    obj.sections[7] = {x = 100, y = obj.sections[6].y + obj.sections[6].h + 6, w = lvar.section1_w - 112, h = butt_h}
    
    obj.sections[80] = {x = 100, y = obj.sections[7].y + obj.sections[7].h + 6, w = lvar.section1_w - 112, h = butt_h}

    --def cc val
    obj.sections[11] = {x = 120, y = obj.sections[80].y + obj.sections[80].h + 10, w = lvar.section1_w - 132, h = butt_h}
    --color
    local colw = 80
    obj.sections[12] = {x = 120, y = obj.sections[11].y + obj.sections[11].h + 6, w = lvar.section1_w - 132, h = butt_h*2}
    --polarity
    obj.sections[14] = {x = 120, y = obj.sections[12].y + obj.sections[12].h + 6, w = lvar.section1_w - 132, h = butt_h}

    obj.sections[15] = {x = 120, y = obj.sections[14].y + obj.sections[14].h + 6, w = lvar.section1_w - 132, h = butt_h}
    obj.sections[18] = {x = 120, y = obj.sections[15].y + obj.sections[15].h + 6, w = lvar.section1_w - 132, h = butt_h}
    obj.sections[16] = {x = 120, y = obj.sections[18].y + obj.sections[18].h + 6, w = lvar.section1_w - 132, h = butt_h}
    obj.sections[17] = {x = 120, y = obj.sections[16].y + obj.sections[16].h + 6, w = lvar.section1_w - 132, h = butt_h}

    obj.sections[19] = {x = 10, y = obj.sections[17].y + obj.sections[17].h + 6, w = lvar.section1_w - 20, h = butt_h}
    obj.sections[20] = {x = 10, y = obj.sections[19].y + obj.sections[19].h + 6, w = lvar.section1_w - 20, h = butt_h}
    obj.sections[21] = {x = 120, y = obj.sections[20].y + obj.sections[20].h + 6, w = lvar.section1_w - 132, h = butt_h}
    obj.sections[22] = {x = 120, y = obj.sections[21].y + obj.sections[21].h + 6, w = lvar.section1_w - 132, h = butt_h}
    --obj.sections[23] = {x = 120, y = obj.sections[22].y + obj.sections[22].h + 6, w = lvar.section1_w - 132, h = butt_h}

    --prev/next
    obj.sections[50] = {x = 10, y = 10, w = 30, h = butt_h*2 - 20}
    obj.sections[51] = {x = 42, y = 10, w = 30, h = butt_h*2 - 20}
    obj.sections[52] = {x = obj.sections[1].w - 72, y = 10, w = 62, h = butt_h*2 - 20}

    --Clear Layerr
    local objidx = 22
    obj.sections[9] = {x = 20, y = math.max(gfx1.main_h - butt_h*4 - 20,obj.sections[objidx].y+obj.sections[objidx].h+10), w = butt_w, h = butt_h*2}
    
    --APPLY
    obj.sections[99] = {x = 20, y = math.max(gfx1.main_h - butt_h*2 - 10,obj.sections[9].y+obj.sections[9].h+10) , w = butt1_w, h = butt_h*2}

    obj.sections[98] = {x = 0, y = 0, w = 8, h = gfx1.main_h}

    --HOST
    --SECTION 3 BOUNDARY
    if lvar.showdevice then
      local hhh = (gfx1.main_h - 8 - butt_h*2)
      if not lvar.splith then
        lvar.splith = math.floor(hhh/2)
      end
      local limit = 146
      if hhh >= 146 then
        lvar.splith = math.max(math.min(lvar.splith, hhh - limit),limit)
      else
        lvar.splith = limit
      end
      
      local hh2 = lvar.splith
      local hh = hhh - lvar.splith
      if hh < 0 then
        hh = 0
        hh2 = hhh
      end

      obj.sections[2000] = {x = lvar.section1_w+2, 
                            y = obj.sections[1].y + obj.sections[1].h + 2, 
                            w = gfx1.main_w - lvar.section1_w, 
                            h = hh}
      obj.sections[2001] = {x = lvar.section1_w+2, 
                            y = obj.sections[2000].y + obj.sections[2000].h, 
                            w = gfx1.main_w - lvar.section1_w, 
                            h = 8}
      obj.sections[100] = {x = lvar.section1_w+2, 
                           y = obj.sections[2000].y + obj.sections[2000].h + 8, 
                           w = gfx1.main_w - lvar.section1_w, 
                           h = hh2}
    else
      obj.sections[2000] = {x = lvar.section1_w+2, 
                            y = obj.sections[1].y + obj.sections[1].h + 2, 
                            w = gfx1.main_w - lvar.section1_w, 
                            h = 0}
      obj.sections[2001] = {x = -1, 
                            y = -1, 
                            w = 0, 
                            h = 0}
      obj.sections[100] = {x = lvar.section1_w+2, 
                           y = obj.sections[1].y + obj.sections[1].h + 2, 
                           w = gfx1.main_w - lvar.section1_w, 
                           h = gfx1.main_h - butt_h*2}    
    end

    --HOST
    --PLUGIN NAME
    obj.sections[101] = {x = lvar.section1_w+2 + 10, 
                         y = obj.sections[100].y + 8, --+ obj.sections[1].h + 2, 
                         w = butt_w*2, 
                         h = butt_h}
    --SHOW FOCUSED
    obj.sections[103] = {x = obj.sections[101].x+obj.sections[101].w + 10, 
                         y = obj.sections[100].y + 8, --+ obj.sections[1].h + 2, 
                         w = butt_w/2 + 40, 
                         h = butt_h}
    --FILTER
    local x = obj.sections[103].x+obj.sections[103].w + 10
    local w = math.max(gfx1.main_w - x - 20, 60)
    obj.sections[104] = {x = x, 
                         y = obj.sections[100].y + 8, --+ obj.sections[1].h + 2, 
                         w = w, 
                         h = butt_h}

    --PARAMS
    obj.sections[102] = {x = lvar.section1_w+2, 
                         y = obj.sections[100].y+(butt_h+20)-2, --+ obj.sections[1].h + 2, 
                         w = gfx1.main_w - lvar.section1_w, 
                         h = gfx1.main_h - (obj.sections[100].y+(butt_h+20)-2)}

    --CC
    --SECTION 4 BOUNDARY 1 - channel
    obj.sections[200] = {x = lvar.section1_w+2, 
                         y = obj.sections[100].y, --+ obj.sections[1].h + 2, 
                         w = gfx1.main_w - lvar.section1_w, 
                         h = butt_h+20}
    --SECTION 4 BOUNDARY 2 - cc nums
    obj.sections[201] = {x = lvar.section1_w+2, 
                         y = obj.sections[200].y + obj.sections[200].h - 2, 
                         w = gfx1.main_w - lvar.section1_w, 
                         h = gfx1.main_h - (obj.sections[200].y + obj.sections[200].h + 2)}
    --channel
    obj.sections[202] = {x = obj.sections[201].x + 10,
                         y = obj.sections[100].y + 8 --[[+ obj.sections[1].h + 10]],
                         w = butt_w,
                         h = butt_h}
    --14bit
    obj.sections[203] = {x = obj.sections[202].x + obj.sections[202].w + 10,
                         y = obj.sections[100].y + 8,
                         w = math.floor(butt_w/2),
                         h = butt_h}

    --TRACK 
    --SECTION 5 BOUNDARY 1 - title
    obj.sections[300] = {x = lvar.section1_w+2, 
                         y = obj.sections[100].y, 
                         w = gfx1.main_w - lvar.section1_w, 
                         h = butt_h+20}

    --SECTION 5 BOUNDARY 2 - params
    obj.sections[301] = {x = lvar.section1_w+2, 
                         y = obj.sections[200].y + obj.sections[200].h - 2, 
                         w = butt_w, 
                         h = gfx1.main_h - (obj.sections[200].y + obj.sections[200].h + 2)}

    --SECTION 5 BOUNDARY 3 - tracks
    obj.sections[302] = {x = obj.sections[301].x + obj.sections[301].w + 5, 
                         y = obj.sections[200].y + obj.sections[200].h - 2, 
                         w = gfx1.main_w - (obj.sections[301].x + obj.sections[301].w + 5), 
                         h = gfx1.main_h - (obj.sections[200].y + obj.sections[200].h + 2)-10}
    
    --scrollbar
    obj.sections[303] = {x = obj.sections[301].x + obj.sections[301].w + 5, 
                         y = obj.sections[302].y + obj.sections[302].h + 2, 
                         w = gfx1.main_w - (obj.sections[301].x + obj.sections[301].w + 10), 
                         h = 6}

    --SECTION 6 Open Actions List
    local hh = butt_h*3 + 30
    obj.sections[400] = {x = math.max(obj.sections[100].x + math.floor(obj.sections[100].w/2 - butt_w/2),obj.sections[100].x+10),
                         y = obj.sections[100].y + math.max(math.floor(obj.sections[100].h*(1/3) - hh/2),10),
                         w = butt_w,
                         h = butt_h}
    obj.sections[401] = {x = obj.sections[400].x,
                         y = obj.sections[400].y + obj.sections[400].h + 10,
                         w = butt_w,
                         h = butt_h*2}

    obj.sections[402] = {x = obj.sections[100].x + 10,
                         y = obj.sections[401].y + obj.sections[401].h + 10,
                         w = obj.sections[100].w - 20,
                         h = butt_h}
    
    --SECTION 6 Paste
    --SECTION 6 Command ID
    
    
    
    
    --BUTTON STATES
    obj.sections[500] = {x = lvar.section1_w+2, 
                         y = obj.sections[1].y + obj.sections[1].h + 1, 
                         w = lvar.section1_w, 
                         h = gfx1.main_h - butt_h*2 -5}
    obj.sections[501] = {x = obj.sections[500].x+2, 
                         y = obj.sections[500].y+butt_h, 
                         w = obj.sections[500].w-4, 
                         h = obj.sections[500].h-butt_h-2}
    --value
    obj.sections[504] = {x = obj.sections[500].x+obj.sections[500].w-4, 
                         y = obj.sections[500].y, 
                         w = 100, 
                         h = obj.sections[500].h}
    obj.sections[505] = {x = obj.sections[504].x, 
                         y = obj.sections[501].y, 
                         w = obj.sections[504].w-2, 
                         h = obj.sections[501].h}
    
    --extend
    obj.sections[502] = {x = obj.sections[504].x+obj.sections[504].w-4, 
                         y = obj.sections[500].y, 
                         w = 100, 
                         h = obj.sections[500].h}
    obj.sections[503] = {x = obj.sections[502].x, 
                         y = obj.sections[501].y, 
                         w = obj.sections[502].w-2, 
                         h = obj.sections[501].h}
                         
    return obj
  end
  
  -----------------------------------------------------------------------     
  function GetBtnType(v)
    for i = 1, #tab_btntype do
      if tab_btntype[i].v == v then
        return tab_btntype[i].t
      end
    end
  end
  
  function GetGUI_vars()
    gfx.mode = 0
    
    local gui = {}
      gui.aa = 1
      gui.fontname = 'Calibri'
      gui.fontsize_tab = 20    
      gui.fontsz_knob = 18
      gui.fontsz_special = 0
      
      local OS = reaper.GetOS()
      --if OS == "OSX32" or OS == "OSX64" then gui.fontsize_tab = gui.fontsize_tab - 5 end
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz_knob = gui.fontsz_knob - 5 end
      --if OS == "OSX32" or OS == "OSX64" then gui.fontsz_get = gui.fontsz_get - 5 end
      if OS == "Other" then
        gui.fontsz_knob = 14
        gui.fontsz_special = -2
      end
      
      gui.color = {['back'] = '87 109 130',
                    ['back2'] = '87 109 130',
                    ['black'] = '0 0 0',
                    ['green'] = '87 109 130',
                    ['blue'] = '87 109 130',
                    ['white'] = '205 205 205',
                    ['red'] = '255 42 0',
                    ['green_dark'] = '0 0 0',
                    ['yellow'] = '87 109 130',
                    ['pink'] = '87 109 130',
                    }
    return gui
  end  
  ------------------------------------------------------------
      
  function f_Get_SSV(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end
  
  local function f_Get_SSV_dim(s, p)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1]*p, t[2]*p, t[3]*p
  end
  
  ------------------------------------------------------------
    
  function GUI_text(gui, xywh, text, flags, col, tsz, justifyiftoobig, donotfadjust)

    if col == nil then col = gui.color.white end
    if tsz == nil then tsz = 0 end
    local fadjust = 0
    local fo = lvar.fontoffset
    if not donotfadjust then
      fadjust = lvar.fadjust
    end
    f_Get_SSV(col)  
    gfx.a = 1 
    gfx.setfont(1, gui.fontname, gui.fontsz_knob+tsz+fadjust)
    --local text_len = gfx.measurestr(text)
    gfx.x, gfx.y = xywh.x,xywh.y+fo
    local r, b
    r, b = xywh.x+xywh.w, xywh.y+xywh.h 
    local tw = gfx.measurestr(text)
    if justifyiftoobig then
      if tw < xywh.w-4 then
        gfx.drawstr(text, flags, r, b+fo)
      else
        gfx.drawstr(text, justifyiftoobig, r, b+fo)      
      end
    else
      gfx.drawstr(text, flags, r, b+fo)
    end
    return tw
  end
  
  ------------------------------------------------------------
  
  function GUI_draw(obj, gui)
    
    gfx.mode =4
    gfx.dest = 1

    if update_gfx or resize_display then    
      gfx.setimgdim(1, -1, -1)  
      gfx.setimgdim(1, gfx1.main_w,gfx1.main_h)
      
      f_Get_SSV(colours.mainbg)
      gfx.rect(0,
               0,
               gfx1.main_w,
               gfx1.main_h, 1)  
    end

    if update_gfx then    

      GUI_DrawSection1(obj, gui)
      GUI_DrawSection2(obj, gui)
      
      if tdata.ptype == ptype.host then
        GUI_DrawSection3_HOST(obj, gui)
      elseif tdata.ptype == ptype.cc then
        GUI_DrawSection4_CC(obj, gui)
      elseif tdata.ptype == ptype.track then
        GUI_DrawSection5_TRK(obj, gui)
      elseif tdata.ptype == ptype.action then
        GUI_DrawSection6_ACT(obj, gui)      
      elseif tdata.ptype == ptype.internal then
        GUI_DrawSection7_INT(obj, gui)
      end
      
      if lvar.showdevice then
        GUI_DrawDevice(obj, gui)
      end
      
      if lvar.buttstates then
        GUI_DrawButtStates(obj, gui)
      end
    end
        
    gfx.dest = -1
    gfx.a = 1
    gfx.blit(1, 1, 0, 
      0,0, gfx1.main_w,gfx1.main_h,
      0,0, gfx1.main_w,gfx1.main_h, 0,0)
    
    update_gfx = false
    resize_display = false
    
  end

  function GUI_text_fit(gui, xywh, text, flags, col, tsz, font, vertical, minsz)
  
    if col == nil then col = '205 205 205' end
    if tsz == nil then tsz = 0 end
    local fo = lvar.fontoffset
    
    f_Get_SSV(col)  
    gfx.a = 1 
    local fit = false
    
    local testw = xywh.w
    local tflags = ''
    if vertical then
      testw = xywh.h
      tflags = string.byte('z')
    end
    
    while not fit and gui.fontsz_knob+tsz+lvar.fadjust >= (minsz or 4) do
      gfx.setfont(1, font or gui.fontname, gui.fontsz_knob+tsz+lvar.fadjust)
      local tw = gfx.measurestr(text)
      if tw > testw then
        tsz = tsz - 6
        break
      else
        fit = true
      end
    end
    if fit then
      gfx.setfont(1, font or gui.fontname, gui.fontsz_knob+tsz+lvar.fadjust, tflags)
      
      gfx.x, gfx.y = xywh.x,xywh.y+fo
      local r, b
      r, b = xywh.x+xywh.w, xywh.y+xywh.h 
      
      gfx.drawstr(text, flags, r, b+fo)
    end
  end

  function GUI_DrawDevice(obj, gui)
    
    if lvar.device then
      local mh = obj.sections[2000].h - 10
      local mw = obj.sections[2000].w - 10
      
      local iw,ih = gfx.getimgdim(lvar.device_img)
      local scale = mw/iw
      if mh/ih < scale then
        scale = mh/ih
      end
      local w = math.floor(iw*scale)
      local h = math.floor(ih*scale)
      
      
      local xywh = {x = obj.sections[2000].x + math.floor((obj.sections[2000].w/2) - w/2),
                    y = obj.sections[2000].y + math.floor((obj.sections[2000].h/2) - h/2),
                    w = w,
                    h = h}
      f_Get_SSV('96 96 96')
      gfx.rect(xywh.x,xywh.y,xywh.w,xywh.h,1)
      
      if lvar.devicetype == 1 then
        gfx.blit(lvar.device_img,scale,0,0,0,iw,ih,xywh.x,xywh.y)
      end
      
      --for a,b in pairs(lvar.devdata) do
      local pad, tz = 3, -4
      local ddata = lvar.devdata[lvar.ctlname]
      for i = #lvar.devdata_do, 1, -1 do
        local b = lvar.devdata[lvar.devdata_do[i].name]
        --if b.bcol then
          if b.shape == 0 then
            local x = round(b.l*scale)
            local y = round(b.t*scale)
            local dw = round((b.r-b.l)*scale)
            local dh = round((b.b-b.t)*scale)
            
            local colt
            if b.bcol then
              f_Get_SSV(b.bcol)
              gfx.rect(xywh.x + x,xywh.y + y, dw, dh,1) 
              colt = '0 0 0'
              if b.bcol == '0 0 0' then
                colt = '128 128 128'
              end
            else
              colt = '128 128 128'
            end
            if lvar.highlight_perm and b.perm then
              f_Get_SSV(colours.permafader)
              gfx.rect(xywh.x + x -1,xywh.y + y-1, dw+2, dh+2,0) 
            end
            
            if lvar.devicetype == 1 then
              local xywh2 = {x = xywh.x + x + pad, y = xywh.y + y + pad, w = dw - pad*2, h = dh - pad*2}
              if xywh2.w >= xywh2.h then
                --horiz
                GUI_text_fit(gui,xywh2,b.shortname or lvar.devdata_do[i].name or '',5,colt,tz,nil,nil)
              else
                --vert
                GUI_text_fit(gui,xywh2,b.shortname or lvar.devdata_do[i].name or '',5,colt,tz,nil,true)
              end
            end
            
          elseif b.shape == 1 then
            local x = b.l*scale
            local y = b.t*scale
            local r = b.r*scale

            local colt
            if b.bcol then
              f_Get_SSV(b.bcol)
              gfx.circle(xywh.x + x,xywh.y + y, r, 1, 1)        
              colt = '0 0 0'
              if b.bcol == '0 0 0' then
                colt = '128 128 128'
              end
            else
              colt = '128 128 128'
            end
            if lvar.highlight_perm and b.perm then
              f_Get_SSV(colours.permafader)
              gfx.circle(xywh.x + x,xywh.y + y, r+1, 1, 1)        
            end            
            if lvar.devicetype == 1 then
              local xywh2 = {x = xywh.x + x - r + pad, y = xywh.y + y - r + pad, w = r*2-pad*2, h = r*2-pad*2}
              GUI_text_fit(gui,xywh2,b.shortname or lvar.devdata_do[i].name or '',5,colt,tz,nil,nil)
            end
          end
        --end
        if ddata and lvar.ctlname == lvar.devdata_do[i].name then
          if lvar.devicetype == 1 then
            gfx.a = 0.7
          end
          if ddata.shape == 0 then
            local x = round(ddata.l*scale)
            local y = round(ddata.t*scale)
            local dw = round((ddata.r-ddata.l)*scale)
            local dh = round((ddata.b-ddata.t)*scale)
            
            f_Get_SSV('255 255 255')
            gfx.rect(xywh.x + x,xywh.y + y, dw, dh,1)

            if lvar.devicetype == 1 then
              local xywh2 = {x = xywh.x + x + pad, y = xywh.y + y + pad, w = dw - pad*2, h = dh - pad*2}
              local colt = '0 0 0'
              if xywh2.w >= xywh2.h then
                --horiz
                GUI_text_fit(gui,xywh2,b.shortname or lvar.devdata_do[i].name or '',5,colt,tz,nil,nil)
              else
                --vert
                GUI_text_fit(gui,xywh2,b.shortname or lvar.devdata_do[i].name or '',5,colt,tz,nil,true)
              end
            end

          elseif ddata.shape == 1 then
            local x = ddata.l*scale
            local y = ddata.t*scale
            local r = ddata.r*scale
            
            f_Get_SSV('255 255 255')
            gfx.circle(xywh.x+x,xywh.y+y,r,1,1)        

            if lvar.devicetype == 1 then
              local xywh2 = {x = xywh.x + x - r + pad, y = xywh.y + y - r + pad, w = r*2-pad*2, h = r*2-pad*2}
              local colt = '0 0 0'
              GUI_text_fit(gui,xywh2,b.shortname or lvar.devdata_do[i].name or '',5,colt,tz,nil,nil)
            end
          end
          gfx.a = 1
        end
        
      end
      
--[[      local ddata = lvar.devdata[lvar.ctlname]
      if ddata then
        if ddata.shape == 0 then
          local x = ddata.l*scale
          local y = ddata.t*scale
          local dw = (ddata.r-ddata.l)*scale
          local dh = (ddata.b-ddata.t)*scale
          
          f_Get_SSV('255 255 255')
          gfx.rect(xywh.x + x,xywh.y + y, dw, dh,1)
        elseif ddata.shape == 1 then
          local x = ddata.l*scale
          local y = ddata.t*scale
          local r = ddata.r*scale
          
          f_Get_SSV('255 255 255')
          gfx.circle(xywh.x+x,xywh.y+y,r,1,1)        
        end
      end]]
      
      if lvar.devicetype ~= 1 then
        gfx.blit(lvar.device_img,scale,0,0,0,iw,ih,xywh.x,xywh.y)
      end
      
      if lvar.dev_borderctls or lvar.devicetype == 1 then
        --local col = lvar.dev_borderctls_col or '128 128 128'
        gfx.a = 1
        for i = #lvar.devdata_do, 1, -1 do
          local b = lvar.devdata[lvar.devdata_do[i].name]
          local col
          if lvar.devicetype == 1 or b.bcol == nil or b.bcol == '0 0 0' then
            col = lvar.dev_borderctls_col or '128 128 128'
          else
            col = b.bcol --or lvar.dev_borderctls_col or '128 128 128'
          end
          if b.shape == 0 then
            local x = b.l*scale
            local y = b.t*scale
            local dw = (b.r-b.l)*scale
            local dh = (b.b-b.t)*scale
            
            if lvar.devicetype ~= 1 then
              x = x + (b.crop_l or 0)*scale
              y = y + (b.crop_t or 0)*scale
              dw = dw - (b.crop_l or 0)*scale + (b.crop_r or 0)*scale
              dh = dh - (b.crop_t or 0)*scale + (b.crop_b or 0)*scale
            end
            
            f_Get_SSV(col)
            gfx.rect(round(xywh.x + x),round(xywh.y + y), round(dw), round(dh),0)        
          elseif b.shape == 1 then
            local x = b.l*scale
            local y = b.t*scale
            local r = b.r*scale

            if lvar.devicetype ~= 1 then
              x = x + (b.crop_l or 0)*scale
              y = y + (b.crop_t or 0)*scale
              r = r + (b.crop_r or 0)*scale
            end
            
            f_Get_SSV(col)
            gfx.circle(round(xywh.x + x),round(xywh.y + y), round(r), 0, 1)        
          end
          if ddata and lvar.ctlname == lvar.devdata_do[i].name then
            if ddata.shape == 0 then
              local x = ddata.l*scale
              local y = ddata.t*scale
              local dw = (ddata.r-ddata.l)*scale
              local dh = (ddata.b-ddata.t)*scale

              x = x + (b.crop_l or 0)*scale
              y = y + (b.crop_t or 0)*scale
              dw = dw - (b.crop_l or 0)*scale + (b.crop_r or 0)*scale
              dh = dh - (b.crop_t or 0)*scale + (b.crop_b or 0)*scale
              
              f_Get_SSV('255 255 255')
              gfx.rect(round(xywh.x + x),round(xywh.y + y), round(dw), round(dh),0)        
            elseif ddata.shape == 1 then
              local x = ddata.l*scale
              local y = ddata.t*scale
              local r = ddata.r*scale

              x = x + (b.crop_l or 0)*scale
              y = y + (b.crop_t or 0)*scale
              r = r + (b.crop_r or 0)*scale
              
              f_Get_SSV('255 255 255')
              gfx.circle(round(xywh.x + x),round(xywh.y + y), round(r), 0, 1)        
            end
          end
          
        end        
      end
      
      local xywh = obj.sections[2001]
      f_Get_SSV('0 0 0')
      gfx.rect(xywh.x,xywh.y,xywh.w,xywh.h-4,1)
    end
    
  end
  
  function GUI_FlashButton(obj, gui, butt, txt, flashtime, col)

    gfx.dest = 1
    GUI_DrawButton(gui, obj.sections[butt], txt, col, '99 99 99', true, -1)
    gfx.dest = -1
    gfx.a = 1
    gfx.blit(1, 1, 0, 
      0,0, gfx1.main_w,gfx1.main_h,
      0,0, gfx1.main_w,gfx1.main_h, 0,0)
    refresh_gfx = reaper.time_precise() + flashtime
      
  end

  function convbs(val)
  
    if tdata.code == 5 and tdata.codeval == 6 then
      return tab_scrubnudge[val].desc
    end
    
  end

  function GUI_DrawButtStates(obj, gui)

    gfx.x = obj.sections[100].x
    gfx.y = obj.sections[100].y
    gfx.blurto(obj.sections[100].x+obj.sections[100].w,
               obj.sections[100].y+obj.sections[100].h)
    gfx.x = obj.sections[100].x
    gfx.y = obj.sections[100].y
    gfx.blurto(obj.sections[100].x+obj.sections[100].w,
               obj.sections[100].y+obj.sections[100].h)

    f_Get_SSV('0 0 0')
    gfx.a = 0.4
    gfx.rect(obj.sections[100].x,
             obj.sections[100].y,
             obj.sections[100].w,
             obj.sections[100].h, 1)  
    gfx.a = 1

    local extended = false
    if tdata.code == 5 and tdata.codeval == 6 then
      extended = true
    end

    --local sech = math.min((tdata.butstates) * butt_h, obj.sections[100].h)
    local tsech = math.min(((tdata.butstates) * butt_h)+butt_h,obj.sections[100].h)
    sech = tsech - butt_h
    
    obj.sections[500].h = tsech
    --obj.sections[500].y = obj.sections[100].y + math.floor(obj.sections[100].h/2) - math.floor(tsech/2)
    --obj.sections[501].y = obj.sections[500].y+butt_h
    
    --if tsech < gfx1.main_h - butt_h*2 -5 then
      obj.sections[500].y = math.max(obj.sections[6].y - butt_h,obj.sections[100].y+1) --+ math.floor(obj.sections[6].h/2) - math.floor(tsech/2),obj.sections[100].y+1)
      if obj.sections[500].y + obj.sections[500].h > gfx1.main_h-2 then
        obj.sections[500].y = math.max((gfx1.main_h-2)-obj.sections[500].h,obj.sections[100].y+1)
      end
      obj.sections[501].y = obj.sections[500].y+butt_h
      obj.sections[502].y = obj.sections[500].y
      obj.sections[503].y = obj.sections[500].y+butt_h
      obj.sections[504].y = obj.sections[500].y
      obj.sections[505].y = obj.sections[500].y+butt_h
      
    --end]]

    local c = colours.sectionline
    f_Get_SSV(colours.sectionline)
    gfx.rect(obj.sections[500].x,
             obj.sections[500].y,
             obj.sections[500].w,
             tsech+4, 1)
    gfx.rect(obj.sections[504].x,
             obj.sections[504].y,
             obj.sections[504].w,
             tsech+4, 1)
    if extended then
      gfx.rect(obj.sections[502].x,
               obj.sections[502].y,
               obj.sections[502].w,
               tsech+4, 1)    
    end         
      
    f_Get_SSV(colours.mainbg)
    gfx.rect(obj.sections[501].x,
             obj.sections[501].y,
             obj.sections[501].w,
             sech+2, 1)  
    gfx.rect(obj.sections[505].x,
             obj.sections[505].y,
             obj.sections[505].w,
             sech+2, 1)  
    if extended then
      gfx.rect(obj.sections[503].x,
               obj.sections[503].y,
               obj.sections[503].w,
               sech+2, 1)    
    end
             
    local xywh = {x = obj.sections[500].x+42,
                  y = obj.sections[500].y,
                  w = obj.sections[500].w-44,
                  h = butt_h}
    GUI_text(gui, xywh, 'BUTTON STATES', 5, '99 99 99', -2)

    local xywh = {x = obj.sections[504].x,
                  y = obj.sections[504].y,
                  w = obj.sections[504].w,
                  h = butt_h}
    GUI_text(gui, xywh, 'VALUE TEXT', 5, '99 99 99', -2)

    if extended then
      local xywh = {x = obj.sections[502].x,
                    y = obj.sections[502].y,
                    w = obj.sections[502].w,
                    h = butt_h}
      GUI_text(gui, xywh, 'TYPE', 5, '99 99 99', -2)
    end
    
    local bcnt = math.floor(obj.sections[501].h / butt_h)
    local xywh = {x = obj.sections[501].x+2,
                  y = obj.sections[501].y+1,
                  w = 38,
                  h = butt_h-1}
    local xywh2 = {x = obj.sections[501].x+42,
                   y = obj.sections[501].y+1,
                   w = obj.sections[501].w-44,
                   h = butt_h-1}
    local xywh3 = {x = obj.sections[505].x+2,
                   y = obj.sections[505].y+1,
                   w = obj.sections[505].w-4,
                   h = butt_h-1}

    local xywh4
    if extended then
      xywh4 = {x = obj.sections[503].x+2,
               y = obj.sections[503].y+1,
               w = obj.sections[503].w-4,
               h = butt_h-1}
    end
    
    for i = 0, bcnt do
      
      if lvar.bsoffs + (i+1) <= tdata.butstates then
      
        local cc = c
        local tc = '99 99 99'
        if tdata.ptype == ptype.host then
          cc = ptype_info[tdata.ptype].col
          tc = '0 0 0'
        end
        GUI_DrawButton(gui, xywh, string.format('%i',lvar.bsoffs+(i+1)), cc, tc, true, -1)
        if lvar.bsoffs+i >= 0 and (tdata.butstates_array_sscolor[lvar.bsoffs+i+1] or -1) ~= -1 then
          local col = tdata.butstates_array_sscolor[lvar.bsoffs+i+1]
          f_Get_SSV_dim(tab_xtouch_colors[col].c, 0.7)
          gfx.rect(xywh.x,xywh.y,xywh.w,xywh.h,0)
        elseif lvar.bsoffs+i >= 0 and tdata.sscolor then
          local col = tdata.sscolor
          f_Get_SSV_dim(tab_xtouch_colors[col].c, 0.7)
          gfx.rect(xywh.x,xywh.y,xywh.w,xywh.h,0)
          gfx.triangle(xywh.x,xywh.y,xywh.x+8,xywh.y,xywh.x,xywh.y+8,1)
        end
        if tdata.butstates_array[lvar.bsoffs+i+1] then
          local tv
          if tdata.ptype == ptype.cc then
            tv = string.format('%i',checkNAN(tdata.butstates_array[lvar.bsoffs+i+1]) or 0)
            GUI_DrawButton(gui, xywh2, tv, c, gui.color.white, true, -1)
          else
            tv = round(tdata.butstates_array[lvar.bsoffs+i+1],5)
            GUI_DrawButton(gui, xywh2, tv, c, gui.color.white, true, -1)      
            if xywh4 then
              GUI_DrawButton(gui, xywh4, convbs(tdata.butstates_array_ext[lvar.bsoffs+i+1]), c, gui.color.white, true, -1)      
            end
          end
          local c3 = gui.color.white
          local ttv = tdata.butstates_array_name[lvar.bsoffs+i+1]
          --DBG('ttv'..tostring(ttv))
          if (ttv or '') == '' then
            c3 = '64 64 64'
            ttv = tv
          end
          GUI_DrawButton(gui, xywh3, ttv, c, c3, true, -1)
        end
        xywh.y = xywh.y + butt_h
        xywh2.y = xywh2.y + butt_h
        xywh3.y = xywh3.y + butt_h
        if xywh4 then
          xywh4.y = xywh4.y + butt_h
        end
      else
        break
      end
    end
    
  end
  
  function checkNAN(v)
    if isNAN(v) then
      return nil
    else
      return v
    end
  end
  
  function isNAN(value)
    return value ~= value
  end
    
  function GUI_DrawSection1(obj, gui)

    local c = colours.sectionline
    local c2 = colours.ibox
    local c3 = colours.iboxT
    
    f_Get_SSV(c)
    gfx.rect(lvar.section1_w-2,
             obj.sections[1].y+obj.sections[1].h+1,
             2,
             gfx1.main_h, 1)  
    local dbus
    if (lvar.devbus or -1) ~= -1 then
      dbus = string.format('%i',lvar.devbus+1)
    else
      dbus = ''
    end
    
    f_Get_SSV(c2)
    gfx.rect(obj.sections[1].x, obj.sections[1].y, obj.sections[1].w, obj.sections[1].h, 1)
    local txt = lvar.assigned or ''
    if txt == '<Please select>' then
      txt = ''
    end
    GUI_text(gui, obj.sections[10], lvar.selfader, 4, c3, 8, 4)
    local xywh = {x = obj.sections[24].x, y = obj.sections[24].y, w = obj.sections[24].w, h = obj.sections[24].h}
    local woff = 0
    if (lvar.device or '') ~= '' then
      woff = GUI_text(gui, xywh, 'Device '..dbus..' : '..lvar.device, 4, gui.color.white, 4, 4)
    else
      woff = GUI_text(gui, xywh, 'No Device', 4, gui.color.white, 4, 4)
    end
    lvar.hdr_devicetxt = {x = xywh.x, y = xywh.y, w = woff, h = xywh.h}
    
    xywh.x = xywh.x + woff + 40
    xywh.w = obj.sections[24].w - woff - 60
    lvar.hdr_slottxt = {x = xywh.x, y = xywh.y, w = xywh.w, h = xywh.h}
    GUI_text(gui, xywh, lvar.ctlname..'  :  '..txt, 4, c3, 4, 4)

    GUI_DrawButton(gui, obj.sections[25], '<', c2, gui.color.white, true, 4, 5)
    GUI_DrawButton(gui, obj.sections[26], '>', c2, gui.color.white, true, 4, 5)
    
    
    --GUI_DrawButton(gui, obj.sections[10], 'DEVICE '..dbus..' - '..lvar.ctlname, c, gui.color.white, true, 4, 5)
    GUI_DrawButton(gui, obj.sections[50], '<', c2, c3, true, 4, 5)
    GUI_DrawButton(gui, obj.sections[51], '>', c2, c3, true, 4, 5)

    local tc = '60 60 60'
    if lvar.autonext then
      tc = gui.color.white
    end
    GUI_DrawButton(gui, obj.sections[52], 'AUTO', c2, tc, true, 2, 5)
    
  end

  function Internal_CanEdit()
    if tdata.ptype == ptype.internal and 
       (internal_commands[internal_commands_idx[(tdata.code<<16) + tdata.codeval]] and
        internal_commands[internal_commands_idx[(tdata.code<<16) + tdata.codeval]].preventedit == true) then
      return false
    else
      return true
    end
  end

  function GUI_DrawSection2(obj, gui)

    local c = colours.buttcol
    local gmem = reaper.gmem_read

    f_Get_SSV(colours.sectionline)
    gfx.rect(0,
             obj.sections[1].y + obj.sections[1].h + 1,
             lvar.section1_w-2,
             butt_h, 1)
    
    --[[gfx.rect(0,
             obj.sections[1000].y,
             lvar.section1_w-2,
             butt_h, 1)]]
    

    local txt = ''
    if lvar.gflag == 3 then
      txt = 'PERMANENT MAP'
      bc = colours.permafader
      tc = colours.permafader_txt
    elseif lvar.gflag == 2 then
      txt = 'GLOBAL MAP'
      bc = colours.globalfader
      tc = colours.globalfader_txt
    elseif lvar.gflag == 1 then
      if lvar.mode == 3 then
        txt = 'TRACK MAP'
      else
        txt = 'PLUGIN MAP'
      end
      bc = colours.mainfader
      tc = colours.mainfader_txt
      --bc = c
      --tc = gui.color.white
    elseif lvar.gflag == 4 then
      if lvar.mode == 3 then
        txt = 'TRACK MAP LAYER '..string.format('%i',lvar.layer)
      else
        txt = 'PLUGIN MAP LAYER '..string.format('%i',lvar.layer)
      end
      bc = colours.layerfader
      tc = colours.layerfader_txt
    end
    GUI_DrawButton(gui, obj.sections[8], '', bc, tc, true, 2, 5)
    local xywh = {x = obj.sections[8].x+2, y = obj.sections[8].y, w = obj.sections[8].w-4, h = butt_h} 
    GUI_text(gui, xywh, txt, 5, tc, 2+gui.fontsz_special)
    xywh.y = obj.sections[8].y+butt_h
    GUI_text(gui, xywh, lvar.targetmap or '', 5, tc, -2, 4)
    
    local xywh = {x = obj.sections[8].x, y = obj.sections[1].y + obj.sections[1].h+1, w = obj.sections[8].w, h = butt_h} 
    GUI_text(gui, xywh, 'EDIT LAYER', 5, '99 99 99', -2)

    GUI_DrawButton(gui, obj.sections[1000], 'COPY', c, gui.color.white, true, -2, 5)
    GUI_DrawButton(gui, obj.sections[1001], 'PASTE', c, gui.color.white, true, -2, 5)

    GUI_DrawButton(gui, obj.sections[9], 'CLEAR ASSIGNMENT', c, gui.color.white, true, -2, 5)
  
    GUI_DrawButton(gui, obj.sections[2], ptype_txt2[tdata.ptype], ptype_info[tdata.ptype].col, ptype_info[tdata.ptype].btntxt, true, 0, 5)
    xywh.y = obj.sections[2].y - 36
    
    
    --GUI_text(gui, obj.sections[1000], 'CONTROL PROPERTIES', 5, '99 99 99', -2)
    
    local txt = tdata.pname
    if tdata.ptype == ptype.cc then
      if tdata.ccchan ~= -1 and tdata.ccnum ~= -1 then
        txt = 'Chan '..string.format('%i',tdata.ccchan+1)..' CC '..string.format('%i',tdata.ccnum)      
      end
    end
    tc = gui.color.white
    if tdata.pname == '<Please select>' or (tdata.pname or '') == '' then
      txt = '< Unassigned >'
      tc = '99 99 99'
    end
    GUI_DrawButton(gui, obj.sections[3], txt, c, tc, true, -2, 5, nil, 6, 4)
    local txt, tc
    if (tdata.name or '') ~= '' then
      txt = tdata.name
      tc = gui.color.white
    else
      txt = '< RENAME >'
      tc = '99 99 99'
    end
    GUI_DrawButton(gui, obj.sections[4], txt, c, tc, true, -2, 5, nil, 6, 4)
    
    --button section
    if lvar.lmode == 4 then
      GUI_DrawButton(gui, obj.sections[5], (GetBtnType(tdata.buttype) or ''), c, gui.color.white, true, -2, 5, 'BUTTON TYPE')
      
      local tc = gui.color.white
      if Internal_CanEdit() == false then
        tc = '64 64 64'
      end
      GUI_DrawButton(gui, obj.sections[6], tdata.butstates, c, tc, true, -2, 5, 'BUTTON STATES')
      
      local bc, tc = c, gui.color.white
      if lvar.buttstates then
        bc = gui.color.white
        tc = c
      end      
      if Internal_CanEdit() == false then
        tc = '64 64 64'
      end
      GUI_DrawButton(gui, obj.sections[13], 'EDIT', bc, tc, true, -4, 5)
      
      if tdata.ledon then
        GUI_DrawButton(gui, obj.sections[7], 'LED ON', c, gui.color.white, true, -2, 5, 'MONITOR VAL')      
      else
        GUI_DrawButton(gui, obj.sections[7], number_to_yn(tdata.actionmon), c, gui.color.white, true, -2, 5, 'MONITOR VAL')
      end
      
      local onval = tdata.but_onval_override or -1
      if onval == -1 then
        onval = 'Device Default'
      end
      GUI_DrawButton(gui, obj.sections[80], onval, c, gui.color.white, true, -2, 5, "FB 'ON' VALUE")      
      
    elseif lvar.lmode == 3 or lvar.lmode == 2 or lvar.lmode == 6 or lvar.lmode == 7 then
      GUI_DrawButton(gui, obj.sections[5], string.format('%i',(tdata.enc_res or 512)), c, gui.color.white, true, -2, 5, 'ENCODER RES')    
    end
    if lvar.lmode == 0 or lvar.lmode == 2 or lvar.lmode == 3 or lvar.lmode == 6 or lvar.lmode == 7 then
      if tdata.ptype == ptype.host or tdata.ptype == ptype.track or tdata.ptype == ptype.cc then
        if tdata.exauto == 1 then
          txt = 'X'
        else
          txt = ''
        end
        local txtd
        if tdata.ptype == ptype.cc then
          txtd = 'EXCLUDE LANES'
        else
          txtd = 'EXCLUDE ENV'
        end
        GUI_DrawButton(gui, obj.sections[6], txt, c, gui.color.white, true, -2+gui.fontsz_special, 5, txtd)      
      end
    end
        
    if tdata.ptype == ptype.cc then
      local txt = 'Off'
      local bc, tc = c, gui.color.white
      local gmdefcc = gmem(lvar.gm_ccstamp.defcc_val+tdata.ccnum)
      if tdata.defcc_val and tdata.defcc_val ~= -1 then
        txt = string.format('%i',tdata.defcc_val)
        bc = ptype_info[tdata.ptype].col
        tc = ptype_info[tdata.ptype].btntxt
      --[[elseif tdata.ccnum and gmdefcc and gmdefcc ~= -1 then
        txt = string.format('%i',gmdefcc)
        bc = ptype_info[tdata.ptype].col
        tc = ptype_info[tdata.ptype].btntxt]]
      end
      GUI_DrawButton(gui, obj.sections[11], txt, bc, tc, true, -2, 5, 'PRINT VALUE')
    elseif tdata.ptype == ptype.host then
      local txt = 'Off'
      local bc, tc = c, gui.color.white
      if tdata.printval and tdata.printval ~= -1 then
        PV_GetDV()
        txt = tdata.printvaldv
        bc = ptype_info[tdata.ptype].col
        tc = ptype_info[tdata.ptype].btntxt
      end
      GUI_DrawButton(gui, obj.sections[11], txt, bc, tc, true, -2, 5, 'PRINT VALUE')
    elseif tdata.ptype == ptype.track then
      if tab_trparams_pv[tdata.trparam] then
        local txt = 'Off'
        local bc, tc = c, gui.color.white
        if tdata.printval and tdata.printval ~= -1 then
          PV_GetDV()
          txt = tdata.printvaldv
          bc = ptype_info[tdata.ptype].col
          tc = ptype_info[tdata.ptype].btntxt
        end
        GUI_DrawButton(gui, obj.sections[11], txt, bc, tc, true, -2, 5, 'PRINT VALUE')
      end
    end
    
    --DBG(lvar.sscolormode)
    if lvar.sscolormode or tdata.ss_override then
      local p = 0.7
      local cc = tdata.sscolor or 7
      local xywh = obj.sections[12]
      
      f_Get_SSV('0 0 0')
      gfx.rect(xywh.x,
               xywh.y,
               xywh.w,
               xywh.h, 1)      

      if cc&16 == 16 and cc&32 == 32 then
        f_Get_SSV_dim(tab_xtouch_colors[cc&7].c, p)
        gfx.rect(xywh.x+1,
                 xywh.y+1,
                 xywh.w-2,
                 xywh.h-2, 1)      
      else
        f_Get_SSV_dim(tab_xtouch_colors[cc&7].c, p)
        gfx.rect(xywh.x+1,
                 xywh.y+1,
                 xywh.w-2,
                 xywh.h-2, 0)      
        if cc&16 == 16 then
          --f_Get_SSV('0 0 0')
          gfx.rect(xywh.x+2,
                   xywh.y+2,
                   xywh.w-4,
                   math.floor(xywh.h/2)-2, 1)                
        end
        if cc&32 == 32 then
          --f_Get_SSV('0 0 0')
          gfx.rect(xywh.x+2,
                   xywh.y+math.floor(xywh.h/2),
                   xywh.w-4,
                   math.floor(xywh.h/2)-2, 1)
        end
        
      end
    
      local xywh2 = {x = 0, y = xywh.y, w = xywh.x-10, h = xywh.h}
      GUI_text(gui, xywh2, 'COLOR', 6, '99 99 99', -2)
      
    end

    local txt = 'Off'
    local bc, tc = c, gui.color.white
    if tdata.polarity == 1 then
      txt = 'On'
      bc = '128 0 0'
    end
    if (tdata.buttype == 4) and tdata.butstates > 2 then
      bc = '32 32 32'
      txt = '-'
      tc = '64 64 64'
    end
    GUI_DrawButton(gui, obj.sections[14], txt, bc, tc, true, -2, 5, 'SWITCH POLARITY')

    local txt = 'Default'
    local bc, tc = c, gui.color.white
    if tdata.ss_override then
      txt = string.format('%i',tdata.ss_override)
      --bc = gui.color.white
      --tc = gui.color.black
    end
    GUI_DrawButton(gui, obj.sections[15], txt, bc, tc, true, -2, 5, 'SCRIBBLE STRIP')
    
    if lvar.lmode ~= 4 and tdata.ptype == ptype.host then
    
      local txt = 'Off'
      local bc, tc = c, gui.color.white
      if (tdata.min or 0) > 0 then
        --[[local mindv
        if adjustmin then
          mindv = adjustmin.mindv
        end]]
        txt = tdata.mindv or round(tdata.min, 3)
        --DBG(txt)
      end
      GUI_DrawButton(gui, obj.sections[16], txt, bc, tc, true, -2, 5, 'MIN')

      local txt = 'Off'
      local bc, tc = c, gui.color.white
      if (tdata.max or 1) < 1 then
        txt = tdata.maxdv or round(tdata.max, 3)
      end
      GUI_DrawButton(gui, obj.sections[17], txt, bc, tc, true, -2, 5, 'MAX')
    
    end
    
    if lvar.lmode == 4 and (lvar.sscolormode or tdata.ss_override) then
      local txt = 'Off'
      local bc, tc = c, gui.color.white
      if tdata.ss_override_sscolor == 1 then
        txt = 'On'
      end
      GUI_DrawButton(gui, obj.sections[16], txt, bc, tc, true, -2, 5, 'KEEP COLOR')
    end

    if lvar.lmode == 4 then
      local txt = 'Off'
      local bc, tc = c, gui.color.white
      if tdata.ss_override_name == 1 then
        txt = 'On'
      end
      GUI_DrawButton(gui, obj.sections[17], txt, bc, tc, true, -2, 5, 'KEEP NAME')

      local txt 
      local bc, tc = c, gui.color.white
      if (tdata.valtime or -1) == -1 then
        txt = 'Default'
      elseif (tdata.valtime) == -2 then
        txt = 'Off'
      else
        txt = string.format('%i',tdata.valtime) .. ' s'
      end
      GUI_DrawButton(gui, obj.sections[18], txt, bc, tc, true, -2, 5, 'SS VALUE TIME')

      local txt
      local bc, tc = c, gui.color.white
      if tdata.linkB then
        txt = 'SHARED/LINKED'
        tc = '99 99 99'
      else
        if tdata.linkonly then
          txt = 'LINK TO:'
        else
          txt = 'SCRIBBLE SHARE:'
        end
      end
      GUI_DrawButton(gui, obj.sections[19], txt, bc, tc, true, -2, 5, '')

      local txt, linked
      local bc, tc = c, gui.color.white
      if tdata.linkonly then
        if (tdata.linkA_linkonly or -1) == -1 then
          if (tdata.linkB or -1) ~= -1 then
            txt = '['..tdata.linkB..']'
            tc = '99 99 99'
          else
            txt = 'Off'
          end
          linked = true
        else
          if lvar.sharedata[tdata.linkA_linkonly] then
            txt = '['..lvar.sharedata[tdata.linkA_linkonly].fader..'] '.. tdata.linkA_linkonly
          end
        end
      else
        if (tdata.linkA or -1) == -1 then
          if (tdata.linkB or -1) ~= -1 then
            txt = '[ '..tdata.linkB..' ]'
            tc = '99 99 99'
          else
            txt = 'Off'
          end
          linked = true
        else
          if lvar.sharedata[tdata.linkA] then
            txt = '['..lvar.sharedata[tdata.linkA].fader..'] '.. tdata.linkA
          end
        end
      end
      --local xywh = {x = obj.sections[19].x, y = obj.sections[19].y + 6, w = obj.sections[19].w, h = obj.sections[19].h}
      --GUI_text(gui, obj.sections[19], txt, 5, '99 99 99', -2)
      GUI_DrawButton(gui, obj.sections[20], txt, bc, tc, true, -2, 5, '')

      if not linked and not tdata.linkonly and tdata.linkB == nil then

        local bc, tc = c, gui.color.white
        local txt = lvar.linkmodes[(tdata.linkA_mode or 1)]
        GUI_DrawButton(gui, obj.sections[21], txt, bc, tc, true, -2, 5, 'LINK A MODE')
  
        local bc, tc = c, gui.color.white
        local txt = lvar.linkmodes[(tdata.linkB_mode or 1)]
        GUI_DrawButton(gui, obj.sections[22], txt, bc, tc, true, -2, 5, 'LINK B MODE')
    
      end
      
    end
    
    local bcol, tcol = ptype_info[tdata.ptype].btntxt, ptype_info[tdata.ptype].col
    if lvar.apply_dirty then
      bcol, tcol = tcol, bcol
    end
    GUI_DrawButton(gui, obj.sections[99], 'APPLY', bcol, tcol, true, 2, 5)

  end
  
  function GUI_DrawSection3_HOST(obj, gui)
    
    local c = colours.devctlassigned 
    
    --local ret, trn, _, fxn = reaper.GetFocusedFX()
    local ret = 1
    local trn = lvar.foc_fx_trn
    local fxn = lvar.foc_fx_num
    local fxguid = lvar.foc_fx_guid
    local itmnum = lvar.foc_fx_itemnum
    
    --DBG(tdata.)
    --DBG(trn)
    --DBG(lvar.focusmode)
    if ret == 1 then
    
      local tr = GetTrack(trn)
      local GetNumParams, GetParamName, GetFXName
      if itmnum and itmnum ~= -1 then
        local item = reaper.GetTrackMediaItem(tr, itmnum)
        local take = reaper.GetActiveTake(item)
        track = take
        GetFXName = reaper.TakeFX_GetFXName
        GetParamName = reaper.TakeFX_GetParamName
        GetNumParams = reaper.TakeFX_GetNumParams
      else
        track = tr
        GetFXName = reaper.TrackFX_GetFXName
        GetParamName = reaper.TrackFX_GetParamName
        GetNumParams = reaper.TrackFX_GetNumParams
      end
      if track then

        local _, fxname = GetFXName(track,fxn,'')
        local c = colours.devctlassigned
        local txtc = gui.color.white
        if fxname == '' or fxn == -1 then
          fxname = 'No plugin selected'
          txtc = '96 96 96'
        else
          if lvar.focusmode ~= 3 then
            txtc = '96 96 96'
          end
          fxname = string.format('%i',fxn+1) .. ':  '.. (fxname or '')
        end
        
        --local bc = ptype_info[tdata.ptype].col
        --local tc = ptype_info[tdata.ptype].btntxt
        GUI_DrawButton(gui, obj.sections[101], fxname, c, txtc, true, -2, 5)

        if lvar.gflag == 2 or lvar.gflag == 3 then
          GUI_DrawButton(gui, obj.sections[103], 'SHOW FOCUSED', c, gui.color.white, true, -2, 5)
        end
        --f_Get_SSV('64 64 64')
        --gfx.rect(obj.sections[103].x, obj.sections[103].y, obj.sections[103].w, obj.sections[103].h, 0)

        local tc = '64 64 64'
        local ftxt = '[Filter]'
        if lvar.hostfilter then
          tc = gui.color.white
          ftxt = lvar.hostfilter
        end
        
        GUI_DrawButton(gui, obj.sections[104], ftxt, c, tc, true, -2, 5, nil, nil, 4)
        f_Get_SSV('64 64 64')
        gfx.rect(obj.sections[104].x, obj.sections[104].y, obj.sections[104].w, obj.sections[104].h, 0)
        
        local pcnt
        if lvar.hostfilter then
          pcnt = #lvar.hostfilter_tab
        else
          pcnt = GetNumParams(track, fxn)
        end
        
        local s3 = obj.sections[102]
        
        local rows = math.floor(s3.h / butt_h)
        local cols = math.floor(s3.w / butt_w)
        
        local xywh = {x = s3.x, y = s3.y, w = butt_w-2, h = butt_h-2}
        for x = 0, cols do
          for y = 0, rows-1 do
          
            xywh.x = s3.x + butt_w*x
            xywh.y = s3.y + butt_h*y
            
            local p = y + x*rows + lvar.listoff_host
            if p < pcnt then
              local ret, pname
              if lvar.hostfilter then
                pname = lvar.hostfilter_tab[p+1].pname
              else
                ret, pname = GetParamName(track,fxn,p,'')
              end
              if (lvar.hostfilter and lvar.hostfilter_tab[p+1] and lvar.hostfilter_tab[p+1].pnum == tdata.pnum) 
                 or (not lvar.hostfilter and p == tdata.pnum) then
                bc = ptype_info[tdata.ptype].col
                tc = ptype_info[tdata.ptype].btntxt
              else
                bc = c
                tc = ptype_info[tdata.ptype].col
              end
    
              GUI_DrawButton(gui, xywh, pname, bc, tc, true, -2, 5)              
            end
          end
        end
      end
    end
  
  end

  function GUI_DrawSection4_CC(obj, gui)

    local c = colours.devctlassigned
    local txtc = gui.color.white
    
    --[[f_Get_SSV(colours.sectionline)
    gfx.rect(obj.sections[201].x,
             obj.sections[201].y-1,
             gfx1.main_w,
             2, 1)  ]]
             
    local bc, tc = c, txtc
    local txt
    if tdata.ccchan == -1 then
      tc = '99 99 99'
      txt = 'CHANNEL'
    end
    GUI_DrawButton(gui, obj.sections[202], txt or ('CHANNEL '..string.format('%i',tdata.ccchan+1)), c, tc, true, -2, 5)

    local txt
    local bc, tc = c, txtc
    if tdata.cc14bit ~= 1 then
      tc = '99 99 99'
    end
    GUI_DrawButton(gui, obj.sections[203], '14 bit', c, tc, true, -2, 5)

    local pcnt = 128
    if tdata.cc14bit == 1 then
      pcnt = 32
    end
    local s3 = obj.sections[201]
     
    local butt_w = math.floor(butt_w/2)
    
    local rows = math.floor(s3.h / butt_h)
    local cols = math.floor(s3.w / butt_w)
    
    local xywh = {x = s3.x, y = s3.y, w = butt_w-2, h = butt_h-2}
    for x = 0, cols do
      for y = 0, rows-1 do
      
        xywh.x = s3.x + butt_w*x
        xywh.y = s3.y + butt_h*y
        
        local p = y + x*rows + lvar.listoff_cc
        if p < pcnt then
          local txt = 'CC '..string.format('%i',p)
          
          if p == tdata.ccnum then
            bc = ptype_info[tdata.ptype].col
            tc = ptype_info[tdata.ptype].btntxt
          else
            bc = c
            tc = ptype_info[tdata.ptype].col
          end

          GUI_DrawButton(gui, xywh, txt, bc, tc, true, -2, 5)              
        end
      end
    end

  end

  function GUI_DrawSection5_TRK(obj, gui)

    local c = colours.devctlassigned
    local txtc = gui.color.white

    f_Get_SSV(colours.sectionline)
    gfx.rect(obj.sections[302].x-4,
             obj.sections[100].y-2,
             1,
             obj.sections[100].h, 1)

    local xywh = {x = obj.sections[300].x,
                  y = obj.sections[300].y,
                  w = obj.sections[301].w,
                  h = obj.sections[300].h}
    GUI_text(gui, xywh, 'TRACK PARAMETER', 5, gui.color.white, -2)              

    xywh.x = xywh.x+xywh.w+5
    GUI_text(gui, xywh, 'TRACK', 5, gui.color.white, -2)


    local pcnt = #tab_trparams + #tab_trsnds + 1
    local s3 = obj.sections[301]
    
    --local butt_w = math.floor(butt_w)
    
    local rows = math.floor(s3.h / butt_h)
    
    local xywh = {x = s3.x, y = s3.y, w = butt_w-2, h = butt_h-2}
    for y = 0, rows-1 do
    
      xywh.y = s3.y + butt_h*y
      
      local p = y + lvar.listoff_trk_prm +1
      if p < #tab_trparams+1 then
        local txt = tab_trparams[p]
        
        if p == tdata.trparam then
          bc = ptype_info[tdata.ptype].col
          tc = ptype_info[tdata.ptype].btntxt
        else
          bc = c
          tc = ptype_info[tdata.ptype].col
        end

        GUI_DrawButton(gui, xywh, txt, bc, tc, true, -2, 5)              
      elseif p == #tab_trparams+1 then
        txt = 'Track Sends'
        GUI_text(gui, xywh, txt, 5, gui.color.white, -2)                   
      elseif p < pcnt+1 then
        q = p - (#tab_trparams+1)
        local txt = tab_trsnds[q]
        
        if q == tdata.trsend then
          bc = ptype_info[tdata.ptype].col
          tc = ptype_info[tdata.ptype].btntxt
        else
          bc = c
          tc = ptype_info[tdata.ptype].col
        end

        GUI_DrawButton(gui, xywh, txt, bc, tc, true, -2, 5)              
      
      end
    end

    local trackcnt = reaper.CountTracks(0)
    
    local pcnt
    if lvar.expandtrackoffs then
      pcnt = 33 + trackcnt + 3
    else
      pcnt = 1 + trackcnt + 3
    end
    local s3 = obj.sections[302]
        
    local rows = math.floor(s3.h / butt_h)
    local cols = math.floor(s3.w / butt_w)
    
    local xywh = {x = s3.x, y = s3.y, w = butt_w-2, h = butt_h-2}
    for x = 0, cols do
      for y = 0, rows-1 do
      
        xywh.x = s3.x + butt_w*x
        xywh.y = s3.y + butt_h*y
        
        local p = y + x*rows + lvar.listoff_trk_trk
        if p < pcnt --[[and p ~= 1 and p ~= 34]] then
        
          local txt = ''
          local hl, mrk
          if p == 0 then
            txt = 'SELECTED'
            if tdata.track == -1 then
              hl = true
            end
          elseif p == 1 then
            txt = 'Internal Offset'
            mrk = true
          end
          
          if lvar.expandtrackoffs then
            if p > 1 and p < 34 then
              txt = 'TRACK OFFSET '..string.format('%i',p-2)
              if tdata.track == -2 and tdata.troff == p-2 then
                hl = true
              end
            elseif p == 34 then
              txt = 'Fixed Track'
              mrk = true
            else
              local tr = GetTrack(p-35)
              if tr then
                local trn = reaper.GetMediaTrackInfo_Value(tr, 'IP_TRACKNUMBER')
                local trnm = reaper.GetTrackState(tr)
                if trn == -1 then
                  txt = trnm
                else
                  txt = string.format('%i',trn) .. ': '..trnm
                end
                if tdata.track == p-35 then
                  hl = true
                end
              end
            end
          else
            if p == 2 then
              txt = 'Fixed Track'
              mrk = true
            else
              local tr = GetTrack(p-3)
              if tr then
                local trn = reaper.GetMediaTrackInfo_Value(tr, 'IP_TRACKNUMBER')
                local trnm = reaper.GetTrackState(tr)
                if trn == -1 then
                  txt = trnm
                else
                  txt = string.format('%i',trn) .. ': '..trnm
                end
                if tdata.track == p-3 then
                  hl = true
                end
              end
            end          
          end
          if not mrk then
            if hl then
              bc = ptype_info[tdata.ptype].col
              tc = ptype_info[tdata.ptype].btntxt
            else
              bc = c
              tc = ptype_info[tdata.ptype].col
            end
  
            GUI_DrawButton(gui, xywh, txt, bc, tc, true, -2, 5)              
          else
            GUI_text(gui, xywh, txt, 5, gui.color.white, -2)
          end
        end
      end
    end
    
    --scroll b
    local sb_len = F_limit(math.floor(((s3.w / butt_w)/math.ceil(pcnt/rows))*obj.sections[303].w),6,obj.sections[303].w)
    local rp = lvar.listoff_trk_trk / rows
    local pp = obj.sections[303].w/(math.ceil(pcnt/rows))
    local xoff = F_limit(math.floor(pp * rp),0,obj.sections[303].w-sb_len)
    if lvar.hscrollb or lvar.hlsb then
      f_Get_SSV(gui.color.white)    
    else
      f_Get_SSV(colours.sectionline)
    end
    gfx.rect(obj.sections[303].x + xoff,
             obj.sections[303].y,
             sb_len,
             obj.sections[303].h, 1)
    --f_Get_SSV(gui.color.white)
    --[[gfx.rect(obj.sections[303].x,
             obj.sections[303].y,
             obj.sections[303].w,
             obj.sections[303].h, 0)]]
             
    --DBG(cols..'  '..rows..'  '..pcnt..'  '..lvar.listoff_trk_trk..'  '..rp..'  '..math.ceil(pcnt/rows)..'  '..xoff)

  end

  function GUI_DrawSection6_ACT(obj, gui)

    local c = colours.buttcol
    local bc = c
    local tc = gui.color.white
    GUI_DrawButton(gui, obj.sections[400], 'OPEN ACTION LIST', bc, tc, true, -2, 5)       
    local txt
    if lvar.js_avail and reaper.JS_ReaScriptAPI_Version() >= 0.961 then
      txt = 'PASTE FROM ACTION LIST'
    else
      txt = 'PASTE FROM CLIPBOARD'
    end
    GUI_DrawButton(gui, obj.sections[401], txt, bc, tc, true, -2, 5)              
  
    if tdata.actionid and tonumber(tdata.actionid) ~= -1 then
      txt = tdata.pname or tdata.actionid
      tc = ptype_info[tdata.ptype].col
    else
      tc = '99 99 99'
      txt = '<Use the PASTE button to copy a command id from the action list>'
    end
    GUI_DrawButton(gui, obj.sections[402], txt, bc, tc, true, -2, 5, nil, 6, 4)              
    
  end 

  function GUI_DrawSection7_INT(obj, gui)

    local c = colours.devctlassigned
    
    local internal_commands = ic_secvis_commands
    
    local pcnt = #internal_commands
    local s3 = obj.sections[100]
    
    local rows = math.floor(s3.h / butt_h)
    local cols = math.floor(s3.w / butt_w)
    
    local xywh = {x = s3.x, y = s3.y, w = butt_w-2, h = butt_h-2}
    for x = 0, cols do
      for y = 0, rows-1 do
      
        xywh.x = s3.x + butt_w*x
        xywh.y = s3.y + butt_h*y
        
        local p = y + x*rows + lvar.listoff_int + 1
        if p <= pcnt then
          local txt = internal_commands[p].comm
          if internal_commands[p].code == tdata.code and 
             internal_commands[p].codeval == tdata.codeval then
            bc = ptype_info[tdata.ptype].col
            tc = ptype_info[tdata.ptype].btntxt
          else
            bc = c
            tc = ptype_info[tdata.ptype].col
          end

          if internal_commands[p].code ~= -1 then
            GUI_DrawButton(gui, xywh, txt, bc, tc, true, -2+gui.fontsz_special, 5)
          else
            GUI_text(gui, xywh, txt, 5, gui.color.white, -2+gui.fontsz_special)          
          end
        end
      end
    end
  
  end
  
  function GUI_DrawButton(gui, xywh, txt, bcol, tcol, val, tsz, flags, txt2, padx, justifyiftoobig)
  
    f_Get_SSV(bcol)
    gfx.rect(xywh.x,
             xywh.y,
             xywh.w,
             xywh.h, 1)
    local xywh2 = {x = xywh.x+(padx or 0), y = xywh.y, w = xywh.w-(padx or 0)*2, h = xywh.h}
    GUI_text(gui, xywh2, txt, flags or 5, tcol, tsz, justifyiftoobig)
    if txt2 then
      xywh2.x = xywh2.x - 140
      xywh2.w = 130
      GUI_text(gui, xywh2, txt2, 6, '99 99 99', tsz, nil, true)
    end
        
  end
  
  function trim1(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end
  
  function CropFXName(n)
  
    if n == nil then
      return ""
    else
      local fxn = string.match(n, ': (.+)%(')
      if fxn then
        return trim1(fxn)
      else
        --fxn = string.match(n, '.+/(.*)')
        --if fxn and fxn ~= '' then
        --  return trim1(fxn)
        --else
          return trim1(n)
        --end
      end
    end
    
  end
   
  ------------------------------------------------------------
  
  function Lokasenna_Window_At_Center (w, h)
    -- thanks to Lokasenna 
    -- http://forum.cockos.com/showpost.php?p=1689028&postcount=15    
    local l, t, r, b = 0, 0, w, h    
    local __, __, screen_w, screen_h = reaper.my_getViewport(l, t, r, b, l, t, r, b, 1)    
    local x, y = (screen_w - w) / 2, (screen_h - h) / 2    
    gfx.init("SK2 FADER PROPERTIES", w, h, 0, x, y)  
  end

 -------------------------------------------------------------     
      
  function F_limit(val,min,max)
      if val == nil or min == nil or max == nil then return end
      local val_out = val
      if val < min then val_out = min end
      if val > max then val_out = max end
      return val_out
    end   
  ------------------------------------------------------------
    
  function MOUSE_click(b)
    if b and mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.LB 
      and not mouse.last_LB then
     return true 
    end 
  end

  function MOUSE_click_RB(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      and mouse.RB 
      and not mouse.last_RB then
     return true 
    end 
  end

  function MOUSE_over(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h 
      then
     return true 
    end 
  end
  
  ------------------------------------------------------------
    
  function nz(val, d)
    if val == nil then return d else return val end
  end
  function zn(val, d)
    if val == '' or val == nil then return d else return val end
  end
  

  function BoolToNum(x)
    if x == true then
      return 1
    else
      return 0
    end
  end

  function GenTrackPName(txt)
    trstr = ''
    if tdata.trparam == -1 then
    else
      if tdata.track == -1 then
        trstr = ' SEL'
      elseif tdata.track == -2 then
        if txt then
          trstr = ' '..txt        
        else
          trstr = ' OFFS '..string.format('%i',tdata.troff)       
        end
      elseif tdata.track == 0 then
        trstr = ' MASTER'
      else
        trstr = ' '..string.format('%i',tdata.track or -1)
      end
      trstr = (tab_trparams[tdata.trparam] or '<not set>')..trstr
    end
    return trstr
  end

  function GenTrackSName(txt)
    trstr = ''
    if tdata.trsend == -1 then
    else
      if tdata.track == -1 then
        trstr = ' SEL'
      elseif tdata.track == -2 then
        if txt then
          trstr = ' '..txt        
        else
          trstr = ' OFFS '..string.format('%i',tdata.troff)       
        end
      elseif tdata.track == 0 then
        trstr = ' MASTER'
      else
        trstr = ' '..string.format('%i',tdata.track or -1)
      end
      trstr = (tab_trsnds[tdata.trsend] or '<not set>')..trstr
    end
    return trstr
  end
  
  function GetCurrentValFromPlug()
  
    if tdata.ptype == ptype.host then
      --local ret, trn, _, fxn = reaper.GetFocusedFX()
      local ret = 1
      local trn = lvar.foc_fx_trn
      local fxn = lvar.foc_fx_num
      local fxguid = lvar.foc_fx_guid
      
      if ret == 1 and tdata.pnum then
      
        local track = GetTrack(trn)
        if track then
          local v = reaper.TrackFX_GetParamNormalized(track, fxn, tdata.pnum)
          return v
        end
      end
    end
  end
  
  function ScrubMenu()
    local menustr = ''
    for i = 0, #tab_scrubnudge do
      if menustr ~= '' then
        menustr = menustr .. '|'
      end
      menustr = menustr .. tab_scrubnudge[i].desc
    end
    
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(menustr)
    return res
  end
  
  function ConvertColor(c)
    local r = (c & 255)
    local g = (c >> 8 & 255)
    local b = (c >> 16 & 255)
    return math.floor(r) .. ' ' .. math.floor(g) .. ' ' .. math.floor(b)
  end
  
  function ConvertColorString(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i)
    end
    return t[1] + (t[2] << 8) + (t[3] << 16)
  end
  
  function Device_RBMenu()
  
    local a = ''
    if lvar.dev_borderctls then
      a = '!'
    end
    local a2 = ''
    if lvar.highlight_perm then
      a2 = '!'
    end
    local mstr = a..'Add Control Borders||Set Border Color||'..a2..'Highlight Permanent Controls'
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if res == 1 then
        lvar.dev_borderctls = not lvar.dev_borderctls
        update_gfx = true
      elseif res == 2 then
        local ret, col = reaper.GR_SelectColor(_,ConvertColorString(lvar.dev_borderctls_col or '0 0 0'))
        if ret ~= 0 then            
          lvar.dev_borderctls_col = ConvertColor(col)
          update_gfx = true            
        end

      elseif res == 3 then
        lvar.highlight_perm = not lvar.highlight_perm
        update_gfx = true
      end
    end
  
  end
  
  function ShareMenu()

    local mstr = 'Off|'
    local tab = {}
    for a, b in pairs(lvar.sharedata) do
      if b.lmode == 4 and b.fader ~= -1 then
        tab[#tab+1] = b
        tab[#tab].devctl = a
      end
    end

    --tab = table_slowsort_gen(tab, 'fader') or {}
    tab = table_sort(tab, 'fader') or {}
    for i = 1, #tab do
      local byp = ''
      if tonumber(tab[i].fader) == tonumber(lvar.selfader) then
        byp = '#'
      end
      mstr = mstr ..'|'..byp..'['..string.format('%i',tab[i].fader)..']   Device '.. string.gsub(tab[i].devctl,'|','   ') .. ' - ' ..tostring(tab[i].name)
    end
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if res == 1 then
        if tdata.linkonly then
          tdata.linkA_linkonly = nil
        else
          tdata.linkA = nil
        end
      else
        res = res -1
        if tdata.linkonly then
          tdata.linkA_linkonly = tab[res].devctl
        else
          tdata.linkA = tab[res].devctl
        end
        tdata.linkB = nil
      end
      update_gfx = true
    end
    
  end
  
  function VTMenu()

    local mstr = 'Default|Off|'
    for i = 0, 5 do
      mstr = mstr .. '|' .. i ..' s'
    end
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if res == 1 then
        tdata.valtime = -1
      elseif res == 2 then
        tdata.valtime = -2
      else
        tdata.valtime = res-3
      end
      update_gfx = true
    end
  end
  
  function SSMenu()
  
    local mstr = 'Default|'
    for i = 1, lvar.sscount do
      mstr = mstr .. '|' .. i
    end
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local res = gfx.showmenu(mstr)
    if res > 0 then
      if res == 1 then
        tdata.ss_override = nil
      --elseif res == 2 then
      --  tdata.ss_override = -1
      else
        tdata.ss_override = res - 1
      end
      update_gfx = true    
    end
  
  end
  
  function GetFocusedFX()
    local ret, trn, itmn, fxn = reaper.GetFocusedFX2()
    if ret > 0 and not (itmn > 0) then
      local tr = GetTrack(trn)
      lvar.foc_fx_trn = trn
      lvar.foc_fx_num = fxn
      lvar.foc_fx_guid = reaper.TrackFX_GetFXGUID(tr, fxn)
      reaper.SetExtState(SCRIPT, 'foc_fx_trn', lvar.foc_fx_trn, false)
      reaper.SetExtState(SCRIPT, 'foc_fx_num', lvar.foc_fx_num, false)
      reaper.SetExtState(SCRIPT, 'foc_fx_guid', lvar.foc_fx_guid, false)
      reaper.SetExtState(SCRIPT, 'UpdateFocFX', 1, false)
      update_gfx = true
    end
  end
  
  function CreateHostFilter()
  
    if not lvar.hostfilter then 
      lvar.hostfilter_tab = nil
      update_gfx = true
      return 
    end
    
    lvar.hostfilter_tab = {}
    
    local trn = lvar.foc_fx_trn
    local fxn = lvar.foc_fx_num
    local fxguid = lvar.foc_fx_guid
    local itmnum = lvar.foc_fx_itemnum
    
    local tr = GetTrack(trn)
    local GetNumParams, GetParamName, GetFXName, CountFXParams
    if itmnum and itmnum ~= -1 then
      local item = reaper.GetTrackMediaItem(tr, itmnum)
      local take = reaper.GetActiveTake(item)
      track = take
      GetFXName = reaper.TakeFX_GetFXName
      GetParamName = reaper.TakeFX_GetParamName
      GetNumParams = reaper.TakeFX_GetNumParams
    else
      track = tr
      GetFXName = reaper.TrackFX_GetFXName
      GetParamName = reaper.TrackFX_GetParamName
      GetNumParams = reaper.TrackFX_GetNumParams
    end
    if track then
      local filtstr = string.lower(lvar.hostfilter)
      for idx = 0, GetNumParams(track, fxn)-1 do
        local _, pname = GetParamName(track,fxn,idx)
        if string.match(string.lower(pname), filtstr) then
          lvar.hostfilter_tab[#lvar.hostfilter_tab+1] = {pnum = idx, pname = pname}
        end
      end
      
    end
    update_gfx = true
    
  end
  
  function run()
    local rt = reaper.time_precise()  
    local lv = lvar
    local td = tdata
    
    if gfx.w ~= last_gfx_w or gfx.h ~= last_gfx_h or force_resize or obj == nil then

      local r = false
      if not r or gfx.dock(-1) > 0 then 
      
        gfx1.main_w = gfx.w
        gfx1.main_h = gfx.h
        win_w = gfx.w
        win_h = gfx.h
  
        last_gfx_w = gfx.w
        last_gfx_h = gfx.h
                
        gui = GetGUI_vars()
        obj = GetObjects()
        
        resize_display = true
        update_gfx = true
        --rsz = true
      end
    --[[elseif rsz then
      if lvar.js_avail then
        local nw, nh = gfx.w, gfx.h
        local resize
        if gfx.h < 560 then
          nh = 600
          resize = true
        end
        if gfx.w < 440 then
          nw = 480
          resize = true
        end
        if resize then
          local hwnd = reaper.JS_Window_Find('SK2 FADER PROPERTIES',true)
          if hwnd then
            reaper.JS_Window_Resize(hwnd, nw, nh)
            gfx.update()
          end
        end
      end
      rsz = nil]]
    end
    
    GUI_draw(obj, gui)
    
    mouse.mx, mouse.my = gfx.mouse_x, gfx.mouse_y
    mouse.LB = gfx.mouse_cap&1==1
    mouse.RB = gfx.mouse_cap&2==2
    mouse.ctrl = gfx.mouse_cap&4==4
    mouse.shift = gfx.mouse_cap&8==8
    mouse.alt = gfx.mouse_cap&16==16
    -------------------------------------------
    
    if reaper.gmem_read(lvar.props.visible) == 0 then
      quit()
    end

    if lvar.nextwait then
      if not tonumber(reaper.GetExtState(SCRIPT, 'writedirty')) then
        lvar.nextwait = nil
        SelectNextSlot()
      end
    end
    MonitorSelectedData()

    if mouse.context == nil then
      if gfx.mouse_wheel ~= 0 then
        local v = GetMW(gfx.mouse_wheel) -- / 120
          
        if mouse.shift and mouse.ctrl then
          lvar.butt_h = F_limit(lvar.butt_h + v, 22, lvar.butth_limit)
          obj = GetObjects()
          update_gfx = true
        elseif mouse.alt then
          lvar.fadjust = F_limit(lvar.fadjust + v, 0, 10)
          update_gfx = true
        else
          if MOUSE_over(obj.sections[1]) then
            if v < 0 then
              SelectNextSlot()
            else
              SelectPrevSlot()
            end
          elseif lvar.buttstates and MOUSE_over(obj.sections[500]) then
            
            lvar.bsoffs = F_limit(lvar.bsoffs - v,0,tdata.butstates-1)
            update_gfx = true
          
          elseif td.ptype == ptype.host then
            if MOUSE_over(obj.sections[102]) then
              --local ret, trn, _, fxn = reaper.GetFocusedFX()
              local ret = 1
              local trn = lvar.foc_fx_trn
              local fxn = lvar.foc_fx_num
              local fxguid = lvar.foc_fx_guid
              
              if ret == 1 then
              
                local track = GetTrack(trn)
                local pcnt = reaper.TrackFX_GetNumParams(track, fxn)
                local s3 = obj.sections[102]            
                local cols = math.floor(s3.w / butt_w)
                local rows = math.floor(s3.h / butt_h)
                local lc = (pcnt % rows) + (cols-1)*rows
                lvar.listoff_host = math.max(F_limit(lvar.listoff_host - (v*rows),0,pcnt-lc),0)
                update_gfx = true
              end
            end
            
          elseif td.ptype == ptype.cc then
            if MOUSE_over(obj.sections[201]) then
              
              local pcnt = 128
              if tdata.cc14bit == 1 then
                pcnt = 32
              end
              local butt_w = math.floor(butt_w/2)
              local s3 = obj.sections[201]            
              local cols = math.floor(s3.w / butt_w)
              local rows = math.floor(s3.h / butt_h)
              local lc = (pcnt % rows) + (cols-1)*rows
              lvar.listoff_cc = math.max(F_limit(lvar.listoff_cc - (v*rows),0,pcnt-lc),0)
              update_gfx = true
            end
  
          elseif td.ptype == ptype.track then
  
            if MOUSE_over(obj.sections[301]) then
              
              local pcnt = #tab_trparams + #tab_trsnds + 1
              local s3 = obj.sections[301]            
              local rows = math.floor(s3.h / butt_h)
              local lc = (pcnt % rows)
              lvar.listoff_trk_prm = math.max(F_limit(lvar.listoff_trk_prm - (v*rows),0,pcnt-lc),0)
              update_gfx = true
              
            elseif MOUSE_over(obj.sections[302]) then
              
              local trackcnt = reaper.CountTracks(0)
              local pcnt
              if lvar.expandtrackoffs then
                pcnt = 33 + trackcnt + 2
              else
                pcnt = 1 + trackcnt + 2
              end
              local s3 = obj.sections[302]            
              local cols = math.floor(s3.w / butt_w)
              local rows = math.floor(s3.h / butt_h)
              local lc = (pcnt % rows) + (cols-1)*rows
              lvar.listoff_trk_trk = math.max(F_limit(lvar.listoff_trk_trk - (v*rows),0,pcnt-lc),0)
              update_gfx = true
            end
          
          elseif td.ptype == ptype.action then
          elseif td.ptype == ptype.internal then
            --local internal_commands = ic_secvis_commands
            local pcnt = #ic_secvis_commands
            local s3 = obj.sections[100]            
            local cols = math.floor(s3.w / butt_w)
            local rows = math.floor(s3.h / butt_h)
            local lc = (pcnt % rows) + (cols-1)*rows
            lvar.listoff_int = math.max(F_limit(lvar.listoff_int - (v*rows),0,pcnt-lc),0)
            update_gfx = true
          
          end 
        end
        gfx.mouse_wheel = 0 
      end
      
      if MOUSE_click(obj.sections[98]) then
        local hwnd = reaper.JS_Window_Find("SK2 FADER PROPERTIES", true)
        if hwnd then
          mouse.context = contexts.resize_l
          local ret, l, t, r, b = reaper.JS_Window_GetRect(hwnd)
        
          lvar.resize = {hwnd = hwnd, x = reaper.GetMousePosition(), o_l = l, o_r = r, o_t = t, o_b = b}
        end
      
      elseif MOUSE_click(obj.sections[2001]) then
      
        mouse.context = contexts.movesplit
        lvar.movesplit = {splith = lvar.splith, y = mouse.my}
      
      elseif MOUSE_click_RB(obj.sections[2000]) then
        
        Device_RBMenu()
        
      elseif MOUSE_click(obj.sections[2000]) then
      
        local mh = obj.sections[2000].h - 10
        local mw = obj.sections[2000].w - 10
              
        local iw,ih = gfx.getimgdim(lvar.device_img)
        local scale = mw/iw
        if mh/ih < scale then
          scale = mh/ih
        end
        local w = math.floor(iw*scale)
        local h = math.floor(ih*scale)
                
        local xywh = {x = obj.sections[2000].x + math.floor((obj.sections[2000].w/2) - w/2),
                      y = obj.sections[2000].y + math.floor((obj.sections[2000].h/2) - h/2),
                      w = w,
                      h = h}
      
        if MOUSE_click(xywh) then
          local mx = (mouse.mx - xywh.x) / scale
          local my = (mouse.my - xywh.y) / scale
          local fnd
          local v = math.huge
          for a, b in pairs(lvar.devdata) do
            if b.shape == 0 then
              if mx >= b.l and mx <= b.r and my >= b.t and my <= b.b then
                local vol = (b.r-b.l) * (b.b-b.t)
                if vol < v then
                  v = vol
                  fnd = a
                end
                --break 
              end
            elseif b.shape == 1 then
              local r = math.sqrt((mx-b.l)^2 + (my-b.t)^2)
              if r <= b.r then
                local vol = 3.14*b.r*b.r
                if vol < v then
                  v = vol
                  fnd = a
                end
                --break 
              end
            end
          end
          if fnd then
            SelectSlotByName(fnd)
          end
        end
        
      elseif td.ptype ~= -1 then

        if lvar.buttstates and (MOUSE_click(obj.sections[100]) or MOUSE_click_RB(obj.sections[100])) then
          if MOUSE_click(obj.sections[501]) then
            --button states window
            local st = math.floor((mouse.my - obj.sections[501].y) / butt_h) + 1
            if tdata.butstates_array[st] then
              if mouse.mx -obj.sections[501].x < 40 then
                if mouse.shift then              
                  local v = GetCurrentValFromPlug()
                  if v then
                    tdata.butstates_array[st] = v
                    --lvar.apply_dirty = true
                    update_gfx = true
                  end
                elseif st >= 1 then
                  --SS color
                  tdata.butstates_array_sscolor[st] = (tdata.butstates_array_sscolor[st] or 0) + 1
                  if tdata.butstates_array_sscolor[st] > #tab_xtouch_colors then
                    tdata.butstates_array_sscolor[st] = nil
                  elseif st == 1 then
                    tdata.sscolor = tdata.butstates_array_sscolor[st]
                  end
                  --lvar.apply_dirty = true
                  update_gfx = true
                --elseif st == 1 then
                  
                end
              else
                local v = tdata.butstates_array[st]
                if tdata.ptype == ptype.cc then
                  v = string.format('%i',v)
                end
                --DBG(tostring(tdata.code)..'  '..tostring(tdata.codeval))
                local ret, val = reaper.GetUserInputs('Button State '..string.format('%i',st), 1, 'Enter value:', v)
                if ret and tonumber(val) then
                  if tdata.ptype == ptype.cc then
                    if tdata.cc14bit == 1 then
                      val = F_limit(math.floor(tonumber(val)),0,16383)
                    else
                      val = F_limit(math.floor(tonumber(val)),0,127)
                    end
                  elseif tdata.ptype == ptype.internal and tdata.code == 5 and tdata.codeval >= 2 then
                    --no limit
                  elseif tdata.ptype == ptype.internal and tdata.code == 6 and tdata.codeval >= 24 and tdata.codeval <= 28 then
                    val = F_limit(math.floor(tonumber(val)),0,400)                    
                  elseif tdata.ptype == ptype.internal and tdata.code == 11 and tdata.codeval >= 4 and tdata.codeval <= 8 then
                    val = F_limit(math.floor(tonumber(val)),0,400)                    
                  elseif tdata.ptype == ptype.internal and tdata.code == 14 and tdata.codeval == 2 then
                    val = F_limit(math.floor(tonumber(val)),0,100)                    
                  else
                    val = F_limit(tonumber(val),0,1)
                  end
                  tdata.butstates_array[st] = val
                  --lvar.apply_dirty = true
                  update_gfx = true
                end
              end
            end

          elseif MOUSE_click_RB(obj.sections[501]) then
          
            lvar.buttstates = not lvar.buttstates
            update_gfx = true

          elseif MOUSE_click(obj.sections[505]) then
            --button states window
            local st = math.floor((mouse.my - obj.sections[501].y) / butt_h) + 1
            if tdata.butstates_array[st] then
              local v = tdata.butstates_array_name[st] or ''
              local ret, val = reaper.GetUserInputs('Value Text '..string.format('%i',st), 1, 'Enter text value (7 chars):', v)
              if ret and val then
                tdata.butstates_array_name[st] = string.sub(val,1,7)
                --lvar.apply_dirty = true
                update_gfx = true 
              end            
            end
            
          elseif MOUSE_click(obj.sections[502]) then
            if tdata.code == 5 and tdata.codeval == 6 then
              local st = math.floor((mouse.my - obj.sections[501].y) / butt_h) + 1
              if tdata.butstates_array[st] then
                local val = ScrubMenu()
                if val > 0 then
                  val = val -1
                  tdata.butstates_array_ext[st] = val
                  tdata.butstates_array[st] = 1
                  --lvar.apply_dirty = true
                end
                update_gfx = true
              end
            end
          
          elseif MOUSE_click(obj.sections[500]) then
            if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.2 then
              CalcButtStates()
              update_gfx = true
            end
          end          
      
        elseif td.ptype == ptype.host then

          if MOUSE_click(obj.sections[101]) then
            if lvar.focusmode == 3 --[[or lvar.gflag == 2 or lvar.gflag == 3]] then
              local trn = lvar.foc_fx_trn
              local fxn = lvar.foc_fx_num
              local fxguid = lvar.foc_fx_guid
              local itmnum = lvar.foc_fx_itemnum
              local tr = GetTrack(trn)
              local GetFXName, GetFXGUID, fxcnt
              if itmnum and itmnum ~= -1 then
                local item = reaper.GetTrackMediaItem(tr, itmnum)
                local take = reaper.GetActiveTake(item)
                track = take
                GetFXName = reaper.TakeFX_GetFXName
                GetFXGUID = reaper.TakeFX_GetFXGUID
                if take then
                  fxcnt = reaper.TakeFX_GetCount(take)
                end
              else
                track = tr
                GetFXName = reaper.TrackFX_GetFXName
                GetFXGUID = reaper.TrackFX_GetFXGUID
                if track then
                  fxcnt = reaper.TrackFX_GetCount(track)
                end
              end
              if fxcnt and fxcnt > 0 then
                local mstr = ''
                for f = 0, fxcnt-1 do
                  local _, fxname = GetFXName(track, f, '')
                  if f ~= 0 then
                    mstr = mstr .. '|'
                  end
                  mstr = mstr .. string.format('%i',f+1) ..': '..fxname
                end
                gfx.x = mouse.mx
                gfx.y = mouse.my
                local res = gfx.showmenu(mstr)
                if res > 0 then
                  local fxnum = res-1
                  lvar.foc_fx_num = fxnum
                  lvar.foc_fx_guid = GetFXGUID(track, fxnum)
                  reaper.SetExtState(SCRIPT, 'foc_fx_trn', lvar.foc_fx_trn, false)
                  reaper.SetExtState(SCRIPT, 'foc_fx_num', lvar.foc_fx_num, false)
                  reaper.SetExtState(SCRIPT, 'foc_fx_guid', lvar.foc_fx_guid, false)
                  reaper.SetExtState(SCRIPT, 'UpdateFocFX', 1, false)
                  update_gfx = true
                  lvar.hostfilter = nil
                  CreateHostFilter()
                end
              end
            end
          
          elseif MOUSE_click_RB(obj.sections[104]) then
            lvar.hostfilter = nil
            lvar.hostfilter_tab = nil
            update_gfx = true
            CreateHostFilter()
            
          elseif MOUSE_click(obj.sections[104]) then
            --filter
            local ret, val = reaper.GetUserInputs('Filter parameter names',1,'Filter:,extrawidth=100',lvar.hostfilter or '')
            if ret then
              if val ~= '' then
                lvar.hostfilter = val
              else
                lvar.hostfilter = nil
                lvar.hostfilter_tab = nil
                update_gfx = true
              end
              CreateHostFilter()
              
            end
            
          elseif MOUSE_click(obj.sections[103]) then
            --make this toggle button - then monitor focused fx (only when gflag = 2 or 3
            --actually won't work nicely without additional logic - best leave it as is maybe.
          
            --hmmm if in monitor function - no plugin assignment exists - show focused (gfalg=2 or 3).
          
            --only do on global layers
            if lvar.gflag == 2 or lvar.gflag == 3 then
              
              GetFocusedFX()
              
            end
            lvar.hostfilter = nil
            CreateHostFilter()
            
          elseif MOUSE_click(obj.sections[102]) then

            --local ret, trn, _, fxn = reaper.GetFocusedFX()
            local ret = 1
            local trn = lvar.foc_fx_trn
            local fxn = lvar.foc_fx_num
            local fxguid = lvar.foc_fx_guid
            local itmnum = lvar.foc_fx_itemnum
            
            if ret == 1 then
            
              local tr = GetTrack(trn)
              local GetNumParams, GetParamName
              if itmnum and itmnum ~= -1 then
                local item = reaper.GetTrackMediaItem(tr, itmnum)
                local take = reaper.GetActiveTake(item)
                track = take
                GetParamName = reaper.TakeFX_GetParamName
                GetNumParams = reaper.TakeFX_GetNumParams
              else
                track = tr
                GetParamName = reaper.TrackFX_GetParamName
                GetNumParams = reaper.TrackFX_GetNumParams
              end

              if track then
                local pcnt
                if lvar.hostfilter then
                  pcnt = #lvar.hostfilter_tab
                else
                  pcnt = GetNumParams(track, fxn)
                end
                
                local s3 = obj.sections[102]
                
                local rows = math.floor(s3.h / butt_h)
                local cols = math.floor(s3.w / butt_w)
                
                local x = math.floor((mouse.mx - obj.sections[102].x) / butt_w)
                local y = math.floor((mouse.my - obj.sections[102].y) / butt_h)
    
                local i = y + x*rows + lvar.listoff_host
                if i < pcnt then
                
                  tdata.actionmon = 1
                  tdata.name = nil
                  if lvar.hostfilter then
                    tdata.pnum = lvar.hostfilter_tab[i+1].pnum
                    tdata.pname = lvar.hostfilter_tab[i+1].pname 
                  else
                    tdata.pnum = i
                    _, tdata.pname = GetParamName(track, fxn, i, '')
                  end
                  update_gfx = true
                
                  if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.2 then
                    Apply()
                  end
                end
              end
              
            end
          end
          
        elseif td.ptype == ptype.cc then
          if MOUSE_click(obj.sections[202]) then
            tdata.ccchan =tdata.ccchan + 1
            if tdata.ccchan > 15 then
              tdata.ccchan = 0
            end
            update_gfx = true
          elseif MOUSE_click_RB(obj.sections[202]) then
            tdata.ccchan = tdata.ccchan - 1
            if tdata.ccchan < 0 then
              tdata.ccchan = 15
            end
            update_gfx = true
          elseif MOUSE_click(obj.sections[203]) then
            tdata.cc14bit = 1-(tdata.cc14bit or 0)
            update_gfx = true
            if lvar.lmode == 4 then
              CalcButtStates()
            end
            
          elseif MOUSE_click(obj.sections[201]) then
            
            local pcnt = 128
            if tdata.cc14bit == 1 then
              pcnt = 32
            end
            
            local butt_w = math.floor(butt_w/2)
                
            local s3 = obj.sections[201]
            
            local rows = math.floor(s3.h / butt_h)
            local cols = math.floor(s3.w / butt_w)
            
            local x = math.floor((mouse.mx - obj.sections[201].x) / butt_w)
            local y = math.floor((mouse.my - obj.sections[201].y) / butt_h)

            local i = y + x*rows + lvar.listoff_cc
            if i < pcnt then
            
              tdata.ccnum = i
              if not lvar.retainassignname then
                tdata.name = nil
              end
              if tdata.ccchan == -1 then
                tdata.ccchan = 0
              end
              
              if lvar.lmode ~= 4 then 
                tdata.defcc_val = reaper.gmem_read(lvar.gm_ccstamp.defcc_val+i)
              else
                tdata.defcc_val = nil
              end
              update_gfx = true
            
              if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.15 then
                Apply()
              end
            end
          end
        
        elseif td.ptype == ptype.track then

          if MOUSE_over(obj.sections[303]) and not lvar.hlsb then
            lvar.hlsb = true
            update_gfx = true          
          elseif not MOUSE_over(obj.sections[303]) and lvar.hlsb then
            lvar.hlsb = nil
            update_gfx = true
          end          
          if MOUSE_click(obj.sections[301]) then

            local pcnt = #tab_trparams + #tab_trsnds + 1
                
            local s3 = obj.sections[301]
            
            local rows = math.floor(s3.h / butt_h)
            
            local y = math.floor((mouse.my - obj.sections[301].y) / butt_h)

            local i = y + lvar.listoff_trk_prm + 1
            if i <= #tab_trparams then
            
              tdata.trparam = i
              tdata.trsend = -1
              tdata.name = nil
              if (tdata.track or -99) == -99 or (tdata.track or -99) == -2 then
                tdata.track = -1
                tdata.troff = -1
                tdata.trguid = ''
              end
              tdata.pname = GenTrackPName()
              update_gfx = true
            
              if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.15 then
                Apply()
              end
            elseif i == #tab_trparams+1 then

            elseif i <= pcnt then
              tdata.trparam = -1
              tdata.trsend = i-(#tab_trparams+1)
              tdata.name = nil
              if (tdata.track or -99) == -99 or (tdata.track or -99) == -2 then
                tdata.track = -1
                tdata.troff = -1
                tdata.trguid = ''
              end
              tdata.pname = GenTrackSName()
              update_gfx = true
            
              if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.15 then
                Apply()
              end

            end
            
          elseif MOUSE_click(obj.sections[302]) then

            local trackcnt = reaper.CountTracks(0)
            
            local pcnt
            if lvar.expandtrackoffs then
              pcnt = 33 + trackcnt + 2
            else
              pcnt = 1 + trackcnt + 2            
            end    
            local s3 = obj.sections[302]
            
            local rows = math.floor(s3.h / butt_h)
            local cols = math.floor(s3.w / butt_w)
            
            local x = math.floor((mouse.mx - obj.sections[302].x) / butt_w)
            local y = math.floor((mouse.my - obj.sections[302].y) / butt_h)

            local i = F_limit(y + x*rows + lvar.listoff_trk_trk,0,9999)
            if i <= pcnt then
            
              if i == 0 then
                tdata.track = -1
                tdata.troff = -1
                tdata.trguid = ''
              elseif i == 1 then --do nowt
                lvar.expandtrackoffs = not lvar.expandtrackoffs
              else
                if lvar.expandtrackoffs then  
                  if i < 34 then
                    tdata.track = -2
                    tdata.troff = i-2
                    tdata.trguid = ''
                  elseif i == 34 then --do nowt
                  else
                    tdata.track = i-35
                    tdata.troff = -1
                    if tdata.track ~= -1 then
                      tdata.trguid = reaper.GetTrackGUID(GetTrack(tdata.track))
                    else
                      tdata.trguid = ''
                    end
                  end
                else
                  if i == 2 then --do nowt
                  else
                    tdata.track = i-3
                    tdata.troff = -1
                    if tdata.track ~= -1 and tdata.track >= 0 then
                      tdata.trguid = reaper.GetTrackGUID(GetTrack(tdata.track))
                    else
                      tdata.trguid = ''
                    end
                  end                
                end
              end
              if (tdata.trparam or -1) == -1 and (tdata.trsend or -1) == -1 then
                tdata.trparam = 1
                tdata.trsend = -1
              end

              if tdata.trparam ~= -1 and tdata.trparam <= #tab_trparams then
                tdata.pname = GenTrackPName()
              elseif tdata.trsend ~= -1 and tdata.trsend <= #tab_trsnds then
                tdata.pname = GenTrackSName()              
              end
              update_gfx = true
            
              if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.15 then
                Apply()
              end
            end

          elseif MOUSE_click(obj.sections[303]) then
            
            local trackcnt = reaper.CountTracks(0)
                
            local pcnt
            if lvar.expandtrackoffs then
              pcnt = 33 + trackcnt + 3
            else
              pcnt = 1 + trackcnt + 3
            end
            local s3 = obj.sections[302]
                
            local rows = math.floor(s3.h / butt_h)
            local cols = math.floor(s3.w / butt_w)
            local sb_len = F_limit(math.floor(((s3.w / butt_w)/math.ceil(pcnt/rows))*obj.sections[303].w),6,obj.sections[303].w)
            local rp = lvar.listoff_trk_trk / rows
            local pp = obj.sections[303].w/(math.ceil(pcnt/rows))
            local xoff = F_limit(math.floor(pp * rp),0,obj.sections[303].w-sb_len)
            
            if mouse.mx >= obj.sections[303].x+xoff and mouse.mx <= obj.sections[303].x+xoff+sb_len then
              local offs = mouse.mx - (obj.sections[303].x+xoff)
              lvar.hscrollb = {offs = offs, pp = pp, rows = rows, cols = cols, pcnt = pcnt, mx = mouse.mx}
              mouse.context = contexts.sbar_trk
              update_gfx = true
            end
          
          elseif lvar.hscrollb then
          
            update_gfx = true
            lvar.hscrollb = nil
          end
          
        elseif td.ptype == ptype.action then
        
          if MOUSE_click(obj.sections[400]) then
            reaper.Main_OnCommand(40605,0)
          elseif MOUSE_click(obj.sections[401]) then
            if reaper.APIExists('JS_ReaScriptAPI_Version') then
              if reaper.JS_ReaScriptAPI_Version() >= 0.961 then
                local hwnd = reaper.JS_Window_Find('Actions',true)
                if hwnd then
                  --local lhwnd = reaper.JS_Window_FindChild(hwnd, 'List1', true)
                  local lhwnd = reaper.JS_Window_FindChildByID(hwnd, 0x52B)                                                         
                  if lhwnd then
                    local retval, text = reaper.JS_ListView_GetFocusedItem(lhwnd)
                    if retval then
                      local desc = reaper.JS_ListView_GetItemText(lhwnd, retval, 1)
                      local commandID = reaper.JS_ListView_GetItemText(lhwnd, retval, 3)
                      if commandID then
                        tdata.actionid = tonumber(commandID) or commandID
                        if (desc or '') ~= '' then
                          tdata.pname = desc
                        else
                          tdata.pname = 'Cmd ID: '..string.gsub(tdata.actionid,'_','')
                        end
                        
                        local actid = tonumber(tdata.actionid)
                        local val
                        if actid and actid ~= -1 then
                          val = reaper.GetToggleCommandStateEx(0, actid)
                        else
                          val = reaper.GetToggleCommandStateEx(0, reaper.NamedCommandLookup(tdata.actionid))                
                        end
                        if val == -1 then --no monitoring
                          tdata.buttype = 0
                          tdata.actionmon = 0
                          tdata.butstates = 1
                          tdata.butstates_array = {0}
                          tdata.butstates_array_ext = {0}
                        else
                          tdata.buttype = 4
                          tdata.actionmon = 1
                          tdata.butstates = 2
                          tdata.butstates_array = {0, 1}
                          tdata.butstates_array_ext = {0, 0}
                        end
                        update_gfx = true
                      end
                    end
                  end 
                end
              end
            elseif reaper.APIExists('CF_GetClipboard') then
              local clipboard = reaper.CF_GetClipboard('')
              if tonumber(clipboard) or string.sub(clipboard,1,1) == '_' then
                tdata.actionid = tonumber(clipboard) or clipboard
                tdata.pname = 'Cmd ID: '..string.gsub(tdata.actionid,'_','')
              end
              update_gfx = true
              if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.15 then
                Apply()
              end
              
            else
              DBG('This button requires a newer version of SWS installed')
            end

          elseif MOUSE_click(obj.sections[402]) then

            if not reaper.APIExists('CF_GetClipboard') then
              local aid = tdata.actionid
              if tonumber(aid) == -1 then
                aid = ''
              end
              local ret, actid = reaper.GetUserInputs('Enter action id',1,'Enter action id:,extrawidth=200',aid or '')
              if ret and actid then
                tdata.actionid = tonumber(clipboard) or clipboard
                tdata.pname = 'Cmd ID: '..string.gsub(tdata.actionid,'_','')
                update_gfx = true
              end
            else
              if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.15 then
                Apply()
              end
            end

          elseif MOUSE_click_RB(obj.sections[402]) then
            local aid = tdata.actionid
            if tonumber(aid) == -1 then
              aid = ''
            end
            local ret, actid = reaper.GetUserInputs('Enter action id',1,'Enter action id:,extrawidth=200',aid or '')
            if ret and actid then
              tdata.actionid = actid
              tdata.pname = 'Cmd ID: '..string.gsub(tdata.actionid,'_','')
              update_gfx = true
            end

          end
                  
        elseif td.ptype == ptype.internal then
          if MOUSE_click(obj.sections[100]) then
            local track = GetTrack(trn)
            local internal_commands = ic_secvis_commands
            local pcnt = #internal_commands
                
            local s3 = obj.sections[100]
            
            local rows = math.floor(s3.h / butt_h)
            local cols = math.floor(s3.w / butt_w)
            
            local x = math.floor((mouse.mx - obj.sections[100].x) / butt_w)
            local y = math.floor((mouse.my - obj.sections[100].y) / butt_h)

            local i = y + x*rows + lvar.listoff_int+1
            if i <= pcnt and internal_commands[i].code ~= -1 then
            
              local oc = tdata.code
              local ocv = tdata.codeval
              tdata.code = internal_commands[i].code
              tdata.codeval = internal_commands[i].codeval
              tdata.pname = internal_commands[i].comm

              if oc ~= tdata.code or ocv ~= tdata.codeval then
                if lvar.lmode == 4 then
                  if internal_commands[i].buttype then
                    tdata.buttype = tab_btntype[internal_commands[i].buttype].v
                    if tdata.buttype == 0 then
                      tdata.butstates = 1
                      tdata.butstates_array = {0}
                      tdata.butstates_array_ext = {0}
                      tdata.actionmon = 0  
                    else
                      if internal_commands[i].toggle then
                        tdata.butstates = internal_commands[i].toggle
                        if tdata.butstates > 0 then
                          tdata.butstates_array = {}
                          tdata.butstates_array_ext = {}
                          for bs = 1, #internal_commands[i].states do
                            tdata.butstates_array[bs] = internal_commands[i].states[bs]
                            tdata.butstates_array_ext[bs] = 0
                          end
                        end
                      end
                    end
                    tdata.actionmon = internal_commands[i].mon or 0
                  else
                    CalcButtStates()
                  end
                end
              end
            
              update_gfx = true
            
              if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.15 then
                Apply()
              end
            elseif i <= pcnt and internal_commands[i].code == -1 then
              local sec = internal_commands[i].sec
              if sec then
                ic_secvis[sec] = not ic_secvis[sec]
                IC_SecVis_Pop()
                update_gfx = true
              end
            end
            
          elseif MOUSE_click_RB(obj.sections[100]) then
            InternalMenu()
          end
          
        end
        if MOUSE_click(obj.sections[99]) then
          Apply()
        elseif lvar.hdr_devicetxt and MOUSE_click(lvar.hdr_devicetxt) then
          SelectNextDevice()
        elseif lvar.hdr_devicetxt and MOUSE_click_RB(lvar.hdr_devicetxt) then
          SelectPrevDevice()
        elseif lvar.hdr_slottxt and MOUSE_click(lvar.hdr_slottxt) then
          SelectNextSlot()
        elseif lvar.hdr_slottxt and MOUSE_click_RB(lvar.hdr_slottxt) then
          SelectPrevSlot()
        elseif MOUSE_click(obj.sections[25]) then --prev
          SelectPrevDevice()
        elseif MOUSE_click(obj.sections[26]) then --next
          SelectNextDevice()
        elseif MOUSE_click(obj.sections[50]) then --prev
          SelectPrevSlot()
        elseif MOUSE_click(obj.sections[51]) then --next
          SelectNextSlot()
        elseif MOUSE_click(obj.sections[52]) then --autonext
          lvar.autonext = not lvar.autonext
          update_gfx = true
        elseif MOUSE_click(obj.sections[2]) then --type
          tdata.ptype = tdata.ptype + 1
          if tdata.ptype > ptype_cnt then
            tdata.ptype = 1
          end
          --[[if tdata.ptype == ptype.host and lvar.mode == 3 then
            tdata.ptype = ptype.cc
          end]]
          if tdata.ptype == ptype.cc then
            tdata.enc_res = 128
          else
            tdata.enc_res = 512          
          end
          if lvar.lmode == 4 then
            CalcButtStates()
          end
          PVReset()
          update_gfx = true
        elseif MOUSE_click_RB(obj.sections[2]) then --type
          tdata.ptype = tdata.ptype - 1
          if tdata.ptype < 1 then
            tdata.ptype = ptype_cnt
          end
          --[[if tdata.ptype == ptype.host and lvar.mode == 3 then
            tdata.ptype = ptype.internal
          end]]
          if tdata.ptype == ptype.cc then
            tdata.enc_res = 128
          else
            tdata.enc_res = 512          
          end
          if lvar.lmode == 4 then
            CalcButtStates()
          end
          PVReset()
          update_gfx = true
        elseif MOUSE_click(obj.sections[4]) then --rename

          local _, nm = reaper.GetUserInputs('Rename CC parameter',1,'Enter name:,extrawidth=100',tdata.name or '')
          if nm and nm ~= '' then
            tdata.name = nm
          else
            tdata.name = ''
          end
          update_gfx = true

        elseif MOUSE_click_RB(obj.sections[4]) then --clear rename
        
          tdata.name = nil
          update_gfx = true
        
        elseif MOUSE_click(obj.sections[5]) then 
        
          if lvar.lmode == 3 or lvar.lmode == 2 or lvar.lmode == 6 or lvar.lmode == 7 then --encoder
            tdata.enc_res = (round((tdata.enc_res or 512)/16)*16)*2
            if tdata.enc_res > 4096 then
              tdata.enc_res = 16
            end
            update_gfx = true
          elseif lvar.lmode == 4 then --buttype
            local bt = 1
            for i = 1, #tab_btntype do
              if tab_btntype[i].v == tdata.buttype then
                bt = i
                break
              end
            end
            bt = bt + 1
            if not tab_btntype[bt] then
              bt = 1
            end
            tdata.buttype = tab_btntype[bt].v
            CalcButtStates()
            update_gfx = true            
          end
          
        elseif MOUSE_click_RB(obj.sections[5]) then 
        
          if lvar.lmode == 3 or lvar.lmode == 2 or lvar.lmode == 6 or lvar.lmode == 7 then --encoder
            tdata.enc_res = (round((tdata.enc_res or 512)/16)*16)/2
            if tdata.enc_res < 16 then
              tdata.enc_res = 4096
            end
            update_gfx = true
          elseif lvar.lmode == 4 then --buttype
            local bt = 1
            for i = 1, #tab_btntype do
              if tab_btntype[i].v == tdata.buttype then
                bt = i
                break
              end
            end
            bt = bt - 1
            if not tab_btntype[bt] then
              bt = #tab_btntype
            end
            tdata.buttype = tab_btntype[bt].v
            CalcButtStates()
            update_gfx = true          
          end
        
        elseif MOUSE_click(obj.sections[6]) then 
          
          if lvar.lmode == 4 then --butstates
            if Internal_CanEdit() then
              if mouse.shift then
                if tdata.buttype == 4 then
                  local ret, st = reaper.GetUserInputs('Button States',1,'Number of states:',tdata.butstates or 2)
                  if ret and tonumber(st) then
                    tdata.butstates = F_limit(tonumber(st),1,32)
                    CalcButtStates2()
                    lvar.buttstates = true
                  end
                end
              else
                if tdata.buttype == 4 then
                  tdata.butstates = tdata.butstates + 1
                  CalcButtStates2()
                  lvar.buttstates = true
                end
              end
            end
            update_gfx = true
          elseif lvar.lmode == 0 or lvar.lmode == 2 or lvar.lmode == 3 or lvar.lmode == 6 or lvar.lmode == 7 then
            if tdata.ptype == ptype.host or tdata.ptype == ptype.track or tdata.ptype == ptype.cc then
              --ex automation
              tdata.exauto = 1-(tdata.exauto or 0)
              update_gfx = true
            end
          end

        elseif MOUSE_click_RB(obj.sections[6]) then 
          
          if lvar.lmode == 4 then --butstates
            if tdata.buttype == 4 and Internal_CanEdit() then
              tdata.butstates = math.max(tdata.butstates - 1,2)
              CalcButtStates2()
              lvar.buttstates = true
            end
            update_gfx = true            
          end

        elseif MOUSE_click(obj.sections[13]) then 

          if lvar.lmode == 4 then
            if Internal_CanEdit() == false and not mouse.ctrl then
              lvar.buttstates = false
            else
              lvar.buttstates = not lvar.buttstates
            end
            if not tdata.butstates_array or #tdata.butstates_array == 0 then
              CalcButtStates()
            end
            lvar.bsoffs = 0
            update_gfx = true
          end

        elseif MOUSE_click(obj.sections[7]) then

          if lvar.lmode == 4 then --monitor but val
            if tdata.ledon then
              tdata.ledon = nil
            else
              tdata.actionmon = 1-tdata.actionmon
              if tdata.actionmon == 0 then
                tdata.ledon = 1
              end
            end
            update_gfx = true
          end

        elseif MOUSE_click(obj.sections[80]) then
          local v = tdata.but_onval_override or -1
          if v == -1 then
            v = ""
          end
          local ret, val = reaper.GetUserInputs("Feedback 'on' value", 1, "On Value (0-127)", v)
          if ret then
            if tonumber(val) and (tonumber(val) >= 0 and tonumber(val) <= 127) then
              tdata.but_onval_override = tonumber(val)
            else
              tdata.but_onval_override = -1
            end
            update_gfx = true
          end
          
        elseif MOUSE_click(obj.sections[8]) then
          --lvar.gflag = lvar.gflag + 1
          --DBG(lvar.layer..'  '..lvar.gflag)
          local switch
          if lvar.gflag == 1 and lvar.layer > 0 then
            lvar.gflag = 4
          elseif lvar.gflag == 1 then
            lvar.gflag = 2
            switch = '2'
          elseif lvar.gflag == 2 then
            lvar.gflag = 3
          elseif lvar.gflag == 3 then
            lvar.gflag = 1
            switch = '2'
          elseif lvar.gflag == 4 then
            lvar.gflag = 2          
            switch = ''
          end
          --[[if tdata.ptype == ptype.host and (lvar.gflag ~= 1 and lvar.gflag ~= 4) then
            tdata.ptype = ptype.cc
          end]]
          --[[if lvar.gflag > 4 then
            lvar.gflag = 1
          end]]
          --lvar.gflag = math.min(lvar.gflag + 1,3)
          if not mouse.shift then
            reaper.SetExtState(SCRIPT, 'gflag', lvar.gflag, false)
            reaper.SetExtState(SCRIPT, 'selectslot', 0, false) 
            reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
          else
            if switch then
              lvar.foc_fx_trn = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_trn'..switch)) or -1
              lvar.foc_fx_num = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_num'..switch)) or -1
              lvar.foc_fx_guid = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_guid'..switch)) or -1
            end
            lvar.apply_dirty = true --doesn't work due to flag reset code
          end
          update_gfx = true
         
        elseif MOUSE_click_RB(obj.sections[8]) then
        
          local switch
          if lvar.gflag == 2 and lvar.layer > 0 then
            lvar.gflag = 4
            switch = '2'
          elseif lvar.gflag == 2 then
            lvar.gflag = 1
            switch = '2'
          elseif lvar.gflag == 1 then
            lvar.gflag = 3
            switch = ''
          elseif lvar.gflag == 3 then
            lvar.gflag = 2
          elseif lvar.gflag == 4 then
            lvar.gflag = 1          
          end
        
          if not mouse.shift then
            reaper.SetExtState(SCRIPT, 'gflag', lvar.gflag, false)
            reaper.SetExtState(SCRIPT, 'selectslot', 0, false)           
            reaper.SetExtState(SCRIPT, 'datadirty', 1, false)
          else
            if switch then
              lvar.foc_fx_trn = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_trn'..switch)) or -1
              lvar.foc_fx_num = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_num'..switch)) or -1
              lvar.foc_fx_guid = tonumber(reaper.GetExtState(SCRIPT, 'foc_fx_guid'..switch)) or -1
            end
            lvar.apply_dirty = true
          end
          update_gfx = true

        elseif MOUSE_click(obj.sections[9]) then
        
          reaper.SetExtState(SCRIPT, 'clearselfader', 0, false)           
          reaper.SetExtState(SCRIPT, 'datadirty', 1, false)

        elseif MOUSE_click(obj.sections[11]) then
          if mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.2 then
            if tdata.ptype == ptype.cc then
              tdata.defcc_val = nil
            else
              PVReset()
            end
            update_gfx = true
            
          elseif tdata.ptype == ptype.cc then
            if (tdata.ccnum or -1) ~= -1 then
              local gmem = reaper.gmem_read
              local def = tdata.defcc_val or gmem(lvar.gm_ccstamp.defcc_val+tdata.ccnum) or ''
              if (tonumber(def) or -1) == -1 then
                def = 0
              end
              local ret, defcc = reaper.GetUserInputs('Input CC value',1,'Value: ',tonumber(string.format('%i',def)))
              if ret and tonumber(defcc) then
                tdata.defcc_val = tonumber(defcc)
                if (reaper.gmem_read(lvar.gm_ccstamp.defcc_val+tdata.ccnum) or -1) == -1 then
                  reaper.gmem_write(lvar.gm_ccstamp.defcc_val+tdata.ccnum,tonumber(defcc))
                end
                update_gfx = true
              end
            end
          elseif tdata.ptype == ptype.host then
            if mouse.ctrl then 
              PV_GetVal()
            else
              mouse.context = contexts.printval
              local printval_adjust
              local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
              local GetParamNormalized, SetParamNormalized, GetFormattedParamValue
              if tdata.globalhost >= 1 then
                GetParamNormalized = reaper.TrackFX_GetParamNormalized
                SetParamNormalized = reaper.TrackFX_SetParamNormalized
                GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
                local track 
                if tdata.globalhost == 1 then
                  track = reaper.GetTrack(0, tdata.ptrack-1)
                else
                  track = reaper.GetSelectedTrack(0, 0)
                end
                printval_adjust = {val = tdata.printval or 0,
                                   my = mouse.my, track = track,
                                   fxnum = tdata.pfxnum, pnum = tdata.pnum,
                                   GetParamNormalized = GetParamNormalized,
                                   SetParamNormalized = SetParamNormalized,
                                   GetFormattedParamValue = GetFormattedParamValue}
              else
                if lvar.foc_fx_itemnum and lvar.foc_fx_itemnum ~= -1 then
                  local itmnum = lvar.foc_fx_itemnum
                  GetParamNormalized = reaper.TakeFX_GetParamNormalized
                  SetParamNormalized = reaper.TakeFX_SetParamNormalized
                  GetFormattedParamValue = reaper.TakeFX_GetFormattedParamValue
                  local item = reaper.GetTrackMediaItem(track, itmnum)
                  local take = reaper.GetActiveTake(item)
                  printval_adjust = {val = tdata.printval or 0,
                                     my = mouse.my, track = take,
                                     fxnum = lvar.foc_fx_num, pnum = tdata.pnum,
                                     GetParamNormalized = GetParamNormalized,
                                     SetParamNormalized = SetParamNormalized,
                                     GetFormattedParamValue = GetFormattedParamValue}
                else
                  GetParamNormalized = reaper.TrackFX_GetParamNormalized
                  SetParamNormalized = reaper.TrackFX_SetParamNormalized
                  GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
                  printval_adjust = {val = tdata.printval or 0,
                                     my = mouse.my, track = track,
                                     fxnum = lvar.foc_fx_num, pnum = tdata.pnum,
                                     GetParamNormalized = GetParamNormalized,
                                     SetParamNormalized = SetParamNormalized,
                                     GetFormattedParamValue = GetFormattedParamValue}
                end
              end
              printval_adjust.shift = mouse.shift
              local defval 
              if track then
                defval = GetParamNormalized(printval_adjust.track, printval_adjust.fxnum, printval_adjust.pnum)
                SetParamNormalized(printval_adjust.track, printval_adjust.fxnum, printval_adjust.pnum, tdata.min or 0)
                printval_adjust.defval = defval
              end
              lvar.printval_adjust = printval_adjust
            end
            
          elseif tdata.ptype == ptype.track then
            mouse.context = contexts.printval
            local printval_adjust
            local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
            lvar.printval_adjust = {val = tdata.printval or 0,
                                     my = mouse.my, track = track,
                                     }
            --lvar.printval_adjust = printval_adjust
          end
        elseif MOUSE_click_RB(obj.sections[11]) then
          if tdata.ptype == ptype.cc then
            if (tdata.ccnum or -1) ~= -1 then
              local gmem = reaper.gmem_read
              CCMenu(mouse.mx, mouse.my, tdata.defcc_val or -1)
            end          
          elseif tdata.ptype == ptype.host then
            PVMenu(mouse.mx, mouse.my, tdata.printval or -1)
          elseif tdata.ptype == ptype.track then
            PVMenu(mouse.mx, mouse.my, tdata.printval or -1)
          end
          
        elseif MOUSE_click(obj.sections[12]) and (lvar.sscolormode or tdata.ss_override) then
          if mouse.shift then
            local ss = tdata.sscolor
            if lvar.sscolormode == 1 then
              tdata.sscolor = (ss&7) + (((((ss&48)>>4)+1)%4)<<4)
            elseif lvar.sscolormode == 2 then
              tdata.sscolor = (ss&7) + (((((ss&48)>>4)+2)%4)<<4)
            end  
            update_gfx = true
          else
            local ss = tdata.sscolor
            tdata.sscolor = (((ss&7)+1)%8) + (ss&48)
            update_gfx = true
          end

        elseif MOUSE_click_RB(obj.sections[12]) and (lvar.sscolormode or tdata.ss_override) then
          if mouse.shift then
            local ss = tdata.sscolor
            if lvar.sscolormode == 1 then
              tdata.sscolor = (ss&7) + (((((ss&48)>>4)-1)%4)<<4)
            elseif lvar.sscolormode == 2 then
              tdata.sscolor = (ss&7) + (((((ss&48)>>4)-2)%4)<<4)
            end  
            update_gfx = true
          else
            local ss = tdata.sscolor
            tdata.sscolor = (((ss&7)-1)%8) + (ss&48)
            update_gfx = true
          end
          
        elseif MOUSE_click(obj.sections[14]) then
          --polarity
          tdata.polarity = 1 - tdata.polarity
          update_gfx = true

        elseif MOUSE_click(obj.sections[15]) then
          --scribble strip override
          SSMenu()

        elseif MOUSE_click(obj.sections[16]) then
          if lvar.lmode == 4 and (lvar.sscolormode or tdata.ss_override) then
            tdata.ss_override_sscolor = 1 - (tdata.ss_override_sscolor or 0)
            update_gfx = true
          elseif tdata.ptype == ptype.host then
            mouse.context = contexts.min
            local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
            local GetParamNormalized, SetParamNormalized, GetFormattedParamValue
            if tdata.globalhost >= 1 then
              GetParamNormalized = reaper.TrackFX_GetParamNormalized
              SetParamNormalized = reaper.TrackFX_SetParamNormalized
              GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
              if tdata.globalhost == 1 then
                track = reaper.GetTrack(0, tdata.ptrack-1)
              else
                track = reaper.GetSelectedTrack(0, 0)
              end
              --local track = reaper.GetTrack(0, tdata.ptrack-1)
              adjustmin = {val = tdata.min or 0, max = tdata.max or 1, maxdv = tdata.maxdv, 
                           my = mouse.my, track = track,
                           fxnum = tdata.pfxnum, pnum = tdata.pnum,
                           GetParamNormalized = GetParamNormalized,
                           SetParamNormalized = SetParamNormalized,
                           GetFormattedParamValue = GetFormattedParamValue}
            else
              if lvar.foc_fx_itemnum and lvar.foc_fx_itemnum ~= -1 then
                local itmnum = lvar.foc_fx_itemnum
                GetParamNormalized = reaper.TakeFX_GetParamNormalized
                SetParamNormalized = reaper.TakeFX_SetParamNormalized
                GetFormattedParamValue = reaper.TakeFX_GetFormattedParamValue
                local item = reaper.GetTrackMediaItem(track, itmnum)
                local take = reaper.GetActiveTake(item)
                adjustmin = {val = tdata.min or 0, max = tdata.max or 1, maxdv = tdata.maxdv, 
                             my = mouse.my, track = take,
                             fxnum = lvar.foc_fx_num, pnum = tdata.pnum,
                             GetParamNormalized = GetParamNormalized,
                             SetParamNormalized = SetParamNormalized,
                             GetFormattedParamValue = GetFormattedParamValue}
              else
                GetParamNormalized = reaper.TrackFX_GetParamNormalized
                SetParamNormalized = reaper.TrackFX_SetParamNormalized
                GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
                adjustmin = {val = tdata.min or 0, max = tdata.max or 1, maxdv = tdata.maxdv, 
                             my = mouse.my, track = track,
                             fxnum = lvar.foc_fx_num, pnum = tdata.pnum,
                             GetParamNormalized = GetParamNormalized,
                             SetParamNormalized = SetParamNormalized,
                             GetFormattedParamValue = GetFormattedParamValue}
              end
            end
            adjustmin.shift = mouse.shift
            local defval 
            if track then
              defval = GetParamNormalized(adjustmin.track, adjustmin.fxnum, adjustmin.pnum)
              SetParamNormalized(adjustmin.track, adjustmin.fxnum, adjustmin.pnum, tdata.min or 0)
              adjustmin.defval = defval
            end
          end

        elseif MOUSE_click(obj.sections[17]) then
          if lvar.lmode == 4 then
            tdata.ss_override_name = 1 - (tdata.ss_override_name or 0)
            update_gfx = true
          elseif tdata.ptype == ptype.host then
            mouse.context = contexts.max
            local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
            local GetParamNormalized, SetParamNormalized, GetFormattedParamValue
            if tdata.globalhost >= 1 then
              GetParamNormalized = reaper.TrackFX_GetParamNormalized
              SetParamNormalized = reaper.TrackFX_SetParamNormalized
              GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
              if tdata.globalhost == 1 then
                track = reaper.GetTrack(0, tdata.ptrack-1)
              else
                track = reaper.GetSelectedTrack(0, 0)
              end
              --local track = reaper.GetTrack(0, tdata.ptrack-1)
              adjustmax = {val = tdata.max or 1, min = tdata.min or 0, mindv = tdata.mindv, 
                           my = mouse.my, track = track,
                           fxnum = tdata.pfxnum, pnum = tdata.pnum,
                           GetParamNormalized = GetParamNormalized,
                           SetParamNormalized = SetParamNormalized,
                           GetFormattedParamValue = GetFormattedParamValue}
            else
              if lvar.foc_fx_itemnum and lvar.foc_fx_itemnum ~= -1 then
                local itmnum = lvar.foc_fx_itemnum
                GetParamNormalized = reaper.TakeFX_GetParamNormalized
                SetParamNormalized = reaper.TakeFX_SetParamNormalized
                GetFormattedParamValue = reaper.TakeFX_GetFormattedParamValue
                local item = reaper.GetTrackMediaItem(track, itmnum)
                local take = reaper.GetActiveTake(item)
                adjustmax = {val = tdata.max or 1, min = tdata.min or 0, mindv = tdata.mindv, 
                             my = mouse.my, track = take,
                             fxnum = lvar.foc_fx_num, pnum = tdata.pnum,
                             GetParamNormalized = GetParamNormalized,
                             SetParamNormalized = SetParamNormalized,
                             GetFormattedParamValue = GetFormattedParamValue}
              else
                GetParamNormalized = reaper.TrackFX_GetParamNormalized
                SetParamNormalized = reaper.TrackFX_SetParamNormalized
                GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
                adjustmax = {val = tdata.max or 1, min = tdata.min or 0, mindv = tdata.mindv, 
                             my = mouse.my, track = track,
                             fxnum = lvar.foc_fx_num, pnum = tdata.pnum,
                             GetParamNormalized = GetParamNormalized,
                             SetParamNormalized = SetParamNormalized,
                             GetFormattedParamValue = GetFormattedParamValue}
              end
            end
            adjustmax.shift = mouse.shift
            local defval 
            if track then 
              defval = GetParamNormalized(adjustmax.track, adjustmax.fxnum, adjustmax.pnum)
              SetParamNormalized(adjustmax.track, adjustmax.fxnum, adjustmax.pnum, tdata.max or 1)
              adjustmax.defval = defval
            end
          end

        elseif MOUSE_click(obj.sections[18]) then
          if lvar.lmode == 4 then
            VTMenu()
          end          

        elseif MOUSE_click(obj.sections[19]) then
          if lvar.lmode == 4 then
            tdata.linkonly = not tdata.linkonly
            if tdata.linkonly then
              tdata.linkA_linkonly = tdata.linkA or tdata.linkA_linkonly
              tdata.linkA = nil
            else
              tdata.linkA = tdata.linkA_linkonly or tdata.linkA
              tdata.linkA_linkonly = nil
            end
            update_gfx = true
          end
          
        elseif MOUSE_click(obj.sections[20]) then
          if lvar.lmode == 4 then
            if (tdata.linkB or -1) == -1 then
              if mouse.ctrl --[[mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.2]] then
                local link = tdata.linkA or tdata.linkA_linkonly
                if link then
                  if lvar.sharedata[link] then
                    local fader_idx = lvar.sharedata[link].fader
                    SelectSlotByName(nil, link)
                  end
                end
              else
                ShareMenu()
              end
            else
              --jump to control here?
              if mouse.ctrl --[[mouse.lastLBclicktime and (rt-mouse.lastLBclicktime) < 0.2]] then
                if lvar.sharedata[tdata.linkB] then
                  local fader_idx = lvar.sharedata[tdata.linkB].fader
                  SelectSlotByName(nil, tdata.linkB)
                end
              end
            end
          end

        elseif MOUSE_click(obj.sections[21]) then
          if lvar.lmode == 4 and not tdata.linkonly then
            if (tdata.linkA or -1) ~= -1 then
              if (tdata.linkA_mode or 1) == 1 then
                tdata.linkA_mode = 2
              else
                tdata.linkA_mode = 1
              end
            end
          end
          update_gfx = true

        elseif MOUSE_click(obj.sections[22]) then
          if lvar.lmode == 4 and not tdata.linkonly then
            if (tdata.linkA or -1) ~= -1 then
              if (tdata.linkB_mode or 1) == 1 then
                tdata.linkB_mode = 2
              else
                tdata.linkB_mode = 1
              end
            end
          end
          update_gfx = true
          
        elseif MOUSE_click(obj.sections[1000]) then
          GUI_FlashButton(obj, gui, 1000, 'COPY', 0.1, gui.color.white)
          Copy()
          
          --[[local mstr = 'Copy||Paste'
          gfx.x = mouse.mx
          gfx.y = mouse.my
          local res = gfx.showmenu(mstr)
          if res > 0 then
            if res == 1 then
              Copy()
            elseif res == 2 then
              Paste()
            end
          end]]

        elseif MOUSE_click(obj.sections[1001]) then
          GUI_FlashButton(obj, gui, 1001, 'PASTE', 0.1, gui.color.white)
          Paste()

        elseif adjustmin then
          if adjustmin.defval then
            adjustmin.SetParamNormalized(adjustmin.track, adjustmin.fxnum, adjustmin.pnum, adjustmin.defval)
          end
          --tdata.mindv = adjustmin.mindv
          adjustmin = nil

        elseif adjustmax then
          if adjustmax.defval then
            adjustmax.SetParamNormalized(adjustmax.track, adjustmax.fxnum, adjustmax.pnum, adjustmax.defval)
          end
          --tdata.mindv = adjustmin.mindv
          adjustmax = nil

        elseif lvar.printval_adjust then
          if lvar.printval_adjust.defval then
            lvar.printval_adjust.SetParamNormalized(lvar.printval_adjust.track, lvar.printval_adjust.fxnum, lvar.printval_adjust.pnum, lvar.printval_adjust.defval)
          end
          lvar.printval_adjust = nil
        end
      end
          
    else
    
      if mouse.context == contexts.resize_l then
      
        local dx = reaper.GetMousePosition()-lvar.resize.x
        if dx ~= lvar.resize.o then
          lvar.resize.o = dx
          local hwnd = lvar.resize.hwnd
          --local hwnd = reaper.JS_Window_Find("SK2 FADER PROPERTIES", true)
          if hwnd then
            local nw = lvar.resize.o_r-lvar.resize.o_l-dx
            --reaper.JS_Window_Resize(hwnd, nw, lvar.resize.o_b-lvar.resize.o_t)
            reaper.JS_Window_SetPosition(hwnd, lvar.resize.o_l+dx, lvar.resize.o_t, nw, lvar.resize.o_b-lvar.resize.o_t)
            resize_display = true
            update_gfx = true
            GUI_draw(obj, gui)
            --reaper.JS_Window_Move(hwnd, lvar.resize.o_l+dx, lvar.resize.o_t)
            
          end
        end
      
      elseif mouse.context == contexts.movesplit then
        
        local dy = lvar.movesplit.y - mouse.my
        lvar.splith = lvar.movesplit.splith + dy
        local limit = 146
        --lvar.splith = F_limit(lvar.splith, limit, (gfx1.main_h - 8 - butt_h*2) -limit)

        obj = GetObjects()
        update_gfx = true
        
      elseif mouse.context == contexts.sbar_trk then
        local data = lvar.hscrollb
        if mouse.mx > data.mx+5 or mouse.mx < data.mx-5 then
          mouse.context = contexts.sbar_trk2
        end
        
      elseif mouse.context == contexts.sbar_trk2 then
      
        local data = lvar.hscrollb
        local x = mouse.mx - obj.sections[303].x
        local p = math.max(math.floor((x) / data.pp),0)
        lvar.listoff_trk_trk = F_limit(p*data.rows,0,math.max((math.ceil(data.pcnt/data.rows)-data.cols)*data.rows,0))
        update_gfx = true

      elseif mouse.context == contexts.printval then

        local div = 400
        local pv = lvar.printval_adjust
        if mouse.shift then
          if mouse.shift ~= pv.shift then
            pv.shift = mouse.shift
            pv.val = tdata.printval or 0
            pv.my = mouse.my
          end
          div = 4000
        else
          if mouse.shift ~= pv.shift then
            pv.shift = mouse.shift
            pv.val = tdata.printval or 0
            pv.my = mouse.my
          end
        end
        if pv.val then
          local nv = F_limit(pv.val - ((mouse.my - pv.my) / div),0,1)
          local opv = tdata.printval
          local odv = tdata.printvaldv
          if tdata.printval ~= nv then
            tdata.printval = nv
          end
          if tdata.ptype == ptype.host then
            if pv.defval then
              pv.SetParamNormalized(pv.track, pv.fxnum, pv.pnum, nv)
              _, tdata.printvaldv = pv.GetFormattedParamValue(pv.track, pv.fxnum, pv.pnum, '')
            end
          elseif tdata.ptype == ptype.track then
            if (tdata.trparam or -1) ~= -1 then
              local data = track_info[tab_trparams_code[tdata.trparam]]
              local nvv = data.min + (nv * (data.max - data.min))
              --tdata.printval = nvv
              if data.conv then
                tdata.printvaldv = data.conv('', nvv)
              end
            end
            --DBG(reaper.GetMediaTrackInfo_Value(pv.track,'IP_TRACKNUMBER'))
          end
          if opv ~= nv or odv ~= tdata.printvaldv then
            update_gfx = true
          end
        end
        
      elseif mouse.context == contexts.min then
      
        local div = 400
        if mouse.shift then
          if mouse.shift ~= adjustmin.shift then
            adjustmin.shift = mouse.shift
            adjustmin.val = tdata.min
            adjustmin.my = mouse.my
          end
          div = 4000
        else
          if mouse.shift ~= adjustmin.shift then
            adjustmin.shift = mouse.shift
            adjustmin.val = tdata.min
            adjustmin.my = mouse.my
          end
        end
        local nv = F_limit(adjustmin.val - ((mouse.my - adjustmin.my) / div),0,1)
        local omin = tdata.min
        local odv = tdata.mindv
        if tdata.min ~= nv then
          tdata.min = nv
          if adjustmin.max < tdata.min then
            tdata.max = tdata.min
          else
            tdata.max = adjustmin.max
          end
        end
        if adjustmin.defval then
          adjustmin.SetParamNormalized(adjustmin.track, adjustmin.fxnum, adjustmin.pnum, nv)
          _, tdata.mindv = adjustmin.GetFormattedParamValue(adjustmin.track, adjustmin.fxnum, adjustmin.pnum, '')
          if adjustmin.max < tdata.min then
            tdata.maxdv = tdata.mindv
          else
            tdata.maxdv = adjustmin.maxdv
          end
        end
        if omin ~= nv or odv ~= tdata.mindv then
          update_gfx = true
        end

      elseif mouse.context == contexts.max then
      
        local div = 400
        if mouse.shift then
          if mouse.shift ~= adjustmax.shift then
            adjustmax.shift = mouse.shift
            adjustmax.val = tdata.max
            adjustmax.my = mouse.my
          end
          div = 4000
        else
          if mouse.shift ~= adjustmax.shift then
            adjustmax.shift = mouse.shift
            adjustmax.val = tdata.max
            adjustmax.my = mouse.my
          end
        end
        local nv = F_limit(adjustmax.val - ((mouse.my - adjustmax.my) / div),0,1)
        local omax = tdata.max
        local odv = tdata.maxdv
        if tdata.max ~= nv then
          tdata.max = nv
          if adjustmax.min > tdata.max then
            tdata.min = tdata.max
          else
            tdata.min = adjustmax.min
          end
        end
        if adjustmax.defval then
          adjustmax.SetParamNormalized(adjustmax.track, adjustmax.fxnum, adjustmax.pnum, nv)
          _, tdata.maxdv = adjustmax.GetFormattedParamValue(adjustmax.track, adjustmax.fxnum, adjustmax.pnum, '')
          if adjustmax.min > tdata.max then
            tdata.mindv = tdata.maxdv
          else
            tdata.mindv = adjustmax.mindv
          end
        end
        if omax ~= nv or odv ~= tdata.maxdv then
          update_gfx = true
        end
        
      end
    
    end    
    
    -------------------------------------------
      
    if not mouse.LB and not mouse.RB then mouse.context = nil end
    local char = gfx.getchar() 
    if char then 
      if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end
      if char>=0 and char~=27 then reaper.defer(run) end
    else
      reaper.defer(run)
    end
    gfx.update()
    mouse.last_LB = mouse.LB
    mouse.last_RB = mouse.RB
    mouse.last_x = mouse.mx
    mouse.last_y = mouse.my
    if mouse.LB then
      mouse.lastLBclicktime = rt
    end
    gfx.mouse_wheel = 0
    
    if refresh_gfx and mouse.context == nil and reaper.time_precise() >= refresh_gfx then
      refresh_gfx = nil
      update_gfx = true
    end
    
    if not CompareData() then
      if not lvar.apply_dirty then
        lvar.apply_dirty = true
        update_gfx = true
      end
    else
      if lvar.apply_dirty then
        lvar.apply_dirty = false
        update_gfx = true
      end
    end
    
  end
  
  function CCMenu(x,y,v)
  
    local mstr = 'Clear||Set As Default|'
    for i = 0, 127 do
      local tk = ''
      if i == v then tk = '!' end
      if i % 32 == 0 then
        mstr = mstr .. '|>'..string.format('%i',i)..' - '.. string.format('%i',(i/32)*32 +31)..'|'..tk.. string.format('%i',i)
      elseif i % 32 == 31 then
        mstr = mstr .. '|'..'<'..tk ..string.format('%i',i)
      else
        mstr = mstr ..'|'..tk..string.format('%i',i)
      end
    end
    
    gfx.x, gfx.y = x,y
    local res = gfx.showmenu(mstr)
    if res and res > 0 then
      if res == 1 then
        tdata.defcc_val = nil
      elseif res == 2 then
        reaper.gmem_write(lvar.gm_ccstamp.defcc_val+tdata.ccnum,tonumber(tdata.defcc_val) or -1)      
      else
        tdata.defcc_val = res-3
        if (reaper.gmem_read(lvar.gm_ccstamp.defcc_val+tdata.ccnum) or -1) == -1 then
          reaper.gmem_write(lvar.gm_ccstamp.defcc_val+tdata.ccnum,tonumber(res-3))
        end
      end
      update_gfx = true
    end
    
  end

  function PV_GetDV() 
    if tdata.ptype == ptype.host then
      local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
      local fxnum, pnum
      local GetParamNormalized, SetParamNormalized, GetFormattedParamValue
      if tdata.globalhost >= 1 then
        GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
        GetParamNormalized = reaper.TrackFX_GetParamNormalized
        SetParamNormalized = reaper.TrackFX_SetParamNormalized
        if tdata.globalhost == 1 then
          track = reaper.GetTrack(0, tdata.ptrack-1)
        else
          track = reaper.GetSelectedTrack(0, 0)
        end
        fxnum = tdata.pfxnum
        pnum = tdata.pnum
      else
        if lvar.foc_fx_itemnum and lvar.foc_fx_itemnum ~= -1 then
          local itmnum = lvar.foc_fx_itemnum
          GetFormattedParamValue = reaper.TakeFX_GetFormattedParamValue
          GetParamNormalized = reaper.TakeFX_GetParamNormalized
          SetParamNormalized = reaper.TakeFX_SetParamNormalized
          local item = reaper.GetTrackMediaItem(track, itmnum)
          local take = reaper.GetActiveTake(item)
          fxnum = lvar.foc_fx_num
          pnum = tdata.pnum
        else
          GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
          GetParamNormalized = reaper.TrackFX_GetParamNormalized
          SetParamNormalized = reaper.TrackFX_SetParamNormalized
          fxnum = lvar.foc_fx_num
          pnum = tdata.pnum
        end
      end
      
      local val = GetParamNormalized(track, fxnum, pnum)
      SetParamNormalized(track, fxnum, pnum, tdata.printval)
      local _, dv = GetFormattedParamValue(track, fxnum, pnum, '')
      SetParamNormalized(track, fxnum, pnum, val)
      tdata.printvaldv = dv
      
    elseif tdata.ptype == ptype.track then
      local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
      if (tdata.trparam or -1) ~= -1 then
        local data = track_info[tab_trparams_code[tdata.trparam]]
        local nvv = data.min + (tdata.printval * (data.max - data.min))
        --tdata.printval = nvv
        if data.conv then
          tdata.printvaldv = data.conv('', nvv)
        end
      end
    end
  end

  function PV_GetVal()
    if tdata.ptype == ptype.host then

      local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
      local fxnum, pnum
      local GetParamNormalized, SetParamNormalized, GetFormattedParamValue
      if tdata.globalhost >= 1 then
        GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
        GetParamNormalized = reaper.TrackFX_GetParamNormalized
        SetParamNormalized = reaper.TrackFX_SetParamNormalized
        if tdata.globalhost == 1 then
          track = reaper.GetTrack(0, tdata.ptrack-1)
        else
          track = reaper.GetSelectedTrack(0, 0)
        end
        fxnum = tdata.pfxnum
        pnum = tdata.pnum
      else
        if lvar.foc_fx_itemnum and lvar.foc_fx_itemnum ~= -1 then
          local itmnum = lvar.foc_fx_itemnum
          GetFormattedParamValue = reaper.TakeFX_GetFormattedParamValue
          GetParamNormalized = reaper.TakeFX_GetParamNormalized
          SetParamNormalized = reaper.TakeFX_SetParamNormalized
          local item = reaper.GetTrackMediaItem(track, itmnum)
          local take = reaper.GetActiveTake(item)
          fxnum = lvar.foc_fx_num
          pnum = tdata.pnum
        else
          GetFormattedParamValue = reaper.TrackFX_GetFormattedParamValue
          GetParamNormalized = reaper.TrackFX_GetParamNormalized
          SetParamNormalized = reaper.TrackFX_SetParamNormalized
          fxnum = lvar.foc_fx_num
          pnum = tdata.pnum
        end
      end
      
      local val = GetParamNormalized(track, fxnum, pnum)
      local _, dv = GetFormattedParamValue(track, fxnum, pnum, '')
      tdata.printval = val
      tdata.printvaldv = dv
      
      update_gfx = true
      
    elseif tdata.ptype == ptype.track then
      local track = reaper.GetTrack(0, lvar.foc_fx_trn-1)
      if (tdata.trparam or -1) ~= -1 then

      end
    end
  end
  
  function PVReset()
    tdata.printval = nil
    tdata.printvaldv = nil
  end

  function PVMenu(x,y,v)
  
    local mstr = 'Clear||#Set As Default'
    
    gfx.x, gfx.y = x,y
    local res = gfx.showmenu(mstr)
    if res and res > 0 then
      if res == 1 then
        tdata.printval = nil
        tdata.printvaldv = nil
        
      elseif res == 2 then
      else
      end
      update_gfx = true
    end
    
  end
  
  function quit()

    SaveSettings()      
    reaper.DeleteExtState(SCRIPT, 'IsOpen', false)
    reaper.gmem_write(lvar.props.visible,0)
    
    gfx.quit()
    
  end
  
  function GES(key, nilallowed)
    if nilallowed == nil then nilallowed = false end
    
    local val = reaper.GetExtState(SCRIPT,key)
    if nilallowed then
      if val == '' then
        val = nil
      end
    end
    return val
  end
  
  function LoadColors()
  
    local fn = paths.resource_path..'colors.txt'
    if reaper.file_exists(fn) then
    
      data = {}
      for line in io.lines(fn) do
        local idx, val = string.match(line,'%[(.-)%](.*)') --decipher(line)
        if idx then
          data[idx] = val
        end
      end
    
      for i = 1, #ptype_info do
        local key = string.format('%i',i)
        if data[key] then
          ptype_info[i].col = data[key]
        end
        if data[key..'T'] then
          ptype_info[i].btntxt = data[key..'T']
        end
      end
      local c = data['globalfader']
      if c then
        colours.globalfader = c
      end
      local c = data['globalfaderT']
      if c then
        colours.globalfader_txt = c
      end

      local c = data['permafader']
      if c then
        colours.permafader = c
      end
      local c = data['permafaderT']
      if c then
        colours.permafader_txt = c
      end

      local c = data['layerfader']
      if c then
        colours.layerfader = c
      end
      local c = data['layerfaderT']
      if c then
        colours.layerfader_txt = c
      end

      local c = data['mainfader']
      if c then
        colours.mainfader = c
      end
      local c = data['mainfaderT']
      if c then
        colours.mainfader_txt = c
      end

      local c = data['mainbg']
      if c then
        colours.mainbg = c
      end

      local c = data['buttcol']
      if c then
        colours.buttcol = c
        colours.sectionline = c
      end
      local c = data['buttcollit']
      if c then
        colours.buttcollit = c
        colours.modebtnhl = c
      end

      local c = data['devctlunassigned']
      if c then
        colours.devctlunassigned = c
      end
      local c = data['devctlname']
      if c then
        colours.devctlname = c
      end
      local c = data['devctlassigned']
      if c then
        colours.devctlassigned = c
      end

      local c = data['faderunassigned']
      if c then
        colours.faderunassigned = c
      end
      local c = data['faderunassignedT']
      if c then
        colours.faderunassigned_txt = c
      end
      local c = data['faderbg2']
      if c then
        colours.faderbg2 = c
      end
      local c = data['faderborder']
      if c then
        colours.faderborder = c
      end
      local c = data['ibox']
      if c then
        colours.ibox = c
      end
      local c = data['iboxT']
      if c then
        colours.iboxT = c
        --tab_amcol[1] = c
      end
        
    end
  
  end
  
  function SaveSettings()
  
    a,x,y,w,h = gfx.dock(-1,1,1,1,1)
    if gfx1 then
      reaper.SetExtState(SCRIPT,'dock',nz(a,0),true)
      reaper.SetExtState(SCRIPT,'win_x',nz(x,0),true)
      reaper.SetExtState(SCRIPT,'win_y',nz(y,0),true)    
      reaper.SetExtState(SCRIPT,'win_w',nz(gfx1.main_w,400),true)
      reaper.SetExtState(SCRIPT,'win_h',nz(gfx1.main_h,580),true)
      reaper.SetExtState(SCRIPT,'splith',nz(lvar.splith,300),true)
      reaper.SetExtState(SCRIPT,'butth',nz(lvar.butt_h,24),true)
      reaper.SetExtState(SCRIPT,'fadjust',nz(lvar.fadjust,0),true)
      
      reaper.SetExtState(SCRIPT,'autonext',tostring(lvar.autonext),true)
      reaper.SetExtState(SCRIPT,'ic_autocollapse',tostring(lvar.ic_autocollapse),true)
      
      reaper.SetExtState(SCRIPT,'dev_borderctls',tostring(lvar.dev_borderctls),true)
      reaper.SetExtState(SCRIPT,'dev_borderctls_col',lvar.dev_borderctls_col or '',true)

      reaper.SetExtState(SCRIPT,'highlight_perm',tostring(lvar.highlight_perm),true)
    end
  
  end
  
  function LoadSettings()
  
    lvar.butt_h = GES('butth',true) or 22
    lvar.fadjust = GES('fadjust',true) or 0
    local x, y = GES('win_x',true), GES('win_y',true)
    local ww, wh = GES('win_w',true), GES('win_h',true)
    lvar.splith = tonumber(GES('splith',true))
    local d = GES('dock',true)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if d == nil then d = gfx.dock(-1) end    
    if ww ~= nil and wh ~= nil then
      gfx1 = {main_w = tonumber(ww),
              main_h = tonumber(wh)}
      gfx.init("SK2 FADER PROPERTIES", gfx1.main_w, gfx1.main_h, 0, x, y)
      gfx.dock(d)
    else
      gfx1 = {main_w = 400, main_h = 580}
      Lokasenna_Window_At_Center(gfx1.main_w,gfx1.main_h)  
    end
    
    if lvar.attach == 1 then
      local hwnd = reaper.JS_Window_Find("SK2 FADER PROPERTIES", true)
      local hwndsk2 = reaper.JS_Window_Find("SRD SMART CONTROL", true)
      if hwndsk2 then
        reaper.JS_Window_SetStyle(hwnd, 'POPUP')
        local ret, sk2_l, sk2_t, sk2_r, sk2_b = reaper.JS_Window_GetRect(hwndsk2)
        local ret, l, t, r, b = reaper.JS_Window_GetRect(hwnd)
        local ww, hh = r-l, sk2_b-sk2_t
        reaper.JS_Window_SetPosition(hwnd, sk2_l-ww, sk2_t, ww, hh)
      end
    end

    lvar.autonext = tobool(zn(GES('autonext',true),true))
    lvar.ic_autocollapse = tobool(zn(GES('ic_autocollapse',true),lvar.ic_autocollapse))
    lvar.dev_borderctls = tobool(zn(GES('dev_borderctls',true),false))
    lvar.dev_borderctls_col = zn(GES('dev_borderctls_col',true))
    lvar.highlight_perm = tobool(zn(GES('highlight_perm',true),true))
    lvar.aot = tobool(zn(GES('aot',false),false))
    lvar.fontoffset = tonumber(reaper.GetExtState(SKSCRIPT,'fontoffset')) or 0
    
  end
  
  
  ------------------------------------------------------------
  
  reaper.gmem_attach('LBX_SK2_SharedMem')
  
  paths.resource_path = reaper.GetResourcePath().."/Scripts/LBX/SmartKnobs2_DATA/"
  paths.ctemplate_path = paths.resource_path.."controller_maps/"
  
  reaper.gmem_write(lvar.props.visible,1)
  
  LoadColors()
  LoadSettings()
  
  SetTrackSendTab()
  Internal_GenIdx()
  
  IC_SecVis_Init()
  
  reaper.SetExtState(SCRIPT, 'IsOpen', 1, false)
  
  if reaper.APIExists('JS_Window_GetFocus') then
    lvar.js_avail = true
  end
  
  LoadCopy()
  
  if lvar.aot then
    hwnd = reaper.JS_Window_Find('SK2 FADER PROPERTIES', true)
    if hwnd then
      reaper.JS_Window_SetZOrder(hwnd, 'TOPMOST', hwnd)
    end
  end
    
  run()
  reaper.atexit(quit)
  
  ------------------------------------------------------------
