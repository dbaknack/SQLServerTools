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

declare @SessionLimitPerc	varchar(max) = '0.40'
declare @ExcusionTable		varchar(max) = '
	(''NT SERVICE\SQLTELEMETRY'')'
declare @SessionConfig		varchar(max)= '
	(''sa'','+@SessionLimitPerc+')
'

if exists (select 1 from sys.tables where name = 'configTable')
begin
	drop table configTable
end


create table configTable  (
	RecID				int identity(1,1),
	LoginName			varchar(max)		null,
	SessionLimitPerc	decimal(4,3)		null
)


declare @cmd_insertconfig varchar(max) = '
insert into tempdb.dbo.configTable
values'+@SessionConfig+''

exec (@cmd_insertconfig)


select ct.SessionLimitPerc,*
from
(
SELECT 
	LoginName			= login_name,
	TotalSessions		= count(login_name),
	AdditionalSession	= ((count(login_name)) * cast(@SessionLimitPerc as decimal(4,3))),
	TotalSessionLimit	= case
		when login_name not in ('NT SERVICE\SQLTELEMETRY')
			then ceiling(((count(login_name)) *cast(@SessionLimitPerc as decimal(4,3)))) + (count(login_name))
			else (count(login_name))
		end
FROM 
    sys.dm_exec_sessions
	group by login_name
) sessions
join configTable ct on ct.LoginName = sessions.LoginName

SELECT 
    session_id,
    login_name,
    host_name,
    program_name,
    login_time,
    status
FROM 
    sys.dm_exec_sessions

declare @counterSessionsTotal int = (SELECT count(*) FROM sys.dm_exec_sessions)
select CEILING((@counterSessionsTotal * .20) + @counterSessionsTotal)


if exists (select 1 from sys.objects where object_id = object_id('tempdb..#configurationItems'))
begin
	drop table #configurationItems
end

create table tempdb.#configurationItems(
	recid			int identity(1,1),
	name			varchar(50)		null,
	minimun			varchar(max)	null,
	maximum			varchar(max)	null,
	config_value	varchar(10)		null,
	run_value		varchar(10)		null
)

EXEC SP_CONFIGURE 'show advanced options', '1'; 
RECONFIGURE WITH OVERRIDE; 

insert into #configurationItems
EXEC SP_CONFIGURE

select * from #configurationItems