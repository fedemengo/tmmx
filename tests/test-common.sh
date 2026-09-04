#!/bin/sh

set -eu

TMMX_TEST_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmux() {
  [ "$1" = list-sessions ] || return 1
  printf '30|remote-wrapper|1|target-host|\n25|remote-deploy|1|deploy@target-host|\n20|local-work|||\n|fresh|||\n10|~tmmx|||1\n'
}
date() { printf 'time-%s\n' "$2"; }
. "$TMMX_TEST_ROOT/scripts/common.sh"

actual=$(tmmx_list_sessions '')
expected=$(printf '@target-host\t30\ttime-30\tremote-wrapper\n@deploy@target-host\t25\ttime-25\tremote-deploy\nlocal-work\t20\ttime-20\tlocal-work\nfresh\t0\tnever\tfresh')
[ "$actual" = "$expected" ]

actual_host=$(tmmx_list_host_sessions '')
expected_host=$(printf 'local-work\t20\ttime-20\tlocal-work\nfresh\t0\tnever\tfresh')
[ "$actual_host" = "$expected_host" ]

actual_manager=$(tmmx_list_manager_sessions '' plink)
expected_manager=$(printf '@target-host\t30\ttime-30\tremote-wrapper\ndeploy@target-host\t25\ttime-25\tremote-deploy\n@plink - local-work\t20\ttime-20\tlocal-work\n@plink - fresh\t0\tnever\tfresh')
[ "$actual_manager" = "$expected_manager" ]

actual_manager_host=$(tmmx_list_manager_sessions '' plink host)
expected_manager_host=$(printf '@target-host\t30\ttime-30\tremote-wrapper\ndeploy@target-host\t25\ttime-25\tremote-deploy\n@plink [local]\t20\ttime-20\tlocal-work')
[ "$actual_manager_host" = "$expected_manager_host" ]

actual_manager_no_local=$(tmmx_list_manager_sessions '' plink none)
expected_manager_no_local=$(printf '@target-host\t30\ttime-30\tremote-wrapper\ndeploy@target-host\t25\ttime-25\tremote-deploy')
[ "$actual_manager_no_local" = "$expected_manager_no_local" ]

[ "$(tmmx_selection "$(printf 'query\nlabel\ttime\ttarget')")" = target ]
ansi_escape=$(printf '\033')
formatted=$(printf 'short\t100\ttime-1\ttarget-1\nlonger\t1\ttime-2\ttarget-2\n' | TMMX_NOW=100 TMMX_PICKER_COLUMNS=30 "$TMMX_TEST_ROOT/scripts/format-picker.sh" | sed "s/${ansi_escape}\\[[0-9;]*m//g")
expected_formatted=$(printf '%-16s\ttime-1\ttarget-1\n%-16s\ttime-2\ttarget-2' short longer)
[ "$formatted" = "$expected_formatted" ]

formatted_narrow=$(printf 'short\t100\ttime-1\ttarget-1\n' | TMMX_NOW=100 TMMX_PICKER_COLUMNS=15 "$TMMX_TEST_ROOT/scripts/format-picker.sh" | sed "s/${ansi_escape}\\[[0-9;]*m//g")
[ "$formatted_narrow" = "$(printf ' \ttime-1\ttarget-1')" ]

formatted_tiny=$(printf 'long-session\t100\t2026-08-31 14:54\ttarget-1\n' | TMMX_NOW=100 TMMX_PICKER_COLUMNS=20 "$TMMX_TEST_ROOT/scripts/format-picker.sh" | sed "s/${ansi_escape}\\[[0-9;]*m//g")
[ "$formatted_tiny" = "$(printf '\t2026-08-31 14:54\ttarget-1')" ]

[ "$(tmmx_remote_session_name db.internal)" = __tmmx_remote__db_internal ]
[ "$(tmmx_remote_session_name db:internal)" = __tmmx_remote__db_internal ]
[ "$(tmmx_remote_session_name deploy@db.internal)" = __tmmx_remote__deploy@db_internal ]
[ "$(tmmx_session_name web.dev)" = web_dev ]
tmmx_valid_session_name plain-name
! tmmx_valid_session_name "$(printf 'bad|name')"
! tmmx_valid_session_name "$(printf 'bad\tname')"
printf '%s\n' 'error connecting to /tmp/tmux-1000/default (No such file or directory)' | tmmx_no_server_error
printf '%s\n' 'no server running on /tmp/tmux-1000/default' | tmmx_no_server_error
! printf '%s\n' 'Permission denied (publickey).' | tmmx_no_server_error

