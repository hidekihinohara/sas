%include '/folders/myfolders/CertAdv/importcsv.sas' /source2;
%macro create_wdata(incsv,varlist);
	options validvarname=any nomlogic nomprint nosymbolgen;
	/*ヘッダ行数を取得*/
	/*ヘッダ行を取得*/
%importcsv(/folders/myfolders/weatherreport/pre72h00_rct.csv);
	
	/*proc univariate data=work.test;
		var &varlist;
		id var2 var3;
	run;*/
	
	ods graphics on;
	proc corr data=work.test plots(maxpoints=100000)=matrix(histogram) ;
		var var4 var12 var19 var24;
	run;
	
%mend;

%create_wdata(/folders/myfolders/weatherreport/pre72h00_rct.csv,var10-var13)