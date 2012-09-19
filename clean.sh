#!/bin/sh

# Delete Oracle sqlldr control files.
rm -rf */sqlldr

# Delete trimmed files.
find . -name \*.trimmed -exec rm {} \;

