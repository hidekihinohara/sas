filename resp "/home/u1878840/excel/covid.txt";

proc http url='https://covid.ourworldindata.org/data/owid-covid-data.json' 
		method="GET" out=resp;
run;

/* Assign a JSON library to the HTTP response */
libname space JSON fileref=resp;
*assign country;
%let cntry=JPN;

data have;
	drop ordinal:;
	retain year month day _date dif_new_cases;
	set space.&cntry._data;
	by date;
	format _date yymmdds10.;
	dif_new_cases=dif(new_cases);
	_date=input(date, yymmdd10.);
	year=year(_date);
	month=month(_date);
	day=day(_date);
	output;
	drop date;
	rename _date=date;
run;

data out;
	length year month day max_dif_new_cases max_dif_new_cases_date max_new_cases 
		max_new_cases_date max_new_deaths max_new_deaths_date max_stringency_index 
		max_stringency_index_date 8;
	format date max_dif_new_cases_date max_new_cases_date max_new_deaths_date 
		max_stringency_index_date yymmdds10.;

	do until(last.month);
		set have end=lr curobs=_r;
		by month notsorted;

		if max_dif_new_cases < dif_new_cases then
			do;
				max_dif_new_cases=dif_new_cases;
				max_dif_new_cases_date=date;
			end;

		if max_new_cases < new_cases then
			do;
				max_new_cases=new_cases;
				max_new_cases_date=date;
			end;

		if max_new_deaths < new_deaths then
			do;
				max_new_deaths=new_deaths;
				max_new_deaths_date=date;
			end;

		if max_stringency_index < stringency_index then
			do;
				max_stringency_index=stringency_index;
				max_stringency_index_date=date;
			end;
	end;
drop new_cases-numeric-new_tests_per_thousand tests_units;
run;

data want;
	length year month day dif_new_cases max_dif_new_cases max_dif_new_cases_date 
		new_cases max_new_cases max_new_cases_date new_deaths max_new_deaths 
		max_new_deaths_date stringency_index max_stringency_index 
		max_stringency_index_date 8;
	format date max_dif_new_cases_date max_new_cases_date max_new_deaths_date 
		max_stringency_index_date yymmdds10.;

	do until(last.month);
		set have;
		by month notsorted;
		dif_new_cases=ifn(first.month, ., dif_new_cases);

		if max_dif_new_cases < dif_new_cases then
			do;
				max_dif_new_cases=dif_new_cases;
				max_dif_new_cases_date=date;
			end;

		if max_new_cases < new_cases then
			do;
				max_new_cases=new_cases;
				max_new_cases_date=date;
			end;

		if max_new_deaths < new_deaths then
			do;
				max_new_deaths=new_deaths;
				max_new_deaths_date=date;
			end;

		if max_stringency_index < stringency_index then
			do;
				max_stringency_index=stringency_index;
				max_stringency_index_date=date;
			end;
	end;

	do until(last.month);
		set have;
		by month notsorted;
		output;
	end;
drop new_cases-numeric-new_tests_per_thousand tests_units;
run;

options fullstimer locale=en_us;
*連続感染者の推移をランキング出力;
data consecevt(keep=con_cases exact_count total_count)
     consecevt_detail(keep=start_date end_date con_cases weekday)
     weekday_cnt(keep=weekday con_cases start_date weekday_cnt);
	if _N_=1 then do;
		if 0 then set want;
		dcl hash consecevt(ordered:"d",suminc:"exact_count",multidata:"y") 
				 consecevt_det(ordered:"d",suminc:"exact_count",multidata:"y")
		         out1(multidata:"y",ordered:"d")
		         out2(multidata:"n",ordered:"d")
		         out3(multidata:"y",ordered:"d");
		consecevt.definekey("con_cases");
		consecevt.definedata("con_cases","year","month","day");
		consecevt.definedone();

		consecevt_det.definekey("con_cases");
		consecevt_det.definedata("con_cases","year","month","day");
		consecevt_det.definedone();

		out1.definekey("con_cases");
		out1.definedata("con_cases","exact_count","total_count");
		out1.definedone();

		out2.definekey("start_date");
		out2.definedata("start_date","end_date","con_cases");
		out2.definedone();

		out3.definekey("weekday");
		out3.definedata("weekday","con_cases","start_date");
		out3.definedone();
		dcl hiter ci("consecevt_det") out2i("out2") out3i("out3");
	end;
	format start_date end_date yymmdds10.;
	con_cases=0;
	do until(last.month);
		set want end=lr;
		by year month notsorted;
		con_cases=ifn(sign(dif_new_cases)=1,con_cases+1,0);
		if sign(dif_new_cases)=1 then consecevt.ref();
		if con_cases then consecevt_det.add();
	end;
	if lr;
	retain exact_count 1;
	total_adjust=0;
	*感染者推移ランキング;
	do con_cases=consecevt.num_items to 1 by -1;
		consecevt.sum(sum:exact_count);
		total_count=exact_count+total_adjust;
		output consecevt;
		total_adjust+exact_count;
	end;
	*詳細;
	do while(ci.next()=0);
		end_date=mdy(month,day,year);
		start_date=end_date-con_cases+1;
		_iorc_=out2.add();
	end;
	if lr;
	do while(out2i.next()=0);
		weekday=weekday(start_date);
		_iorc_=out3.add();
		output consecevt_detail;
	end;
	if lr;
	do while(out3i.next()=0);
		weekday_cnt=ifn(lag(weekday) ne weekday,1,sum(weekday_cnt,1));
		output weekday_cnt;
	end;
run;

*曜日表示用出力形式;
proc format;
	picture mywk(default=10)
	1="日"
	2="月"
	3="火"
	4="水"
	5="木"
	6="金"
	7="土"
	;
run;

*上のコードに次期に修正する予定;
data weekday_cnt(keep=weekday weekday_cnt);
	do until(last.weekday);
		format weekday mywk.;
		set weekday_cnt;
		by weekday notsorted;
	end;
run;

proc sort data=work.weekday_cnt;
by weekday;
run;

*csvファイル作成マクロ;
%macro callcsv(filename,dsn);
  ods csv file="&filename";
    proc print data=&dsn noobs;
     title "consecevt";
	 footnote "&sysdate";
    run;
  ods csv close;
%mend;

*csvファイル作成バッチ;

data _null_;
infile datalines dlm="09"x;
input filename:$200. dsn:$50.;

*_iorc_=dosubl(cats('%callcsv(',filename,',',dsn,')'));
call execute(cats('%callcsv(',filename,',',dsn,')'));

datalines;
/home/u1878840/excel/consecevt.csv	consecevt
/home/u1878840/excel/consecevt_detail.csv	consecevt_detail
/home/u1878840/excel/weekday_cnt.csv	weekday_cnt
;
run;



