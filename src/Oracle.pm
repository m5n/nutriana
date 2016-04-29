#!/usr/bin/perl
#
# Oracle SQL generating perl module
# This file is part of http://github/m5n/nutriana
     
use strict;

# TODO: how to make Oracle stop processing a .sql script on error?

sub sql_ignore_exception {
    my ($errcode, $sql) = @_;

    return "BEGIN EXECUTE IMMEDIATE '" . $sql . "'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != " . $errcode . " THEN RAISE; END IF; END;\n/";
}

sub sql_comment {
    my ($comment) = @_;

    return "-- $comment";
}

sub sql_how_to_run_as_admin {
    my ($user_name, $outfile) = @_;

    return "sqlplus \"/as sysdba\" < $outfile";
    # alternative: return "sqlplus system/your_pwd < $outfile";
}

sub sql_recreate_database_and_user_to_access_it {
    my ($db_name, $user_name, $user_pwd, $db_server) = @_;

    my $result = "";

    # *Re*create, so drop old database, if any.
    # TODO: drop database

    # Create database.
    $result .= sql_comment("This script assumes you've already set up a database when you installed Oracle and that \$ORACLE_HOME/bin is in your path.") . "\n";   # TODO: create db

    # Switch to it.
    # Not needed for Oracle.
    # Thanks, https://www.baezaconsulting.com/index.php?option=com_content&view=article&id=46:use-database-command-in-oracle&catid=7:oracle-answers&Itemid=12

    # Create user, if not already there.
    # Yes, it's better to create tablespace, but then we'd have to pick a path to a
    # datafile, complicating the script.  Something like this could be added however:
    # DEFAULT TABLESPACE $user_name TEMPORARY TABLESPACE temp QUOTA UNLIMITED ON $user_name

    # Needed since Oracle 12c.
    $result .= "\n" . sql_comment('Needed since Oracle 12c.') . "\n";
    $result .= "ALTER SESSION SET \"_ORACLE_SCRIPT\"=TRUE;\n\n";

    $result .= sql_ignore_exception("-01920", "CREATE USER $user_name IDENTIFIED BY $user_pwd") . "\n";   # Avoid error if user already exists.

    # Needed since Oracle 12c.
    $result .= "\n" . sql_comment('Needed since Oracle 12c.') . "\n";
    $result .= "ALTER USER food QUOTA UNLIMITED ON USERS;\n";

    # Needed since Oracle 12c.
    $result .= "\n" . sql_comment('Needed since Oracle 12c.') . "\n";
    $result .= "ALTER SESSION SET \"_ORACLE_SCRIPT\"=FALSE;\n\n";

    $result .= "GRANT CONNECT, RESOURCE TO $user_name;\n";

    # The tables should be created in the new user's schema (see "thanks" link above), so connect as that user.
    $result .= "CONNECT $user_name/$user_pwd;";

    return $result;
}

sub sql_create_table_start {
    my ($table_name) = @_;

    # Oracle does not support "create or replace" for tables, so drop and (re-)create.
    # TODO: remove "drop table" once "drop database" is implemented
    my $result = sql_ignore_exception("-00942", "DROP TABLE $table_name CASCADE CONSTRAINTS") . "\n";   # Avoid error if table does not exist.
    $result .= "CREATE TABLE $table_name (";
    return $result;
}

sub sql_create_table_end {
    return ");";
}

sub sql_datatype_def {
    my ($type, $size, $is_unsigned) = @_;

    if ($type eq "Numeric") {
        my $result;
        if ($size =~ /\./) {
            $result = "NUMBER(" . join(", ", split /\./, $size) . ")";
        } else {
            $result = "NUMBER($size)";
        }
        # TODO: does Oracle have an unsigned type?  Replace "NUMBER" with "POSITIVE"?
        #$result .= " UNSIGNED" if $is_unsigned;
        return $result;
    } elsif ($type eq "Alphanumeric") {
        return "VARCHAR2($size)";
    } elsif ($type =~ /^Date/) {
        return "date";
    } else {
        die "Unexpected data type $type";
    }
}

sub sql_field_def {
    my ($field_name, $datatype, $allows_null) = @_; 

    return "$field_name $datatype" . ($allows_null ? "" : " NOT NULL");
}

sub sql_insert {
    my ($table_name, %field_names_and_values) = @_;
    my @field_names = ();
    my @field_values = ();

    foreach my $key (keys %field_names_and_values) {
        push @field_names, $key;
        push @field_values, $field_names_and_values{$key};
    }

    return "INSERT INTO $table_name (" . join(", ", @field_names) . ") VALUES ('" . join("', '", @field_values) . "');";
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

    return "ALTER TABLE $table_name ADD PRIMARY KEY (" . join(", ", @field_names) . ");";
}

