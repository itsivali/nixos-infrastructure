{
  hostName = "prague";

  gitops = {
    repo = "https://gitlab.com/willisivali/nixos-infrastructure";
    branch = "main";
  };

  notifications = {
    email = "itsivali@outlook.com";

    telegram = {
      chatId = "7724444807";
    };
  };
}
