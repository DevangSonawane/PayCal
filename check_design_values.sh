#!/bin/bash
# CI check: fail on hardcoded Color(0x or fontSize: outside core/theme/
echo "Checking for hardcoded design values outside core/theme/..."

# Check for Color(0x outside core/theme/
if grep -r "Color(0x" lib/ --include="*.dart" | grep -v "lib/core/theme/" | grep -v ".dart_tool/"; then
  echo "ERROR: Found Color(0x outside lib/core/theme/"
  exit 1
fi

# Check for fontSize: outside core/theme/
if grep -r "fontSize:" lib/ --include="*.dart" | grep -v "lib/core/theme/" | grep -v ".dart_tool/"; then
  echo "ERROR: Found fontSize: outside lib/core/theme/"
  exit 1
fi

echo "OK: No hardcoded design values found outside core/theme/"
exit 0