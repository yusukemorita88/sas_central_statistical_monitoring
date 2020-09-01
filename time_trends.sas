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

proc sort data = sdtm.vs out = vs(keep=USUBJID VISITNUM VISIT /*VSTPTNUM VSTPT*/ VSTESTCD VSORRES VSBLFL);
  where VSTESTCD in ("SYSBP" "DIABP" "PULSE") /*and VSBLFL = "Y"*/;
  by USUBJID VISITNUM /*VSTPTNUM*/ VSTESTCD;
run;

data vs2;
  merge vs(in=ina) dm(in=inb);
  by USUBJID;
  if ina and inb;

  *Char to Numeric;
  if not missing(VSORRES) then VSORRESN = input(VSORRES, best.);
run;

proc sql noprint;
  create table vs3 as
    select *, count(distinct USUBJID) as N_PER_SITE
    from vs2
    group by SITEID
    having N_PER_SITE >= 0 /*You can exclude sites with few subjects if necessary*/
  ;
quit;


************************************************************************;
* Output;
************************************************************************;
ods pdf file = "time_trends.pdf";
ods html close;         *only for listing destination.;
ods listing gpath='.';  *specify image output folder;


*-----------------------------------------------------------------------;
*Mean plot by Site ;
proc means data = vs3 noprint n mean stddev;
  class VSTESTCD SITEID VISITNUM VISIT;
  var VSORRESN;
  output out = outSumm(where=(not missing(VSTESTCD) and not missing(SITEID) and not missing(VISITNUM) and not missing(VISIT))) N = N MEAN = MEAN;
run;

ods graphics / reset=all imagename="trend_mean" outputfmt=png /*height=10 cm width = 12cm*/;

proc sgpanel data = outSumm;
  panelby VSTESTCD / novarname rows = 2 columns = 2;/*The number of panels must be adjusted according to the number of VSTESTCD*/;
  series x = VISITNUM y = MEAN /markers group = SITEID;
run;


*-----------------------------------------------------------------------;
*Box plot by Site ;
proc sort data = vs3;
  by VSTESTCD SITEID VISITNUM;
run;

ods graphics / reset=all imagename="trend_vbox" outputfmt=png /*height=10 cm width = 12cm*/;

proc sgpanel data = vs3;
  by VSTESTCD;
  panelby SITEID / novarname rows = 5 columns = 5;/*The number of panels must be adjusted according to the number of SITES*/;
  vbox VSORRESN / group = VISITNUM;
run;


*-----------------------------------------------------------------------;
*Individual plot by Site ;
proc sort data = vs3;
  by VSTESTCD USUBJID VISITNUM;
run;

ods graphics / reset=all imagename="trend_subjects" outputfmt=png /*height=10 cm width = 12cm*/;
 
proc sgpanel data = vs3 noautolegend;
  by VSTESTCD;
  panelby SITEID / novarname rows = 5 columns = 5;/*The number of panels must be adjusted according to the number of SITES*/;
  series x = VISITNUM y = VSORRESN / group = USUBJID;
run;


*-----------------------------------------------------------------------;
*Paralell Coordinate Plot;
proc means data = vs3 noprint;
  class VSTESTCD SITEID USUBJID;
  var VSORRESN;
  output out = outCoor(where=(not missing(VSTESTCD) and not missing(SITEID) and not missing(USUBJID))) STDDEV = STDDEV CV = CV N = N;
run;

data outCoor2;
  set Outcoor;
  by VSTESTCD;
  retain PARAMN 0;
  if first.VSTESTCD then PARAMN + 1;
  label PARAMN = "Parameter";
run;


*-----------------------------------------------------------------------;
*Prepare Y-Axis Format;
proc sql noprint;
  create table form as
    select distinct VSTESTCD, PARAMN
    from OutCoor2;
  ;
quit;

data fomr2;
  set form;
  start = PARAMN;
  end   = PARAMN;
  fmtname = "PARAMF";
  rename VSTESTCD = LABEL;
run;

proc format lib = work cntlin = fomr2;
run;

ods graphics / reset=all imagename="trend_sd" outputfmt=png /*height=10 cm width = 12cm*/;

proc sgpanel data = outCoor2 noautolegend;
  panelby SITEID / novarname rows = 5 columns = 5;/*The number of panels must be adjusted according to the number of SITES*/;
  series x = STDDEV y = PARAMN / group = USUBJID;
  *series x = CV y = PARAMN / group = USUBJID;/* In some case, CV is better. */
  rowaxis integer;
  format PARAMN PARAMF.;
run;

ods pdf close;

*EOF;
