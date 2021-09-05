kendo.culture("en-GB");

var loading = true;
var interval;
var userHasInteracted = false;

var viewModel = kendo.observable({
    isVisible: true,
    selectedWoM0: null,
    productionScheduleDetails: null,
    // Filters.
    search: {
        FactoryLocationId: FactoryLocationId,
        WorksOrderId: WorksOrderId,
        WorksOrders: new kendo.data.DataSource({
            transport: {
                read: {
                    url: "/autocompletes/workorders",
                    contentType: "application/json"
                },
                parameterMap: function (e) {
                    var term = $("#workOrderSuggestion").data("kendoComboBox").text();

                    if (term === "")
                        return "";

                    return "term=" + encodeURI(term) + "&liveOnly=false&ibarOnly=false&awaitingProductionOnly=false&testDocumentTemplatesOnly=false";
                }
            },
            serverFiltering: true,
            filter: {
                logic: "and",
                filters: []
            }
        }),
        StartFrom: StartFrom,
        StartTo: StartTo,
        HasCtbValue: HasCtbValue
    },
    // Clear To Build Overview data source.
    overview: new kendo.data.DataSource({
        transport: {
            read: {
                url: "/procurement/cleartobuild/data",
                contentType: "application/json",
                data: function () {
                    return {
                        FactoryLocationId: viewModel.search.FactoryLocationId,
                        WorksOrderId: viewModel.search.WorksOrderId,
                        StartFrom: viewModel.search.StartFrom,
                        StartTo: viewModel.search.StartTo,
                        HasCtbValue: viewModel.search.HasCtbValue,
                        Autoplay: autoPlay
                    };
                }
            }
        },
        requestEnd: function (e) {
            // Fired when the data source call has completed.
            // Allows access to properties in the Result object other than the specified data collection.
            if (autoPlay && e.response) {
                // Autoplay active.
                if (e.response.StartFrom) {
                    // If the model StartFrom property is set, update the corresponding search property and filter control.
                    viewModel.search.StartFrom = e.response.StartFrom;
                    $("input[name='StartFrom']").val(new Date(viewModel.search.StartFrom).toLocaleDateString());
                }
                if (e.response.StartTo) {
                    // If the model StartTo property is set, update the corresponding search property and filter control.
                    viewModel.search.StartTo = e.response.StartTo;
                    $("input[name='StartTo']").val(new Date(viewModel.search.StartTo).toLocaleDateString());
                }
            }
        },
        sort: {
            field: "EarliestStartDate",
            dir: "asc"
        },
        schema: {
            data: "WorksOrderM0Summaries",  // The specified data collection to use from the Result object.
            model: {
                fields: {
                    FactoryLocationAbbreviation: {
                        type: "object"
                    },
                    WoNumber: {
                        type: "object"
                    },
                    Project: {
                        type: "object"
                    },
                    M0: {
                        type: "object"
                    },
                    OpenPos: {
                        type: "number"
                    },
                    ClearToBuildValue: {
                        type: "number"
                    },
                    OrderedItems: {
                        type: "number"
                    },
                    ReceivedItems: {
                        type: "number"
                    },
                    EarliestStartDate: {
                        type: "date"
                    },
                    EarliestFinishDate: {
                        type: "date"
                    },
                    EarliestFatDate: {
                        type: "date"
                    }
                },
                ClearToBuildPercentage: function () {
                    // Converts the decimal value to a percentage and returns in an array (index 0).
                    return decimalToPercentageArray(this.ClearToBuildValue);
                }
            },
            total: "RowCount",  // The specified data property used to return the total from the Result object.
            errors: "Errors"
        },
        pageSize: 20
    }),
    // Clear To Build PO Items data source.
    poItems: new kendo.data.DataSource({
        transport: {
            read: {
                url: "/procurement/cleartobuild/poitems",
                contentType: "application/json"
            }
        },
        schema: {
            model: {
                fields: {
                    PoNumber: {
                        type: "number"
                    },
                    PoNumberPrefix: {
                        type: "object"
                    },
                    Supplier: {
                        type: "object"
                    },
                    SupplierPartNumber: {
                        type: "object"
                    },
                    PartDescription: {
                        type: "object"
                    },
                    ItemQuantity: {
                        type: "number"
                    },
                    ReceivedQuantity: {
                        type: "number"
                    },
                    OrderFulfilled: {
                        type: "object"
                    },
                    DeliveryDate: {
                        type: "date"
                    },
                },
                PoNumberWithPrefix: function () {
                    // Returns the PO number formatted to 5 digits, with the associated prefix.
                    var poNumber = "00000" + this.PoNumber;
                    return this.PoNumberPrefix + poNumber.substr(poNumber.length - 5);
                },
                OrderFulfilledYesNo: function () {
                    // Returns Yes if the PO is fulfilled, or No if not.
                    if (this.OrderFulfilled)
                        return "Yes";
                    return "No";
                },
                DeliveryDateValue: function () {
                    // Returns the delivery date and incomplete flag in an array (index 0 and 1 respectively).
                    // Used by extended widget datarowalert.js.
                    if (this.DeliveryDate == null)
                        return [];
                    else
                        return [this.DeliveryDate, (this.ReceivedQuantity < this.ItemQuantity && !this.OrderFulfilled)];
                }
            },
            errors: "Errors"
        },
        pageSize: 20
    }),
    // Clear To Build Period Summaries data source.
    periodSummaries: new kendo.data.DataSource({
        transport: {
            read: {
                url: "/procurement/cleartobuild/periodsummaries",
                contentType: "application/json"
            }
        },
        schema: {
            model: {
                fields: {
                    Site: {
                        type: "object"
                    },
                    Average2Weeks: {
                        type: "number"
                    },
                    Average4Weeks: {
                        type: "number"
                    },
                    Average6Weeks: {
                        type: "number"
                    }
                },
                Average2WeeksPercentage: function () {
                    // Converts the decimal value to a percentage and returns in an array (index 0).
                    return decimalToPercentageArray(this.Average2Weeks);
                },
                Average4WeeksPercentage: function () {
                    // Converts the decimal value to a percentage and returns in an array (index 0).
                    return decimalToPercentageArray(this.Average4Weeks);
                },
                Average6WeeksPercentage: function () {
                    // Converts the decimal value to a percentage and returns in an array (index 0).
                    return decimalToPercentageArray(this.Average6Weeks);
                }
            },
            errors: "Errors"
        },
    }),
    // Factory Locations data source.
    factoryLocations: new kendo.data.DataSource({
        transport: {
            read: {
                url: "/factorylocations/data",
                contentType: "application/json"
            }
        }
    }),
    factoryLocationChange: function (e) {
        // Fired when the factory location drop down box is changed.
        var factoryLocation = e.sender.dataItem(e.sender.select());
        if (factoryLocation)
            // Set the corresponding search property.
            viewModel.set("search.FactoryLocationId", factoryLocation.Id);
    },
    onChange: function (e) {
        // Fired when a row is selected in the main grid.

        e.preventDefault();

        // Get the selected data item.
        var grid = e.sender;
        var selectedItem = grid.dataItem(grid.select());
        // Populate the selection objects from the data.
        viewModel.selectedWoM0 = selectedItem.WorksOrderId + "|" + selectedItem.M0;
        viewModel.productionScheduleDetails = {
            WoNumber: selectedItem.WoNumber,
            Project: selectedItem.Project,
            M0: selectedItem.M0,
            ProductionScheduleDescription: selectedItem.ProductionScheduleDescription
        };

        // Fetch the PO items data.
        // Reset paging: https://stackoverflow.com/questions/13508849/kendoui-resetting-grid-data-to-first-page-after-button-click
        if (viewModel.poItems.page() !== 1)
            viewModel.poItems.page(1);
        viewModel.poItems.read({
            WorksOrderId: selectedItem.WorksOrderId,
            M0: selectedItem.M0
        });
    },
    dataBound: function (e) {
        // Fired when a page of data is databound in either grid.

        if (e.sender.dataSource === viewModel.overview) {
            // Clear To Build Overview grid.

            // Hide the results.
            $("div.cleartobuild-left").removeClass("cleartobuild-loading");
            viewModel.hideResults("left");
            if (!viewModel.selectedWoM0)
                viewModel.hideResults("right");

            // Display results depending on whether we have any valid data.
            if (e.sender.dataSource.data().length > 0) {
                $("div.cleartobuild-left").removeClass("hidden");
            } else {
                $("div.cleartobuild-left").removeClass("hidden").addClass("hidden");
                $("div.cleartobuild-wrapper-left").find("div.cleartobuild-noresults").removeClass("hidden");
            }

            // If we have an active selected row in the main grid, highlight it.
            // This could be the case if the databound event was fired from a page change.
            if (viewModel.selectedWoM0) {
                $.each(e.sender._data, function (index, value) {
                    if (viewModel.selectedWoM0 === value.WorksOrderId + "|" + value.M0) {
                        var rowIndex = 0;
                        $(e.sender.tbody).find("tr").each(function () {
                            if (rowIndex === index)
                                $(this).addClass("cleartobuild-selected");
                            rowIndex++;
                        });
                    }
                });
            }

            // Wire up the row click event.
            $(e.sender.tbody).on("click", "td", function () {
                $(e.sender.tbody).find("tr").each(function () {
                    $(this).removeClass("cleartobuild-selected");
                });
                $(this).closest("tr").addClass("cleartobuild-selected");
            });

            // Set autoplay interval.
            loading = false;
            if (typeof interval !== "undefined")
                clearInterval(interval);
            interval = setInterval(viewModel.autoPlay, 30000);
        }

        if (e.sender.dataSource === viewModel.poItems) {
            // Clear To Build PO Items grid.

            // Hide the results.
            viewModel.hideResults("right");

            // Display the grid header.
            $("div.cleartobuild-gridheader-right").removeClass("hidden");
            $("div.cleartobuild-gridheader-right").html(
                "<table><tr><td>" +
                "<b>" + viewModel.productionScheduleDetails.WoNumber + "</b></td><td>" + viewModel.productionScheduleDetails.Project +
                "</td></tr><tr><td>" +
                "<b>" + viewModel.productionScheduleDetails.M0 + "</b></td><td>" + viewModel.productionScheduleDetails.ProductionScheduleDescription +
                "</td></tr></table>"
                );

            // Display results depending on whether we have any valid data.
            if (e.sender.dataSource.data().length > 0) {
                $("div.cleartobuild-right").removeClass("hidden");
                $("div.cleartobuild-right").removeClass("cleartobuild-right-visible").addClass("cleartobuild-right-visible");
            } else {
                $("div.cleartobuild-wrapper-right").find("div.cleartobuild-noresults").removeClass("hidden");
                $("div.cleartobuild-wrapper-right").find("div.cleartobuild-noresults").removeClass("cleartobuild-right-visible").addClass("cleartobuild-right-visible");
            }

            adjustPeriodSummariesPosition();
        }

        if (e.sender.dataSource === viewModel.periodSummaries) {
            // Clear To Build Period Summaries grid.
            $("div.cleartobuild-periodsummaries").removeClass("cleartobuild-loading");
        }
    },
    hideResults: function (side) {
        // Hides all results containers for the specified side (left or right).
        $("div.cleartobuild-" + side).removeClass("hidden").addClass("hidden");
        $("div.cleartobuild-" + side).removeClass("cleartobuild-right-visible");
        $("div.cleartobuild-wrapper-" + side).find("div.cleartobuild-noresults").removeClass("hidden").addClass("hidden");
        $("div.cleartobuild-gridheader-" + side).removeClass("hidden").addClass("hidden");
    },
    autoPlay: function () {
        // Fired during each autoplay timer tick.
        var count = viewModel.overview.data().length;
        if (count > 0 && autoPlay && !loading && !userHasInteracted) {
            // Get the next visible page in the grid.
            var nextButton = $(".cleartobuild-left .k-pager-nav .k-i-arrow-60-right").parent();

            if (nextButton.hasClass("k-state-disabled")) {
                // No further pages to display, so perform a full data refresh.
                displayGridLoad();
                adjustPeriodSummariesPosition();
                viewModel.overview.page(1);
                viewModel.overview.read();
                viewModel.periodSummaries.read();
                loading = true;
            }
            else {
                // Display the next page of data.
                nextButton.trigger("click");
            }
        }
    }
});

