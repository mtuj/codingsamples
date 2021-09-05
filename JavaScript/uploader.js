Vision.Ui.Uploader = (function () {

    var application;
    var formViewInstance;
    var documentUploadTypeDropDownViewInstance;
    var metadataViewInstance;

    var documentUploadTypes;
    var documentTypes;
    var documentTypesCpsDocumentTemplate;
    var documentTypesTestDocumentTemplate;
    var documentTypesTestSessionDocumentTemplate;
    var equipmentM0;
    var barStandards;
    var siteVisitReports;

    var documentUploadType;
    var siteVisitReport;
    var cpsDocumentTemplate;
    var testDocumentTemplate;
    var testSessionDocumentTemplate;
    var uploaderModel;

    var files;
    var documentIndex;

    /// <summary>
    /// Set up backbone routing
    /// </summary>
    /// <returns>The Backbone router</returns>
    var applicationRouter = Backbone.Router.extend({
        initialize: function () {
            // Render document upload type drop down list
            documentUploadTypeDropDownViewInstance = new documentUploadTypeDropDownViewDefinition({ el: $("#DocumentUploadTypeContainer"), collection: documentUploadTypes });
            documentUploadTypeDropDownViewInstance.render();

            // Render metadata view
            metadataViewInstance = new metadataViewDefinition({ el: $("#MetadataContainer"), model: documentUploadType });
            metadataViewInstance.render();

            // Render form view
            formViewInstance = new formViewDefinition({ el: $("#FormHolder"), model: uploaderModel });
            formViewInstance.render();
        },
        routes: {
            "": "index"
        },
        index: function () {}
    });

    /// <summary>
    /// Backbone view for main form
    /// Note that no model is sent to the controller, and data is instead posted by the jQuery file upload plugin
    /// (using iframe transport) in order to post file data together with associated form fields
    /// https://github.com/blueimp/jQuery-File-Upload
    /// Because of this, the main form is actually an empty template bound to an empty model
    /// However this is necessary because, as the model definition contains the Backbone Validation logic, it needs a view to bind to
    /// </summary>
    var formViewDefinition = Backbone.View.extend({
        _modelBinder: undefined,
        initialize: function () {
            // Set scope of 'this' in the specified methods
            _.bindAll(this, "render");
            // Set template for form
            this.template = $("#FormView");
            this._modelBinder = new Backbone.ModelBinder();
        },
        render: function () {
            // Render the view
            this.$el.html(this.template.render(this.model.toJSON()));

            // Apply validation
            Vision.Utilities.RegisterBackboneValidation(this);

            return this;
        }
    });

    /// <summary>
    /// Backbone view for document upload type drop down list
    /// </summary>
    var documentUploadTypeDropDownViewDefinition = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this, "render", "click", "change");
            // Set template for view
            this.template = $("#DocumentUploadTypeDropDownTemplate");
        },
        // Bind view events to methods
        events: {
            "click": "click",
            "change": "change"
        },
        click: function (e) {
            this.previousIndex = e.target.selectedIndex;
        },
        change: function (e) {
            // Only allow change to fire if no document type is currently selected or the user has clicked the confirmation dialog
            if (this.previousIndex === 0 || confirm(Vision.Utilities.GetDisplayText("ConfirmChangeDocumentUploadType")) === true) {
                // Update document upload type model to trigger a change in the metadata and file upload views
                documentUploadType.set("Name", $(e.target).find(":selected").attr("name"));
                // Reset collections
                if (equipmentM0.length > 0) equipmentM0.reset();
                if (siteVisitReports.length > 0) siteVisitReports.reset();
            } else {
                e.target.selectedIndex = this.previousIndex;
            }
        },
        render: function () {
            this.$el.html(this.template.render([this.collection.toJSON()]));
            return this;
        }
    });

    /// <summary>
    /// Backbone view for test document template document type drop down list
    /// </summary>
    var documentTypeTestDocumentTemplateDropDownViewDefinition = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this, "render", "change");
            this.template = options.template;
        },
        // Bind view events to methods
        events: {
            "change": "change"
        },
        change: function (e) {
            // Verify document type against uploaded document
            verifyTestDocumentTemplateType(e);
        },
        render: function () {
            this.$el.html(this.template.render([this.collection.toJSON()]));
            return this;
        }
    });

    /// <summary>
    /// Backbone view for metadata
    /// </summary>
    var metadataViewDefinition = Backbone.View.extend({
        initialize: function() {
            _.bindAll(this, "render");
            // Bind model events to functions
            this.model.on("change", this.render);
        },
        render: function () {
            // Dynamically set view template
            var template = $("#MetadataTemplate" + this.model.get("Name"));
            if (template.length === 0) template = $("#MetadataTemplateDefault");    // Use the default if no template exists
            this.template = template;

            this.$el.html(this.template.render(this.model.toJSON()));

            // Render drop-down lists

            var siteVisitReportDropDownViewInstance = new siteVisitReportDropDownViewDefinition({ collection: siteVisitReports });
            siteVisitReportDropDownViewInstance.setElement(this.$(".site-visit-report-container")).render();

            var m0DropDownViewInstance = new m0DropDownViewDefinition({ collection: equipmentM0 });
            m0DropDownViewInstance.setElement(this.$(".m0-container")).render();

            var barDropDownViewInstance = new barDropDownViewDefinition({ collection: barStandards });
            barDropDownViewInstance.setElement(this.$("#BarStandard")).render();

            // Render lookups

            var lookupEmNumber = new Vision.Common.Lookup("EmNumber", null, "/uploader/datalookup", siteVisitReports, null, { numeric : true });
            var lookupViewEmNumber = new lookupEmNumber.LookupViewDefinition();
            lookupViewEmNumber.render();

            var lookupServiceTagNumber = new Vision.Common.Lookup("ServiceTagNumber", null, "/uploader/datalookup", null, serviceTagNumberSelected, { numeric: true });
            var lookupViewServiceTagNumber = new lookupServiceTagNumber.LookupViewDefinition();
            lookupViewServiceTagNumber.render();

            var lookupWorksOrderNumber = new Vision.Common.Lookup("WorksOrderNumber", null, "/uploader/datalookup", equipmentM0, null, { numeric: true });
            var lookupViewWorksOrderNumber = new lookupWorksOrderNumber.LookupViewDefinition();
            lookupViewWorksOrderNumber.render();

            // Whenever the user changes an input, refresh the latest revision displays
            this.$el.find("input, select").change(displayAllLatestRevisions);

            // Whenever the user selects generic test document template, prompt them to confirm
            this.$el.find("input[name='Generic']").click(confirmGenericTestDocumentTemplate);

            return this;
        }
    });

    /// <summary>
    /// Backbone view for associated equipment
    /// </summary>
    var associatedEquipmentViewDefinition = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this, "render");
            this.template = options.template;
            // Bind model events to functions
            this.model.on("change", this.render);
        },
        render: function () {
            // Get selected site visit report
            var siteVisitReport = siteVisitReports.get(this.model.get("Id"));
            if (!siteVisitReport) siteVisitReport = new Backbone.Model();

            this.$el.html(this.template.render(siteVisitReport.toJSON()));

            // Prepend document index to input controls
            prependDocumentIndexToInputs(this.$el, this.$el.attr("data-document-index"));

            return this;
        }
    });

    /// <summary>
    /// Backbone view for site visit report drop down list
    /// </summary>
    var siteVisitReportDropDownViewDefinition = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this, "render", "change", "reset");
            // Set template for view
            this.template = $("#SiteVisitReportDropDownTemplate");
            // Bind collection events to functions
            this.collection.on("reset", this.reset);
        },
        // Bind view events to methods
        events: {
            "change": "change"
        },
        change: function (e) {
            // Update site visit report model to trigger a change in the associated equipment view
            siteVisitReport.set("Id", siteVisitReports.get(e.target.value));
        },
        reset: function () {
            siteVisitReport.set("Id", null);
            this.render();
        },
        render: function () {
            this.$el.html(this.template.render([this.collection.toJSON()]));
            return this;
        }
    });

    /// <summary>
    /// Backbone view for M0 drop down list
    /// </summary>
    var m0DropDownViewDefinition = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this, "render", "reset");
            // Set template for view
            this.template = $("#M0DropDownTemplate");
            // Bind collection events to functions
            this.collection.on("reset", this.reset);
        },
        // Bind view events to methods
        reset: function () {
            this.render();
            this.$el.find("select").change(displayAllLatestRevisions);  // Whenever the user changes the input, refresh the latest revision displays
        },
        render: function () {
            this.$el.html(this.template.render([this.collection.toJSON()]));
            return this;
        }
    });

    /// <summary>
    /// Backbone view for Bar Standard drop down list
    /// </summary>
    var barDropDownViewDefinition = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this, "render");
            this.template = $("#BarStandardDropDownTemplate");
            this.selectedItem = options.selectedItem;
        },
        render: function () {
            this.$el.empty();
            this.$el.append("<option value=\"\">- Select Bar Standard -</option>");
            this.$el.append(this.template.render(this.collection.toJSON()));

            if (this.selectedItem != null)
                this.$el.val(this.selectedItem);

            return this;
        }
    });

    /// <summary>
    /// Backbone view for file upload form
    /// </summary>
    var fileUploadViewDefinition = Backbone.View.extend({
        _modelBinder: undefined,
        initialize: function (options) {
            this._modelBinder = new Backbone.ModelBinder();
            // Set scope of 'this' in the specified methods
            _.bindAll(this, "render", "renderFields", "close", "cancel");
            // Bind model events to functions
            this.model.on("change", this.renderFields);
            // Set template for view
            this.template = $("#FileUploadTemplate");
            // Get options specified during instantiation
            this.index = options.index;
        },
        // Close view
        close: function () {
            this._modelBinder.unbind();
            this.remove();
            this.unbind();
        },
        // Cancel changes
        cancel: function (e) {
            e.preventDefault();
        },
        render: function () {
            // Render the view
            this.$el.html(this.template.render(this.model.toJSON()));

            // Render the additional fields
            this.renderFields();

            return this;
        },
        renderFields: function () {
            // Dynamically set subview template
            var template = $("#FileUploadFields" + this.model.get("Name"));
            if (template.length === 0) template = $("#FileUploadFieldsDefault");    // Use the default if no template exists
            this.template = template;

            // Render the subview
            this.$el.find(".file-upload-fields-container").html(template.render());

            // Render drop-down lists

            var documentTypeDropDownViewInstance = new Vision.Views.DropDown.ViewDefinition({ template: $("#DocumentTypeExtendedDropDownTemplate"), collection: documentTypes });
            documentTypeDropDownViewInstance.setElement(this.$(".document-type-container")).render();

            var documentTypeCpsDocumentTemplateDropDownViewInstance = new Vision.Views.DropDown.ViewDefinition({ template: $("#DocumentTypeDropDownTemplate"), collection: documentTypesCpsDocumentTemplate });
            documentTypeCpsDocumentTemplateDropDownViewInstance.setElement(this.$(".document-type-cps-document-template-container")).render();

            var documentTypeTestDocumentTemplateDropDownViewInstance = new documentTypeTestDocumentTemplateDropDownViewDefinition({ template: $("#DocumentTypeDropDownTemplate"), collection: documentTypesTestDocumentTemplate });
            documentTypeTestDocumentTemplateDropDownViewInstance.setElement(this.$(".document-type-test-document-template-container")).render();

            var documentTypeTestSessionDocumentTemplateDropDownViewInstance = new Vision.Views.DropDown.ViewDefinition({ template: $("#DocumentTypeDropDownTemplate"), collection: documentTypesTestSessionDocumentTemplate });
            documentTypeTestSessionDocumentTemplateDropDownViewInstance.setElement(this.$(".document-type-test-session-document-template-container")).render();

            // Prepend document index to input controls
            prependDocumentIndexToInputs(this.$el, this.index);

            // Render associated equipment view
            var associatedEquipmentViewInstance = new associatedEquipmentViewDefinition({ template: $("#AssociatedEquipmentContainerTemplate"), model: siteVisitReport });
            associatedEquipmentViewInstance.setElement(this.$(".associated-equipment-container"));
            $(associatedEquipmentViewInstance.el).attr("data-document-index", this.index);
            associatedEquipmentViewInstance.render();

            // Verify document type against uploaded document (test document templates only)
            this.$el.find(":file").change(function (e) {
                verifyTestDocumentTemplateType(e);
            });

            var el = this.$el;
            this.$el.find("input, select").change(function() {
                displayLatestRevision(el);      // Whenever the user changes an input, refresh the latest revision display
            });
        }
    });

    /// <summary>
    /// Add Document handler
    /// </summary>
    $("a.add-document").click(function (e) {
        // Render file upload view
        documentIndex++;
        var fileUploadView = new fileUploadViewDefinition({ index: documentIndex, model: documentUploadType }).render().$el;

        // Re-bind the fileupload plugin now we have added a form field
        $(fileUploadView).insertBefore($(".file-upload-add-document")).each(function () { bindFileUpload(); }); // Each is iterative, but in this case is only called once

        // Remove Document handler
        // We have to declare this here as the Remove Document button is only created during this render event
        $("a.remove-document").click(function (e) {
            var fileControl = $(e.target).closest(".file-upload").find(":file");
            if (fileControl && fileControl[0].files.length > 0) {
                // Remove the file control with the specified name from the master file control list 
                for (var i = files.length - 1; i >= 0; i--) {
                    if ($(files[i].fileInput).attr("name") === $(fileControl[0]).attr("name"))
                        files.splice(i, 1);
                }
            }
            // Re-bind the fileupload plugin now we have removed a form field
            $(e.target).closest(".file-upload-container").remove().each(function () { bindFileUpload(); });;    // Each is iterative, but in this case is only called once
        });
    });

    /// <summary>
    /// Submit Form handler
    /// </summary>
    $("a.submit").click(function () {
        // Only proceed if model has been successfully validated, and we actually have some files
        if (uploaderModel.isValid(true) && files.length > 0) {

            // Display the loading overlay
            $(".uploader-container").block();

            // Remove any error messages
            Vision.Common.BackboneNotifications.ClearErrors();

            // Get all form fields associated with file uploads
            // We need to do this because these are not processed with the main model, but during a second POST contaning file data
            // File data is handled by the jQuery fileupload plugin, and sent as multipart form data
            // We get the associated form fields so we can send these as well
            // These fields are associated with a file upload control by means of filename convention
            var controls = $(".uploader-container").find("input, select");
            var formData = {};
            _.each($(controls).serializeArray(), function (control) {
                formData[control.name] = control.value;
            });
            if (files.length > 0) {
                // Invoke the jQuery fileupload send method, which sends all file data as multipart form data
                // We specify the files explicitly as we append to a master file control list in memory each time a new file is added using fileupload
                // (this is because file upload is mainly designed for single file upload controls)
                // We also send our associated form data derived above
                // Note that success/failure of this call is defined and handled in the bindFileUpload method, where we set up the fileupload plugin
                var fileData = [];
                // Build up list of raw files from the master file control list
                _.each(files, function (file) {
                    if (file.files.length > 0)
                        fileData.push(file.files[0]);
                });
                $("#wrapper").fileupload("send", { files: fileData, formData: formData });
            } else {
                // No files selected to send; we shouldn't have got this far, but let's handle it anyway

                // Remove the loading overlay
                $(".uploader-container").unblock();

                // Show the failure message
                Vision.Common.BackboneNotifications.AddError(Vision.Utilities.GetDisplayText("SaveFailed"));
            }
        }
    });

    /// <summary>
    /// Dynamically prepends the index to the various attribute of each child input
    /// </summary>
    var prependDocumentIndexToInputs = function (el, index) {
        var prefix = "Document" + index;
        $(el).find(":input").each(function () {
            prependPrefixToElementAttribute(prefix, $(this), "id");
            prependPrefixToElementAttribute(prefix, $(this), "name");
        });
        $(el).find("label").each(function () {
            prependPrefixToElementAttribute(prefix, $(this), "for");
        });
    }

    /// <summary>
    /// Dynamically prepends the prefix to the specified attribute of the element
    /// </summary>
    var prependPrefixToElementAttribute = function (prefix, el, attr) {
        if ($(el).attr(attr) && $(el).attr(attr).substring(0, prefix.length) !== prefix)
            $(el).attr(attr, prefix + $(el).attr(attr));
    }

    /// <summary>
    /// Binds the jQuery fileupload plugin to the main form
    /// </summary>
    var bindFileUpload = function () {

        // If the plugin is already bound to the form, we destroy the binding and re-create it
        // This is because if the form changes, we need to re-bind so the plugin knows about any new fields
        // Note that even though the plugin is bound to the whole form, and knows about all of our file upload controls,
        // it is really only designed for single controls, rather than individual controls dotted around the form like we have
        // Because of this, when the user selects a file using one of the controls (triggering the 'add' method)
        // we append the file upload control data to a master file control list in memory
        // If we did not do this, when the user clicks on one of the other file controls, the information from the first file would be lost
        // When the 'send' method is invoked, we then retrieve and send in our master file control list at that point
        // This destroy/re-create scenario happens each time we dynamically add or remove a new file upload control to the form
        // as otherwise, the new control would not be bound to the plugin - or a removed control would still incorrectly be bound to it
        try {
            $("#wrapper").fileupload("destroy");
        } catch (e) {}  // We cannot destroy the binding if the plugin is not active!

        $("#wrapper").fileupload({
            dataType: "json",
            singleFileUploads: false,
            autoUpload: false,
            replaceFileInput: false,    // Display the selected file
            url: "/uploader/data/",     // Url of the controller's data handling method
            method: "POST",
            //timeout: 90000,  // 15 mins
            add: function (e, data) {
                // User has selected a file, so add this information to our master file control list
                var controlExists = false;
                // If the control already exists in our collection, we simply update it
                // This is necessary to preserve the existing file key in the collection 
                for (var i = 0; i < files.length; i++) {
                    if ($(files[i].fileInput).attr("name") === $(data.fileInput).attr("name")) {
                        files[i] = data;
                        controlExists = true;
                    }
                }
                // Otherwise add the control to the collection
                if (!controlExists)
                    files.push(data);
            },
            done: function () {
                // Documents successfully uploaded

                // Remove the loading overlay
                $(".uploader-container").unblock();

                // Show the success message
                Vision.Common.BackboneNotifications.AddSuccess(Vision.Utilities.GetDisplayText("SaveSuccessful"));

                // Reset the form
                resetFormDisplay();

                // Reset the files collection
                files = [];
            },
            fail: function () {
                // Error uploading documents

                // Remove the loading overlay
                $(".uploader-container").unblock();

                // Show the failure message
                Vision.Common.BackboneNotifications.AddError(Vision.Utilities.GetDisplayText("SaveFailed"));
            }
        });
    };

    /// <summary>
    /// Fired when a service tag number is selected
    /// </summary>
    var serviceTagNumberSelected = function (label, value) {
        // Set the value of the service tag number field
        $("#ServiceTagNumber").val(value);
    }

    /// <summary>
    /// For test document template uploads, verifies that the selected file appears to be the selected type
    /// </summary>
    var verifyTestDocumentTemplateType = function (e) {

        // Only applies to test document templates
        if (documentUploadType.get("Name") !== Vision.Utilities.GetDisplayText("DocumentUploadTypeTestDocumentTemplate").trim())
            return;

        // Get the file upload and document type controls
        var fileControl = $(e.target).closest(".file-upload").find("input[type='file']");
        var documentTypeControl = $(e.target).closest(".file-upload").find("select[name$='DocumentType']");

        // Only perform check if a file and document type have been selected
        if (fileControl[0].files.length > 0 && documentTypeControl.children("option:selected").val() !== "") {
            var labelControl = $(documentTypeControl).closest(".field").find("label");
            var warningControl = $(documentTypeControl).closest(".field").find(".document-type-warning");
            var documentTypeSegments = documentTypeControl.children("option:selected").text().split("-");
            if (documentTypeSegments.length > 0 && fileControl[0].files[0].name.replace(/ /g, "").toLowerCase().match(documentTypeSegments[0].replace(/ /g, "").toLowerCase())) {
                // File name contains document type, so no warning displayed
                $(labelControl).removeClass("document-type-warning-label");
                $(warningControl).removeClass("hidden").addClass("hidden");
                $(documentTypeControl).removeClass("document-type-warning-highlight");
            } else {
                // File name does not contain document type, so display warning
                $(labelControl).removeClass("document-type-warning-label").addClass("document-type-warning-label");
                $(warningControl).removeClass("hidden");
                $(documentTypeControl).removeClass("document-type-warning-highlight").addClass("document-type-warning-highlight");
            }
        }
    }

    /// <summary>
    /// For test document template uploads, when selecting generic template, prompt the user to confirm
    /// </summary>
    var confirmGenericTestDocumentTemplate = function () {
        // Enable Works Order Number and M0 controls to begin with
        $("input[name='WorksOrderNumber']").prop("disabled", false);
        $("select[name='M0']").prop("disabled", false);
        var checked = $(this).is(":checked");
        if (checked) {
            // User has checked the generic box, so display prompt
            if (!confirm(Vision.Utilities.GetDisplayText("ConfirmSelectGenericTestDocumentTemplate"))) {
                // User has had second thoughts, so uncheck the box
                $(this).removeAttr("checked");
            } else {
                // User has chosen to proceed, so clear Works Order Number and M0 controls
                $("input[name='WorksOrderNumber']").val("");
                equipmentM0.reset();
                // Disable Works Order Number and M0 controls 
                $("input[name='WorksOrderNumber']").prop("disabled", true);
                $("select[name='M0']").prop("disabled", true);
                // Revalidate model to clear any errors on Works Order Number and M0 controls
                uploaderModel.validate();
            }
        }
    }

    /// <summary>
    /// Displays the latest revision for all file upload views
    /// </summary>
    var displayAllLatestRevisions = function() {
        $(".file-upload").each(function () {
            displayLatestRevision(this);
        });
    }

    /// <summary>
    /// Displays the latest revision for the file upload view
    /// </summary>
    var displayLatestRevision = function (el) {

        // Select the active revision model based on the current document upload type
        var templateModel = null;
        if (documentUploadType.get("Name") === Vision.Utilities.GetDisplayText("DocumentUploadTypeCpsDocumentTemplate").trim()) templateModel = cpsDocumentTemplate;
        if (documentUploadType.get("Name") === Vision.Utilities.GetDisplayText("DocumentUploadTypeTestDocumentTemplate").trim()) templateModel = testDocumentTemplate;
        if (documentUploadType.get("Name") === Vision.Utilities.GetDisplayText("DocumentUploadTypeTestSessionDocumentTemplate").trim()) templateModel = testSessionDocumentTemplate;
        if (!templateModel) return;

        // Set the data properties for the fetch operation
        // Note that not all revision models require all fields, but there is no harm in adding them all every time
        var documentTypeId = $(el).find("select[name$='DocumentType']").val();
        var barStandardId = $("select[name$='BarStandard']").val();
        var data = {
            documentTypeId: documentTypeId && documentTypeId.length ? documentTypeId : Vision.Utilities.EmptyGuid(),
            worksOrderNumber: $("input[name='WorksOrderNumber']").val(),
            m0: $("select[name='M0']").val(),
            barStandardId: barStandardId && barStandardId.length ? barStandardId : null,
            isGeneric: $("input[name='Generic']").is(":checked")
        };

        // Fetch the revision model data
        $(el).find("input[name$='Revision']").attr("placeholder", "");
        templateModel.fetch({
            cache: false,
            data: data,
            success: function (model) {
                if (model.get("Revision"))
                    // Display the latest revision, if we have one
                    $(el).find("input[name$='Revision']").attr("placeholder", Vision.Utilities.GetDisplayText("Latest") + ": " + model.get("Revision"));
            }
        });
    }

    /// <summary>
    /// Resets the form
    /// </summary>
    var resetFormDisplay = function () {

        // Reset collections and models
        equipmentM0.reset();
        siteVisitReports.reset();
        documentUploadType.set("Name", null);
        siteVisitReport.set("Id", null);;
        $("#DocumentUploadType").selectedIndex = 0;

        // Re-render the views
        documentUploadTypeDropDownViewInstance.render();
        metadataViewInstance.render();

        // Remove all file uploads currently being displayed
        $(".file-uploads-container").find("div:not(.file-upload-add-document)").remove();
    }

    var debugFiles = function () {
        var output = "";
        _.each(files, function (file) {
            if (file.files.length > 0) {
                output += "File name: " + file.files[0].name + "<br>";
                output += "File size: " + file.files[0].size + "<br>";
                output += "<br>";
            }
        });
        var controls = $(".uploader-container").find("input, select");
        _.each($(controls), function (control) {
            output += "Control name: " + $(control).attr("name") + "<br>";
            output += "Control value: " + $(control).val() + "<br>";
            output += "<br>";
        });
        $("#Debug").html(output);
    };

    /// <summary>
    /// Initialises the application
    /// </summary>
    var initialise = function (documentUploadTypesJson, documentTypesJson, documentTypesCpsDocumentTemplateJson, documentTypesTestDocumentTemplateJson, documentTypesTestSessionDocumentTemplateJson, barStandardsJson) {

        // Initialise document upload type model
        documentUploadTypes = new (
            Backbone.Collection.extend({ model: Backbone.Model.extend({ idAttribute: "Id" }) })
        )();
        documentUploadTypes.reset(documentUploadTypesJson);

        // Initialise main model
        var uploaderModelDefinitions = new Vision.Models.Uploader();
        uploaderModel = new uploaderModelDefinitions.ModelDefinition();

        // Initialise Backbone reference data collections

        var documentTypeModelDefinitions = new Vision.Models.DocumentTypes;
        documentTypes = new documentTypeModelDefinitions.CollectionDefinition(documentTypesJson);
        documentTypesCpsDocumentTemplate = new documentTypeModelDefinitions.CollectionDefinition(documentTypesCpsDocumentTemplateJson);
        documentTypesTestDocumentTemplate = new documentTypeModelDefinitions.CollectionDefinition(documentTypesTestDocumentTemplateJson);
        documentTypesTestSessionDocumentTemplate = new documentTypeModelDefinitions.CollectionDefinition(documentTypesTestSessionDocumentTemplateJson);

        var siteVisitReportModelDefinitions = new Vision.Models.SiteVisitReports("uploader/datafiltersitevisitreports");
        siteVisitReports = new siteVisitReportModelDefinitions.CollectionDefinition();

        var equipmentM0ModelDefinitions = new Vision.Models.Equipment("uploader/datafilterequipmentm0");
        equipmentM0 = new equipmentM0ModelDefinitions.CollectionDefinition();

        var barstandardsModelDefinitions = new Vision.Models.BarStandards();
        barStandards = new barstandardsModelDefinitions.CollectionDefinition(barStandardsJson);

        // Initialise Backbone revision data models

        var cpsDocumentTemplateModelDefinitions = new Vision.Models.Documents("uploader/datacpsdocumenttemplaterevision");
        cpsDocumentTemplate = new cpsDocumentTemplateModelDefinitions.ModelDefinition();

        var testDocumentTemplateModelDefinitions = new Vision.Models.Documents("uploader/datatestdocumenttemplaterevision");
        testDocumentTemplate = new testDocumentTemplateModelDefinitions.ModelDefinition();

        var testSessionDocumentTemplateModelDefinitions = new Vision.Models.Documents("uploader/datatestsessiondocumenttemplaterevision");
        testSessionDocumentTemplate = new testSessionDocumentTemplateModelDefinitions.ModelDefinition();

        // Initialise Backbone selection models

        documentUploadType = new Backbone.Model({
            Name: null
        });

        siteVisitReport = new Backbone.Model({
            Id: null
        });

        // Reset files collection
        files = [];
        documentIndex = 0;

        // Initialise Backbone routing
        application = new applicationRouter();
        Backbone.history.start();
    };

    return {
        Initialise: initialise
    };
})();