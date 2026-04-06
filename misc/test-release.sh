#!/bin/sh

set -eu

die() {
    echo "$@" >&2
    exit 1
}

repo_root=$(git rev-parse --show-toplevel)
script="$repo_root/misc/release.sh"
source_branch="kazuho/reltest/master"
release_branch="kazuho/reltest/release"
tag_prefix="vtest1."

cleanup() {
    rm -rf "$source_worktree"
    git -C "$repo_root" worktree prune >/dev/null 2>&1 || true
    git -C "$repo_root" branch -D "$source_branch" >/dev/null 2>&1 || true
    git -C "$repo_root" branch -D "$release_branch" >/dev/null 2>&1 || true
    for existing_tag in $(git -C "$repo_root" tag -l "${tag_prefix}*"); do
        git -C "$repo_root" tag -d "$existing_tag" >/dev/null 2>&1 || true
    done
}

source_worktree=
trap cleanup EXIT INT TERM HUP

cleanup

git -C "$repo_root" branch "$source_branch" HEAD

"$script" \
    --source-branch "$source_branch" \
    --release-branch "$release_branch" \
    --tag-prefix "$tag_prefix"

git -C "$repo_root" show "$release_branch:picohttpparser.h" | grep -q '^#define PICOHTTPPARSER_VERSION "1.1"$' \
    || die "first release did not set version 1.1"
git -C "$repo_root" show "$release_branch:picohttpparser.h" | grep -q '^#define PICOHTTPPARSER_VERSION_MINOR 1$' \
    || die "first release did not set minor version 1"
git -C "$repo_root" rev-parse --verify "${tag_prefix}1^{tag}" >/dev/null 2>&1 \
    || die "first release tag missing"

source_worktree=$(mktemp -d "${TMPDIR:-/tmp}/picohttpparser-reltest.XXXXXX")
git -C "$repo_root" worktree add "$source_worktree" "$source_branch" >/dev/null
(
    cd "$source_worktree"
    printf '\nrelease-test-marker\n' >>README.md
    git add README.md
    git -c user.name="Kazuho Oku" -c user.email="kazuhooku@gmail.com" commit -m "reltest source update" >/dev/null
)
git -C "$repo_root" worktree remove --force "$source_worktree" >/dev/null
source_worktree=

"$script" \
    --source-branch "$source_branch" \
    --release-branch "$release_branch" \
    --tag-prefix "$tag_prefix"

git -C "$repo_root" show "$release_branch:picohttpparser.h" | grep -q '^#define PICOHTTPPARSER_VERSION "1.2"$' \
    || die "second release did not set version 1.2"
git -C "$repo_root" show "$release_branch:picohttpparser.h" | grep -q '^#define PICOHTTPPARSER_VERSION_MINOR 2$' \
    || die "second release did not set minor version 2"
git -C "$repo_root" rev-parse --verify "${tag_prefix}2^{tag}" >/dev/null 2>&1 \
    || die "second release tag missing"

release_head_before=$(git -C "$repo_root" rev-parse "$release_branch")
tag_count_before=$(git -C "$repo_root" tag -l "${tag_prefix}*" | wc -l | tr -d ' ')

"$script" \
    --source-branch "$source_branch" \
    --release-branch "$release_branch" \
    --tag-prefix "$tag_prefix"

release_head_after=$(git -C "$repo_root" rev-parse "$release_branch")
tag_count_after=$(git -C "$repo_root" tag -l "${tag_prefix}*" | wc -l | tr -d ' ')

[ "$release_head_before" = "$release_head_after" ] || die "release branch moved without new source commits"
[ "$tag_count_before" = "$tag_count_after" ] || die "tag count changed without new source commits"

echo "release automation test passed"
