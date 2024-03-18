if exists (select 1 from sys.objects where object_id = object_id('tempdb..#ExtendedProcedures'))
begin
    drop table #ExtendedProcedures
end

create #ExtendedProcedures table (
    RecID       int identity(1,1),
    Procedure   varchar(100) null,
    isApproved  bit DEFAULT 0
)

insert into #ExtendedProcedures
values
    ('Procedure','Description'
    ('xp_regaddmultistring','Adds multi-string value to Windows registry'),
    ('xp_regdeletekey','Deletes registry key and its subkeys and values'),
    ('xp_regdeletevalue','Deletes specific value under given registry key'),
    ('xp_regenumvalues','Retrieves names and types of values under registry key'),
    ('xp_regenumkeys','Retrieves names of subkeys under registry key'),
    ('xp_regremovemultistring','Removes multi-string value from Windows registry'),
    ('xp_regwrite','Writes value to Windows registry under specified key'),
    ('xp_instance_regaddmultistring','Adds multi-string value to registry within SQL Server instance'),
    ('xp_instance_regdeletekey','Deletes registry key and its values within SQL Server instance'),
    ('xp_instance_regdeletevalue','Deletes specific value under given registry key within SQL Server instance'),
    ('xp_instance_regenumkeys','Retrieves names of subkeys under registry key within SQL Server instance'),
    ('xp_instance_regenumvalues','Retrieves names and types of values under registry key within SQL Server instance'),
    ('xp_instance_regremovemultistring','Removes multi-string value from registry within SQL Server instance'),
    ('xp_instance_regwrite','Writes value to Windows registry under specified key within SQL Server instance'),

