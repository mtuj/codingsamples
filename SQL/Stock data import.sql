-------------------------------------------------------------------------------
-- Stores Stock Management Excel Import
-- Stage		2
-- Action		Import - Castle Mills Ibar
-- Author		Mark Jackson
-- Created		25/09/2018
-- Copyright © 2018, Anord-Mardix Ltd, All Rights Reserved
-------------------------------------------------------------------------------

SET NOCOUNT ON

-------------------------------------------------------------------------------
-- This article details the steps required to set up the OLE DB provider required to directly query an Excel spreadsheet using T-SQL
-- http://sqlwithmanoj.wordpress.com/tag/sp_addlinkedserver/
--
-- This forum post shows how to install the Access Database Engine for 64-bit SQL Server with 32-bit MS Office (you will need to use the /passive flag)
-- (You may also need to reinstall this if the import spreadsheet stops working or hangs at any point)
-- http://stackoverflow.com/questions/2899201/microsoft-ace-oledb-12-0-64x-sql-server-and-86x-office
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Execution options
-------------------------------------------------------------------------------

DECLARE @ClearTable BIT = 1		-- Clear down temporary data table prior to updating

-------------------------------------------------------------------------------
-- User-defined variables
-------------------------------------------------------------------------------

DECLARE @SiteTown NVARCHAR(4000) = 'Kendal'
DECLARE @SiteName NVARCHAR(4000) = 'Castle Mills (IBAR)'
----> Change the below path to wherever the source file is copied to on MXCOLOSSUS
DECLARE @ImportDirectory NVARCHAR(4000) = 'D:\Vision\Stock.Management\documentation\Data Setup\Data source'
DECLARE @ImportFilename NVARCHAR(4000) = 'SAP Prices and Data.xlsx'
DECLARE @SuppliersWorksheet NVARCHAR(4000) = 'Suppliers'
DECLARE @ImportWorksheet NVARCHAR(4000) = 'Ibar Kendal Reimport'

-------------------------------------------------------------------------------
-- System variables
-------------------------------------------------------------------------------

DECLARE @CmdShell NVARCHAR(4000)
DECLARE @Sql NVARCHAR(MAX)
DECLARE @FilePath NVARCHAR(4000)
DECLARE @Worksheet NVARCHAR(255)
DECLARE @Column NVARCHAR(4000)
DECLARE @LinkedServer NVARCHAR(4000)
DECLARE @Count INT

DECLARE @ordLocation INT = 1
DECLARE @ordSupplier INT = 2
DECLARE @ordPartNumber INT = 3
DECLARE @ordProductDescription INT = 4
DECLARE @ordQuantity INT = 5
DECLARE @ordPrice INT = 6
DECLARE @ordDateLastPurchased INT = 7
DECLARE @ordSuppliersId INT = 1
DECLARE @ordSuppliersName INT = 2

DECLARE @colLocation NVARCHAR(255)
DECLARE @colSupplier NVARCHAR(255)
DECLARE @colPartNumber NVARCHAR(255)
DECLARE @colProductDescription NVARCHAR(255)
DECLARE @colQuantity NVARCHAR(255)
DECLARE @colPrice NVARCHAR(255)
DECLARE @colDateLastPurchased NVARCHAR(255)
DECLARE @colSuppliersId NVARCHAR(255)
DECLARE @colSuppliersName NVARCHAR(255)

-------------------------------------------------------------------------------
-- Create temporary tables
-------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Worksheets') IS NOT NULL
BEGIN
	DROP TABLE #Worksheets
END
CREATE TABLE #Worksheets (
	TABLE_CAT NVARCHAR(MAX)
	,TABLE_SCHEM NVARCHAR(MAX)
	,TABLE_NAME NVARCHAR(MAX)
	,TABLE_TYPE NVARCHAR(32)
	,REMARKS NVARCHAR(254)
)

IF OBJECT_ID('tempdb..#Columns') IS NOT NULL
BEGIN
	DROP TABLE #Columns
END
CREATE TABLE #Columns (
	TABLE_CAT NVARCHAR(MAX)
	,TABLE_SCHEM NVARCHAR(MAX)
	,TABLE_NAME NVARCHAR(MAX)
	,COLUMN_NAME NVARCHAR(MAX)
	,DATA_TYPE SMALLINT
	,TYPE_NAME NVARCHAR(13)
	,COLUMN_SIZE INT
	,BUFFER_LENGTH INT
	,DECIMAL_DIGITS SMALLINT
	,NUM_PREC_RADIX SMALLINT
	,NULLABLE SMALLINT
	,REMARKS NVARCHAR(254)
	,COLUMN_DEF NVARCHAR(254)
	,SQL_DATA_TYPE SMALLINT
	,SQL_DATETIME_SUB SMALLINT
	,CHAR_OCTET_LENGTH INT
	,ORDINAL_POSITION INT
	,IS_NULLABLE NVARCHAR(254)
	,SS_DATA_TYPE TINYINT
)

