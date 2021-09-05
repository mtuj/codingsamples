using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using Vision.Api.DotNet.Builder.CQRS.Queries;
using Vision.Api.DotNet.Builder.CQRS.Queries.Production;
using Vision.Api.DotNet.Domain.Equipments;
using Vision.Api.DotNet.Domain.Production;

namespace Vision.Api.DotNet.Tests.Integration.Builder.IBARProduction.Production
{
    public class CreateProductionJobTests : TestBase
    {
        /// <summary>
        /// Quick test to ensure we get a different production definition back for each market sector
        /// </summary>
        [Test]
        public void ProductionDefinitionTest()
        {
            var responseIbar = ApiBuilder.Query(BearerToken)
                .Production()
                .ProductionDefinitions(new Dto.Queries.Production.ProductionDefinitions.Query.Query
                {
                    EquipmentTypeId = EquipmentTypeFlangeId,
                    MarketSectorId = Types.MarketSectorType.Types.IBAR.Id
                })
                .Execute();
            var productionDefinitionIbar = responseIbar.Data.ProductionDefinitions.FirstOrDefault(
                pd => pd.ConductorMaterial.Id == Types.ConductorMaterial.Types.Copper.Id && pd.Rating.Id == Types.EquipmentRating.Ratings.Rating2500.Id
                );

            var responseResinbar = ApiBuilder.Query(BearerToken)
                .Production()
                .ProductionDefinitions(new Dto.Queries.Production.ProductionDefinitions.Query.Query
                {
                    EquipmentTypeId = EquipmentTypeFlangeId,
                    MarketSectorId = Types.MarketSectorType.Types.Resinbar.Id
                })
                .Execute();
            var productionDefinitionResinbar = responseResinbar.Data.ProductionDefinitions.FirstOrDefault(
                pd => pd.ConductorMaterial.Id == Types.ConductorMaterial.Types.Copper.Id && pd.Rating.Id == Types.EquipmentRating.Ratings.Rating2500.Id
                );

            Assert.NotNull(productionDefinitionIbar);
            Assert.NotNull(productionDefinitionResinbar);
            Assert.AreNotEqual(productionDefinitionIbar.Id, productionDefinitionResinbar.Id);
        }

