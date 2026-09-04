#!/usr/bin/env python3
"""Rehome stranded Hyprland workspaces after a dock/undock.

Hyprland changes monitor layout live, but `hl.workspace_rule` only
re-evaluates when the config is parsed. After a dock/undock, windows are
left on workspaces belonging to a monitor that is now mirrored or gone,
and in the dead numeric gaps between blocks (10, 20, 30) which no rule
covers.

`plan()` and `lua_program()` are pure: they take a snapshot of
`hyprctl -j monitors all`, `workspacerules`, `workspaces` and `clients`
and return the window moves needed, rendered as a `hyprctl eval` program.
Everything below `main()` is the I/O layer that feeds them live state.

A live monitor is one that is not disabled and mirrors nothing. A
homeless workspace is a populated, positive-id workspace whose rule names
a monitor that is not live, or that has no rule at all. Each one moves to
its own slot in the target block if free, else the lowest free slot, else
the block's void slot (defaultName "0"). Blocks are read from
`workspacerules`, never hardcoded.

Plain `hyprctl dispatch` is rejected under a Lua config, and `hyprctl
eval` exits 0 even when the Lua failed -- the failure is a stdout line
starting with "error:". The working move is `follow = false`, not
`silent = true`; hl.dsp.* drops unknown keys silently.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from typing import NamedTuple


class Move(NamedTuple):
    """One window that needs to move off a homeless workspace."""

    address: str
    source: int
    target: int
    reason: str = ""


def refocus(focused: str, moves: list[Move]) -> str:
    """The window needing refocus after `moves`, or "" if none does."""
    return focused if any(m.address == focused for m in moves) and focused else ""


# --------------------------------------------------------------------------
# pure planning
# --------------------------------------------------------------------------


def _is_live(mon) -> bool:
    """Live: not disabled and not mirroring anything."""
    return not mon.get("disabled", False) and (mon.get("mirrorOf") or "none") == "none"


def _by_id_or_name(monitors, token):
    """Resolve a monitor reference by numeric id, then by name."""
    for mon in monitors:
        if str(mon.get("id")) == token:
            return mon
    for mon in monitors:
        if mon.get("name") == token:
            return mon
    return None


def _by_selector(monitors, selector):
    """Resolve a workspace rule's `monitor` selector to a monitor entry."""
    if selector.startswith("desc:"):
        desc = selector[len("desc:") :]
        for mon in monitors:
            if mon.get("description") == desc:
                return mon
        # Hyprland matches `desc:` as a prefix, so honour that too.
        for mon in monitors:
            if (mon.get("description") or "").startswith(desc):
                return mon
        return None
    return _by_id_or_name(monitors, selector)


def _read_rules(monitors, workspacerules):
    """-> (blocks, {ws id: (monitor, slot)}, {ws id: block base})."""
    blocks: dict = {}
    ruled: dict = {}
    by_selector: dict = {}
    for rule in workspacerules:
        try:
            ws_id = int(rule.get("workspaceString"))
        except (TypeError, ValueError):
            continue
        selector = rule.get("monitor") or ""
        mon = _by_selector(monitors, selector)
        slot = str(rule.get("defaultName") or "1")
        ruled[ws_id] = (mon, slot)
        by_selector.setdefault(selector, []).append(ws_id)
        if mon is not None:
            blocks.setdefault(mon["id"], []).append((ws_id, slot))
    # A block's base is the lowest workspace id its rules cover, readable from
    # `workspacerules` alone, so it survives the monitor being unplugged.
    bases = {ws_id: min(ids) for ids in by_selector.values() for ws_id in ids}
    return blocks, ruled, bases


def _target_monitor(ruled_mon, monitors, live):
    """Mirror target, else primary (origin), else focused, else lowest id."""
    if ruled_mon is not None:
        mirror_of = ruled_mon.get("mirrorOf") or "none"
        if mirror_of != "none":
            mirrored = _by_id_or_name(monitors, mirror_of)
            if mirrored is not None and _is_live(mirrored):
                return mirrored
    origin = [m for m in live if m.get("x") == 0 and m.get("y") == 0]
    if len(origin) == 1:
        return origin[0]
    for mon in monitors:
        if mon.get("focused") and _is_live(mon):
            return mon
    return min(live, key=lambda m: m["id"]) if live else None


