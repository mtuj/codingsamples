SET XACT_ABORT ON
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET NOCOUNT ON
GO

DECLARE @Commit BIT;
SET @Commit = 0; -- Commit = 1, Don't Commit = 0.

BEGIN TRANSACTION

	DECLARE @TestSessionTypeIdIbarInstallationJointTest UNIQUEIDENTIFIER = '4FA4BE63-3462-42E4-9D01-CCD15774A15F'
	DECLARE @TestTypeIdIbarInstallationJointTest UNIQUEIDENTIFIER = '7FADAAE2-5830-435C-A0BD-9A710F2F0792'
	DECLARE @TestSessionTypeIdIbarInstallationTest UNIQUEIDENTIFIER = 'A97A59B6-24EC-4364-BA7B-BC55EB93C3E4'
	DECLARE @TestTypeIdSiteConnectionTest UNIQUEIDENTIFIER = '0F29ADB3-DA2C-4D95-9E1A-97021D5FA828'
	DECLARE @DocumentTypeIdTestDocumentTemplateIBARInstallationJointTestCertificate UNIQUEIDENTIFIER = '837D4C25-B4DD-4EB1-9381-4065D01D074B'
	DECLARE @DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate UNIQUEIDENTIFIER = 'D3A3F18F-9FDF-428D-BD39-85D2034680C1'
	DECLARE @DocumentTypeIdTestDocumentIBARInstallationTestCertificate UNIQUEIDENTIFIER = '78970E23-6208-407B-B34B-F3FD486A40B5'
	DECLARE @DocumentTypeTestSessionPhoto UNIQUEIDENTIFIER = 'D33DF4CF-66A9-45D0-8656-6ACB71ECC800'

	PRINT '---------------------------------------------------------------------'
	PRINT ' Backfill records in WorksBook table.								'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	UPDATE
		[dbo].[WorksBook] 
	SET
		[PhotographyNotAllowedOnSite] = 0

	PRINT '---------------------------------------------------------------------'
	PRINT ' Update records in ConductorConfiguration table.						'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	UPDATE [dbo].[ConductorConfiguration] SET [NumberOfBars] = 1 WHERE [Name] IN ('SP - L1', 'SP - L2', 'SP - L3')
	UPDATE [dbo].[ConductorConfiguration] SET [IsArchived] = 1 WHERE [Name] = 'TP&2N' AND [NumberOfBars] = 4

	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 1 WHERE [Name] = '2P&E'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'TP'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'TP&1.5N'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 1, [ConductorE] = 0 WHERE [Name] = 'TP&2N'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 1, [ConductorE] = 1 WHERE [Name] = 'TP&2N&E'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'TP&N'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 1 WHERE [Name] = 'TP&E'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 1 WHERE [Name] = 'TP&N&E'

	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 0, [ConductorL3] = 0, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'SP - L1'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 0, [ConductorL2] = 1, [ConductorL3] = 0, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'SP - L2'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 0, [ConductorL2] = 0, [ConductorL3] = 1, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'SP - L3'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 0, [ConductorL3] = 0, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'SP&N - L1'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 0, [ConductorL2] = 1, [ConductorL3] = 0, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'SP&N - L2'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 0, [ConductorL2] = 0, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'SP&N - L3'

	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 0, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'DP - L1 & L2'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 0, [ConductorL3] = 1, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'DP - L1 & L3'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 0, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 0, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'DP - L2 & L3'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 0, [ConductorN] = 1, [ConductorN2] = 1, [ConductorE] = 0 WHERE [Name] = 'DP&2N - L1 & L2'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 0, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 1, [ConductorE] = 0 WHERE [Name] = 'DP&2N - L1 & L3'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 0, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 1, [ConductorE] = 0 WHERE [Name] = 'DP&2N - L2 & L3'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 1, [ConductorL3] = 0, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'DP&N - L1 & L2'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 1, [ConductorL2] = 0, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'DP&N - L1 & L3'
	UPDATE [dbo].[ConductorConfiguration] SET [ConductorL1] = 0, [ConductorL2] = 1, [ConductorL3] = 1, [ConductorN] = 1, [ConductorN2] = 0, [ConductorE] = 0 WHERE [Name] = 'DP&N - L2 & L3'


	PRINT '---------------------------------------------------------------------'
	PRINT ' Set QMF 139_1 template records to be of type BLOB Document.			'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'
	UPDATE
		[dbo].[Document]
	SET
		[DocumentType_id] = 'C320DEF9-76D0-4020-A1BD-6338979A64A3'			-- BLOB Document
		WHERE [DocumentType_id] = 'FC29E3DE-3436-4C14-BFCF-88141B08A101'	-- IBAR Installation Test Certificate (Ductor/Torque Test), Test Session Document Template

	PRINT '---------------------------------------------------------------------'
	PRINT ' Delete QMF 139_1 test session document template document type.		'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	DELETE FROM
		[dbo].[DocumentType]
	WHERE
		[Id] = 'FC29E3DE-3436-4C14-BFCF-88141B08A101'						-- IBAR Installation Test Certificate (Ductor/Torque Test), Test Session Document Template

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add QMF 139_2 records to DocumentType table							'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	INSERT INTO [dbo].[DocumentType] (
			[Id]
           ,[Name]
           ,[QualityManagementSystemCode]
           ,[IsArchived]
           ,[DocumentTypeCategory_id]
           ,[AbbreviatedName]
		   )
     SELECT
           @DocumentTypeIdTestDocumentTemplateIBARInstallationJointTestCertificate,
           'IBAR Installation Joint Test Certificate',
           'QMF 139_2',
           0,
           '9578C240-F63D-48DD-813F-170F58968783', -- Test Document Template
           NULL
     UNION SELECT
           @DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate,
           'IBAR Installation Joint Test Certificate',
           'QMF 139_2',
           0,
           'C1735341-5625-441B-BDA3-6286EBA21B7B', -- Test Document
           NULL

	PRINT '---------------------------------------------------------------------'
	PRINT ' Backfill records in TestSessionType table.							'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	UPDATE
		[dbo].[TestSessionType] 
	SET
		[DisplayPhoto] = 0,
		[EquipmentLocationRequiredForPass] = 0

	PRINT '---------------------------------------------------------------------'
	PRINT ' Increment sort order of some test session types.					'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	UPDATE
		[dbo].[TestSessionType]
	SET
		[SortOrder] = [SortOrder] + 1
	WHERE
		[SortOrder] > 11

	PRINT '---------------------------------------------------------------------'
	PRINT ' Update IBAR Installation Test test session type.					'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	UPDATE
		[dbo].[TestSessionType]
	SET
		[DisplayAdditionalDocuments] = 0
	WHERE
		[Id] = @TestSessionTypeIdIbarInstallationTest

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add IBAR Installation Joint Test test session type.					'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	INSERT INTO [dbo].[TestSessionType] (
		[Id],
        [Name],
        [MasterDocumentType_Id],
        [RequiresWitness],
        [SortOrder],
        [AbbreviatedName],
        [RequiresBuildLocation],
        [SpecifyWitnessInName],
        [DisplayAdditionalDocuments],
        [DisplayVerification],
        [DisplayPduTypeSerialsRatings],
        [DisplayUnitRating],
        [DisplayElectricalSupplySystem],
        [DisplayLocation],
        [DisplayComments],
        [AllowCreateTests],
        [UpdateBuildStatusDuringTest],
        [UpdateCommissioningStatusDuringTest],
        [NetworkSubdirectoryMardix],
        [NetworkSubdirectoryWitness],
		[DisplayPhoto],
		[EquipmentLocationRequiredForPass]
		)
	SELECT
		@TestSessionTypeIdIbarInstallationJointTest,
		'IBAR Installation Joint Test',
		@DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate,
		1,
		12,
		NULL,
		0,
		0,
		0,
		0,
		0,
		1,
		0,
		0,
		1,
		0,
		0,
		0,
		'ScanSiteTCerts',
		'ScanSiteTCerts',
		1,
		1

	PRINT '---------------------------------------------------------------------'
	PRINT ' Update Site connection test test type.								'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	UPDATE
		[dbo].[TestType]
	SET
		[RequiresResult] = 0
	WHERE
		[Id] = @TestTypeIdSiteConnectionTest

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add IBAR Installation joint test test type.							'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	INSERT INTO [dbo].[TestType] (
		[Id],
        [Number],
        [Name],
        [EnforceInstrumentReference],
        [RequiresResult]
		)
	SELECT
		@TestTypeIdIbarInstallationJointTest,
        0,
        'IBAR installation joint test',
		0,
        1

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add IBAR Installation Joint Test test session join record.			'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	INSERT INTO [dbo].[TestSessionType_TestType_DocumentType_EquipmentType] (
		[TestSessionType_Id],
		[TestType_Id],
		[DocumentType_Id],
		[EquipmentType_Id],
		[HiddenNotApplicableWhenNoTemplate]
		)
	SELECT
		@TestSessionTypeIdIbarInstallationJointTest,
		@TestTypeIdIbarInstallationJointTest,
		@DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate,
        NULL,
		0

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add Test Session Photo document type.								'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	INSERT INTO [dbo].[DocumentType] (
		[Id],
		[Name],
		[QualityManagementSystemCode],
		[IsArchived],
		[DocumentTypeCategory_id],
		[AbbreviatedName]
		)
	SELECT
		@DocumentTypeTestSessionPhoto,
		'Test Session Photo',
		NULL,
		0,
		NULL,
		NULL

	PRINT '---------------------------------------------------------------------'
	PRINT ' Update Document Type Image Co-Ordinates for QMF 139.				'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	UPDATE
		[dbo].[DocumentTypeImageCoOrdinates]
	SET
		[OriginY] = 80,
		[PageNumber] = 2
	WHERE
		[DocumentType_id] = @DocumentTypeIdTestDocumentIBARInstallationTestCertificate

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add Document Type Image Co-Ordinates for QMF 139_2.					'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	INSERT INTO [dbo].[DocumentTypeImageCoOrdinates] (
		[DocumentType_id],
		[ImageDocumentType_id],
		[OriginX],
		[OriginY],
		[MaxWidth],
		[MaxHeight],
		[PageNumber]
		)
	SELECT
		@DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate,
		'91D6F309-BD9A-4206-AC23-57A8D5816D25',	-- Test Session Tester Signature
		239,
		85,
		75,
		26,
		1
	UNION
	SELECT
		@DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate,
		'8A0E8449-2E83-44B0-9115-078B6FD3342B',	-- Test Session Mardix Witness Signature
		404,
		85,
		130,
		26,
		1
	UNION
	SELECT
		@DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate,
		'188CC920-AA30-4529-9A87-D89816A713F8',	-- Test Session Client Witness Signature
		404,
		85,
		130,
		26,
		1
	UNION
	SELECT
		@DocumentTypeIdTestDocumentIBARInstallationJointTestCertificate,
		@DocumentTypeTestSessionPhoto,
		72,
		204,
		450,
		178,
		1

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
