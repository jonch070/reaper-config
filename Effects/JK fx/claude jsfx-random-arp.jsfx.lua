desc: Humanized Non-Repeating Random MIDI Arpeggiator [DEBUG BUILD]
//tags: MIDI processing
//author: Assistant

slider1:11<0,20,1{Custom,1/32T,1/32,1/32.,1/16T,1/16,1/16.,1/8T,1/8,1/8.,1/4T,1/4,1/4.,1/2T,1/2,1/2.,1T,1,1.,2T,2}>Speed Preset
slider2:4<0.001,128,0.001>Custom Speed (1/x notes)
slider3:80<0,100,1>Gate Length (%)
slider4:0<0,100,1>Random Gate (±%)

slider10:4<1,16,1>Note History Lockout (steps)
slider11:4<1,16,1>Channel History Lockout (steps)

slider15:1<1,16,1>MIDI Channel Start
slider16:1<1,16,1>Number of Channels
slider17:0<0,1,1{Off,On}>Enable Channel Randomization

slider20:100<0,127,1>Base Velocity
slider21:20<0,100,1>Velocity Randomization (±%)
slider22:5<0,50,1>Timing Jitter (ms)

slider30:0<0,1,1{Off,On}>Hold Mode (latch notes)
slider31:1<0,2,1{Off,GUI Only,Console Output}>Debug Mode

in_pin:none
out_pin:none

@init

// Debug log buffer
debug_buf = 10000;
debug_idx = 0;
debug_line = 0;

// Debug function
function debug_log(msg) (
  slider31 > 0 ? (
    debug_buf[debug_idx] = msg;
    debug_idx = (debug_idx + 1) % 100;
    slider31 == 2 ? (
      printf("%d: %d\n", debug_line, msg);
      debug_line += 1;
    );
  );
);

// Constants
MAX_NOTES = 128;
MAX_HISTORY = 16;

// Note buffer
notelist = 1000;

// History buffers
note_history = 2000;
note_history_pos = 0;
note_history_count = 0;

channel_history = 3000;
channel_history_pos = 0;
channel_history_count = 0;

// Timing
dinc = 0;
pbincpos = 0;
gate_pos = 0;

playing_note = -1;
playing_channel = -1;
playing_vel = 0;

last_note_time = 0;
note_count_tracker = 0;

// Random seed
rand_seed = 12345;

// Initialize note list
i = 0;
loop(MAX_NOTES,
  notelist[i] = 0;
  i += 1;
);

debug_log(1000); // Init complete marker

// Function: Better random
function my_rand() (
  rand_seed = (rand_seed * 1103515245 + 12345) & 0x7FFFFFFF;
  rand_seed / 0x7FFFFFFF;
);

// Function: Random int range
function rand_range(min_val, max_val) (
  min_val + floor(my_rand() * (max_val - min_val + 1));
);

// Function: Check note in history
function note_in_history(note, lookback) local(i, idx) (
  i = 0;
  loop(min(lookback, note_history_count),
    idx = (note_history_pos - 1 - i + MAX_HISTORY) % MAX_HISTORY;
    note_history[idx] == note ? return 1;
    i += 1;
  );
  0;
);

// Function: Check channel in history
function channel_in_history(chan, lookback) local(i, idx) (
  i = 0;
  loop(min(lookback, channel_history_count),
    idx = (channel_history_pos - 1 - i + MAX_HISTORY) % MAX_HISTORY;
    channel_history[idx] == chan ? return 1;
    i += 1;
  );
  0;
);

// Function: Add to note history
function add_note_to_history(note) (
  note_history[note_history_pos] = note;
  note_history_pos = (note_history_pos + 1) % MAX_HISTORY;
  note_history_count = min(note_history_count + 1, MAX_HISTORY);
  debug_log(3000 + note); // Note added to history
);

// Function: Add to channel history
function add_channel_to_history(chan) (
  channel_history[channel_history_pos] = chan;
  channel_history_pos = (channel_history_pos + 1) % MAX_HISTORY;
  channel_history_count = min(channel_history_count + 1, MAX_HISTORY);
  debug_log(4000 + chan); // Channel added to history
);