var fetchData = function () {
    // Perform a full data fetch.
    displayGridLoad();
    adjustPeriodSummariesPosition();
    // Clear the selection objects.
    viewModel.selectedWoM0 = null;
    viewModel.productionScheduleDetails = null;
    // Fetch the data.
    // Reset paging: https://stackoverflow.com/questions/13508849/kendoui-resetting-grid-data-to-first-page-after-button-click
    if (viewModel.overview.page() !== 1)
        viewModel.overview.page(1);
    viewModel.overview.read({
        FactoryLocationId: viewModel.search.FactoryLocationId,
        WorksOrderId: viewModel.search.WorksOrderId,
        StartFrom: viewModel.search.StartFrom != null ? (new Date(viewModel.search.StartFrom)).toISOString() : null,
        StartTo: viewModel.search.StartTo != null ? (new Date(viewModel.search.StartTo)).toISOString() : null,
        HasCtbValue: viewModel.search.HasCtbValue
    });
    viewModel.periodSummaries.read();
};

var displayGridLoad = function () {
    // For the main grid and the period summaries grid, display with a minimum height so the loading dialog can be seen.
    $("div.cleartobuild-left").removeClass("hidden");
    $("div.cleartobuild-left").removeClass("cleartobuild-loading").addClass("cleartobuild-loading");
    $("div.cleartobuild-periodsummaries").removeClass("cleartobuild-loading").addClass("cleartobuild-loading");
}

