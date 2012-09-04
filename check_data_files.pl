#!/usr/bin/perl

use strict;

my $pwd = `pwd`; chomp $pwd;
my @files = split /\n/, `file data/*.txt`;
foreach (@files) {
    $_ =~ /^(.*):/;
    print "WARNING: data file $pwd/$1 contains non-ASCII characters\n" if $_ !~ /ASCII/;
}

# TODO:
# NUTR_DEF.txt contains non-ascii character:
# ~578~^~µg~^~~^~Vitamin B-12, added~^~2~^~7340~
# replace with mcg?
