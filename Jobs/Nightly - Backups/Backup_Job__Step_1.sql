use master
set nocount on
if object_id('tempdb..#dbnames') is not null
drop table #dbnames

use master
if object_id('tempdb..#directorytree') is not null
drop table #directorytree

if object_id('tempdb..#recovery_model') is not null
drop table #recovery_model

select identity(int, 1, 1) as ruid, name
into #dbnames
from sys.databases
where name <> 'tempdb'

select identity (int, 1,1) as ruid, recovery_model, name
into #recovery_model
from sys.databases
where name <> 'tempdb'

create table #directorytree
(
	subdirectory nvarchar(50),
	depth int
)

declare
	 @a					int = 1
	,@b					int = (select max(ruid) from #dbnames)
	,@cmd_full			varchar(100)
	,@cmd_simple		varchar(100)
	,@dbname			varchar(25)
	,@instance_name		varchar(25) = convert(varchar(50),serverproperty('instancename'))
	,@servername		varchar(25) = convert(varchar(50),serverproperty('servername'))
	,@drive_letter		varchar(3)
	,@sub_dir_1			varchar(25)
	,@recovery_model	int

set @drive_letter = (select distinct(left(physical_name, 1) + ':\') from sys.master_files)

insert #directorytree (subdirectory, depth)
exec master.sys.xp_dirtree @drive_letter ,1 ,0

set @sub_dir_1 = (select subdirectory from #directorytree where subdirectory like '%backup%')

while @a <= @b
begin
	set @dbname			= (select name from #dbnames where ruid = @a)
	set @recovery_model	= (select recovery_model from #recovery_model where ruid = @a)
	set @cmd_simple		= (@drive_letter + @sub_dir_1 + '\db_backups\' + rtrim(@instance_name) + '\' + replace(upper(@dbname),'.','_')+ '\')
	set @cmd_full		= (@cmd_simple + 'tlog')

	if @recovery_model = 3
		print @cmd_simple
	else
		print @cmd_full
	set @a = @a + 1
end

if object_id('tempdb..#dbnames') is not null
drop table #dbnames

use master
if object_id('tempdb..#directorytree') is not null
drop table #directorytree

if object_id('tempdb..#recovery_model') is not null
drop table #recovery_model