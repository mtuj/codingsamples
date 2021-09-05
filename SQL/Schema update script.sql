SET XACT_ABORT ON
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET NOCOUNT ON
GO

DECLARE @Commit BIT;
SET @Commit = 0; -- Commit = 1, Don't Commit = 0.

BEGIN TRANSACTION

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add fields to WorksBook and WorksBook_audit tables.					'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	ALTER TABLE [dbo].[WorksBook] ADD [PhotographyNotAllowedOnSite] BIT
	ALTER TABLE [dbo].[WorksBook_audit] ADD [PhotographyNotAllowedOnSite] BIT

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add fields to ConductorConfiguration tables.						'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	ALTER TABLE [dbo].[ConductorConfiguration] ADD [ConductorL1] BIT
	ALTER TABLE [dbo].[ConductorConfiguration] ADD [ConductorL2] BIT
	ALTER TABLE [dbo].[ConductorConfiguration] ADD [ConductorL3] BIT
	ALTER TABLE [dbo].[ConductorConfiguration] ADD [ConductorN] BIT
	ALTER TABLE [dbo].[ConductorConfiguration] ADD [ConductorN2] BIT
	ALTER TABLE [dbo].[ConductorConfiguration] ADD [ConductorE] BIT

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add fields to EquipmentRatingProperty table.						'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	ALTER TABLE [dbo].[EquipmentRatingProperty] ADD [MaximumDuctorResistanceMicroOhms] FLOAT

	PRINT '---------------------------------------------------------------------'
	PRINT ' Add fields to TestSessionType table.								'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	ALTER TABLE [dbo].[TestSessionType] ADD [DisplayPhoto] BIT
	ALTER TABLE [dbo].[TestSessionType] ADD [EquipmentLocationRequiredForPass] BIT

	PRINT '---------------------------------------------------------------------'
	PRINT ' Rename DocumentTypeSignatureCoOrdinates field and table.			'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	EXEC sp_rename 'dbo.DocumentTypeSignatureCoOrdinates.SignatureDocumentType_id', 'ImageDocumentType_id', 'COLUMN'
	EXEC sp_rename 'dbo.DocumentTypeSignatureCoOrdinates', 'DocumentTypeImageCoOrdinates'

	PRINT '---------------------------------------------------------------------'
	PRINT ' Drop IbarInstallationTestMetadataDuctorTest table.					'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	ALTER TABLE [dbo].[IbarInstallationTestMetadataDuctorTest] DROP CONSTRAINT [FK_IbarInstallationTestMetadataDuctorTest_IbarInstallationTestMetadata]
	ALTER TABLE [dbo].[IbarInstallationTestMetadataDuctorTest] DROP CONSTRAINT [FK_IbarInstallationTestMetadataDuctorTest_Document]
	DROP TABLE [dbo].[IbarInstallationTestMetadataDuctorTest]

	PRINT '---------------------------------------------------------------------'
	PRINT ' Drop IbarInstallationTestMetadata table.							'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	DROP TABLE [dbo].[IbarInstallationTestMetadata]

	PRINT '---------------------------------------------------------------------'
	PRINT ' Create IbarInstallationTestMetadata table.							'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	CREATE TABLE [dbo].[IbarInstallationTestMetadata] (
		-- Core fields.
		[Id] [UNIQUEIDENTIFIER] NOT NULL,
		[TestSession_Id] [UNIQUEIDENTIFIER] NOT NULL,
		[Document_Id] [UNIQUEIDENTIFIER] NOT NULL,
		-- Visual Inspection Checks.
		[AdjoiningSectionsLevel] [BIT] NULL,
		[SupportBracketsInstalled] [BIT] NULL,
		[SupportBracketsFixingBoltsSecure] [BIT] NULL,
		[JointsInstalled] [BIT] NULL,
		[CoversSecurelyInstalled] [BIT] NULL,
		-- Ductor Test Instrument.
		[DuctorTestInstrumentIdNumber] [NVARCHAR](MAX) NULL,
		-- Insulation Resistance Test.
		[InsulationResistanceTestResultMegaOhmsPEToE] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsPEToN] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsPEToL1] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsPEToL2] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsPEToL3] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsEToN] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsEToL1] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsEToL2] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsEToL3] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsNToL1] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsNToL2] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsNToL3] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsL1ToL2] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsL2ToL3] [NVARCHAR](MAX) NULL,
		[InsulationResistanceTestResultMegaOhmsL3ToL1] [NVARCHAR](MAX) NULL,
		-- Insulation Resistance Test Instrument.
		[InsulationResistanceTestInstrumentIdNumber] [NVARCHAR](MAX) NULL,
		-- Comments.
		[Comments] [NVARCHAR](MAX) NULL,
	 CONSTRAINT [PK_IbarInstallationTestMetadata] PRIMARY KEY CLUSTERED 
	(
		[Id] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

	ALTER TABLE [dbo].[IbarInstallationTestMetadata] ADD CONSTRAINT [FK_IbarInstallationTestMetadata_TestSession] FOREIGN KEY([TestSession_Id]) REFERENCES [dbo].[TestSession] ([Id])
	ALTER TABLE [dbo].[IbarInstallationTestMetadata] ADD CONSTRAINT [FK_IbarInstallationTestMetadata_Document] FOREIGN KEY([Document_Id]) REFERENCES [dbo].[Document] ([Id])

	PRINT '---------------------------------------------------------------------'
	PRINT ' Create IbarInstallationTestMetadataContinuityRunDuctorTest table.	'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	CREATE TABLE [dbo].[IbarInstallationTestMetadataContinuityRunDuctorTest] (
		[Id] [UNIQUEIDENTIFIER] NOT NULL,
		[IbarInstallationTestMetadata_Id] [UNIQUEIDENTIFIER] NOT NULL,
		[TestFrom] [NVARCHAR](MAX) NULL,
		[TestTo] [NVARCHAR](MAX) NULL,
		[ConductorPair1] [NVARCHAR](MAX) NULL,
		[ConductorPair1LinkMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair1ResultMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair2] [NVARCHAR](MAX) NULL,
		[ConductorPair2LinkMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair2ResultMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair3] [NVARCHAR](MAX) NULL,
		[ConductorPair3LinkMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair3ResultMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair4] [NVARCHAR](MAX) NULL,
		[ConductorPair4LinkMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair4ResultMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair5] [NVARCHAR](MAX) NULL,
		[ConductorPair5LinkMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair5ResultMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair6] [NVARCHAR](MAX) NULL,
		[ConductorPair6LinkMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair6ResultMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair7] [NVARCHAR](MAX) NULL,
		[ConductorPair7LinkMilliOhms] [NVARCHAR](MAX) NULL,
		[ConductorPair7ResultMilliOhms] [NVARCHAR](MAX) NULL,
	 CONSTRAINT [PK_IbarInstallationTestMetadataContinuityRunDuctorTest] PRIMARY KEY CLUSTERED 
	(
		[Id] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

	ALTER TABLE [dbo].[IbarInstallationTestMetadataContinuityRunDuctorTest] ADD CONSTRAINT [FK_IbarInstallationTestMetadataContinuityRunDuctorTest_IbarInstallationTestMetadata] FOREIGN KEY([IbarInstallationTestMetadata_Id]) REFERENCES [dbo].[IbarInstallationTestMetadata] ([Id])

	PRINT '---------------------------------------------------------------------'
	PRINT ' Create IbarInstallationJointTestMetadata table.						'
	PRINT GETDATE()
	PRINT '---------------------------------------------------------------------'

	CREATE TABLE [dbo].[IbarInstallationJointTestMetadata] (
		[Id] [UNIQUEIDENTIFIER] NOT NULL,
		[TestSession_Id] [UNIQUEIDENTIFIER] NOT NULL,
		[Document_Id] [UNIQUEIDENTIFIER] NOT NULL,
		[BellevilleWashersSeated] [BIT] NULL,
		[NutOuterHeadsShearedOff] [BIT] NULL,
		[NutsMarked] [BIT] NULL,
		[CoversInstalled] [BIT] NULL,
		[BoltsTorqueChecked] [BIT] NULL,
		[TorqueWrenchIdNumber] [NVARCHAR](MAX) NULL,
		[DuctorResistanceMicroOhmsEarth] [NVARCHAR](max) NULL,
		[DuctorResistanceMicroOhmsNeutral] [NVARCHAR](max) NULL,
		[DuctorResistanceMicroOhmsNeutral2] [NVARCHAR](max) NULL,
		[DuctorResistanceMicroOhmsPhaseL1] [NVARCHAR](max) NULL,
		[DuctorResistanceMicroOhmsPhaseL2] [NVARCHAR](max) NULL,
		[DuctorResistanceMicroOhmsPhaseL3] [NVARCHAR](max) NULL,
		[DuctorTestInstrumentIdNumber] [NVARCHAR](MAX) NULL,
		[Comments] [NVARCHAR](MAX) NULL,
	CONSTRAINT [PK_IbarInstallationJointTestMetadata] PRIMARY KEY CLUSTERED 
	(
		[Id] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

	ALTER TABLE [dbo].[IbarInstallationJointTestMetadata] ADD CONSTRAINT [FK_IbarInstallationJointTestMetadata_TestSession] FOREIGN KEY([TestSession_Id]) REFERENCES [dbo].[TestSession] ([Id])
	ALTER TABLE [dbo].[IbarInstallationJointTestMetadata] ADD CONSTRAINT [FK_IbarInstallationJointTestMetadata_Document] FOREIGN KEY([Document_Id]) REFERENCES [dbo].[Document] ([Id])

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
