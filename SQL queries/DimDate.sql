USE [gravity_books_dwh];
GO

---Drop FK if exsits

if exists
	(select * from sys.foreign_keys 
	where name='fk_fact_sales_dim_date'
	and parent_object_id=object_id('FactSales'))
alter table FactSales drop constraint fk_fact_sales_dim_date
go

if exists
		(select * from sys.tables
		where name='DimDate')
	drop table DimDate

go

--Make sure you set the Start and End Date below on row 58 and 59
--Create the tables
BEGIN TRY
 DROP TABLE [DimDate]
END TRY
BEGIN CATCH
 --DO NOTHING
END CATCH
CREATE TABLE [dbo].[DimDate](
 [DateSK] [int] IDENTITY(1,1) NOT NULL--Use this line if you just want an autoincrementing counter AND COMMENT BELOW LINE
 --[DateSK] [int] NOT NULL--TO MAKE THE ID THE YYYYMMDD FORMAT USE THIS LINE AND COMMENT ABOVE LINE.
 , [Date] [datetime] NOT NULL
 , [Day] [char](2) NOT NULL
 , [DaySuffix] [varchar](4) NOT NULL
 , [DayOfWeek] [varchar](9) NOT NULL
 , [DOWInMonth] [TINYINT] NOT NULL
 , [DayOfYear] [int] NOT NULL
 , [WeekOfYear] [tinyint] NOT NULL
 , [WeekOfMonth] [tinyint] NOT NULL
 , [Month] [char](2) NOT NULL
 , [MonthName] [varchar](9) NOT NULL
 , [Quarter] [tinyint] NOT NULL
 , [QuarterName] [varchar](6) NOT NULL
 , [Year] [char](4) NOT NULL
 , [StandardDate] [varchar](10) NULL
 CONSTRAINT [PK_DimDate] PRIMARY KEY CLUSTERED 
 (
 [DateSK] ASC
 )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
 ) ON [PRIMARY]

GO


---create FKs:
if exists
		(select * from sys.tables
		where name='FactSales')
	alter table FactSales
	add constraint fk_fact_sales_dim_date
	foreign key (FK_date_id)
	references DimDate(DateSK)
go


--Populate Date dimension

TRUNCATE TABLE DimDate

--IF YOU ARE USING THE YYYYMMDD format for the primary key then you need to comment out this line.
--DBCC CHECKIDENT (DimDate, RESEED, 60000) --In case you need to add earlier dates later.

DECLARE @tmpDOW TABLE (DOW INT, Cntr INT)--Table for counting DOW occurance in a month
INSERT INTO @tmpDOW(DOW, Cntr) VALUES(1,0)--Used in the loop below
INSERT INTO @tmpDOW(DOW, Cntr) VALUES(2,0)
INSERT INTO @tmpDOW(DOW, Cntr) VALUES(3,0)
INSERT INTO @tmpDOW(DOW, Cntr) VALUES(4,0)
INSERT INTO @tmpDOW(DOW, Cntr) VALUES(5,0)
INSERT INTO @tmpDOW(DOW, Cntr) VALUES(6,0)
INSERT INTO @tmpDOW(DOW, Cntr) VALUES(7,0)

DECLARE @StartDate datetime
 , @EndDate datetime
 , @Date datetime
 , @WDofMonth INT
 , @CurrentMonth INT

SELECT @StartDate = '10/1/2020'  -- Set The start and end date 
 , @EndDate = '10/31/2023'--Non inclusive. Stops on the day before this.
 , @CurrentMonth = 1 --Counter used in loop below.

SELECT @Date = @StartDate