var adjustPeriodSummariesPosition = function () {
    // Adusts the position of the period summaries grid
    // This avoids having to set the height of the PO items kendo grid to 0 when hidden, which can cause problems

    var divPeriodSummaries = $("div.cleartobuild-periodsummaries");
    var divGridRight = $("div.cleartobuild-right");
    var divNoResultsRight = $("div.cleartobuild-wrapper-right").find("div.cleartobuild-noresults");

    var heightGrid = $(divGridRight).height();
    var heightNoResults = $(divNoResultsRight).height();

    var marginTop = 0;

    if ($(divGridRight).hasClass("hidden")) {
        if ($(divNoResultsRight).hasClass("hidden"))
            marginTop = 14 - (heightGrid + heightNoResults);
        else
            marginTop = 0 - (heightGrid);
    }

    $(divPeriodSummaries).css("margin-top", marginTop);
}

var decimalToPercentageArray = function (value) {
    // Converts the decimal value to a percentage and returns in an array (index 0).
    // Used by extended widget cleartobuild.js.
    // Value conversion: https://stackoverflow.com/questions/11832914/round-to-at-most-2-decimal-places-only-if-necessary
    if (value == null)
        return [];
    else if (value === 0)
        return [0];
    else
        return [+(Math.round((value * 100) + "e+2") + "e-2")];
}

