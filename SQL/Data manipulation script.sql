-------------------------------------------------------------------------------
-- Time Log Redistribution Script
-- Author		Mark Jackson
-- Created		20/04/2020
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- IMPORTANT User Guidance
-- Ensure all required values are set in the 'User defined variables' section.
-------------------------------------------------------------------------------

SET NOCOUNT ON

-------------------------------------------------------------------------------
-- User defined variables.
-------------------------------------------------------------------------------

-- Commit flag (1 = Commit, 0 = Don't Commit).
DECLARE @Commit BIT = 0

-- Display verification flag (1 = Display, 0 = Don't Display).
DECLARE @DisplayVerification BIT = 1

-- The works order number for which to redistribute time logs.
DECLARE @WorksOrderNumber INT = 31588

-- The percentage of total time to be redistributed.
-- e.g. 80 = redistribute 80% of the logged time.
DECLARE @RedistributionPercentage FLOAT = 80

-- The valid hours during the day in which time logs can be redistributed.
-- e.g. 6 = 6am, 18 = 6pm.
DECLARE @TimeRangeHourStart INT = 6
DECLARE @TimeRangeHourEnd INT = 20

-- The service tags of target equipment to which the logged time is to be redistributed.
DECLARE @RedistributionTargetServiceTags TABLE (
	[ServiceTagNumber] BIGINT
	)
INSERT INTO @RedistributionTargetServiceTags (
	[ServiceTagNumber]
	)
VALUES 
	(1000172990), (1000172991), (1000172992), (1000172993), (1000172994), (1000172995), (1000172996), (1000172997), (1000172998), (1000172999), (1000173000), (1000173001), (1000173002), (1000173003), (1000173004), (1000173005), (1000173006), (1000173007)

-- The employees and source periods from which the logged time is to be redistributed.
DECLARE @EmployeeSourcePeriods TABLE (
	[EmployeeId] INT,
	[PeriodStartDateTimeUtc] DATETIME,
	[PeriodEndDateTimeUtc] DATETIME
	)
INSERT INTO @EmployeeSourcePeriods (
	[EmployeeId],
	[PeriodStartDateTimeUtc],
	[PeriodEndDateTimeUtc]
	)
-- Canopy erection (Commenced 15th December).
SELECT
	employee.[EmployeeId],
	period.[PeriodStartDateTimeUtc],
	period.[PeriodEndDateTimeUtc]
FROM
	(
		SELECT '2019-12-15 00:00:00.000' AS [PeriodStartDateTimeUtc],
			   '2020-02-21 23:59:59.000' AS [PeriodEndDateTimeUtc]
	) period
	OUTER APPLY
	(
			  SELECT 100813 AS [EmployeeId]	-- Andrew Feather.
		UNION SELECT 100928 AS [EmployeeId]	-- Mo Latif.
		UNION SELECT 100976 AS [EmployeeId]	-- Thomas Tolutis.
		UNION SELECT 100833 AS [EmployeeId]	-- Lee Yates.
		UNION SELECT 100988 AS [EmployeeId]	-- Sajid Patel.
		UNION SELECT 100875 AS [EmployeeId]	-- Daniel Wrigley.
		UNION SELECT 101240 AS [EmployeeId]	-- Martin Somers (fork lift).
		UNION SELECT 100323 AS [EmployeeId]	-- Martin Hewitt (fork lift).
		UNION SELECT 101116 AS [EmployeeId]	-- Jon Tulley.
	) employee
-- Panel installation/skid movements (Commenced 3rd January).
UNION
SELECT
	employee.[EmployeeId],
	period.[PeriodStartDateTimeUtc],
	period.[PeriodEndDateTimeUtc]
FROM
	(
		SELECT '2020-01-03 00:00:00.000' AS [PeriodStartDateTimeUtc],
			   '2020-02-21 23:59:59.000' AS [PeriodEndDateTimeUtc]
	) period
	OUTER APPLY
	(
			  SELECT 100332 AS [EmployeeId]	-- Rafal Steinke.
		UNION SELECT 101403 AS [EmployeeId]	-- Daniel Laut.
		UNION SELECT 101260 AS [EmployeeId]	-- Henryk Strugala.
		UNION SELECT 100890 AS [EmployeeId]	-- Jaroslaw Beziuk.
		-- Martin Hewitt (fork lift) captured in Canopy erection list.
	) employee
-- Fish plate installation (Commenced 10th January).
UNION
SELECT
	employee.[EmployeeId],
	period.[PeriodStartDateTimeUtc],
	period.[PeriodEndDateTimeUtc]
FROM
	(
		SELECT '2020-01-10 00:00:00.000' AS [PeriodStartDateTimeUtc],
			   '2020-02-21 23:59:59.000' AS [PeriodEndDateTimeUtc]
	) period
	OUTER APPLY
	(
			  SELECT 101000 AS [EmployeeId]	-- Mohammad Sadaqut.
		UNION SELECT 101002 AS [EmployeeId]	-- Yasin Rodriguez.
		UNION SELECT 100999 AS [EmployeeId]	-- Chris Hayden.
		-- Jon Tulley captured in Canopy erection list.
		UNION SELECT 101363 AS [EmployeeId]	-- Cliff Garrett.
		UNION SELECT 101006 AS [EmployeeId]	-- Gary Lambley.
		UNION SELECT 100987 AS [EmployeeId]	-- Paul Jackson.
	) employee
-- Checker plate fitment/ vent fitment/ CN remedial works (Commenced 10th January).
UNION
SELECT
	employee.[EmployeeId],
	period.[PeriodStartDateTimeUtc],
	period.[PeriodEndDateTimeUtc]
FROM
	(
		SELECT '2020-01-10 00:00:00.000' AS [PeriodStartDateTimeUtc],
			   '2020-02-21 23:59:59.000' AS [PeriodEndDateTimeUtc]
	) period
	OUTER APPLY
	(
			  SELECT 101337 AS [EmployeeId]	-- Ian Jagger.
		UNION SELECT 101421 AS [EmployeeId]	-- Brett Holland.
		UNION SELECT 101211 AS [EmployeeId]	-- James Crompton.
		-- Mohammad Sadaqut captured in Canopy erection list.
		UNION SELECT 101210 AS [EmployeeId]	-- Graham Moon.
		UNION SELECT 100995 AS [EmployeeId]	-- Graeme Walker.
		UNION SELECT 101234 AS [EmployeeId]	-- Atif Mehboob.
	) employee
-- Aiding power on (Commenced 24th January).
		-- Cliff Garrett captured in Fish plate installation list.
		-- Jon Tulley captured in Canopy erection list.

-------------------------------------------------------------------------------
-- Table variables.
-------------------------------------------------------------------------------

DECLARE @EmployeeTimeLogs TABLE (
	[EmployeeId] INT,
	[TimeLogId] UNIQUEIDENTIFIER,
	[TimeLogActivityId] UNIQUEIDENTIFIER,
	[TimeLogStartOfWeekUtc] DATETIME,
	[TimeLogStartDateUtc] DATETIME,
	[TimeLogEndDateUtc] DATETIME,
	[TimeLogDurationSeconds] FLOAT
	)

DECLARE @TimeLogRanges TABLE (
	[StartRangeUtc] DATETIME,
	[EndRangeUtc] DATETIME
	)

-------------------------------------------------------------------------------
-- Populate table variable with employee time logs in scope.
-------------------------------------------------------------------------------

INSERT INTO @EmployeeTimeLogs (
	[EmployeeId],
	[TimeLogId],
	[TimeLogActivityId],
	[TimeLogStartOfWeekUtc],
	[TimeLogStartDateUtc],
	[TimeLogEndDateUtc],
	[TimeLogDurationSeconds]
	)
SELECT
	es.[EmployeeId],
	t.[Id],
	t.[TimeLogActivityId],
	-- Date part only.
	DATEADD(dd, 0, 
		-- Start of week (Monday).
		DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, t.[StartDateUtc])), DATEADD(dd, -1, t.[StartDateUtc])))
		),
	t.[StartDateUtc],
	t.[EndDateUtc],
	DATEDIFF(second, t.[StartDateUtc], t.[EndDateUtc])
