#!/usr/bin/perl
#
# Warns if a raw data file is not ASCII.
# This file is part of http://github/m5n/nutriana

use strict;

my $nutdbid = $ARGV[0];
my $pwd = `pwd`; chomp $pwd;
my @files = split /\n/, `file $nutdbid/*.txt`;
foreach (@files) {
    $_ =~ /^(.*):/;
    print "WARNING: data file $pwd/$1 contains non-ASCII characters\n" if $_ !~ /ASCII/;
}

# TODO:
# NUTR_DEF.txt contains non-ascii character:
# ~578~^~µg~^~~^~Vitamin B-12, added~^~2~^~7340~
# replace with mcg?
