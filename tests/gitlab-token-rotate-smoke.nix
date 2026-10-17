##############################################################################
#
# GitLab Token Rotation — smoke test
#
# Purpose
# -------
# Exercises scripts/gitlab-token-rotate.sh against a mock GitLab API and
# asserts the rotation decision:
#   - far-future expiry  -> no rotation request
#   - near expiry        -> rotation request issued
#
# The publish path (sops re-encrypt, git push, reconciler trigger) is skipped
# via ROTATE_DRY_RUN=1.
#
##############################################################################

{ pkgs, ... }:

let
  rotateScript = ../scripts/gitlab-token-rotate.sh;

  mockApi = pkgs.writeText "mock-gitlab-api.py" ''
    import http.server, json

    LOG = "/tmp/api.log"
    EXPIRY = "/tmp/expiry.txt"

    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def _send(self, code, payload):
            body = json.dumps(payload).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path.endswith("/personal_access_tokens/self"):
                with open(EXPIRY) as f:
                    exp = f.read().strip()
                self._send(200, {"id": 28526970, "name": "prague",
                                 "expires_at": exp, "scopes": ["api", "self_rotate"]})
            else:
                self._send(404, {"error": "not found"})

        def do_POST(self):
            length = int(self.headers.get("Content-Length", "0"))
            self.rfile.read(length)
            if self.path.endswith("/personal_access_tokens/self/rotate"):
                with open(LOG, "a") as f:
                    f.write("ROTATE\n")
                self._send(200, {"id": 999, "token": "glpat-NEWTESTTOKENVALUE1234567",
                                 "expires_at": "2030-01-01"})
            else:
                self._send(404, {"error": "not found"})

    http.server.HTTPServer(("127.0.0.1", 8099), H).serve_forever()
  '';

  runEnv = "GITLAB_API_BASE=http://127.0.0.1:8099/api/v4 "
    + "GITLAB_TOKEN_FILE=/tmp/token "
    + "GITLAB_REPO=example.invalid "
    + "NOTIFY_DISABLE=1 "
    + "ROTATE_DRY_RUN=1";
in
pkgs.testers.nixosTest {
  name = "gitlab-token-rotate-smoke";

  nodes.machine = {
    environment.systemPackages = with pkgs; [
      bash
      curl
      jq
      coreutils
      python3
    ];

    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    machine.succeed("echo glpat-testtoken > /tmp/token")
    machine.succeed("date -d '+365 days' +%F > /tmp/expiry.txt")
    machine.succeed(": > /tmp/api.log")

    machine.succeed("nohup python3 ${mockApi} >/tmp/mock.log 2>&1 &")
    machine.wait_until_succeeds(
        "curl -fsS http://127.0.0.1:8099/api/v4/personal_access_tokens/self >/dev/null"
    )

    # Far future: no rotation.
    out = machine.succeed("${runEnv} bash ${rotateScript}")
    assert "nothing to do" in out, out
    machine.fail("grep -q ROTATE /tmp/api.log")

    # Near expiry: rotation requested.
    machine.succeed("date -d '+2 days' +%F > /tmp/expiry.txt")
    out = machine.succeed("${runEnv} bash ${rotateScript}")
    assert "dry-run" in out, out
    machine.succeed("grep -q ROTATE /tmp/api.log")
  '';
}
