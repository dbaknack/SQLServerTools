set nocount on

-- check if #proceduresinfo exists and drop if it does
if exists (select 1 from tempdb.sys.objects where object_id = object_id(N'tempdb..#proceduresinfo'))
begin
    drop table #proceduresinfo
end

-- temptable to coalate instance stored procedure info
create table #proceduresinfo
(
    recid 				int identity(1,1),
    databasename 		nvarchar(128) 	null,
    schemaname 			nvarchar(128) 	null,
    procedurename 		nvarchar(256) 	null,
    is_auto_executed 	bit 			null
)


-- check if #proceduresinfodesc exists and drop if it does
if exists (select 1 from tempdb.sys.objects where object_id = object_id(N'tempdb..#proceduresinfodesc'))
begin
    drop table #proceduresinfodesc
end

-- temptable to coalate stored procedure info
create table #proceduresinfodesc
(
	recid 				int,
    databasename 		nvarchar(128) 	null,
    schemaname 			nvarchar(128)	null,
    procedurename 		nvarchar(256)	null,
    is_auto_executed 	bit				null,
	is_approved 		varchar(10)		null,
	[description] 		varchar(255)	null
)

-- dynamic sql
declare @sql nvarchar(max)
set @sql = stuff((select 
                     char(13) + 'union all select ''' 
                     + name + ''' as databasename, schema_name(schema_id) as schemaname, name as procedurename,is_auto_executed from [' 
                     + name + '].sys.procedures '
                  from sys.databases
                  where state_desc = 'online'
                  for xml path(''), type).value('.', 'nvarchar(max)'), 1, 10, '')

-- execute the dynamic sql
insert into #proceduresinfo
exec sp_executesql @sql


declare @counter_sp int						= 1
declare @counter_total_sp int				= (select max(recid) from #proceduresinfo)
declare @sys_sp_description varchar(255)
declare @userdb_sp_description varchar(255)
declare @master_sp_description varchar(255)
declare @is_approved varchar(10) 
while @counter_sp <= @counter_total_sp
begin

	-- by default all stored procedures are considered to be approved
	set @is_approved = 'true'

	-- stored procedured can only be set to auto start in master, every other system database will return stored
	-- procedures that 'should' had is_auto_executed value of 0
	if(select databasename from #proceduresinfo where recid = @counter_sp) in ('model','temp','distribution','msdb')
	begin
		set @sys_sp_description = 'this is a system database stored procedure created by default.'
		if(select is_auto_executed from #proceduresinfo where recid = @counter_sp) = 1
		begin
			set @is_approved = 'false'
			set @sys_sp_description = 'description is needed for any stored procedure that is set to auto execute.'
		end
		insert into #proceduresinfodesc
		select *,[isapproved] = @is_approved,[description] = @sys_sp_description from #proceduresinfo where recid = @counter_sp
	end

	-- stored procedures can be set to auto start by the application that created them
	if(select databasename from #proceduresinfo where recid = @counter_sp) not in ('model','temp','distribution','msdb','master')
	begin
		set @userdb_sp_description = 'this is a appplication stored procedure, create by the application service.'
		if(select is_auto_executed from #proceduresinfo where recid = @counter_sp) = 1
		begin
			set @is_approved = 'false'
			set @userdb_sp_description = 'description is needed for any stored procedure that is set to auto execute.'
		end
		insert into #proceduresinfodesc
		select *,[isapproved] = @is_approved, [description] = @userdb_sp_description from #proceduresinfo where recid = @counter_sp	
	end

	-- master is the only system database that can have stored procedures with is_auto_executed value of 1
	-- by default they will be considered to not be approved, and the description should state that as well
	if(select databasename from #proceduresinfo where recid = @counter_sp) in ('master')
	begin
		set @master_sp_description = 'this is a system database stored procedure created by default.'
		if(select is_auto_executed from #proceduresinfo where recid = @counter_sp) = 1
		begin
			set @is_approved = 'false'
			set @master_sp_description = 'description is needed for any stored procedure that is set to auto execute.'
		end
		insert into #proceduresinfodesc
		select *,[isapproved] = @is_approved, [description] = @master_sp_description from #proceduresinfo where recid = @counter_sp	
	end
	set @counter_sp = @counter_sp + 1
end


-- if its a default or named instance, the instance name will be that
declare @instancename nvarchar(128)
set @instancename = @@servername

if charindex('\', @instancename) > 0
    set @instancename = substring(@instancename, charindex('\', @instancename) + 1, len(@instancename))
else
    set @instancename = convert(nvarchar(128), serverproperty('machinename'))


-- the machine name will be considered by default to be the host name
SELECT
	 RecID
	,HostName
	,InstanceName
	,DatabaseName
	,SchemaName
	,ProcedureName
	,[IsAutoExecuted] = is_auto_executed
	,[IsApproved] = is_approved
	,[Description]
FROM(
select
	 [hostname] = serverproperty('machinename')
	,[instancename] = @instancename
	,*
FROM #proceduresinfodesc 
) ProcedureInfo
order by recid 

-- drop the temporary table when done
drop table #proceduresinfo
drop table #proceduresinfodesc