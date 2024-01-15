USE [msdb]
GO

/****** Object:  Job [Nightly - Database Backup]    Script Date: 1/15/2024 2:11:21 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 1/15/2024 2:11:21 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Nightly - Database Backup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Get-BackupPaths]    Script Date: 1/15/2024 2:11:21 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Get-BackupPaths', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'set nocount on
declare
	@BackupFullPath	as varchar(max),
	@RootDrive		as char(1),
	@BackupsFolder	as char(6),
	@MachineName	as varchar(max),
	@InstanceName	as varchar(max),
	@ServerName		as varchar(max),
	@cmd_backup 	nvarchar(max)

set @BackupsFolder	= ''Backups''
set @BackupFullPath	= ''{0}:\{1}\{2}\{3}''

print @cmd_backup

if object_id(''tempdb..#BackupPathParams'') is not null
drop table #BackupPathParams

set @RootDrive		= (select distinct(left(physical_name, 1)) from sys.master_files)
set @MachineName	= (convert(varchar(max),ServerProperty(''machinename'')))
set @InstanceName	= (convert(varchar(max),serverproperty(''instancename'')))
set @ServerName		= (convert(varchar(max),serverproperty(''ServerName'')))

select
	[rootDrive]		= @RootDrive,
	[servername]	= @ServerName,
	[InstanceName]	= @Instancename,
	[machineName]	= @MachineName,
	[backupDir]		= @BackupsFolder
into #BackupPathParams

IF OBJECT_ID(''tempdb.dbo.BackUpJobParams'', ''U'') IS NOT NULL
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

if object_id(''tempdb..#dbnames'') is not null
drop table #dbnames

select
	[ruid] = identity (int, 1,1),
	recovery_model,name
into #dbnames
from sys.databases
where name != ''tempdb''

set @BackupFullPath = (replace(@BackupFullPath,''{0}'',@RootDrive))
set @BackupFullPath = (replace(@BackupFullPath,''{1}'',@BackupsFolder))
set @BackupFullPath = (replace(@BackupFullPath,''{2}'',@MachineName))

declare @db_counter				int = 1
declare @db_total				int	= (select max(ruid) from #dbnames)
declare @db_fullpath			varchar(max)
declare @db_name				varchar(max)
declare @recovery_model_used	varchar(max)
declare @tlog_path				varchar(max)

print ''RootDrive,BackupFolder,InstanceName,DatabaseName,TLogPath,RecoveryModel,BackupFullPath''
while @db_counter <= @db_total
begin
	set @db_name 			 = ( select name from #dbnames where ruid = @db_counter )
	set @db_fullpath		 = ( select	replace(@BackupFullPath,''{3}'',name) from #dbnames where ruid = @db_counter )
	set @recovery_model_used = ( select recovery_model from #dbnames where name = @db_name )

	set @cmd_backup 	= ''BACKUP DATABASE [{0}]''+char(10)
	+'' TO DISK = N''+''''''''+''{1}\{0}.bak''+''''''''+char(10)
	+'' WITH''+char(10)
	+'' NOFORMAT,''+char(10)
	+'' NOINIT,''+char(10)
	+'' NAME = N''+''''''''+''{0}-Database Backup''+''''''''+'',''+char(10)
	+'' SKIP,''+char(10)
	+'' NOREWIND,''+char(10)
	+'' NOUNLOAD,''+char(10)
	+'' STATS = 5''+char(10)

	-- full
	if(@recovery_model_used) = 1
	begin
		set @tlog_path = ''Tlogs\''
	end

	-- simple
	if(@recovery_model_used) = 3
	begin
		set @tlog_path = ''NULL''
	end

	print @RootDrive+'':\''+'',''+@BackupsFolder+''\''+'',''+@MachineName+''\''+'',''+@db_name+''\''+'',''+@tlog_path+'',''+@recovery_model_used+'',''+@db_fullpath

	set @cmd_backup = (select replace(@cmd_backup,''{0}'',@db_name))
	set @cmd_backup = (select replace(@cmd_backup,''{1}'',@db_fullpath))
	insert into tempdb.dbo.BackUpJobParams
	select
		@RootDrive+'':\'',
		@BackupsFolder+''\'',
		@MachineName+''\'',
		@db_name+''\'',
		@tlog_path,
		@db_fullpath+''\'',
		@recovery_model_used,
		@cmd_backup
	set @db_counter = @db_counter + 1
end', 
		@database_name=N'master', 
		@output_file_name=N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\JOBS\BackupPaths.csv', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Invoke-CreatePaths]    Script Date: 1/15/2024 2:11:21 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Invoke-CreatePaths', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'powershell.exe -File "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\JOBS\Create-BackupPaths.ps1"', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Backup-Database]    Script Date: 1/15/2024 2:11:21 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Backup-Database', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'declare
	@db_counter int,
	@db_total	int,
	@cmd_backup varchar(max)

set @db_counter = 1
set @db_total	= (select count(paramID) from [tempdb].[dbo].[BackUpJobParams])

while @db_counter <= @db_total
begin
	set @cmd_backup = (select BackupCommand from tempdb.dbo.BackupJobParams where paramID = @db_counter)
	begin try
		exec (@cmd_backup)
	end try
	begin catch
		print ''error_number:''	+convert(varchar(max),error_number())
		print ''error_severity''	+convert(varchar(max),error_severity())
		print ''error_state''		+convert(varchar(max),error_state())
		print ''error_procedure'' +error_procedure()
		print ''error message:''	+error_message()
	end catch
	set @db_counter = @db_counter + 1
end

IF OBJECT_ID(''tempdb.dbo.BackUpJobParams'', ''U'') IS NOT NULL
BEGIN
    -- Drop the table if it exists
    DROP TABLE tempdb.dbo.BackUpJobParams;
END', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Nightly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240115, 
		@active_end_date=99991231, 
		@active_start_time=190000, 
		@active_end_time=235959, 
		@schedule_uid=N'3ea1c6f4-981e-4389-9c4e-e54bac430c54'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO