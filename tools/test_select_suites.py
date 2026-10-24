"""Regression checks for the pull-request suite selection (tools/select_suites.py), without running Godot."""
import pathlib
import tempfile
import unittest

from ci_shards import ROOT, discover, selected_layout
from select_suites import SMOKE, select


class SelectionTests(unittest.TestCase):
    def repo(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = pathlib.Path(temp.name)
        files = {
            "project.godot": '[autoload]\n\nState="*res://scripts/state/State.gd"\n',
            "scripts/state/State.gd": "extends Node\nvar a = Alpha\n",
            "scripts/sim/Alpha.gd": "class_name Alpha\nextends RefCounted\nvar b = preload(\"res://scripts/sim/Deep.gd\")\n",
            "scripts/sim/Deep.gd": "extends RefCounted\n",
            "scripts/sim/Beta.gd": "class_name Beta\nextends RefCounted\n",
            "scripts/sim/Lonely.gd": "extends RefCounted\n",
            "scripts/ui/Screen.gd": "extends Control\n",
            "scenes/Screen.tscn": '[ext_resource type="Script" path="res://scripts/ui/Screen.gd" id="1"]\n',
            "tests/run_a_tests.gd": 'var s = load("res://tests/test_a.gd")\n',
            "tests/test_a.gd": 'var x = load("res://scripts/sim/Alpha.gd")\n',
            "tests/run_b_tests.gd": 'var s = load("res://tests/test_b.gd")\n',
            "tests/test_b.gd": "var x = Beta.new()\nvar scene = load(\"res://scenes/Screen.tscn\")\n",
            "tests/run_smoke_tests.gd": "# nothing\n",
            "tests/functions_ran.gd": "",
            "data/players.csv": "",
        }
        for name, text in files.items():
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            (root / name).write_text(text)
        return root

    def pick(self, *changed):
        return select(list(changed), root=self.repo(), smoke=("smoke",))

    def test_a_changed_script_selects_its_suites_and_not_unrelated_ones(self):
        self.assertEqual(self.pick("scripts/sim/Alpha.gd"), (["a", "smoke"], ""))
        self.assertEqual(self.pick("scripts/sim/Beta.gd"), (["b", "smoke"], ""))  # reached by class_name

    def test_a_scene_and_its_script_select_the_suite_that_loads_the_scene(self):
        self.assertEqual(self.pick("scenes/Screen.tscn")[0], ["b", "smoke"])
        self.assertEqual(self.pick("scripts/ui/Screen.gd")[0], ["b", "smoke"])

    def test_a_script_nothing_names_selects_only_the_smoke_set(self):
        self.assertEqual(self.pick("scripts/sim/Lonely.gd"), (["smoke"], ""))

    def test_a_script_two_hops_away_is_left_to_main(self):
        # Deep.gd is called by Alpha.gd, which suite a names; suite a does not name Deep.gd itself.
        self.assertEqual(self.pick("scripts/sim/Deep.gd"), (["smoke"], ""))

    def test_a_test_file_selects_its_own_suite(self):
        self.assertEqual(self.pick("tests/test_b.gd")[0], ["b", "smoke"])
        self.assertEqual(self.pick("tests/run_a_tests.gd.uid")[0], ["a", "smoke"])

    def test_data_and_untraceable_files_select_everything(self):
        everything = ["a", "b", "smoke"]
        for path in ("data/players.csv", "project.godot", "tools/run_tests.sh", "tests/functions_ran.gd",
                     "tests/tap.gd", ".github/workflows/tests.yml", "tools/select_suites.py", "export_presets.cfg",
                     "scripts/state/State.gd"):  # the last is an autoload
            self.assertEqual(self.pick(path)[0], everything, path)
            self.assertTrue(self.pick(path)[1], path)

    def test_a_deleted_file_selects_everything(self):
        self.assertEqual(self.pick("scripts/sim/Gone.gd")[0], ["a", "b", "smoke"])

    def test_docs_only_selects_the_smoke_set(self):
        self.assertEqual(self.pick("docs/ROADMAP.md", "README.md"), (["smoke"], ""))

    def test_one_full_wall_change_among_scripts_wins(self):
        self.assertEqual(self.pick("scripts/sim/Beta.gd", "data/players.csv")[0], ["a", "b", "smoke"])


class RealRepoTests(unittest.TestCase):
    def test_the_smoke_set_exists(self):
        self.assertTrue(set(SMOKE) <= set(discover()), SMOKE)

    def test_a_sim_script_selects_its_suite_and_not_unrelated_ones(self):
        suites, why = select(["scripts/sim/Draft.gd"])
        self.assertEqual(why, "")
        self.assertIn("draft", suites)
        self.assertTrue(set(SMOKE) <= set(suites))
        self.assertLess(len(suites), len(discover()))
        self.assertNotIn("scroll", suites)

    def test_data_selects_every_suite(self):
        self.assertEqual(select(["data/players_2026.csv"])[0], discover())

    def test_project_godot_and_the_workflow_select_every_suite(self):
        for path in ("project.godot", ".github/workflows/tests.yml", "tools/run_tests.sh", "tests/tap.gd"):
            self.assertEqual(select([path])[0], discover(), path)

    def test_a_selection_packs_into_few_shards_and_loses_no_suite(self):
        suites = select(["scripts/sim/Draft.gd"])[0]
        shards = selected_layout(suites)
        self.assertEqual(sorted(s for _, names in shards for s in names), sorted(suites))
        self.assertLessEqual(len(shards), 12)

    def test_main_runs_the_full_wall(self):
        # Only a pull request (or a hand-started run that names files) picks suites; a push to main
        # leaves `files` empty, so the plan job keeps the whole layout and records no partial run.
        text = (ROOT / ".github/workflows/tests.yml").read_text()
        self.assertIn('if [ "${{ github.event_name }}" = pull_request ]; then files=', text)
        self.assertIn('if [ "${{ github.event_name }}" = workflow_dispatch ]; then files="$PRETEND"', text)
        self.assertIn('if [ -n "$files" ]; then', text)
        self.assertIn("needs.plan.outputs.partial != 'true'", text)  # a partial run never lets main skip its shards


if __name__ == "__main__":
    unittest.main()
