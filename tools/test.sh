#!/bin/sh
# Runs the off-device BrightScript tests. Exits non-zero if any check fails.
# The tests run against a small package root: the app's components (for the bundled
# open-movies list) plus tests/fixtures, both reachable through pkg:/.
BRS=node_modules/.bin/brs
C=app/components
ROOT=build/testroot

rm -rf "$ROOT"
mkdir -p "$ROOT"
ln -s ../../app/components "$ROOT/components"
ln -s ../../tests/fixtures "$ROOT/fixtures"

run() {
  out=$("$BRS" --root "$ROOT" "$@" 2>&1 | grep -v "extends unknown component")
  echo "$out"
  echo "$out" | grep -q "^ALL PASSED" || status=1
}

status=0
run $C/common/Utils.brs $C/common/Tracks.brs $C/common/Playback.brs $C/common/Config.brs $C/common/Media.brs $C/common/Rank.brs \
    tests/fake_registry.brs $C/common/Prefs.brs $C/common/Progress.brs \
    $C/tasks/Http.brs $C/tasks/TmdbParse.brs $C/tasks/Resolve.brs $C/sources/Sources.brs $C/sources/OpenMovies.brs \
    tests/core_test.brs
exit $status
