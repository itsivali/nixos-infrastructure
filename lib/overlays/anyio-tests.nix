##############################################################################
#
# Overlay: anyio test quarantine
#
# Purpose
# -------
# Work around an upstream regression in python3.12-anyio-4.14.2 that makes the
# derivation fail to build, breaking every consumer that pulls it in (notably
# apostrophe via the levenshtein/rapidfuzz chain).
#
# Why this exists
# ---------------
# python3.12-anyio-4.14.2 is absent from cache.nixos.org for nixos-unstable
# (checked across the Sep/Oct 2026 revisions), so Nix falls back to building it
# from source. Its test suite then fails deterministically:
#
#   tests/streams/test_tls.py::test_tls_connectable
#     ValueError: server_hostname can only be specified in client mode
#   tests/test_fileio.py::{test_glob_recurse_symlinks,test_rglob}
#     unraisable exception warnings
#
# The failure is unrelated to this repository and cascades through
# pytest-subprocess, scikit-build-core, levenshtein and apostrophe up to the
# system closure, so `nixos-rebuild switch` cannot complete.
#
# This overlay disables only the affected test names, mirroring what nixpkgs
# would record in `disabledTests`. Every other check in the suite still runs.
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
      });
    })
  ];
}
