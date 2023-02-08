---Here we will be creating new columns on the COPY OF ORIGINAL TABLE, to alter datatypes of some features and add new features in order to 
---make them compatible with the final database to be chosen and also, fill null values where found with suitable data

SELECT * INTO [Company LAF Details] FROM [main laf]--making a copy of original dataset to perform all calculations so that original remains unchanged

-- feature engineered features i.e. new features----
ALTER TABLE dbo.[Company LAF Details] ADD [ratio of women employees] float,
									      [bod counts] float,-- adds new feature having float datatype
										  [kmp counts] float,-- adds new feature having float datatype
										  [Nominated] float,--adds new feature having float datatype
										  [Percentage of nominated] float,-- adds new feature having float datatype
										  [directors age] float,-- adds new feature having float datatype
										  [percent change employees] float,-- adds new feature having float datatype
										  [FI or nonfi] nvarchar(255),-- adds new feature having NVARCHAR datatype
										  [directors tenure] float,-- adds new feature having float datatype
										  [kmp tenure] float,-- adds new feature having float datatype
										  [kmp bod ratio] float,-- adds new feature having float datatype
										  [kmp as bod count ratio] float,-- adds new feature having float datatype
										  [converted loan amt cr] float,-- adds new column  having float datatype
										  [converted turnover in cr] float,
										  [Date of Incorporation converted] datetime,
										  [Commencement Of Operations converted] datetime,
										  [Created Date converted] DATETIME;
------------------------------------------------------------------------------------------------------------------------------------
--Converting [Created Date converted] from 'nvarchar' to 'dateTIME' datatype
--POPULATING the NEW COLUMN by converting string data:                                             
UPDATE dbo.[Company LAF Details] SET [Created Date converted] = CONVERT(DATETIME,[Created Date], 104);

 --Converting Date_of_Incorporation feature from 'nvarchar' to 'dateTIME' datatype
--POPULATING the NEW COLUMN by converting string data:
UPDATE dbo.[Company LAF Details] SET [Date of Incorporation converted] = CONVERT(DATETIME,[Date of Incorporation], 104);

----Converting Commencement_Of_Operations feature from 'nvarchar' to 'datetime' datatype
--POPULATING the NEW COLUMN by converting string data:
UPDATE dbo.[Company LAF Details] SET [Commencement Of Operations converted]= CONVERT(DATETIME,[Commencement Of Operations], 104);

-------------------------------------------------------------------------------------------------------------------------------------
------[y label] introduction in [company laf details] table
--First, [RejectionReason],[Status] columns have to be merged into [company laf details] table by comparing [laf number] from [y label] table
alter table [company laf details] 
add [RejectionReason] nvarchar(255),[Status] nvarchar(255),[Status 2] nvarchar(255);
update B
SET B.[RejectionReason]=TEMP.[RejectionReason],
    B.[Status]=TEMP.[Status]
FROM [Company LAF Details] B
inner join
[y label] TEMP
ON 
B.[Loan Application Number]= TEMP.[LAF number]
--removing rows with status ='cold'
DELETE FROM [Company LAF Details]
WHERE [Status]= 'cold';--25 rows removed
--updating [status 2] :when [stage of the Deal] ='disbursed', then [Status 2]='approved'
update [Company LAF Details]
set [Status 2]=CASE [Stage of the Deal] 
				 WHEN 'Disbursed' THEN 'Approved' 
				 WHEN 'documentation' THEN 'Approved'
				 WHEN 'Partially Disbursed' THEN 'Approved'
				 WHEN 'Sanctioned' THEN 'Approved'
				 WHEN 'Rejected' THEN 'Rejected'
				 WHEN 'Pre Due Diligence' THEN 'Rejected'
				 WHEN 'Due Diligence' THEN 'Rejected'
				 end;
