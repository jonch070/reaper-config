-- Quick Builder Instrument Configuration
-- Maps instrument IDs to their display labels and associated track names

return {
  ["woods"] = {
    ["picc"] = {
      ["label"] = "Picc",
      ["tracks"] = {"AS Piccolo**"}
    },
    ["fl"] = {
      ["label"] = "Fl",
      ["tracks"] = {"AS Flute 1**", "AS Flute 2**"}
    },
    ["ob"] = {
      ["label"] = "Ob",
      ["tracks"] = {"AS Oboe 1**", "AS Oboe 2**"}
    },
    ["eh"] = {
      ["label"] = "EH",
      ["tracks"] = {"AS English Horn**"}
    },
    ["cl"] = {
      ["label"] = "Cl",
      ["tracks"] = {"AS Clarinet 1**", "AS Clarinet 2**"}
    },
    ["bcl"] = {
      ["label"] = "BCl",
      ["tracks"] = {"AS Bass Clarinet**"}
    },
    ["bsn"] = {
      ["label"] = "Bsn",
      ["tracks"] = {"AS Bassoon 1**", "AS Bassoon 2**"}
    },
    ["cbsn"] = {
      ["label"] = "C.Bsn",
      ["tracks"] = {"AS Contrabassoon**"}
    }
  },
  ["brass"] = {
    ["tpt"] = {
      ["label"] = "Tpt",
      ["tracks"] = {"Trumpet 1 - IB", "Trumpet 2 - IB", "Trumpet 3 - IB", "Trumpet 4 - IB"}
    },
    ["hrn"] = {
      ["label"] = "Hrn",
      ["tracks"] = {"Horn 1 - IB", "Horn 2 - IB", "Horn 3 - IB", "Horn 4 - IB", "Horn 5 - IB", "Horn 6 - IB"}
    },
    ["tbn"] = {
      ["label"] = "Tbn",
      ["tracks"] = {"Trombone 1 - IB", "Trombone 2 - IB", "Trombone 3 - IB"}
    },
    ["btbn"] = {
      ["label"] = "B.Tbn",
      ["tracks"] = {"B Trombone - IB"}
    },
    ["tba"] = {
      ["label"] = "Tba",
      ["tracks"] = {"Tuba - IB"}
    }
  },
  ["strings"] = {
    ["vln1"] = {
      ["label"] = "Vln1",
      ["tracks"] = {
        ["solo"] = {"Stradivari Violin*"},
        ["chamber"] = {"Vlns 1: Legato: SCS"},
        ["symphony"] = {"Vlns 1: Legato: PCS"}
      }
    },
    ["vln2"] = {
      ["label"] = "Vln2",
      ["tracks"] = {
        ["solo"] = nil,  -- No solo vln2 currently
        ["chamber"] = {"Vlns 2: Legato: SCS"},
        ["symphony"] = {"Vlns 2: Legato: PCS"}
      }
    },
    ["vla"] = {
      ["label"] = "Vla",
      ["tracks"] = {
        ["solo"] = {"Amati Viola*"},
        ["chamber"] = {"Violas: Legato: SCS"},
        ["symphony"] = {"Violas: Legato: PCS "}
      }
    },
    ["vc"] = {
      ["label"] = "Vc",
      ["tracks"] = {
        ["solo"] = {"Stradivari Cello*"},
        ["chamber"] = {"Cellos: Legato: SCS"},
        ["symphony"] = {"Cellos: Legato: PCS"}
      }
    },
    ["cb"] = {
      ["label"] = "Cb",
      ["tracks"] = {
        ["solo"] = {"Spitfire Solo Bass*"},
        ["chamber"] = {"Basses: Legato: SCS"},
        ["symphony"] = {"Basses: Legato: PCS"}
      }
    }
  }
}