// Function: Count active notes
function count_notes() local(cnt, i) (
  cnt = 0;
  i = 0;
  loop(MAX_NOTES,
    notelist[i] > 0 ? cnt += 1;
    i += 1;
  );
  cnt;
);

// Function: Select random note with lockout
function select_random_note() local(note, tries, found) (
  found = 0;
  tries = 0;
  
  debug_log(5000); // Starting note selection
  
  // Try to find note not in history
  loop(100,
    note = rand_range(0, 127);
    notelist[note] > 0 && !note_in_history(note, slider10) ? (
      found = 1;
      debug_log(5100 + note); // Found valid note
      return note;
    );
    tries += 1;
  );
  
  // Fallback: any active note
  !found ? (
    debug_log(5200); // Using fallback
    loop(128,
      note = rand_range(0, 127);
      notelist[note] > 0 ? (
        found = 1;
        debug_log(5300 + note); // Fallback note selected
        return note;
      );
    );
  );
  
  debug_log(5999); // No note found!
  -1;
);

// Function: Select random channel
function select_random_channel() local(chan, max_chan) (
  slider17 > 0.5 ? (
    max_chan = min(slider15 + slider16 - 1, 16);
    
    loop(50,
      chan = rand_range(slider15, max_chan);
      !channel_in_history(chan, slider11) ? (
        debug_log(6000 + chan); // Channel selected
        return chan;
      );
    );
    
    chan = rand_range(slider15, max_chan);
    debug_log(6100 + chan); // Fallback channel
    chan;
  ) : (
    debug_log(6200 + slider15); // Fixed channel
    slider15;
  );
);

// Function: Get speed from preset or custom
function get_active_speed() (
  slider1 == 0 ? (
    max(0.001, slider2);
  ) : slider1 == 1 ? (
    48; // 1/32T
  ) : slider1 == 2 ? (
    32; // 1/32
  ) : slider1 == 3 ? (
    21.333; // 1/32.
  ) : slider1 == 4 ? (
    24; // 1/16T
  ) : slider1 == 5 ? (
    16; // 1/16
  ) : slider1 == 6 ? (
    10.667; // 1/16.
  ) : slider1 == 7 ? (
    12; // 1/8T
  ) : slider1 == 8 ? (
    8; // 1/8
  ) : slider1 == 9 ? (
    5.333; // 1/8.
  ) : slider1 == 10 ? (
    6; // 1/4T
  ) : slider1 == 11 ? (
    4; // 1/4
  ) : slider1 == 12 ? (
    2.667; // 1/4.
  ) : slider1 == 13 ? (
    3; // 1/2T
  ) : slider1 == 14 ? (
    2; // 1/2
  ) : slider1 == 15 ? (
    1.333; // 1/2.
  ) : slider1 == 16 ? (
    1.5; // 1T
  ) : slider1 == 17 ? (
    1; // 1
  ) : slider1 == 18 ? (
    0.667; // 1.
  ) : slider1 == 19 ? (
    0.75; // 2T
  ) : (
    0.5; // 2
  );
);

@slider

active_speed = get_active_speed();

// Update custom slider to show preset value
slider1 > 0 ? slider2 = active_speed;

rate = active_speed;
notelen = slider3 / 100;
notelen = max(0.01, min(0.99, notelen));

debug_log(7000 + rate); // Speed changed

@block

notecnt = count_notes();
lastnotecnt = notecnt;

debug_log(8000 + notecnt); // Block start, note count