select [status],[status 2],[Stage of the deal] from [Company LAF Details]
--when [status]='hold' then [Status 2]='Rejected'
--temp table needs to be created here otherwise updation is over riding previous step
select [Laf number] as [laf number],
       [RejectionReason] as [RejectionReason],
	   [Status] as [Status] into [## y label copy] 
from [y label]--temp table having 3 columns which will be needed ahead for calculations
update B
SET B.[Status 2]='Rejected'
FROM [Company LAF Details] B
inner join
[## y label copy] TEMP
ON 
B.[Loan Application Number]= TEMP.[laf number] WHERE B.[status]='hold'--81 rows affected
-- if [RejectionReason] is in the given list(for which we are making a temp table) then [status 2] = 'rejected'.
--merging will happen by comparing rejection reason
create table [##Rejection]([rejection list] nvarchar(255)) 
INSERT INTO [##Rejection]([rejection list]) VALUES ('Lower Debt Required'),('Non-target sector'),('Financial Performance'),
('Sector with temporary issues'),('Transparency issues'),('Bad reference'),('Governance')
select * from [##Rejection]
--now check and merge into main table
update B
SET B.[Status 2]='Rejected'
FROM [Company LAF Details] B
inner join
[##Rejection] TEMP
ON 
B.[RejectionReason]= TEMP.[rejection list]--51 rows
alter table [Company LAF Details]drop column [RejectionReason],[status]



--calculating and pushing values for [ratio of women employees] feature created in LAF TABLE
--we also need to fill null values first in [Total payroll woman column] with AVG value before calculating this ratio feature
--filling values which are null in [total payroll woman] column with mean of entire column
SELECT [client id] as [client id],
       [Total Payroll Woman] as [Total Payroll Woman],
	   [Loan Application Number] AS [Loan Application Number]
	   INTO [temp table for updating women ratio] 
from [main laf]--new  table for updating women ratio
select * from  [temp table for updating women ratio];

SELECT  * INTO ##TEMP_TABLE_FOR_WOMEN_EMP--NEW TEMP TABLE having rows where [Total Payroll Woman] is null
     FROM [temp table for updating women ratio] 
	 where [Total Payroll Woman] is null;
--(these null values in [Total Payroll Woman] should be filled with avg value now)         
 
 UPDATE  ##TEMP_TABLE_FOR_WOMEN_EMP
SET[Total Payroll Woman]= (select AVG([Total Payroll Woman]) 
                 FROM [temp table for updating women ratio] );--updates null values in this temp table which now have to be merged with 
				                                               --[temp table for updating women ratio] (will be laf )
update b
set b.[Total Payroll Woman]=TEMP.[Total Payroll Woman]
FROM  [temp table for updating women ratio] b
INNER JOIN
##TEMP_TABLE_FOR_WOMEN_EMP TEMP
ON b.[client id] = TEMP.[client id]--merges null values into [temp table for updating women ratio] table
--THIS COLUMN HAS TO BE MERGED WITH [Company LAF Details] TABLE.
update b
set b.[Total Payroll Woman]=TEMP.[Total Payroll Woman]
FROM  [Company LAF Details] b
INNER JOIN
[temp table for updating women ratio] TEMP
ON b.[client id] = TEMP.[client id]
---NOW WE CAN EASILY CALCULATE [ratio of women employees]
UPDATE dbo.[Company LAF Details]SET
    [ratio of women employees]=([Total Payroll Woman]/nullif([Total Payroll Employee],0)*100)



------calculating and pushing values for [bod count] feature created--------------------------------------
SELECT * INTO [BOD] FROM [BOD TABLE]--creating a copy of original [bod TABLE] WHERE WILL PUSH ALL NEW VALUES CREATED AND LATER ON, THIS TABLE CAN BE USED TO PUSH ALL VALUES INTO [COMPANY LAF] TABLE
--CREATING NEW TEMP TABLE CALLED ##BOD_TEMP WHERE NAMES OF ALL BOD'S ARE PRESENT I.E. NO NAME IS NULL
SELECT * INTO ##BOD_TEMP from [BOD TABLE] WHERE [First Name] IS NOT NULL;
ALTER TABLE [##BOD_TEMP] ADD [bod count] float;
SELECT * FROM [BOD] 
UPDATE ##BOD_TEMP----calculates [bod count] by taking groupby of each lafnum
SET [bod count]= (select count([Loan Application Number]) 
                 FROM ##BOD_TEMP b
                 WHERE b.[Loan Application Number]=##BOD_TEMP.[Loan Application Number]
			      GROUP BY b.[Loan Application Number]) ;
--[bod count] FEATURE IS CURRENTLY IN ##BOD_TEMP TABLE. HENCE,PUSHING IT INTO NEW COLUMN 'BOD_COUNT' IN [BOD] TABLE USING JOINS
ALTER TABLE [BOD] ADD BOD_COUNT FLOAT;
UPDATE B1
SET 
B1.BOD_COUNT=TEMP.[bod count]
FROM  [BOD] B1
INNER JOIN
##BOD_TEMP TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]
--UPDATING INTO [COMPANY LAF] TABLE'S [bod counts] COLUMN. This will have to done twice once using client id's and once using laf num
UPDATE B1
SET 
B1.[bod counts]=TEMP.[BOD_COUNT]
FROM  [Company LAF Details] B1
INNER JOIN
[BOD] TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]
UPDATE B1
SET 
B1.[bod counts]=TEMP.[BOD_COUNT]
FROM  [Company LAF Details] B1
INNER JOIN
[BOD] TEMP
ON B1.[Client Id] = TEMP.[client id]



---------calculating and pushing values for [kmp count] feature created-------------------------------------------
SELECT * INTO [KMP] FROM [KMP TABLE];--MAKING A COPY OF IMPORTED TABLE 
ALTER TABLE [KMP] ADD [KMP count] float;--ADDING [KMP COUNT] COLUMN IN KMP
SELECT * INTO ##KMP_TEMP from [KMP] WHERE [Name] IS NOT NULL;--creates new ##KMP_TEMP temp table where names of all kmp's are present and no name is null 

UPDATE ##KMP_TEMP-- calculates [KMP count] by taking count of each laf num and doing group by
SET [KMP count]= (select count([Loan Application Number]) 
                 FROM ##KMP_TEMP k
                 WHERE k.[Loan Application Number]=##KMP_TEMP.[Loan Application Number]
			      GROUP BY k.[Loan Application Number]) ;

--[kmp count] FEATURE IS CURRENTLY IN ##KMP_TEMP TABLE. HENCE,PUSHING IT INTO NEW COLUMN 'KMP COUNT' IN [BOD] USING JOINS
ALTER TABLE [BOD] ADD KMP_COUNT FLOAT;--IT WILL BE USED AHEAD.HENCE IS BEING MERGED INTO BOD
UPDATE B1
SET 
B1.KMP_COUNT=TEMP.[KMP count]
FROM  [BOD] B1
INNER JOIN
##KMP_TEMP TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]
--UPDATING INTO [COMPANY LAF] TABLE'S [kmp counts] COLUMN. This willbe done twice. once using [loan app num] and then [client id]
UPDATE B1
SET 
B1.[kmp counts]=TEMP.[KMP_COUNT]
FROM  [Company LAF Details] B1
INNER JOIN
[BOD] TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]
UPDATE B1
SET 
B1.[kmp counts]=TEMP.[KMP_COUNT]
FROM  [Company LAF Details] B1
INNER JOIN
[BOD] TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]



--calculating and pushing values for [Nominated] feature created
ALTER TABLE dbo.[BOD] ADD [Nominated] float;--new column added in [BOD] table
 UPDATE [BOD] 
SET[Nominated]= (select count([Loan Application Number]) 
                 FROM [BOD] B
                 WHERE B.[Board of Director Type] = 'Nominated'
			     AND B.[Loan Application Number]=[BOD].[Loan Application Number]);                                                                                           
--UPDATING INTO [COMPANY LAF] TABLE'S [Nominated] COLUMN
UPDATE B1
SET 
B1.[Nominated]=TEMP.[Nominated]
FROM  [Company LAF Details] B1
INNER JOIN
[BOD] TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]



--calculating and pushing values for [percent Nominated] feature created 
ALTER TABLE dbo.[BOD] ADD [Percent Nominated] float;
UPDATE [BOD]
SET
   [Percent Nominated]=([Nominated]/nullif([BOD_COUNT],0)*100);
----UPDATING INTO [COMPANY LAF] TABLE'S [Percentage of Nominated] COLUMN.

UPDATE B1
SET 
B1.[kmp counts]=TEMP.[KMP_COUNT]
FROM  [Company LAF Details] B1
INNER JOIN
[BOD] TEMP
ON B1.[Client Id] = TEMP.[client id]



--calculating and pushing values for [fi non fi] feature directly into [laf] table----------------------------------------------
UPDATE dbo.[Company LAF Details] set 
 [FI or nonfi]= 
 case
  WHEN [Sector of Operation: Sector Name] in ('Microfinance', 'Small Business Finance',
              'Business Correspondent for NBFC/Banks',  'Housing Finance', 
              'Financial Services (non-lending)', 'Others (Financial Inclusion)') THEN 'FI'
 WHEN [Sector of Operation: Sector Name] in ('Food & Agriculture','Education', 'Healthcare','Rural Distribution Channels',
       'Cleantech', 'Skill Development', 'Affordable Housing',
       'Non-farm Livelihoods','Drinking Water','Sustainability Certified Business', 'Sanitation & Hygiene',
        'ICT for Development', 'Others') THEN 'NON_FI'
END;

--------------------calculating and pushing values for [directors age]
ALTER table [dbo].[BOD] add [Created Date converted] DATEtime ;--adding new column FROM LAF SHEET HERE TO CALCULATE director's age
 select * from 	[dbo].[BOD]								       --WHERE DIRECTOR'S AGE IS DIFFERENCE OF DOB & CREATED DATE              
------ using joins
UPDATE B1
SET 
B1.[Created Date converted]=TEMP.[Created Date converted]
FROM  [BOD] B1
INNER JOIN
[Company LAF Details] TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]--UPDATES [Created Date converted] COLUMN FROM LAF SHEET INTO [BOD]

alter table [dbo].[BOD] add [Director's age] float ;--adding new column IN BOD
alter table [dbo].[BOD] add [MEAN Director's age] float ;--adding new column IN BOD
UPDATE dbo.[BOD]
SET  [Director's age]=(DATEDIFF(mm,[Date Of Birth], [Created Date converted])/12.0);---CALCULATES AGE OF DIRECTOR
UPDATE dbo.[BOD]
SET  [MEAN Director's age]= (select AVG([Director's age]) 
                            FROM [BOD] B
                             WHERE B.[Loan Application Number]=[BOD].[Loan Application Number]
			                 GROUP BY B.[Loan Application Number]) ;--UPDATES MEAN AGE FOR EACH CLIENT ID IN BOD TABLE
--updating this into [company laf ] table now
UPDATE B1
SET 
B1.[directors age]=TEMP.[MEAN Director's age]
FROM  [Company LAF Details] B1
INNER JOIN
BOD TEMP
ON B1.[Client id] = TEMP.[Client id]

--------------------------CALCULATING AND PUSHING VALUES FOR [DIRECTOR'S TENURE] COLUMN
--DIFFERENCE OF [Created Date converted]FROM BOD & [Date of Joining] FROM BOD AND THEN THEIR MEAN
--BUT [Date of Joining] NEEDS TO BE CONVERTED INTO DATETIME FIRST
select * FROM [BOD] where [loan application number]='APP-00000305'
alter table BOD add [mean dir tenure] float,[mean kmp tenure] float,[DOJ conv] datetime,[director's tenure] float, 
                  [kmp tenure] float,[doj kmp] datetime;--new columns added
UPDATE BOD SET [DOJ conv]=[Date of Joining]
UPDATE BOD SET [director's tenure]=(DATEDIFF(mm,[Date of Joining],[Created Date converted])/12.0)
UPDATE dbo.[BOD]
SET  [MEAN Dir tenure]= (select AVG([Director's tenure]) 
                            FROM [BOD] B
                             WHERE B.[Loan Application Number]=[BOD].[Loan Application Number]
			                 GROUP BY B.[Loan Application Number]) ;--UPDATES MEAN TENURE FOR EACH CLIENT ID IN BOD TABLE
--updating this into [company laf ] table now
UPDATE B1
SET 
B1.[directors tenure]=TEMP.[MEAN Dir tenure]
FROM  [Company LAF Details] B1
INNER JOIN
BOD TEMP
ON B1.[Client id] = TEMP.[Client id]
SELECT * FROM BOD
----SIMILARLY CALCULATING AND PUSHING VALUES FOR [KMP TENURE].WE ARE CALCULATING THIS IN BOD FIRST AND WILL LATER ON, PUSH IT INTO [COMPANY LAF]
--converting[kmp's doj] from nvarchar to datetime and storing in bod
UPDATE B1
SET 
B1.[doj kmp]=TEMP.[Date of Joining]
FROM  [BOD] B1
INNER JOIN
KMP TEMP
ON B1.[Client id] = TEMP.[Client id]
UPDATE BOD SET [KMP tenure]=(DATEDIFF(mm,[doj kmp],[Created Date converted])/12.0)
UPDATE dbo.[BOD]
SET  [MEAN kmp tenure]= (select AVG([kmp tenure]) 
                            FROM [BOD] B
                             WHERE B.[Loan Application Number]=[BOD].[Loan Application Number]
			                 GROUP BY B.[Loan Application Number]) ;--UPDATES MEAN TENURE FOR EACH CLIENT ID IN BOD TABLE
--updating this into [company laf ] table now
UPDATE B1
SET 
B1.[kmp tenure]=TEMP.[MEAN kmp tenure]
FROM  [Company LAF Details] B1
INNER JOIN
BOD TEMP
ON B1.[Client id] = TEMP.[Client id]
--ALSO, Filling [kmp tenure] with [bod tenure] where kmp tenure is null
update B   
set B.[kmp tenure]=TEMP.[directors tenure]
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[kmp tenure] IS NULL;






------calculating and pushing values for [KMP BOD RATIO]-----doing this in bod first and later merging into [company laf]
ALTER TABLE [BOD] ADD [KMP BOD RATIO] FLOAT;
UPDATE dbo.[BOD]
 SET   [KMP BOD RATIO]=([KMP_COUNT]/nullif([BOD_COUNT],0))
--updating this into [company laf ] table now once using [client id] 
UPDATE B1
SET 
B1.[kmp bod ratio]=TEMP.[KMP BOD RATIO]
FROM  [Company LAF Details] B1
INNER JOIN
BOD TEMP
ON B1.[Client id] = TEMP.[Client id]


------calculating and pushing values for [KMP BOD COUNT] RATIO
SELECT [full name],[Loan Application Number],[KMP BOD COUNT] FROM [bod COUNTS] WHERE [Loan Application Number]='APP-00000278';
select * from [BOD]
ALTER TABLE [BOD] ADD [KMP as BOD COUNT] FLOAT,[KMP BOD COUNT ratio] FLOAT,[FULL NAME KMP] VARCHAR(255);--adds new column in [bod] which will have [kmp as bod count] ratio
---first we will have to check whether name of bod=name of kmp.
ALTER TABLE dbo.[BOD] ADD [FULL NAME] VARCHAR(255);--new column in bod
 UPDATE [BOD]
 SET [FULL NAME]=(SELECT CONCAT([First Name],SPACE(1),[Last Name]));--merging [first name] column of bod with [last name]

ALTER TABLE [KMP] ADD [FULL NAME] VARCHAR(255);--NEW COLUMN CREATED TO MAKE CHANGES IN NAME AND REMOVE IRREGULARITIES
--UPDATES NAME OF KMP INTO NEW [FULL NAME] COLUMN
 UPDATE dbo.[KMP] SET [FULL NAME]='Subhrangsu Chankravorty' WHERE [Client id]='CII000037' and name='Mr. Subhrangsu Chankravorty'
 UPDATE dbo.[KMP] SET [FULL NAME]='Aditya Narayan Parida' WHERE [Client id]='CII000059' and name='Mr. Aditya Narayan Parida'
 UPDATE dbo.[KMP] SET [FULL NAME]='Gagan Kumar Gahlot' WHERE [Client id]='CII000074' and name='Mr. Gagan Kumar Gahlot'
 UPDATE dbo.[KMP] SET [FULL NAME]='Saroj Topno' WHERE [Client id]='CII000138' and name='Ms. Saroj Topno'
 UPDATE dbo.[KMP] SET [FULL NAME]='Sakshi Sodhi' WHERE [Client id]='CII000051' and name='Ms. Sakshi Sodhi'
 UPDATE dbo.[KMP] SET [FULL NAME]='Rajagopalan Balasubramanian' WHERE [Client id]='CII000070' and name='Mr. Rajagopalan Balasubramanian'
 UPDATE dbo.[KMP] SET [FULL NAME]='Rajeev Ranjan' WHERE [Client id]='CII000112' and name='Mr. Rajeev Ranjan'
 UPDATE dbo.[KMP] SET [FULL NAME]='Aditya Narayan Parida' WHERE [Client id]='CII000059' and name='Mr. Aditya Narayan Parida'
 UPDATE dbo.[KMP] SET [FULL NAME]='Piyush Maheshwari' WHERE [Client id]='CII000047' and name='Mr. Piyush Maheshwari'
 UPDATE dbo.[KMP] SET [FULL NAME]='Manav Singh Gahlaut' WHERE [Client id]='CII000053' and name='Mr. Manav Singh Gahlaut'
 UPDATE dbo.[KMP] SET [FULL NAME]='Mithun Bose' WHERE [Client id]='CII000007' and name='Mr. Mithun Bose'
 UPDATE dbo.[KMP] SET [FULL NAME]='Arindam Paul' WHERE [Client id]='CII000087' and name='Mr Arindam Paul'
 UPDATE dbo.[KMP] SET [FULL NAME]='Nasir Bashir Sayed' WHERE [Client id]='CII000012' and name='Mr. Nasir Bashir Sayed'
 UPDATE dbo.[KMP] SET [FULL NAME]='Jeyseelan L' WHERE [Client id]='CII000026' and name='Jeyseelan L'
 UPDATE dbo.[KMP] SET [FULL NAME]='Joby C O' WHERE [Client id]='CII000006' and name='Mr. Joby C O'
 UPDATE dbo.[KMP] SET [FULL NAME]='Richa Sharma' WHERE [Client id]='CII000007' and name='Ms. Richa Sharma'
 UPDATE dbo.[KMP] SET [FULL NAME]='Nikesh Kumar Sinha' WHERE [Client id]='CII000015' and name='Mr. Nikesh Kumar Sinha'
 UPDATE dbo.[KMP] SET [FULL NAME]='Sorabh Malhotra' WHERE [Client id]='CII000018' and name='Mr. Sorabh Malhotra'
 UPDATE dbo.[KMP] SET [FULL NAME]='Makarand Kulkarni' WHERE [Client id]='CII000053' and name='Dr. Makarand Kulkarni'
 UPDATE dbo.[KMP] SET [FULL NAME]='Unnikrishnan Nair' WHERE [Client id]='CII000088' and name='Mr. Unnikrishnan Nair'
 UPDATE dbo.[KMP] SET [FULL NAME]='Krishna Kalyan T D' WHERE [Client id]='CII000094' and name='Mr. Krishna Kalyan T D'
 UPDATE dbo.[KMP] SET [FULL NAME]='Prashun Purkastha' WHERE [Client id]='CII000107' and name='Mr Prashun Purkastha'
 UPDATE dbo.[KMP] SET [FULL NAME]='ajit nigam' WHERE [Client id]='CII000311' and name='Dr Ajit Nigam'
 UPDATE dbo.[KMP] SET [FULL NAME]='saritha ramanath' WHERE [Client id]='CII000201' and name='Sarita Ramnath'
 UPDATE dbo.[KMP] SET [FULL NAME]='dasalakuntey venkatesh' WHERE [Client id]='CII000148' and name='Dasalkuntey Venkatesh'
 UPDATE dbo.[KMP] SET [FULL NAME]='balasubramanian narayanan' WHERE [Client id]='CII000013' and name='Balasubramian N,'
 UPDATE dbo.[KMP] SET [FULL NAME]='steven edwin hardgrave' WHERE [Client id]='CII000025' and name='Steven Hardgrave'
 UPDATE dbo.[KMP] SET [FULL NAME]='thirunavukkarasu rajendran' WHERE [Client id]='CII000012' and name='R.Thirunavukkarasu'
 UPDATE dbo.[KMP] SET [FULL NAME]='ganesan subramanian' WHERE [Client id]='CII000122' and name='Ganesh Subramanian'
 UPDATE dbo.[KMP] SET [FULL NAME]='ramaswamy pratap' WHERE [Client id]='CII000025' and name='Pratap R'
 UPDATE dbo.[KMP] SET [FULL NAME]='hardur manjunatha dattatri' WHERE [Client id]='CII000202' and name='Dattatri HM'
 UPDATE dbo.[KMP] SET [FULL NAME]='alfred david kanjirakkatt' WHERE [Client id]='CII000202' and name='Alfred David'
 UPDATE dbo.[KMP] SET [FULL NAME]='madhusudhan akkara veetil' WHERE [Client id]='CII000123' and name='Mr. Madhu Sudhan A V'
 UPDATE dbo.[KMP] SET [FULL NAME]='sachin chhabra chhabra' WHERE [Client id]='CII000255' and name='Sachin Chhabra'
 UPDATE dbo.[KMP] SET [FULL NAME]='vinay kumar pandey' WHERE [Client id]='CII000331' and name='Mr Vinay Kumar Pandey'
 UPDATE dbo.[KMP] SET [FULL NAME]='rajesh krishnamurthy' WHERE [Client id]='CII000094' AND [name]='Mr.Rajesh Krishnamurthy'
 UPDATE dbo.[KMP] SET [FULL NAME]='krishnakalyan thiruvannamalai dhandapani' WHERE [Client id]='CII000094' AND [name]='Mr. Krishna Kalyan T D'
 UPDATE dbo.[KMP] SET [FULL NAME]='rokkam raja pradeep' WHERE [Client id]='CII000213' and name='RAJA PRADEEP ROKKAM'
 UPDATE dbo.[KMP] SET [FULL NAME]='suryanarayanan subramanian' WHERE [Client id]='CII000205' and name='Subramaninan'
 UPDATE dbo.[KMP] SET [FULL NAME]='varsha akshay shah' WHERE [Client id]='CII000238' and name='Akshay Shah'
 UPDATE dbo.[KMP] SET [FULL NAME]='vivek arun modi' WHERE [Client id]='CII000259' and name='Vivek Modi'
 UPDATE dbo.[KMP] SET [FULL NAME]='prabakaran thangavelu' WHERE [Client id]='CII000257' and name='V T PRABAKARAN'
 UPDATE dbo.[KMP] SET [FULL NAME]='shripad anant kulkarni' WHERE [Client id]='CII000334' and name='SHRIPAD KULKARNI'
 UPDATE dbo.[KMP] SET [FULL NAME]='gopinath ramachandra rao mallipatna' WHERE [Client id]='CII000211' AND name='Gopinath Mallipatna'
 UPDATE dbo.[KMP] SET [FULL NAME]='prateep basu' WHERE [Client id]='CII000211' AND name='Pradeep Basu' 
 UPDATE dbo.[KMP] SET [FULL NAME]='KIRAN MANDYAM ANANDAMPILLAI' WHERE [Client id]='CII000056' and name='Kiran Anandampillai'
 UPDATE dbo.[KMP] SET [FULL NAME]='MAMIDIPUDI GIRIDHAR KRISHNA' WHERE [Client id]='CII000060' and name='M Giridhar Krishna'
 UPDATE dbo.[KMP] SET [FULL NAME]='HARI PRASAD SHARMA' WHERE [Client id]='CII000086'AND name='Mr. Hari Sharma'
 UPDATE dbo.[KMP] SET [FULL NAME]='satyendra kumar' WHERE [Client id]='CII000086' AND name='Mr. Hari Sharma'
 UPDATE dbo.[KMP] SET [FULL NAME]='anand sivaraman' WHERE [Client id]='CII000121' and name='Dr. Anand Sivaraman'
 UPDATE dbo.[KMP] SET [FULL NAME]='monish ahuja' WHERE [Client id]='CII000088' and name='Lt Col Monish Ahuja'
 UPDATE dbo.[KMP] SET [FULL NAME]='pradeep kumar rapole' WHERE [Client id]='CII000095' and name='Pradeep Rapole'
 UPDATE dbo.[KMP] SET [FULL NAME]='DYANBELLIAPPA NADIKERIANDA NANAYA' WHERE [Client id]='CII000050' AND name='Dyan Belliappa'
 UPDATE dbo.[KMP] SET [FULL NAME]='SATYANARAYANA VEJELLA' WHERE [Client id]='CII000050' AND name='V. Satyanarayana'
 UPDATE dbo.[KMP] SET [FULL NAME]='bhagavathi narayanan subramaniam' WHERE [Client id]='CII000119' and name='Bhagavathi Subramaniam Narayanan'
 UPDATE dbo.[KMP] SET [FULL NAME]='harvinder pal singh' WHERE [Client id]='CII000051' and name='Mr. H P Singh'
 UPDATE dbo.[KMP] SET [FULL NAME]='ashok mittal' WHERE [Client id]='CII000251' and name='Ashok Kumar Mittal'
 UPDATE dbo.[KMP] SET [FULL NAME]='arun kumar biswal' WHERE [Client id]='CII000009' and name='Arunkumar Biswal'
 UPDATE dbo.[KMP] SET [FULL NAME]='chittur parasuram viswanath' WHERE [Client id]='CII000108' and name='C.P. Viswanath'

UPDATE B1
SET B1.[FULL NAME KMP]=TEMP.[FULL NAME]
FROM  [BOD] B1
INNER JOIN
[KMP] TEMP
ON B1.[FULL NAME] = TEMP.[FULL NAME];--MERGING [FULL NAME] ONLY IF FULL NAME FROM BOD=FULL NAME FROM KMP
--CHECK IF BOD IS ALSO KMP  AND TAKING COUNT THEREAFTER
SELECT  COUNT( *) AS COUNTNUM,[Loan Application Number] AS [Loan Application Number] INTO ##TEMPT--TEMP TABLE TO STORE VALUES
                     FROM [BOD] B                                                              
                     WHERE B.[FULL NAME]=B.[FULL NAME KMP]
                     GROUP BY B.[Loan Application Number]
UPDATE B1
SET B1.[KMP as BOD COUNT]=TEMP.COUNTNUM
FROM  [BOD] B1
INNER JOIN
[##TEMPT] TEMP
ON B1.[Loan Application Number] = TEMP.[Loan Application Number]

UPDATE [BOD]
 SET [KMP BOD COUNT ratio]=([KMP as BOD COUNT]/nullif([BOD_COUNT],0))
 --updating this into [company laf ] table now 
 alter table [company LAF Details] add [kmp as bod count] int;
 UPDATE B1
SET 
B1.[kmp as bod count]=TEMP.[KMP as BOD count]
FROM  [Company LAF Details] B1
INNER JOIN
BOD TEMP
ON B1.[Loan application number] = TEMP.[Loan application number]
UPDATE B1
SET 
B1.[kmp as bod count ratio]=TEMP.[KMP BOD count RATIO]
FROM  [Company LAF Details] B1
INNER JOIN
BOD TEMP
ON B1.[Loan application number] = TEMP.[Loan application number]



-------------------------------FOR [PERCENT CHANGE EMPLOYEES]---------------------------------
--first we will have to DEAL WITH NULL VALUES in [Total Payroll Employee],[Total Payroll Employee Before Year] columns of [laf] table 
--for which we have imported [SAVERISK EMP] 

select * from [Company LAF Details]where [Total Payroll Employee] is null--84 rows found where [total payroll] value has to be filled
select * into ##T--temp table which is duplicate of [SAVERISK EMP]
from [SAVERISK EMP] 
ALTER TABLE ##T ADD [max period] datetime,--new columns to find max and min periods
					 [min period] datetime,[CONV MONTH] nvarchar(255),[CONV PERIOD] nvarchar(255),[conv period copy] NVARCHAR(255),
					 [conv period DATETIME] DATETIME,[uniform client id] nvarchar(255), [len of id] int;
UPDATE ##T SET [CONV PERIOD]=(LEFT([PERIOD],4)+'-'+SUBSTRING([PERIOD],7,4)) --EXRACTS PERIOD 
 --[CONV PERIOD COPY]column WILL HAVE DATE IN DDMMYYYY format (but is varchar)  WHICH WILL BE LATER CONVERTED INTO DATETIME
--doing corrections on [CONV MONTH] to get data in targetted format
SELECT * FROM ##T1 where [client id] ='DC104'
update ##T set [CONV MONTH]= (LEFT([CONV PERIOD],4))--EXTRACTS MONTHS AS 'JAN' in words
--UPDATING MONTHS AS NUMBERS
UPDATE ##T SET [CONV MONTH]=CASE [conv MONTH]
									WHEN 'Jan ' THEN '01'
									WHEN 'Feb ' THEN '02'
									WHEN 'Mar ' THEN '03'
									WHEN 'Apr ' then '04'
									WHEN 'May ' then '05'
									WHEN 'Jun ' then '06'
									WHEN 'Jul ' then '07'
									WHEN 'Aug ' then '08'
									WHEN 'Sep ' then '09'
									WHEN 'Oct ' then '10'
									WHEN 'Nov ' then '11'
									WHEN 'Dec ' then '12'
							        else null end; 
UPDATE ##T
SET [conv period copy]=('01'+'/'+LEFT([CONV MONTH],3)+'/'+SUBSTRING([CONV PERIOD],6,3))
--NOW THIS [CONV PERIOD COPY] NEEDS TO BE CONVERTED INTO DATETIME FROM NVARCHAR
UPDATE ##T SET[conv period datetime]=([conv period copy])--CONVERTING FROM NVARCHAR TO DATETIME
SELECT * FROM ##t order by [client id]
UPDATE ##T-- calculates max date for each client id IN ##T1 
SET [max period]= (select max([conv period datetime]) --------------------error= THIS RESOLVES NAVNI'S ERROR
                 FROM ##T t1
                 WHERE t1.[client id]=##T.[client id]
			      GROUP BY t1.[client id]) ;
UPDATE ##T-- calculates min  date for each client id
SET [min period]= (select min([conv period datetime]) -----------------------error
                 FROM ##T t1
                 WHERE t1.[client id]=##T.[client id]
			      GROUP BY t1.[client id]) ;
--NOW WE WILL BE MAKING [CLIENT ID UNIFROM] SO THAT MERGING CAN BE TAKEN PLACE INTO [COMPANY LAF] LATER ON
UPDATE  ##T SET [uniform client id]=[client id];--MAKING IT DUPLICATE OF [CLIENT ID] COLUMN FIRST
--calculating len of each [client id]
UPDATE ##T 
SET [len of id]= (select LEN(t1.[client id]) 
                  FROM ##T t1
                  WHERE t1.[client id]=##T.[client id]
			      GROUP BY t1.[client id]) ;
SELECT * FROM ##T
-- updating values into [uniform client id] column only where len=7 for which a temp table is needed
select 'CII000'+RIGHT([client id],3) as [uniform client id], 
         [client id] as [client id] 
		 into ##TEMP_TABLE_FOR_CLIENT
 from ##T t 
 WHERE t.[len of id]=7;--temp table created having [uniform client id]
--now this [uniform client id] is merged back into ##T
UPDATE B1
set
B1.[uniform client id]=TEMP.[uniform client id]
FROM  [##T] B1
INNER JOIN
##TEMP_TABLE_FOR_CLIENT TEMP
ON B1.[Client id] = TEMP.[Client id] WHERE B1.[len of id]=7;

SELECT  * FROM ##T where [len of id]='7';--len'3' and '2' have only numbers;len'5' ignored as starts with"DC"; len'6' starts with"DUMMY" 
--filling null values OF [Total Payroll Employee] column belonging to [company and LAF] TABLE 
--with [employee] from ##T1 where [conv period DATETIME]=[max period]
select [Client id]	AS [Client id]	,[Total Payroll Employee] AS [Total Payroll Employee] INTO [TEMP PAYROLL] 
from [main laf]where [Total Payroll Employee] is null--TABLE CREATED HAVING [Total Payroll Employee] AS NULL

select * from [TEMP PAYROLL];
update B   --filling [employee] into [Total Payroll Employee] 
set B.[Total Payroll Employee]=TEMP.[Employee]
FROM [TEMP PAYROLL] B 
INNER JOIN
##T TEMP
ON B.[Client id] = TEMP.[uniform Client id]	WHERE TEMP.[conv period datetime]=TEMP.[max period]

--merging this [temp payroll emp] into [main laf OR COMPANY LAF] 
update B 
set B.[Total Payroll Employee]=TEMP.[Total Payroll Employee]
FROM [Company LAF Details] B 
INNER JOIN
[TEMP PAYROLL] TEMP
ON B.[Client id] = TEMP.[Client id]	

-------DEALING WITH NULL VALUES in [Total Payroll Employee Before Year] column ------------------------------------------------------------------
SELECT [Client id]	AS [Client id]	,[TOTAL PAYROLL EMPLOYEE BEFORE YEAR] AS [TOTAL PAYROLL EMPLOYEE BEFORE YEAR] 
INTO [TEMP PAYROLL BEFORE YR] FROM [main laf] WHERE [TOTAL PAYROLL EMPLOYEE BEFORE YEAR] IS NULL--TABLE  HAVING [Total Payroll Employee BEFORE YEAR]=NULL
--83 ROWS
--first we will have to merge [max period] ,[min period]  in this [TEMP PAYROLL BEFORE YR] table from earlier created temporary table ##T1 & ##T
alter table [TEMP PAYROLL BEFORE YR] add [max] datetime, [min] datetime,[difference] int;

update B 
set B.[max]=TEMP.[max period]
FROM [TEMP PAYROLL BEFORE YR] B 
INNER JOIN
##T TEMP
ON B.[Client id] = TEMP.[uniform Client id]	--merging [max] here--78 rows affected

--now we can fetch [min period]column easily by comparing [uniform client id] from ##T1 & [client id] from [TEMP PAYROLL BEFORE YR] 
update B 
set B.[min]=TEMP.[min period]
FROM [TEMP PAYROLL BEFORE YR] B 
INNER JOIN
##T TEMP
ON B.[Client id] = TEMP.[uniform Client id]
--calculating [difference]now in months
update [TEMP PAYROLL BEFORE YR] set [difference]=(DATEDIFF(mm,min,max))
--if [difference]<12, then take [employee]count where[min period]=[conv period datetime]
--if [difference]>12, then take [employee]count where [max period]=[max period - 1] i.e. same date of previous year and then [max period - 1]=[conv period datetime]
select * from [Temp PAYROLL BEFORE YR]
--now we can push [employee count] accordingly into [TEMP PAYROLL BEFORE YR] table by matching their [client id]
update B   --filling [employee count] into [Total Payroll Employee before year] column of [TEMP PAYROLL BEFORE YR] table
set B.[TOTAL PAYROLL EMPLOYEE BEFORE YEAR]=TEMP.[employee]--this will take place for (difference<12)
FROM [TEMP PAYROLL BEFORE YR] B 
INNER JOIN
##T TEMP
ON B.[Client id] = TEMP.[uniform Client id]	WHERE B.[difference]<12 AND TEMP.[conv period datetime]=B.[min];--0ROWS DONE

update B   
set B.[TOTAL PAYROLL EMPLOYEE BEFORE YEAR]=TEMP.[employee]--this will take place for (difference=12)
FROM [TEMP PAYROLL BEFORE YR] B 
INNER JOIN
##T TEMP
ON B.[Client id] = TEMP.[uniform Client id]	WHERE B.[difference]=12;--20 ROWS DONE

--for [difference>12], [max - 1] has to be done in a temporary table first
SELECT DATEADD(year, -1,[max] ) as [max-1],[client id] as [client id] 
     into [table for diff>12]
     FROM [TEMP PAYROLL BEFORE YR] ;--extra table created having [max-1] as [max ]date has 83 rows
--now this will be merged into [TEMP PAYROLL BEFORE YR] table's [max - 1 year] column 				 
alter table [TEMP PAYROLL BEFORE YR] add [max - 1 year] datetime;					 
update B   
set B.[max - 1 year]=TEMP.[max-1]
FROM [TEMP PAYROLL BEFORE YR] B 
INNER JOIN
[table for diff>12] TEMP
ON B.[Client id] = TEMP.[Client id];
 
 --now [max - 1 year]column from here will be compared with [conv period datetime]column of ##T
 --and then values pushed into [Total Payroll Employee Before Year] column of [TEMP PAYROLL BEFORE YR]
update B   
set B.[TOTAL PAYROLL EMPLOYEE BEFORE YEAR]=TEMP.[employee]--this will take place for (difference>12)
FROM [TEMP PAYROLL BEFORE YR] B 
INNER JOIN
##T TEMP
ON B.[Client id] = TEMP.[uniform Client id]	WHERE B.[difference]>12 AND B.[max - 1 year]=TEMP.[conv period datetime];--56 ROWS UPDATED
--havent merged this [TEMP PAYROLL BEFORE YR] into [ COMPANY LAF] TABLE yet
update B 
set B.[Total Payroll Employee Before Year]=TEMP.[Total Payroll Employee Before Year]
FROM [Company LAF Details] B 
INNER JOIN
[TEMP PAYROLL BEFORE YR] TEMP
ON B.[Client id] = TEMP.[Client id]	


--filling [Total Payroll Employee Before Year] with [Total Payroll Employee] where [Total Payroll Employee Before Year]=0
update B 
set B.[Total Payroll Employee Before Year]=TEMP.[Total Payroll Employee]
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	where TEMP.[Total Payroll Employee Before Year]=0



--calculating and pushing values for [percent change employees] feature created directly into [laf] table----------------------
UPDATE dbo.[Company LAF Details]SET
    [percent change employees]=(([Total Payroll Employee]-[Total Payroll Employee Before Year]) /nullif([Total Payroll Employee Before Year],0)*100)
drop table ##T, ##T1,##T2;

-----------Filling Missing values for the below features
--[Secondary Sector: Sector Name] WHERE '' THERE FILL WITH 'NONE'
update B   
set B.[Secondary Sector: Sector Name]='none'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Secondary Sector: Sector Name]='';

--[Is your business social / sustainability Certified?] WHERE '' THERE FILL WITH 'NO'
update B   
set B.[Is your business social / sustainability Certified?]='no'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Is your business social / sustainability Certified?]='';

--[Client Type] WHERE '' THERE FILL WITH 'Uknown'
update B   
set B.[Client Type]='Uknown'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Client Type]='';

--[Internal Audit Function] WHERE '' THERE FILL WITH 'no'
update B   
set B.[Internal Audit Function]='no'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Internal Audit Function]='';

--[Rating And Agency] WHERE '' THERE FILL WITH 'not rated'
update B   
set B.[Rating And Agency]='not rated'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Rating And Agency]='';

--[Rating] WHERE '' THERE FILL WITH 'not rated'
update B   
set B.[Rating]='not rated'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Rating]='';

--[Has the company raised funds from Venture Capital/ Private Equity/ Angel Investment?] where blank, fill with 'no'
update B   
set B.[Has the company raised funds from Venture Capital/ Private Equit]='no'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Has the company raised funds from Venture Capital/ Private Equit]='';

--[Any optional convertible debt?] where '' there 'no'
update B   
set B.[Any optional convertible debt?]='no'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Any optional convertible debt?]='';

--[Purpose of Loan]: this needs to be filled with mode values when [FI or nonfi]= 'fi' else 'uknown'
select count([Purpose of Loan]), [Purpose of Loan] from[Company LAF Details] group by[Purpose of Loan]--seeing mode value=142	Working Capital
																									-------------------132	OnLending					
update B   
set B.[Purpose of Loan]='Working Capital'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Purpose of Loan]='' AND B.[FI or nonfi]= 'FI';
update B   
set B.[Purpose of Loan]='uknown'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Purpose of Loan]='' AND B.[FI or nonfi]= 'NON_FI';

--[Business model] :for FI missing values fill by 'Financing' , for non_FI missing values fill by 'Others'
update B   
set B.[Business model]='Financing'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Business model]='' AND B.[FI or nonfi]= 'FI';
update B   
set B.[Business model]='others'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Business model]='' AND B.[FI or nonfi]= 'NON_FI';