def _allocate(block, slot, taken):
    """One source's slot in `block`, given what is `taken`.

    Own slot if free, else the lowest free ordinary slot, else the block's
    void slot, else the own slot even though it is taken.
    """
    ordinary: dict = {}
    void = None
    for ws_id, ws_slot in sorted(block):
        if ws_slot == "0":
            void = ws_id if void is None else void
        else:
            ordinary.setdefault(ws_slot, ws_id)
    own = ordinary.get(slot)
    if own is not None and own not in taken:
        return own
    free = [ws_id for ws_id in ordinary.values() if ws_id not in taken]
    if free:
        return min(free)
    return void if void is not None else own


def _slot_order(slot):
    """Within-block ordering: numeric slots first, ascending."""
    return int(slot) if slot.isdigit() else 99


def plan(monitors, workspacerules, workspaces, clients, collapse: bool = False) -> list[Move]:
    """Compute the moves needed to rehome every homeless workspace's windows.

    `collapse=False` keeps each source's own slot index when it is free, so
    gaps are left where they fall. `collapse=True` packs densely from the
    first slot instead.
    """
    return _plan_rescue(monitors, workspacerules, workspaces, clients, dense=collapse)


def _plan_rescue(monitors, workspacerules, workspaces, clients, dense: bool = False) -> list[Move]:
    """Rescue every homeless workspace, own-slot-preferred."""
    live = [m for m in monitors if _is_live(m)]
    live_ids = {m["id"] for m in live}
    blocks, ruled, bases = _read_rules(monitors, workspacerules)
    populated = {(cl.get("workspace") or {}).get("id") for cl in clients}

    # The homeless sources that have content, and the monitor each is bound for.
    sources = []
    for ws in workspaces:
        ws_id = ws.get("id")
        if not isinstance(ws_id, int) or ws_id <= 0 or ws_id not in populated:
            continue  # an empty homeless workspace moves nothing
        ruled_mon, slot = ruled.get(ws_id, (None, "1"))
        if ruled_mon is not None and ruled_mon["id"] in live_ids:
            continue  # homed on a live monitor
        target_mon = _target_monitor(ruled_mon, monitors, live)
        if target_mon is not None:
            sources.append((ws_id, slot, ruled_mon, target_mon, bases.get(ws_id)))

    # Lowest block first, then slot; unruled sources last.
    sources.sort(key=lambda s: (1, 0, 0, s[0]) if s[4] is None else (0, s[4], _slot_order(s[1]), s[0]))

    # Walk the sources, one free-slot pool per target block.
    rehome: dict = {}
    taken: dict = {}
    for ws_id, slot, ruled_mon, target_mon, _base in sources:
        block = blocks.get(target_mon["id"])
        if not block:
            continue
        # A slot already holding clients of its own is unavailable.
        claimed = taken.setdefault(target_mon["id"], {w for w, _ in block if w in populated})
        target_ws = _allocate(block, None if dense else slot, claimed)
        if target_ws is None or target_ws == ws_id:
            continue
        claimed.add(target_ws)
        if ruled_mon is None:
            # No rule at all (a dead block gap), or ruled to a monitor that is
            # unplugged and so absent from `monitors` entirely.
            why = "unruled" if _base is None else "monitor unplugged"
        elif (ruled_mon.get("mirrorOf") or "none") != "none":
            why = "%s mirrors %s" % (ruled_mon.get("name"), target_mon.get("name"))
        else:
            why = "%s not live" % ruled_mon.get("name")
        landed = dict(block).get(target_ws, slot)
        rehome[ws_id] = (target_ws, "%s -> slot %s on %s" % (why, landed, target_mon.get("name")))

    # One move per client, all of one source's clients to its allocated slot.
    moves = []
    for cl in clients:
        ws_id = (cl.get("workspace") or {}).get("id")
        if ws_id in rehome:
            target_ws, reason = rehome[ws_id]
            moves.append(Move(cl.get("address", ""), ws_id, target_ws, reason))

    return sorted(moves, key=lambda m: (m.source, m.address))


