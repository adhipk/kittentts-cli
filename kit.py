#!/usr/bin/env python3
"""
KittenTTS command-line interface - acts as a 'say' command replacement
Usage: kit [options] <text>
"""
import sys
import argparse
import tempfile
import subprocess
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(
        description='KittenTTS - Text-to-speech command',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  kit "Hello, world!"
  kit -v Luna "This is a test"
  kit -s 1.2 "Speak faster"
  kit -o output.wav "Save to file"
  echo "Hello" | kit
        """
    )

    parser.add_argument('text', nargs='*', help='Text to speak')
    parser.add_argument('-v', '--voice', default='Jasper',
                       help='Voice to use (default: Jasper)')
    parser.add_argument('-s', '--speed', type=float, default=1.0,
                       help='Speech speed (default: 1.0)')
    parser.add_argument('-o', '--output', help='Output file (if not specified, plays audio)')
    parser.add_argument('-l', '--list-voices', action='store_true',
                       help='List available voices')
    parser.add_argument('-m', '--model', default='KittenML/kitten-tts-mini-0.8',
                       help='Model to use (default: KittenML/kitten-tts-mini-0.8)')

    args = parser.parse_args()

    # Import KittenTTS
    try:
        from kittentts import KittenTTS
        import soundfile as sf
    except ImportError as e:
        print(f"Error: KittenTTS not installed properly: {e}", file=sys.stderr)
        print("Please run setup again.", file=sys.stderr)
        sys.exit(1)

    # Initialize model
    try:
        model = KittenTTS(args.model)
    except Exception as e:
        print(f"Error loading model: {e}", file=sys.stderr)
        sys.exit(1)

    # List voices if requested
    if args.list_voices:
        print("Available voices:")
        for voice in model.available_voices:
            print(f"  - {voice}")
        sys.exit(0)

    # Get text to speak
    if not args.text:
        if not sys.stdin.isatty():
            # Read from stdin
            text = sys.stdin.read().strip()
        else:
            parser.print_help()
            sys.exit(1)
    else:
        text = ' '.join(args.text)

    if not text:
        print("Error: No text provided", file=sys.stderr)
        sys.exit(1)

    # Generate audio
    try:
        if args.output:
            # Save to file
            model.generate_to_file(text, args.output, voice=args.voice, speed=args.speed)
            print(f"Audio saved to {args.output}")
        else:
            # Play audio
            audio = model.generate(text, voice=args.voice, speed=args.speed)

            # Save to temporary file and play
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                sf.write(tmp.name, audio, 24000)
                tmp_path = tmp.name

            # Play audio using afplay (macOS)
            try:
                subprocess.run(['afplay', tmp_path], check=True)
            finally:
                # Clean up temp file
                Path(tmp_path).unlink(missing_ok=True)

    except Exception as e:
        print(f"Error generating speech: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
