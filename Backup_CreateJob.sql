use [msdb]
go

begin transaction
declare @returncode int
select @returncode = 0

if not exists (
    select
        name
    from msdb.dbo.syscategories
    where name = N'[uncategorized (local)]' and category_class = 1
)
begin
    exec @returncode = msdb.dbo.sp_add_category @class = N'job',
         @type       = N'local',
         @name       = N'[uncategorized (local)]'

    if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
end

declare @jobid      binary(16)
declare @myUserName varchar(max) = (select SUSER_SNAME())
exec @returncode               =  msdb.dbo.sp_add_job @job_name = N'differential - database backup',
       @enabled                      = 1,
       @notify_level_eventlog  = 0,
       @notify_level_email     = 0,
       @notify_level_netsend   = 0,
       @notify_level_page      = 0,
       @delete_level           = 0,
       @description            = N'no description available.',
       @category_name          = N'[uncategorized (local)]',
       @owner_login_name       = @myUserName , @job_id = @jobid output
if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

exec @returncode              = msdb.dbo.sp_add_jobstep @job_id = @jobid, @step_name = N'run - differential backup',
       @step_id               = 1,
       @cmdexec_success_code  = 0,
       @on_success_action     = 1,
       @on_success_step_id    = 0,
       @on_fail_action        = 2,
       @on_fail_step_id       = 0,
       @retry_attempts        = 0,
       @retry_interval        = 0,
       @os_run_priority       = 0,
     @subsystem             = N'tsql',
       @command               = N'
            set nocount on
            if object_id(''tempdb.dbo.diffbackupjobparams'', ''u'') is not null
            begin
                  -- drop the table if it exists
                  drop table tempdb.dbo.diffbackupjobparams
            end

            create table tempdb.dbo.diffbackupjobparams (
                  paramid                 int identity(1,1),
                  databasename      varchar(255),
                  difffullpath      varchar(max)
            )

            declare @datestring varchar(17) = (select ''_''+format(getdate(), ''yyyy-mm-dd-hh-mm''))
            insert into tempdb.dbo.diffbackupjobparams
            select
                  [databasename] = (left(databasename, (len(databasename) -1))),
                  [differentialbackupfullpath] = backupfullpath + diffpath + (left(databasename, (len(databasename) -1))) +''_diff''+ @datestring+''.dif''
            from tempdb.dbo.backupjobparams
            where diffpath ! =  ''null''

            declare
                  @cmd_diffbackup as varchar(max),
                  @cmdref_diffbackup as varchar(max)
            set @cmd_diffbackup = ''
            backup database '' + ''{0}'' +char(10)+
            ''to disk = '' + '''''''' +''{1}'' + '''''''' +char(10)+
            ''with differential''
            set @cmdref_diffbackup = @cmd_diffbackup

            declare
                  @path_counter     int,
                  @total_paths      int,
                  @databasename     varchar(255),
                  @difffullpath     varchar(max)
            set @path_counter  =  1
            set @total_paths   =  (select count(paramid) from tempdb.dbo.diffbackupjobparams)
            while @path_counter < =  @total_paths
                  begin
                        set @cmdref_diffbackup   =  @cmd_diffbackup
                        set @databasename        =  (select databasename from tempdb.dbo.diffbackupjobparams where paramid = @path_counter)
                        set @difffullpath        =  (select difffullpath from tempdb.dbo.diffbackupjobparams where paramid = @path_counter)
                  
                        set @cmdref_diffbackup =  (replace(@cmdref_diffbackup, ''{0}'', @databasename))
                        set @cmdref_diffbackup =  (replace(@cmdref_diffbackup, ''{1}'', @difffullpath))

                  
                        begin
                              exec (@cmdref_diffbackup)
                        end
                        set @path_counter = @path_counter + 1
                  end
            ',
       @database_name         = N'master',
       @flags                       = 0

if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
exec @returncode = msdb.dbo.sp_update_job @job_id = @jobid, @start_step_id = 1

