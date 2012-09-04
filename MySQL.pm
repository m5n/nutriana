#!/usr/bin/perl
    
use strict;

sub sql_comment {
   my ($comment) = @_;

   return "-- $comment";
}

sub sql_drop_database {
   my ($db_name) = @_;

   return "drop database if exists $db_name;";
}

sub sql_create_database {
   my ($db_name) = @_;

   return "create database $db_name;";
}

sub sql_use_database {
   my ($db_name) = @_;

   return "use $db_name;";
}

sub sql_drop_user {
   my ($user_name, $server_name) = @_;

   # MySQL (versions <= 5.5 at least) does not have an "if exists" clause for drop user.
   # A workaround is to grant a harmless priviledge to the user before dropping it which will create the user if it doesn't exist.
   # Thanks, http://bugs.mysql.com/bug.php?id=19166
   my $result = "grant usage on *.* to '$user_name'\@'$server_name';   -- Creates user if it does not yet exist.\n";
   $result .= "drop user '$user_name'\@'$server_name';";
   return $result;
}

sub sql_create_user {
   my ($user_name, $user_pwd, $db_name, $server_name) = @_;

   my $result = "create user '$user_name'\@'$server_name' identified by '$user_pwd';\n";
   $result .= "grant all on $db_name.* to '$user_name'\@'$server_name' identified by '$user_pwd';";
   return $result;
}

sub sql_create_table_start {
   my ($table_name) = @_;

   return "create table $table_name (";
}

sub sql_create_table_end {
   return ");";
}

sub sql_datatype_def {
    my ($type, $size, $is_unsigned) = @_;

    if ($type eq "Numeric") {
        my $result;
        if ($size =~ /\./) {
            $result = "dec(" . join(", ", split /\./, $size) . ")";
        } elsif ($size <= 2) {
            $result = "tinyint($size)";
        } elsif ($size <= 4) {
            $result = "smallint($size)";
        } elsif ((!$is_unsigned and $size <= 6) or ($is_unsigned and $size <= 7)) {
            $result = "mediumint($size)";
        } elsif ($size <= 9) {
            $result = "int($size)";
        } else {
            $result = "bigint($size)";
        }
        $result .= " unsigned" if $is_unsigned;
        return $result;
    } elsif ($type eq "Alphanumeric") {
        return "varchar($size)";
    } else {
        die "Unexpected data type $type";
    }
}

sub sql_field_def {
    my ($field_name, $datatype, $can_be_blank) = @_; 

    return "$field_name $datatype " . ($can_be_blank ? "null" : "not null");
}

sub sql_insert {
    my ($table_name, %field_names_and_values) = @_;
    my @field_names = ();
    my @field_values = ();

    foreach my $key (keys %field_names_and_values) {
        push @field_names, $key;
        push @field_values, $field_names_and_values{$key};
    }

    #return "insert into $table_name (" . join(", ", @{keys %field_names_and_values}) . ") values ('" . join("', '", @{values %field_names_and_values}) . "');";
    return "insert into $table_name (" . join(", ", @field_names) . ") values ('" . join("', '", @field_values) . "');";
}

sub sql_add_primary_keys {
   my ($table_name, @field_names) = @_;

   return "alter table $table_name add primary key (" . join(", ", @field_names) . ");";
}

sub sql_add_foreign_key {
   my ($table_name, $field_name, $foreign_key) = @_;

   return "alter table $table_name add foreign key ($field_name) references " . join("(", split /\./, $foreign_key) . ");";
}

sub sql_load_file {
   my ($file, $table_name, $field_separator, $text_separator) = @_;

   # TODO: how to make MySQL generate an error if varchar data truncation occurs?
   return "load data infile '$file' into table $table_name fields terminated by '$field_separator' optionally enclosed by '$text_separator' lines terminated by '\\r\\n';";
}

sub sql_assert_record_count {
   my ($table_name, $record_count) = @_;

   # MySQL (versions <= 5.5 at least) does not support assertions, so do this via a (clunky) workaround.
   # 1. create a temporary table with a single unique numeric field
   # 2. insert the value 2 
   # 3. insert the record count of the table to be asserted
   # 4. remove the record where the value is the assertion value
   # case a: if the record count == assertion value, there's now just 1 row in the temporary table (just the value 2)
   # case b: if the record count != assertion value, there are 2 rows in the temporary table (the value 2 and the incorrect assertion value)
   # 5. insert the record count of the temporary table
   # no error for case a, and a sql error for case b (trying to insert a non-unique value)

   my $result = "create table tmp (c int unique key);\n";
   $result .= "insert into tmp (c) values (2);\n";
   $result .= "insert into tmp (select count(*) from $table_name);\n";
   $result .= "delete from tmp where c = $record_count;\n";
   $result .= "insert into tmp (select count(*) from tmp);\n";
   $result .= "drop table tmp;";
   return $result;
}

1;
