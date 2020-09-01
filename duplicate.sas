************************************************************************;
* library setting;
************************************************************************;
*libname sdtm "yourpath" access = readonly;
%include ".\common.sas";


************************************************************************;
* merge SITEID and check the Number of Subjects;
************************************************************************;
proc sort data = sdtm.dm out = dm(keep=USUBJID SITEID);
  by USUBJID;
run;

proc sort data = sdtm.vs out = vs(keep=USUBJID VISITNUM VISIT /*VSTPTNUM VSTPT VSPOS...*/ VSTESTCD VSORRES);
  where VSTESTCD in ("SYSBP" "DIABP" "PULSE");
  by USUBJID VISITNUM /*VSTPTNUM*/ VSTESTCD;
run;

data vs2;
  merge vs(in=ina) dm(in=inb);
  by USUBJID;
  if ina and inb;
run;

proc sql noprint;
  create table vs3 as
    select *, count(distinct USUBJID) as N_PER_SITE
    from vs2
    group by SITEID
    having N_PER_SITE >= 0 /*You can exclude sites with few subjects if necessary*/
    order by USUBJID, SITEID, VISITNUM, VISIT /*,VSTPTNUM, VSTPT, VSPOS...*/
  ;
quit;


************************************************************************;
* count the sets of measurements repeated with identical values on different occasions;
************************************************************************;
proc transpose data = vs3 out = vs3t(drop=_:);
  by USUBJID SITEID VISITNUM VISIT /*VSTPTNUM VSTPT VSPOS...*/;
  var VSORRES;
  id VSTESTCD;
run;

proc sql noprint;
  create table vs4 as
    select distinct USUBJID, SITEID, /*VSPOS...,*/ SYSBP, DIABP, PULSE, count(*) as N_PER_TEST label = "Duplicate Records"
    from vs3t
    group by USUBJID, SITEID, /*VSPOS...,*/ SYSBP, DIABP, PULSE
    having N_PER_TEST > 1
    order by N_PER_TEST desc, USUBJID, SITEID/*,VSPOS...*/
  ;
quit;

proc sql noprint;
  create table listing as
    select distinct USUBJID, SITEID, /*VSPOS...,*/VISITNUM, VISIT,/*,VSTPTNUM,VSTPT,*/ SYSBP, DIABP, PULSE, count(*) as N_PER_TEST
    from vs3t
    group by USUBJID, SITEID, /*VSPOS...,*/ SYSBP, DIABP, PULSE
    having N_PER_TEST > 1
    order by N_PER_TEST desc, USUBJID, SITEID/*,VSPOS...*/,VISITNUM, VISIT/*,VSTPTNUM,VSTPT*/
  ;
quit;


************************************************************************;
* Output;
************************************************************************;
ods pdf file = "duplicate.pdf";
ods html close;         *only for listing destination.;
ods listing gpath='.';  *specify image output folder;

%macro report;

  %if &sqlobs. > 0 %then %do;

    *-----------------------------------------------------------------------;
    title1 "Duplicate Records within identical USUBJID";
    ods graphics / reset=all imagename="dup_subjects" outputfmt=png /*height=10 cm width = 12cm*/;
 
    proc sgplot data = vs4;
      hbar USUBJID/group=SITEID response = N_PER_TEST stat = sum categoryorder=respdesc ;
    run;
    title;


    *-----------------------------------------------------------------------;
    title1 "Duplicate Records within identical SITEID";
    ods graphics / reset=all imagename="dup_sites" outputfmt=png /*height=10 cm width = 12cm*/;
 
    proc sgplot data = vs4;
      hbar SITEID/group=SITEID response = N_PER_TEST stat = sum categoryorder=respdesc ;
    run;
    title;


    *-----------------------------------------------------------------------;
    title1 "Data Lisitng of Duplicate Records";
    proc report data = listing;
      columns SITEID USUBJID VISITNUM VISIT /*VSTPTNUM VSTPT VSPOS...*/  SYSBP DIABP PULSE;
      define SITEID/order width = 10;
      define USUBJID/order;
      define VISITNUM/order noprint;
      *define VSTPTNUM/order noprint;
    run;
    quit;
    title;

  %end;
  %else %do;

    data _null_;
      file print;
      put "There were no subjects with duplicate records.";
    run;

  %end;

%mend;

%report;

ods pdf close;
*EOF;

