#!/usr/bin/perl
#
# Fixes data rows in preparation of adding foreign keys.
# This file is part of http://github/m5n/nutriana

use strict;

my $project_url = $ARGV[0];

print sql_insert("DERIV_CD", ("Deriv_Cd" => "", "Deriv_Desc" => "Added by $project_url to avoid foreign key error")) . "\n";
print sql_insert("FOOD_DES", ("NDB_No" => "", "FdGrp_Cd" => "0100", "Long_Desc" => "Added by $project_url to avoid foreign key error", "Shrt_Desc" => "See Long_Desc")) . "\n";
print sql_insert("NUTR_DEF", ("Nutr_No" => "", "Units" => "g", "NutrDesc" => "Added by $project_url to avoid foreign key error", "Num_Dec" => "0", "Sr_Order" => 0)) . "\n";

