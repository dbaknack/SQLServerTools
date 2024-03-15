SET NOCOUNT ON

-- check if #logininfo exists and drop if it does
IF EXISTS (SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#logininfo'))
BEGIN
    DROP TABLE #logininfo
END

-- create #logininfo table
CREATE TABLE #logininfo (
    recid			INT IDENTITY(1,1),
    loginname		VARCHAR(50)		NULL,
    logintype		VARCHAR(50)		NULL,
	isdisabled		BIT				NULL,
    isshared		BIT				NULL,
	isunapproved	BIT				NULL,
    [description]	VARCHAR(max)	NULL
    
)

-- check if #sharedaccounts exists and drop if it does
IF EXISTS (SELECT 1 FROM tempdb.sys.objects WHERE object_id = OBJECT_ID(N'tempdb..#sharedaccounts'))
BEGIN
    DROP TABLE #sharedaccounts
END

-- all account that are considered to be shared will be here
CREATE TABLE #sharedaccounts (
    recid			INT IDENTITY(1,1),
    loginname		NVARCHAR(50)        null,
    [description]	varchar(max)         null
)
-- insert into #sharedaccounts
insert into #sharedaccounts (loginname)
values ('nt service\mssql$devinstance')

-- all account that need to have a description will be here
create table #loginDescriptions (
    recid			int identity(1,1),
    loginname		nvarchar(50)			NULL,
    [Description]	nvarchar(max) 	NULL
)
insert into #loginDescriptions (loginname,[Description])
VALUES
	('MST3K\abrah','Login is used in the MST3K Host.'),
	('PSUniversal_User','Login Account used for PSUniversal'),
	('NT SERVICE\SQLWriter','The SQL Server VSS Writer service is responsible for preparing SQL Server databases for a consistent shadow copy to be taken.'),
	('NT SERVICE\SQLTELEMETRY$DEVINSTANCE','This service is part of the SQL Server infrastructure, and its primary role is to collect and send telemetry data about the usage of SQL Server to Microsoft.'),
	('NT SERVICE\Winmgmt',' not directly related to SQL Server but rather to the Windows Management Instrumentation (WMI) service on Windows operating systems. WMI is a core Windows management technology that allows for monitoring and controlling system resources through a unified interface.')

-- all account that are unapproved will be here
create table #unapprovedaccounts (
    recid			int identity(1,1),
    loginname		nvarchar(50)        null
)
insert into #unapprovedaccounts (loginname)
VALUES
	('NT SERVICE\Winmgmt')


-- insert into #logininfo
-- note: this query attempts to join #sharedaccounts on loginname which might not result in rows unless matched
-- you might need an outer join if you want to insert regardless of matching in #sharedaccounts, or handle the logic for isshared differently
insert into #logininfo (loginname, logintype, isdisabled, isshared,isunapproved,[description])
select 
    sp.name as loginname,
    sp.type_desc as logintype,
	 sp.is_disabled as isdisabled,
    case when sa.loginname is not null then 1 else 0 end as isshared, -- use a case statement to determine if shared
	CASE WHEN ua.loginname IS NOT null THEN 1 ELSE 0 END AS isunapproved,
	[description] = CASE WHEN ld.loginname IS NOT NULL
		THEN ld.Description
			ELSE CASE WHEN sp.is_disabled = 1
			THEN 'Account is disabled per DISA requirement.'
				ELSE CASE WHEN sa.loginname IS NOT NULL 
					THEN 'Account is a shared account.'
						ELSE CASE WHEN ua.loginname IS NOT NULL
							THEN 'Account is not approved by data owner.'
								ELSE 'Account is not documented.' 
							END
					END
			END
	END
from 
    sys.server_principals sp
    left outer join #sharedaccounts sa on sa.loginname = sp.name
	LEFT OUTER JOIN #unapprovedaccounts ua ON ua.loginname = sp.name
	LEFT OUTER JOIN #loginDescriptions ld ON ld.loginname = sp.name
where 
    sp.type in ('s', 'u', 'g') -- s = sql login, u = windows login, g = windows group
    and sp.name not like '##%' -- exclude system logins

	-- if its a default or named instance, the instance name will be that
declare @instancename nvarchar(128)
set @instancename = @@servername

if charindex('\', @instancename) > 0
    set @instancename = substring(@instancename, charindex('\', @instancename) + 1, len(@instancename))
else
    set @instancename = convert(nvarchar(128), serverproperty('machinename'))

SELECT
	 RecID
	,HostName
	,InstanceName
	,LoginName
	,LoginType
	,IsDisabled
	,isShared
	,IsUnapproved
	,[Description] 
FROM(
	select
		 [hostname]		= serverproperty('machinename')
		,[instancename] = @instancename
		,*
	FROM #logininfo 
) LoginInfo
order by RecID 

drop table #logininfo
drop table #sharedaccounts
DROP TABLE #unapprovedaccounts
DROP TABLE #loginDescriptions