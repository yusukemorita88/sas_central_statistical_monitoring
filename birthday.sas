************************************************************************;
* library setting;
************************************************************************;
*libname sdtm "yourpath" access = readonly;
%include ".\common.sas";


************************************************************************;
* check suspectd Subjects - same birthday, same gender;
************************************************************************;
proc sort data = sdtm.dm out = dm(keep=USUBJID SITEID SEX RACE BRTHDTC COUNTRY);
  where not missing(BRTHDTC);
  by USUBJID;
run;

proc sql noprint;
  create table suspected as
    select distinct BRTHDTC, SEX, RACE, COUNTRY, USUBJID, SITEID, count(*) as N
    from dm
    group by BRTHDTC, SEX
    having N > 1
  ;
quit;


************************************************************************;
* Output;
************************************************************************;
ods pdf file = "birthday.pdf";
ods html close;         *only for listing destination.;
ods listing gpath='.';  *specify image output folder;

%macro report;
  %if &sqlobs. > 0 %then %do;

    proc report data = suspected;
      columns BRTHDTC SEX RACE COUNTRY USUBJID SITEID ;
      define BRTHDTC/order width = 14;
      define SEX    /order width = 5;
      define RACE   /order width = 20;
    run;

  %end;
  %else %do;

    data _null_;
      file print;
      put "There were no subjects where birthdays and sex overlapped.";
    run;

  %end;

%mend;

%report;

ods pdf close;

*EOF;

