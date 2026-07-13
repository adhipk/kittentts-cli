#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/kittentts-cli}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
INSTALL_CLAUDE_SKILL="${INSTALL_CLAUDE_SKILL:-auto}"
MARKER_NAME=".kittentts-cli-install"
SKILL_MARKER_NAME=".kittentts-cli-skill-owned"
LEGACY_INSTALL_DIR="${LEGACY_INSTALL_DIR:-$HOME/.kittentts}"
LEGACY_KIT_CKSUM='4230403962 420'
LEGACY_SKILL_CKSUM='2153954729 2233'

die() {
    printf 'kittentts-cli: %s\n' "$*" >&2
    exit 1
}

remove_managed_dir() {
    local directory="$1"
    [[ -d "$directory" && ! -L "$directory" ]] || return 0
    rm -f \
        "$directory/kit" \
        "$directory/kit-watch" \
        "$directory/tts.skill.md" \
        "$directory/$SKILL_MARKER_NAME" \
        "$directory/$MARKER_NAME"
    rmdir "$directory" 2>/dev/null || true
}

assert_owned_install_dir() {
    local path name

    [[ ! -L "$INSTALL_DIR" && -d "$INSTALL_DIR" ]] \
        || die "refusing to replace non-directory install path: $INSTALL_DIR"
    [[ -f "$INSTALL_DIR/$MARKER_NAME" ]] \
        || die "refusing to replace unowned install directory: $INSTALL_DIR"

    while IFS= read -r -d '' path; do
        name="${path##*/}"
        case "$name" in
            kit|kit-watch|tts.skill.md|"$MARKER_NAME"|"$SKILL_MARKER_NAME") ;;
            *) die "refusing to replace install directory containing an unowned path: $path" ;;
        esac
    done < <(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -print0)
}

assert_owned_or_missing_link() {
    local link_path="$1" expected_target="$2" allowed_legacy_target="${3:-}"
    if [[ -L "$link_path" && "$(readlink "$link_path")" == "$expected_target" ]]; then
        return 0
    fi
    if [[ -n "$allowed_legacy_target" && -L "$link_path" ]] \
        && [[ "$(readlink "$link_path")" == "$allowed_legacy_target" ]]; then
        return 0
    fi
    [[ ! -e "$link_path" && ! -L "$link_path" ]] \
        || die "refusing to replace existing command: $link_path"
}

legacy_checkout_is_owned() {
    [[ "$INSTALL_DIR" == "$HOME/.local/share/kittentts-cli" ]] || return 1
    [[ -d "$LEGACY_INSTALL_DIR" && ! -L "$LEGACY_INSTALL_DIR" ]] || return 1
    [[ -f "$LEGACY_INSTALL_DIR/kit" && ! -L "$LEGACY_INSTALL_DIR/kit" ]] || return 1
    [[ "$(cksum "$LEGACY_INSTALL_DIR/kit" | awk '{print $1 " " $2}')" == "$LEGACY_KIT_CKSUM" ]]
}

legacy_skill_is_owned() {
    [[ "$legacy_install_owned" == "1" && -f "$1" && ! -L "$1" ]] || return 1
    [[ "$(cksum "$1" | awk '{print $1 " " $2}')" == "$LEGACY_SKILL_CKSUM" ]]
}

if ! command -v uv >/dev/null 2>&1; then
    die 'uv is required: https://docs.astral.sh/uv/'
fi

