use tempdb
set nocount on


if exists (select 1 from sys.objects where object_id = object_id('tempdb..#configurables'))
begin
	drop table #configurables
end

create table tempdb.#configurables(
	recid int identity(1,1),
	name varchar(50) null,
	is_approved bit null,
	documentation varchar(max)
)

insert into #configurables
values
	('external scripts enabled',0,'not approved for use')

if exists (select 1 from sys.objects where object_id = object_id('tempdb..#configurationItems'))
begin
	drop table #configurationItems
end

create table tempdb.#configurationItems(
	recid int identity(1,1),
	name varchar(50) null,
	minimun	varchar(max) null,
	maximum varchar(max) null,
	config_value varchar(10) null,
	run_value varchar(10) null
)

EXEC SP_CONFIGURE 'show advanced options', '1'; 
RECONFIGURE WITH OVERRIDE; 

insert into #configurationItems
EXEC SP_CONFIGURE

EXEC SP_CONFIGURE 'show advanced options', '0'; 
RECONFIGURE WITH OVERRIDE; 

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
	[Name]			= configuration.name,
	[ConfigValue]	= configuration.config_value,
	[isApproved]	= configuration.is_approved,
	[Documentation]	= configuration.documentation
from (
	select
		c.recid,
		ci.name,
		ci.config_value,
		c.is_approved,
		documentation = case when c.documentation is not null
			then c.documentation else 'configuration item need approval'
		end
	from #configurationItems ci
	join #configurables c on ci.name = c.name
	where ci.name in (
		select name
		from #configurables
	)
) configuration