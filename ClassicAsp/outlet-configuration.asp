<!-- #include virtual="/common/std_includes.asp" -->

<%
    ' Declare constants
    ' Ordinal positions of outlet configuration data
    Const ocId = 0
    Const ocOutlet = 1
    Const ocConductorConfiguration_id = 2
    Const ocEquipmentRating_id = 3
    Const ocTapOffBoxPins_id = 4
    Const ocTapOffBoxWires_id = 5
    Const template = "#template#"
    Const templateAppend = "#template-append#"

    ' Get the id of the associated PS line
    ps_id = Request.QueryString("ps_id")

    ' Get the production schedule details
    sql = "SELECT w.[WNumber] + ' - ' + et.[equipment_type_name], q.[BarStandard_id] "
    sql = sql & "FROM [dbo].[t2_prodsched] ps "
    sql = sql & "LEFT JOIN [dbo].[qmf_tb] q ON q.[qmf_id] = ps.[PS_qmf_id] "
    sql = sql & "LEFT JOIN [dbo].[tr_equipment_type] et ON et.[equipment_type_id] = q.[qmf_equip_id] "
    sql = sql & "LEFT JOIN [dbo].[WorksBook] w ON w.[WorksID] = q.[qmf_JB_id] "
    sql = sql & "WHERE ps.[PS_id] = " & ps_id
    ary_data = getData(sql)
    psDetails = ary_data(0, 0)
    barStandardId = ary_data(1, 0)

    ' Has the form been submitted?
    ' If so, process the form input instead of displaying the page
    If Request.Form("submit") <> "" Then
        ps_id = Request.Form("ps_id")
        ProcessForm()
    End If

    ' Get the outlet configuration data for the PS line
    rowsDatabase = getOutletConfigurations()
    If IsArray(rowsDatabase) Then
        outletConfigurations = rowsDatabase
	Else
        ' If no outlet configurations exist, create a default empty set of 1 outlet
        Dim outletConfigurations(5, 0)
    End If
%>

<html>

    <head>
        <title>Outlet Configuration</title>
        <link rel="stylesheet" type="text/css" href="../common/styles/default.css">
        <link rel="stylesheet" type="text/css" href="../common/styles/jobbook.css">
        <link rel="stylesheet" media="all" type="text/css" href="/common/jquery/jqueryui/1.9.2/themes/smoothness/jquery-ui-1.9.2.custom.min.css" />
        <link rel="stylesheet" media="all" type="text/css" href="../jscripts/chosen/chosen.css" />
        <link rel="stylesheet" media="all" type="text/css" href="../jscripts/chosen/chosenImage.css" />
        <script type="text/javascript" src="/common/jquery/jquery-2.2.4.min.js"></script>
        <script type="text/javascript" src="/common/jquery/jqueryui/1.9.2/jquery-ui-1.9.2.custom.min.js"></script>
        <script type="text/javascript" src="../jscripts/chosen/chosen.jquery.js"></script>
        <script type="text/javascript" src="../jscripts/chosen/chosenImage.jquery.js"></script>
    </head>

    <body>
        <h1 class="outlet-configuration">Outlet Configuration</h1>
        <h2 class="outlet-configuration"><% =psDetails %></h2>
        <form method="post" action="outlet-configuration.asp?ps_id=<% =ps_id %>">
            <input type="hidden" name="ps_id" value="<% =ps_id %>" />
            <table class="outlet-configuration">
                <thead>
                    <tr>
                        <th>Outlet</th>
                        <th>Phase</th>
                        <th>Rating</th>
                        <%
                        If barStandardId = barStandardUL Then
                        %>
                        <th>Poles</th>
                        <th>Wires (Pins)</th>
                        <%
                        End If
                        %>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <%
                        ' Render a template outlet configuration
                        ' This will be hidden, and cloned when we add a new row
                        renderOutletConfiguration(template)

                        ' Render each outlet configuration
                        For i = 0 To UBound(outletConfigurations, 2)
                            renderOutletConfiguration(i + 1)
                        Next
                    %>
                    <tr class="add-outlet">
                        <td colspan="4">
                            <a href="javascript:void(0)" class="outlet-configuration-add">+ add outlet</a>
                        </td>
                    </tr>
                </tbody>
            </table>
            <div class="outlet-configuration-save-cancel">
                <button onclick="javascript:document.form_submit.submit();" name="submit" value="submit">Submit</button>
                <button onclick="self.close();">Cancel</button>
            </div>
        </form>
        
        <script type="text/javascript">
            
            // Initial setup
            jQueryFunctions();
            checkSubmit();

            // Callback function when spawned window closes
            window.onunload = function (e) {
                // Update outlook configuration for PS line
                opener.outletConfigurationCallback(<% =ps_id %>);
            };

            // Add row handler
            $(".outlet-configuration-add").click(function(e) {
                var rows = $(e.target).closest("tr").parent().find("tr.outlet").length;
                // Get and clone the template row
                var tr = $(e.target).closest("tr").parent().find("tr.hidden");
                var clone = $(tr).clone();
                // Update the class of the cloned row, replace the template placeholder with the correct outlet number,
                // and remove the template append string so we can now apply the relevant jQuery functions to the select boxes
                $(clone).removeClass("hidden").addClass("outlet").html($(clone).html().replace(/<% =template %>/g, rows + 1).replace(/<% =templateAppend %>/g, ""));
                // Insert the cloned row before the 'add outlet' row
                var trLast = $(tr).parent().find("tr.add-outlet").last();
                $(trLast).before(clone);
                jQueryFunctions();
            });

            function jQueryFunctions()
            {
                // Apply the relevant jQuery functions to the select boxes with the specified classes
                $(".outlet-configuration-select").chosen({ disable_search: true });
                $(".outlet-configuration-select-image").chosenImage({ disable_search: true });
                // Remove row handler
                $(".outlet-configuration-remove").click(function(e) {
                    var parent = $(e.target).closest("tr").parent();
                    $(e.target).closest("tr").remove();
                    var i = 1;
                    // Update the outlet number for the remaining rows, including in child controls
                    $("tr.outlet").each(function(){
                        $(this).find("td.row-number-display").html(i);
                        $(this).find("input[name^=OutletNumber]").val(i);
                        $(this).find("input[name^=OutletNumber]").attr("name", "OutletNumber" + i);
                        $(this).find("select[name^=ConductorConfiguration]").attr("name", "ConductorConfiguration" + i);
                        $(this).find("select[name^=EquipmentRating]").attr("name", "EquipmentRating" + i);
                        i++;
                    });
                    checkSubmit();
                });
            }

            function checkSubmit()
            {
                // Disables the submit button if any controls do not have a value selected
                var submit = $("button[name=submit]");
                $(submit).prop("disabled", false);
                $("tr.outlet").each(function(){
                    $(this).find("select").each(function() {
                        var val = $(this).val();
                        if (!val || val == "")
                            $(submit).prop("disabled", true);
                    });
                });
            }

        </script>
    </body>

