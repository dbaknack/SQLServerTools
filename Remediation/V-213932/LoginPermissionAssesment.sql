set nocount on


if exists (select 1 from tempdb.sys.objects where object_id = object_id(N'tempdb..#assessedLogin'))
begin
    drop table #assessedLogin
end

CREATE TABLE #assessedLogin (
	recid INT IDENTITY(1,1),
	InstanceName VARCHAR(25) NULL,
	LoginName VARCHAR(50) NULL
)


INSERT INTO #assessedLogin
VALUES
('DEVINSTANCE','MST3K\abrah'),
('INST01','sa')

declare @instancename nvarchar(128)
set @instancename = @@servername

if charindex('\', @instancename) > 0
    set @instancename = substring(@instancename, charindex('\', @instancename) + 1, len(@instancename))
else
    set @instancename = convert(nvarchar(128), serverproperty('machinename'))

SELECT 
	 [hostname]		= serverproperty('machinename')
	 ,[instanceName] = @instancename,
    rp.name AS LoginName,
	rp.type,
	rp.type_desc,
	rp.is_disabled,
    p.permission_name AS Permission,
    p.state_desc AS PermissionState,
	CASE WHEN (al.LoginName IS NULL) THEN 'login has not been assesesed.'
		ELSE 'login has  been assesed'
	END AS 'Assessed'
	
FROM 
    sys.server_principals rp
JOIN 
    sys.server_permissions p ON p.grantee_principal_id = rp.principal_id
LEFT OUTER JOIN #assessedLogin al ON rp.name = al.LoginName
WHERE rp.name NOT LIKE '##%' AND rp.type_desc IN ('SQL_LOGIN', 'WINDOWS_LOGIN', 'WINDOWS_GROUP')


