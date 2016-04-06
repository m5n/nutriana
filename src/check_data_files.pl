#!/usr/bin/perl
#
# Warns if a raw data file is not ASCII.
# This file is part of http://github/m5n/nutriana

use strict;

my $nutdbid = $ARGV[0];
my $prefix = $ARGV[1];
die "Usage: $0 nutdbid [outputprefix]\n" if !$nutdbid;

my @files = split /\n/, `find ../$nutdbid/data -regextype awk -regex ".*\.(csv|txt)" -exec file {} \\;`;
foreach (@files) {
    $_ =~ /^(.*):/;
    print $prefix . "WARNING: data file $1 contains non-ASCII characters\n" if $_ !~ /ASCII/;
}
