# THLNTFS Internal Development Guidelines

This document outlines the internal development setup, testing standards, and build procedures for the THLNTFS project.

## Requirements
- Apple Silicon Mac, macOS 14.0+.
- Xcode and Command Line Tools.

## Build and Testing
- Build app bundle: `./build/package-app.sh`
- Run test suites: `swift test`
- Verification suite: `python3 tests/verify_win10_prd.py`
