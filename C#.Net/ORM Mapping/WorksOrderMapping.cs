using System;
using NHibernate.Mapping.ByCode;
using NHibernate.Mapping.ByCode.Conformist;
using NHibernate.Type;
using Vision.Api.DotNet.Domain.WorksOrders;

namespace Vision.Api.DotNet.Domain.NHibernate.Mapping.WorksOrders
{
    public class WorksOrderMapping : ClassMapping<WorksOrder>
    {
        public WorksOrderMapping()
        {
            Table("WorksBook");

            var totalValueFormula = "(SELECT v.TotalValue FROM WorksOrder_TotalValue v WHERE v.WorksOrderId = WorksID)";
            var netValueFormula = "(SELECT v.DiscountedValue FROM WorksOrder_DiscountedValue v WHERE v.WorksOrderId = WorksID)";

			// Formula definitions.
			
            var invoicedAmountFormula = @"(SELECT COALESCE(SUM(_il.[Amount]), 0)
		                                                            FROM
			                                                            dbo.[InvoiceLine] _il
			                                                            INNER JOIN
			                                                            dbo.[Invoice] _i ON _il.[Invoice_id] = _i.[Id]
			                                                            INNER JOIN
			                                                            dbo.[InvoiceStatus] _is ON _i.[Status_Id] = _is.[Id]
								                                                             AND
								                                                             _is.[Name] = 'Sent To Client'
			                                                            INNER JOIN
			                                                            dbo.[qmf_tb] _qmf ON _il.[QMF_id] = _qmf.[qmf_id]
								                                                             AND
								                                                             _qmf.[qmf_JB_id] = [WorksID])";

            var certifiedAmountFormula = @"(SELECT COALESCE(SUM(_ip.[InvoiceAmount]), 0)
		                                                            FROM
			                                                            dbo.[Invoice] _ip
			                                                            INNER JOIN
			                                                            dbo.[InvoiceStatus] _ips ON _ip.[Status_Id] = _ips.[Id]
								                                                             AND
								                                                             _ips.[Name] = 'Sent To Client'
			                                                            INNER JOIN
			                                                            dbo.[PayCertificate] _p ON _ip.[PayCertificate_id] = _p.[Id]
								                                                             AND
								                                                             _p.[WorksID] = [WorksID])";

