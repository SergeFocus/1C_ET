
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var DataProcessorObject, Number, TemplateName, Template, NewTemplate, Presentation, Details;
	// Gathering all templates with the "Template*" name that the data processor includes
	DataProcessorObject = FormAttributeToValue("Object");
	Number = 1;
	While True Do
		TemplateName = "Template"+String(Number);
		Try
			Template = DataProcessorObject.GetTemplate(TemplateName);
			Number = Number + 1;
		Except
			// Stop searching once the template is not found for the current number
			Break;
		EndTry;
		// The template has been found, attempting to parse it by the default positions
		NewTemplate = TemplateList.Add();
		NewTemplate.Name = TemplateName;
		Presentation = Template.GetLine(2);
		NewTemplate.Presentation = ?(IsBlankString(Presentation), TemplateName, Presentation);
		Details = Template.GetLine(4);
		NewTemplate.Details = ?(IsBlankString(Details), NewTemplate.Presentation, Details);
		NewTemplate.External = False;
		NewTemplate.Picture = PictureLib.DataCompositionStandardSettings;
	EndDo;
	PathToTemplates = Parameters.PathToTemplates;
EndProcedure
&AtClient
Procedure OnOpen(Cancel)
	Var Document, Files, Presentation, Details, NewTemplate;
#If WebClient Then
	Items.ContextMenuTemplateListDeleteTemplateFromDisk.Enabled = False;
#EndIf
#If ThinClient Then
	// If 1C:Enderprise runs in the thin client mode, searching for the templates in the configuration file directory.
	// Template files have the following name - config*.lct
	// where * is a number substituted during saving.
	If Not IsBlankString(PathToTemplates) Then
		Document = New TextDocument;
		Files = FindFiles(PathToTemplates, "config*.lct", True);
		// Attempting to read all found files, templates may be among them
		For Each File In Files Do
			Document.Read(File.FullName);
			If Lower(Document.GetLine(1)) <> "name:" And Lower(Document.GetLine(1)) <> "details:" Then
				// Considering that the file is a template
				Continue;
			EndIf;
			// The template has been found, attempting to parse it by the default positions
			NewTemplate = TemplateList.Add();
			NewTemplate.Name = File.FullName;
			Presentation = Document.GetLine(2);
			NewTemplate.Presentation = ?(IsBlankString(Presentation), File.BaseName, Presentation);
			Details = Document.GetLine(4);
			NewTemplate.Details = ?(IsBlankString(Details), NewTemplate.Presentation, Details);
			NewTemplate.External = True;
			NewTemplate.Picture = New Picture;
		EndDo;
	EndIf;
#EndIf
	TemplateList.Sort("Presentation");
EndProcedure
&AtClient
Procedure TemplateListChoice(Item, SelectedRow, Field, StandardProcessing)
	Close(Item.CurrentData.Name);
EndProcedure
&AtClient
Procedure Ok(Command)
	Close(Items.TemplateList.CurrentData.Name);
EndProcedure
&AtClient
Procedure DeleteTemplateFromDisk(Command)
	Var TemplateDetails, Text, AsynchronousCall, CallParameters;
#If Not WebClient Then
	// Deleting the template if it is not included into the data processor
	TemplateDetails = Items.TemplateList.CurrentData;
	If TemplateDetails = Undefined Or Not TemplateDetails.External Then
		Return;
	EndIf;
	Text = NStr("en = 'Do you want to delete the ""%1%"" template?'; ru = 'Вы действительно хотите удалить шаблон ""%1%""?'");
	Text = StrReplace(Text, "%1%", TemplateDetails.Presentation);
	CallParameters = New Structure;
	CallParameters.Insert("Name", TemplateDetails.Name);
	CallParameters.Insert("Details", TemplateDetails);
	AsynchronousCall = New NotifyDescription("DeleteTemplateFromDiskCompletion", ThisObject, CallParameters);
	ShowQueryBox(AsynchronousCall, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
#EndIf
EndProcedure
&AtClient
Procedure DeleteTemplateFromDiskCompletion(Result, ExtendedParameters) Export
	If Result = DialogReturnCode.Yes Then
		DeleteFiles(ExtendedParameters.Name);
		TemplateList.Delete(ExtendedParameters.Details);
	EndIf;
EndProcedure
&AtClient
Procedure TemplateListOnActivateRow(Item)
	Var TemplateDetails;
	TemplateDetails = Items.TemplateList.CurrentData;
	If TemplateDetails = Undefined Then
		Return;
	EndIf;
	Items.ContextMenuTemplateListDeleteTemplateFromDisk.Enabled = TemplateDetails.External;
EndProcedure
