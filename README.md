# ssh-agent-tools

Helper tools useful for working with the SSH Agent.

Will check for existing `ssh-agent` processes and reuse them if possible.

The reason behind this script is that a huge number of stale `ssh-agent` processes can accumulate if you're simply just running `eval $(ssh-agent)` every time you're opening a Git Bash terminal. This script can actually reuse a lot of these no-so-stale processes without having to start a new one.

# How To Use

All that's necessary is to source the script file `ssh-agent-tools.sh` -- for example from `.bashrc`. The rest is automatic.

# How It Works

First, the script will check the environment variable `SSH_AGENT_PID`. If the variable is set, the script will then check whether there is an actual `ssh-agent` process behind the process ID. If that's the case, then the environment variable `SSH_AUTH_SOCK` is checked next. If that one is fine as well, then the identities found in `~/.ssh` are simply added. If either of these steps failed for any reason, both of the environment variables are unset. In that case you will see a message like:
```
Removing stale SSH_AGENT_PID
```

The next step is to check for socket files in `/tmp`. If any of those files points to a valid process, then the `SSH_AGENT_PID` and `SSH_AUTH_SOCK` environment variables are set according to the process ID. If, during the socket file discovery, any stale socket file were found, then they will be removed and you will see one or more messages like:
```
Removing stale socket /tmp/ssh-vpP0nkSM33dz/agent.118
```

Only if all that fails, the the `eval $(ssh-agent)` command is actually run and the identities are added.

# Known Limitations

If adding an identity requires a passphrase, then the way the identities are added at the moment might actually not work as expected (or at all).

Also, this script has so far only been tested and used on a Windows system in the scope of Git Bash. Running it on Linux may have unexpected consequences.
