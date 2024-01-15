DECLARE @rootInstallPath NVARCHAR(512);

-- Get the root installation path
SELECT @rootInstallPath =
	REPLACE(
		SUBSTRING(
			physical_name,1,LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1
		)
	,'DATA\',''
)
FROM sys.master_files
WHERE database_id = 1 AND file_id = 1;


-- Display the result
select @rootInstallPath
SELECT 'RootInstallPath' AS PropertyName, @rootInstallPath AS PropertyValue;

select * from 
sys.master_files