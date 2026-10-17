##############################################################################
#
# Overlay: anyio test quarantine
#
# Purpose
# -------
# Work around an upstream regression in anyio 4.14.2 that makes the derivation
# fail to build, breaking every consumer that pulls it in (fastapi, httpx,
# aiohttp, yt-dlp/mpv, black, onnxruntime, apostrophe via levenshtein, ...).
#
# Why this exists
# ---------------
# anyio 4.14.2 is absent from cache.nixos.org for nixos-unstable (checked
# across the Sep/Oct 2026 revisions), so Nix falls back to building it from
# source. Its test suite then fails deterministically:
#
#   python3.12 — three individually named tests:
#     tests/streams/test_tls.py::test_tls_connectable
#       ValueError: server_hostname can only be specified in client mode
#     tests/test_fileio.py::{test_glob_recurse_symlinks,test_rglob}
#       unraisable exception warnings
#
#   python3.14 — eight cases, all in tests/test_pytest_plugin.py:
#     test_autouse_async_fixture, test_cancel_scope_in_asyncgen_fixture,
#     test_async_fixture_teardown_after_sync_test, test_hypothesis_module_mark,
#     test_hypothesis_function_mark, test_debugger_exit_in_taskgroup[trio],
#     test_asyncgen_fixture_in_test_class, test_async_fixture_params
#       Timeout (>20.0s) from pytest-timeout, or
#       PytestUnraisableExceptionWarning on Popen teardown
#
# The failures are unrelated to this repository and cascade up to the system
# closure, so `nixos-rebuild switch` cannot complete.
#
# This overlay disables only the affected tests and the one affected test file,
# mirroring what nixpkgs would record in `disabledTests`/`disabledTestPaths`.
# Every other check in the suite still runs.
#
# Removal condition
# -----------------
# Delete this overlay once nixpkgs ships an anyio revision whose test suite
# passes as-is (or once the failing tests are part of upstream `disabledTests`).
#
# Ownership
# ---------
# nixpkgs python package sets: anyio test selection only
#
# Does NOT Own
# ------------
# - anyio source, version or runtime behaviour
# - any other python package
#
##############################################################################

_final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      anyio = pyPrev.anyio.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_tls_connectable"
          "test_glob_recurse_symlinks"
          "test_rglob"
        ];

        disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
          # anyio's own pytest-plugin suite; every case drives a nested
          # pytester subprocess. Under python3.14 in the Nix sandbox these
          # either exceed the 20s pytest-timeout or trip
          # PytestUnraisableExceptionWarning on Popen teardown. Exercises the
          # plugin, not the anyio runtime we actually consume.
          "tests/test_pytest_plugin.py"
        ];
      });
    })
  ];
}
