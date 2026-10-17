##############################################################################
#
# Overlay: collabora-desktop coda-qt link fix
#
# Purpose
# -------
# Fix an undefined-reference link failure when building
# collabora-desktop 25.04.9.2-2 from source.
#
# Why this exists
# ---------------
# collabora-desktop is absent from cache.nixos.org for the pinned
# nixos-unstable revision, so Nix builds it from source. The bundled coda-qt
# target then fails to link:
#
#   undefined reference to 'http::Response::readData(char const*, long)'
#   undefined reference to 'StreamSocket::send(http::Request&)'
#
# which cascades to system-path and nixos-system-<host>, so
# `nixos-rebuild switch` cannot complete.
#
# Upstream fixed this on nixpkgs master after the pinned revision by adding
# 0002-fix-coda-qt-link.patch to pkgs/by-name/co/collabora-desktop (commit
# c2342c171205, "collabora-desktop: fix build"). The pinned revision does not
# yet contain it, so the same patch is vendored here and appended to the
# derivation's patch list.
#
# Removal condition
# -----------------
# Delete this overlay (and lib/overlays/patches/collabora-desktop/) once the
# nixpkgs pin includes upstream commit c2342c171205, i.e. once the package
# already lists ./0002-fix-coda-qt-link.patch in its patches.
#
# Ownership
# ---------
# nixpkgs collabora-desktop patch list only
#
# Does NOT Own
# ------------
# - collabora-desktop source, version or runtime behaviour
# - libreoffice-collabora or any other package
#
##############################################################################

_final: prev: {
  collabora-desktop = prev.collabora-desktop.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/collabora-desktop/0002-fix-coda-qt-link.patch
    ];
  });
}
