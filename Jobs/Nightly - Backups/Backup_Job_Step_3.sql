set nocount on
if object_id('tempdb..#dbnames') is not null
drop table #dbnames;

select identity(int, 1, 1) as ruid, name
into #dbnames

from sys.databases
where name <> 'tempdb'
and state_desc = 'online'
order by database_id

declare
	 @a					int = 1
	,@b					int = (select max(ruid) from #dbnames)
	,@cmd				varchar(max)
	,@dbname			varchar(25)
	,@instancename		varchar(25) = convert(varchar(50),serverproperty('instancename'))
	,@servername		varchar(25) = convert(varchar(50),serverproperty('servername'))
	,@wait				varchar(10) = '00:10:00'
	,@retrycount		int = 0
	,@error_message		varchar (500)

while  @a < @b and @retrycount <= 12
begin
	begin try
		set @dbname = (select name from #dbnames where ruid = @a)

		set @cmd = (
			'backup database['+rtrim(@dbname) +']
			to disk = ''k:\k_backup\db_backups\' + rtrim (@instancename) + '\' + replace (upper(@dbname),'.','_') + '\'
			+ replace (@servername,'\','_') + '_'
			+ replace (upper(@dbname),'.','_') + '_full_compressed1.bak'',

			disk = ''k:\k_backup\db_backups\' + rtrim (@instancename) + '\' + replace (upper(@dbname),'.','_') + '\'
			+ replace (@servername,'\','_') + '_'
			+ replace (upper(@dbname),'.','_') + '_full_compressed2.bak'',
	
			disk = ''k:\k_backup\db_backups\' + rtrim (@instancename) + '\' + replace (upper(@dbname),'.','_') + '\'
			+ replace (@servername,'\','_') + '_'
			+ replace (upper(@dbname),'.','_') + '_full_compressed3.bak'',

			disk = ''k:\k_backup\db_backups\' + rtrim (@instancename) + '\' + replace (upper(@dbname),'.','_') + '\'
			+ replace (@servername,'\','_') + '_'
			+ replace (upper(@dbname),'.','_') + '_full_compressed4.bak''
			with compression, init'
		)

		exec (@cmd)
		set @a = @a + 1
	end try

	begin catch
		print 'error_number:'	+convert(varchar(max),error_number())
		print 'error_severity'	+convert(varchar(max),error_severity())
		print 'error_state'	+convert(varchar(max),error_state())
		print 'error_procedure' +error_procedure()
		print 'error message:' +error_message()
	if error_number() in (3013)
	begin
		set @retrycount = @retrycount + 1
		print 'incrementing retry to: ' +convert(varchar(max),@retrycount)
		print 'waiting for: ' + @wait
		waitfor delay @wait

	end
	end catch
	if @retrycount > 12
	begin
		set @error_message = '12 retry limit reached: backup' + @dbname + 'failed.'
			raiserror(@error_message, 16, 1)
	end
end