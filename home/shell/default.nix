# home/default.nix

{
  imports = [
    ./ivali.nix
    ./fonts.nix
    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}