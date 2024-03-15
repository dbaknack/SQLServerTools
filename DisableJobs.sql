USE msdb;
GO

-- Declare a table variable to hold job names
DECLARE @JobsToDisable TABLE (JobName NVARCHAR(128));

-- Insert the names of the jobs you wish to disable
INSERT INTO @JobsToDisable (JobName) VALUES
('test2'),
('test3'),
('test4'),
('test5'),
('test6'),
('test7'),
('test8'),
('test9'),
('test10'),
('test12'),
('test13'),
('test14'),
('Track')

-- Add more jobs as needed
;

-- Variable to hold the current job name in the loop
DECLARE @CurrentJobName NVARCHAR(128);

-- Cursor to iterate through the job names
DECLARE JobCursor CURSOR FOR
SELECT JobName FROM @JobsToDisable;

-- Open the cursor
OPEN JobCursor;

-- Fetch the first job name into the variable
FETCH NEXT FROM JobCursor INTO @CurrentJobName;

-- Loop through the cursor
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Disable the current job
    EXEC sp_update_job
        @job_name = @CurrentJobName,
        @enabled = 0;  -- 0 to disable

    -- Fetch the next job name
    FETCH NEXT FROM JobCursor INTO @CurrentJobName;
END

-- Clean up
CLOSE JobCursor;
DEALLOCATE JobCursor;
GO