if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
exec @returncode                    = msdb.dbo.sp_add_jobschedule @job_id = @jobid, @name = N'hourly - differential backups',
       @enabled                   = 1,
       @freq_type                 = 4,
       @freq_interval             = 1,
       @freq_subday_type          = 8,
       @freq_subday_interval      = 1,
       @freq_relative_interval    = 0,
       @freq_recurrence_factor    = 0,
       @active_start_date         = 20240202,
       @active_end_date           = 99991231,
       @active_start_time         = 0,
       @active_end_time           = 235959,
       @schedule_uid              = N'10a77e25-a11d-4e19-8bd3-877f2127c111'
if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
exec @returncode = msdb.dbo.sp_add_jobserver @job_id = @jobid, @server_name = N'(local)'

if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
commit transaction
goto endsave
quitwithrollback:
    if (@@trancount > 0) rollback transaction
endsave:
go

use [msdb]
go

-- job [weekly full - database backup]
begin transaction
declare @returncode int
select @returncode = 0

-- jobcategory [[uncategorized (local)]]
if not exists (
    select name
    from msdb.dbo.syscategories
    where name =  N'[uncategorized (local)]' and category_class = 1)
begin
    exec @returncode = msdb.dbo.sp_add_category @class =  N'job',
         @type       =  N'local',
         @name       =  N'[uncategorized (local)]'

    if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
end

-- dynamic job parameters

declare @jobid              binary(16)
declare @myUserName         varchar(max) = (select SUSER_SNAME())
declare @rc                 int
declare @dir                nvarchar(4000)
declare @output_file_name   nvarchar(4000)
exec @rc = master.dbo.xp_instance_regread
        N'hkey_local_machine',
        N'software\microsoft\mssqlserver\setup',
        N'sqlpath',
        @dir output,'no_output'
set @output_file_name       =  @dir+'\jobs\backuppaths.csv'

declare @create_path_pwsh_cmd       nvarchar(max)
declare @create_paths_script_path   nvarchar(4000)
exec @rc = master.dbo.xp_instance_regread
        N'hkey_local_machine',
        N'software\microsoft\mssqlserver\setup',
        N'sqlpath',
        @dir output,'no_output'
set @create_paths_script_path =  @dir+'\jobs\create-backuppaths.ps1'
set @create_path_pwsh_cmd     = 'c:\windows\system32\windowspowershell\v1.0\powershell.exe -file ' +'"'+@create_paths_script_path+'"'

declare @remove_path_pwsh_cmd       nvarchar(max)
declare @remove_paths_script_path   nvarchar(4000)
exec @rc = master.dbo.xp_instance_regread
        N'hkey_local_machine',
        N'software\microsoft\mssqlserver\setup',
        N'sqlpath',
        @dir output,'no_output'
set @remove_path_pwsh_cmd       =  @dir+'\jobs\remove-differentialbackups.ps1'
set @remove_paths_script_path   = 'c:\windows\system32\windowspowershell\v1.0\powershell.exe -file ' +'"'+@remove_path_pwsh_cmd+'"'

exec @returncode             =  msdb.dbo.sp_add_job @job_name =  N'weekly full - database backup',
       @enabled                = 1,
       @notify_level_eventlog  = 0,
       @notify_level_email     = 0,
       @notify_level_netsend   = 0,
       @notify_level_page      = 0,
       @delete_level           = 0,
       @description            = N'Run a full weekly backup.',
       @category_name          = N'[uncategorized (local)]',
       @owner_login_name       = @myUserName,
     @job_id = @jobid output
if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

