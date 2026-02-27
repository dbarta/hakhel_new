#!/bin/bash
# SMS Pipeline End-to-End Test
# Prerequisites: bin/dev must be running (Rails server needed for CSV import API)
#
# Usage: script/test_sms_pipeline.sh

cd "$(dirname "$0")/.." || exit 1
bin/rails runner 'load Rails.root.join("script","hke","test_sms_pipeline.rb")'
