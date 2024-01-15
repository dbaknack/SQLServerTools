set nocount on
declare
	@BackupFullPath	as varchar(max),
	@RootDrive		as char(1),
	@BackupsFolder	as char(6),
	@MachineName	as varchar(max),
	@InstanceName	as varchar(max),
	@ServerName		as varchar(max),
	@cmd_backup 	nvarchar(max)

set @BackupsFolder	= 'Backups'
set @BackupFullPath	= '{0}:\{1}\{2}\{3}'

print @cmd_backup

if object_id('tempdb..#BackupPathParams') is not null
drop table #BackupPathParams

set @RootDrive		= (select distinct(left(physical_name, 1)) from sys.master_files)
set @MachineName	= (convert(varchar(max),ServerProperty('machinename')))
set @InstanceName	= (convert(varchar(max),serverproperty('instancename')))
set @ServerName		= (convert(varchar(max),serverproperty('ServerName')))

select
	[rootDrive]		= @RootDrive,
	[servername]	= @ServerName,
	[InstanceName]	= @Instancename,
	[machineName]	= @MachineName,
	[backupDir]		= @BackupsFolder
into #BackupPathParams

IF OBJECT_ID('tempdb.dbo.BackUpJobParams', 'U') IS NOT NULL
BEGIN
    -- Drop the table if it exists
    DROP TABLE tempdb.dbo.BackUpJobParams;
END
-- Create the table
CREATE TABLE tempdb.dbo.BackUpJobParams (
    paramID         INT IDENTITY(1,1),
    RootDrive       VARCHAR(MAX),
    BackupFolder    VARCHAR(MAX),
    InstanceName    VARCHAR(MAX),
    DatabaseName    VARCHAR(MAX),
	TlogPath        VARCHAR(MAX),
    BackupFullPath  VARCHAR(MAX),
	RecoveryModel   VARCHAR(MAX),
	BackupCommand	NVARCHAR(MAX)
);

if object_id('tempdb..#dbnames') is not null
drop table #dbnames

select
	[ruid] = identity (int, 1,1),
	recovery_model,name
into #dbnames
from sys.databases
where name != 'tempdb'

set @BackupFullPath = (replace(@BackupFullPath,'{0}',@RootDrive))
set @BackupFullPath = (replace(@BackupFullPath,'{1}',@BackupsFolder))
set @BackupFullPath = (replace(@BackupFullPath,'{2}',@MachineName))

declare @db_counter				int = 1
declare @db_total				int	= (select max(ruid) from #dbnames)
declare @db_fullpath			varchar(max)
declare @db_name				varchar(max)
declare @recovery_model_used	varchar(max)
declare @tlog_path				varchar(max)

print 'RootDrive,BackupFolder,InstanceName,DatabaseName,TLogPath,RecoveryModel,BackupFullPath'
while @db_counter <= @db_total
begin
	set @db_name 			 = ( select name from #dbnames where ruid = @db_counter )
	set @db_fullpath		 = ( select	replace(@BackupFullPath,'{3}',name) from #dbnames where ruid = @db_counter )
	set @recovery_model_used = ( select recovery_model from #dbnames where name = @db_name )

	set @cmd_backup 	= 'BACKUP DATABASE [{0}]'+char(10)
	+' TO DISK = N'+''''+'{1}\{0}.bak'+''''+char(10)
	+' WITH'+char(10)
	+' NOFORMAT,'+char(10)
	+' INIT,'+char(10)
	+' NAME = N'+''''+'{0}-Database Backup'+''''+','+char(10)
	+' SKIP,'+char(10)
	+' NOREWIND,'+char(10)
	+' NOUNLOAD,'+char(10)
	+' STATS = 5'+char(10)

	-- full
	if(@recovery_model_used) = 1
	begin
		set @tlog_path = 'Tlogs\'
	end

	-- simple
	if(@recovery_model_used) = 3
	begin
		set @tlog_path = 'NULL'
	end

	print @RootDrive+':\'+','+@BackupsFolder+'\'+','+@MachineName+'\'+','+@db_name+'\'+','+@tlog_path+','+@recovery_model_used+','+@db_fullpath

	set @cmd_backup = (select replace(@cmd_backup,'{0}',@db_name))
	set @cmd_backup = (select replace(@cmd_backup,'{1}',@db_fullpath))
	insert into tempdb.dbo.BackUpJobParams
	select
		@RootDrive+':\',
		@BackupsFolder+'\',
		@MachineName+'\',
		@db_name+'\',
		@tlog_path,
		@db_fullpath+'\',
		@recovery_model_used,
		@cmd_backup
	set @db_counter = @db_counter + 1
end
select * from tempdb.dbo.BackUpJobParams