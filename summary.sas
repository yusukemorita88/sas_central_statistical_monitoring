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
%*Macro to perform Mean check on SITEID;
************************************************************************;
%macro mean_compare(
    dsout,  /*Output*/
    dsin,   /*Input*/  
    byvar,  /*By Variable ex)xxTESTCD PARAMCD*/
    var     /*Variable for check (Numeric) */
);

  *Copy input data set;
  proc sort data = &dsin. out = _dsin;
    by &byvar.;
  run;

  *Preparation for repeating comparison between a site and other sites;
  proc sql noprint;

    %*Counts the number of sites and stores them in macro variable;
    select count(distinct SITEID) into :_sitenum
    from _dsin;

    %*Store SITEID in macro variable as many as site;
    select distinct SITEID 
    into :_siteid1 - :_siteid%left(&_sitenum.)
    from _dsin; 

  quit;

  *initialize out-dataset;
  data &dsout.;
    delete;
  run;

  %*Iterate processing as many as the number of sites;
  %do _i = 1 %to &_sitenum.;

    *Format for Contigency Table;
    proc format;
      value $site
      "&&_siteid&_i." = "SITE"
      other  = "NOT SITE"
      ;
    run;

    *Compare the Means;
    ods listing close;
    ods output ttests = _ttest statistics = _stat;
    proc ttest data = _dsin ;
      by &byvar.;
      class SITEID;
      var &var.;
      format SITEID $site.;
    run;
    ods listing;

    *Calc Standarized Difference in Means;
    data _stat2;
      set _stat;
      where index(upcase(CLASS),"DIFF") > 0;
      stdMeanDiff = Mean / StdErr;
      keep &byvar. StdMeanDiff Mean StdErr;
    run;

    *Summary;
    proc transpose data = _stat out = _stat3 prefix=N_;
      where not missing(N);
      by &byvar.;
      var N;
      id CLASS;
    run;

    proc transpose data = _stat out = _stat4 prefix=MEAN_;
      where not missing(N);
      by &byvar.;
      var MEAN;
      id CLASS;
    run;

    proc transpose data = _stat out = _stat5 prefix=SD_;
      where not missing(N);
      by &byvar.;
      var STDDEV;
      id CLASS;
    run;

    data _stat6;
       merge _stat3 - _stat5;
       by &byvar.;
       drop _:;
    run;

    *Integrate the results;
    data _out;
      merge _stat2 _ttest(in=new where=(upcase(Variances)="UNEQUAL") keep=&byvar. Variances Probt) _stat6;
      by &byvar.;
      logProb = -log10(Probt);
      label
        logProb = "-log10(p-Value)"
        stdMeanDiff = "Standarized Difference in Means"        
      ;
    run;

    *Stack the results;
    data &dsout.;
      set &dsout. _out(in=new);
      if new then SITEID = "&&_siteid&_i.";
    run;

  %end;


%mend;

%mean_compare(dsout=outSumm, dsin=vs3(where=(VSBLFL="Y")), byvar=VSTESTCD, var=VSORRESN);


************************************************************************;
* Output;
************************************************************************;
ods pdf file = "summary.pdf";
ods html close;         *only for listing destination.;
ods listing gpath='.';  *specify image output folder;


*-----------------------------------------------------------------------;
*Volcano plot for Screeinig;
ods graphics / reset=all imagename="sum_volcano" outputfmt=png /*height=10 cm width = 12cm*/;
 
proc sgpanel data = outSumm;
  panelby VSTESTCD / novarname rows = 2 columns = 2;/*The number of panels must be adjusted according to the number of VSTESTCD*/;
  scatter x = stdMeanDiff y = LOGPROB/Group = SITEID;
run;


*-----------------------------------------------------------------------;
*listing;
data outSumm2;
  set outSumm;
  absDiff = abs(stdMeanDiff);
run;

proc sort data = outSumm2;
  by VSTESTCD descending LOGPROB descending absDiff; 
run;

proc report data = outSumm2;
  columns VSTESTCD SITEID stdMeanDiff N_SITE MEAN_SITE SD_SITE N_NOT_SITE MEAN_NOT_SITE SD_NOT_SITE LOGPROB;
  define VSTESTCD/order;
run;


*-----------------------------------------------------------------------;
*Distribution Check;
ods graphics / reset=all imagename="sum_vbox" outputfmt=png /*height=10 cm width = 12cm*/;

proc sgpanel data = vs3(where=(VSBLFL="Y"));
  panelby VSTESTCD / novarname rows = 2 columns = 2;/*The number of panels must be adjusted according to the number of VSTESTCD*/;
  vbox VSORRESN / group = SITEID;
run;

ods pdf close;

*EOF;

