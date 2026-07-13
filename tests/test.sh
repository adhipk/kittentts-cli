#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kittentts-cli.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
FAKE_BIN="$TEMP_DIR/bin"
PASSED=0
FAILED=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT
pass() { printf 'ok - %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf 'not ok - %s\n' "$1"; FAILED=$((FAILED + 1)); }

if python3 - "$ROOT/kit" <<'PY'
import runpy
import sys
from contextlib import redirect_stderr
from io import StringIO
from types import SimpleNamespace

kit = runpy.run_path(sys.argv[1], run_name="kit_test")
assert kit["repo_id_for_model"]("mini") == "KittenML/mini"
assert kit["strip_markdown"]("# Hello **portable** [world](https://example.com)") == "Hello portable world"
assert kit["strip_markdown"]("Before ![diagram](x.png) after") == "Before after"
assert kit["strip_markdown"]("---") == ""
assert kit["chunk_text"]("One. Two. Three.", 7) == ["One.", "Two.", "Three."]
try:
    with redirect_stderr(StringIO()):
        kit["get_input_text"](
            SimpleNamespace(text=["---"], no_strip_markdown=False),
            None,
        )
except SystemExit as error:
    assert error.code == 1
else:
    raise AssertionError("markdown-only input must not reach the model")
PY
then
    pass "kit text helpers run without model or network access"
else
    fail "kit text helpers run without model or network access"
fi

mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/kit" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$KIT_TEST_ARGS"
cat >"$KIT_TEST_INPUT"
EOF
cat >"$FAKE_BIN/fswatch" <<'EOF'
#!/usr/bin/env bash
printf '1\n'
EOF
cat >"$FAKE_BIN/uv" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_BIN/kit" "$FAKE_BIN/fswatch" "$FAKE_BIN/uv"
printf 'Read this changed file.\n' >"$TEMP_DIR/draft.txt"

if PATH="$FAKE_BIN:/usr/bin:/bin" \
    KIT_TEST_ARGS="$TEMP_DIR/kit.args" \
    KIT_TEST_INPUT="$TEMP_DIR/kit.input" \
    "$ROOT/kit-watch" --no-initial --debounce 0 "$TEMP_DIR/draft.txt" -- --voice Luna >/dev/null \
    && [[ "$(cat "$TEMP_DIR/kit.args")" == "--voice Luna" ]] \
    && cmp -s "$TEMP_DIR/draft.txt" "$TEMP_DIR/kit.input"; then
    pass "kit-watch forwards arguments and file content"
else
    fail "kit-watch forwards arguments and file content"
fi

TEST_HOME="$TEMP_DIR/home"
TEST_INSTALL="$TEST_HOME/share/kittentts-cli"
TEST_BIN="$TEST_HOME/bin"
mkdir -p "$TEST_HOME/.claude/skills"
if HOME="$TEST_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$TEST_INSTALL" BIN_DIR="$TEST_BIN" INSTALL_CLAUDE_SKILL=1 \
    "$ROOT/install.sh" >/dev/null \
    && [[ -x "$TEST_INSTALL/kit" && -x "$TEST_INSTALL/kit-watch" ]] \
    && [[ "$(readlink "$TEST_BIN/kit")" == "$TEST_INSTALL/kit" ]] \
    && cmp -s "$ROOT/tts.skill.md" "$TEST_HOME/.claude/skills/tts.md"; then
    pass "installer creates owned commands and optional skill"
else
    fail "installer creates owned commands and optional skill"
fi

if HOME="$TEST_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$TEST_INSTALL" BIN_DIR="$TEST_BIN" INSTALL_CLAUDE_SKILL=1 \
    "$ROOT/install.sh" >/dev/null \
    && [[ -x "$TEST_INSTALL/kit" && -x "$TEST_INSTALL/kit-watch" ]] \
    && [[ "$(readlink "$TEST_BIN/kit")" == "$TEST_INSTALL/kit" ]] \
    && cmp -s "$ROOT/tts.skill.md" "$TEST_HOME/.claude/skills/tts.md"; then
    pass "installer safely refreshes its own existing installation"
else
    fail "installer safely refreshes its own existing installation"
fi

if [[ -f "$TEST_INSTALL/.kittentts-cli-skill-owned" ]]; then
    pass "installer records explicit Claude skill ownership"
else
    fail "installer records explicit Claude skill ownership"
fi

printf 'keep\n' >"$TEST_BIN/unrelated"
if HOME="$TEST_HOME" INSTALL_DIR="$TEST_INSTALL" BIN_DIR="$TEST_BIN" \
    "$ROOT/uninstall.sh" >/dev/null \
    && [[ ! -e "$TEST_INSTALL" && ! -e "$TEST_BIN/kit" && ! -e "$TEST_BIN/kit-watch" ]] \
    && [[ -f "$TEST_BIN/unrelated" && ! -e "$TEST_HOME/.claude/skills/tts.md" ]]; then
    pass "uninstaller removes only project-owned files"
else
    fail "uninstaller removes only project-owned files"
fi

COLLISION_HOME="$TEMP_DIR/collision-home"
COLLISION_INSTALL="$COLLISION_HOME/share/kittentts-cli"
COLLISION_BIN="$COLLISION_HOME/bin"
mkdir -p "$COLLISION_BIN"
printf 'foreign command\n' >"$COLLISION_BIN/kit"
if ! HOME="$COLLISION_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$COLLISION_INSTALL" BIN_DIR="$COLLISION_BIN" INSTALL_CLAUDE_SKILL=0 \
    "$ROOT/install.sh" >"$TEMP_DIR/collision.out" 2>&1 \
    && grep -q 'refusing to replace existing command' "$TEMP_DIR/collision.out" \
    && [[ "$(cat "$COLLISION_BIN/kit")" == "foreign command" ]] \
    && [[ ! -e "$COLLISION_INSTALL" ]]; then
    pass "installer refuses an existing command without changing it"
else
    fail "installer refuses an existing command without changing it"
fi

FOREIGN_HOME="$TEMP_DIR/foreign-home"
FOREIGN_INSTALL="$FOREIGN_HOME/share/kittentts-cli"
FOREIGN_BIN="$FOREIGN_HOME/bin"
mkdir -p "$FOREIGN_INSTALL"
printf 'keep me\n' >"$FOREIGN_INSTALL/user-file"
if ! HOME="$FOREIGN_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$FOREIGN_INSTALL" BIN_DIR="$FOREIGN_BIN" INSTALL_CLAUDE_SKILL=0 \
    "$ROOT/install.sh" >"$TEMP_DIR/foreign.out" 2>&1 \
    && grep -q 'refusing to replace unowned install directory' "$TEMP_DIR/foreign.out" \
    && [[ "$(cat "$FOREIGN_INSTALL/user-file")" == "keep me" ]]; then
    pass "installer refuses a foreign install directory"
else
    fail "installer refuses a foreign install directory"
fi

SKILL_HOME="$TEMP_DIR/skill-home"
SKILL_INSTALL="$SKILL_HOME/share/kittentts-cli"
SKILL_BIN="$SKILL_HOME/bin"
mkdir -p "$SKILL_HOME/.claude/skills"
printf 'personal skill\n' >"$SKILL_HOME/.claude/skills/tts.md"
if ! HOME="$SKILL_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$SKILL_INSTALL" BIN_DIR="$SKILL_BIN" INSTALL_CLAUDE_SKILL=1 \
    "$ROOT/install.sh" >"$TEMP_DIR/skill.out" 2>&1 \
    && grep -q 'refusing to replace an unowned Claude skill' "$TEMP_DIR/skill.out" \
    && [[ "$(cat "$SKILL_HOME/.claude/skills/tts.md")" == "personal skill" ]] \
    && [[ ! -e "$SKILL_INSTALL" ]]; then
    pass "installer preserves a pre-existing Claude skill"
else
    fail "installer preserves a pre-existing Claude skill"
fi

IDENTICAL_HOME="$TEMP_DIR/identical-home"
IDENTICAL_INSTALL="$IDENTICAL_HOME/share/kittentts-cli"
IDENTICAL_BIN="$IDENTICAL_HOME/bin"
mkdir -p "$IDENTICAL_HOME/.claude/skills"
cp "$ROOT/tts.skill.md" "$IDENTICAL_HOME/.claude/skills/tts.md"
if HOME="$IDENTICAL_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$IDENTICAL_INSTALL" BIN_DIR="$IDENTICAL_BIN" INSTALL_CLAUDE_SKILL=0 \
    "$ROOT/install.sh" >/dev/null \
    && HOME="$IDENTICAL_HOME" INSTALL_DIR="$IDENTICAL_INSTALL" BIN_DIR="$IDENTICAL_BIN" \
    "$ROOT/uninstall.sh" >/dev/null \
    && cmp -s "$ROOT/tts.skill.md" "$IDENTICAL_HOME/.claude/skills/tts.md"; then
    pass "uninstaller preserves an identical skill it did not install"
else
    fail "uninstaller preserves an identical skill it did not install"
fi

RELATIVE_HOME="$TEMP_DIR/relative-home"
mkdir -p "$RELATIVE_HOME"
if ! (cd "$RELATIVE_HOME" && HOME="$RELATIVE_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR=share/kittentts-cli BIN_DIR=bin INSTALL_CLAUDE_SKILL=0 \
    "$ROOT/install.sh" >"$TEMP_DIR/relative.out" 2>&1) \
    && grep -q 'INSTALL_DIR must be an absolute path' "$TEMP_DIR/relative.out" \
    && [[ ! -e "$RELATIVE_HOME/share" && ! -e "$RELATIVE_HOME/bin" ]]; then
    pass "installer rejects relative override paths before changing state"
else
    fail "installer rejects relative override paths before changing state"
fi

NPM_HOME="$TEMP_DIR/npm-home"
NPM_ROOT="$TEMP_DIR/npm-project/node_modules"
NPM_PACKAGE="$NPM_ROOT/kittentts-cli"
NPM_BIN="$NPM_ROOT/.bin"
mkdir -p "$NPM_PACKAGE" "$NPM_BIN"
cp "$ROOT/install.sh" "$ROOT/kit" "$ROOT/kit-watch" "$ROOT/tts.skill.md" "$NPM_PACKAGE/"
cp "$ROOT/npx-install.sh" "$NPM_PACKAGE/"
ln -s ../kittentts-cli/npx-install.sh "$NPM_BIN/kittentts-cli"
if HOME="$NPM_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" INSTALL_CLAUDE_SKILL=0 \
    "$NPM_BIN/kittentts-cli" >/dev/null \
    && [[ -x "$NPM_HOME/.local/share/kittentts-cli/kit" ]] \
    && [[ "$(readlink "$NPM_HOME/.local/bin/kit")" == "$NPM_HOME/.local/share/kittentts-cli/kit" ]]; then
    pass "npm bin symlink resolves the packaged installer"
else
    fail "npm bin symlink resolves the packaged installer"
fi

LEGACY_HOME="$TEMP_DIR/legacy-home"
LEGACY_DIR="$LEGACY_HOME/.kittentts"
mkdir -p "$LEGACY_DIR" "$LEGACY_HOME/.local/bin" "$LEGACY_HOME/.claude/skills"
cp "$ROOT/tests/fixtures/v1.0-kit" "$LEGACY_DIR/kit"
chmod +x "$LEGACY_DIR/kit"
cp "$ROOT/tests/fixtures/v1.0-tts.skill.md" "$LEGACY_DIR/tts.skill.md"
cp "$LEGACY_DIR/tts.skill.md" "$LEGACY_HOME/.claude/skills/tts.md"
printf 'locally changed implementation\n' >"$LEGACY_DIR/kit.py"
ln -s "$LEGACY_DIR/kit" "$LEGACY_HOME/.local/bin/kit"
if HOME="$LEGACY_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" INSTALL_CLAUDE_SKILL=auto \
    "$ROOT/install.sh" >"$TEMP_DIR/legacy-install.out" \
    && [[ "$(readlink "$LEGACY_HOME/.local/bin/kit")" == "$LEGACY_HOME/.local/share/kittentts-cli/kit" ]] \
    && [[ -f "$LEGACY_HOME/.local/share/kittentts-cli/.kittentts-cli-skill-owned" ]] \
    && cmp -s "$ROOT/tts.skill.md" "$LEGACY_HOME/.claude/skills/tts.md" \
    && [[ "$(cat "$LEGACY_DIR/kit.py")" == 'locally changed implementation' ]] \
    && grep -q 'Preserved legacy checkout for manual review' "$TEMP_DIR/legacy-install.out"; then
    pass "installer safely migrates a verified v1.0 checkout and preserves local changes"
else
    fail "installer safely migrates a verified v1.0 checkout and preserves local changes"
fi

if HOME="$LEGACY_HOME" "$ROOT/uninstall.sh" >/dev/null \
    && [[ ! -e "$LEGACY_HOME/.local/bin/kit" ]] \
    && [[ ! -e "$LEGACY_HOME/.claude/skills/tts.md" ]] \
    && [[ -f "$LEGACY_DIR/kit.py" && -f "$LEGACY_DIR/kit" ]]; then
    pass "uninstall removes migrated ownership but preserves the legacy checkout"
else
    fail "uninstall removes migrated ownership but preserves the legacy checkout"
fi

CUSTOM_HOME="$TEMP_DIR/custom-legacy-home"
CUSTOM_DIR="$CUSTOM_HOME/.kittentts"
mkdir -p "$CUSTOM_DIR" "$CUSTOM_HOME/.local/bin" "$CUSTOM_HOME/.claude/skills"
printf '#!/usr/bin/env bash\nprintf custom\\n\n' >"$CUSTOM_DIR/kit"
chmod +x "$CUSTOM_DIR/kit"
printf 'user customized skill\n' >"$CUSTOM_HOME/.claude/skills/tts.md"
ln -s "$CUSTOM_DIR/kit" "$CUSTOM_HOME/.local/bin/kit"
if ! HOME="$CUSTOM_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" INSTALL_CLAUDE_SKILL=auto \
    "$ROOT/install.sh" >"$TEMP_DIR/custom-legacy.out" 2>&1 \
    && [[ "$(readlink "$CUSTOM_HOME/.local/bin/kit")" == "$CUSTOM_DIR/kit" ]] \
    && [[ "$(cat "$CUSTOM_HOME/.claude/skills/tts.md")" == 'user customized skill' ]] \
    && [[ ! -e "$CUSTOM_HOME/.local/share/kittentts-cli" ]]; then
    pass "migration refuses arbitrary legacy command and skill content"
else
    fail "migration refuses arbitrary legacy command and skill content"
fi

ROLLBACK_HOME="$TEMP_DIR/rollback-home"
ROLLBACK_DIR="$ROLLBACK_HOME/.kittentts"
ROLLBACK_BIN="$TEMP_DIR/rollback-bin"
mkdir -p "$ROLLBACK_DIR" "$ROLLBACK_HOME/.local/bin" "$ROLLBACK_HOME/.claude/skills" "$ROLLBACK_BIN"
cp "$ROOT/tests/fixtures/v1.0-kit" "$ROLLBACK_DIR/kit"
chmod +x "$ROLLBACK_DIR/kit"
cp "$ROOT/tests/fixtures/v1.0-tts.skill.md" "$ROLLBACK_HOME/.claude/skills/tts.md"
ln -s "$ROLLBACK_DIR/kit" "$ROLLBACK_HOME/.local/bin/kit"
ln -s "$FAKE_BIN/uv" "$ROLLBACK_BIN/uv"
cat >"$ROLLBACK_BIN/ln" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -s && "${2:-}" == "$FAIL_NEW_TARGET" && "${3:-}" == "$FAIL_LINK_PATH" ]]; then
    exit 42
