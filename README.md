# DT1_Outcomes

SQL programs are copied from the [MIMIC concepts code repository] (https://github.com/MIT-LCP/mimic-code/tree/main/mimic-iv/concepts).  We used the code from the BigQuery folder so we had to modify slightly to work for sqlite.  Specifically, parts using date and date-time functions available in BigQuery were modified to use functions available in sqlite.

Rmd programs are used to derive the MIMIC-IV data and to write csv files that are nearly ready for input into the models

Python programs load the models and score the MIMIC-IV data
