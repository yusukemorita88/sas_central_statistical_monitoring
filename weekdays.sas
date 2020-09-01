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

proc sort data = sdtm.sv out = sv(keep=USUBJID VISITNUM VISIT SVSTDTC);
  by USUBJID SVSTDTC;
run;

data sv2;
  merge sv(in=ina) dm(in=inb);
  by USUBJID;
  if ina and inb;

  *Unlike JMP Clinical, holidays can not be considered;
  CHECKDT = input(SVSTDTC, yymmdd10.); *char to date;
  WEEKDAY = weekday(CHECKDT); *date to day of the week;

run;

proc sql noprint;
  create table sv3 as
    select *, count(distinct USUBJID) as N_PER_SITE
    from sv2
    group by SITEID
    having N_PER_SITE >= 0 /*You can exclude sites with few subjects if necessary*/
  ;
quit;


************************************************************************;
* Output;
************************************************************************;
*Formats for Mosaic Plot;
proc format;
  value dowe
    1 = "Sun"
    2 = "Mon"
    3 = "Tue"
    4 = "Wed"
    5 = "Thu"
    6 = "Fri"
    7 = "Sat"
  ;
run;

ods pdf file = "weekdays.pdf";
ods html close;         *only for listing destination.;
ods listing gpath = '.';  *specify image output folder;


*-----------------------------------------------------------------------;
*Mosaic Plot;
ods graphics on / reset=all imagename="week_mosaic" outputfmt=png /*width = 10cm height = 5cm */ ; /*Image size must be adjusted according to the number of sites*/

proc freq data = sv3;
  table WEEKDAY * SITEID/out = outFreq plots = MosaicPlot outpct;
  format WEEKDAY dowe.;
  ods select MosaicPlot;
run;

ods graphics off;


*-----------------------------------------------------------------------;
*Propotrion/Frequency by SITEID, WEEKDAY;
ods graphics / reset=all imagename="week_hist" outputfmt=png /*height=10 cm width = 12cm*/;        

proc sgpanel data = outFreq;
  panelby SITEID /novarname rows = 5 columns = 5;/*The number of panels must be adjusted according to the number of sites*/
  *vbar WEEKDAY/response = PCT_COL stat = sum;/*Prop*/
  vbar WEEKDAY/response = COUNT   stat = sum;/*Freq*/
run;

ods pdf close;

*EOF;
