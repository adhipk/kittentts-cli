---
name: tts
description: Generate text-to-speech audio using KittenTTS
trigger: When the user asks to speak text, generate audio, create voice output, use TTS, or convert text to speech
---

# KittenTTS Text-to-Speech Skill

Use the `kit` command to generate text-to-speech audio using KittenTTS.

## Installation

If `kit` is not installed, install it with:

```bash
# Clone and install
git clone https://github.com/adhipk/kittentts-cli.git /tmp/kittentts-cli
cd /tmp/kittentts-cli
./install.sh
rm -rf /tmp/kittentts-cli
```

Or via npx (one-command install):
```bash
npx kittentts-cli
```

Requirements: Python 3.12, uv package manager

## Available Commands

### Basic usage
```bash
kit "Text to speak"
```

### List available voices
```bash
kit --list-voices
```
Available voices: Bella, Jasper (default), Luna, Bruno, Rosie, Hugo, Kiki, Leo

### Use specific voice
```bash
kit -v Luna "Text to speak with Luna's voice"
```

### Adjust speech speed
```bash
kit -s 1.2 "Speak 20% faster"
kit -s 0.8 "Speak 20% slower"
```

### Save to file
```bash
kit -o output.wav "Save this audio to a file"
```

### Pipe from stdin
```bash
echo "Some text" | kit
cat document.txt | kit
```

### Combine options
```bash
kit -v Bruno -s 1.1 -o output.wav "Bruno speaking faster, saved to file"
```

## When to Use This Skill

- User asks to "speak" or "say" something
- User wants to hear text read aloud
- User requests audio generation from text
- User asks for text-to-speech or TTS
- User wants to test different voices
- User needs to create audio files from text

## Examples

**User request:** "Read this paragraph aloud"
```bash
kit "Your paragraph text here"
```

**User request:** "Say hello in Luna's voice"
```bash
kit -v Luna "Hello!"
```

**User request:** "Convert this text to an audio file"
```bash
kit -o output.wav "Your text content here"
```

**User request:** "What voices are available?"
```bash
kit --list-voices
```

## Notes

- First run downloads model from HuggingFace (~22MB, cached locally)
- Audio plays automatically using `afplay` on macOS
- Output format is WAV at 24kHz sample rate
- The command runs entirely locally after initial model download
- Installation repo: https://github.com/adhipk/kittentts-cli
