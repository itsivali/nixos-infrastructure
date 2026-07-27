##############################################################################
#
# Development Aliases
#
# Purpose
# -------
# Developer tool shortcuts for Kubernetes, Terraform, Docker, Go,
# databases, clipboard, and general productivity.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for development tools
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    # ── Clipboard ────────────────────────────────────────────────────────
    clip = "wl-copy";
    cclip = "wl-paste";
    cclear = "wl-copy --clear";

    # ── Kubernetes ───────────────────────────────────────────────────────
    k = "kubectl";
    kgp = "kubectl get pods";
    kgn = "kubectl get nodes";
    kga = "kubectl get all";
    kdf = "kubectl describe";
    klo = "kubectl logs";
    kex = "kubectl exec -it";
    kaf = "kubectl apply -f";
    kdl = "kubectl delete";
    kns = "kubectl config set-context --current --namespace";

    # ── Helm ─────────────────────────────────────────────────────────────
    hi = "helm install";
    hs = "helm search repo";
    hl = "helm list";
    hu = "helm upgrade";
    hd = "helm uninstall";

    # ── Terraform / OpenTofu ─────────────────────────────────────────────
    tf = "terraform";
    tfi = "terraform init";
    tfp = "terraform plan";
    tfa = "terraform apply";
    tfd = "terraform destroy";
    tfst = "terraform state list";
    tftr = "terraform import";
    tfcl = "terraform console";
    tofu = "opentofu";

    # ── Ansible ──────────────────────────────────────────────────────────
    an = "ansible";
    ap = "ansible-playbook";

    # ── Docker ───────────────────────────────────────────────────────────
    d = "docker";
    dc = "docker compose";
    dps = "docker ps";
    dpa = "docker ps -a";
    dl = "docker logs";
    dex = "docker exec -it";
    di = "docker images";
    dpr = "docker system prune";

    # ── Go ───────────────────────────────────────────────────────────────
    gob = "go build";
    gor = "go run";
    got = "go test";
    gom = "go mod tidy";
    gow = "go work";

    # ── Databases ────────────────────────────────────────────────────────
    pg = "pgcli";
    vr = "valkey-cli";

    # ── General Dev ──────────────────────────────────────────────────────
    ff = "fastfetch";
    lg = "lazygit";
    bt = "btop";
    rg = "rg";
    f = "fd";
    v = "nvim";
    vi = "nvim";
    reload = "exec zsh";
    py = "python";
    serve = "python -m http.server";
    json = "jq";
    tldr = "tldr";
  };
}
