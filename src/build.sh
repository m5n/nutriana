#!/bin/sh

# The SQL files are generated via Perl, so make sure it's installed.
PERL=`which perl`
if [ "$PERL" = "" ]; then echo "Please install Perl" ; exit 1 ; fi

# Start clean.
./clean.sh

# Process all nutrient databases included.
for NUTDBDIR in `find .. -mindepth 1 -maxdepth 1 -type d`; do
    # Extract nutrient dabatase identifier.
    NUTDBID=`expr "$NUTDBDIR" : "\.\./\(.*\)"`

    # Ignore non-DB dirs.
    if [ "$NUTDBID" = ".git" -o "$NUTDBID" = "src" ]; then continue; fi

    echo "================================== $NUTDBID =================================="

    # Check that the data files do not contain any special characters.
    # Because in shell scripts `file $NUTDBID/data/*.txt` does not preserve
    # newlines, defer to Perl for this.
    echo "Checking data files..."
    $PERL ./check_data_files.pl $NUTDBID "- "

    # The Perl modules indicate the databases to generate SQL for.
    echo "Generating SQL files..."
    for PMFILE in `find . -type f -name \*.pm`; do
        # Extract dabatase identifier.
        RDBMSID=`expr "$PMFILE" : "\./\(.*\).pm"`
        # Convert outfile to lowercase.
        #OUTFILE="$(tr [A-Z] [a-z] <<< $NUTDBID"_"$RDBMSID.sql)"
        OUTFILE="$( echo $NUTDBID"_"$RDBMSID.sql | tr '[:upper:]' '[:lower:]')"

        echo "- $RDBMSID: $OUTFILE"

        # Generate the SQL file for this database.
        # Make sure to add the current directory to the beginning of @INC
        # to avoid accidentally using official modules with the same name.
        $PERL -I . -M$RDBMSID ./generate_sql.pl $RDBMSID $NUTDBID $OUTFILE > ../$NUTDBID/dist/$OUTFILE
    done
done
