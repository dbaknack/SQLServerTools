set nocount on
declare
	@insertedcount				int,
	@filterblockedevents_min	int,
	@eventlabel					varchar(22),
	@test						bit,
	@retentionperiodin_day		int,
	@target						varchar(25)

set	@retentionperiodin_day		= -7							--< 1) retain records for how n day(s)
set	@test						= 0								--< 2) set to 1 if testing
set @filterblockedevents_min	= -500							--< 3) match to redgate alert interval
set @eventlabel					= 'blocked_process_report'		--< 4) match to session event being monitored
set @target						= 'lock-deadlock events*.xel'	--< 5) set to match session event output filename


-- when testing, you want to work with a clean temp table
if (@test) = 1
begin
	drop table #session_events_blocked_process_alertdata
end
if object_id('tempdb.dbo.#session_events_blocked_process_alertdata', 'u') is null
begin
	create table #session_events_blocked_process_alertdata (
		eventlabel				varchar(22),
		blockedprocess_datetime datetime2(2),
		blockedprocess_status	varchar(20),
		blockedprocess_spid		int
	)
end
else
begin
	-- records are removed given your event label and retention period
	delete
	from
		#session_events_blocked_process_alertdata
	where
		blockedprocess_datetime <
		dateadd(
			hour,
			@retentionperiodin_day,
			getdate()
		) and
		eventlabel = @eventlabel

end
-- use the session event as the data source, define time window of interest
;with cte as (
    select
        raweventdata		= convert(
			xml,
			event_data
		),
        loggeddatetimelocal = dateadd(hour,
			datediff(
				hour,
				getutcdate(),
				getdate()
			), timestamp_utc
		)
    from
        sys.fn_xe_file_target_read_file(
			@target	,
			null,
			null,
			null
		)
    where
        object_name = @eventlabel and
		dateadd(
			hour,
			datediff(
				hour,
				getutcdate(),
				getdate()
			),timestamp_utc
		) > dateadd(
			minute,
			@filterblockedevents_min,
			getdate()
		)
)
insert into #session_events_blocked_process_alertdata (
	eventlabel,
	blockedprocess_datetime,
	blockedprocess_status,
	blockedprocess_spid
)
select distinct
    -- blocked process stats
	eventlabel				= @eventlabel,
    blockedprocess_datetime = cast(raweventdata.value('(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@lastbatchstarted)[1]'	, N'nvarchar(max)') as datetime2(2)),
    blockedprocess_status	= raweventdata.value('(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@status)[1]'				, N'nvarchar(max)'),
    blockedprocess_spid		= raweventdata.value('(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process/@spid)[1]'					, N'nvarchar(max)')
from cte
where not exists (
select
	eventlabel,
	blockedprocess_datetime,
	blockedprocess_status,
	blockedprocess_spid
from #session_events_blocked_process_alertdata)

-- alert used count to alert on how many blocked processes have accured in the time window set
set @insertedcount				= @@rowcount
select blockedprocesses_count	= @insertedcount
