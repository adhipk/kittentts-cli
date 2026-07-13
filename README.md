# KittenTTS CLI

`kit` is a `say`-like text-to-speech command powered by KittenTTS. It accepts
arguments or stdin, strips Markdown for natural speech, streams long text in
chunks, writes WAV files, and can lazily use Chatterbox for voice cloning.
`kit-watch` watches a text file and reads the full file or only appended text.

## Requirements

- macOS for direct playback through `afplay` (WAV output works elsewhere)
- [`uv`](https://docs.astral.sh/uv/)
- `fswatch` for the optional `kit-watch` command

Python and KittenTTS are declared in the `kit` script using PEP 723 metadata;
`uv` creates and caches the environment on first use. No project virtualenv is
required.

## Install

```bash
git clone https://github.com/adhipk/kittentts-cli.git
cd kittentts-cli
./install.sh
```

The installer places managed files in `~/.local/share/kittentts-cli` and links
`kit` and `kit-watch` into `~/.local/bin`. Override `INSTALL_DIR` or `BIN_DIR`
with absolute paths when needed. If Claude Code is present, its TTS skill is installed as well;
set `INSTALL_CLAUDE_SKILL=0` to skip it.

Verified v1.0 installs under `~/.kittentts` are migrated automatically. The
legacy checkout is retained for manual review so local changes or its old
virtual environment are never discarded by an upgrade.

To remove only files owned by this project:

```bash
./uninstall.sh
```

An npm-compatible installer remains available with `npx kittentts-cli`.

## Usage

```bash
kit "Hello, world"
printf '# A **Markdown** note\n' | kit
kit --voice Luna --speed 1.1 "A different voice"
kit --output speech.wav "Save instead of playing"
kit --list-voices
```

Long input streams automatically. Tune its behavior with
`--stream-threshold` and `--chunk-size`, or preserve Markdown punctuation with
`--no-strip-markdown`.

Chatterbox is an optional lazy backend:

```bash
kit --backend chatterbox --voice-ref voice.wav "Clone this voice"
```

It resolves `chatterbox-tts` only when selected. Use
`--chatterbox-device`, `--chatterbox-python`, or `--chatterbox-package` to
override its runtime.

Watch a file:

```bash
kit-watch notes.md
kit-watch --tail notes.md
kit-watch notes.md -- --voice Luna --speed 1.1
```

`--tail` speaks only appended bytes after the initial read. Use
`--no-initial` to start at the current end of the file and `--debounce` to tune
the change delay.

## Development

The test suite exercises text processing, watcher delegation, reversible
install/uninstall behavior, and streaming failure cleanup without loading a
model or using the network:

```bash
npm test
```

The first real KittenTTS run downloads its Python packages and model data.
Set `HF_TOKEN` when needed; once the required model files are cached, `kit`
uses Hugging Face offline mode unless `--refresh-model` is passed.
