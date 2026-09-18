# presentation/ — desk, map playback, cutscenes, ledger, summary

**Portrait-first.** Mobile is portrait; reply options overlay the bottom of the
letter. Desktop shows the same portrait letter column with options beside it and
more of the desk visible. Both come from one scene, not two implementations.

Every screen works with touch **and** with mouse and keyboard (SPEC §15). Text
is the main medium and must be comfortable to read at length on a phone.

All assets load through `Assets` (SPEC §16.3), so swapping placeholder art for
final art is a change to `data/assets/`, never a code change.

`main.tscn` is a placeholder boot scene. The desk arrives with #21.
