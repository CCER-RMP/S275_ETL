
# NOTE: our python scripts use the target specified in ~/.dbt/profiles.yml,
# there's no way to override it on the command line, so beware!

# Extract S275 from Access database files to flat files
python -c "import S275; S275.extract()"

# Load the raw S275 data and other source tables into db
python -c "import S275; S275.load()"

# Create some seed tables
dbt seed

# Run all the transforms. Don't stop after this step! Some fields will be incorrect
# because they depend on data generated by scripts in the next step. Keep going.
#
# It'd be less wasted compute time to halt just before the 'ext' tables below
# but I haven't been able to figure out a clean way to do that.
dbt run

# Now run scripts to populate external 'ext' tables that couldn't be created in SQL:
python -c "import S275; S275.create_ext_teachermobility_distance()"
python -c "import S275; S275.create_ext_school_leadership_broad()"
python -c "import S275; S275.create_ext_duty_list()"

# Re-run the specific transforms that depend on the above re-created tables.
dbt run -m source:ext+