// Process MIDI
midi_count = 0;
while (
  midirecv(ts, msg1, msg23) ? (
    midi_count += 1;
    m = msg1 & 0xF0;
    note = msg23 & 0x7F;
    vel = (msg23 / 256) | 0;
    
    debug_log(8100 + m); // MIDI message type
    
    // Note On
    (m == 0x90 && vel > 0) ? (
      notelist[note] < 0.001 ? (
        notelist[note] = vel;
        notecnt += 1;
        debug_log(8200 + note); // Note added
      );
    ) : 
    // Note Off
    (m == 0x80 || (m == 0x90 && vel == 0)) ? (
      slider30 < 0.5 ? ( // Not in hold mode
        notelist[note] > 0.001 ? (
          playing_note == note ? (
            midisend(ts, 0x80, note, 0);
            playing_note = -1;
            debug_log(8300 + note); // Stopped playing note
          );
          notecnt -= 1;
          notelist[note] = 0;
          debug_log(8400 + note); // Note removed
        );
      );
    ) : 
    // Pass through other messages
    (
      midisend(ts, msg1, msg23);
      debug_log(8500); // Passthrough
    );
    
    1;
  );
);

debug_log(8600 + midi_count); // MIDI messages processed

// Stop if no notes
notecnt < 1 && playing_note >= 0 ? (
  midisend(0, 0x80, playing_note, 0);
  playing_note = -1;
  debug_log(8700); // All notes stopped
);

// Reset position on first note
notecnt > 0 && !lastnotecnt ? (
  pbincpos = 1; // Trigger immediately
  debug_log(8800); // First note trigger
);

spos = 0;
dinc = 1 / srate * (tempo / 60) * rate;

debug_log(8900 + (dinc * 1000000)); // dinc value (scaled)

@sample

pbincpos += dinc;

// Turn off note at gate time
notecnt > 0 && pbincpos >= gate_pos && playing_note >= 0 ? (
  midisend(spos, 0x80, playing_note, 0);
  debug_log(9000 + playing_note); // Gate off
  playing_note = -1;
);

// Trigger new note
notecnt > 0 && pbincpos >= 1.0 ? (
  debug_log(9100); // Trigger point reached
  
  pbincpos -= 1;
  
  // Turn off old note if still on
  playing_note >= 0 ? (
    midisend(spos, 0x80, playing_note, 0);
    debug_log(9200 + playing_note); // Old note off
  );
  
  // Select new note and channel
  new_note = select_random_note();
  new_channel = select_random_channel();
  
  debug_log(9300 + new_note); // Selected note
  debug_log(9400 + new_channel); // Selected channel
  
  new_note >= 0 ? (
    add_note_to_history(new_note);
    add_channel_to_history(new_channel);
    
    // Humanized velocity
    vel_var = (my_rand() - 0.5) * 2 * (slider21 / 100);
    out_vel = slider20 * (1 + vel_var);
    out_vel = max(1, min(127, out_vel)) | 0;
    
    // Timing jitter as fraction of beat
    time_jitter = (my_rand() - 0.5) * 2 * (slider22 / 1000) * (tempo / 60) * rate;
    
    // Random gate variation
    gate_var = (my_rand() - 0.5) * 2 * (slider4 / 100);
    actual_gate = notelen * (1 + gate_var);
    actual_gate = max(0.01, min(0.99, actual_gate));
    
    debug_log(9500 + out_vel); // Output velocity
    
    // Send note on (convert channel to 0-based)
    midisend(spos, 0x90 | (new_channel - 1), new_note | (out_vel << 8));
    
    debug_log(9600); // MIDI SENT!
    
    playing_note = new_note;
    playing_channel = new_channel - 1;
    playing_vel = out_vel;
    last_note_time = pbincpos;
    note_count_tracker += 1;
    
    // Schedule gate off and next note
    gate_pos = pbincpos + actual_gate;
    
    debug_log(9700 + note_count_tracker); // Total notes sent
  ) : (
    debug_log(9999); // FAILED TO SELECT NOTE!
  );
);

spos += 1;

@gfx 600 420

gfx_clear = 1330597887;

gfx_setfont(1, "Arial", 18, 'b');
gfx_x = 10; gfx_y = 10;
gfx_r = 1; gfx_g = 1; gfx_b = 1;
gfx_printf("HUMANIZED RANDOM ARPEGGIATOR [DEBUG]");

gfx_setfont(1, "Arial", 12);

notecnt = count_notes();

// Status section
gfx_r = 0.3; gfx_g = 1; gfx_b = 0.3;
gfx_x = 10; gfx_y = 40;
gfx_printf("STATUS:");