IF OBJECT_ID('tempdb..#Suppliers') IS NOT NULL
BEGIN
	DROP TABLE #Suppliers
END
CREATE TABLE #Suppliers (
	[Id] NVARCHAR(255)
	,[Name] NVARCHAR(255)
)

IF OBJECT_ID('tempdb..#Data') IS NOT NULL
BEGIN
	DROP TABLE #Data
END
CREATE TABLE #Data (
	[Location] NVARCHAR(255)
	,[Supplier] NVARCHAR(255)
	,[PartNumber] NVARCHAR(255)
	,[ProductDescription] NVARCHAR(255)
	,[Quantity] NVARCHAR(255)
	,[Price] NVARCHAR(255)
	,[DateLastPurchased] DATETIME
)

-------------------------------------------------------------------------------
-- Add linked server for spreadsheet
-------------------------------------------------------------------------------
		
SET @LinkedServer = N'srvExcelImport' + @ImportFilename
-- Strip unwanted characters
WHILE PATINDEX('%[^A-Za-z0-9]%', @LinkedServer) > 0
SET @LinkedServer = STUFF(@LinkedServer, PATINDEX('%[^A-Za-z0-9]%', @LinkedServer), 1, '')

IF EXISTS(SELECT * FROM sys.servers WHERE name = @LinkedServer)
BEGIN
	EXEC sp_dropserver @LinkedServer, 'droplogins'
END

SET @FilePath = @ImportDirectory + N'\' + @ImportFilename
EXEC sp_addLinkedServer
	@server= @LinkedServer,
	@srvproduct = N'Excel',
	@provider = N'Microsoft.ACE.OLEDB.12.0',
	@datasrc = @FilePath,
	@provstr = N'Excel 12.0; HDR=Yes; IMEX=1; TypeGuessRows=0';

PRINT 'Created linked server for [' + @FilePath + ']'
PRINT ''

-------------------------------------------------------------------------------
-- SUPPLIERS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Get suppliers worksheet
-------------------------------------------------------------------------------

DELETE FROM #Worksheets
INSERT INTO #Worksheets EXEC sp_tables_ex @LinkedServer
SELECT @Worksheet = TABLE_NAME FROM #Worksheets WHERE TABLE_NAME LIKE '%' + @SuppliersWorksheet + '%' AND TABLE_NAME NOT LIKE '%FilterDatabase%'

-------------------------------------------------------------------------------
-- Get suppliers list of columns
-------------------------------------------------------------------------------

DELETE FROM #Columns
INSERT INTO #Columns EXEC sp_columns_ex @LinkedServer, @Worksheet

-------------------------------------------------------------------------------
-- Import suppliers data into temporary table
-------------------------------------------------------------------------------

SELECT @colSuppliersId = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordSuppliersId
SELECT @colSuppliersName = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordSuppliersName

SET @Sql = 
	N'INSERT INTO #Suppliers ([Id], [Name]) ' + 
	'SELECT LTRIM(RTRIM([' + @colSuppliersId + '])), LTRIM(RTRIM([' + @colSuppliersName + '])) '
	+ 'FROM ' + @LinkedServer + '...[' + @Worksheet  + N'] '
	+ 'WHERE NOT ([' + @colSuppliersId + '] IS NULL AND [' + @colSuppliersName + '] IS NULL)'
EXECUTE sp_executesql @Sql

-------------------------------------------------------------------------------
-- IMPORT
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Get import worksheet
-------------------------------------------------------------------------------

DELETE FROM #Worksheets
INSERT INTO #Worksheets EXEC sp_tables_ex @LinkedServer
SELECT @Worksheet = TABLE_NAME FROM #Worksheets WHERE TABLE_NAME LIKE '%' + @ImportWorksheet + '%' AND TABLE_NAME NOT LIKE '%FilterDatabase%'

-------------------------------------------------------------------------------
-- Get import list of columns
-------------------------------------------------------------------------------

DELETE FROM #Columns
INSERT INTO #Columns EXEC sp_columns_ex @LinkedServer, @Worksheet

