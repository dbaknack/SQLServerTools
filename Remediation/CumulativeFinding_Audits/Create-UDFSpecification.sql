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
-- set 1 to drop and recreate the audit if it exists, 0 will create it
declare @recreateSpecification int				= 1

declare @auditName varchar(max)					= 'STIG_AUDIT_SERVER'
declare @auditSpecificationsName varchar(max)	= 'STIG_AUDIT_SERVER_SPECIFICATION'
declare	@auditSpecificationsList varchar(max)	= '
	add (APPLICATION_ROLE_CHANGE_PASSWORD_GROUP),
	add (AUDIT_CHANGE_GROUP),
	add (BACKUP_RESTORE_GROUP),
	add (DATABASE_CHANGE_GROUP),
	add (DATABASE_OBJECT_CHANGE_GROUP),
	add (DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP),
	add (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
	add (DATABASE_OPERATION_GROUP),
	add (DATABASE_OWNERSHIP_CHANGE_GROUP),
	add (DATABASE_PERMISSION_CHANGE_GROUP),
	add (DATABASE_PRINCIPAL_CHANGE_GROUP),
	add (DATABASE_PRINCIPAL_IMPERSONATION_GROUP),
	add (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
	add (DBCC_GROUP),
	add (LOGIN_CHANGE_PASSWORD_GROUP),
	add (LOGOUT_GROUP),
	add (SCHEMA_OBJECT_CHANGE_GROUP),
	add (SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP),
	add (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
	add (SERVER_OBJECT_CHANGE_GROUP),
	add (SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP),
	add (SERVER_OBJECT_PERMISSION_CHANGE_GROUP),
	add (SERVER_OPERATION_GROUP),
	add (SERVER_PERMISSION_CHANGE_GROUP),
	add (SERVER_PRINCIPAL_CHANGE_GROUP),
	add (SERVER_PRINCIPAL_IMPERSONATION_GROUP),
	add (SERVER_ROLE_MEMBER_CHANGE_GROUP),
	add (SERVER_STATE_CHANGE_GROUP),
	add (TRACE_CHANGE_GROUP),
	add (USER_CHANGE_PASSWORD_GROUP),
	add (SUCCESSFUL_LOGIN_GROUP),
	add (SCHEMA_OBJECT_ACCESS_GROUP),
	add (FAILED_LOGIN_GROUP),
	add (DATABASE_OBJECT_ACCESS_GROUP)
'


declare @auditState	int = (
	select is_state_enabled
	from sys.server_audits
	where name = @auditName
)
declare @auditSpecificationState int = (
	select is_state_enabled
	from sys.server_audit_specifications
	where name = @auditSpecificationsName
)

declare @cmdSetAuditStateOff varchar(max) = '
	alter server audit ['+@auditName+']
	with (state = off)'

declare @cmdSetAuditServerSpecificationOff varchar(max) = '
	alter server audit specification ['+@auditSpecificationsName+']
	with (state = off)'

declare @cmdCreateAuditSpecifications varchar(max) = '
	create server audit specification ['+@auditSpecificationsName+']
	for server audit ['+@auditName+']
	'+@auditSpecificationsList+''
declare @cmdDropAuditSpecifications varchar(max) = '
	drop server audit specification ['++@auditSpecificationsName++']'


-- tracker: store script items done
declare @status as Table (
	Ruid		int	identity(1,1),
	TaskID		int,
	Task		varchar(max),
	OutcomeDesc	varchar(max),
	OutcomeID	int
)

if(select @auditState) = 0
begin
    insert into @status
	values(1,'check_audit_state','the audit '''+@auditName+''' is set to disabled ',0)
end
else
begin
    insert into @status
	values(1,'check_audit_state','the audit '''+@auditName+''' is set to enabled ',1)
end

if(select OutcomeID from @status where TaskID = 1) = 1
begin
	exec (@cmdSetAuditStateOff)
	insert into @status
	values(2,'changed_audit_state','the audit '''+@auditName+''' has been disabled ',1)
end
else
begin
	insert into @status
	values(2,'changed_audit_state','the audit '''+@auditName+''' doesnt not need to be changed ',0)
end

if exists (select 1 from sys.server_audit_specifications where [name] = @auditSpecificationsName)
begin
	insert into @status
	values(3,'audit_specification_exists','the audit specification '''+@auditSpecificationsName+''' exists',1)
end
else
begin
	insert into @status
	values(3,'audit_specification_exists','the audit specification '''+@auditSpecificationsName+''' does not exists',0)
end

-- when the specification exists, the user parameter is used to see if its going
-- to be recreated
if(select OutcomeID from @status where TaskID = 3) = 1
begin
	if(@auditSpecificationState) = 1
	begin
		insert into @status
		values(4,'audit_specification_status','the audit specification '''+@auditSpecificationsName+''' is enabled',1)
	end
	else
	begin
		insert into @status
		values(4,'audit_specification_status','the audit specification '''+@auditSpecificationsName+''' is disabled',0)
	end

	if(select OutcomeID from @status where TaskID = 4) = 1
	begin
		exec (@cmdSetAuditServerSpecificationOff)
		insert into @status
		values(4,'audit_specification_status','the audit specification '''+@auditSpecificationsName+''' has been disabled',1)
	end
	
	if(@recreateSpecification) = 1
	begin
		exec (@cmdDropAuditSpecifications)
		insert into @status
		values(4,'audit_specification_dropped','the audit specification '''+@auditSpecificationsName+''' has been dropped',-1)
	end
end

exec (@cmdCreateAuditSpecifications)
insert into @status
values(5,'audit_specification_created','the audit specification '''+@auditSpecificationsName+''' has been created',1)

select * from @status