fi
exec /bin/ln "$@"
EOF
chmod +x "$ROLLBACK_BIN/ln"
rollback_status=0
HOME="$ROLLBACK_HOME" PATH="$ROLLBACK_BIN:/usr/bin:/bin" INSTALL_CLAUDE_SKILL=auto \
    FAIL_NEW_TARGET="$ROLLBACK_HOME/.local/share/kittentts-cli/kit" \
    FAIL_LINK_PATH="$ROLLBACK_HOME/.local/bin/kit" \
    "$ROOT/install.sh" >"$TEMP_DIR/rollback.out" 2>&1 || rollback_status=$?
if [[ "$rollback_status" == 42 ]] \
    && [[ "$(readlink "$ROLLBACK_HOME/.local/bin/kit")" == "$ROLLBACK_DIR/kit" ]] \
    && cmp -s "$ROOT/tests/fixtures/v1.0-tts.skill.md" "$ROLLBACK_HOME/.claude/skills/tts.md" \
    && [[ ! -e "$ROLLBACK_HOME/.local/share/kittentts-cli" ]]; then
    pass "failed legacy link replacement restores the original command"
else
    fail "failed legacy link replacement restores the original command"
fi

PRESERVE_HOME="$TEMP_DIR/preserve-home"
PRESERVE_INSTALL="$PRESERVE_HOME/share/kittentts-cli"
PRESERVE_BIN="$PRESERVE_HOME/bin"
mkdir -p "$PRESERVE_HOME/.claude"
if HOME="$PRESERVE_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$PRESERVE_INSTALL" BIN_DIR="$PRESERVE_BIN" INSTALL_CLAUDE_SKILL=1 \
    "$ROOT/install.sh" >/dev/null; then
    printf 'user data\n' >"$PRESERVE_INSTALL/user-note"
    printf 'customized skill\n' >"$PRESERVE_HOME/.claude/skills/tts.md"
