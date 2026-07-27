##############################################################################
#
# Kotlin / JVM Toolchain
#
# Purpose
# -------
# Kotlin compiler, language server, build tools, and Kotlin/Native support.
#
# Ownership
# ---------
# environment.systemPackages for Kotlin tooling
#
##############################################################################

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kotlin
    kotlin-language-server
    gradle
    kotlin-native
  ];
}
