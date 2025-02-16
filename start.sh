#!/bin/bash

# Colors for status messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${BLUE}[*] $1${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[-] $1${NC}"
    exit 1
}

# Check for required tools
print_status "Checking required tools..."

# Check Python version
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed"
fi

python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
if (( $(echo "$python_version < 3.10" | bc -l) )) || (( $(echo "$python_version >= 3.12" | bc -l) )); then
    print_error "Python version must be >= 3.10 and < 3.12 (current: $python_version)"
fi

# Check for bun
if ! command -v bun &> /dev/null; then
    print_error "bun is required but not installed"
fi

# Check for uv
if ! command -v uv &> /dev/null; then
    print_error "uv is required but not installed"
fi

# Create and activate virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    print_status "Creating virtual environment..."
    uv venv || print_error "Failed to create virtual environment"
    print_success "Virtual environment created"
else
    print_status "Virtual environment already exists"
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source .venv/bin/activate || print_error "Failed to activate virtual environment"
print_success "Virtual environment activated"

# Install Python dependencies
print_status "Installing Python dependencies..."
uv pip install -r requirements.txt || print_error "Failed to install Python dependencies"
print_success "Python dependencies installed"

# Kill any existing processes
print_status "Cleaning up existing processes..."
pkill -f "python devika.py"
lsof -ti:1337,3002 | xargs kill -9 2>/dev/null || true
sleep 2

# Start Devika server in background with debug output
print_status "Starting Devika server..."
python devika.py &
SERVER_PID=$!

# Wait a bit for server to start
sleep 5

# Check if server is running
if ! ps -p $SERVER_PID > /dev/null; then
    print_error "Failed to start Devika server"
fi
print_success "Devika server started"

# Install and start frontend
print_status "Setting up frontend..."
cd ui || print_error "Failed to navigate to ui directory"

print_status "Installing frontend dependencies..."
export TOKENIZERS_PARALLELISM=false
bun install || print_error "Failed to install frontend dependencies"
npx update-browserslist-db@latest --yes > /dev/null 2>&1
print_success "Frontend dependencies installed"

print_status "Starting frontend with debug output..."
VITE_API_BASE_URL=http://127.0.0.1:1337 NODE_ENV=development bun run dev || print_error "Failed to start frontend"
