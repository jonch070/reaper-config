track_marks = {
    record = 'REC',
    transcribe = 'TR',
    improve = 'IM'
}

-- Track colors keyed by mark abbreviation, ordered red (record) -> orange (improve),
-- with transcribe in between since it implies record but is a step closer to done.
track_mark_colors = {
    [track_marks.record] = { 255, 0, 0 },
    [track_marks.transcribe] = { 255, 85, 0 },
    [track_marks.improve] = { 255, 165, 0 }
}

return track_marks