            var appliedForAmountFormula = @"(SELECT COALESCE(SUM(_al.[Amount]), 0)
		                                                            FROM
			                                                            dbo.[ApplicationLine] _al
			                                                            INNER JOIN
			                                                            dbo.[Application] _a ON _al.[Application_id] = _a.[Id]
			                                                            INNER JOIN
			                                                            dbo.[ApplicationStatus] _as ON _a.[Status_Id] = _as.[Id]
								                                                             AND
								                                                             _as.[Name] = 'Sent To Client'
			                                                            INNER JOIN
			                                                            dbo.[qmf_tb] _qmf ON _al.[QMF_id] = _qmf.[qmf_id]
								                                                             AND
								                                                             _qmf.[qmf_JB_id] = [WorksID])";
																							 
            var retentionAmountFormula = @"(SELECT (SELECT COALESCE(SUM(CASE WHEN _it.[Name] = 'Credit Note' THEN (0 - _il.[RetentionAmount]) ELSE _il.[RetentionAmount] END), 0)
		                                                            FROM
			                                                            dbo.[InvoiceLine] _il
			                                                            INNER JOIN
			                                                            dbo.[Invoice] _i ON _il.[Invoice_id] = _i.[Id]
			                                                            INNER JOIN
			                                                            dbo.[InvoiceType] _it ON _i.[InvoiceType_Id] = _it.[Id]
			                                                            INNER JOIN
			                                                            dbo.[InvoiceStatus] _is ON _i.[Status_Id] = _is.[Id]
								                                                             AND
								                                                             _is.[Name] = 'Sent To Client'
			                                                            INNER JOIN
			                                                            dbo.[qmf_tb] _qmf ON _il.[QMF_id] = _qmf.[qmf_id]
								                                                             AND
								                                                             _qmf.[qmf_JB_id] = [WorksID])
																	+
																	(SELECT COALESCE(SUM(CASE WHEN _ipt.[Name] = 'Credit Note' THEN (0 - _ip.[RetentionAmount]) ELSE _ip.[RetentionAmount] END), 0)
		                                                            FROM
			                                                            dbo.[Invoice] _ip
			                                                            INNER JOIN
			                                                            dbo.[InvoiceType] _ipt ON _ip.[InvoiceType_Id] = _ipt.[Id]
			                                                            INNER JOIN
			                                                            dbo.[InvoiceStatus] _ips ON _ip.[Status_Id] = _ips.[Id]
								                                                             AND
								                                                             _ips.[Name] = 'Sent To Client'
			                                                            INNER JOIN
			                                                            dbo.[PayCertificate] _p ON _ip.[PayCertificate_id] = _p.[Id]
								                                                             AND
								                                                             _p.[WorksID] = [WorksID]))";


            var homeCurrencyFormula = @"(
																	--HomeCurrencyValue
																	SELECT TOP 1
																		CASE _c.[Currency_id]
																			WHEN '2551C0AA-E9DD-4064-B1A6-7A2AC147FB22' THEN _qmfhc.[EuroToLocalValue]
																			WHEN 'B6D6AF18-F7C3-4A6A-BA16-46D41BDCB663' THEN _qmfhc.[GBPToLocalValue]
																			WHEN 'B81AE81A-13D5-40EF-9453-55A18A86C229' THEN _qmfhc.[USDToLocalValue]
																		END
																	FROM
																		dbo.[QMFHomeCurrency] _qmfhc
																		INNER JOIN
																		dbo.[qmf_tb] _b ON _b.[qmf_JB_id] = WorksID
																		INNER JOIN
																		dbo.[Clients] _c ON ResponsibleUnit = _c.[SapOrgStructureCode]
																	WHERE
																		_qmfhc.[QMFId] = _b.[qmf_id]
																	ORDER BY
																		_qmfhc.[CreatedDateTimeUtc] DESC
																	)";
																							 
			// Id property.
			
            Id(x => x.Id, map =>
            {
                map.Generator(Generators.Identity);
                map.Column("WorksID");
            });

			// Properties.

            Property(x => x.WNumber, map => map.Column("WNumber"));
            Property(x => x.WoNumber, map => map.Column("WNumCount"));
            Property(x => x.SNumber, map => map.Column("WorksSNum"));
            Property(x => x.ERPClientId, map => map.Column("ERPClientId"));
            Property(x => x.ERPProjectId, map => map.Column("ERPProjectId"));
            Property(x => x.OrderDate, map => map.Column("WorksDateReceived"));
            Property(x => x.ProjectName, map => map.Column("Works"));
            Property(x => x.Status, map => map.Column("WorksStatus"));
            Property(x => x.ClientOrderReference, map => map.Column("ClientOrderReference"));
            Property(x => x.ResponsibleUnit, map => map.Column("ResponsibleUnit"));
            Property(x => x.InvoicingNotes, map => map.Column("InvoicingNotes"));
            Property(x => x.ExchangeRateAtTimeOfOrder, map => map.Column("ExchangeRateAtTimeOfOrder"));
            Property(x => x.RetentionPercentage, map => map.Column("WorksRetention"));
            Property(x => x.AllocatedToProjectManagerDate, map => map.Column("AllocatedToProjectManagerDate"));
            Property(x => x.ApplicationScheduleContact, map => map.Column("ApplicationScheduleContact"));
            Property(x => x.ContractTermsAgreedNote, map => map.Column("ContractTermsAgreedNote"));
            Property(x => x.LiquidatedDamagesPerWeek, map => map.Column("LiquidatedDamagesPerWeek"));
            Property(x => x.LiquidatedDamagesCap, map => map.Column("LiquidatedDamagesCap"));
            Property(x => x.DoNotProceed, map => map.Column("DoNotProceed"));
            Property(x => x.PhotographyNotAllowedOnSite, map => map.Column("PhotographyNotAllowedOnSite"));

            Property(x => x.TotalValue, map => map.Formula(totalValueFormula));
            Property(x => x.DiscountedValue, map => map.Formula(netValueFormula));
            Property(x => x.InvoicedAmount, map => map.Formula(invoicedAmountFormula));
            Property(x => x.AppliedForAmount, map => map.Formula(appliedForAmountFormula));
            Property(x => x.CertifiedAmount, map => map.Formula(certifiedAmountFormula));
			Property(x => x.RetentionAmount, map => map.Formula(retentionAmountFormula));
            Property(x => x.HomeCurrencyValue, map => map.Formula(homeCurrencyFormula));
            Property(x => x.ApplicationRequiredAmount, map => map.Formula(string.Format("{0} - {1}", netValueFormula, appliedForAmountFormula)));
            Property(x => x.InvoiceRequiredAmount, map => map.Formula(string.Format("{0} - {1} - {2}", netValueFormula, invoicedAmountFormula, certifiedAmountFormula)));
            Property(x => x.PayOnApplicationNetAmount, map => map.Formula(GetNetValue(Types.InvoicingTerm.InvoicingTerms.PayOnApplication.Id)));
            Property(x => x.MilestoneBillingNetAmount, map => map.Formula(GetNetValue(Types.InvoicingTerm.InvoicingTerms.MilestoneBilling.Id)));
            Property(x => x.InvoiceOnPurchaseOrderNetAmount, map => map.Formula(GetNetValue(Types.InvoicingTerm.InvoicingTerms.InvoiceOnPurchaseOrder.Id)));
            Property(x => x.MilestoneBillingInvoicedAmount, map => map.Formula(GetInvoicedValue(Types.InvoicingTerm.InvoicingTerms.MilestoneBilling.Id)));
            Property(x => x.InvoiceOnPurchaseOrderInvoicedAmount, map => map.Formula(GetInvoicedValue(Types.InvoicingTerm.InvoicingTerms.InvoiceOnPurchaseOrder.Id)));
            Property(x => x.ParentId, map => map.Formula("(SELECT TOP 1 e.EstimateID FROM EstimateBook e WHERE e.EstimateMarketSectorID = WorksMarketSectorID AND e.WorksOrder_id = WorksID ORDER BY e.EstimateDateReceived DESC)"));
            Property(x => x.EquipmentCount, map => map.Formula("(SELECT COUNT(e.Id) FROM Equipment e WHERE e.WorksOrder_id = WorksID)"));
            Property(x => x.InvoiceCount, map => map.Formula("( SELECT COUNT(DISTINCT ni.Id) FROM Invoice ni INNER JOIN InvoiceLine nl ON ni.Id = nl.Invoice_id INNER JOIN qmf_tb nq ON nl.QMF_id = nq.qmf_id WHERE nq.qmf_jb_id = WorksId )"));
            Property(x => x.WipValue, map => map.Formula("(SELECT v.WipValue FROM WorksOrder_WipValue v WHERE v.WorksOrderId = WorksID)"));
            Property(x => x.Wip, map => map.Formula("(SELECT v.Wip FROM WorksOrder_Wip v WHERE v.WorksOrderId = WorksID)"));
            Property(x => x.AllocatedAmount, map => map.Formula("(SELECT SUM(v.AllocatedAmount) FROM Productionschedule_AllocatedAmount v INNER JOIN qmf_tb q ON v.qmf_id = q.qmf_id WHERE q.qmf_JB_id = WorksID)"));

            Property(x => x.PracticalCompletionDate, map =>
            {
                map.Column("PracticalCompletionDate");
                map.Type<UtcDateTimeType>();
            });

			// Many To One.
			
            ManyToOne(x => x.ParentWorksOrder, map => map.Column("ParentWorksOrder_Id"));
            ManyToOne(x => x.MarketSector, map => map.Column("WorksMarketSectorID"));
            ManyToOne(x => x.Sector, map => map.Column("Sector_id"));
            ManyToOne(x => x.EndUser, map => map.Column("WorksEndUser"));
            ManyToOne(x => x.FieldSales, map => map.Column("WorksEngineerID"));
            ManyToOne(x => x.Estimator, map => map.Column("WorksEstimator"));
            ManyToOne(x => x.ProjectManager, map => map.Column("WorksManagerID"));
            ManyToOne(x => x.SupportingManager, map => map.Column("WorksSupportingManagerID"));
            ManyToOne(x => x.ApplicationEngineer, map => map.Column("ApplicationEngineer_id"));
            ManyToOne(x => x.Country, map => map.Column("Region_id"));
            ManyToOne(x => x.Currency, map => map.Column("Currency_id"));
            ManyToOne(x => x.ContractForm, map => map.Column("ContractForm_id"));
            ManyToOne(x => x.ThirdPartySecurity, map => map.Column("ThirdPartySecurity_id"));
            ManyToOne(x => x.ContractTermsAgreedAnswer, map => map.Column("ContractTermsAgreedAnswer_id"));
            ManyToOne(x => x.LiquidatedDamagesAnswer, map => map.Column("LiquidatedDamagesAnswer_id"));
            ManyToOne(x => x.SAPStatus, map => map.Column("WorksOrderSAPStatus_Id"));

            ManyToOne(x => x.Client, map => map.Formula("(SELECT lwc.LinkWorksClientClientID from LinkWorksClient lwc where lwc.LinkWorksClientWorksID = WorksID)"));

            ManyToOne(x => x.ResponsibleUnitOrganisation, map => map.Formula(@"(
                SELECT TOP 1
	                respUnit.[ClientID]
                FROM
	                dbo.[Clients] respUnit
                WHERE
	                respUnit.[SapOrgStructureCode] = [ResponsibleUnit]
	            )"));
				
			// Sets.

            Set(x => x.ChildWorksOrders, map =>
            {
                map.Key(km => km.Column("ParentWorksOrder_Id"));
            }, action => action.OneToMany());

            Set(x => x.Branches, mapper =>
            {
                mapper.Table("LinkWorksEndUser");
                mapper.Key(k => k.Column("LinkWorksClientWorksID"));
                mapper.Lazy(CollectionLazy.Extra);
            }, relation => relation.ManyToMany(m => m.Column("LinkWorksClientClientID")));

            Set(x => x.Equipment, map =>
            {
                map.Inverse(true);
                map.Key(km => km.Column("WorksOrder_id"));
            }, action => action.OneToMany());

            Set(x => x.Qmfs, map =>
            {
                map.Inverse(true);
                map.Key(km => km.Column("qmf_jb_id"));
            }, action => action.OneToMany());

            Set(x => x.InvoicingApplicationSchedules, map =>
            {
                map.Inverse(true);
                map.Key(km => km.Column("WorksOrder_Id"));
            }, action => action.OneToMany());

            Set(x => x.WorksBookGrossMargins, map =>
            {
                map.Inverse(true);
                map.Key(km => km.Column("WorksBook_id"));
            }, action => action.OneToMany());

            Set(x => x.Estimates, map =>
            {
                map.Key(km => km.Column("WorksOrder_id"));
            }, action => action.OneToMany());

            Set(x => x.SalesAdditions, map =>
            {
                map.Key(km => km.Column("WorksOrderId"));
            }, action => action.OneToMany());

            Set(x => x.PayCertificates, map =>
            {
                map.Key(km => km.Column("WorksID"));
            }, action => action.OneToMany());
        }

        /// <summary>
        /// Return the Net Value formula for the requested invoicing term.
        /// </summary>
        /// <param name="invoicingTerm"></param>
        /// <returns></returns>
        private static string GetNetValue(Guid invoicingTerm)
        {
            return $@"(SELECT
	                       COALESCE(SUM(q.qmf_100_per_value - ((q.qmf_100_per_value * q.qmf_discount_percent) / 100)), 0)
                       FROM
	                       dbo.[qmf_tb] q
                       WHERE
	                       q.[qmf_JB_id] = [WorksID]
                           AND
                           q.[InvoicingTerm_Id] = '{invoicingTerm}')";
        }

        /// <summary>
        /// Return the remaining value formula for the requested invoicing term.
        /// </summary>
        /// <param name="invoicingTerm"></param>
        /// <returns></returns>
        private static string GetInvoicedValue(Guid invoicingTerm)
        {
            return $@"(SELECT
                            COALESCE(SUM(_il.[Amount]), 0)
		               FROM
			               dbo.[InvoiceLine] _il
			               INNER JOIN
			               dbo.[Invoice] _i ON _il.[Invoice_id] = _i.[Id]
			               INNER JOIN
			               dbo.[InvoiceStatus] _is ON _i.[Status_Id] = _is.[Id]
							                 AND
							                 _is.[Name] = 'Sent To Client'
			               INNER JOIN
			               dbo.[qmf_tb] _qmf ON _il.[QMF_id] = _qmf.[qmf_id]
							                 AND
							                 _qmf.[qmf_JB_id] = [WorksID]
                                             AND
                                             _qmf.[InvoicingTerm_Id] = '{invoicingTerm}')";
        }
    }
}