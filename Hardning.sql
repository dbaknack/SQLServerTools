set nocount on

-- set 1 to drop and recreate server level role, set 0 to create server level roles, if they dont already exists
declare @DropAndRecreateServerRole bit = 1

begin --region --  [FUNCTIONS]
	-- Get members of a server-level role in SQL Server 2016
	declare @cmd_GetServerRoleMembers nvarchar(max) = '
	SELECT 
		serverRoles.name AS ServerRole,
		members.name AS MemberName
	FROM 
		sys.server_principals serverRoles
	JOIN 
		sys.server_role_members roleMembers ON serverRoles.principal_id = roleMembers.role_principal_id
	JOIN 
		sys.server_principals members ON roleMembers.member_principal_id = members.principal_id
	WHERE 
		serverRoles.type_desc = ''SERVER_ROLE'''
end			--endregion--
begin --region --  [DYNAMIC PARAMETERS]
	-- domain
	declare @DomainName		nvarchar(max) =  (
		select cast( default_domain() as nvarchar(max))
	)

	-- instance
	declare @InstanceName	nvarchar(max) =	(
	select case when SERVERPROPERTY('instancename') is null
		then CAST(SERVERPROPERTY('machineName') as nvarchar(max))
		else CAST(SERVERPROPERTY('machineName') as nvarchar(max)) + '\\' + CAST(SERVERPROPERTY('instancename') as nvarchar(max))
	end
	)
end	-- endregion--
begin --region --  [DATA]
	-- data structure
	declare @DataSource nvarchar(max)= N'{
		"Domains" : {
			"DEVLAB": {
				"InstanceNames": {
					"DEV-SQL01\\SANDBOX01": {
						"Roles" : {
							"ServerLevel": {
								"AuditLogMaintenanceRole": {
									"Members": [
										"DEVLAB\\SQLAdmins"
									],
									"GRANT": [
										"CONTROL SERVER",
										"ALTER ANY SERVER AUDIT",
										"ALTER ANY DATABASE",
										"CREATE ANY DATABASE"
									]
								}
							},
							"DatabaseLevel": {}
						}
					},
					"DEV-SPLT01\\INST01": {}
				}
			}
		}
	}';
end	--endregion--

-- define path to data
declare @RoleType nvarchar(max) = 'ServerLevel'
declare @lvl01_PropKey	nvarchar(max) = 'Domains'
declare	@lvl01_PropVal	nvarchar(max) = @DomainName
declare	@lvl02_PropKey	nvarchar(max) = 'InstanceNames'
declare @lvl02_PropVal	nvarchar(max) = '"'+@InstanceName+'"'
declare	@lvl03_PropKey	nvarchar(max) = 'Roles'
declare @lvl03_PropVal  nvarchar(max) = '"'+@RoleType+'"'

-- concat path
declare @jsonPath		nvarchar(max) = '$.'+@lvl01_PropKey+'.'+@lvl01_PropVal+'.'+@lvl02_PropKey+'.'+@lvl02_PropVal+'.'+@lvl03_PropKey+'.'+@lvl03_PropVal
declare @cmd			nvarchar(max) = 'select [key] from openjson(@DataSource,'+quotename(@jsonPath,'''')+')'

----------------------------------------------------------------------------------------------------------------------------------------- ServerLevel Roles
declare @ServerLevelRoles as table (Ruid int identity(1,1),RoleName	varchar(max))

-- execute command to retreive data
insert into @ServerLevelRoles
exec sp_executesql @cmd,N'@DataSource nvarchar(MAX)', @DataSource

