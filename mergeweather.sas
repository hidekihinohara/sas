/*-------------------------------------------------------*/
/*Macro Name:Watch.                                      */
/*Author:hideki hinohara								 */

%macro importcsv_4_header(incsv);
	filename flname "&incsv";
	options nomprint nomlogic nosymbolgen;
	data _NULL_;
		/*eofラベルでOBSのループを制御*/
		infile flname encoding='ms932' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=1 obs=1;
		/*後置inputでinput待ち*/
		input @;
		count=count(_infile_,",")+1;
		/*行数をマクロ変数に代入*/
		call symputx("varcount",cats(count));
	run;
	
	data WORK.header(encoding=utf8 drop=invar1-invar&varcount j);
		infile flname encoding='ms932' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=1 obs=4 end=eof;
		informat invar1-invar&varcount $256.;
		input invar1-invar&varcount $ @;
		retain VAR1-VAR&varcount "                                                                                                    ";
		retain j 0;
		%do i=1 %to &varcount;
			VAR&i=cats(VAR&i,invar&i);
		%end;
		/*行の最後*/
		/*連結した文字列を最後の行だけ出力*/
		if (eof) then do;
			output;
		end;
	run;
	/*array転置*/
	data work.header_trps(keep=name label);
		length NAME $32 LABEL $256;
		set work.header;
		array tmp _character_;
		do i=1 to dim(tmp);
			name=vlabel(tmp[i]);
			label=tmp[i];
			output;
		end;
	run;	
	
	/*データの長さ、タイプの判定*/
	/*ヘッダ行を省き、変数名、長さをそろえてデータ取り込み*/
	data _null_;
		infile flname encoding='ms932' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=5 obs=max;
		informat var1-var&varcount $300.;
		input var1-var&varcount $;
		file "/folders/myfolders/tmp.txt" encoding='utf8';
		put _infile_;
	run;

	/*再度データ出力*/
	proc import datafile="/folders/myfolders/tmp.txt" dbms=dlm out=work.data_info replace;
		delimiter=",";
		getnames=no;
		guessingrows=5000;
	run;

	/*ディスクリプタ情報を出力*/
	proc datasets nodetails nolist nowarn;
		contents memtype=data data=work.data_info out=work.data_info_des noprint ;
	run;
	quit;
	
	proc sort data=work.data_info_des;
		by varnum name label;
	run;
	
	/*table lookup*/
	proc fcmp outlib=work.functions.fcmp;
		function use_hash_table(name $) $1000;
			/*文字切れ対策で長さを指定*/
			length LABEL $1000;
			declare hash tmp(dataset:"work.header_trps");
			rc=tmp.definekey("NAME");
			rc=tmp.definedata("LABEL");
			rc=tmp.definedone();
			rc=tmp.find();
			if rc=0 then return(LABEL);
		endsub;
	quit;
	
	options cmplib=work.functions;
	/*ラベル名を含むディスクリプタデータセットの作成*/
	data merge_header(encoding=utf8);
		length LABEL $ 768;
		set work.data_info_des;
		LABEL=use_hash_table(NAME);
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
	data weather(encoding=utf8);
	infile "/folders/myfolders/tmp.txt" encoding='utf8' dlm=',' MISSOVER DSD lrecl=32767 firstobs=5;
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
	proc delete data=Work.data_info Work.data_info_des work.header work.header_trps work.merge_header;
	run;

%mend;
%importcsv_4_header(/folders/myfolders/earthquake/data/data.csv)
