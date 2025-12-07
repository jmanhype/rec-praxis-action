#!/usr/bin/env python3
"""
Example Python file for testing rec-praxis-action security scanning.
This file intentionally contains some patterns that might trigger security findings.
"""

import os
import pickle
import subprocess


def read_file(filename):
    """Read file with potential path traversal vulnerability."""
    # SECURITY: Should validate filename to prevent path traversal
    with open(filename, 'r') as f:
        return f.read()


def execute_command(cmd):
    """Execute shell command - potential command injection."""
    # SECURITY: Should use subprocess with shell=False and validate input
    return subprocess.check_output(cmd, shell=True)


def deserialize_data(data):
    """Deserialize pickle data - known vulnerability."""
    # SECURITY: pickle is unsafe for untrusted data
    return pickle.loads(data)


def get_api_key():
    """Retrieve API key from environment."""
    # This is acceptable pattern
    return os.getenv('API_KEY')


if __name__ == '__main__':
    print("Example security scan test file")
