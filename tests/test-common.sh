#!/bin/sh

set -eu

TMMX_TEST_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmux() {
  [ "$1" = list-sessions ] || return 1
  printf '30|remote-wrapper|1|target-host|\n20|local-work|||\n10|~tmmx|||1\n'
}
date() { printf 'time-%s\n' "$2"; }
. "$TMMX_TEST_ROOT/scripts/common.sh"

actual=$(tmmx_list_sessions '')
expected=$(printf '@target-host\t30\ttime-30\tremote-wrapper\nlocal-work\t20\ttime-20\tlocal-work')
[ "$actual" = "$expected" ]

actual_host=$(tmmx_list_host_sessions '')
expected_host=$(printf 'local-work\t20\ttime-20\tlocal-work')
[ "$actual_host" = "$expected_host" ]

actual_manager=$(tmmx_list_manager_sessions '' plink)
expected_manager=$(printf '@target-host\t30\ttime-30\tremote-wrapper\n@plink - local-work\t20\ttime-20\tlocal-work')
[ "$actual_manager" = "$expected_manager" ]

actual_manager_host=$(tmmx_list_manager_sessions '' plink host)
expected_manager_host=$(printf '@target-host\t30\ttime-30\tremote-wrapper\n@plink [local]\t20\ttime-20\tlocal-work')
[ "$actual_manager_host" = "$expected_manager_host" ]

actual_manager_no_local=$(tmmx_list_manager_sessions '' plink none)
expected_manager_no_local=$(printf '@target-host\t30\ttime-30\tremote-wrapper')
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
[ "$(tmmx_session_name web.dev)" = web_dev ]
tmmx_valid_session_name plain-name
! tmmx_valid_session_name "$(printf 'bad|name')"
! tmmx_valid_session_name "$(printf 'bad\tname')"
printf '%s\n' 'error connecting to /tmp/tmux-1000/default (No such file or directory)' | tmmx_no_server_error
printf '%s\n' 'no server running on /tmp/tmux-1000/default' | tmmx_no_server_error
! printf '%s\n' 'Permission denied (publickey).' | tmmx_no_server_error
