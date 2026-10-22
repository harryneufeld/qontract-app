#!/bin/sh
# Fails unless pubspec.yaml's version is higher than the one on the base branch.
# Usage: tool/check_version_bump.sh <base-ref>   (default: origin/main)
# Every change that reaches main must raise the app version: the build number
# (+N) drives the Android versionCode and iOS build number, so it must increase.
set -eu

base_ref="${1:-origin/main}"
current=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '\r')
base=$(git show "$base_ref:pubspec.yaml" | sed -n 's/^version:[[:space:]]*//p' | tr -d '\r')

case "$current" in
    [0-9]*.[0-9]*.[0-9]*+[0-9]*) ;;
    *) echo "pubspec.yaml version '$current' must look like 1.2.3+4." >&2; exit 1 ;;
esac

name_current=${current%%+*}; build_current=${current##*+}
name_base=${base%%+*};       build_base=${base##*+}

if [ "$build_current" -le "$build_base" ]; then
    echo "Version not raised: $current on this branch, $base on $base_ref." >&2
    echo "Increase the number after '+' (and the 1.2.3 part for user-visible changes) in pubspec.yaml." >&2
    exit 1
fi
if [ "$name_current" != "$name_base" ] \
    && [ "$(printf '%s\n%s\n' "$name_base" "$name_current" | sort -V | tail -n 1)" != "$name_current" ]; then
    echo "Version name went backwards: $name_current is lower than $name_base." >&2
    exit 1
fi
echo "Version raised: $base -> $current"
