declare
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
		print 'error_number:'	+convert(varchar(max),error_number())
		print 'error_severity'	+convert(varchar(max),error_severity())
		print 'error_state'		+convert(varchar(max),error_state())
		print 'error_procedure' +error_procedure()
		print 'error message:'	+error_message()
	end catch
	set @db_counter = @db_counter + 1
end

IF OBJECT_ID('tempdb.dbo.BackUpJobParams', 'U') IS NOT NULL
BEGIN
    -- Drop the table if it exists
    DROP TABLE tempdb.dbo.BackUpJobParams;
END