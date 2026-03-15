#!/usr/bin/env bash

set -euo pipefail

bundle exec mutant run --use rspec "FCS::Engine*"