WHILE @Date < @EndDate
 BEGIN
 
 IF DATEPART(MONTH,@Date) <> @CurrentMonth 
 BEGIN
 SELECT @CurrentMonth = DATEPART(MONTH,@Date)
 UPDATE @tmpDOW SET Cntr = 0
 END

 UPDATE @tmpDOW
 SET Cntr = Cntr + 1
 WHERE DOW = DATEPART(DW,@DATE)

 SELECT @WDofMonth = Cntr
 FROM @tmpDOW
 WHERE DOW = DATEPART(DW,@DATE) 

 SET IDENTITY_INSERT DimDate ON;

 INSERT INTO DimDate
 (
 [DateSK],--TO MAKE THE DateSK THE YYYYMMDD FORMAT UNCOMMENT THIS LINE... Comment for autoincrementing.
 [Date]
 , [Day]
 , [DaySuffix]
 , [DayOfWeek]
 , [DOWInMonth]
 , [DayOfYear]
 , [WeekOfYear]
 , [WeekOfMonth] 
 , [Month]
 , [MonthName]
 , [Quarter]
 , [QuarterName]
 , [Year]
 )
 SELECT CONVERT(VARCHAR,@Date,112), --TO MAKE THE DateSK THE YYYYMMDD FORMAT UNCOMMENT THIS LINE COMMENT FOR AUTOINCREMENT
 @Date [Date]
 , DATEPART(DAY,@DATE) [Day]
 , CASE 
 WHEN DATEPART(DAY,@DATE) IN (11,12,13) THEN CAST(DATEPART(DAY,@DATE) AS VARCHAR) + 'th'
 WHEN RIGHT(DATEPART(DAY,@DATE),1) = 1 THEN CAST(DATEPART(DAY,@DATE) AS VARCHAR) + 'st'
 WHEN RIGHT(DATEPART(DAY,@DATE),1) = 2 THEN CAST(DATEPART(DAY,@DATE) AS VARCHAR) + 'nd'
 WHEN RIGHT(DATEPART(DAY,@DATE),1) = 3 THEN CAST(DATEPART(DAY,@DATE) AS VARCHAR) + 'rd'
 ELSE CAST(DATEPART(DAY,@DATE) AS VARCHAR) + 'th' 
 END AS [DaySuffix]
 , CASE DATEPART(DW, @DATE)
 WHEN 1 THEN 'Sunday'
 WHEN 2 THEN 'Monday'
 WHEN 3 THEN 'Tuesday'
 WHEN 4 THEN 'Wednesday'
 WHEN 5 THEN 'Thursday'
 WHEN 6 THEN 'Friday'
 WHEN 7 THEN 'Saturday'
 END AS [DayOfWeek]
 , @WDofMonth [DOWInMonth]--Occurance of this day in this month. If Third Monday then 3 and DOW would be Monday.
 , DATEPART(dy,@Date) [DayOfYear]--Day of the year. 0 - 365/366
 , DATEPART(ww,@Date) [WeekOfYear]--0-52/53
 , DATEPART(ww,@Date) + 1 -
 DATEPART(ww,CAST(DATEPART(mm,@Date) AS VARCHAR) + '/1/' + CAST(DATEPART(yy,@Date) AS VARCHAR)) [WeekOfMonth]
 , DATEPART(MONTH,@DATE) [Month]--To be converted with leading zero later. 
 , DATENAME(MONTH,@DATE) [MonthName]
 , DATEPART(qq,@DATE) [Quarter]--Calendar quarter
 , CASE DATEPART(qq,@DATE) 
 WHEN 1 THEN 'First'
 WHEN 2 THEN 'Second'
 WHEN 3 THEN 'Third'
 WHEN 4 THEN 'Fourth'
 END AS [QuarterName]
 , DATEPART(YEAR,@Date) [Year]

 SET IDENTITY_INSERT DimDate ON;

 SELECT @Date = DATEADD(dd,1,@Date)
 END

--You can replace this code by editing the insert using my functions dbo.DBA_fnAddLeadingZeros
UPDATE dbo.DimDate
 SET [DAY] = '0' + [DAY]
 WHERE LEN([DAY]) = 1

UPDATE dbo.DimDate
 SET [MONTH] = '0' + [MONTH]
 WHERE LEN([MONTH]) = 1

UPDATE dbo.DimDate
 SET STANDARDDATE = [MONTH] + '/' + [DAY] + '/' + [YEAR]


--------------------------------------------------------------------------------------------------------
PRINT CONVERT(VARCHAR,GETDATE(),113)--USED FOR CHECKING RUN TIME.

--DimDate indexes---------------------------------------------------------------------------------------------
CREATE UNIQUE NONCLUSTERED INDEX [IDX_DimDate_Date] ON [dbo].[DimDate] 
(
[Date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_Day] ON [dbo].[DimDate] 
(
[Day] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_DayOfWeek] ON [dbo].[DimDate] 
(
[DayOfWeek] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_DOWInMonth] ON [dbo].[DimDate] 
(
[DOWInMonth] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_DayOfYear] ON [dbo].[DimDate] 
(
[DayOfYear] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_WeekOfYear] ON [dbo].[DimDate] 
(
[WeekOfYear] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_WeekOfMonth] ON [dbo].[DimDate] 
(
[WeekOfMonth] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_Month] ON [dbo].[DimDate] 
(
[Month] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_MonthName] ON [dbo].[DimDate] 
(
[MonthName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_Quarter] ON [dbo].[DimDate] 
(
[Quarter] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_QuarterName] ON [dbo].[DimDate] 
(
[QuarterName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [IDX_DimDate_Year] ON [dbo].[DimDate] 
(
[Year] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]



