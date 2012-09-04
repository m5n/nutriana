#!/bin/sh

# The SQL files are generated via perl, so make sure it's installed.
PERL=`which perl`
if [ "$PERL" == "" ]; then echo "Please install perl" ; exit 1 ; fi

# Check that the data files do not contain any special characters.
# Because in shell scripts `file data/*.txt` does not preserve newlines, defer to perl for this.
$PERL ./check_data_files.pl

# The perl modules indicate the databases to generate SQL for.
for PMFILE in `find . -type f -name \*.pm`; do
    # Extract dabatase identifier.
    DBID=`expr "$PMFILE" : "\.\/\(.*\).pm"`
    # Convert outfile to lowercase.
    OUTFILE="$(tr [A-Z] [a-z] <<< "usda_nndsr_$DBID.sql")"

    # Generate the SQL file for this database.
    # Make sure to add the current directory to the beginning of @INC
    # to avoid accidentally using official modules with the same name.
    $PERL -I . -M$DBID ./generate_sql.pl > $OUTFILE

    echo "$DBID file generated: $OUTFILE"
done

