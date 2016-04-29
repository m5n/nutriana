#!/usr/bin/perl
#
# MySQL SQL generating perl module
# This file is part of http://github/m5n/nutriana

use strict;

sub sql_comment {
    my ($comment) = @_;

    return "-- $comment";
}

sub sql_how_to_run_as_admin {
    my ($user_name, $outfile) = @_;

    return "mysql --local_infile=1 -v -u root < $outfile";
}

sub sql_recreate_database_and_user_to_access_it {
    my ($db_name, $user_name, $user_pwd, $db_server) = @_;

    # *Re*create, so drop old database, if any.
    my $result = "drop database if exists $db_name;\n";

    # Create database.
    $result .= "create database $db_name;\n";

    # Switch to it.
    $result .= "use $db_name;\n";

    # Create user, if not already there.
    # The grant statement will create a user if it doesn't already exist.
    # Thanks, http://bugs.mysql.com/bug.php?id=19166
    $result .= "grant all on $db_name.* to '$user_name'\@'$db_server' identified by '$user_pwd';";

    # No need to switch to this user for schema creation or data import; this user is for accessing the data only.
    # TODO: limit to specific grants rather than "all"?

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
    } elsif ($type =~ /^Date/) {
        return "date";
    } else {
        die "Unexpected data type $type";
    }
}

sub sql_field_def {
    my ($field_name, $datatype, $allows_null) = @_; 

    return "$field_name $datatype" . ($allows_null ? "" : " not null");
}

sub sql_insert {
    my ($table_name, %field_names_and_values) = @_;
    my @field_names = ();
    my @field_values = ();

    foreach my $key (keys %field_names_and_values) {
        push @field_names, $key;
        push @field_values, $field_names_and_values{$key};
    }

    return "insert into $table_name (" . join(", ", @field_names) . ") values ('" . join("', '", @field_values) . "');";
}

sub sql_convert_empty_string_to_null {
    my ($table_name, $field_name) = @_;

    return "UPDATE $table_name SET $field_name = NULL WHERE $field_name = '';";
}

sub sql_convert_to_uppercase {
    my ($table_name, $field_name) = @_;

    return "UPDATE $table_name SET $field_name = UPPER($field_name);";
}

sub sql_add_primary_keys {
    my ($table_name, @field_names) = @_;

    return "alter table $table_name add primary key (" . join(", ", @field_names) . ");";
}

sub sql_add_foreign_key {
    my ($table_name, $field_name, $foreign_key) = @_;

    return "alter table $table_name add foreign key ($field_name) references " . join("(", split /\./, $foreign_key) . ");";
}

sub sql_dateformat {
    my ($format) = @_;

    $format =~ s/mm/%m/;
    $format =~ s/dd/%d/;
    $format =~ s/yyyy/%Y/;

    return $format;
}

sub sql_load_file {
    my ($nutdbid, $user_name, $user_pwd, $file, $table_name, $field_separator, $text_separator, $line_separator, $ignore_header_lines, @fieldinfo) = @_;

    # TODO: how to make MySQL generate an error if varchar data truncation occurs?
    my $relative_file = join("", split /\.\/$nutdbid\/dist/, $file);
    my $result = "load data local infile '$relative_file'\n";
    $result .= "    into table $table_name\n";
    $result .= "    fields terminated by '$field_separator'";
    $result .= " optionally enclosed by '$text_separator'" if $text_separator;
    $result .= "\n";
    $result .= "    lines terminated by '$line_separator'\n";
    $result .= "    ignore $ignore_header_lines lines\n" if $ignore_header_lines;
    $result .= "    (";

    # Specify field order and convert dates.
    my $saw_one = 0;
    my @date_vars = ();
    foreach (@fieldinfo) {
        $result .= ", " if $saw_one;
        $saw_one = 1;

        my %info = %{$_};
        if ($info{"type"} =~ m/^Date/) {
            $info{"type"} =~ s/Date\(//;
            $info{"type"} =~ s/\)//;
            push @date_vars, { "name" => $info{"name"}, "format" => sql_dateformat($info{"type"}) };

            $result .= "\@date" . ($#date_vars + 1);
        } else {
            $result .= $info{"name"};
        }
    }
    $result .= ")\n";

    # Output date assignments, if any.
    $result .= "    set\n" if $#date_vars >= 0;
    my $idx = 1;
    my $saw_one = 0;
    foreach (@date_vars) {
        $result .= ",\n" if $saw_one;
        $saw_one = 1;

        my %info = %{$_};
        $result .= "    " . $info{"name"} . " = str_to_date(\@date$idx, '" . $info{"format"} . "')";
        $idx += 1;
    }

    # Finish command.
    $result .= ";";
    return $result;
}

sub sql_assert_record_count {
    my ($table_name, $record_count) = @_;

    # MySQL (versions <= 5.5 at least) does not support assertions, so do this via a workaround.
    # 1. create a temporary table with a single unique numeric field
    # 2. insert the value 2 
    # 3. insert the record count of the table to be asserted
    # 4. remove the record where the value is the assertion value
    # case a: if the record count in step 3 == assertion value, there's now just 1 row in the temporary table (just the value 2)
    # case b: if the record count in step 3 != assertion value, there are now 2 rows in the temporary table (the value 2 and the incorrect record count value)
    # 5. insert the record count of the temporary table
    # no error for case a, and a sql error for case b (trying to insert a non-unique value)
    # (note this also works if the assertion value happens to == 2)

    my $result = "create table tmp (c int unique key);\n";
    $result .= "insert into tmp (c) values (2);\n";
    $result .= "insert into tmp (select count(*) from $table_name);\n";
    $result .= "delete from tmp where c = $record_count;\n";
    $result .= "insert into tmp (select count(*) from tmp);\n";
    $result .= "drop table tmp;";
    return $result;
}

1;
