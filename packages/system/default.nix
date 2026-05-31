{ pkgs }:

(import ../terminal { inherit pkgs; })
+ (import ../gui { inherit pkgs; })
