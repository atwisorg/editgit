#!/bin/sh
# editgit.sh. Repository git editor.
#
# Copyright (c) 2025 Semyon A Mironov
#
# Authors: Semyon A Mironov <atwis@atwis.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

PKG="${0##*/}"

usage () {
    echo "Usage: $PKG [OPTION] [-s] <path> [[-t] <path>]"
}

show_help () {
    usage
    echo "
Options:
  -s, --work-tree=<path>    Set the path to the working tree. It can be an
                              absolute path or a path relative to the current
                              working directory. This can also be controlled by
                              setting the GIT_WORK_TREE environment variable and
                              the core.worktree configuration variable (see
                              core.worktree in git-config(1) for a more detailed
                              discussion).
  -t, --target-work-tree=<path>
                            Set the path to the new working tree. It can be an
                              absolute path or a path relative to the current
                              working directory.
  -v, --version             display version information and exit
  -h, -?, --help            display this help and exit

  An argument of '--' disables further option processing.

Report bugs to: bug-$PKG@atwis.org
$PKG home page: <https://www.atwis.org/shell-script/$PKG/>"
    die
}

show_version () {
    echo "${0##*/} ${1:-0.0.2} - (C) 05.04.2025

Written by Mironov A Semyon
Site       www.atwis.org
Email      info@atwis.org"
    die
}

try () {
    get_rc "$@" >&2
    echo "Try '$PKG --help' for more information."
    exit "$RETURN"
}

say () {
    echo "$PKG:${FUNC_NAME:+" $FUNC_NAME:"}${1:+" $@"}"
}

get_rc () {
    RETURN=$?
    case "${1:-}" in
        *[!0-9]*|"")
            ;;
        *)
            RETURN="$1"
            shift
    esac
    case "$@" in
        ?*)
            say "$*"
    esac
}

die () {
    get_rc "$@" >&2
    exit "$RETURN"
}

is_diff () {
    case "${1:-}" in
        "${2:-}")
            return 1
    esac
}

is_equal () {
    case "${1:-}" in
        "${2:-}")
            return 0
    esac
    return 1
}

is_empty () {
    case "${1:-}" in
        ?*)
            return 1
    esac
}

is_not_empty () {
    case "${1:-}" in
        "")
            return 1
    esac
}

is_dir () {
    test -d "${1:-}"
}

is_exists () {
    test -e "${1:-}"
}

arg_is_not_empty () {
    is_not_empty "${2:-}"  || {
        is_equal "${#1}" 2 &&
        try 2 "option requires an argument -- '${1#?}'" ||
        try 2 "option '$1' requires an argument"
    }
}

arg_parse () {
    OPTIONS="yes"
    while is_diff $# 0
    do
        is_equal "$OPTIONS" "yes" &&
        case "${1:-}" in
            "")
                ;;
            --)
                shift
                OPTIONS="no"
                ;;
            -[?h]|--help)
                HELP="$1"
                ;;
            -[?h]*)
                HELP="${1%"${1#??}"}"
                ARG="-${1#??}"
                shift
                set -- '' "$ARG" "$@"
                ;;
            -v|--version)
                VERSION="$1"
                ;;
            -v*)
                VERSION="${1%"${1#??}"}"
                ARG="-${1#??}"
                shift
                set -- '' "$ARG" "$@"
                ;;
            -s|--work-tree)
                arg_is_not_empty "$1" "${2:-}"
                SRC_WORK_TREE="$2"
                shift
                ;;
            -s=*|--work-tree=*)
                arg_is_not_empty "${1%%=*}" "${1#*=}"
                SRC_WORK_TREE="${1#*=}"
                ;;
            -s*)
                SRC_WORK_TREE="${1#??}"
                ;;
            -t|--target-work-tree)
                arg_is_not_empty "$1" "${2:-}"
                TRG_WORK_TREE="$2"
                shift
                ;;
            -t=*|--target-work-tree=*)
                arg_is_not_empty "${1%%=*}" "${1#*=}"
                TRG_WORK_TREE="${1#*=}"
                ;;
            -t*)
                TRG_WORK_TREE="${1#??}"
                ;;
            -|--*)
                try 2 "unknow option: '$1'"
                ;;
            -?)
                try 2 "unknow option: '${1#?}'"
                ;;
            -*)
                ARG="${1%"${1#??}"}"
                try 2 "unknow option: '${ARG#?}'"
                ;;
            *)
                false
        esac || {
            if is_empty "${SRC_WORK_TREE:-}"
            then
                SRC_WORK_TREE="$1"
            elif is_empty "${TRG_WORK_TREE:-}"
            then
                TRG_WORK_TREE="$1"
            else
                try 2 "unknow argument: '$1'"
            fi
        }
        shift
    done
}