function launchIntoFullscreen() {
    // Toggles full screen on or off.
    var elem = document.documentElement;

    if (!document.fullscreenElement && !document.mozFullScreenElement && !document.webkitFullscreenElement && !document.msFullscreenElement) {
        if (elem.requestFullscreen) {
            elem.requestFullscreen();
        } else if (elem.msRequestFullscreen) {
            elem.msRequestFullscreen();
        } else if (elem.mozRequestFullScreen) {
            elem.mozRequestFullScreen();
        } else if (elem.webkitRequestFullscreen) {
            elem.webkitRequestFullscreen(Element.ALLOW_KEYBOARD_INPUT);
        }
        enteredFullScreen();
    } else {
        if (document.exitFullscreen) {
            document.exitFullscreen();
        } else if (document.msExitFullscreen) {
            document.msExitFullscreen();
        } else if (document.mozCancelFullScreen) {
            document.mozCancelFullScreen();
        } else if (document.webkitExitFullscreen) {
            document.webkitExitFullscreen();
        }
        exitedFullScreen();
    }
}

function fullScreenChanged() {
    // Handler for full screen changed event.
    if (document.webkitIsFullScreen !== null || document.mozFullScreen !== null || document.msFullscreenElement !== null) {
        if (document.webkitIsFullScreen === true || document.mozFullScreen === true || document.msFullscreenElement === true) {
            enteredFullScreen();
        }
        if (document.webkitIsFullScreen === false || document.mozFullScreen === false || document.msFullscreenElement === false) {
            exitedFullScreen();
        }
    }
}