-------------------------------------------------------------------------------
-- Import import data into temporary table
-------------------------------------------------------------------------------

SELECT @colLocation = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordLocation
SELECT @colSupplier = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordSupplier
SELECT @colPartNumber = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordPartNumber
SELECT @colProductDescription = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordProductDescription
SELECT @colQuantity = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordQuantity
SELECT @colPrice = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordPrice
SELECT @colDateLastPurchased = COLUMN_NAME FROM #Columns WHERE ORDINAL_POSITION = @ordDateLastPurchased

SET @Sql = 
	N'INSERT INTO #Data ([Location], [Supplier], [PartNumber], [ProductDescription], [Quantity], [Price], [DateLastPurchased]) ' + 
	'SELECT LTRIM(RTRIM([' + @colLocation + '])), LTRIM(RTRIM([' + @colSupplier + '])), LTRIM(RTRIM([' + @colPartNumber + '])), LTRIM(RTRIM([' + @colProductDescription + '])), LTRIM(RTRIM([' + @colQuantity + '])), LTRIM(RTRIM([' + @colPrice + '])), LTRIM(RTRIM([' + @colDateLastPurchased + '])) '
	+ 'FROM ' + @LinkedServer + '...[' + @Worksheet  + N'] '
	+ 'WHERE NOT ([' + @colPartNumber + '] IS NULL AND [' + @colProductDescription + '] IS NULL)'
EXECUTE sp_executesql @Sql

-------------------------------------------------------------------------------
-- Delete previous data
-------------------------------------------------------------------------------

DELETE
	qc
FROM
	[dbo].[StockQuantityChange] qc
	INNER JOIN [dbo].[StoresLocation] sl ON qc.[StoresLocation_id] = sl.[Id]
WHERE
	sl.[Group] IN ('AA', 'AB', 'AC')
	AND qc.[QuantityChangedDateTimeUtc] < '2018-11-27 00:00:00.000'

DELETE
	cc
FROM
	[dbo].[StockCycleCount] cc
	INNER JOIN [dbo].[StoresLocation] sl ON cc.[StoresLocation_id] = sl.[Id]
WHERE
	sl.[Group] IN ('AA', 'AB', 'AC')
	AND cc.[QuantityVerifiedDateTimeUtc] < '2018-11-27 00:00:00.000'

DELETE
	fc
FROM
	[dbo].[StockFourWallCount] fc
	INNER JOIN [dbo].[StoresLocation] sl ON fc.[StoresLocation_id] = sl.[Id]
WHERE
	sl.[Group] IN ('AA', 'AB', 'AC')
	AND fc.[QuantityVerifiedDateTimeUtc] < '2018-11-27 00:00:00.000'

-------------------------------------------------------------------------------
-- Process data
-------------------------------------------------------------------------------

-- Clear down previous import
IF @ClearTable = 1
BEGIN
	
	DELETE FROM 
		[dbo].[StockManagementExcelImport] 
	WHERE 
		[ImportWorksheet] = @ImportWorksheet

END

-- Run import
INSERT INTO
	[dbo].[StockManagementExcelImport] (
		[SiteTown],
		[SiteName],
		[Group],
		[Bay],
		[Level],
		[Location],
		[Supplier],
		[PartNumber],
		[ProductDescription],
		[Quantity],
		[Price],
		[DateLastPurchased],
		[DateImported],
		[ImportWorksheet]
	)
SELECT
	@SiteTown,
	@SiteName,
	[dbo].[Split](d.[Location], '-', 0),
	[dbo].[Split](d.[Location], '-', 1),
	[dbo].[Split](d.[Location], '-', 2),
	[dbo].[Split](d.[Location], '-', 3),
	s.[Id],
	d.[PartNumber],
	d.[ProductDescription],
	d.[Quantity],
	d.[Price],
	d.[DateLastPurchased],
	GETDATE(),
	@ImportWorksheet
FROM
	#Data d
	LEFT JOIN #Suppliers s ON d.[Supplier] = s.[Name]

-------------------------------------------------------------------------------
-- Drop temporary tables
-------------------------------------------------------------------------------

DROP TABLE #Data
DROP TABLE #Suppliers
DROP TABLE #Columns
DROP TABLE #Worksheets

-------------------------------------------------------------------------------
-- Delete linked server for spreadsheet
-------------------------------------------------------------------------------
		
EXEC sp_dropserver @LinkedServer, 'droplogins'
		
PRINT 'Dropped linked server for [' + @FilePath + ']'
PRINT ''

SET NOCOUNT OFF
