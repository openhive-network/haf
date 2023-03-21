#!/usr/bin/env python3
import argparse
from pathlib import Path

import test_tools as tt

from shared_tools.complex_networks import generate_networks
import shared_tools.networks_architecture as networks

def prepare_blocklog(desired_blocklog_length: int):

    # Before creating `config` take a look at `README.md`
    config = {}

    architecture = networks.NetworksArchitecture()
    architecture.load(config)

    tt.logger.info(architecture)

    generate_networks(architecture, Path('generated'), None, desired_blocklog_length)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--length', type=int, default=105, help='Desired blocklog length')
    args = parser.parse_args()

    prepare_blocklog(args.length)
