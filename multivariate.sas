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

proc sort data = sdtm.vs out = vs(keep=USUBJID VISITNUM VISIT /*VSTPTNUM VSTPT*/ VSTESTCD VSORRES);
  where VSBLFL = "Y";
  by USUBJID VISITNUM /*VSTPTNUM*/ VSTESTCD;
run;

data vs2;
  merge vs(in=ina) dm(in=inb);
  by USUBJID;
  if ina and inb;
  if not missing(VSORRES) then VSORRESN = input(VSORRES,best.);
run;

proc sql noprint;
  create table vs3 as
    select *, count(distinct USUBJID) as N_PER_SITE
    from vs2
    group by SITEID
    having N_PER_SITE >= 0 /*You can exclude sites with few subjects if necessary*/
    order by USUBJID
  ;
quit;


************************************************************************;
*Calc Mahalanobis Distance;
************************************************************************;

*One observation per Subject;
proc transpose data = vs3 out = vs4(drop=_:);
  by USUBJID SITEID;
  var VSORRESN;
  id  VSTESTCD;
run;

*Check Missing Proporiton;
proc sql noprint;
  create table _missig_prop as
    select USUBJID, SITEID,
        mean(missing(PULSE))  as misPULSE,
        mean(missing(WEIGHT)) as misWEIGHT,
        mean(missing(HEIGHT)) as misHEIGHT,
        mean(missing(SYSBP))  as misSYSBP,
        mean(missing(DIABP))  as misDIABP
    from vs4
  ;
quit;

*Exclude variables with high missing ratio in DROP statement if necessary.;
proc princomp data = vs4 std out = outprin noprint;
  var _numeric_;
run;

data mahalanobis;
  set outprin;
  MAHALADIS = sqrt(uss(of PRIN:));
  ROW = _N_;
  label MAHALADIS = "Mahalanobis Distance" ROW = "Row Number";
run;


************************************************************************;
* Output;
************************************************************************;
ods pdf file = "multivariate.pdf";
ods html close;         *only for listing destination.;
ods listing gpath='.';  *specify image output folder;


*-----------------------------------------------------------------------;
ods graphics / reset=all imagename="md_by_subjects" outputfmt=png /*height=10 cm width = 12cm*/;

title1 "Mahalanobis Distances";
proc sgplot data = mahalanobis;
  scatter x = ROW y = MAHALADIS / group = SITEID;
run;
title;


*-----------------------------------------------------------------------;
ods graphics / reset=all imagename="md_all" outputfmt=png /*height=10 cm width = 12cm*/;

title1 "Mahalanobis Distance for all Sites";
proc sgplot data = mahalanobis;
  vbox MAHALADIS / datalabel = USUBJID;
run;
title;


*-----------------------------------------------------------------------;
ods graphics / reset=all imagename="md_by_sits" outputfmt=png /*height=10 cm width = 12cm*/;

title1 "Mahalanobis Distance vs Study Site Identifier";
proc sgplot data = mahalanobis;
  vbox MAHALADIS / group = SITEID datalabel = USUBJID;
run;
title;


*-----------------------------------------------------------------------;
ods graphics / reset=all imagename="md_vars" outputfmt=png /*height=12 cm width = 12cm*/;

title1 "Scatter-plots of the variables used for Mahalanobis Distance Calculation";
proc sgscatter data = vs4;
  matrix _numeric_ / diagonal=(kernel histogram);
run;
title;

ods pdf close;

*EOF;

