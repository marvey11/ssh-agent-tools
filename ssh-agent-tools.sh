# ------------------------------------------------------------------------------------------------
#
# ssh-agent helper script.
#
# Will check for existing ssh-agent processes and reuse them if possible.
#
# Source in ~/.bashrc
#
# File any issue here: https://github.com/marvey11/ssh-agent-tools/issues
#
# Or, better yet, fork the repository, fix what's not working and create a pull request.
#
# ------------------------------------------------------------------------------------------------
#
# MIT License
#
# Copyright (c) 2020 Marco Wegner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ------------------------------------------------------------------------------------------------


#
# Checks whether a single process ID represents an ssh-agent process
#
# Returns the process number on sucess, or nothing on error
#
# Required parameter: process ID to check
#
function ssha-check-process()
{
    local pid=$1
    local result=$(ps -u $(id -un) -s | awk '/\/usr\/bin\/ssh-agent$/ { print $1; }' | grep "^${pid}$")
    echo "${result}"
}

#
# Checks whether a single ssh-agent socket in ${TMPDIR} is still good or not.
# Basically, we try to find out whether there is an actual process connected to the socket.
#
# Also performs clean-up if the socket is found to be stale.
#
# Required parameter: full path to the socket
#
function ssha-check-sock()
{
    local sock_pid_file=$1
    local sock_pid=${pid_file##*.}

    # for some reason the socket PID number and the actual process ID are off by 1
    # (tested so far only on Windows 10 with git bash)
    local pid_actual=$((sock_pid+1))

    local found=$(ssha-check-process ${pid_actual})

    if [[ -n ${found} ]]; then
        export SSH_AGENT_PID=${pid_actual}
        export SSH_AUTH_SOCK=${sock_pid_file}
        # success, we're done
        return
    fi

    # cleaning up stale socket
    echo "Removing stale socket ${sock_pid_file}"
    sock_pid_dir=$(dirname ${sock_pid_file})
    rm ${sock_pid_file}
    rmdir ${sock_pid_dir}
}

#
# Checks all the ssh-agent sockets in ${TMPDIR}.
#
# This function requires to have the caller checked before whether there are any ssh-agent
# sockets at all; otherwise the find command will give an error
#
function ssha-evaluate-sockets()
{
    for pid_file in $(find ${TMPDIR}/ssh-* -name "agent.[0-9]*" -type s -uid $(id -u))
    do
        ssha-check-sock ${pid_file}
    done
}

#
# Adds all the identity files discovered in ${HOME}/.ssh
#
# Important note: doesn't take pass phrases into account!
#
function ssha-add-identities()
{
    [[ -d ${HOME}/.ssh/ ]] &&
    {
        # ssh-add the identity files in ~/.ssh
        # --> find names starting with "id_" but ignoring the *.pub files
        find ${HOME}/.ssh/ -name "id_*" -a ! -name "*.pub" -type f | xargs ssh-add
    }
}

SSHA_SUCCESS=0

# first, check whether the SSH_AGENT is actually good
if [[ -n ${SSH_AGENT_PID} ]]; then
    SSHA_FOUND=$(ssha-check-process ${SSH_AGENT_PID})

    if [[ -n ${SSHA_FOUND} ]]; then
        # there is a process behind the PID, so we'll check whether there is socket, too

        if [[ -n ${SSH_AUTH_SOCK} ]]; then
            ls ${SSH_AUTH_SOCK} 2>&1 1>/dev/null && {
                # SSH_AUTH_SOCK seems good as well

                # let's check for identities and maybe re-add them if necessary
                ssh-add -l >/dev/null || ssha-add-identities

                SSHA_SUCCESS=1
            }
        fi
    fi

    if [[ ${SSHA_SUCCESS} -eq 0 ]]; then
        echo "Removing stale SSH_AGENT_PID"
        unset SSH_AGENT_PID
        unset SSH_AUTH_SOCK
    fi
fi

if [[ ${SSHA_SUCCESS} -eq 0 ]]; then
    # try to find sockets in ${TMPDIR}
    SSHA_FOUND=$(find ${TMPDIR} -name "ssh-*")
    if [[ -n ${SSHA_FOUND} ]]; then
        # okay, so we found sockets in ${TMPDIR}; let's check them
        ssha-evaluate-sockets
    fi

    # if the agent still isn't found (e.g. all the sockets were stale), we finally start it
    if [[ -z ${SSH_AGENT_PID} ]]; then
        eval $(ssh-agent) && ssha-add-identities
    fi
fi

unset -f ssha-check-process ssha-check-sock ssha-evaluate-sockets ssha-add-identities
unset SSHA_FOUND SSHA_SUCCESS
