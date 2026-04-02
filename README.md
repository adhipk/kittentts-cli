# KittenTTS Command - `kit`

A command-line interface for KittenTTS that acts as a replacement for the macOS `say` command.

## Installation

### Quick Install (npx)

```bash
npx kittentts-cli
```

### Manual Install

```bash
git clone https://github.com/adhipk/kittentts-cli.git
cd kittentts-cli
./install.sh
```

### Requirements

- Python 3.12
- [uv](https://docs.astral.sh/uv/) package manager

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Python 3.12 (macOS)
brew install python@3.12
```

The `kit` command will be installed to `~/.local/bin/kit`. Make sure this directory is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

### Basic usage
```bash
kit "Hello, world!"
```

### List available voices
```bash
kit --list-voices
```

Available voices: Bella, Jasper, Luna, Bruno, Rosie, Hugo, Kiki, Leo

### Use a specific voice
```bash
kit -v Luna "This is Luna speaking"
```

### Adjust speech speed
```bash
kit -s 1.2 "Speaking faster"
kit -s 0.8 "Speaking slower"
```

### Save to file instead of playing
```bash
kit -o output.wav "Save this to a file"
```

### Read from stdin
```bash
echo "Hello from stdin" | kit
cat file.txt | kit
```

### Combine options
```bash
kit -v Bruno -s 1.1 "Bruno speaking a bit faster"
```

## Options

- `-v, --voice VOICE` - Voice to use (default: Jasper)
- `-s, --speed SPEED` - Speech speed multiplier (default: 1.0)
- `-o, --output FILE` - Save audio to file instead of playing
- `-l, --list-voices` - List all available voices
- `-m, --model MODEL` - Specify model (default: KittenML/kitten-tts-mini-0.8)
- `-h, --help` - Show help message

## Comparison with macOS `say`

| Feature | `say` | `kit` |
|---------|-------|-------|
| Basic TTS | `say "hello"` | `kit "hello"` |
| List voices | `say -v ?` | `kit --list-voices` |
| Choose voice | `say -v Alex "hello"` | `kit -v Luna "hello"` |
| Speech rate | `say -r 200 "hello"` | `kit -s 1.2 "hello"` |
| Save to file | `say -o out.aiff "hello"` | `kit -o out.wav "hello"` |

## Notes

- First run will download the model (~22MB) from HuggingFace
- Audio is played using `afplay` on macOS
- Output format is WAV at 24kHz sample rate
- To get faster downloads and avoid warnings, set your HuggingFace token:
  ```bash
  export HF_TOKEN="your_token_here"
  ```
