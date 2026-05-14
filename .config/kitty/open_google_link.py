"""
open_google_link.py — kitty kitten that on cmd+click extracts the word
under the mouse cursor and, if it matches a Google internal short-link
pattern (cl/123, b/456, go/foo, cs/path, who/ldap, playbook/foo,
teams/bar, monorail/issue), opens https://<that>. Otherwise does
nothing and lets the chained mouse_handle_click in the kitty.conf
mouse_map handle real URLs the standard way.

Why this exists: kitty's URL auto-detector requires `scheme://` form,
so bare `cl/123` strings printed by Google internal tools (gob, fig,
hg, critique, blaze, etc.) are not detected as URLs and cmd+click
does nothing. iTerm2's "smart selection" provides the same feature
via user-defined regexes; this is the kitty equivalent.

Triggered from kitty.conf:

    mouse_map cmd+left release grabbed,ungrabbed combine : \
        kitten open_google_link.py : mouse_handle_click link

The `combine` chain runs the kitten first (which opens the URL if a
match was found), then runs the standard URL-click fallback. The
fallback is a no-op when the kitten already opened something — clicks
on plain (non-URL, non-pattern) text just do nothing.

Cursor cell discovery (verified empirically against kitty 0.46.2):
  Window.current_mouse_position() returns
    {'cell_x': int, 'cell_y': int, 'in_left_half_of_cell': bool}
  cell_y is the 0-indexed visual screen row (NOT scrollback-absolute).
  Screen.line(y) returns a fast_data_types.Line whose __str__ is the
  cell text (the line has no as_text() method despite Screen having
  one — that asymmetry is a kitty quirk; just use str()).

The kitten runs without a UI overlay (handle_result.no_ui = True)
so kitty doesn't open a useless terminal pane that immediately
closes. handle_result executes inside kitty's main process with
direct access to the Window/Screen objects via the boss.
"""

from __future__ import annotations

import re
import subprocess
from typing import Any

# Patterns we treat as Google internal short-links. Any token of the
# form `<prefix>/<rest>` where <prefix> is in this set and <rest> is
# at least one URL-safe character. Tokens are normalized (stripped of
# surrounding punctuation) and lowercased before matching the prefix
# so `Cl/123` and `cl/123` both work.
#
# Add new prefixes here. Lowercase only; matching is case-insensitive
# on the prefix but case-preserving on the path (the URL is built from
# the original token, not the lowered one).
_PREFIXES = (
    "cl", "b", "go", "cs", "who", "playbook", "teams", "monorail",
    "moma", "yaqs", "qs", "sponge", "sponge2", "piper", "fig",
    "crrev", "ariane", "buganizer", "chat", "drive", "docs",
)
GOOGLE_INTERNAL_PATTERN = re.compile(
    r"^(?:" + "|".join(_PREFIXES) + r")/[A-Za-z0-9._/?#&=:%@+\-]+$",
    re.IGNORECASE,
)

# Characters commonly adjacent to URLs in prose that should be peeled
# off before matching. Includes ASCII brackets, quotes, sentence
# punctuation, and the box-drawing border kitty draws around panes
# (because cloudcode/scion render those right next to URLs).
_PEEL = "()[]{}<>'\"`,.;:!?│┃|"


def main(args: list[str]) -> str:
    # No-UI kitten; kitty insists this symbol exists even when
    # handle_result.no_ui is True. Returning an empty string passes
    # through to handle_result without opening an overlay window.
    return ""


def _word_at_cell(line: str, col: int) -> str:
    """Extract the whitespace-delimited word containing column `col`,
    then peel surrounding punctuation. Returns "" if `col` is on
    whitespace or out of bounds."""
    if col < 0 or col >= len(line):
        return ""
    if line[col].isspace():
        return ""
    # Walk left to start-of-word.
    start = col
    while start > 0 and not line[start - 1].isspace():
        start -= 1
    # Walk right to end-of-word.
    end = col
    while end < len(line) - 1 and not line[end + 1].isspace():
        end += 1
    return line[start : end + 1].strip(_PEEL)


def handle_result(
    args: list[str],
    main_result: str,
    target_window_id: int,
    boss: Any,
) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    # Get the mouse cell (None if mouse hasn't entered the window
    # since the last clear, which shouldn't happen on a real click).
    pos = window.current_mouse_position()
    if not pos:
        return
    col = int(pos["cell_x"])
    row = int(pos["cell_y"])

    # Pull the visible line text at the cursor row. Screen.line()
    # returns a Line object whose str() is the cell contents.
    try:
        line_text = str(window.screen.line(row))
    except Exception:
        return

    word = _word_at_cell(line_text, col)
    if not word or not GOOGLE_INTERNAL_PATTERN.match(word):
        # No match → let the chained mouse_handle_click do its thing
        # for real URLs (or nothing for plain text).
        return

    # Use http:// (NOT https://) for Google internal short-links.
    # The single-label hosts (cl, b, go, cs, who, …) don't have valid
    # https certs at the bare-hostname level; the canonical form
    # routed by corp DNS / UberProxy is plain http. Browsers
    # transparently upgrade to https on the redirect target.
    url = "http://" + word
    # macOS `open` routes via the system default-handler database
    # (Launch Services). Fire-and-forget so kitty's event loop isn't
    # blocked by browser launch.
    try:
        subprocess.Popen(
            ["open", url],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


# No terminal UI — handle_result runs in-process. Without this kitty
# spawns an overlay pane for the kitten that flashes and closes.
handle_result.no_ui = True  # type: ignore[attr-defined]
