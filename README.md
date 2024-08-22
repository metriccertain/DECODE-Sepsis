# DT1_Outcomes - MIMIC-IV as an external test set

SQL programs are copied from the [MIMIC concepts code repository](https://github.com/MIT-LCP/mimic-code/tree/main/mimic-iv/concepts).  We used the code from the BigQuery folder so we had to modify slightly to work for sqlite.  Specifically, parts using date and date-time functions available in BigQuery were modified to use functions available in sqlite.

Rmd programs are used to derive the MIMIC-IV data and to write CSV files that are then read in by the Python programs

Python programs read in CSV data output above, get the data into the shape that the model expects, load the models, and score the MIMIC-IV data
