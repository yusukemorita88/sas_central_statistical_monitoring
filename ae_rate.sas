************************************************************************;
* library setting;
************************************************************************;
*libname sdtm "yourpath" access = readonly;
%include ".\common.sas";


************************************************************************;
* merge SITEID and check the Number of Subjects;
************************************************************************;
proc sort data = sdtm.dm out = dm(keep=USUBJID SITEID RF:);
  by USUBJID;
run;

proc sort data = sdtm.ae out = ae(keep=USUBJID AESEQ AETERM /*AESER*/);
  *where AESER = "Y";
  by USUBJID AESEQ;
run;

*total number of events by Subject;
proc sql noprint;

  create table ae2 as
    select distinct USUBJID, count(*) as AEEVENTS
    from ae
    where not missing(AETERM)
    group by USUBJID
  ;

quit;

data dm2;
  merge dm ae2;
  by USUBJID;

  if missing(AEEVENTS) then AEEVENTS = 0;

  TRTSDT = input(RFXSTDTC, yymmdd10.);
  TRTEDT = input(RFXENDTC, yymmdd10.);

  /* *You may also use RFSTDTC / RFENDTC if appropriate.;
  TRTSDT = input(RFSTDTC, yymmdd10.);
  TRTEDT = input(RFENDTC, yymmdd10.);
  */
run;

proc sql noprint;
  create table dm3 as
    select *, count(distinct USUBJID) as N_PER_SITE
    from dm2
    group by SITEID
    having N_PER_SITE >= 0 /*You can exclude sites with few subjects if necessary*/
    order by USUBJID
  ;
quit;


************************************************************************;
* Summarize by SITEID;
************************************************************************;
proc sql noprint;
  create table dm4 as
    select distinct SITEID, 
            count(distinct USUBJID) as NPATS label = "Number of Patients", 
/*            sum(TRTEDT - TRTSDT + 1) / 365.25 as PYEARS label = "Patient Years",*/
            sum(TRTEDT - TRTSDT + 1) / 7 as PWEEKS label = "Patient Weeks", 
            sum(AEEVENTS) as AEEVENTS label = "Total Number of Adverse Events",
            sum(AEEVENTS > 0 ) as AEPATS label = "Number of Patients Experienced any AE",
            calculated AEPATS / calculated NPATS as AEPROP label = "AE Proportion",
/*            calculated AEPATS / calculated PYEARS as AERATE label = "AE Rate (N per PatientYears)",*/
            calculated AEPATS / calculated PWEEKS as AERATE label = "AE Rate (N per PatientWeeks)"
    from dm3
    group by SITEID
  ;
quit;


************************************************************************;
* Output;
************************************************************************;
ods pdf file = "ae_rate.pdf";
ods html close;         *only for listing destination.;
ods listing gpath='.';  *specify image output folder;


*-----------------------------------------------------------------------;
*Bubble plots;
ods graphics / reset=all imagename="ae_rate" outputfmt=png /*height=10 cm width = 12cm*/;
proc sgplot data = dm4 /*noautolegend*/;
  bubble x = NPATS y = AERATE size = PWEEKS/*PYERAS*/ / group = SITEID;
  inset "Bubble size represents Treatment Duration" / position=bottomright textattrs=(size=10);
  xaxis grid;
  yaxis grid;
run;


*-----------------------------------------------------------------------;
*listing;
proc sort data = dm4 out = dm5;
  by descending AERATE descending AEPROP descending AEEVENTS SITEID;
run;

proc report data = dm5 split = " ";
  columns SITEID NPATS PWEEKS/*PYEARS*/ AEEVENTS AEPATS AEPROP AERATE;
  define SITEID / width = 10;
  format PWEEKS/*PYEARS*/ AEPROP AERATE 8.2;
run;

ods pdf close;

*EOF;

