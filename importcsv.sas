/*-------------------------------------------------------*/
/*Macro Name:Watch.                                      */
/*Author:hideki hinohara								 */


%macro importcsv(incsv);
	options validvarname=any nomlogic nomprint nosymbolgen nospool;
	%let path=/folders/myfolders/certadv;
	libname certadv "&path";
	filename flname "&incsv";
	/*ヘッダー情報をテキストに出力*/
	 %let filrf=myfile;                                                                                                                     
	 %let rc=%sysfunc(filename(filrf,&incsv));                                                                                  
	 %let fid=%sysfunc(fopen(&filrf));                                                                                                      
	  %if &fid > 0 %then %do;                                                                                                               
	   %let rc=%sysfunc(fread(&fid));                                                                                                       
	   %let rc=%sysfunc(fget(&fid,mystring));
		%let rc=%sysfunc(filename(filrf1,/folders/myfolders/header.txt));
		%let fid1=%sysfunc(fopen(&filrf1,a));   
		%let rc3=%sysfunc(fput(&fid1,%sysfunc(count(%quote(&mystring),%str(,)))));
		%let rc1=%sysfunc(fwrite(&fid1));
		%let rc1=%sysfunc(fput(&fid1,%superq(mystring)));
		%let rc1=%sysfunc(fwrite(&fid1));
		%let rc1=%sysfunc(fclose(&fid1));
	   %let rc1=%sysfunc(fclose(&fid1));                                                                                                      
	   %let rc=%sysfunc(fclose(&fid));                                                                                                      
	  %end;                                                                                                                                 
	 %let rc=%sysfunc(filename(filrf));
	 
	/*ヘッダー情報をデータセットに出力*/
	data WORK.header_trps(encoding=utf8 keep=NAME LABEL);
		infile "/folders/myfolders/header.txt" encoding='ms932' dlmstr=',' dsd MISSOVER lrecl=32767 firstobs=1 obs=max;
		input count $;
		length NAME $32 LABEL $256;
		call symputx("varcount",cats(count));
		do i=1 to count;
			input label $ @;
			put label=;
			name=cats("VAR",putn(i,2.));
			output;
		end;
	run;

	/*データの長さ、タイプの判定*/
	/*ヘッダ行を省き、変数名、長さをそろえてデータ取り込み*/
	data _null_;
		infile flname encoding='ms932' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 obs=max;
		informat var1-var&varcount $100.;
		input var1-var&varcount $;
		file "/folders/myfolders/tmp.txt" encoding='utf8';
		put _infile_;
	run;

	/*再度データ出力*/
	proc import datafile="/folders/myfolders/tmp.txt" dbms=dlm out=work.data_info(encoding=utf8) replace;
		delimiter=",";
		getnames=no;
		guessingrows=5000;
	run;

	/*ディスクリプタ情報を出力*/
	proc datasets nodetails nolist nowarn;
		contents memtype=data data=work.data_info out=work.data_info_des noprint ;
	run;
	quit;

	/*table lookup*/
	proc fcmp outlib=certadv.functions.fcmp;
		function hash_table(name $) $256;
			/*文字切れ対策で長さを指定*/
			length LABEL $1000;
			declare hash tmp(dataset:"work.header_trps");
			rc=tmp.definekey("NAME");
			rc=tmp.definedata("LABEL");
			rc=tmp.definedone();
			rc=tmp.find();
			if rc=0 then return(LABEL);
			else return("NA");
		endsub;
	quit;
	
	options cmplib=certadv.functions;
	/*ラベル名を含むディスクリプタデータセットの作成*/
	data merge_header;
		set work.data_info_des;
		LABEL=hash_table(NAME);
	run;
	
	/*informat,format,labelステートメントを生成する*/
	data _NULL_;
		set work.merge_header;
		if type=2 then do;
			formatl=formatl*3;
			informl=informl*3;
		end;
		if formatl=0 then do;
			formatl=10;
		end;
		call symputx(cats("name",_N_),cats(name));
		call symputx(cats("type",_N_),cats(type));
		call symputx(cats("label",_N_),cats(label));
		call symputx(cats("format",_N_),cats(format));
		call symputx(cats("formatl",_N_),cats(formatl,"."));
		call symputx(cats("informat",_N_),cats(informat));
		call symputx(cats("informl",_N_),cats(informl,"."));
		call symputx("count",max(cats(varnum)));
	run;

	/*ラベル名を含めてデータセットを作成*/
	%macro loop_ds;
		data test;
		infile "/folders/myfolders/tmp.txt" encoding='utf8' dlm=',' MISSOVER DSD lrecl=32767 firstobs=1;
			%do i=1 %to &count;
				informat &&name&i &&informat&i..&&informl&i;
			%end;
			%do i=1 %to &count;
				format &&name&i &&format&i..&&formatl&i;
			%end;
			input 
			%do i=1 %to &count;
				%if &&type&i=1 %then %do;
					 &&name&i 
				%end;
				%else %if &&type&i=2 %then %do;
					 &&name&i $
				%end;
			%end;
			;
			label 
			%do i=1 %to &count;
				 &&name&i.="&&label&i"
			%end;
			;
		run;
	%mend;
	%loop_ds;

	data _null_;
	    fname="tmpfile";
	    rc=filename(fname,"/folders/myfolders/header.txt");
	    if rc = 0 and fexist(fname) then do;
	       rc=fdelete(fname);
		   rc=filename(fname);
		end;
	run;
	data _null_;
	    fname="tmpfile";
	    rc=filename(fname,"/folders/myfolders/tmp.txt");
	    if rc = 0 and fexist(fname) then do;
	       rc=fdelete(fname);
		   rc=filename(fname);
		end;
	run;
%mend importcsv;

/*%importcsv(/folders/myfolders/weatherreport/pre72h00_rct.csv);*/

