#!/bin/bash
# KittenTTS CLI Installer

set -e

echo "Installing KittenTTS CLI..."

# Check for required tools
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed. Please install it first:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

if ! command -v python3.12 &> /dev/null; then
    echo "Error: Python 3.12 is not installed. KittenTTS requires Python 3.12."
    echo "  brew install python@3.12"
    exit 1
fi

# Determine installation directory
INSTALL_DIR="${INSTALL_DIR:-$HOME/.kittentts}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

echo "Installation directory: $INSTALL_DIR"
echo "Binary link directory: $BIN_DIR"

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

# Copy files
echo "Copying files..."
cp kit.py "$INSTALL_DIR/"
cp kit "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/kit"

# Set up virtual environment with uv
echo "Setting up virtual environment with Python 3.12..."
cd "$INSTALL_DIR"
uv venv --python 3.12

# Install dependencies
echo "Installing KittenTTS and dependencies..."
uv pip install https://github.com/KittenML/KittenTTS/releases/download/0.8.1/kittentts-0.8.1-py3-none-any.whl soundfile

# Create symlink
echo "Creating symlink..."
ln -sf "$INSTALL_DIR/kit" "$BIN_DIR/kit"

# Install Claude Code skill
SKILL_DIR="$HOME/.claude/skills"
if [ -d "$HOME/.claude" ]; then
    echo "Installing Claude Code skill..."
    mkdir -p "$SKILL_DIR"
    cp tts.skill.md "$SKILL_DIR/tts.md"
    echo "✓ Claude Code skill installed to $SKILL_DIR/tts.md"
else
    echo "⚠️  Claude Code not found - skill not installed"
    echo "   Install skill manually: cp tts.skill.md ~/.claude/skills/tts.md"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "The 'kit' command is now available at: $BIN_DIR/kit"
echo ""
echo "Make sure $BIN_DIR is in your PATH. Add to ~/.zshrc if needed:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "Usage:"
echo "  kit \"Hello, world!\""
echo "  kit --list-voices"
echo "  kit -v Luna \"This is a test\""
echo ""
echo "Run 'kit --help' for more options."
