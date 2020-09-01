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

proc sort data = sdtm.sv out = sv(keep=USUBJID VISITNUM VISIT SVSTDTC SVSTDY);
  where index(VISIT,"Unscheduled") = 0 and index(VISIT,"Discontinuation") = 0;*recommend Only for Scheduled Visit;
  by USUBJID SVSTDTC ;
run;

data sv2;
  merge sv(in=ina) dm(in=inb);
  by USUBJID;
  if ina and inb;
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
%*Macro to perform Perfect Scheduled Attendance check on SITEID;
************************************************************************;
%macro perfect_scheduled_attendance(
    dsoutP, /*Output for p-Values*/
    dsoutF, /*Output for Frequency*/
    dsin,   /*Input*/  
    byvar,  /*By Variable ex)VISIT(NUM) AVISIT(N)*/
    var,    /*Variable for Check*/
    statistic=2/*Statistics of chi-square test 1:Nonzero Correlation 2:Row Mean Scores Differ(JMP Clinical) 3:General Association*/
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
  data &dsoutP.;
    delete;
  run;

  data &dsoutF.;
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

    *Compare the distribution of Study Day;
    ods listing close;
    ods output cmh = _cmh;
    proc freq data = _dsin ;
      by &byvar.;
      tables SITEID * &var. / cmh scores = modridit out = _out outpct;
      format SITEID $site.;
    run;
    ods listing;

    *Calc Maximum Difference of the proportion;
    proc sort data = _out;
      by &byvar. &var. SITEID;
    run;

    proc transpose data = _out out = _out2;
      by &byvar. &var.;
      var PCT_ROW;
      id SITEID;
    run;

    data _out3;
      set _out2;
      if missing(SITE) then SITE = 0;
      if missing(NOT_SITE) then NOT_SITE = 0;
    run;

    %let _byvarcomma = %qsysfunc(tranwrd(&byvar.,%str( ),%str(,)));
    proc sql noprint;
      create table _out4 as
        select distinct &_byvarcomma. , max(abs(SITE - NOT_SITE)) as absDiff, (SITE - NOT_SITE) as Diff
        from _out3
        group by &_byvarcomma.
        having absDiff = abs(Diff) 
      ;
    quit;

    *Integrate the results;
    data _out5;
      merge _out4 _cmh(in=new where=(Statistic=&statistic.) keep=&byvar. AltHypothesis Statistic Prob);
      by &byvar.;
      logProb = -log10(Prob);
      label
        logProb = "-log10(p-Value)"
        Diff    = "Max. Difference of Proportion"        
      ;
    run;

    *Stack the results;
    data &dsoutP.;
      set &dsoutP. _out5(in=new);
      if new then SITEID = "&&_siteid&_i.";
    run;

    data &dsoutF.;
      length _SITEID $10;
      set &dsoutF. _out(in=new rename=(SITEID = SITEID2));
      if new then do;
        SITEID  = "&&_siteid&_i.";
        _SITEID = strip(put(SITEID2, $site.));
      end;
      format SITEID;
    run;

  %end;


%mend;

%perfect_scheduled_attendance(dsoutP=outPval, dsoutF=outFreq, dsin=sv3, byvar=VISITNUM VISIT, var=SVSTDY);


************************************************************************;
* Output;
************************************************************************;
ods pdf file = "schedule.pdf";
ods html close;         *only for listing destination.;
ods listing gpath='.';  *specify image output folder;


*-----------------------------------------------------------------------;
*Volcano plot for Screening;
ods graphics / reset=all imagename="sched_volcano" outputfmt=png /*height=10 cm width = 12cm*/;

proc sgpanel data = outPval;
  panelby VISIT / novarname rows = 2 columns = 4;/*The number of panels must be adjusted according to the number of visits*/
  scatter x = DIFF y = LOGPROB/Group = SITEID;
run;


*-----------------------------------------------------------------------;
*Study Day Proportion/Frequency by SITE;
proc sort data = outFreq;
  by VISITNUM SITEID;/*Select One Visit*/
run;

ods graphics / reset=all imagename="sched_hist" outputfmt=png /*height=10 cm width = 12cm*/;

proc sgpanel data = outFreq;
  by VISITNUM;
  panelby SITEID / uniscale= row rows = 5 columns = 5;/*The number of panels must be adjusted according to the number of sites*/
  *vbar SVSTDY/response = PCT_ROW stat = sum group = _SITEID groupdisplay = cluster;/*Prop*/
  vbar SVSTDY/response = COUNT   stat = sum group = _SITEID groupdisplay = cluster;/*Freq*/
run;

ods pdf close;

*EOF;