[[ "$INSTALL_DIR" == /* ]] || die 'INSTALL_DIR must be an absolute path'
[[ "$BIN_DIR" == /* ]] || die 'BIN_DIR must be an absolute path'

case "$INSTALL_CLAUDE_SKILL" in
    0|1|auto) ;;
    *) die 'INSTALL_CLAUDE_SKILL must be 0, 1, or auto' ;;
esac

owned_reinstall=0
if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
    assert_owned_install_dir
    owned_reinstall=1
fi

legacy_install_owned=0
if legacy_checkout_is_owned; then
    legacy_install_owned=1
fi

legacy_kit_target=""
if ((legacy_install_owned)); then
    legacy_kit_target="$LEGACY_INSTALL_DIR/kit"
fi
assert_owned_or_missing_link "$BIN_DIR/kit" "$INSTALL_DIR/kit" "$legacy_kit_target"
assert_owned_or_missing_link "$BIN_DIR/kit-watch" "$INSTALL_DIR/kit-watch"

install_skill=0
if [[ "$INSTALL_CLAUDE_SKILL" == "1" ]] \
    || [[ "$INSTALL_CLAUDE_SKILL" == "auto" && -d "$HOME/.claude" ]]; then
    install_skill=1
fi

skill="$HOME/.claude/skills/tts.md"
previous_skill_owned=0
if ((owned_reinstall)) \
    && [[ -f "$INSTALL_DIR/$SKILL_MARKER_NAME" ]] \
    && [[ -f "$skill" && -f "$INSTALL_DIR/tts.skill.md" ]] \
    && cmp -s "$skill" "$INSTALL_DIR/tts.skill.md"; then
    previous_skill_owned=1
fi
legacy_skill_owned=0
if legacy_skill_is_owned "$skill"; then
    legacy_skill_owned=1
fi
skill_existed=0
if ((install_skill)) && [[ -e "$skill" || -L "$skill" ]]; then
    ((previous_skill_owned || legacy_skill_owned)) \
        || die "refusing to replace an unowned Claude skill: $skill"
    skill_existed=1
fi

install_parent="$(dirname "$INSTALL_DIR")"
mkdir -p "$install_parent" "$BIN_DIR"
stage_dir="$(mktemp -d "$install_parent/.kittentts-cli-stage.XXXXXX")"
backup_dir=""
new_install_active=0
created_kit_link=0
created_watch_link=0
replaced_legacy_kit_link=0
skill_replaced=0
skill_tmp=""

rollback() {
    local status=$?
    trap - EXIT
    set +e

    if ((status != 0)); then
        ((created_kit_link || replaced_legacy_kit_link)) && rm -f "$BIN_DIR/kit"
        if ((replaced_legacy_kit_link)); then
            ln -s "$LEGACY_INSTALL_DIR/kit" "$BIN_DIR/kit"
        fi
        ((created_watch_link)) && rm -f "$BIN_DIR/kit-watch"

        if ((skill_replaced)); then
            if ((skill_existed)) && [[ -n "$backup_dir" && -f "$backup_dir/tts.skill.md" ]]; then
                install -m 0644 "$backup_dir/tts.skill.md" "$skill"
            else
                rm -f "$skill"
            fi
        fi

        if ((new_install_active)); then
            remove_managed_dir "$INSTALL_DIR"
        fi
        if [[ -n "$backup_dir" && -d "$backup_dir" && ! -e "$INSTALL_DIR" ]]; then
            mv "$backup_dir" "$INSTALL_DIR"
            backup_dir=""
        fi
    fi

    [[ -n "$skill_tmp" ]] && rm -f "$skill_tmp"
    remove_managed_dir "$stage_dir"
    [[ -n "$backup_dir" ]] && remove_managed_dir "$backup_dir"
    exit "$status"
}
trap rollback EXIT

install -m 0755 "$SOURCE_DIR/kit" "$stage_dir/kit"
install -m 0755 "$SOURCE_DIR/kit-watch" "$stage_dir/kit-watch"
install -m 0644 "$SOURCE_DIR/tts.skill.md" "$stage_dir/tts.skill.md"
printf '%s\n' 'managed by kittentts-cli' >"$stage_dir/$MARKER_NAME"
if ((install_skill)); then
    printf '%s\n' 'managed Claude skill' >"$stage_dir/$SKILL_MARKER_NAME"
fi

if ((install_skill)); then
    mkdir -p "$(dirname "$skill")"
    skill_tmp="$(mktemp "$(dirname "$skill")/.tts.md.XXXXXX")"
    install -m 0644 "$SOURCE_DIR/tts.skill.md" "$skill_tmp"
fi

if ((owned_reinstall)); then
    backup_dir="$(mktemp -d "$install_parent/.kittentts-cli-backup.XXXXXX")"
    rmdir "$backup_dir"
    mv "$INSTALL_DIR" "$backup_dir"
fi
mv "$stage_dir" "$INSTALL_DIR"
stage_dir=""
new_install_active=1

if [[ -n "$legacy_kit_target" && -L "$BIN_DIR/kit" ]] \
    && [[ "$(readlink "$BIN_DIR/kit")" == "$legacy_kit_target" ]]; then
    replaced_legacy_kit_link=1
    rm "$BIN_DIR/kit"
    ln -s "$INSTALL_DIR/kit" "$BIN_DIR/kit"
elif [[ ! -L "$BIN_DIR/kit" ]]; then
    ln -s "$INSTALL_DIR/kit" "$BIN_DIR/kit"
    created_kit_link=1
fi
if [[ ! -L "$BIN_DIR/kit-watch" ]]; then
    ln -s "$INSTALL_DIR/kit-watch" "$BIN_DIR/kit-watch"
    created_watch_link=1
fi

if ((install_skill)); then
    mv "$skill_tmp" "$skill"
    skill_tmp=""
    skill_replaced=1
elif ((previous_skill_owned)); then
    rm -f "$skill"
fi

new_install_active=0
if [[ -n "$backup_dir" ]]; then
    remove_managed_dir "$backup_dir"
    backup_dir=""
fi
trap - EXIT

printf 'Installed kit and kit-watch in %s\n' "$BIN_DIR"
if ((legacy_install_owned)); then
    printf 'Preserved legacy checkout for manual review: %s\n' "$LEGACY_INSTALL_DIR"
fi
