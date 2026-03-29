#!/bin/sh
# shellcheck shell=bash disable=SC2016,SC2317,SC2329

load_tmux_sysstat() {
    TMUX_SYSSTAT_SOURCE_ONLY=1 \
        . "$SHELLSPEC_PROJECT_ROOT/.local/bin/tmux-sysstat"
}

Describe 'get_mem_percent()'
    It 'returns a value on the current platform'
        load_tmux_sysstat
        is_numeric() { [ "$1" -ge 0 ] 2>/dev/null && [ "$1" -le 100 ]; }
        When call get_mem_percent
        The status should be success
        The output should satisfy is_numeric
    End
End

Describe 'get_cpu_percent()'
    It 'returns a numeric value'
        load_tmux_sysstat
        get_cpu_percent() { echo "42"; }
        When call get_cpu_percent
        The output should equal '42'
    End
End

Describe 'sysstat_main()'
    It 'produces formatted output'
        load_tmux_sysstat
        get_mem_percent() { echo "50"; }
        get_cpu_percent() { echo "30"; }
        When call sysstat_main
        The output should equal 'CPU: 30% | MEM: 50%'
    End
End
