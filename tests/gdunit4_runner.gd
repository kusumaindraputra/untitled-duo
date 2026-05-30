# GdUnit4 v6 test runner — invoked by CI and /smoke-check
# Usage: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
#
# GdUnit4 v6 is run directly via GdUnitCmdTool.gd — this file documents the CI command.
# The gdUnit4-action GitHub Action handles CI automatically (see .github/workflows/tests.yml).
#
# To run a specific suite locally:
#   godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
#         -a res://tests/unit/prana-data/game_enums_test.gd --ignoreHeadlessMode