        /// <summary>
        /// Test to ensure we get a different set of steps for each market sector
        /// </summary>
        [Test]
        public void CanCreateProductionJobForDifferentMarketSectors()
        {
            Equipment component1; Equipment component2;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                component1 = CreateComponentOfType(session, Types.MarketSectorType.Types.IBAR.Id, EquipmentTypeFlangeId, "B01", null, Types.ConductorMaterial.Types.Copper.Id, new []{ 2500 }, null);
                component2 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeFlangeId, "B01", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 2500 }, null);
            }
            var components = new[] { component1, component2 };

            foreach (var component in components)
            {
                var productionJobId = CreateProductionJob(component);
                ProductionJobIds.Add(productionJobId);

                List<ProductionJobBuildStep> productionJobBuildSteps;
                using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
                {
                    ProductionJobBuildStep productionJobBuildStepAlias = null;
                    ProductionJobEquipment productionJobEquipmentAlias = null;
                    ProductionJob productionJobAlias = null;
                    EquipmentTypeProductionStepDefinition equipmentTypeProductionStepDefinitionAlias = null;
                    EquipmentTypeProductionDefinition equipmentTypeProductionDefinitionAlias = null;
                    ProductionDefinition productionDefinitionAlias = null;
                    ProductionStepDefinition productionStepDefinitionAlias = null;
                    ProductionStep productionStepAlias = null;
                    ProductionStageDefinition productionStageDefinitionAlias = null;
                    ProductionPart productionPartAlias = null;
                    productionJobBuildSteps = session.QueryOver(() => productionJobBuildStepAlias)
                            .JoinAlias(e => e.ProductionJobEquipment, () => productionJobEquipmentAlias)
                            .JoinAlias(() => productionJobEquipmentAlias.ProductionJob, () => productionJobAlias)
                            .JoinAlias(() => productionJobBuildStepAlias.EquipmentTypeProductionStepDefinition, () => equipmentTypeProductionStepDefinitionAlias)
                            .JoinAlias(() => equipmentTypeProductionStepDefinitionAlias.EquipmentTypeProductionDefinition, () => equipmentTypeProductionDefinitionAlias)
                            .JoinAlias(() => equipmentTypeProductionDefinitionAlias.ProductionDefinition, () => productionDefinitionAlias)
                            .JoinAlias(() => equipmentTypeProductionStepDefinitionAlias.ProductionStepDefinition, () => productionStepDefinitionAlias)
                            .JoinAlias(() => productionStepDefinitionAlias.Step, () => productionStepAlias)
                            .JoinAlias(() => productionStepDefinitionAlias.ProductionStageDefinition, () => productionStageDefinitionAlias)
                            .JoinAlias(() => productionStageDefinitionAlias.ProductionPart, () => productionPartAlias)
                            .Where(() => productionJobAlias.Id == productionJobId)
                            .Future<ProductionJobBuildStep>()
                            .ToList();
                }
                var productionDefinition = productionJobBuildSteps.First().EquipmentTypeProductionStepDefinition.EquipmentTypeProductionDefinition.ProductionDefinition;
                var productionStepIds = productionJobBuildSteps.Select(p => p.EquipmentTypeProductionStepDefinition)
                            .Select(e => e.ProductionStepDefinition)
                            .Select(sd => sd.Step)
                            .Select(s => s.Id)
                            .ToList();

                if (component.Id == component1.Id)
                {
                    Assert.AreEqual(Types.ProductionDefinition.Definitions.IbarConductorHousingPair.Id, productionDefinition.Id);
                    Assert.Contains(Types.ProductionStep.Steps.Cm.Id, productionStepIds);
                    Assert.That(productionStepIds, Has.No.Member(Types.ProductionStep.Steps.Kf.Id));
                }

                if (component.Id == component2.Id)
                {
                    Assert.AreEqual(Types.ProductionDefinition.Definitions.ResinbarConductor.Id, productionDefinition.Id);
                    Assert.Contains(Types.ProductionStep.Steps.Kf.Id, productionStepIds);
                    Assert.That(productionStepIds, Has.No.Member(Types.ProductionStep.Steps.Cm.Id));
                }
            }
        }

        /// <summary>
        /// Test to ensure Resinbar component only includes punch step when unit reference ends with 'H'
        /// </summary>
        [Test]
        public void IncludesPunchStepOnlyWhenUnitReferenceWhenEndsWithH()
        {
            Equipment component1; Equipment component2; Equipment component3; Equipment component4;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                component1 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeFlangeId, "B01", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 2500 }, null);
                component2 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeFlangeId, "B02", "", Types.ConductorMaterial.Types.Copper.Id, new[] { 2500 }, null);
                component3 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeFlangeId, "B03", "HG", Types.ConductorMaterial.Types.Copper.Id, new[] { 2500 }, null);
                component4 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeFlangeId, "B04", "GH", Types.ConductorMaterial.Types.Copper.Id, new[] { 2500 }, null);
            }
            var components = new[] { component1, component2, component3, component4 };

            foreach (var component in components)
            {
                var productionJobId = CreateProductionJob(component);
                ProductionJobIds.Add(productionJobId);

                List<ProductionJobBuildStep> productionJobBuildSteps;
                using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
                {
                    ProductionJobBuildStep productionJobBuildStepAlias = null;
                    ProductionJobEquipment productionJobEquipmentAlias = null;
                    ProductionJob productionJobAlias = null;
                    EquipmentTypeProductionStepDefinition equipmentTypeProductionStepDefinitionAlias = null;
                    EquipmentTypeProductionDefinition equipmentTypeProductionDefinitionAlias = null;
                    ProductionDefinition productionDefinitionAlias = null;
                    ProductionStepDefinition productionStepDefinitionAlias = null;
                    ProductionStep productionStepAlias = null;
                    ProductionStageDefinition productionStageDefinitionAlias = null;
                    ProductionPart productionPartAlias = null;
                    productionJobBuildSteps = session.QueryOver(() => productionJobBuildStepAlias)
                            .JoinAlias(e => e.ProductionJobEquipment, () => productionJobEquipmentAlias)
                            .JoinAlias(() => productionJobEquipmentAlias.ProductionJob, () => productionJobAlias)
                            .JoinAlias(() => productionJobBuildStepAlias.EquipmentTypeProductionStepDefinition, () => equipmentTypeProductionStepDefinitionAlias)
                            .JoinAlias(() => equipmentTypeProductionStepDefinitionAlias.EquipmentTypeProductionDefinition, () => equipmentTypeProductionDefinitionAlias)
                            .JoinAlias(() => equipmentTypeProductionDefinitionAlias.ProductionDefinition, () => productionDefinitionAlias)
                            .JoinAlias(() => equipmentTypeProductionStepDefinitionAlias.ProductionStepDefinition, () => productionStepDefinitionAlias)
                            .JoinAlias(() => productionStepDefinitionAlias.Step, () => productionStepAlias)
                            .JoinAlias(() => productionStepDefinitionAlias.ProductionStageDefinition, () => productionStageDefinitionAlias)
                            .JoinAlias(() => productionStageDefinitionAlias.ProductionPart, () => productionPartAlias)
                            .Where(() => productionJobAlias.Id == productionJobId)
                            .Future<ProductionJobBuildStep>()
                            .ToList();
                }
                var productionStepIds = productionJobBuildSteps.Select(p => p.EquipmentTypeProductionStepDefinition)
                            .Select(e => e.ProductionStepDefinition)
                            .Select(sd => sd.Step)
                            .Select(s => s.Id)
                            .ToList();

                if (component.Id == component4.Id)
                    Assert.Contains(Types.ProductionStep.Steps.Punch.Id, productionStepIds);
                else
                    Assert.That(productionStepIds, Has.No.Member(Types.ProductionStep.Steps.Punch.Id));
            }
        }

        /// <summary>
        /// Test to ensure components have the correct number of stack pairs created
        /// </summary>
        [Test]
        public void CreatesCorrectNumberOfPairs()
        {
            Equipment component1; Equipment component2; Equipment component3; Equipment component4; Equipment component5; Equipment component6;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Scenario 1 - IBAR Flange, 2500A, expected two pairs/single stack
                component1 = CreateComponentOfType(session, Types.MarketSectorType.Types.IBAR.Id, EquipmentTypeFlangeId, "B01", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 2500 }, null);
                // Scenario 2 - IBAR Flange, 6300A, expected two pairs/double stack
                component2 = CreateComponentOfType(session, Types.MarketSectorType.Types.IBAR.Id, EquipmentTypeFlangeId, "B02", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 6300 }, null);
                // Scenario 3 - IBAR Expansion Unit, 6300A, expected (two pairs/double stack) * production pair multiplier of 2
                component3 = CreateComponentOfType(session, Types.MarketSectorType.Types.IBAR.Id, EquipmentTypeExpansionUnitId, "B03", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 6300 }, null);
                // Scenario 4 - Resinbar Flange, 2500A, expected one pair/single stack
                component4 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeFlangeId, "B04", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 2500 }, null);
                // Scenario 5 - Resinbar Flange, 6300A, expected one pair/double stack overridden to single stack
                component5 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeFlangeId, "B05", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 6300 }, null);
                // Scenario 6 - Resinbar Expansion Unit, 6300A, expected two (pairs/double stack overridden to single stack) * production pair multiplier of 2
                component6 = CreateComponentOfType(session, Types.MarketSectorType.Types.Resinbar.Id, EquipmentTypeExpansionUnitId, "B06", null, Types.ConductorMaterial.Types.Copper.Id, new[] { 6300 }, null);
            }
            var components = new[] { component1, component2, component3, component4 };

            foreach (var component in components)
            {
                var productionJobId = CreateProductionJob(component);
                ProductionJobIds.Add(productionJobId);

                List<ProductionJobEquipmentProductionPartIdentifier> productionJobEquipmentProductionPartIdentifiers;
                using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
                {
                    ProductionJobEquipmentProductionPartIdentifier productionJobEquipmentProductionPartIdentifierAlias = null;
                    ProductionJobEquipment productionJobEquipmentAlias = null;
                    ProductionJob productionJobAlias = null;
                    productionJobEquipmentProductionPartIdentifiers = session.QueryOver(() => productionJobEquipmentProductionPartIdentifierAlias)
                            .JoinAlias(() => productionJobEquipmentProductionPartIdentifierAlias.ProductionJobEquipment, () => productionJobEquipmentAlias)
                            .JoinAlias(() => productionJobEquipmentAlias.ProductionJob, () => productionJobAlias)
                            .Where(() => productionJobAlias.Id == productionJobId)
                            .Future<ProductionJobEquipmentProductionPartIdentifier>()
                            .ToList();
                }

                if (component.Id == component1.Id)
                    Assert.AreEqual(2, productionJobEquipmentProductionPartIdentifiers.Count);
                if (component.Id == component2.Id)
                    Assert.AreEqual(4, productionJobEquipmentProductionPartIdentifiers.Count);
                if (component.Id == component3.Id)
                    Assert.AreEqual(8, productionJobEquipmentProductionPartIdentifiers.Count);
                if (component.Id == component4.Id)
                    Assert.AreEqual(1, productionJobEquipmentProductionPartIdentifiers.Count);
                if (component.Id == component5.Id)
                    Assert.AreEqual(1, productionJobEquipmentProductionPartIdentifiers.Count);
                if (component.Id == component6.Id)
                    Assert.AreEqual(2, productionJobEquipmentProductionPartIdentifiers.Count);
            }
        }
    }
}