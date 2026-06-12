-- ========================================
-- Type Definitions
-- ========================================

-- Global variables (defined at runtime)
---@class DebugModule
---@field FEATURE table<string, number> Feature scope constants
---@field log fun(message: string|table, feature: number) Log at DEBUG level
---@field warn fun(message: string|table, feature: number) Log at WARN level
---@field error fun(message: string|table, feature: number) Log at ERROR level

---@type DebugModule
Debug = Debug

-- Primitives

---@class Rect
---@field x number
---@field y number
---@field width number
---@field height number


-- Modal Component Types

---@class ModalState
---@field isOpen boolean
---@field inputText string
---@field justOpened boolean


-- FilterInput Component Types

---@class FilterInputConfig
---@field onItemSelected fun(selectedItem: FilterInputItem): nil Callback when item is selected
---@field getFilteredList fun(searchQuery: string): FilterInputItem[] Function to get filtered items based on search
---@field isLoading? fun(): boolean Optional function to check if data is still loading
---@field showAllWhenEmpty? boolean Optional - show all items when search is empty (defaults to false)
---@field placeholderText? string Optional placeholder text (defaults to "Type to search...")
---@field hintText? string Optional hint text for input (defaults to "Select an item")

---@class FilterInputPopupState
---@field positionX number
---@field positionY number

---@class FilterInputScrollState
---@field selected_index number
---@field should_scroll boolean
---@field selection_changed boolean

---@class FilterInputDropdownState
---@field search_query string
---@field dropdown_was_open boolean
---@field clear_search_next_frame boolean
---@field dropdown_clicked boolean

---@class FilterInputItem
---@field name string Display name for the item
---@field id string Unique identifier for the item
---@field itemData any The original data object for the item


-- Template System Types

---@class SectionTemplate
---@field name string Template name
---@field originalVoiceCount integer Voice count when template was saved
---@field instruments InstrumentFlat[] Instruments in this template
---@field version? integer Data version number
---@field metadata table Metadata (createdDate, etc.)

---@class TemplateCacheEntry
---@field name string Template name
---@field instrumentNames string[] Array of instrument names within this template


-- Sections

---@class Section
---@field sectionId string
---@field name string
---@field displayOrder number


-- ReaperTracks

---@class TrackCacheTrack
---@field guid string
---@field name string
---@field number integer
---@field color any -- TODO FIX THIS
---@field track MediaTrack
---@field isVisible boolean Track is visible in TCP
---@field parentFolders TrackCacheTrack[] Array of ancestor folder tracks (empty if no parents)


-- Instruments

---@class VoicePosition
---@field voice number
---@field octave number

---@class ChordTonePosition
---@field targetNote string
---@field chordToneNum number

---@class Position
---@field sectionId string
---@field voice? VoicePosition
---@field chordTone? ChordTonePosition

---@class TrackData  
---@field guid string
---@field reaperTrack MediaTrack|nil
---@field isMissing? boolean

---@class Instrument
---@field name string
---@field position Position
---@field trackData TrackData

---@class InstrumentFlat
---@field name string
---@field position Position
---@field trackGuid string


-- State

---@class EnsembleSaveState
---@field name string
---@field divisi_mode integer
---@field is_modified boolean
---@field voiceCount integer
---@field numVisibleOctavesPositive integer
---@field numVisibleOctavesNegative integer
---@field instruments InstrumentFlat[]
---@field sections Section[]
---@field transforms TransformData
---@field emptyChordTonePositions? ChordTonePosition[]
---@field createdDate? number
---@field version? integer


-- UI State

---@class FilterPopupState
---@field cellId string
---@field positionX number
---@field positionY number


-- Grid

---@class GridRowColumnData
---@field section Section
---@field instruments Instrument[]
---@field cellId string

---@class GridVoiceRowData
---@field position VoicePosition
---@field columns GridRowColumnData[]

---@class GridChordToneRowData
---@field position ChordTonePosition
---@field columns GridRowColumnData[]

---@class GridData
---@field sortedSections Section[]
---@field voiceRows GridVoiceRowData[]
---@field chordToneRows GridChordToneRowData[]
---@field voiceCount integer
---@field numVisibleOctavesNegative integer
---@field numVisibleOctavesPositive integer

---@class InstrumentDraggablePayload
---@field sourceCellId string
---@field instrument Instrument

---@class DragState
---@field is_active boolean
---@field payload any|nil
---@field offset_x number
---@field offset_y number
---@field render_fn function|nil
---@field item_rect table|nil
---@field item_copy_rect table|nil
---@field hasLinkedElements boolean


-- Quick Builder Types

---@alias QuickBuilderVoicingMode "solo"|"unison"|"closed"|"open"|"brass_2part"|"brass_3part"

---@alias QuickBuilderCombineMode "aligned"|"stacked"|"interlocked"|"enclosure"|"overlap"|"octaves"

---@alias QuickBuilderLowMode "voiced"|"unison_root"|"root_octaves"

---@alias QuickBuilderStringSize "solo"|"chamber"|"symphony"


-- Transform System Types

---@alias TransformerType "scale"|"fixed"|"ignore"

---@alias TransformParameter "velocity"|string  -- string format: "cc1", "cc11", etc.

---@class Transformer
---@field type TransformerType
---@field value number  -- Scale: 0-200 (percentage), Fixed: 0-127 (CC/velocity value)

---@class TransformData
---@field activeColumns TransformParameter[]  -- Currently visible columns in Transform view
---@field bySection table<string, table<TransformParameter, Transformer>>  -- [sectionId][parameter] = transformer
---@field byInstrument table<string, table<TransformParameter, Transformer>>  -- [instrumentId][parameter] = transformer


-- TabView Component Types

---@class TabConfig
---@field id string Unique identifier for the tab
---@field name string Display name for the tab
---@field renderFunction fun(ctx: ImGui_Context): nil Function to render the tab content


-- Transform View Types

---@class TransformRowData
---@field type "section"|"instrument"
---@field name string Display name for the row
---@field source Section|Instrument The section or instrument object


-- Retroactive Recording Types

---@class RetroMidiEvent
---@field projectTime number Timeline position in seconds (-1 if playback stopped)
---@field sampleTime number Event timestamp in seconds from JSFX time_precise() (for note timing)
---@field eventType integer 0=noteOff, 1=noteOn, 2=CC
---@field data1 integer Note number (for notes) or CC number (for CCs)
---@field data2 integer Velocity (for notes) or CC value (for CCs)
---@field data3 integer MIDI channel (0-15)
---@field polledTime number Reaper time when Lua polled this event from GMEM (for pruning)

---@class RetroInstrumentBuffer
---@field events RetroMidiEvent[] Array of captured MIDI events
---@field lastReadHead number Last GMEM write_head value we read
---@field slotNumber integer Sequential slot number (0-based) for GMEM address calculation
---@field instrumentId string Track GUID of this instrument
---@field recentCursor integer Index in events array marking start of "recent" session
---@field lastInputTime number Timestamp of last MIDI input (for idle detection)

---@class RetroActiveBuffersMap
---@field [string] RetroInstrumentBuffer Map of instrumentId → buffer

---@class RetroSlotNumberMap
---@field [string] integer Map of instrumentId → sequential slot number (0-based)


-- Debug System Types

--- Debug feature scopes (bitwise flags - use Debug.FEATURE constants)
---@alias DebugFeature number

--- Debug log levels (internal use)
---@alias DebugLevel "DEBUG" | "WARN" | "ERROR"