FROM
	[dbo].[Timelog] t
	INNER JOIN @EmployeeSourcePeriods es 
		ON t.[EmployeeId] = es.[EmployeeId]
		AND t.[StartDateUtc] >= es.[PeriodStartDateTimeUtc]
		AND t.[EndDateUtc] <= es.[PeriodEndDateTimeUtc]
	INNER JOIN [dbo].[Equipment] e ON t.[EquipmentId] = e.[Id]
	INNER JOIN [dbo].[t2_prodsched] ps ON e.[ProductionSchedule_id] = ps.[PS_id]
	INNER JOIN [dbo].[qmf_tb] q ON ps.[PS_qmf_id] = q.[qmf_id]
	INNER JOIN [dbo].[WorksBook] w 
		ON q.[qmf_JB_id] = w.[WorksID]
		AND w.[WNumCount] = @WorksOrderNumber

-------------------------------------------------------------------------------
-- Begin processing.
-------------------------------------------------------------------------------

BEGIN TRANSACTION

	-------------------------------------------------------------------------------
	-- Verification (Before).

	IF (@DisplayVerification = 1)
	BEGIN
		-- Total count of hours by employee.
		SELECT 
			[EmployeeName], 
			SUM([Seconds])
		FROM (
			SELECT 
				emp.[EmployeeName], 
				DATEDIFF(second, t.[StartDateUtc], t.[EndDateUtc]) AS [Seconds]
			FROM
				[dbo].[Timelog] t 
				INNER JOIN [dbo].[Employees] emp ON t.[EmployeeId] = emp.[EmployeeID] 
				INNER JOIN [dbo].[Equipment] e ON t.[EquipmentId] = e.[Id]
				INNER JOIN [dbo].[t2_prodsched] ps ON e.[ProductionSchedule_id] = ps.[PS_id] 
				INNER JOIN [dbo].[qmf_tb] q ON ps.[PS_qmf_id] = q.[qmf_id]
				INNER JOIN [dbo].[TimeLogActivity] tla ON t.[TimeLogActivityId] = tla.[Id] 
				INNER JOIN [dbo].[WorksBook] w ON q.[qmf_JB_id] = w.[WorksID]
				INNER JOIN @EmployeeSourcePeriods esp ON emp.[EmployeeID] = esp.[EmployeeId]
			WHERE 
				t.[StartDateUtc] >= DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])))) 
				AND t.[EndDateUtc] <= DATEADD(ww, 1, DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])))))
			) sums
		GROUP BY 
			[EmployeeName] 
		ORDER BY 
			[EmployeeName]
		-- Time logs by employee.
		SELECT 
			emp.[EmployeeName], 
			tla.[Description], 
			t.[StartDateUtc], 
			t.[EndDateUtc], 
			DATEDIFF(second, t.[StartDateUtc], t.[EndDateUtc]),
			w.[WNumCount] AS [WO No]
		FROM
			[dbo].[Timelog] t 
			INNER JOIN [dbo].[Employees] emp ON t.[EmployeeId] = emp.[EmployeeID] 
			INNER JOIN [dbo].[Equipment] e ON t.[EquipmentId] = e.[Id]
			INNER JOIN [dbo].[t2_prodsched] ps ON e.[ProductionSchedule_id] = ps.[PS_id] 
			INNER JOIN [dbo].[qmf_tb] q ON ps.[PS_qmf_id] = q.[qmf_id]
			INNER JOIN [dbo].[TimeLogActivity] tla ON t.[TimeLogActivityId] = tla.[Id] 
			INNER JOIN [dbo].[WorksBook] w ON q.[qmf_JB_id] = w.[WorksID]
			INNER JOIN @EmployeeSourcePeriods esp ON emp.[EmployeeID] = esp.[EmployeeId]
		WHERE 
			t.[StartDateUtc] >= DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])))) 
			AND t.[EndDateUtc] <= DATEADD(ww, 1, DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])))))
		ORDER BY 
			emp.[EmployeeName], t.[StartDateUtc]
	END	
	-------------------------------------------------------------------------------

	-------------------------------------------------------------------------------
	-- Loop 1: Reduce existing hours to retained percentage of logged values.
	-------------------------------------------------------------------------------

	DECLARE @OriginalTimeLogId UNIQUEIDENTIFIER
	DECLARE @OriginalTimeLogStartDateUtc DATETIME 
	DECLARE @OriginalTimeLogEndDateUtc DATETIME 
	DECLARE @OriginalTimeLogDurationSeconds FLOAT

	-- Cursor: Original time logs.
	
	DECLARE cursor_original_time_logs CURSOR FOR
	SELECT
		[TimeLogId], 
		[TimeLogStartDateUtc], 
		[TimeLogEndDateUtc], 
		[TimeLogDurationSeconds]
    FROM 
        @EmployeeTimeLogs

	OPEN cursor_original_time_logs

	FETCH NEXT FROM cursor_original_time_logs INTO 
		@OriginalTimeLogId, 
		@OriginalTimeLogStartDateUtc, 
		@OriginalTimeLogEndDateUtc, 
		@OriginalTimeLogDurationSeconds

	WHILE @@FETCH_STATUS = 0
    BEGIN

		UPDATE
			[dbo].[Timelog]
		SET
			[EndDateUtc] = DATEADD(second, (@OriginalTimeLogDurationSeconds * ((100 - @RedistributionPercentage) / 100)), @OriginalTimeLogStartDateUtc)
		WHERE
			[Id] = @OriginalTimeLogId

		FETCH NEXT FROM cursor_original_time_logs INTO 
			@OriginalTimeLogId, 
			@OriginalTimeLogStartDateUtc, 
			@OriginalTimeLogEndDateUtc, 
			@OriginalTimeLogDurationSeconds
    END

	CLOSE cursor_original_time_logs
	DEALLOCATE cursor_original_time_logs

	-------------------------------------------------------------------------------
	-- Loop 2: Redistribute remaining hours to target service tags.
	-------------------------------------------------------------------------------

	DECLARE @EmployeeId INT
	DECLARE @EmployeeName NVARCHAR(MAX)
	DECLARE @StartOfWeekUtc DATETIME
	DECLARE @TimeLogActivityId UNIQUEIDENTIFIER
	DECLARE @RedistributedSeconds FLOAT
	DECLARE @TargetServiceTagNumber BIGINT
	DECLARE @TargetEquipmentId BIGINT

	-- Cursor: Employees / Week.

	DECLARE cursor_employee_week CURSOR FOR
	SELECT DISTINCT
		etl.[EmployeeId],
		e.[EmployeeName],
		etl.[TimeLogStartOfWeekUtc]
    FROM 
        @EmployeeTimeLogs etl
		INNER JOIN [dbo].[Employees] e ON etl.[EmployeeId] = e.[EmployeeID]
	ORDER BY
		e.[EmployeeName],
		etl.[TimeLogStartOfWeekUtc]

	OPEN cursor_employee_week

	FETCH NEXT FROM cursor_employee_week INTO 
		@EmployeeId,
		@EmployeeName,
		@StartOfWeekUtc

	WHILE @@FETCH_STATUS = 0
    BEGIN

		IF (@DisplayVerification = 1)
		BEGIN
			DECLARE @VerificationEmployeeName NVARCHAR(MAX)
			SELECT @VerificationEmployeeName = 
				EmployeeName 
			FROM 
				[dbo].[Employees] 
			WHERE 
				[EmployeeID] = @EmployeeId
			PRINT '-----------------------------------------------------------'
			PRINT UPPER(@VerificationEmployeeName)
			PRINT 'Week Beginning: ' + CONVERT(NVARCHAR, @StartOfWeekUtc, 106)
			PRINT '-----------------------------------------------------------'
		END

		-- Cursor: Target Service Tag / Activity / Total seconds.

		DECLARE cursor_target_service_tag_activity_seconds CURSOR FOR
		SELECT
			equipmentdata.[ServiceTagNumber],
			equipmentdata.[Id],
			tx.[TimeLogActivityId],
			(
				-- Redistribution percentage of total time for employee / week / activity.
				tx.[TotalSeconds] * (@RedistributionPercentage / 100)) 
				/ 
				-- Divide by total number of target tags to redistribute to.
				(SELECT COUNT([ServiceTagNumber]) FROM @RedistributionTargetServiceTags)
		FROM (
			SELECT
				[TimeLogActivityId],
				SUM([TimeLogDurationSeconds]) AS [TotalSeconds]
			FROM 
				@EmployeeTimeLogs
			WHERE
				[EmployeeId] = @EmployeeId
				AND [TimeLogStartOfWeekUtc] = @StartOfWeekUtc
			GROUP BY
				[TimeLogActivityId]
			) tx
			-- One resulting record for each target tag to apply to.
			OUTER APPLY (
				SELECT
					r.[ServiceTagNumber],
					e.[Id]
				FROM
					@RedistributionTargetServiceTags r
					INNER JOIN [dbo].[Equipment] e ON r.[ServiceTagNumber] = e.[ServiceTagNumber]
				) equipmentdata
		OPEN cursor_target_service_tag_activity_seconds

		FETCH NEXT FROM cursor_target_service_tag_activity_seconds INTO 
			@TargetServiceTagNumber,
			@TargetEquipmentId,
			@TimeLogActivityId,
			@RedistributedSeconds

		DECLARE @VerificationLastTimeLogActivity NVARCHAR(MAX) = ''
		
		WHILE @@FETCH_STATUS = 0
		BEGIN

			IF (@DisplayVerification = 1)
			BEGIN
				DECLARE @VerificationTimeLogActivity NVARCHAR(MAX)
				SELECT @VerificationTimeLogActivity = 
					[Description]
				FROM 
					[dbo].[TimeLogActivity]
				WHERE 
					[Id] = @TimeLogActivityId
				IF @VerificationTimeLogActivity <> @VerificationLastTimeLogActivity
				BEGIN
					PRINT 'Activity: ' + @VerificationTimeLogActivity
					PRINT 'Allocate Minutes: ' + CAST((@RedistributedSeconds / 60) AS NVARCHAR(MAX))
					PRINT 'Target Service Tags: '
				END
				SET @VerificationLastTimeLogActivity = @VerificationTimeLogActivity
				PRINT '    ' + CAST(@TargetServiceTagNumber AS NVARCHAR(10))
			END

			-------------------------------------------------------------------------------
			-- Insert new time log record.

			-- Clear ranges table variable.
			DELETE
			FROM
				@TimeLogRanges
			
			-- Populate ranges table variable with a full set of possible target time log ranges.
			-- Each range is, in length, the number of seconds to be redistributed.
			-- We begin at the start of the week then increment each possible range by one minute each time.
			;WITH minuteSequence AS
			(
				SELECT
					@StartOfWeekUtc AS [StartRange], 
					DATEADD(second, @RedistributedSeconds, @StartOfWeekUtc) AS [EndRange]
				UNION ALL
				SELECT
					DATEADD(minute, 1, [StartRange]),
					DATEADD(minute, 1, [EndRange])
				FROM 
					minuteSequence
				WHERE 
					DATEADD(second, @RedistributedSeconds, [StartRange]) < DATEADD(week, 1, @StartOfWeekUtc)
			)
			INSERT INTO
				@TimeLogRanges (
				[StartRangeUtc],
				[EndRangeUtc]
				)
			SELECT
				[StartRange], 
				[EndRange]
			FROM
				minuteSequence
			OPTION (MAXRECURSION 0)

			DECLARE @NewTimeLogId UNIQUEIDENTIFIER = NEWID()
			DECLARE @NewTimeLogStartDateUtc DATETIME
			DECLARE @NewTimeLogEndDateUtc DATETIME

			-- We now insert a new time log for each target service tag.
			-- We select the first available time log range, within the specified hours,
			-- and where there are currently no overlapping time logs for that employee.
			INSERT INTO [dbo].[Timelog] (
				[Id],
				[EmployeeId],
				[TimeLogActivityId],
				[EquipmentId],
				[Section],
				[StartDateUtc],
				[EndDateUtc]
				)
			SELECT TOP 1
				@NewTimeLogId,
				@EmployeeId,
				@TimeLogActivityId,
				@TargetEquipmentId,
				NULL,
				[StartRangeUtc],
				[EndRangeUtc]
			FROM 
				@TimeLogRanges
			WHERE
				DATEPART(hour, [StartRangeUtc]) >= @TimeRangeHourStart
				AND DATEPART(hour, [EndRangeUtc]) < @TimeRangeHourEnd
				AND NOT EXISTS (
					SELECT
						tl.[Id]
					FROM
						[dbo].[Timelog] tl
					WHERE
						tl.[EmployeeId] = @EmployeeId
					AND (
						(tl.[StartDateUtc] >= [StartRangeUtc] AND tl.[StartDateUtc] <= [EndRangeUtc])
						OR (tl.[EndDateUtc] >= [StartRangeUtc] AND tl.[EndDateUtc] <= [EndRangeUtc])
						)
					)
			ORDER BY
				[StartRangeUtc]

			IF (@DisplayVerification = 1)
			BEGIN
				SELECT @NewTimeLogStartDateUtc = 
					[StartDateUtc]
				FROM
					[dbo].[Timelog]
				WHERE
					[Id] = @NewTimeLogId
				SELECT @NewTimeLogEndDateUtc = 
					[EndDateUtc]
				FROM
					[dbo].[Timelog]
				WHERE
					[Id] = @NewTimeLogId
				PRINT '        Start: ' + CONVERT(NVARCHAR, @NewTimeLogStartDateUtc, 0)
				PRINT '          End: ' + CONVERT(NVARCHAR, @NewTimeLogEndDateUtc, 0)
			END
			------------------------------------------------------------------------

			FETCH NEXT FROM cursor_target_service_tag_activity_seconds INTO 
				@TargetServiceTagNumber,
				@TargetEquipmentId,
				@TimeLogActivityId,
				@RedistributedSeconds

		END

		CLOSE cursor_target_service_tag_activity_seconds
		DEALLOCATE cursor_target_service_tag_activity_seconds

		FETCH NEXT FROM cursor_employee_week INTO 
			@EmployeeId,
			@EmployeeName,
			@StartOfWeekUtc

    END

	CLOSE cursor_employee_week
	DEALLOCATE cursor_employee_week

	-------------------------------------------------------------------------------
	-- Verification (After).

	IF (@DisplayVerification = 1)
	BEGIN
		-- Total count of hours by employee.
		SELECT 
			[EmployeeName], 
			SUM([Seconds])
		FROM (
			SELECT 
				emp.[EmployeeName], 
				DATEDIFF(second, t.[StartDateUtc], t.[EndDateUtc]) AS [Seconds]
			FROM
				[dbo].[Timelog] t 
				INNER JOIN [dbo].[Employees] emp ON t.[EmployeeId] = emp.[EmployeeID] 
				INNER JOIN [dbo].[Equipment] e ON t.[EquipmentId] = e.[Id]
				INNER JOIN [dbo].[t2_prodsched] ps ON e.[ProductionSchedule_id] = ps.[PS_id] 
				INNER JOIN [dbo].[qmf_tb] q ON ps.[PS_qmf_id] = q.[qmf_id]
				INNER JOIN [dbo].[TimeLogActivity] tla ON t.[TimeLogActivityId] = tla.[Id] 
				INNER JOIN [dbo].[WorksBook] w ON q.[qmf_JB_id] = w.[WorksID]
				INNER JOIN @EmployeeSourcePeriods esp ON emp.[EmployeeID] = esp.[EmployeeId]
			WHERE 
				t.[StartDateUtc] >= DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])))) 
				AND t.[EndDateUtc] <= DATEADD(ww, 1, DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])))))
			) sums
		GROUP BY 
			[EmployeeName] 
		ORDER BY 
			[EmployeeName]
		-- Time logs by employee.
		SELECT 
			emp.[EmployeeName], 
			tla.[Description], 
			t.[StartDateUtc], 
			t.[EndDateUtc], 
			DATEDIFF(second, t.[StartDateUtc], t.[EndDateUtc]),
			w.[WNumCount] AS [WO No]
		FROM
			[dbo].[Timelog] t 
			INNER JOIN [dbo].[Employees] emp ON t.[EmployeeId] = emp.[EmployeeID] 
			INNER JOIN [dbo].[Equipment] e ON t.[EquipmentId] = e.[Id]
			INNER JOIN [dbo].[t2_prodsched] ps ON e.[ProductionSchedule_id] = ps.[PS_id] 
			INNER JOIN [dbo].[qmf_tb] q ON ps.[PS_qmf_id] = q.[qmf_id]
			INNER JOIN [dbo].[TimeLogActivity] tla ON t.[TimeLogActivityId] = tla.[Id] 
			INNER JOIN [dbo].[WorksBook] w ON q.[qmf_JB_id] = w.[WorksID]
			INNER JOIN @EmployeeSourcePeriods esp ON emp.[EmployeeID] = esp.[EmployeeId]
		WHERE 
			t.[StartDateUtc] >= DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodStartDateTimeUtc])))) 
			AND t.[EndDateUtc] <= DATEADD(ww, 1, DATEADD(dd, 0, DATEDIFF(dd, 0, DATEADD(dd, 2 - DATEPART(dw, DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])), DATEADD(dd, -1, esp.[PeriodEndDateTimeUtc])))))
		ORDER BY 
			emp.[EmployeeName], t.[StartDateUtc]
	END	
	-------------------------------------------------------------------------------

IF (@Commit = 0)
BEGIN
    ROLLBACK TRANSACTION
    PRINT 'Transaction rolled back. Please set the @Commit flag.' 
END
ELSE 
BEGIN
    COMMIT TRANSACTION
    PRINT 'Transaction committed.'
END

SET NOCOUNT OFF