gfx_r = 1; gfx_g = 1; gfx_b = 1;
gfx_x = 80; gfx_y = 40;
gfx_printf("Active Notes: %d | Tempo: %.1f BPM | Total Sent: %d", 
  notecnt, tempo, note_count_tracker);

// Timing section
gfx_r = 1; gfx_g = 0.7; gfx_b = 0.3;
gfx_x = 10; gfx_y = 60;
gfx_printf("TIMING:");

gfx_r = 1; gfx_g = 1; gfx_b = 1;
gfx_x = 80; gfx_y = 60;
preset_names = " Custom  1/32T  1/32  1/32.  1/16T  1/16  1/16.  1/8T  1/8  1/8.  1/4T  1/4  1/4.  1/2T  1/2  1/2.  1T  1  1.  2T  2 ";
match(preset_names, #speed_name, slider1 * 7);
gfx_printf("Speed: %s (1/%.3f)", #speed_name, active_speed);

gfx_x = 10; gfx_y = 80;
gfx_printf("Position: %.6f | dinc: %.9f | Gate: %.3f", 
  pbincpos, dinc, gate_pos);

// Playing section
gfx_r = 0.3; gfx_g = 0.7; gfx_b = 1;
gfx_x = 10; gfx_y = 100;
gfx_printf("PLAYING:");

gfx_r = 1; gfx_g = 1; gfx_b = 1;
gfx_x = 80; gfx_y = 100;
gfx_printf("%s", 
  playing_note >= 0 ? sprintf(#tmp, "Note %d | Ch %d | Vel %d", 
    playing_note, playing_channel + 1, playing_vel) : "--- (waiting for notes)");

// Config section
gfx_r = 1; gfx_g = 0.5; gfx_b = 1;
gfx_x = 10; gfx_y = 130;
gfx_printf("CONFIG:");

gfx_r = 1; gfx_g = 1; gfx_b = 1;
gfx_x = 10; gfx_y = 150;
gfx_printf("  Lockout: Note=%d | Channel=%d", slider10, slider11);

gfx_x = 10; gfx_y = 170;
gfx_printf("  Humanization: Time=±%dms | Vel=%d±%d%%", 
  slider22, slider20, slider21);

gfx_x = 10; gfx_y = 190;
max_chan = min(slider15 + slider16 - 1, 16);
gfx_printf("  Channels: %d-%d (%d) %s | Gate: %d%% ±%d%%", 
  slider15, max_chan, slider16,
  slider17 > 0.5 ? "[RANDOM]" : "[FIXED]",
  slider3, slider4);

gfx_x = 10; gfx_y = 210;
gfx_printf("  Hold: %s", slider30 > 0.5 ? "ON" : "OFF");

// Debug section
gfx_r = 1; gfx_g = 1; gfx_b = 0;
gfx_x = 10; gfx_y = 240;
gfx_printf("DEBUG LOG (last 10 events):");

gfx_setfont(1, "Courier New", 10);
slider31 > 0 ? (
  i = 0;
  loop(10,
    idx = (debug_idx - 10 + i + 100) % 100;
    val = debug_buf[idx];
    
    gfx_x = 10; gfx_y = 260 + i * 14;
    
    // Decode debug codes
    val >= 9000 && val < 10000 ? (
      gfx_r = 0; gfx_g = 1; gfx_b = 0;
      val >= 9700 ? (
        gfx_printf("[SENT] Total notes: %d", val - 9700);
      ) : val >= 9600 ? (
        gfx_printf("[MIDI] Note ON sent!");
      ) : val >= 9500 ? (
        gfx_printf("[VEL] Output velocity: %d", val - 9500);
      ) : val >= 9400 ? (
        gfx_printf("[CHAN] Selected channel: %d", val - 9400);
      ) : val >= 9300 ? (
        gfx_printf("[NOTE] Selected note: %d", val - 9300);
      ) : val >= 9200 ? (
        gfx_printf("[OFF] Old note turned off: %d", val - 9200);
      ) : val >= 9100 ? (
        gfx_printf("[TRIG] Trigger point reached!");
      ) : val >= 9000 ? (
        gfx_printf("[GATE] Gate off for note: %d", val - 9000);
      ) : val == 9999 ? (
        gfx_printf("[ERROR] Failed to select note!");
      ) : (
        gfx_printf("???");
      );
    ) : val >= 8000 && val < 9000 ? (
      gfx_r = 0.7; gfx_g = 0.7; gfx_b = 1;
      val >= 8900 ? (
        gfx_printf("[DINC] Value: %.9f", (val - 8900) / 1000000);
      ) : val >= 8800 ? (
        gfx_printf("[RESET] First note, immediate trigger");
      ) : val >= 8700 ? (
        gfx_printf("[STOP] All notes stopped");
      ) : val >= 8600 ? (
        gfx_printf("[BLOCK] Processed %d MIDI msgs", val - 8600);
      ) : val >= 8500 ? (
        gfx_printf("[PASS] Non-note message passed through");
      ) : val >= 8400 ? (
        gfx_printf("[REMOVE] Note removed: %d", val - 8400);
      ) : val >= 8300 ? (
        gfx_printf("[STOP] Stopped playing note: %d", val - 8300);
      ) : val >= 8200 ? (
        gfx_printf("[ADD] Note added: %d", val - 8200);
      ) : val >= 8100 ? (
        gfx_printf("[MIDI] Received type: 0x%X", val - 8100);
      ) : val >= 8000 ? (
        gfx_printf("[BLOCK] Start, notes: %d", val - 8000);
      ) : (
        gfx_printf("???");
      );
    ) : val >= 5000 && val < 8000 ? (
      gfx_r = 1; gfx_g = 0.7; gfx_b = 0.3;
      val >= 7000 ? (
        gfx_printf("[SPEED] Changed to: %d", val - 7000);
      ) : val >= 6200 ? (
        gfx_printf("[CHAN] Fixed channel: %d", val - 6200);
      ) : val >= 6100 ? (
        gfx_printf("[CHAN] Fallback: %d", val - 6100);
      ) : val >= 6000 ? (
        gfx_printf("[CHAN] Random selected: %d", val - 6000);
      ) : val >= 5300 ? (
        gfx_printf("[NOTE] Fallback note: %d", val - 5300);
      ) : val >= 5100 ? (
        gfx_printf("[NOTE] Valid note found: %d", val - 5100);
      ) : val >= 5000 ? (
        gfx_printf("[SELECT] Starting note selection");
      ) : (
        gfx_printf("???");
      );
    ) : (
      gfx_r = 0.5; gfx_g = 0.5; gfx_b = 0.5;
      val >= 4000 ? (
        gfx_printf("[HIST] Channel added: %d", val - 4000);
      ) : val >= 3000 ? (
        gfx_printf("[HIST] Note added: %d", val - 3000);
      ) : val == 1000 ? (
        gfx_printf("[INIT] Plugin initialized");
      ) : (
        gfx_printf("...");
      );
    );
    
    i += 1;
  );
) : (
  gfx_r = 0.7; gfx_g = 0.7; gfx_b = 0.7;
  gfx_x = 10; gfx_y = 260;
  gfx_printf("(Set Debug Mode to 'GUI Only' or 'Console Output' to see log)");
);

// Active notes display
gfx_setfont(1, "Arial", 12);
gfx_r = 1; gfx_g = 1; gfx_b = 1;
gfx_x = 10; gfx_y = 400;
gfx_printf("Active Notes: ");

gfx_x = 120; gfx_y = 400;
displayed = 0;
idx = 0;
loop(MAX_NOTES,
  notelist[idx] > 0 && displayed < 16 ? (
    idx == playing_note ? (
      gfx_r = 0.3; gfx_g = 1; gfx_b = 0.3;
    ) : (
      gfx_r = 0.7; gfx_g = 0.7; gfx_b = 0.7;
    );
    
    gfx_printf("%d ", idx);
    displayed += 1;
  );
  idx += 1;
);

notecnt > 16 ? (
  gfx_r = 0.5; gfx_g = 0.5; gfx_b = 0.5;
  gfx_printf("... +%d more", notecnt - 16);
);