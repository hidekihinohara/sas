%macro create_wdata(incsv,varlist);
	/*ヘッダ行数を取得*/
	data _null_;
		infile "&incsv" encoding='ms932' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=1 obs=1;
		input aaa $32767;
		count=count(_infile_,",")+1;
		call symputx("varcount",cats(count));
	run;

	/*ヘッダ行を取得*/
	data WORK.header_info(encoding=utf8);
		infile "&incsv" encoding='ms932' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=1 obs=1;
		informat var1-var&varcount $100.;
		input var1-var&varcount $;
	run;
	/*transposeプロシジャでヘッダ行を取得*/
	proc transpose data=work.header_info(obs=1) out=header_trps(rename=(_NAME_=NAME COL1=LABEL));
		var var1-var&varcount;
	run;
	
	/*データの長さ、タイプの判定*/
	/*ヘッダ行を省き、変数名、長さをそろえてデータ取り込み*/
	data WORK.data_info(encoding=utf8);
		infile "&incsv" encoding='ms932' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 obs=max;
		informat var1-var&varcount $100.;
		input var1-var&varcount $;
	run;
	/*ヘッダ行を省いてデータ出力*/
	proc export data=work.data_info outfile="/folders/myfolders/tmp.txt" replace;
	run;
	
	/*再度データ出力*/
	proc import datafile="/folders/myfolders/tmp.txt" dbms=dlm out=work.data_info(encoding=utf8) replace;
		delimiter="09"x;
		getnames=yes;
	run;
	
	/*ディスクリプタ情報を出力*/
	proc datasets nodetails nolist nowarn;
		contents memtype=data data=work.data_info out=work.data_info_des noprint ;
	run;
	quit;
	
	proc sort data=work.data_info_des;
		by varnum name label;
	run;
	
	/*proc sort data=work.header_trps;
		by varnum name label;
	run;
	/*ラベル名を含むディスクリプタデータセットの作成*/
	data merge_header;
		merge work.data_info_des work.header_trps(in=in2);
	run; 
	
	/*informat,format,labelステートメントを生成する*/
	data _NULL_;
		set work.merge_header;
		if type=2 then do;
			formatl=formatl*3;
			informl=informl*3;
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
	options validvarname=any noMlogic mprint nosymbolgen;
	/*ラベル名を含めてデータセットを作成*/
	%macro loop_ds;
		data test;
		infile "/folders/myfolders/tmp.txt" encoding='UTF8' dlm='09'x MISSOVER DSD lrecl=32767 firstobs=2;
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
	
	proc univariate data=work.test;
		var &varlist;
		id var2 var3;
	run;
%mend;

%create_wdata(/folders/myfolders/pre72h00_rct.txt,var10-var13)

