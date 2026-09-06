#!/bin/bash

echo "================================================="
echo "   AUDIO SEPARATOR INSTALLER FOR MAC & LINUX     "
echo "================================================="
echo ""

# Check if python3 and pip are installed
if ! command -v python3 &> /dev/null
then
    echo "[ERROR] python3 not found. Please install Python 3 first."
    echo "Download from: https://www.python.org/downloads/mac-osx/"
    echo ""
    read -p "Press Enter to exit..."
    exit
fi

echo "[1/2] Updating pip..."
python3 -m pip install --upgrade pip

echo ""
echo "[2/2] Installing 'audio-separator[cpu]' package..."
python3 -m pip install "audio-separator[cpu]"

echo ""
echo "================================================="
echo "   INSTALLATION COMPLETE! YOU CAN CLOSE THIS.    "
echo "================================================="
echo ""

read -p "Press Enter to exit..."
