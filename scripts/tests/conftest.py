#!/usr/bin/env python
"""
Shared pytest fixtures and configuration for process_openapi tests.
"""

import sys
from pathlib import Path

import pytest

# Add the scripts directory to the path so we can import process_openapi
SCRIPTS_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

import process_openapi


@pytest.fixture
def reset_global_state():
    """Reset global state before each test."""
    process_openapi.collected_openapi_fragments = {}
    process_openapi.all_openapi_fragments = {}
    yield
    process_openapi.collected_openapi_fragments = {}
    process_openapi.all_openapi_fragments = {}


@pytest.fixture
def fixtures_dir():
    """Return the path to the fixtures directory."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def expected_dir():
    """Return the path to the expected outputs directory."""
    return Path(__file__).parent / "expected"
