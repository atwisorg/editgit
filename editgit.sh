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

while test $# -gt 0
do
    case "${1:-}" in
        -g)
            SRC_WORK_TREE="$2"
            shift
            ;;
        -n)
            TRG_WORK_TREE="$2"
            shift
            ;;
        *)
            if test -z "${SRC_WORK_TREE:-}"
            then
                SRC_WORK_TREE="$1"
            elif test -z "${TRG_WORK_TREE:-}"
            then
                TRG_WORK_TREE="$1"
            else
                echo "invalid argument: '$1'"
                exit 1
            fi
    esac
    shift
done

test "${SRC_WORK_TREE:-}" && {
    SRC_WORK_TREE="$(cd -- "$SRC_WORK_TREE" && pwd -P)"
} || {
    echo "'SRC_WORK_TREE' is not set"
    exit 1
}

test -e "${TRG_WORK_TREE:="${SRC_WORK_TREE}_editgit"}" && {
    test -d "$TRG_WORK_TREE" || {
        echo "is not a directory: '$TRG_WORK_TREE'"
        exit 2
    }
} || {
    mkdir -vp -- "$TRG_WORK_TREE"
} && TRG_WORK_TREE="$(cd -- "$TRG_WORK_TREE" && pwd -P)" || exit 2

git init "$TRG_WORK_TREE"

exec_git () {
    WORK_TREE="$1"
    shift
    git --work-tree="$WORK_TREE" --git-dir="$WORK_TREE/.git" "$@"
}

get_list_commit ()
{
    exec_git "$1" log | \
    grep --color=never '^[[:cntrl:]]\[33mcommit[^[:cntrl:]]\+[[:cntrl:]]\[m' | \
    sed 's/\(^[[:cntrl:]]\[33m\|[[:cntrl:]]\[m$\)//g' | \
    awk '{print $2}'
}


exec_cp ()
{
    cp -vpPr -- "$@"
}

copy ()
{
    for i in "$1"/.*
    do
        test -e "$i" &&
        case "$i" in
            */.|*/..|*/.git)
                ;;
            *)
                exec_cp "$i" "$2/"
        esac
    done

    for i in "$1"/*
    do
        test -e "$i" && exec_cp "$i" "$2/"
    done
}

get_commit ()
{
     GIT_AUTHOR_NAME="$(exec_git "$SRC_WORK_TREE" show -s --format=%an "$1")"
    GIT_AUTHOR_EMAIL="$(exec_git "$SRC_WORK_TREE" show -s --format=%ae "$1")"
     GIT_AUTHOR_DATE="$(exec_git "$SRC_WORK_TREE" show -s --format=%ad "$1")"
     GIT_AUTHOR_DATE="$(date -d "$GIT_AUTHOR_DATE" --rfc-2822)"
             SUBJECT="$(exec_git "$SRC_WORK_TREE" show -s --format=%s  "$1")"
         COMMIT_BODY="$(exec_git "$SRC_WORK_TREE" show -s --format=%b  "$1")"

    test -z "${COMMIT_BODY:-}" ||
    COMMIT_BODY="$(echo "$COMMIT_BODY" | \
        sed '/^Signed-off-by:/d' | \
        sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"

    GPG="$(exec_git "$SRC_WORK_TREE" show -s --format=%GG "$1")"
    test -z "${GPG:-}" || {
        GPG_DATE="$(echo    "$GPG"      | head -1)"
        GPG_DATE="$(echo    "$GPG_DATE" | cut -d' ' -f4-9)"
        GPG_DATE="$(date -d "$GPG_DATE" "+%Y-%m-%d %T")"
    }
}

puts_commit_message ()
{
    echo "$SUBJECT"
    test -z "${COMMIT_BODY:-}" || {
        echo ""
        echo "$COMMIT_BODY"
    }
}

set_date ()
{
    timedatectl set-time "$1"
}

ntp_service ()
{
    timedatectl set-ntp "$1"
}

git_commit ()
{
    exec_git "$1" add -A
    export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
    export GIT_AUTHOR_DATE="$GIT_AUTHOR_DATE"
    puts_commit_message | exec_git "$1" commit -s -F -
}

ntp_service 0

get_list_commit "$SRC_WORK_TREE" | tac | while read -r COMMIT
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

ntp_service 1