def lua_program(moves: list[Move]) -> str:
    """Render `moves` as a Lua program body for `hyprctl eval`.

    One statement per line, in the order given. An empty move list renders
    an empty string.
    """
    return "\n".join(
        'hl.dispatch(hl.dsp.window.move({ window = "address:%s", workspace = %d, follow = false }))'
        % (m.address, m.target)
        for m in moves
    )


# --------------------------------------------------------------------------
# thin I/O layer
# --------------------------------------------------------------------------


class HyprctlError(RuntimeError):
    pass


def _hyprctl(*args):
    """Run `hyprctl <args>` and return its stdout, or raise HyprctlError."""
    try:
        done = subprocess.run(
            ["hyprctl", *args], capture_output=True, text=True, check=False
        )
    except FileNotFoundError:
        raise HyprctlError("hyprctl not found on PATH") from None
    if done.returncode != 0:
        raise HyprctlError(
            "hyprctl %s failed (exit %d): %s"
            % (" ".join(args), done.returncode, (done.stderr or done.stdout).strip())
        )
    return done.stdout


def _eval(program):
    """Run a Lua program through `hyprctl eval`."""
    out = _hyprctl("eval", program)
    if out.startswith("error:"):
        raise HyprctlError("hyprctl eval: %s" % out.strip())
    return out


def _hyprctl_json(*args):
    out = _hyprctl("-j", *args)
    try:
        return json.loads(out)
    except json.JSONDecodeError as exc:
        raise HyprctlError(
            "hyprctl -j %s did not return JSON (%s): %.200s"
            % (" ".join(args), exc, out.strip())
        ) from None


def _describe(move, clients_by_address, width=52):
    cl = clients_by_address.get(move.address, {})
    what = "%s  %s" % (cl.get("class") or "?", cl.get("title") or "")
    what = what.strip()
    if len(what) > width:
        what = what[: width - 1] + "…"
    return "  ws %-3d -> ws %-3d  %s" % (move.source, move.target, what)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        prog="ws-rehome",
        description="Move windows off homeless Hyprland workspaces onto live monitors.",
    )
    ap.add_argument("-n", "--dry-run", action="store_true", help="print the plan, change nothing")
    ap.add_argument(
        "-c",
        "--collapse",
        action="store_true",
        help="pack rescued workspaces densely from the first slot, with no "
        "gaps, instead of each keeping its own slot index when free",
    )
    ap.add_argument(
        "-r",
        "--reload",
        action="store_true",
        help="hyprctl reload first, so the Lua config re-emits current workspace rules",
    )
    args = ap.parse_args(argv)

    try:
        if args.reload:
            if args.dry_run:
                print("--reload skipped: --dry-run changes nothing", file=sys.stderr)
            else:
                print("reloading hyprland config...")
                _hyprctl("reload")
        monitors = _hyprctl_json("monitors", "all")
        workspacerules = _hyprctl_json("workspacerules")
        workspaces = _hyprctl_json("workspaces")
        clients = _hyprctl_json("clients")
    except HyprctlError as exc:
        print("ws-rehome: %s" % exc, file=sys.stderr)
        return 1

    moves = plan(monitors, workspacerules, workspaces, clients, collapse=args.collapse)
    if not moves:
        print("nothing to rehome")
        return 0

    clients_by_address = {c.get("address"): c for c in clients}
    print("%d window%s to rehome:" % (len(moves), "" if len(moves) == 1 else "s"))
    for move in moves:
        print(_describe(move, clients_by_address))
    for source in sorted({m.source for m in moves}):
        reason = next(m.reason for m in moves if m.source == source)
        print("  ws %-3d  %s" % (source, reason))

    if args.dry_run:
        print("dry run: nothing applied")
        return 0

    try:
        focused = (_hyprctl_json("activewindow") or {}).get("address") or ""
        _eval(lua_program(moves))
        restore = refocus(focused, moves)
        if restore:
            _eval('hl.dispatch(hl.dsp.focus({ window = "address:%s" }))' % restore)
    except HyprctlError as exc:
        print("ws-rehome: %s" % exc, file=sys.stderr)
        return 1
    print("applied")
    return 0


if __name__ == "__main__":
    sys.exit(main())