</html>

<%
    Function getOutletConfigurations()

        ' Gets outlet configurations for the PS line
        sql = "SELECT [Id], [Outlet], [ConductorConfiguration_id], [EquipmentRating_id], [TapOffBoxPins_id], [TapOffBoxWires_id] "
        sql = sql & "FROM [dbo].[OutletConfiguration] "
        sql = sql & "WHERE [ProductionSchedule_id] = " & ps_id & " "
        sql = sql & "ORDER BY [Outlet]"
        getOutletConfigurations = getData(sql)

    End Function

    Function renderOutletConfiguration(outletNumber)

        ' Renders the outlet configuration for the specified outlet number

        ' Set classes depending on whether or not this is the template row
        If (outletNumber = template) Then
            rowClass = "hidden"
            selectClassAppend = templateAppend
        Else
            rowClass = "outlet"
            selectClassAppend = ""
        End If        
    
        ' Select lists
        lstEquipmentRating = create_default_list("EquipmentRating", "EquipmentRating" & outletNumber, 1 )
      	lstEquipmentRating = replace(lstEquipmentRating, "name=""", "onChange=""checkSubmit();"" class=""outlet-configuration-select" & selectClassAppend & """ style=""width: 80px;"" name=""")
        lstTapOffBoxPins = create_default_list("TapOffBoxPins", "TapOffBoxPins" & outletNumber, 1 )
      	lstTapOffBoxPins = replace(lstTapOffBoxPins, "name=""", "onChange=""checkSubmit();"" class=""outlet-configuration-select" & selectClassAppend & """ style=""width: 80px;"" name=""")
        lstTapOffBoxWires = create_default_list("TapOffBoxWires", "TapOffBoxWires" & outletNumber, 1 )
      	lstTapOffBoxWires = replace(lstTapOffBoxWires, "name=""", "onChange=""checkSubmit();"" class=""outlet-configuration-select" & selectClassAppend & """ style=""width: 80px;"" name=""")

        ' Conductor Configuration select list
        lstConductorConfiguration =                             "<select onChange=""checkSubmit();"" class=""outlet-configuration-select-image" & selectClassAppend & """ name=""ConductorConfiguration"  & outletNumber & """ style=""width: 60px;"">"
        lstConductorConfiguration = lstConductorConfiguration & "   <option value="""">&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-l1.png"" value=""" & conductorConfigurationL1 & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-l2.png"" value=""" & conductorConfigurationL2 & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-l3.png"" value=""" & conductorConfigurationL3 & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-n.png"" value=""" & conductorConfigurationN & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-e.png"" value=""" & conductorConfigurationE & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-tp.png"" value=""" & conductorConfigurationTP & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-tpn.png"" value=""" & conductorConfigurationTPN & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-xyg.png"" value=""" & conductorConfigurationXYG & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-xyz.png"" value=""" & conductorConfigurationXYZ & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-gxy.png"" value=""" & conductorConfigurationGXY & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-xyw.png"" value=""" & conductorConfigurationXYW & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-gwx.png"" value=""" & conductorConfigurationGWX & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-gxyw.png"" value=""" & conductorConfigurationGXYW & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-gxyz.png"" value=""" & conductorConfigurationGXYZ & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-wxyz.png"" value=""" & conductorConfigurationWXYZ & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-gwxyz.png"" value=""" & conductorConfigurationGWXYZ & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-dpl1l2.png"" value=""" & conductorConfigurationDPL1L2 & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-dpl1l3.png"" value=""" & conductorConfigurationDPL1L3 & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "   <option data-img-src=""/images/outlet-configuration-dpl2l3.png"" value=""" & conductorConfigurationDPL2L3 & """>&nbsp;</option>"
        lstConductorConfiguration = lstConductorConfiguration & "</select>"

        ' Display select lists if this is not the template row
        If (outletNumber <> template) Then

            EquipmentRating_id = outletConfigurations(ocEquipmentRating_id, outletNumber - 1)
            If Len(EquipmentRating_id) > 0 Then
		        EquipmentRating_id = replace(EquipmentRating_id, "{", "")
		        EquipmentRating_id = replace(EquipmentRating_id, "}", "")
	        End If
            lstEquipmentRating = select_value(lstEquipmentRating, EquipmentRating_id)

            ConductorConfiguration_id = outletConfigurations(ocConductorConfiguration_id, outletNumber - 1)
            If Len(ConductorConfiguration_id) > 0 Then
		        ConductorConfiguration_id = replace(ConductorConfiguration_id, "{", "")
		        ConductorConfiguration_id = replace(ConductorConfiguration_id, "}", "")
	        End If
            lstConductorConfiguration = select_value(lstConductorConfiguration, ConductorConfiguration_id)

            TapOffBoxPins_id = outletConfigurations(ocTapOffBoxPins_id, outletNumber - 1)
            If Len(TapOffBoxPins_id) > 0 Then
		        TapOffBoxPins_id = replace(TapOffBoxPins_id, "{", "")
		        TapOffBoxPins_id = replace(TapOffBoxPins_id, "}", "")
	        End If
            lstTapOffBoxPins = select_value(lstTapOffBoxPins, TapOffBoxPins_id)

            TapOffBoxWires_id = outletConfigurations(ocTapOffBoxWires_id, outletNumber - 1)
            If Len(TapOffBoxWires_id) > 0 Then
		        TapOffBoxWires_id = replace(TapOffBoxWires_id, "{", "")
		        TapOffBoxWires_id = replace(TapOffBoxWires_id, "}", "")
	        End If
            lstTapOffBoxWires = select_value(lstTapOffBoxWires, TapOffBoxWires_id)

        End If

        ' Render the outlet configuration
        Response.Write "<tr class=""" & rowClass & """>"
        Response.Write "    <input type=""hidden"" name=""OutletNumber"  & outletNumber & """ value=" & outletNumber & "></input>"
        Response.Write "    <td class=""row-number-display"">" & outletNumber & "</td>"
        Response.Write "    <td>"
        Response.Write lstConductorConfiguration
        Response.Write "    </td>"
        Response.Write "    <td>"
        Response.Write lstEquipmentRating
        Response.Write "    </td>"
        If barStandardId = barStandardUL Then
            Response.Write "    <td>"
            Response.Write lstTapOffBoxPins
            Response.Write "    </td>"
            Response.Write "    <td>"
            Response.Write lstTapOffBoxWires
            Response.Write "    </td>"
        End If
        Response.Write "    <td>"
        Response.Write "        <a href=""javascript:void(0)"" class=""outlet-configuration-remove""><img src=""../images/trash.png"" style=""width: 28px; height: 28px;"" /></a>"
        Response.Write "    </td>"
        Response.Write "</tr>"
  
    End Function

    Function ProcessForm()
        
        ' Processes the form submission

        Set Conn = Server.CreateObject("ADODB.Connection")
        Conn.open strConnect

        ' Delete all existing records
        sql = "DELETE FROM [dbo].[OutletConfiguration] WHERE [ProductionSchedule_id] = " & ps_id
        Conn.Execute(sql)

        ' Recreate all outlet configuration records
        For Each field In Request.Form
            If Instr(field, "OutletNumber") > 0 And Instr(field, template) = 0 Then
                fieldIndex = Replace(field, "OutletNumber", "")
                sql = "INSERT INTO [dbo].[OutletConfiguration] ([ProductionSchedule_id], [Outlet], [ConductorConfiguration_id], [EquipmentRating_id]"
                If barStandardId = barStandardUL Then sql = sql & ",[TapOffBoxPins_id], [TapOffBoxWires_id]"
                sql = sql & ") VALUES (" & ps_id & ", " & Request.Form("OutletNumber" & fieldIndex) & ", '" & Request.Form("ConductorConfiguration" & fieldIndex) & "', '" & Request.Form("EquipmentRating" & fieldIndex) & "'"
                If barStandardId = barStandardUL Then sql = sql & ", '" & Request.Form("TapOffBoxPins" & fieldIndex) & "', '" & Request.Form("TapOffBoxWires" & fieldIndex) & "'"
                sql = sql & ")"
                Conn.Execute(sql)
            End If
        Next

        Conn.Close
        Set Conn = Nothing

        ' Close window
        Response.Write ("<script>self.close();</script>")
        Response.End

    End Function
%>