--step [define - backup paths]
exec @returncode                = msdb.dbo.sp_add_jobstep @job_id = @jobid, @step_name =  N'define - backup paths',
            @step_id                = 1,
            @cmdexec_success_code   = 0,
            @on_success_action      = 3,
            @on_success_step_id     = 0,
            @on_fail_action         = 2,
            @on_fail_step_id        = 0,
            @retry_attempts         = 0,
            @retry_interval         = 0,
            @os_run_priority        = 0,
        @subsystem              = N'tsql',
            @command                = N'
            set nocount on
            declare
                @backupfullpath     as varchar(max),
                @rootdrive          as char(1),
                @backupsfolder      as char(6),
                @machinename  as varchar(max),
                @instancename as varchar(max),
                @servername         as varchar(max),
                @cmd_backup   nvarchar(max)

            set @backupsfolder       =  ''backups''
            set @backupfullpath      =  ''{0}:\{1}\{2}\{3}''

            if object_id(''tempdb..#backuppathparams'') is not null
            drop table #backuppathparams

            set @machinename   =  (convert(varchar(max),serverproperty(''machinename'')))
            set @instancename  =  (convert(varchar(max),serverproperty(''instancename'')))
            set @servername          =  (convert(varchar(max),serverproperty(''servername'')))
            declare @my_instance varchar(max)

            set @my_instance = (convert(varchar(max),@@servername))
            begin
                set @rootdrive             =  ''P:\Backup''
            end

            select
                [rootdrive]          =  @rootdrive,
                [servername]   =  @servername,
                [instancename]       =  @instancename,
                [machinename]  =  @machinename,
                [backupdir]          =  @backupsfolder
            into #backuppathparams
            if object_id(''tempdb.dbo.backupjobparams'', ''u'') is not null
            begin
                -- drop the table if it exists
                drop table tempdb.dbo.backupjobparams;
            end
            -- create the table
            create table tempdb.dbo.backupjobparams (
                paramid         int identity(1,1),
                rootdrive       varchar(max),
                backupfolder    varchar(max),
                instancename    varchar(max),
                databasename    varchar(max),
                diffpath        varchar(max),
                backupfullpath  varchar(max),
                recoverymodel   varchar(max),
                backupcommand nvarchar(max)
            );

            if object_id(''tempdb..#dbnames'') is not null
            drop table #dbnames

            select
                [ruid] = identity (int, 1,1),
                recovery_model,name
            into #dbnames
            from sys.databases
            where name ! =  ''tempdb''

            set @backupfullpath = (replace(@backupfullpath,''{0}'',@rootdrive))
            set @backupfullpath = (replace(@backupfullpath,''{1}'',@backupsfolder))
            set @backupfullpath = (replace(@backupfullpath,''{2}'',@machinename))

            declare @db_counter                       int = 1
            declare @db_total                   int    =  (select max(ruid) from #dbnames)
            declare @db_fullpath                varchar(max)
            declare @db_name                    varchar(max)
            declare @recovery_model_used  varchar(max)
            declare @diff_path                        varchar(max)

            print ''rootdrive,backupfolder,instancename,databasename,diffpath,recoverymodel,backupfullpath''
            while @db_counter < =  @db_total
            begin
                set @db_name               = ( select name from #dbnames where ruid = @db_counter )
                set @db_fullpath           = ( select replace(@backupfullpath,''{3}'',name) from #dbnames where ruid = @db_counter )
                set @recovery_model_used = ( select recovery_model from #dbnames where name = @db_name )

                set @cmd_backup      =  ''backup database [{0}]''+char(10)
                +'' to disk =  N''+''''''''+''{1}\{0}_full.bak''+''''''''+char(10)
                +'' with''+char(10)
                +'' noformat,''+char(10)
                +'' init,''+char(10)
                +'' name =  N''+''''''''+''{0}-database backup''+''''''''+'',''+char(10)
                +'' skip,''+char(10)
                +'' norewind,''+char(10)
                +'' nounload,''+char(10)
                +'' stats = 5''+char(10)

                -- full
                if(@recovery_model_used) = 1
                begin
                    set @diff_path = ''diffs\''
                end

                -- simple
                if(@recovery_model_used) = 3
                begin
                    set @diff_path = ''null''
                end

                print @rootdrive+'':\''+'',''+@backupsfolder+''\''+'',''+@machinename+''\''+'',''+@db_name+''\''+'',''+@diff_path+'',''+@recovery_model_used+'',''+@db_fullpath

                set @cmd_backup = (select replace(@cmd_backup,''{0}'',@db_name))
                set @cmd_backup = (select replace(@cmd_backup,''{1}'',@db_fullpath))
                insert into tempdb.dbo.backupjobparams
                select
                    @rootdrive+'':\'',
                    @backupsfolder+''\'',
                    @machinename+''\'',
                    @db_name+''\'',
                    @diff_path,
                    @db_fullpath+''\'',
                    @recovery_model_used,
                    @cmd_backup
                set @db_counter = @db_counter + 1
            end
            -- validate output (troubleshoot) if needed
            --select * from tempdb.dbo.backupjobparams',
          @database_name          = N'master',
          @output_file_name       = @output_file_name,
          @flags                  = 0
if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

-- step [create - backup paths]
exec @returncode                = msdb.dbo.sp_add_jobstep @job_id = @jobid, @step_name =  N'create - backup paths',
            @step_id                = 2,
            @cmdexec_success_code   = 0,
            @on_success_action      = 3,
            @on_success_step_id     = 0,
            @on_fail_action         = 2,
            @on_fail_step_id        = 0,
            @retry_attempts         = 0,
            @retry_interval         = 0,
            @os_run_priority        = 0,
        @subsystem              = N'powershell',
            @command                = @create_path_pwsh_cmd,
            @database_name          = N'master',
            @flags                  = 0
if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

-- step [run - backup]
exec @returncode            = msdb.dbo.sp_add_jobstep @job_id = @jobid, @step_name =  N'run - backup',
       @step_id               = 3,
       @cmdexec_success_code  = 0,
       @on_success_action     = 3,
       @on_success_step_id    = 0,
       @on_fail_action        = 2,
       @on_fail_step_id       = 0,
       @retry_attempts        = 0,
       @retry_interval        = 0,
       @os_run_priority       = 0,
     @subsystem             = N'tsql',
       @command               = N'
        declare
          @db_counter int,
          @db_total     int,
          @cmd_backup varchar(max)

        set @db_counter = 1
        set @db_total    =  (select count(paramid) from [tempdb].[dbo].[backupjobparams])

        while @db_counter < =  @db_total
        begin
            set @cmd_backup = (select backupcommand from tempdb.dbo.backupjobparams where paramid = @db_counter)
            begin try
                exec (@cmd_backup)
            end try
            begin catch
                print ''error_number:''   +convert(varchar(max),error_number())
                print ''error_severity''  +convert(varchar(max),error_severity())
                print ''error_state''           +convert(varchar(max),error_state())
                print ''error_procedure'' +error_procedure()
                print ''error message:''  +error_message()
            end catch
            set @db_counter = @db_counter + 1
        end

        ---- table will  not be dropped
        --if object_id(''tempdb.dbo.backupjobparams'', ''u'') is not null
        --begin
        --    -- drop the table if it exists
        --    drop table tempdb.dbo.backupjobparams;
        --end',
       @database_name         = N'master',
       @flags                 = 0
if ( @@error <> 0 or @returncode <> 0) goto quitwithrollback

--step [remove - differential backups]
exec @returncode             = msdb.dbo.sp_add_jobstep @job_id = @jobid, @step_name =  N'remove - differential backups',
       @step_id                = 4,
       @cmdexec_success_code   = 0,
       @on_success_action      = 1,
       @on_success_step_id     = 0,
       @on_fail_action         = 2,
       @on_fail_step_id        = 0,
       @retry_attempts         = 0,
       @retry_interval         = 0,
       @os_run_priority        = 0,
     @subsystem              = N'powershell',
       @command                = @remove_paths_script_path,
       @database_name          = N'master',
       @flags                  = 0
if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
exec @returncode = msdb.dbo.sp_update_job @job_id = @jobid, @start_step_id = 1

if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
exec @returncode                = msdb.dbo.sp_add_jobschedule @job_id = @jobid, @name =  N'weekly full backups',
            @enabled                = 1,
            @freq_type              = 8,
            @freq_interval          = 1,
            @freq_subday_type       = 1,
            @freq_subday_interval   = 0,
            @freq_relative_interval = 0,
            @freq_recurrence_factor = 1,
            @active_start_date      = 20240202,
            @active_end_date        = 99991231,
            @active_start_time      = 0,
            @active_end_time        = 235959,
            @schedule_uid           =  N'a3c36b0f-672f-48e9-89ee-89238dd625b6'
if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
exec @returncode = msdb.dbo.sp_add_jobserver @job_id = @jobid, @server_name =  N'(local)'

if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
commit transaction
goto endsave
quitwithrollback:
    if (@@trancount > 0) rollback transaction
endsave:
go