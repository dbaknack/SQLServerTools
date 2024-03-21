set nocount on
use [master]

-- variables: define
declare @domainName nvarchar(max)	= (select cast( default_domain() as nvarchar(max)))
declare @instanceName nvarchar(max) = (
	select case when serverproperty('instancename') is null
		then cast(serverproperty('machineName')		as nvarchar(max))
		else cast(serverproperty('instancename')	as nvarchar(max))
	end
)

-- user: parameters
-- set 1 to drop and recreate the audit if it exists
declare @recreateAudit int					= 1

-- configuration: audit
declare @auditName varchar(max)				= 'STIG_AUDIT_SERVER'
declare	@auditPropFilePath varchar(max)		= 'A:\Audits\'+@instanceName+''
declare @auditPropFileMaxSizeMB char(3)		= '100'
declare @auditPropMaxFiles char(3)			= '100'
declare	@auditPropOnfailure	varchar(max)	= 'Continue'
declare @auditPropRsrvDiskSpace varchar(3)	= 'Off'
declare @auditPropQueueDelay varchar(max)	= '1000'

-- tracker: store script items done
declare @status as Table (
	Ruid		int	identity(1,1),
	TaskID		int,
	Task		varchar(max),
	OutcomeDesc	varchar(max),
	OutcomeID	int
)

-- declare: audit commands
declare @cmdCreateAudit varchar(max) = '
create server audit ['+@auditName+']
to file(
	filepath			= '''+@auditPropFilePath+''',
	maxsize				= '+@auditPropFileMaxSizeMB+' mb,
	max_files			= '+@auditPropMaxFiles+',
	reserve_disk_space	= '+@auditPropRsrvDiskSpace+'
)
with(
	queue_delay = '+@auditPropQueueDelay+',
	on_failure	= '+@auditPropOnfailure+'
)'
declare @cmdSetAuditStateOff varchar(max) = '
alter server audit ['+@auditName+']
with (state = Off)'

declare @cmdDropAudit varchar(max) = '
	drop server audit ['+@auditName+']'

-- check: validate and audit exists
if exists( select 1 from sys.server_audits)
begin
    insert into @status
	values(1,'check_audit_exists','audit exists',1)
end
else
begin
    insert into @status
	values(1,'check_audit_exists','no audit exists',0)
end

-- check: validate audit of named provided exists
if exists(select 1 from sys.server_audits where [name] = @auditName)
begin
	insert into @status
	values(2,'check_named_audit_exists','audit named '''+@auditName+''' exists',1)
end
else
begin
	insert into @status
	values(2,'check_named_audit_exists','no audit named '''+@auditName+''' does not exists',0)
end

if(select OutcomeID from @status where TaskID = 1) = 0
begin
	-- task: no audit exists
	insert into @status
	values(3,'audit_create','since no audit exists, one will be created',-1)

	exec(@cmdCreateAudit)
	insert into @status
	values(3,'audit_create','audit created',1)
end
else
begin
	-- task: an audit exists
	insert into @status
	values(3,'audit_create','an audit exists, before creating one, the name needs to be checked',-1)

	if (select OutcomeID from @status where TaskID = 2) = 1
	begin
		-- task: audit to create already exists
		insert into @status
		values(3,'audit_of_same_name_exists','the audit attempting to create, already exist',0)

		if(@recreateAudit) = 1
		begin
			-- task: evaluate use preference when audit already exists
			insert into @status
			values(4,'evaluate_audit_preference','user selected to recreate audit when it exists',1)			
		end
		else
		begin
			-- task: audit to create already exists
			insert into @status
			values(4,'evaluate_audit_preference','user selected to not recreate audit when it exists',0)
		end

		if(select OutComeID from @status where TaskID = 4) = 1
		begin
			if(select is_state_enabled from sys.server_audits) = 1
			begin
				insert into @status
				values(5,'audit_status','currently the audit is enabled, need to be disabled to remove',0)
			end
			else
			begin
				insert into @status
				values(5,'audit_status','currently the audit is disabled, will not need to disable it',1)
			end

			if(select OutcomeID from @status where TaskID = 5) = 0
			begin
				exec (@cmdSetAuditStateOff)
				insert into @status
				values(6,'audit_status','the audit state for audit '''+@auditName+''' has been set to disabled',-1)
			end

			exec (@cmdDropAudit)
			insert into @status
			values(7,'audit_status','the audit '''+@auditName+''' has been dropped',1)

			exec (@cmdCreateAudit)
			insert into @status
			values(8,'audit_status','the audit '''+@auditName+''' has been recreated',1)
		end
	end
end

select * from @status
