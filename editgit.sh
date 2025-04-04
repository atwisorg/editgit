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
            CURRENT_WORK_TREE="$2"
            shift
            ;;
        -n)
            NEW_WORK_TREE="$2"
            shift
            ;;
        *)
            if test -z "${CURRENT_WORK_TREE:-}"
            then
                CURRENT_WORK_TREE="$1"
            elif test -z "${NEW_WORK_TREE:-}"
            then
                NEW_WORK_TREE="$1"
            else
                echo "invalid argument: '$1'"
                exit 1
            fi
    esac
    shift
done

test "${CURRENT_WORK_TREE:-}" && {
    CURRENT_WORK_TREE="$(cd -- "$CURRENT_WORK_TREE" && pwd -P)"
} || {
    echo "'CURRENT_WORK_TREE' is not set"
    exit 1
}

test -e "${NEW_WORK_TREE:="${CURRENT_WORK_TREE}_editgit"}" && {
    test -d "$NEW_WORK_TREE" || {
        echo "is not a directory: '$NEW_WORK_TREE'"
        exit 2
    }
} || {
    mkdir -vp -- "$NEW_WORK_TREE"
} && NEW_WORK_TREE="$(cd -- "$NEW_WORK_TREE" && pwd -P)" || exit 2

git init "$NEW_WORK_TREE"

get_list_commit ()
{
    git log | \
    grep --color=never '^[[:cntrl:]]\[33mcommit[^[:cntrl:]]\+[[:cntrl:]]\[m' | \
    sed 's/\(^[[:cntrl:]]\[33m\|[[:cntrl:]]\[m$\)//g' | \
    awk '{print $2}'
}

GIT_DIR="$CURRENT_WORK_TREE/.git" get_list_commit
