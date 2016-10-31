### Database Systems Supported
* MySQL
* Oracle

### Nutrient Databases Included
* Health Canada, 2015. Canadian Nutrient File
  www.healthcanada.gc.ca/cnf
* US Department of Agriculture, Agricultural Research Service, Nutrient Data Laboratory.
  USDA National Nutrient Database for Standard Reference, Release 28. Version Current:
  September 2015. Internet: https://www.ars.usda.gov/Services/docs.htm?docid=8964
  (Full and Abbreviated versions.)

### Where Are the SQL Files?
The SQL files are located in the "dist" directory of each nutrient database,
e.g. "usda_nndsr/dist".

### Project Description
Nutriana takes the food composition data released by various official sources
in the world and converts it into formats specific to the database systems
mentioned above. (A good list of nutrient databases in the world is available here:
http://www.langual.org/langual_linkcategory.asp?CategoryID=4&Category=Food+Composition)

### How it Works
A human being is needed to extract the description and constraints of a given
nutrient database into a file that can be programmatically processed.  The JSON
format was chosen for readability and portability reasons.
Nutriana prefers not to modify the nutrient database's official data files, but
to ensure successful database creation and data import, some changes may be
necessary.
All modifications are fully disclosed in the */MODIFICATIONS files, and
typically involve correcting field size or key constraint definition, using date
format instead of string, removing trailing whitespace and/or replacing "no value"
indicators with "null".

### If Your Preferred Database is Not Supported
It should be easy to add support for other databases by copying one of the Perl
module files (*.pm) and editing it as needed to output the format for your
database system.  (If you find it's not, let me know by creating an issue.)
Run the build.sh file to (re)generate the database vendor files.  The script
will automatically detect the new .pm file and attempt to output SQL for it.
To alter the database name or user credentials, edit the "generate_sql.pl" file.

### Author
* Maarten van Egmond

Special thanks to these users for contributing:
* [alastair-duncan](https://github.com/alastair-duncan)

### License
* Nutriana is released under the MIT license; see the LICENSE file.
* Full licensing and usage information for the incuded nutrient databases is
  available in the */LICENSE files.
