/*-------------------------------------------------------*/
/*Macro Name:Watch.                                      */
/*Author:hideki hinohara								 */
%macro importcsv(incsv, dsn);
	options validvarname=any nomlogic nomprint nosymbolgen nospool mcompilenote=none;
	%let path=/folders/myfolders/certadv;
	libname certadv "&path";
	filename flname "&incsv";

	/*ヘッダー情報をテキストに出力*/
	 %let filrf=myfile;
	%let rc=%sysfunc(filename(filrf, &incsv));
	%let fid=%sysfunc(fopen(&filrf));

	%if &fid > 0 %then
		%do;
			%let rc=%sysfunc(fread(&fid));
			%let rc=%sysfunc(fget(&fid, mystring));
			%let rc=%sysfunc(filename(filrf1, /folders/myfolders/header.txt));
			%let fid1=%sysfunc(fopen(&filrf1, a));
			%let rc3=%sysfunc(fput(&fid1, %sysfunc(count(%quote(&mystring), %str(,)))));
			%let rc1=%sysfunc(fwrite(&fid1));
			%let rc1=%sysfunc(fput(&fid1, %superq(mystring)));
			%let rc1=%sysfunc(fwrite(&fid1));
			%let rc1=%sysfunc(fclose(&fid1));
			%let rc1=%sysfunc(fclose(&fid1));
			%let rc=%sysfunc(fclose(&fid));
		%end;
	%let rc=%sysfunc(filename(filrf));

	/*ヘッダー情報をデータセットに出力*/
	data WORK.header_trps(encoding=utf8 keep=NAME LABEL);
		infile "/folders/myfolders/header.txt" encoding='ms932' dlmstr=',' dsd 
			MISSOVER lrecl=32767 firstobs=1 obs=max;
		input count $;
		length NAME $32 LABEL $256;
		call symputx("varcount", cats(count));

		do i=1 to count;
			input label $ @;
			name=cats("VAR", putn(i, 2.));
			output;
		end;
	run;

	/*データの長さ、タイプの判定*/
	/*ヘッダ行を省き、変数名、長さをそろえてデータ取り込み*/
	data _null_;
		infile flname encoding='ms932' delimiter=',' MISSOVER DSD lrecl=32767 
			firstobs=2 obs=max;
		informat var1-var&varcount $100.;
		input var1-var&varcount $;
		file "/folders/myfolders/tmp.txt" encoding='utf8';
		put _infile_;
	run;

	/*再度データ出力*/
	proc import datafile="/folders/myfolders/tmp.txt" dbms=dlm 
			out=work.data_info(encoding=utf8) replace;
		delimiter=",";
		getnames=no;
		guessingrows=5000;
	run;

	/*ディスクリプタ情報を出力*/
	proc datasets nodetails nolist nowarn;
		contents memtype=data data=work.data_info out=work.data_info_des noprint;
		run;
	quit;

	options cmplib=certadv.functions;

	/*ラベル名を含むディスクリプタデータセットの作成*/
	data merge_header;
		set work.data_info_des;
		LABEL=hash_table(NAME);
	run;

	/*informat,format,labelステートメントを生成する*/
	proc sql noprint;
		select ifc(type=1, cat(cats(name), ' length=', cats(length), ' label=', '"',
			cats(label), '"', ' format=', cats(format), cats(formatl), '. informat=', 
			cats(informat), cats(informl), '.'), cat(cats(name), ' length=$', 
			cats(length), ' label=', '"', cats(label), '"', ' format=', cats(format), 
			cats(formatl), '. informat=', cats(informat), cats(informl), '.') ) 
			into:attribs separated by "0d0a"x from work.merge_header;
		select ifc(type=1, cat(name, ' ?? ') , cat(name, ' ?? ', '$') ) into:input 
			separated by "0d0a"x from work.merge_header;
	quit;

	/*ラベル名を含めてデータセットを作成*/
	data work.&dsn;
		infile "/folders/myfolders/tmp.txt" encoding='utf8' dlm=',' MISSOVER DSD 
			lrecl=32767 firstobs=1;
		attrib 
		&attribs;
		input 
		&input;
	run;

	data _null_;
		fname="tmpfile";
		rc=filename(fname, "/folders/myfolders/header.txt");

		if rc=0 and fexist(fname) then
			do;
				rc=fdelete(fname);
				rc=filename(fname);
			end;
	run;

	data _null_;
		fname="tmpfile";
		rc=filename(fname, "/folders/myfolders/tmp.txt");

		if rc=0 and fexist(fname) then
			do;
				rc=fdelete(fname);
				rc=filename(fname);
			end;
	run;

%mend importcsv;

/* %importcsv(/folders/myfolders/weatherreport/data/pre72h00_rct.csv, weather); */