-- loop on role types
declare @ruid_role		int = 1
declare	@total_roles	int = (select max(ruid) from @ServerLevelRoles)
declare @RoleName		nvarchar(max)
while @ruid_role <= @total_roles
begin
	begin --region --  [ROLE CREATION]
		print CHAR(10)+'ROLE CREATION'
		print '-------------'
		set @RoleName = (select RoleName from @ServerLevelRoles where Ruid = @ruid_role)

		-- display feed back - user parameter set...
		if(@DropAndRecreateServerRole) = 1
		begin
			print '[Informational]:: user parameter DropAndRecreateServerRole set'
		end
	

		-- check: when users exists...
		if exists (select 1 from sys.server_principals where type_desc = 'server_role' and name = @RoleName)
		begin

			-- when user exists, and user parameter set to drop and recreate..
			if(@DropAndRecreateServerRole) = 1
			begin
				-- check what roles exist
				declare @CurrentRoleMembers as table(Ruid int identity(1,1), ServerRole varchar(max), MemberName varchar(max))

				insert into @CurrentRoleMembers
				exec sp_executesql @cmd_GetServerRoleMembers

				-- if the role has members, remove them
				IF EXISTS (SELECT 1 FROM @CurrentRoleMembers WHERE ServerRole = @RoleName)
				begin
					declare @MembersList as table (Ruid int identity(1,1), MemberName varchar(max))
					insert into @MembersList
					select MemberName from @CurrentRoleMembers where ServerRole = @RoleName
					
					declare @ruid_members_list		int = 1
					declare @total_current_members	int = (select max(Ruid) from @MembersList)
					declare @from_list_member		varchar(max)
					while @ruid_members_list <= @total_current_members
					begin
						set @from_list_member = (select MemberName from @MembersList where Ruid = @ruid_members_list)
						set @cmd =  'ALTER SERVER ROLE '+@RoleName+' DROP MEMBER '+ '['+@from_list_member+']'
						--ALTER SERVER ROLE AuditLogMaintenanceRole DROP MEMBER [DEVLAB\SQLAdmins]
						exec (@cmd)
						print 'Dropped '+ @from_list_member +'from server role '+@RoleName
						set @ruid_members_list = @ruid_members_list + 1
					end
				end
				set @cmd = 'drop server role '+ @RoleName
				exec(@cmd)
				print 'server role '+ @RoleName+' dropped...'

				-- create server role
				set @cmd = 'create server role '+ @RoleName	
				exec(@cmd)
				print 'server role '+ @RoleName+' created...'
			end
			else
			begin
				print  'server role '+ @RoleName+' already exists...'
			end
		end
		else
		begin
			-- check: when user doesn't exits it will be created
			set @cmd = 'create server role '+ @RoleName	
			exec(@cmd)
			print 'server role '+ @RoleName+' created...'
		end

	end --endregion--

	begin --region --  [ROLE GRANT PERMISSIONS]
		print CHAR(10)+'ROLE GRANT PERMISSIONS'
		print '---------------------'
		-- set path to GRANT Permissions for the current role...

		declare @PermissionType nvarchar(max) = 'GRANT'

		declare	@lvl04_PropKey	nvarchar(max) = '"'+@RoleName+'"'
		declare	@lvl04_PropVal	nvarchar(max) = '"'+@PermissionType+'"'
		-- concat path
		set @jsonPath	= '$.'+@lvl01_PropKey+'.'+@lvl01_PropVal+'.'+@lvl02_PropKey+'.'+@lvl02_PropVal+'.'+@lvl03_PropKey+'.'+@lvl03_PropVal+'.'+@lvl04_PropKey+'.'+@lvl04_PropVal
		set	@cmd		= 'select [value] from openjson(@DataSource,'+quotename(@jsonPath,'''')+')'

		declare @ServerLevelGrants as table (Ruid int identity(1,1),Permission	varchar(max))
		insert into @ServerLevelGrants
		exec sp_executesql @cmd,N'@DataSource nvarchar(max)', @DataSource
		
		declare @ruid_grant_permission		int				= 1
		declare @total_grant_permissions	nvarchar(max)	= (select max(ruid) from @ServerLevelGrants)
		declare @permission					nvarchar(max)
		
		while @ruid_grant_permission <= @total_grant_permissions
		begin
			set @permission = (select Permission from @ServerLevelGrants where Ruid = @ruid_grant_permission)
			set @cmd = 'grant '+@permission+' to '+@RoleName
			exec sp_executesql @cmd
			print 'granted '+@permission+' to '+@RoleName
			set @ruid_grant_permission = @ruid_grant_permission + 1
		end
	end --endregion--

	begin --region --  [ADD ROLE MEMBERS]
		print CHAR(10)+'ADD ROLE MEMBERS'
		print '----------------'

		declare @Member nvarchar(max)

		set	@lvl04_PropKey	= '"'+@RoleName+'"'
		set	@lvl04_PropVal	= '"'+'Members'+'"'
		-- concat path
		set @jsonPath	= '$.'+@lvl01_PropKey+'.'+@lvl01_PropVal+'.'+@lvl02_PropKey+'.'+@lvl02_PropVal+'.'+@lvl03_PropKey+'.'+@lvl03_PropVal+'.'+@lvl04_PropKey+'.'+@lvl04_PropVal
		set	@cmd		= 'select [value] from openjson(@DataSource,'+quotename(@jsonPath,'''')+')'

		declare @ServerLevelRoleMembers as table (Ruid int identity(1,1),Member varchar(max))
		insert into @ServerLevelRoleMembers
		exec sp_executesql @cmd,N'@DataSource nvarchar(max)', @DataSource
		
		declare @ruid_member	int				= 1
		declare @total_memebers	nvarchar(max)	= (select max(ruid) from @ServerLevelRoleMembers)
		
		while @ruid_member <= @total_memebers
		begin
			set @Member = (select '['+Member+']' from @ServerLevelRoleMembers where Ruid = @ruid_member)
			set @cmd = 'ALTER SERVER ROLE '+@RoleName+' ADD MEMBER '+@Member
			exec sp_executesql @cmd
			print 'added '+@Member+' to '+@RoleName
			set @ruid_member = @ruid_member + 1
		end
	end --endregion--

	set @ruid_role = @ruid_role + 1
end