check_args ()
{
    is_not_empty "${SRC_WORK_TREE:="${GIT_WORK_TREE:-}"}" ||
        try 2 "'SRC_WORK_TREE' is not set"
    SRC_WORK_TREE="$(cd -- "$SRC_WORK_TREE" 2>&1 && pwd -P 2>&1)" ||
        die "$SRC_WORK_TREE"

    is_exists "${TRG_WORK_TREE:="${SRC_WORK_TREE}_editgit"}"  ||
        TRG_WORK_TREE="$(mkdir -vp -- "$TRG_WORK_TREE" 2>&1)" ||
            die "$TRG_WORK_TREE"

    TRG_WORK_TREE="$(cd -- "$TRG_WORK_TREE" 2>&1 && pwd -P 2>&1)" ||
        die "$TRG_WORK_TREE"

    unset -v "GIT_WORK_TREE"
}

main ()
{
    arg_parse "$@"

    is_empty "${HELP:-}"    || show_help
    is_empty "${VERSION:-}" || show_version
    
    check_args

    git init "$TRG_WORK_TREE"

    ntp_service off

    get_list_commit "$SRC_WORK_TREE" | while read -r COMMIT
    do
        (
            echo "commit: $COMMIT"
            exec_git "$SRC_WORK_TREE" reset --hard "$COMMIT"
            get_commit "$COMMIT"
            copy       "$SRC_WORK_TREE" "$TRG_WORK_TREE"
            set_date   "$GPG_DATE"
            git_commit "$TRG_WORK_TREE"
        )
    done

    ntp_service on
}

ntp_service ()
{
    case "$1" in
        off)
            timedatectl set-ntp 0
            ;;
        on)
            timedatectl set-ntp 1
    esac
}

get_list_commit ()
{
    exec_git "$1" log --reverse | \
    grep --color=never '^[[:cntrl:]]\[33mcommit[^[:cntrl:]]\+[[:cntrl:]]\[m' | \
    sed 's/\(^[[:cntrl:]]\[33m\|[[:cntrl:]]\[m$\)//g' | \
    awk '{print $2}'
}

exec_git () {
    WORK_TREE="$1"
    shift
    git --work-tree="$WORK_TREE" --git-dir="$WORK_TREE/.git" "$@"
}

get_commit ()
{
     GIT_AUTHOR_NAME="$(exec_git "$SRC_WORK_TREE" show -s --format=%an "$1")"
    GIT_AUTHOR_EMAIL="$(exec_git "$SRC_WORK_TREE" show -s --format=%ae "$1")"
     GIT_AUTHOR_DATE="$(exec_git "$SRC_WORK_TREE" show -s --format=%ad "$1")"
     GIT_AUTHOR_DATE="$(date -d "$GIT_AUTHOR_DATE" --rfc-2822)"
             SUBJECT="$(exec_git "$SRC_WORK_TREE" show -s --format=%s  "$1")"
         COMMIT_BODY="$(exec_git "$SRC_WORK_TREE" show -s --format=%b  "$1")"

    is_empty "${COMMIT_BODY:-}" ||
    COMMIT_BODY="$(echo "$COMMIT_BODY" | \
        sed '/^Signed-off-by:/d' | \
        sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"

    GPG="$(exec_git "$SRC_WORK_TREE" show -s --format=%GG "$1")"
    is_empty "${GPG:-}" || {
        GPG_DATE="$(echo    "$GPG"      | head -1)"
        GPG_DATE="$(echo    "$GPG_DATE" | cut -d' ' -f4-9)"
        GPG_DATE="$(date -d "$GPG_DATE" "+%Y-%m-%d %T")"
    }
}

copy ()
{
    for i in "$1"/.*
    do
        is_exists "$i" &&
        case "$i" in
            */.|*/..|*/.git)
                ;;
            *)
                exec_cp "$i" "$2/"
        esac
    done

    for i in "$1"/*
    do
        is_exists "$i" && exec_cp "$i" "$2/"
    done
}

exec_cp ()
{
    cp -vpPr -- "$@"
}

set_date ()
{
    timedatectl set-time "$1"
}

git_commit ()
{
    exec_git "$1" add -A
    export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
    export GIT_AUTHOR_DATE="$GIT_AUTHOR_DATE"
    puts_commit_message | exec_git "$1" commit -s -F -
}

puts_commit_message ()
{
    echo "$SUBJECT"
    is_empty "${COMMIT_BODY:-}" || {
        echo ""
        echo "$COMMIT_BODY"
    }
}

main "$@"