else
    fail "preservation fixture installs"
fi

if ! HOME="$PRESERVE_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
    INSTALL_DIR="$PRESERVE_INSTALL" BIN_DIR="$PRESERVE_BIN" INSTALL_CLAUDE_SKILL=1 \
    "$ROOT/install.sh" >"$TEMP_DIR/preserve-reinstall.out" 2>&1 \
    && grep -q 'unowned path' "$TEMP_DIR/preserve-reinstall.out" \
    && [[ "$(cat "$PRESERVE_INSTALL/user-note")" == "user data" ]]; then
    pass "reinstall refuses to discard unexpected install-directory files"
else
    fail "reinstall refuses to discard unexpected install-directory files"
fi

if HOME="$PRESERVE_HOME" INSTALL_DIR="$PRESERVE_INSTALL" BIN_DIR="$PRESERVE_BIN" \
    "$ROOT/uninstall.sh" >"$TEMP_DIR/preserve-uninstall.out" 2>&1 \
    && [[ -f "$PRESERVE_INSTALL/user-note" ]] \
    && [[ ! -e "$PRESERVE_INSTALL/kit" && ! -e "$PRESERVE_INSTALL/kit-watch" ]] \
    && [[ ! -e "$PRESERVE_BIN/kit" && ! -e "$PRESERVE_BIN/kit-watch" ]] \
    && [[ "$(cat "$PRESERVE_HOME/.claude/skills/tts.md")" == "customized skill" ]] \
    && grep -q 'preserved unowned files' "$TEMP_DIR/preserve-uninstall.out"; then
    pass "uninstaller preserves unexpected files and a customized skill"
else
    fail "uninstaller preserves unexpected files and a customized skill"
fi

printf 'Results: %s passed, %s failed\n' "$PASSED" "$FAILED"
exit "$FAILED"