--Removing [Sustainability Certified Business] from sector and replacing it by [Secondary sector]
update B   
set B.[Sector of Operation: Sector Name]=TEMP.[Secondary Sector: Sector Name]
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Sector of Operation: Sector Name]='Sustainability Certified Business'




--replacing [date of incorporation] values by [Description] COLUMN 
--for which we are importing saverisk's file [Date of incorporation] as [Incorporation date]
SELECT * into [##Incorporation date copy] from [Incorporation date]
alter table [##Incorporation date copy] add [uniform client id] nvarchar(255), [len of id] int;
UPDATE  [##Incorporation date copy] SET [uniform client id]=[client id];--MAKING IT DUPLICATE OF [CLIENT ID] COLUMN FIRST
--calculating len of each [client id]
UPDATE [##Incorporation date copy] 
SET [len of id]= (select LEN(t1.[client id]) 
                  FROM [##Incorporation date copy] t1
                  WHERE t1.[client id]=[##Incorporation date copy].[client id]
			      GROUP BY t1.[client id]) ;

-- updating values into [uniform client id] column only where len=7 for which a temp table is needed
select 'CII000'+RIGHT([client id],3) as [uniform client id], 
         [client id] as [client id] 
		 into [##TEMP_Incorporation date copy]
 from [##Incorporation date copy] t 
 WHERE t.[len of id]=7;--temp table created having [uniform client id]-----
--now this [uniform client id] is merged back into [##Incorporation date copy]
UPDATE B1
set
B1.[uniform client id]=TEMP.[uniform client id]
FROM  [##Incorporation date copy] B1
INNER JOIN
[##TEMP_Incorporation date copy] TEMP
ON B1.[Client id] = TEMP.[Client id] WHERE B1.[len of id]=7;
SELECT * FROM [##Incorporation date copy]
UPDATE B1
set
B1.[uniform client id]=TEMP.[client id]
FROM  [##Incorporation date copy] B1
INNER JOIN
[##Incorporation date copy] TEMP
ON B1.[Client id] = TEMP.[Client id] WHERE B1.[len of id]=9;--The ids having len 9 are also added-------------error by navni

---now check ids and merge in [company laf]
update B   
set B.[Date of Incorporation]=TEMP.[Description]
FROM [Company LAF Details] B 
INNER JOIN
[##Incorporation date copy] TEMP
ON B.[Client id] = TEMP.[uniform Client id]	WHERE B.[Date of Incorporation] IS NULL;
--converting  THIS COLUMN INTO DATETIME DATATYPE

select [Date of Incorporation] as [Date of Incorporation],[Client Id] as [Client id] 
into [##temp date inc] from [main laf]--creating temp table as facing issues while converting [date of incorporation] to datetime datatype
--error:conversion of a nvarchar data type to a datetime data type resulted in an out-of-range value.
--we'll have to convert date into a proper yyyy-mm-dd format first
select RIGHT([Date of Incorporation],4)+'-'+SUBSTRING([Date of Incorporation],4,2)+'-'+LEFT([Date of Incorporation],2) as [Date of Incorporation], 
         [client id] as [client id] 
		 into [##TEMP DATE INC]
 from [main laf]
 SELECT * FROM [##TEMP DATE INC]
 --now merge into a new column in [company laf] table
 --first we'll have to merge nulls here
 alter table [##TEMP DATE INC] add [conv dt incorporation] datetime;
update B 
set B.[conv dt incorporation]=TEMP.[Description]
FROM [##TEMP DATE INC] B 
INNER JOIN
[##Incorporation date copy] TEMP
ON B.[Client id] = TEMP.[uniform Client id]	WHERE B.[Date of Incorporation] IS NULL;
--merging newly created values into new column here first
update B 
set B.[conv dt incorporation]=TEMP.[Date of Incorporation]
FROM [##TEMP DATE INC] B 
INNER JOIN
[##TEMP DATE INC] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[conv dt incorporation] IS NULL;
--now merging this into [company laf]'s [Date of Incorporation converted] column
update B 
set B.[Date of Incorporation converted]=TEMP.[conv dt incorporation]
FROM [Company LAF Details] B 
INNER JOIN
[##TEMP DATE INC] TEMP
ON B.[Client id] = TEMP.[Client id]


--------------------Filling missing values for [Commencement of Operations] by [Date of Incorporation]
--we'll have to convert date into a proper yyyy-mm-dd format first
select RIGHT([Commencement of Operations],4)+'-'+SUBSTRING([Commencement of Operations],4,2)+'-'+LEFT([Commencement of Operations],2) as [Date of ops], 
         [client id] as [client id] 
		 into [##TEMP DATE OPS]
 from [main laf]
 SELECT * FROM [##TEMP DATE OPS]
 --now merge into a new column in [company laf] table BUT
 --first we'll have to merge these into new column having datetime datatype here
 alter table [##TEMP DATE OPS] add [conv dt OPS] datetime;
 update B 
set B.[conv dt OPS]=TEMP.[Date of ops]
FROM [##TEMP DATE OPS] B 
INNER JOIN
[##TEMP DATE OPS] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[Date of ops] IS NOT NULL;
--merging null values into new column here first
update B 
set B.[conv dt OPS]=TEMP.[Date of Incorporation CONVERTED]
FROM [##TEMP DATE OPS] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[conv dt OPS] IS NULL;
--now merging this into [company laf]'s 
update B 
set B.[Commencement Of Operations converted]=TEMP.[conv dt ops]
FROM [Company LAF Details] B 
INNER JOIN
[##TEMP DATE OPS] TEMP
ON B.[Client id] = TEMP.[Client id]




----FILLING COLUMN [Legal Issues?] where it is empty  or blank with values from saverisk
--for this, we imported "legal overview' sheet from saverisk as [Fill legal cases] table
 SELECT * from [Fill legal cases]
 --[client id] are in different lengths we will have to make them uniform first------------------------------
SELECT * into ##T-- CREATE temp table which is duplicate of [Fill legal cases]
from [Fill legal cases]

--[client id] column in ##T has irregularities..at some places it has len=5/7/9. so making it uniform as it will be needed ahead
alter table ##T add [uniform client id] nvarchar(255), [len of id] int;
UPDATE  ##t SET [uniform client id]=[client id];--MAKING IT DUPLICATE OF [CLIENT ID] COLUMN FIRST
--calculating len of each [client id]
UPDATE ##T 
SET [len of id]= (select LEN(t1.[client id]) 
                  FROM ##T t1
                  WHERE t1.[client id]=##T.[client id]
			      GROUP BY t1.[client id]) ;

-- updating values into [uniform client id] column only where len=7 for which a temp table is needed
select 'CII000'+RIGHT([client id],3) as [uniform client id], 
         [client id] as [client id] 
		 into ##TEMP_TABLE_FOR_CLIENTID
 from ##T t 
 WHERE t.[len of id]=7;--temp table created having [uniform client id]
--now this [uniform client id] is merged back into ##T
UPDATE B1
set
B1.[uniform client id]=TEMP.[uniform client id]
FROM  [##T] B1
INNER JOIN
##TEMP_TABLE_FOR_CLIENTID TEMP
ON B1.[Client id] = TEMP.[Client id] WHERE B1.[len of id]=7;------------------------------------------------CORRECT THIS STEP
UPDATE B1-----------------------------------------------------------HAS TO BE DELETED--------------------------------------------------
set
B1.[uniform client id]=TEMP.[client id]
FROM  [##T] B1
INNER JOIN
##T
ON B1.[Client id] = TEMP.[Client id] WHERE B1.[len of id]=9;----client ids having len 9 are also added back

--WE HAVE TO MERGE INTO [Company LAF Details]TABLE IF [uniform client id] OF ##T MATCHES [client id] OF [Company LAF Details]
SELECT [client id] as [client id],
       [Legal Issues?] as [Legal Issues?] 
into ##T1 FROM [Company LAF Details] WHERE [Legal Issues?] =''--new temp table from [laf] having [Legal Issues?] as blank
update B   --filling 'yes' into [LEGAL CASES?]COLUMN in [##T1]temp table first if client id's match 
set B.[Legal Issues?]='yes'
FROM [##T1] B 
INNER JOIN
##T TEMP
ON B.[Client id] = TEMP.[uniform Client id]--fills values as yes
--now remaining values have to be filled with 'no' as [client id] is not matching for which we need another temp table ##T2
select * into ##T2 from ##T1 --NEW temp table created again which has blank cells where 'no' has to be filled
where isnull([Legal Issues?],'') = ''

update B   --filling 'no' into remaining values of ##T2 table which will be then merged back into ##T1
set B.[Legal Issues?]='no'
FROM [##T2] B 
INNER JOIN
##T1 TEMP
ON B.[Client id] = TEMP.[Client id]	
--finally merging column having' no' back into ##T1
update B   
set B.[Legal Issues?]=TEMP.[Legal Issues?]
FROM [##T1] B 
INNER JOIN
##T2 TEMP
ON B.[Client id] = TEMP.[Client id]	
---------NOW IF [ CLIENT ID] OF ##T1 =[CLIENT ID] OF [COMPANY LAF] , THEN IT SHOULD MERGE VALUES IN [LEGAL ISSUES] column
update B   
set B.[Legal Issues?]=TEMP.[Legal Issues?]
FROM [Company LAF Details] B 
INNER JOIN
##T1 TEMP
ON B.[Client id] = TEMP.[Client id]	
select * from [main laf] where [Client Id]='CII000068'

----------------------------------FILLING [What is the turnover of your company?] COLUMN 
--FOR THIS, WE HAVE IMPORTED 'AUMSIZE' EXCEL SHEET' AS [AUM] TABLE AND MADE IT'S COPY
SELECT * INTO [AUM COPY] FROM [AUM] 
SELECT [Client Id] as [client id],
       [What is the turnover of your company?] as [What is the turnover of your company?]
	   INTO [##LAF COPY]
	   FROM [main laf] 
	   WHERE [What is the turnover of your company?] =''--MAKING TEMPORARY COPY OF ORGINAL DATASET WHERE [TURNOVER] COLUMN IS ''
--now client id's have to be compared of [##LAF COPY] and [AUM COPY] table and values filled in targetted column [turnover] OF [LAF COPY]
--which will be later merged back into [company laf] table
update B
SET B.[What is the turnover of your company?]=TEMP.[Assets Under Management]
FROM [##LAF COPY] B
inner join
[AUM COPY] TEMP
ON 
B.[client id]= TEMP.[client id]
select * from [##LAF COPY]
--NOW MERGING THESE BACK IN [COMPANY LAF]
update B
SET B.[What is the turnover of your company?]=TEMP.[What is the turnover of your company?]
FROM [Company LAF Details] B
inner join
[##LAF COPY] TEMP
ON 
B.[client id]= TEMP.[client id]
select COUNT([What is the turnover of your company?]),[What is the turnover of your company?]
from [Company LAF Details] GROUP BY [What is the turnover of your company?]--90 ROWS STILL HAVE BLANKS BECAUSE THIS LAF SHEET IS AN UPDATED ONE
--THIS [TURNOVER] COLUMN HAVING RANGE HAS TO BE CONVERTED INTO [CONVERTED TURNOVER IN CR] WHICH WILL HAVE MEAN VALUES

--for this, we are making a TEMPORARY copy of [company laf] table again having all rows
select [client id] as [client id],
       [What is the turnover of your company?] as [What is the turnover of your company?]
	   into [##laf copy 1] 
	   from [Company LAF Details] 
alter table[##laf copy 1] add [mean turnover in cr] float;--new column added to calculate mean
   
select count([What is the turnover of your company?]),[What is the turnover of your company?] 
from [##laf copy 1] group by[What is the turnover of your company?]--to see unique cases and fill mean value accordingly
SELECT distinct[What is the turnover of your company?] FROM  dbo.[Company LAF Details]-- views distinct values from turnover column

update [##laf copy 1]
set [mean turnover in cr]=CASE [What is the turnover of your company?] 
							WHEN '<₹ 1.5 Cr' THEN '1.5'
							WHEN '₹ 1.5 Cr-5 Cr' THEN '3.25'
                            WHEN '₹ 5 Cr-15 Cr' THEN '10'
							WHEN '₹ 15 Cr-30 Cr' THEN '22.5'
							WHEN '₹ 30 Cr-50 Cr' THEN '40'
							WHEN '₹ 50 Cr-100 Cr' THEN '75'
							WHEN '₹ 100 Cr-150 Cr' THEN '125'
							WHEN '>₹ 150 Cr' THEN '150'
							WHEN '100-250 Cr' THEN '175'
							WHEN '10-25 Cr' THEN '17.5'
							WHEN '250-500 Cr' THEN '375'
							WHEN '25-100 Cr' THEN '62.5'
							WHEN '500-1000 Cr' THEN '750'
							WHEN 'upto 10 Cr' THEN '10'
							WHEN '>1000 Cr' THEN '1000'
							ELSE NULL END;-- VALUES BEGINNING WITH '₹' SYMBOL ARE NOT GETTING READ.EG: '₹ 30 Cr-50 Cr', '>₹ 150 Cr'
SELECT [client id] as [client id],
       [What is the turnover of your company?]  as [What is the turnover of your company?] ,
	   [mean turnover in cr] as [mean turnover in cr]
       INTO [##LAF COPY 2.0] from [##laf copy 1] WHERE [mean turnover in cr] IS NULL;--new table created where mean is null 
alter table [##LAF COPY 2.0] add [changed turnover] varchar(255);
UPDATE [##LAF COPY 2.0] 
SET [changed turnover]=(SUBSTRING([What is the turnover of your company?],3,14))
--now mean can be calculated here easily
update [##LAF copy 2.0]
set [mean turnover in cr]=CASE [changed turnover] 
							WHEN ' 1.5 Cr' THEN '1.5'
							WHEN '1.5 Cr-5 Cr' THEN '3.25'
							WHEN '5 Cr-15 Cr' THEN '10'
							WHEN '15 Cr-30 Cr' THEN '22.5'
							WHEN '30 Cr-50 Cr' THEN '40'
							WHEN '50 Cr-100 Cr' THEN '75'
							WHEN '100 Cr-150 Cr' THEN '125'
							WHEN '150 Cr' THEN '150'
							ELSE NULL END;
--now these values have to be merged into [##laf copy 1]
update B
SET B.[mean turnover in cr]=TEMP.[mean turnover in cr]
FROM [##laf copy 1] B
inner join
[##LAF COPY 2.0] TEMP
ON 
B.[Loan Application Number]= TEMP.[Loan Application Number]

--NOW MERGING THESE VALUES INTO [MEAN TURNOVER IN CR] COLUMN OF [COMPANY AND LAF DETAILS]
update B
SET B.[converted turnover in cr]=TEMP.[mean turnover in cr]
FROM [Company LAF Details] B
inner join
[##laf copy 1] TEMP
ON 
B.[Loan Application Number]= TEMP.[Loan Application Number]
DROP TABLE [##laf copy 1],[##LAF COPY 2.0]



-------------CALCULATING AND PUSHING VALUES INTO [CONVERTED loan amt cr] COLUMN OF [Company LAF Details] TABLE
--for this, we are making a temporary copy of [main laf] table having all rows
select [client id] as [client id],
      [Amount Of Loan Required] as [Amount Of Loan Required]
	   into [##laf copy] 
	   from [main laf] 
	    
alter table[##laf copy] add [mean loan in cr] float;--new column added to calculate mean
SELECT DISTINCT [Amount Of Loan Required] FROM[##laf copy]--check unique values and calculate mean accordingly
update [##laf copy]
set [mean loan in cr]=CASE [Amount Of Loan Required] 
							WHEN '15cr-30cr' THEN '22.5'
							WHEN '1.5-5cr' THEN '3.25'
							WHEN '30Cr-50Cr' THEN '40'
							WHEN '<1.5 cr' THEN '1.5'
							WHEN '>150 Cr' THEN '150'
							WHEN '50Cr-100Cr' THEN '75'
							else null end
--not all values have been updated because of some irregularities like the rupee symbol
--hence we will have to create another temp table to deal with these null values
SELECT * INTO [##LAF copy 1] from [##laf copy] WHERE [mean loan in cr] IS NULL;
alter table [##laf copy 1] add [changed loan] varchar(255);--new column added where range of loan values will be corrected and updated
select * from [##laf copy]
UPDATE [##laf copy 1]
SET [changed loan]=(SUBSTRING([Amount Of Loan Required],3,14))
--now mean can be calculated here easily
update [##laf copy 1]
set [mean loan in cr]=CASE [changed loan] 
							WHEN '1 Cr-2.5 Cr' THEN '1.75'
							WHEN '2.5 Cr-5 Cr' THEN '3.75'
							WHEN '5 Cr-10 Cr' THEN '7.5'
							WHEN '50 L-1 Cr' THEN '0.75'
							WHEN '10 Cr+' THEN '10'
							ELSE NULL END;
--now this can be merged back into [##laf copy]
update B
SET B.[mean loan in cr]=TEMP.[mean loan in cr]
FROM [##laf copy] B
inner join
[##LAF COPY 1] TEMP
ON 
B.[Loan Application Number]= TEMP.[Loan Application Number]
--NOW MERGING THESE VALUES INTO [CONVERTED LOAN AMT CR] COLUMN OF [COMPANY AND LAF DETAILS]
update B
SET B.[converted loan amt cr]=TEMP.[mean loan in cr]
FROM [Company LAF Details] B
inner join
[##laf copy] TEMP
ON 
B.[Loan Application Number]= TEMP.[Loan Application Number]

-----filling NULL values of [converted loan amt cr] COLUMN. For this median values are needed separately for fi and non_fi columns
--we'll have to create separate temp tables for fi and non fi to do so 
select [converted loan amt cr] as [converted loan amt cr] 
into [## temp for fi] 
from [Company LAF Details] where [FI or nonfi]= 'FI'
select * from [## temp for fi]
SELECT
((SELECT MAX([converted loan amt cr]) FROM
   (SELECT TOP 50 PERCENT [converted loan amt cr] FROM [## temp for fi] ORDER BY [converted loan amt cr]) AS BottomHalf)
 +
 (SELECT MIN([converted loan amt cr]) FROM
   (SELECT TOP 50 PERCENT [converted loan amt cr] FROM [## temp for fi] ORDER BY [converted loan amt cr] DESC) AS TopHalf)) / 2 AS Median
--fi median= 7.5
--doing same for non_fi now
select [converted loan amt cr] as [converted loan amt cr] 
into [## temp for nonfi] 
from [Company LAF Details] where [FI or nonfi]= 'NON_FI'
SELECT
((SELECT MAX([converted loan amt cr]) FROM
   (SELECT TOP 50 PERCENT [converted loan amt cr] FROM [## temp for nonfi] ORDER BY [converted loan amt cr]) AS BottomHalf)
 +
 (SELECT MIN([converted loan amt cr]) FROM
   (SELECT TOP 50 PERCENT [converted loan amt cr] FROM [## temp for nonfi] ORDER BY [converted loan amt cr] DESC) AS TopHalf)) / 2 AS Median
-- non fi median=3.75
--UPDATING INTO [COMPANY] TABLE NOW
update B   
set B.[converted loan amt cr]='7.5'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[converted loan amt cr] IS null AND B.[FI or nonfi]= 'FI';
update B   
set B.[converted loan amt cr]='3.75'
FROM [Company LAF Details] B 
INNER JOIN
[Company LAF Details] TEMP
ON B.[Client id] = TEMP.[Client id]	WHERE B.[converted loan amt cr] IS NULL AND B.[FI or nonfi]= 'NON_FI';



---------------replacing values in[legal form of company] column of [Company LAF Details] table with appropriate values
--wherever 'public'word appears there it should be 'public limited' else update to 'private limited'
select distinct [Legal Form Of The Company] from [Company LAF Details]
update [Company LAF Details]
set [Legal Form Of The Company]= case [Legal Form Of The Company]
									WHEN '' THEN ''
									WHEN 'HFC' THEN 'private limited'
									WHEN 'NBFC' THEN 'private limited'
									WHEN 'NBFC Private Limited' THEN 'private limited'
									WHEN 'NBFC Public Limited' THEN 'public limited'
									WHEN 'NBFC-MFI Private Limited' THEN 'private limited'
									WHEN 'NBFC-MFI Public Limited' THEN 'public limited'
									WHEN 'Others' THEN 'private limited'
									WHEN 'Society' THEN 'private limited'
									WHEN 'Private Limited' THEN 'private limited'
									WHEN 'Public Limited' THEN 'public limited'
									else null end
---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
