
set nocount on
declare
	@filterblockedevents_min	int,
	@eventlabel					varchar(22),
	@target						varchar(25)



set @filterblockedevents_min	= -500							--< 1) get stats on blocked processes from n minutes ago upto now
set @eventlabel					= 'blocked_process_report'
set @target						= 'lock-deadlock events*.xel'

-- use the session event as the datasource
;WITH cte AS
(
  SELECT
  RawEventData			= CONVERT(XML, event_data),
  LoggedDateTimeLocal	= dateadd(hh, datediff(hh, getutcdate(), getdate()), timestamp_utc)
  FROM
  sys.fn_xe_file_target_read_file(@target, NULL, NULL, NULL)
  WHERE
  object_name = @eventlabel	 and
  dateadd(hh, datediff(hh, getutcdate(), getdate()), timestamp_utc) > dateadd(MINUTE,@filterblockedevents_min,getdate())
)
SELECT 
  LoggedDateTime			= LoggedDateTimeLocal,
  InstanceName				= serverproperty('servername'),
  EventDataBase				= RawEventData.value(N'(event/data[@name = "database_name"]/value)[1]', N'sysname'),

  BlockedProcess_DateTime	= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@lastbatchstarted)[1]',  N'nvarchar(max)'),
  BlockedProcess_Status		= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@status)[1]',  N'nvarchar(max)'),
  BlockedProcess_SPID		= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@spid)[1]',  N'nvarchar(max)'),
  BlockedProcess_HostName	= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@hostname)[1]',  N'nvarchar(max)'),
  BlockedProcess_LoginName	= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@loginname)[1]',  N'nvarchar(max)'),

  BlockingProcess_DateTime	= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process/@lastbatchstarted)[1]',  N'nvarchar(max)'),
  BlockingProcess_SPID		= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process/@spid)[1]',  N'nvarchar(max)'),
  BlockingProcess_Status	= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process/@status)[1]',  N'nvarchar(max)'),
  BlockingProcess_HostName	= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process/@hostname)[1]',  N'nvarchar(max)'),
  BlockingProcess_LoginName	= RawEventData.value(N'(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process/@loginname)[1]',  N'nvarchar(max)'),
  RawData_XML				= cte.RawEventData
FROM cte
