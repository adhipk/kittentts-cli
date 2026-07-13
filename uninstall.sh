#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/kittentts-cli}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
MARKER_NAME=".kittentts-cli-install"
SKILL_MARKER_NAME=".kittentts-cli-skill-owned"

if [[ "$INSTALL_DIR" != /* || "$BIN_DIR" != /* ]]; then
    printf '%s\n' 'kittentts-cli: INSTALL_DIR and BIN_DIR must be absolute paths' >&2
    exit 1
fi

remove_owned_link() {
    local link_path="$1" expected_target="$2"
    if [[ -L "$link_path" && "$(readlink "$link_path")" == "$expected_target" ]]; then
        rm "$link_path"
    fi
}

remove_owned_link "$BIN_DIR/kit" "$INSTALL_DIR/kit"
remove_owned_link "$BIN_DIR/kit-watch" "$INSTALL_DIR/kit-watch"

if [[ -f "$INSTALL_DIR/$MARKER_NAME" ]]; then
    skill="$HOME/.claude/skills/tts.md"
    if [[ -f "$INSTALL_DIR/$SKILL_MARKER_NAME" ]] \
        && [[ -f "$skill" && -f "$INSTALL_DIR/tts.skill.md" ]] \
        && cmp -s "$skill" "$INSTALL_DIR/tts.skill.md"; then
        rm "$skill"
    fi

    rm -f \
        "$INSTALL_DIR/kit" \
        "$INSTALL_DIR/kit-watch" \
        "$INSTALL_DIR/tts.skill.md" \
        "$INSTALL_DIR/$SKILL_MARKER_NAME" \
        "$INSTALL_DIR/$MARKER_NAME"

    if ! rmdir "$INSTALL_DIR" 2>/dev/null; then
        printf 'kittentts-cli: preserved unowned files in %s\n' "$INSTALL_DIR" >&2
    fi
fi

printf 'Removed kittentts-cli managed files\n'