# ssh user@host command parsing and validation.
[ "$(tmmx_ssh_command_destination 'ssh deploy@target-host')" = deploy@target-host ]
[ "$(tmmx_ssh_command_destination 'ssh   deploy@target-host  ')" = deploy@target-host ]
[ "$(tmmx_ssh_command_destination 'ssh target-host')" = target-host ]
[ "$(tmmx_ssh_command_destination 'ssh')" = '' ]
! tmmx_ssh_command_destination 'sshd'
! tmmx_ssh_command_destination 'deploy@target-host'
! tmmx_ssh_command_destination '@target-host'
tmmx_valid_ssh_destination deploy@target-host
tmmx_valid_ssh_destination deploy_1@db.internal
tmmx_valid_ssh_destination target-host
! tmmx_valid_ssh_destination ''
! tmmx_valid_ssh_destination @target-host
! tmmx_valid_ssh_destination deploy@
! tmmx_valid_ssh_destination deploy@jump@target-host
! tmmx_valid_ssh_destination 'deploy@target-host -p 2222'
! tmmx_valid_ssh_destination "deploy@target-host'; rm -rf /"
[ "$(tmmx_ssh_user deploy@target-host)" = deploy ]
[ "$(tmmx_ssh_user target-host)" = '' ]
[ "$(tmmx_ssh_host deploy@target-host)" = target-host ]
[ "$(tmmx_ssh_host target-host)" = target-host ]

# ssh config hosts: file order, Include followed, wildcards and duplicates dropped.
config_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmmx-test.XXXXXX")
mkdir -p "$config_dir/.ssh/conf.d"
printf 'Host alpha beta # trailing comment\nHost *.internal\nInclude conf.d/*.conf\nHost !bad ?q\nHost alpha\n' > "$config_dir/.ssh/config"
printf 'Host gamma\n  HostName gamma.example\n' > "$config_dir/.ssh/conf.d/extra.conf"
printf 'Include %s/.ssh/config\nHost target-host\n' "$config_dir" > "$config_dir/.ssh/conf.d/loop.conf"
[ "$(HOME=$config_dir tmmx_ssh_config_hosts)" = "$(printf 'alpha\nbeta\ngamma\ntarget-host')" ]
[ "$(tmmx_ssh_config_hosts /nonexistent/config)" = '' ]

# Candidates: sessions only until the query names a destination; then hosts from
# the config without a wrapper for that exact destination.
HOME=$config_dir
[ "$(tmmx_list_manager_candidates '' plink all '')" = "$expected_manager" ]
[ "$(tmmx_list_manager_candidates '' plink all 'loc')" = "$expected_manager" ]
host_rows=$(printf '@alpha\t0\tssh config\tssh:alpha\n@beta\t0\tssh config\tssh:beta\n@gamma\t0\tssh config\tssh:gamma')
[ "$(tmmx_list_manager_candidates '' plink all '@')" = "$(printf '%s\n%s' "$expected_manager" "$host_rows")" ]
[ "$(tmmx_list_manager_candidates '' plink all '@alp')" = "$(printf '%s\n%s' "$expected_manager" "$host_rows")" ]
[ "$(tmmx_list_manager_candidates '' plink all 'ssh al')" = "$expected_manager" ]
deploy_rows=$(printf 'deploy@alpha\t0\tssh config\tssh:deploy@alpha\ndeploy@beta\t0\tssh config\tssh:deploy@beta\ndeploy@gamma\t0\tssh config\tssh:deploy@gamma')
[ "$(tmmx_list_manager_candidates '' plink all 'deploy@')" = "$(printf '%s\n%s' "$expected_manager" "$deploy_rows")" ]
ops_rows=$(printf 'ops@alpha\t0\tssh config\tssh:ops@alpha\nops@beta\t0\tssh config\tssh:ops@beta\nops@gamma\t0\tssh config\tssh:ops@gamma\nops@target-host\t0\tssh config\tssh:ops@target-host')
[ "$(tmmx_list_manager_candidates '' plink all 'ops@')" = "$(printf '%s\n%s' "$expected_manager" "$ops_rows")" ]
[ "$(tmmx_list_manager_candidates '' plink all 'bad user@')" = "$expected_manager" ]
rm -rf "$config_dir"
[ "$(tmmx_selection "$(printf 'query\nlabel\tssh config\tssh:deploy@alpha')")" = ssh:deploy@alpha ]

# Rows without a timestamp show their text instead of never.
formatted_text=$(printf '@alpha\t0\tssh config\tssh:alpha\n' | TMMX_NOW=100 TMMX_PICKER_COLUMNS=40 "$TMMX_TEST_ROOT/scripts/format-picker.sh" | sed "s/${ansi_escape}\\[[0-9;]*m//g")
[ "$formatted_text" = "$(printf '%-22s\tssh config\tssh:alpha' @alpha)" ]

# Labels: @host for alias targets, user@host for explicit users. Colors match the
# full destination first and fall back to the host part.
[ "$(tmmx_host_label target-host)" = @target-host ]
[ "$(tmmx_host_label deploy@target-host)" = deploy@target-host ]
tmux() {
  [ "$1" = show-options ] && [ "$3" = @tmmx_host_colors ] || return 1
  printf 'target-host=#ff0000,ops@target-host=#00ff00\n'
}
red_start=$(printf '\033[38;2;255;0;0m'); green_start=$(printf '\033[38;2;0;255;0m'); reset=$(printf '\033[0m')
[ "$(tmmx_host_label target-host)" = "${red_start}@target-host${reset}" ]
[ "$(tmmx_host_label deploy@target-host)" = "${red_start}deploy@target-host${reset}" ]
[ "$(tmmx_host_label ops@target-host)" = "${green_start}ops@target-host${reset}" ]
[ "$(tmmx_host_label other-host)" = @other-host ]
