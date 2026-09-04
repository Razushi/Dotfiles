"""Contract tests for ws_rehome.plan/lua_program/refocus.

fixtures/docked-stranded.json is a real `hyprctl -j` capture and is
treated as ground truth; its expected moves are derived by hand. Its one
homeless block has no gap for --collapse to close, so the compaction step
itself is pinned by the hand-built CollapseDenseTests instead.
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest import mock

import ws_rehome
from ws_rehome import Move, lua_program, plan, refocus

FIXTURE_PATH = Path(__file__).parent / "fixtures" / "docked-stranded.json"


def load_fixture() -> dict:
    with open(FIXTURE_PATH, encoding="utf-8") as fh:
        return json.load(fh)


# --- builders for edge cases the fixture doesn't cover ---


def monitor(id, name, desc, disabled=False, mirror_of="none", focused=False, x=0, y=0):
    return {
        "id": id,
        "name": name,
        "description": desc,
        "disabled": disabled,
        "mirrorOf": mirror_of,
        "focused": focused,
        "x": x,
        "y": y,
    }


def rule(ws_string, monitor_selector, default_name, **extra):
    r = {"workspaceString": ws_string, "monitor": monitor_selector, "defaultName": default_name}
    r.update(extra)
    return r


def workspace(id, name, monitor_name, monitor_id, windows=1):
    return {
        "id": id,
        "name": name,
        "monitor": monitor_name,
        "monitorID": monitor_id,
        "windows": windows,
    }


def client(address, workspace_id, workspace_name=""):
    return {"address": address, "workspace": {"id": workspace_id, "name": workspace_name or str(workspace_id)}}


class RealFixtureTests(unittest.TestCase):
    """Expectations derived by hand from fixtures/docked-stranded.json."""

    @classmethod
    def setUpClass(cls):
        cls.fixture = load_fixture()

    def _plan(self, collapse=False):
        f = self.fixture
        return plan(f["monitors"], f["workspacerules"], f["workspaces"], f["clients"], collapse=collapse)

    def test_fixture_raw_monitor_facts_match_rule_1_inputs(self):
        # eDP-1 (Lenovo laptop panel) mirrors DP-7 (ViewSonic, id 1), so it is
        # not live even though it is not disabled.
        by_name = {m["name"]: m for m in self.fixture["monitors"]}
        self.assertEqual(by_name["eDP-1"]["disabled"], False)
        self.assertEqual(by_name["eDP-1"]["mirrorOf"], "1")
        self.assertEqual(by_name["DP-7"]["id"], 1)
        self.assertEqual(by_name["DP-7"]["disabled"], False)
        self.assertEqual(by_name["DP-7"]["mirrorOf"], "none")
        self.assertEqual(by_name["DP-8"]["disabled"], False)
        self.assertEqual(by_name["DP-8"]["mirrorOf"], "none")

    def test_fixture_workspaces_4_and_11_produce_no_move(self):
        moves = self._plan()
        sources = {m.source for m in moves}
        self.assertNotIn(4, sources)
        self.assertNotIn(11, sources)

    def test_fixture_lenovo_block_rehomed_to_viewsonic_slots(self):
        moves = self._plan()
        by_source = {m.source: m for m in moves}
        self.assertEqual(by_source[21], Move("0x64425f6a98c0", 21, 1, by_source[21].reason))
        self.assertEqual(by_source[22], Move("0x64425ed93f60", 22, 2, by_source[22].reason))
        self.assertEqual(by_source[23], Move("0x64425ed934d0", 23, 3, by_source[23].reason))
        # Slot "4" of the DP-7 block is ws4, which already exists and holds a
        # window of its own, so ws24 is bumped to the lowest free slot: 5.
        self.assertEqual(by_source[24], Move("0x64425f62db40", 24, 5, by_source[24].reason))

    def test_fixture_dead_gap_workspace_10_sorts_last_and_fills_lowest_free_slot(self):
        moves = self._plan()
        ws10_moves = [m for m in moves if m.source == 10]
        addresses = {m.address for m in ws10_moves}
        self.assertEqual(addresses, {"0x64425f5d7b80", "0x64425f6dac00"})
        # ws10 is unruled, so it has no block base and sorts after the whole
        # Lenovo block. Slot "1" (ws1) is claimed by ws21 and ws4 is occupied,
        # so both its windows go to the lowest free slot, 6.
        self.assertTrue(all(m.target == 6 for m in ws10_moves))

    def test_fixture_total_moves_is_six(self):
        self.assertEqual(len(self._plan()), 6)

    def test_fixture_moves_sorted_by_source_then_address(self):
        moves = self._plan()
        expected = [
            Move("0x64425f5d7b80", 10, 6, moves[0].reason if moves else ""),
            Move("0x64425f6dac00", 10, 6, moves[1].reason if len(moves) > 1 else ""),
            Move("0x64425f6a98c0", 21, 1, moves[2].reason if len(moves) > 2 else ""),
            Move("0x64425ed93f60", 22, 2, moves[3].reason if len(moves) > 3 else ""),
            Move("0x64425ed934d0", 23, 3, moves[4].reason if len(moves) > 4 else ""),
            Move("0x64425f62db40", 24, 5, moves[5].reason if len(moves) > 5 else ""),
        ]
        self.assertEqual(moves, expected)

    def test_fixture_lua_program_renders_six_statements_in_plan_order(self):
        moves = self._plan()
        program = lua_program(moves)
        lines = program.splitlines()
        self.assertEqual(len(lines), 6)
        self.assertEqual(
            lines[0],
            'hl.dispatch(hl.dsp.window.move({ window = "address:0x64425f5d7b80", workspace = 6, follow = false }))',
        )
        self.assertEqual(
            lines[-1],
            'hl.dispatch(hl.dsp.window.move({ window = "address:0x64425f62db40", workspace = 5, follow = false }))',
        )


class CollapseFixtureTests(unittest.TestCase):
    """--collapse against the same real capture.

    docked-stranded.json's homeless sources already land on contiguous
    slots under the default algorithm, so there is no gap for dense packing
    to close and --collapse must reproduce the same six moves. The
    compaction step itself is pinned by CollapseDenseTests.
    """

    @classmethod
    def setUpClass(cls):
        cls.fixture = load_fixture()

    def _plan(self, collapse):
        f = self.fixture
        return plan(f["monitors"], f["workspacerules"], f["workspaces"], f["clients"], collapse=collapse)

    def test_collapse_matches_default_when_there_is_nothing_to_compact(self):
        self.assertEqual(self._plan(collapse=True), self._plan(collapse=False))

    def test_collapse_still_produces_the_same_six_moves(self):
        moves = self._plan(collapse=True)
        by_source = {m.source: (m.address, m.target) for m in moves}
        self.assertEqual(by_source[21], ("0x64425f6a98c0", 1))
        self.assertEqual(by_source[22], ("0x64425ed93f60", 2))
        self.assertEqual(by_source[23], ("0x64425ed934d0", 3))
        self.assertEqual(by_source[24], ("0x64425f62db40", 5))
        self.assertEqual(len(moves), 6)


class CollapseDenseTests(unittest.TestCase):
    """--collapse: pack the sources densely from the first slot.

    Keeps rescue's source ordering (lowest block base first, in its own
    slot order) but ignores each source's own slot number. Hand-built: no
    fixture has a gap to close.
    """

    def test_single_blocks_gap_is_closed(self):
        # A lone source block whose own slots are 1, 2, 6 lands on 21, 22, 26
        # by default, but compacts to 21, 22, 23 under --collapse.
        mon_z = monitor(3, "Z", "MonZ", disabled=False, mirror_of="none", focused=True)
        rules = block_rules(1, "desc:MonX") + block_rules(21, "desc:MonZ")
        workspaces = [
            workspace(1, "1", "X", 1, windows=1),
            workspace(2, "2", "X", 1, windows=1),
            workspace(6, "6", "X", 1, windows=1),
        ]
        clients = [client("0xX1", 1), client("0xX2", 2), client("0xX6", 6)]

        default_moves = plan([mon_z], rules, workspaces, clients, collapse=False)
        collapse_moves = plan([mon_z], rules, workspaces, clients, collapse=True)

        self.assertEqual({m.address: m.target for m in default_moves}, {"0xX1": 21, "0xX2": 22, "0xX6": 26})
        self.assertEqual({m.address: m.target for m in collapse_moves}, {"0xX1": 21, "0xX2": 22, "0xX6": 23})

    def test_second_blocks_sources_fill_after_the_first_blocks_own_order(self):
        # Same three-monitor shape as the default-mode test, densely packed:
        # MonX's order (1, 2, 6) fills 21-23, closing its own gap, then MonY's
        # (1, 2, 3) fills 24-26.
        mon_z = monitor(3, "Z", "MonZ", disabled=False, mirror_of="none", focused=True)
        rules = (
            block_rules(1, "desc:MonX")
            + block_rules(11, "desc:MonY")
            + block_rules(21, "desc:MonZ")
        )
        workspaces = [
            workspace(1, "1", "X", 1, windows=1),
            workspace(2, "2", "X", 1, windows=1),
            workspace(6, "6", "X", 1, windows=1),
            workspace(11, "1", "Y", 2, windows=1),
            workspace(12, "2", "Y", 2, windows=1),
            workspace(13, "3", "Y", 2, windows=1),
        ]
        clients = [
            client("0xX1", 1),
            client("0xX2", 2),
            client("0xX6", 6),
            client("0xY1", 11),
            client("0xY2", 12),
            client("0xY3", 13),
        ]

        moves = plan([mon_z], rules, workspaces, clients, collapse=True)

        by_address = {m.address: m.target for m in moves}
        self.assertEqual(
            by_address,
            {"0xX1": 21, "0xX2": 22, "0xX6": 23, "0xY1": 24, "0xY2": 25, "0xY3": 26},
        )


class RefocusTests(unittest.TestCase):
    """Whatever was focused before a rescue must be focused after.

    `refocus()` decides what must end up focused; rendering that into
    hyprctl calls is main()'s job and is not pinned here.
    """

    def test_untouched_focus_needs_no_correction(self):
        moves = [Move("0xDEF", 1, 21, "unrelated")]

        self.assertEqual(refocus("0xABC", moves), "")

    def test_focused_window_that_was_rescued_follows_it_to_the_new_workspace(self):
        moves = [Move("0xABC", 1, 21, "rescued")]

        self.assertEqual(refocus("0xABC", moves), "0xABC")

    def test_nothing_focused_before_stays_nothing_focused(self):
        moves = [Move("0xDEF", 1, 21, "unrelated")]

        self.assertEqual(refocus("", moves), "")

    def test_against_the_real_fixture_focus_follows_the_window_it_was_on(self):
        # The Firefox window on ws21 was focused before this rescue
        # (focusHistoryID 1); collapse's plan moves it to ws1.
        fixture = load_fixture()
        moves = plan(
            fixture["monitors"],
            fixture["workspacerules"],
            fixture["workspaces"],
            fixture["clients"],
            collapse=True,
        )
        self.assertEqual(refocus("0x64425f6a98c0", moves), "0x64425f6a98c0")


class CliCollapseAndReloadTests(unittest.TestCase):
    """main()'s wiring: --collapse threads through to plan(), and a default
    run never issues hyprctl reload. --reload stays for manual use."""

    def _run_main(self, argv):
        with mock.patch.object(ws_rehome, "_hyprctl_json", return_value=[]), mock.patch.object(
            ws_rehome, "plan", return_value=[]
        ) as mock_plan, mock.patch.object(ws_rehome, "_hyprctl") as mock_hyprctl:
            ws_rehome.main(argv)
        return mock_plan, mock_hyprctl

    def test_default_invocation_plans_in_rescue_mode(self):
        mock_plan, _ = self._run_main([])
        self.assertIs(mock_plan.call_args.kwargs["collapse"], False)

    def test_collapse_flag_plans_in_collapse_mode(self):
        mock_plan, _ = self._run_main(["--collapse"])
        self.assertIs(mock_plan.call_args.kwargs["collapse"], True)

    def test_default_rescue_run_never_reloads(self):
        _, mock_hyprctl = self._run_main([])
        reload_calls = [c for c in mock_hyprctl.call_args_list if c.args and c.args[0] == "reload"]
        self.assertEqual(reload_calls, [])


class Rule1LiveMonitorTests(unittest.TestCase):
    """Rule 1: live == not disabled AND mirrorOf == 'none'."""

    def test_disabled_monitor_owns_no_workspaces(self):
        mon_a = monitor(1, "A", "MonA", disabled=True, mirror_of="none", focused=False)
        mon_b = monitor(2, "B", "MonB", disabled=False, mirror_of="none", focused=True)
        rules = [
            rule("1", "desc:MonA", "1"),
            rule("2", "desc:MonB", "1"),
        ]
        workspaces = [
            workspace(1, "1", "A", 1, windows=1),
            workspace(2, "1", "B", 2, windows=0),
        ]
        clients = [client("0xAAA", 1)]

        moves = plan([mon_a, mon_b], rules, workspaces, clients)

        # MonA is disabled, so ws1 is homeless. MonA mirrors nothing, so the
        # target falls through to the focused monitor MonB, slot "1" (ws2).
        self.assertEqual(moves, [Move("0xAAA", 1, 2, moves[0].reason if moves else "")])


class Rule2MirrorOfResolutionTests(unittest.TestCase):
    """Rule 2: mirrorOf names a monitor by numeric id (as a string), with a
    name-matching fallback."""

    def test_mirror_of_resolves_by_numeric_id_not_connector_name(self):
        mon_c = monitor(5, "DP-C", "MirroringPanel", disabled=False, mirror_of="9", focused=False)
        mon_d = monitor(9, "DP-D", "TargetPanel", disabled=False, mirror_of="none", focused=False)
        rules = [
            rule("1", "desc:MirroringPanel", "1"),
            rule("2", "desc:TargetPanel", "1"),
        ]
        workspaces = [
            workspace(1, "1", "DP-C", 5, windows=1),
            workspace(2, "1", "DP-D", 9, windows=0),
        ]
        clients = [client("0xBBB", 1)]

        moves = plan([mon_c, mon_d], rules, workspaces, clients)

        # MonC (id 5) is not disabled but mirrors id "9" (MonD), so ws1 is
        # homeless and targets the monitor it mirrors, landing on ws2.
        self.assertEqual(moves, [Move("0xBBB", 1, 2, moves[0].reason if moves else "")])

    def test_mirror_of_falls_back_to_name_match(self):
        # mirrorOf matches no monitor id, so the resolver falls back to `name`:
        # mon_e is "DP-9", which is what mon_c's mirrorOf names.
        mon_c = monitor(5, "not-DP-9", "MirroringPanel", disabled=False, mirror_of="DP-9", focused=False)
        mon_e = monitor(7, "DP-9", "TargetPanel", disabled=False, mirror_of="none", focused=False)
        rules = [
            rule("1", "desc:MirroringPanel", "1"),
            rule("2", "desc:TargetPanel", "1"),
        ]
        workspaces = [
            workspace(1, "1", "not-DP-9", 5, windows=1),
            workspace(2, "1", "DP-9", 7, windows=0),
        ]
        clients = [client("0xCCC", 1)]

        moves = plan([mon_c, mon_e], rules, workspaces, clients)

        self.assertEqual(moves, [Move("0xCCC", 1, 2, moves[0].reason if moves else "")])


class Rule3BlocksFromRulesTests(unittest.TestCase):
    """Rule 3: blocks come from workspacerules; skip rules whose
    workspaceString is not a plain integer."""

    def test_non_integer_workspace_string_is_skipped_and_does_not_crash(self):
        mon = monitor(1, "M", "M", disabled=False, mirror_of="none", focused=True)
        rules = [
            rule("7", "desc:M", "1"),
            rule("special:1", "desc:M", "2"),  # bogus rule, must be ignored
        ]
        workspaces = [
            workspace(7, "1", "M", 1, windows=0),
            workspace(99, "99", "M", 1, windows=1),  # no rule -> homeless, default slot "1"
        ]
        clients = [client("0xDDD", 99)]

        moves = plan([mon], rules, workspaces, clients)

        # ws99 has no rule so its slot defaults to "1", matching the valid rule
        # for ws7. The bogus "special:1" rule must not be consulted or crash.
        self.assertEqual(moves, [Move("0xDDD", 99, 7, moves[0].reason if moves else "")])


class Rule4HomelessDefinitionTests(unittest.TestCase):
    """Rule 4: homeless = id > 0 and (no rule, or rule names a non-live monitor)."""

    def test_workspace_with_no_rule_at_all_is_homeless(self):
        mon = monitor(1, "M", "M", disabled=False, mirror_of="none", focused=True)
        rules = [rule("1", "desc:M", "1")]
        workspaces = [
            workspace(1, "1", "M", 1, windows=0),
            workspace(50, "50", "M", 1, windows=1),  # unruled dead gap
        ]
        clients = [client("0xEEE", 50)]

        moves = plan([mon], rules, workspaces, clients)

        self.assertEqual(len(moves), 1)
        self.assertEqual(moves[0].source, 50)

    def test_workspace_ruled_to_live_monitor_is_never_touched(self):
        mon = monitor(1, "M", "M", disabled=False, mirror_of="none", focused=True)
        rules = [rule("1", "desc:M", "1")]
        workspaces = [workspace(1, "1", "M", 1, windows=1)]
        clients = [client("0xFFF", 1)]

        moves = plan([mon], rules, workspaces, clients)

        self.assertEqual(moves, [])


class Rule5TargetMonitorTests(unittest.TestCase):
    """Rule 5: mirrored ruled monitor -> its mirror target; else focused
    monitor; else lowest-id live monitor."""

    def test_falls_back_to_lowest_id_live_monitor_when_nothing_is_focused(self):
        mon_z = monitor(1, "Z", "Z", disabled=True, mirror_of="none", focused=False)  # ruled, disabled
        mon_y = monitor(3, "Y", "Y", disabled=False, mirror_of="none", focused=False)  # live
        mon_x = monitor(5, "X", "X", disabled=False, mirror_of="none", focused=False)  # live, higher id
        rules = [
            rule("1", "desc:Z", "1"),
            rule("30", "desc:Y", "1"),
        ]
        workspaces = [
            workspace(1, "1", "Z", 1, windows=1),
            workspace(30, "1", "Y", 3, windows=0),
        ]
        clients = [client("0x111", 1)]

        moves = plan([mon_z, mon_y, mon_x], rules, workspaces, clients)

        # No monitor is focused, so target falls back to the live monitor
        # with the lowest id: Y (3), not X (5).
        self.assertEqual(moves, [Move("0x111", 1, 30, moves[0].reason if moves else "")])


class Rule5PrimaryMonitorTests(unittest.TestCase):
    """Target: mirrored ruled monitor wins unconditionally; otherwise the
    primary monitor (live, at x==0,y==0); otherwise the focused monitor;
    otherwise the lowest-id live monitor.

    "Focused" only tracks where the cursor happened to be, so it is not
    deterministic across identical dock events and must not win over
    primary.
    """

    def test_absent_ruled_monitor_lands_on_primary_not_focused(self):
        # Primary (0,0) and focused are different live monitors, and ws1's
        # ruled monitor ("Ghost") is absent. Pick the one at the origin.
        mon_primary = monitor(2, "PRI", "Primary", focused=False, x=0, y=0)
        mon_focused = monitor(1, "FOC", "Focused", focused=True, x=1920, y=0)
        rules = [
            rule("1", "desc:Ghost", "1"),  # ws1's ruled monitor is absent
            rule("30", "desc:Primary", "1"),
            rule("40", "desc:Focused", "1"),
        ]
        workspaces = [workspace(1, "1", "Ghost", 99, windows=1)]
        clients = [client("0xPRI", 1)]

        moves = plan([mon_primary, mon_focused], rules, workspaces, clients)

        # Must land in the primary monitor's block (ws30), not the
        # focused monitor's block (ws40).
        self.assertEqual(moves, [Move("0xPRI", 1, 30, moves[0].reason if moves else "")])

    def test_mirroring_still_wins_over_a_different_primary(self):
        mon_mirror_target = monitor(3, "TARGET", "MirrorTarget", focused=False, x=500, y=500)
        mon_ruled = monitor(4, "RULED", "RuledMirroring", mirror_of="3", focused=False, x=999, y=999)
        mon_primary = monitor(5, "PRI2", "PrimaryElsewhere", focused=False, x=0, y=0)
        rules = [
            rule("1", "desc:RuledMirroring", "1"),
            rule("50", "desc:MirrorTarget", "1"),
            rule("60", "desc:PrimaryElsewhere", "1"),
        ]
        workspaces = [workspace(1, "1", "RULED", 4, windows=1)]
        clients = [client("0xMIR", 1)]

        moves = plan([mon_mirror_target, mon_ruled, mon_primary], rules, workspaces, clients)

        # Mirroring wins unconditionally: target the mirror source, not the
        # monitor sitting at the origin.
        self.assertEqual(moves, [Move("0xMIR", 1, 50, moves[0].reason if moves else "")])

    def test_no_monitor_at_origin_falls_back_to_focused(self):
        mon_a = monitor(1, "A", "A", focused=True, x=100, y=200)
        mon_b = monitor(2, "B", "B", focused=False, x=300, y=400)
        rules = [
            rule("1", "desc:Ghost", "1"),
            rule("70", "desc:A", "1"),
        ]
        workspaces = [workspace(1, "1", "Ghost", 99, windows=1)]
        clients = [client("0xNOORIGIN", 1)]

        moves = plan([mon_a, mon_b], rules, workspaces, clients)

        self.assertEqual(moves, [Move("0xNOORIGIN", 1, 70, moves[0].reason if moves else "")])

    def test_two_monitors_at_origin_is_ambiguous_falls_back_to_focused(self):
        mon_x = monitor(1, "X", "X", focused=False, x=0, y=0)
        mon_y = monitor(2, "Y", "Y", focused=True, x=0, y=0)
        rules = [
            rule("1", "desc:Ghost", "1"),
            rule("80", "desc:Y", "1"),
        ]
        workspaces = [workspace(1, "1", "Ghost", 99, windows=1)]
        clients = [client("0xAMBIG", 1)]

        moves = plan([mon_x, mon_y], rules, workspaces, clients)

        self.assertEqual(moves, [Move("0xAMBIG", 1, 80, moves[0].reason if moves else "")])

    def test_neither_primary_nor_focused_resolves_falls_back_to_lowest_id(self):
        mon_p = monitor(5, "P", "P", focused=False, x=111, y=222)
        mon_q = monitor(3, "Q", "Q", focused=False, x=333, y=444)
        rules = [
            rule("1", "desc:Ghost", "1"),
            rule("90", "desc:Q", "1"),
        ]
        workspaces = [workspace(1, "1", "Ghost", 99, windows=1)]
        clients = [client("0xLOWEST", 1)]

        moves = plan([mon_p, mon_q], rules, workspaces, clients)

        self.assertEqual(moves, [Move("0xLOWEST", 1, 90, moves[0].reason if moves else "")])


class Rule6TargetWorkspaceTests(unittest.TestCase):
    """Rule 6: match defaultName slot in target block; else lowest ws id in
    that block."""

    def test_falls_back_to_lowest_workspace_id_in_block_when_slot_missing(self):
        mon_a = monitor(1, "A", "A", disabled=True, mirror_of="none", focused=False)
        mon_b = monitor(2, "B", "B", disabled=False, mirror_of="none", focused=True)
        rules = [
            rule("1", "desc:A", "1"),
            rule("5", "desc:B", "2"),
            rule("6", "desc:B", "3"),
        ]
        workspaces = [
            workspace(1, "1", "A", 1, windows=1),
            workspace(5, "2", "B", 2, windows=0),
            workspace(6, "3", "B", 2, windows=0),
        ]
        clients = [client("0x222", 1)]

        moves = plan([mon_a, mon_b], rules, workspaces, clients)

        # Source slot is "1" (ws1's own rule). MonB's block has slots
        # "2" and "3" only -- no "1" -- so fall back to the lowest
        # workspace id in that block: 5.
        self.assertEqual(moves, [Move("0x222", 1, 5, moves[0].reason if moves else "")])


def block_rules(base, selector):
    """A 10-slot workspacerules block: `base`..`base+8` as ordinary slots
    "1".."9" and `base+9` as the void slot "0", matching the real config."""
    rules = [rule(str(base + i), selector, str(i + 1)) for i in range(9)]
    rules.append(rule(str(base + 9), selector, "0"))
    return rules


class Rule6SlotAllocationTests(unittest.TestCase):
    """Slot allocation is one pass over the whole plan, not an independent
    same-slot lookup per source workspace."""

    def test_headline_three_monitor_collapse_allocates_distinct_slots(self):
        # Monitor X (block 1-10) had windows on slots 1, 2, 6; monitor Y
        # (block 11-20) on 1, 2, 3. Both are unplugged and monitor Z
        # (block 21-30, live and empty) is what is left. X goes first and keeps
        # its own slots (21, 22, 26); Y fills the gaps (23, 24, 25).
        mon_z = monitor(3, "Z", "MonZ", disabled=False, mirror_of="none", focused=True)
        rules = (
            block_rules(1, "desc:MonX")
            + block_rules(11, "desc:MonY")
            + block_rules(21, "desc:MonZ")
        )
        workspaces = [
            workspace(1, "1", "X", 1, windows=1),
            workspace(2, "2", "X", 1, windows=1),
            workspace(6, "6", "X", 1, windows=1),
            workspace(11, "1", "Y", 2, windows=1),
            workspace(12, "2", "Y", 2, windows=1),
            workspace(13, "3", "Y", 2, windows=1),
        ]
        clients = [
            client("0xX1", 1),
            client("0xX2", 2),
            client("0xX6", 6),
            client("0xY1", 11),
            client("0xY2", 12),
            client("0xY3", 13),
        ]

        moves = plan([mon_z], rules, workspaces, clients)

        by_address = {m.address: m.target for m in moves}
        self.assertEqual(
            by_address,
            {
                "0xX1": 21,
                "0xX2": 22,
                "0xX6": 26,
                "0xY1": 23,
                "0xY2": 24,
                "0xY3": 25,
            },
        )
        # No two sources ever land on the same slot.
        self.assertEqual(len(set(by_address.values())), 6)

    def test_lower_block_wins_shared_slot_higher_block_takes_next_free(self):
        mon_z = monitor(1, "Z", "MonZ", focused=True)
        rules = (
            block_rules(1, "desc:MonA")
            + block_rules(11, "desc:MonB")
            + block_rules(21, "desc:MonZ")
        )
        workspaces = [
            workspace(1, "1", "A", 10, windows=1),
            workspace(11, "1", "B", 11, windows=1),
        ]
        clients = [client("0xA", 1), client("0xB", 11)]

        moves = plan([mon_z], rules, workspaces, clients)

        # Both sources want slot "1". Block A (base 1) sorts before block B
        # (base 11), so A keeps slot 1 (-> 21) and B is bumped to the
        # lowest free slot instead (-> 22).
        by_address = {m.address: m.target for m in moves}
        self.assertEqual(by_address, {"0xA": 21, "0xB": 22})

    def test_occupied_target_slot_is_skipped_source_takes_next_free(self):
        mon_z = monitor(1, "Z", "MonZ", focused=True)
        rules = block_rules(1, "desc:MonA") + block_rules(21, "desc:MonZ")
        workspaces = [
            workspace(1, "1", "A", 10, windows=1),  # homeless, wants slot "1"
            workspace(21, "1", "Z", 1, windows=1),  # already live on Z with its own window
        ]
        clients = [
            client("0xHOME", 1),
            client("0xOCCUPIED", 21),
        ]

        moves = plan([mon_z], rules, workspaces, clients)

        # ws21 is already home (ruled to the live monitor Z) and has its
        # own window -- it must not move, and the homeless source that
        # wanted its slot ("1" -> 21) is bumped to the lowest free slot
        # (22) instead of piling onto it.
        self.assertEqual(moves, [Move("0xHOME", 1, 22, moves[0].reason if moves else "")])
        self.assertNotIn("0xOCCUPIED", {m.address for m in moves})

    def test_overflow_shares_the_void_slot_when_block_is_full(self):
        mon_z = monitor(1, "Z", "MonZ", focused=True)
        # Target block Z has only two ordinary slots (1, 2) plus a void
        # slot (29). Four homeless sources from block A want slots 1-4.
        rules = [
            rule("21", "desc:MonZ", "1"),
            rule("22", "desc:MonZ", "2"),
            rule("29", "desc:MonZ", "0"),
            rule("1", "desc:MonA", "1"),
            rule("2", "desc:MonA", "2"),
            rule("3", "desc:MonA", "3"),
            rule("4", "desc:MonA", "4"),
        ]
        workspaces = [
            workspace(1, "1", "A", 10, windows=1),
            workspace(2, "2", "A", 10, windows=1),
            workspace(3, "3", "A", 10, windows=1),
            workspace(4, "4", "A", 10, windows=1),
        ]
        clients = [
            client("0xS1", 1),
            client("0xS2", 2),
            client("0xS3", 3),
            client("0xS4", 4),
        ]

        moves = plan([mon_z], rules, workspaces, clients)

        by_address = {m.address: m.target for m in moves}
        # ws1 and ws2 keep their own slots; ws3 and ws4 have no ordinary
        # slot free, so they overflow onto the block's void slot (29) --
        # and share it with each other.
        self.assertEqual(
            by_address, {"0xS1": 21, "0xS2": 22, "0xS3": 29, "0xS4": 29}
        )

    def test_no_void_slot_means_overflow_produces_no_move(self):
        mon_z = monitor(1, "Z", "MonZ", focused=True)
        rules = [
            rule("21", "desc:MonZ", "1"),
            rule("22", "desc:MonZ", "2"),
            # No rule with defaultName "0" -- this block has no void slot.
            rule("1", "desc:MonA", "1"),
            rule("2", "desc:MonA", "2"),
            rule("3", "desc:MonA", "3"),
        ]
        workspaces = [
            workspace(1, "1", "A", 10, windows=1),
            workspace(2, "2", "A", 10, windows=1),
            workspace(3, "3", "A", 10, windows=1),
        ]
        clients = [client("0xS1", 1), client("0xS2", 2), client("0xS3", 3)]

        moves = plan([mon_z], rules, workspaces, clients)

        by_address = {m.address: m.target for m in moves}
        # ws1 and ws2 land on their own slots. ws3 has nowhere to go --
        # both ordinary slots are taken and there is no void slot -- so it
        # produces no move at all; its windows are left where they are.
        self.assertEqual(by_address, {"0xS1": 21, "0xS2": 22})
        self.assertNotIn("0xS3", by_address)

    def test_all_windows_of_one_source_move_together(self):
        mon_z = monitor(1, "Z", "MonZ", focused=True)
        rules = block_rules(1, "desc:MonA") + block_rules(21, "desc:MonZ")
        workspaces = [workspace(6, "6", "A", 10, windows=3)]
        clients = [client("0xW1", 6), client("0xW2", 6), client("0xW3", 6)]

        moves = plan([mon_z], rules, workspaces, clients)

        self.assertEqual({m.target for m in moves}, {26})
        self.assertEqual({m.address for m in moves}, {"0xW1", "0xW2", "0xW3"})

    def test_allocation_is_deterministic_and_sorted_by_source_then_address(self):
        mon_z = monitor(1, "Z", "MonZ", focused=True)
        rules = (
            block_rules(1, "desc:MonA")
            + block_rules(11, "desc:MonB")
            + block_rules(21, "desc:MonZ")
        )
        workspaces = [
            workspace(1, "1", "A", 10, windows=1),
            workspace(6, "6", "A", 10, windows=2),
            workspace(11, "1", "B", 11, windows=1),
        ]
        # Deliberately scrambled input order.
        clients = [
            client("0xB1", 11),
            client("0xA6b", 6),
            client("0xA6a", 6),
            client("0xA1", 1),
        ]

        first = plan([mon_z], rules, workspaces, clients)
        second = plan([mon_z], rules, workspaces, clients)

        # Same input, same output every time (rule 9's sort order still
        # holds under the new allocation).
        self.assertEqual(first, second)
        self.assertEqual(
            [(m.source, m.address) for m in first],
            [(1, "0xA1"), (6, "0xA6a"), (6, "0xA6b"), (11, "0xB1")],
        )


class Rule7OneMovePerClientTests(unittest.TestCase):
    """Rule 7: one move per client on a homeless workspace; live-workspace
    and negative-workspace clients are never moved."""

    def test_only_homeless_clients_move_live_and_special_clients_are_untouched(self):
        mon_a = monitor(1, "A", "A", disabled=False, mirror_of="none", focused=True)
        rules = [rule("1", "desc:A", "1")]
        workspaces = [
            workspace(1, "1", "A", 1, windows=1),  # live, homed
            workspace(2, "2", "A", 1, windows=2),  # no rule -> homeless
        ]
        clients = [
            client("0xLIVE", 1),
            client("0xH1", 2),
            client("0xH2", 2),
            client("0xSPECIAL", -2, "special:magic"),
        ]

        moves = plan([mon_a], rules, workspaces, clients)

        addresses = {m.address for m in moves}
        self.assertEqual(addresses, {"0xH1", "0xH2"})
        self.assertTrue(all(m.target == 1 for m in moves))
        self.assertNotIn("0xLIVE", addresses)
        self.assertNotIn("0xSPECIAL", addresses)


class Rule8EmptyHomelessWorkspaceTests(unittest.TestCase):
    """Rule 8: a homeless workspace with no clients produces no moves."""

    def test_empty_homeless_workspace_produces_no_move(self):
        mon_a = monitor(1, "A", "A", disabled=True, mirror_of="none", focused=False)
        mon_b = monitor(2, "B", "B", disabled=False, mirror_of="none", focused=True)
        rules = [
            rule("1", "desc:A", "1"),
            rule("2", "desc:B", "1"),
        ]
        workspaces = [workspace(1, "1", "A", 1, windows=0)]
        clients = []

        moves = plan([mon_a, mon_b], rules, workspaces, clients)

        self.assertEqual(moves, [])


class Rule9DeterministicOrderTests(unittest.TestCase):
    """Rule 9: moves sorted by (source workspace id, window address)."""

    def test_moves_sorted_by_source_then_address(self):
        mon_a = monitor(1, "A", "A", disabled=True, mirror_of="none", focused=False)
        mon_b = monitor(2, "B", "B", disabled=False, mirror_of="none", focused=True)
        rules = [
            rule("3", "desc:A", "3"),
            rule("5", "desc:A", "5"),
            # B needs more than one slot. This test is about ordering, and a
            # single-slot block would force the two sources to overflow onto
            # each other -- which rule 6e forbids when there is no void slot,
            # making the scenario unsatisfiable for reasons unrelated to sort
            # order.
            rule("9", "desc:B", "1"),
            rule("10", "desc:B", "2"),
            rule("11", "desc:B", "3"),
        ]
        workspaces = [
            workspace(3, "3", "A", 1, windows=1),
            workspace(5, "5", "A", 1, windows=2),
            workspace(9, "1", "B", 2, windows=0),
        ]
        # Deliberately out of order.
        clients = [
            client("0xC", 3),
            client("0xB", 5),
            client("0xA", 5),
        ]

        moves = plan([mon_a, mon_b], rules, workspaces, clients)

        sources_and_addresses = [(m.source, m.address) for m in moves]
        self.assertEqual(sources_and_addresses, [(3, "0xC"), (5, "0xA"), (5, "0xB")])


class LuaProgramTests(unittest.TestCase):
    def test_empty_move_list_renders_empty_string(self):
        self.assertEqual(lua_program([]), "")

    def test_single_move_renders_exact_verified_form(self):
        moves = [Move(address="0x55f2a3b4c5d6", source=5, target=21, reason="homeless")]
        expected = (
            'hl.dispatch(hl.dsp.window.move({ window = "address:0x55f2a3b4c5d6", '
            "workspace = 21, follow = false }))"
        )
        self.assertEqual(lua_program(moves), expected)

    def test_multiple_moves_render_one_statement_per_line_in_given_order(self):
        moves = [
            Move("0xAAA", 1, 2),
            Move("0xBBB", 3, 4),
        ]
        expected = "\n".join(
            [
                'hl.dispatch(hl.dsp.window.move({ window = "address:0xAAA", workspace = 2, follow = false }))',
                'hl.dispatch(hl.dsp.window.move({ window = "address:0xBBB", workspace = 4, follow = false }))',
            ]
        )
        self.assertEqual(lua_program(moves), expected)


if __name__ == "__main__":
    unittest.main()
