#!/bin/bash
# NPX installer for KittenTTS CLI

set -e

echo "KittenTTS CLI Installer (via npx)"
echo "=================================="
echo ""

# Check for required tools
if ! command -v uv &> /dev/null; then
    echo "❌ Error: uv is not installed."
    echo ""
    echo "Please install uv first:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo ""
    exit 1
fi

if ! command -v python3.12 &> /dev/null; then
    echo "❌ Error: Python 3.12 is not installed."
    echo ""
    echo "KittenTTS requires Python 3.12. Install with:"
    echo "  brew install python@3.12"
    echo ""
    exit 1
fi

INSTALL_DIR="$HOME/.kittentts"
BIN_DIR="$HOME/.local/bin"

# Get the directory where this script is located (npx cache)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "📦 Installing KittenTTS CLI..."
echo ""

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

# Copy files from npx cache to installation directory
echo "Copying files to $INSTALL_DIR..."
cp "$SCRIPT_DIR/kit.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/kit" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/kit"

# Set up virtual environment
echo "Setting up virtual environment with Python 3.12..."
cd "$INSTALL_DIR"
uv venv --python 3.12 > /dev/null 2>&1

# Install dependencies
echo "Installing KittenTTS and dependencies..."
uv pip install https://github.com/KittenML/KittenTTS/releases/download/0.8.1/kittentts-0.8.1-py3-none-any.whl soundfile > /dev/null 2>&1

# Create symlink
echo "Creating command link..."
ln -sf "$INSTALL_DIR/kit" "$BIN_DIR/kit"

# Install Claude Code skill
SKILL_DIR="$HOME/.claude/skills"
if [ -d "$HOME/.claude" ]; then
    echo "Installing Claude Code skill..."
    mkdir -p "$SKILL_DIR"
    cp "$SCRIPT_DIR/tts.skill.md" "$SKILL_DIR/tts.md"
    echo "✅ Claude Code skill installed to $SKILL_DIR/tts.md"
else
    echo "⚠️  Claude Code not found - skill not installed"
    echo "   Install skill manually: cp tts.skill.md ~/.claude/skills/tts.md"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "The 'kit' command is now available at: $BIN_DIR/kit"
echo ""
echo "Usage:"
echo "  kit \"Hello, world!\""
echo "  kit --list-voices"
echo "  kit -v Luna \"This is a test\""
echo ""
echo "Run 'kit --help' for more options."
echo ""

# Check if bin dir is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "⚠️  Note: $BIN_DIR is not in your PATH"
    echo "Add to ~/.zshrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi
