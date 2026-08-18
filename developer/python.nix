##############################################################################
#
# Python Toolchain
#
# Purpose
# -------
# Python runtime and development tools including package management,
# linting, formatting, type checking, and interactive shells.
#
# All python packages are overridden to NOT build documentation. Building
# Sphinx/man docs for python packages pulls in a large doc toolchain and
# adds significant time to every `nixos-rebuild switch`, for zero runtime
# benefit. Documentation outputs are dropped and `share/doc` is removed
# post-install.
#
# Ownership
# ---------
# environment.systemPackages for Python tooling
#
##############################################################################

{ pkgs, ... }:

let
  py = pkgs.python313;

  # Drop documentation from a python package: removes the man/doc outputs
  # (so their build phase never runs) and strips any share/doc that a
  # build hook emits anyway.
  stripDocs = p: p.overrideAttrs (o: {
    outputs = builtins.filter (x: x != "doc" && x != "man") (o.outputs or [ "out" ]);
    postInstall = (o.postInstall or "") + ''
      rm -rf "$out/share/doc" "$out/share/man" "$out/man" 2>/dev/null || true
    '';
  });

  # python with doc-stripped packages always available
  pythonUnDoc = py.override {
    packageOverrides = pself: psuper: {
      ipython = stripDocs psuper.ipython;
    };
  };

  ipython = pythonUnDoc.pkgs.ipython;
  pytest = stripDocs py.pkgs.pytest;
in
{
  environment.systemPackages = with pkgs; [
    python313
    ipython
    pytest
    uv
    ruff
    black
    mypy
  ];
}
