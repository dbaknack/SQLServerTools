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
	[RecID]			= configuration.recid,
	[DomainName]	= (select domain_name from @env_table),
	[HostName]		= (select hostname from @env_table),
	[InstanceName]	= (select instancename from @env_table),
	[name]			= 'filestream access level',
	[ConfigValue]	= configuration.ConfigValue,
	[isApproved]	= 0,
	[Documentation] = 'not approved for use'
from (
	SELECT
		[RecID] = 1,
		[ConfigValue] = CASE WHEN EXISTS (
			SELECT * FROM sys.configurations WHERE Name = 'filestream access level' AND Cast(value AS INT) = 0)
	THEN 0 ELSE 1 END
) configuration