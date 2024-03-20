/*
EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'user connections', N'1000'
GO
RECONFIGURE WITH OVERRIDE
GO
EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
GO
*/
use tempdb

-- NOTE:	sessionlimitperc defines what the limit in a percentage, that any given login will have extra,
--			given the current total sessions that login has. i.e 
--			nosa has 10 sessions, the limit will be 12 since 0.20 is 20% of the current sessions active
--			at the time of creation.
-- NOTE:	any account included in sessionsconfig can be added to manually set a limit to a given account

declare @SessionLimitPerc	varchar(max) = '0.30'
declare @ExcusionTable		varchar(max) = '(''NT SERVICE\SQLTELEMETRY''),
											(''NT SERVICE\SQLSERVERAGENT''),
											(''nosa'')'
declare @SessionConfig		varchar(max) = '(''DEVBOX01\AbrahamHernandez'','+@SessionLimitPerc+')'

if exists (select 1 from sys.tables where name = 'configTable')
begin
	drop table configTable
end
create table configTable  (
	RecID				int identity(1,1),
	LoginName			varchar(max)		null,
	SessionLimitPerc	decimal(4,2)		null
)

if exists (select 1 from sys.tables where name = 'exclusion')
begin
	drop table exclusion
end
create table exclusion  (
	RecID				int identity(1,1),
	LoginName			varchar(max)		null
)

declare @cmd_insertconfig varchar(max) = '
insert into tempdb.dbo.configTable
values'+@SessionConfig+''

declare @cmd_insertexclusion varchar(max) = '
insert into tempdb.dbo.exclusion
values'+@ExcusionTable+''

exec (@cmd_insertconfig)
exec (@cmd_insertexclusion)


if exists (select 1 from sys.tables where name = 'computedResults')
begin
	drop table computedResults
end
create table computedResults  (
	RecID				int identity(1,1),
	LoginName			varchar(max)		null,
	TotalSessions			int		null,
	TotalExtraSessions			int		null,
	SessionsLimited			int		null,
	IncreaseByPercent	decimal(4,2) null,
	SessionLimit int null
)

insert into computedResults
select
	sessions.LoginName,
	sessions.TotalSessions,
	TotalExtraSessions = case when ct.SessionLimitPerc is null
		then 0 * sessions.TotalSessions
		else ceiling(ct.SessionLimitPerc * sessions.TotalSessions)
	end,
	SessionsLimited = case when ex.LoginName is not null
		then 0 
		else 1
	end,
	[IncreaseByPercent] = case when ct.SessionLimitPerc is not null
		then ct.SessionLimitPerc
		else null
	end,
	SessionLimit = case when ct.loginname is null
		then null
		else ceiling(ct.SessionLimitPerc * sessions.TotalSessions) + sessions.TotalSessions

	end
from
(
	select
		LoginName,
		TotalSessions
	from(
		select 
			LoginName		= login_name,
			TotalSessions	= count(login_name)
		from sys.dm_exec_sessions 
		group by login_name
	) root

) sessions
left outer join configTable ct on ct.LoginName = sessions.LoginName
left outer join exclusion ex on ex.LoginName = sessions.LoginName
declare @env_table table (
	domain_name		varchar(max),
	hostname		varchar(max),
	instancename	varchar(max)
)


declare @instancename nvarchar(128)
set @instancename = @@servername

if charindex('\', @instancename) > 0
    set @instancename = substring(@instancename, charindex('\', @instancename) + 1, len(@instancename))
else
    set @instancename = convert(nvarchar(128), serverproperty('machinename'))
	
insert into @env_table
select
	convert(varchar(max),default_domain()),
	convert(varchar(max),serverproperty('machinename')),
	@instancename

select
	[RecID],
	[DomainName]	= (select domain_name from @env_table),
	[HostName]		= (select hostname from @env_table),
	[InstanceName]	= (select instancename from @env_table),
	LoginName,
	TotalSessions,
	TotalExtraSessions,
	SessionsLimited,
	IncreaseByPercent,
	SessionLimit
from computedResults

drop table configTable
drop table exclusion
drop table computedResults