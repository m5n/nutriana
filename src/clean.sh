#!/bin/sh

# Delete Oracle sqlldr log files.
rm -rf ../*/dist/sqlldr/*.log

# Delete Oracle sqlldr bad files.
rm -rf ../*/dist/sqlldr/*.bad