function enteredFullScreen() {
    // Layout changes when entering full screen.
    viewModel.overview.pageSize(25);
    $("#header").removeClass("cleartobuild-title-container").addClass("cleartobuild-title-container");
    $("#header").removeClass("cleartobuild-solid-border").addClass("cleartobuild-solid-border");
    $("#anordMardixLogo").removeClass("cleartobuild-title-large").addClass("cleartobuild-title-large");
    $("#anordMardixLogo").removeClass("hidden");
    $("#pageTitle").removeClass("cleartobuild-title-large").addClass("cleartobuild-title-large");
    $("#FiltersHolder").removeClass("cleartobuild-solid-border").addClass("cleartobuild-solid-border");
    $("#grid-left").removeClass("cleartobuild-solid-border").addClass("cleartobuild-solid-border");
    $("#grid-periodsummaries").removeClass("cleartobuild-solid-border").addClass("cleartobuild-solid-border");
    $("#grid-periodsummaries").removeClass("cleartobuild-large-text").addClass("cleartobuild-large-text");
}

function exitedFullScreen() {
    // Layout changes when exiting full screen.
    viewModel.overview.pageSize(20);
    $("#header").removeClass("cleartobuild-title-container");
    $("#header").removeClass("cleartobuild-solid-border");
    $("#anordMardixLogo").removeClass("cleartobuild-title-large");
    $("#anordMardixLogo").removeClass("hidden").addClass("hidden");
    $("#pageTitle").removeClass("cleartobuild-title-large");
    $("#FiltersHolder").removeClass("cleartobuild-solid-border");
    $("#grid-left").removeClass("cleartobuild-solid-border");
    $("#grid-periodsummaries").removeClass("cleartobuild-solid-border");
    $("#grid-periodsummaries").removeClass("cleartobuild-large-text");
}

/*
$(document).on("mousedown keydown", function (e) {
    // User interaction detection, used to stop autoplay

    // Ignore mousedown event if the full screen icon has been clicked.
    if (e.target && e.target.id && e.target.id === "fullscreenableTrigger")
        return;

    if (userHasInteracted)
        return;

    userHasInteracted = true;

    if (typeof interval !== "undefined")
        clearInterval(interval);

    console.log("Auto-play stopped due to user interaction.");
});
*/

//////////////////////////////////////////////////////////////
// Initialisation
//////////////////////////////////////////////////////////////

$().ready(function () {
    // Bind the kendo view model to the page
    kendo.bind($("body"), viewModel);

    // Wire up the full screen icon.
    $(".fullscreenableTrigger").click(function () {
        launchIntoFullscreen();
    });

    // Wire up the full screen handler.
    // https://stackoverflow.com/questions/10706070/how-to-detect-when-a-page-exits-fullscreen
    if (document.addEventListener) {
        document.addEventListener('webkitfullscreenchange', fullScreenChanged, false);
        document.addEventListener('mozfullscreenchange', fullScreenChanged, false);
        document.addEventListener('fullscreenchange', fullScreenChanged, false);
        document.addEventListener('MSFullscreenChange', fullScreenChanged, false);
    }

    adjustPeriodSummariesPosition();

    if (autoPlay) {
        // If autoplay is active, hide the main grid toolbar and launch full screen
        $("#grid-left").find(".k-grid-toolbar").remove();
        launchIntoFullscreen();
    }
    else
        // If autoplay is not active, display the main grid toolbar at the bottom of the grid
        $("#grid-left").find(".k-grid-toolbar").insertAfter($("#grid-left .k-grid-pager"));

    $("#searchSubmit").on("click", function () {
        // Search filter activated.
        // Hide Clear To Build PO Items grid.
        viewModel.hideResults("right");
        // Perform a full data fetch.
        fetchData();
    });

    $("#searchReset").on("click", function () {
        // Search filter cleared.
        displayGridLoad();
        // Hide both grids.
        viewModel.hideResults("left");
        viewModel.hideResults("right");
        // Clear all filters.
        viewModel.search.FactoryLocationId = null;
        viewModel.search.WorksOrderId = null;
        viewModel.search.StartFrom = null;
        viewModel.search.StartTo = null;
        viewModel.search.HasCtbValue = null;
        $("#FiltersHolder").find("input").val("");
        $("#FiltersHolder").find(".k-dropdown").find(".k-input").html("");
        $("#FiltersHolder").find("input:checkbox").data("kendoMobileSwitch").check(false);
        // Perform a full data fetch.
        fetchData();
    });
});