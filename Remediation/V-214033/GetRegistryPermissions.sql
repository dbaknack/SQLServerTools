if exists (select 1 from sys.objects where object_id = object_id('tempdb..#myExtendedProcedures'))
begin
    drop table #myExtendedProcedures
end

create table #myExtendedProcedures  (
    RecID			int identity(1,1),
    [Procedure]		varchar(100) null,
	[Description]	varchar(max) null,
    isApproved		bit DEFAULT 0
)

insert into #myExtendedProcedures
values
    ('xp_regaddmultistring','Adds multi-string value to Windows registry',DEFAULT),
    ('xp_regdeletekey','Deletes registry key and its subkeys and values',DEFAULT),
    ('xp_regdeletevalue','Deletes specific value under given registry key',DEFAULT),
    ('xp_regenumvalues','Retrieves names and types of values under registry key',DEFAULT),
    ('xp_regenumkeys','Retrieves names of subkeys under registry key',DEFAULT),
    ('xp_regremovemultistring','Removes multi-string value from Windows registry',DEFAULT),
    ('xp_regwrite','Writes value to Windows registry under specified key',DEFAULT),
    ('xp_instance_regaddmultistring','Adds multi-string value to registry within SQL Server instance',DEFAULT),
    ('xp_instance_regdeletekey','Deletes registry key and its values within SQL Server instance',DEFAULT),
    ('xp_instance_regdeletevalue','Deletes specific value under given registry key within SQL Server instance',DEFAULT),
    ('xp_instance_regenumkeys','Retrieves names of subkeys under registry key within SQL Server instance',DEFAULT),
    ('xp_instance_regenumvalues','Retrieves names and types of values under registry key within SQL Server instance',DEFAULT),
    ('xp_instance_regremovemultistring','Removes multi-string value from registry within SQL Server instance',DEFAULT),
    ('xp_instance_regwrite','Writes value to Windows registry under specified key within SQL Server instance',DEFAULT)

if exists (select 1 from sys.objects where object_id = object_id('tempdb..#checkResults'))
begin
    drop table #checkResults
end

create table #checkResults  (
    RecID			int identity(1,1),
    [Procedure]		varchar(100) null,
	[Description]	varchar(max) null,
    isApproved		bit
)

declare @cntr_refTable int	= 1
declare @total_refTable int	= (select max(recid) from #myExtendedProcedures)
declare @xp	varchar(50)
while @cntr_refTable <= @total_refTable
begin
	set @xp = (select [procedure] from #myExtendedProcedures where RecId = @cntr_refTable)
	
	if exists(
		SELECT 1
		FROM sys.database_permissions AS dp
		INNER JOIN sys.database_principals AS dpr ON dp.grantee_principal_id = dpr.principal_id
		WHERE major_id = OBJECT_ID(@xp)
	)
	begin
		insert into #checkResults
		select
			 [Procedure]
			,[Description]
			,[isApproved] = 1
		from #myExtendedProcedures
		where RecID = @cntr_refTable
	end
	else
	begin
		insert into #checkResults
		select
			 [Procedure]
			,[Description]
			,[isApproved]
		from #myExtendedProcedures
		where RecID = @cntr_refTable
	end

	set @cntr_refTable = @cntr_refTable + 1
end

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
	RecID,
	DomainName = (select domain_name from @env_table),
	HostName = (select hostname from @env_table),
	InstanceName = (select instancename from @env_table),
    isApproved,
	[Procedure],
	[Description]
from #checkResults