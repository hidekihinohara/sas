%include '/folders/myfolders/include/importcsv.sas' /source2;

%macro create_wdata(incsv, varlist);
	options validvarname=any nomlogic nomprint nosymbolgen;
	%importcsv(/folders/myfolders/weatherreport/data/pre72h00_rct.csv, weather);

	/*proc univariate data=work.test;
	var &varlist;
	id var2 var3;
	run;*/
	ods graphics on;

	proc corr data=work.weather plots(maxpoints=100000)=matrix(histogram);
		var var4 var12 var19 var24;
	run;

%mend;

%create_wdata(/folders/myfolders/weatherreport/data/pre72h00_rct.csv, 
	var10-var13)