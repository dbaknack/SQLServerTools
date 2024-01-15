--<< backup tlogs >>--
if object_id('tempdb..#dbnames') is not null
	drop table #dbnames
set nocount on;

select 
	identity(int,1,1) as ruid, [name] into #dbnames
from 
	sys.databases
where
	[name] not in ('tempdb','master') and state_desc = 'online'

declare
@a int = 1,
@b int = (select max(ruid) from #dbnames),
@time varchar(50) = replace(replace(convert(varchar(10),getdate(),108), ' ',''),':',''),
@cmd varchar(600),
@dbname varchar(30),
@instancename varchar(30) = convert(varchar(50),serverproperty('instancename')),
@servername varchar(30) = convert(varchar(50),serverproperty('servername'))

while @a <= @b
begin
	set @dbname = (select name from #dbnames where ruid = @a)
	set @cmd = 
	('backup log [' +rtrim(@dbname)+']
	to disk = ''k:k_backup\db_backups\'+rtrim(@instancename)+'\'+replace(upper(@dbname),'.','_')+'\tlog\'
	+replace(upper(@dbname),'.','_')+'_tlog'+'_'+ltrim(rtrim(@time))+'.trn''
	with compression, init')

	print (@cmd)

	set @a = @a+1
end

if object_id('tempdb..#dbnames') is not null
	drop table #dbnames