sub sql_add_foreign_key {
    my ($table_name, $field_name, $foreign_key) = @_;

    return "ALTER TABLE $table_name ADD FOREIGN KEY ($field_name) REFERENCES " . join("(", split /\./, $foreign_key) . ");";
}

sub sqlldr_datatype_def {
    my ($data_type, $data_size) = @_;

    # CHAR type is good enough for all except date.
    if ($data_type eq "Numeric") {
        return (index($data_size, ".") == -1) ? "INTEGER EXTERNAL" : "DECIMAL EXTERNAL";
    } elsif ($data_type eq "Alphanumeric") {
        return ($data_size > 255) ? "CHAR($data_size)" : "CHAR";
    } elsif ($data_type =~ m/^Date/) {
        $data_type =~ s/Date\(/DATE "/;
        $data_type =~ s/\)/"/;
        return $data_type;
    } else {
        die "Unexpected data type $data_type";
    }
}

sub sql_load_file {
    my ($nutdbid, $user_name, $user_pwd, $file, $table_name, $field_separator, $text_separator, $line_separator, $ignore_header_lines, @fieldinfo) = @_;

    # Keep things tidy and gather all control files into a subdir.
    `mkdir -p ../$nutdbid/dist/sqlldr`;

    # Generate infile from $file (which looks like "../<nutdbid>/dist/data.processed/<table>.(csv|txt)[.trimmed]").
    my @parts = split /\//, $file;
    splice @parts, 0, 3;
    my $infile = "./" . join("/", @parts);

    # Generate control file.
    $file =~ s|/data.processed/|/sqlldr/|;
    $file =~ s/\.(csv|txt)(.trimmed)?$/\.ctl/;

    open FILE, ">$file" or die $!;
    print FILE "OPTIONS (DIRECT=TRUE, PARALLEL=TRUE";   # Load all or nothing.
    print FILE ", SKIP=$ignore_header_lines" if $ignore_header_lines;
    print FILE ")\n";
    print FILE "LOAD DATA\n";
    print FILE "    INFILE '$infile'\n";   # Using field separator so no need for streaming option to load multi-line values.
    print FILE "    APPEND\n";   # Must be APPEND to use PARALLEL option.
    print FILE "    INTO TABLE $table_name\n";
    print FILE "    FIELDS TERMINATED BY '$field_separator'\n";
    print FILE "    OPTIONALLY ENCLOSED BY '$text_separator'\n" if $text_separator;
    print FILE "    TRAILING NULLCOLS\n";   # To load empty columns, e.g. lines ending in ^^^^.
    print FILE "    (";
    # Need to specify sqlldr data types to get around sqlldr's max char size of 255, as well as read date formats.
    my $saw_one = 0;
    foreach (@fieldinfo) {
        print FILE ", " if $saw_one;
        $saw_one = 1;

        my %info = %{$_};
        print FILE $info{"name"} . " " . sqlldr_datatype_def($info{"type"}, $info{"size"});
    }
    print FILE ")";
    close FILE;

    # Invoke sqlldr.
    my $relative_file = join("", split /\.\/$nutdbid\/dist/, $file);
    return "HOST sqlldr $user_name/$user_pwd CONTROL=$relative_file LOG=./sqlldr/$table_name.log;";
}

sub sql_assert_record_count {
    my ($table_name, $record_count) = @_;

    # Oracle (versions <= 11g at least) does not support assertions, so do this via a workaround.
    # 1. create a temporary table with a single unique numeric field
    # 2. insert the value 2 
    # 3. insert the record count of the table to be asserted
    # 4. remove the record where the value is the assertion value
    # case a: if the record count in step 3 == assertion value, there's now just 1 row in the temporary table (just the value 2)
    # case b: if the record count in step 3 != assertion value, there are now 2 rows in the temporary table (the value 2 and the incorrect record count value)
    # 5. insert the record count of the temporary table
    # no error for case a, and a sql error for case b (trying to insert a non-unique value)
    # (note this also works if the assertion value happens to == 2)

    my $result = "CREATE TABLE tmp (c NUMBER PRIMARY KEY);\n";
    $result .= "INSERT INTO tmp (c) VALUES (2);\n";
    $result .= "INSERT INTO tmp (SELECT COUNT(*) FROM $table_name);\n";
    $result .= "DELETE FROM tmp WHERE c = $record_count;\n";
    $result .= "INSERT INTO tmp (SELECT COUNT(*) FROM tmp);\n";
    $result .= "DROP TABLE tmp;";
    return $result;
}

1;
