
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Saving important parameters
	PathToTemplates = Parameters.PathToTemplates;
	Template = Parameters.ConfigurationFile;
	// Filling the action template list and attempting to set action parameters:
	// if the text contains "<dump", setting the "Prompt for path to dump" flag,
	// if the text contains "<log", setting the "Prompt for path to TL files" flag.
	ActionsToPerform.Add("PathToDump", NStr("en = 'Prompt for path to dump storage directory';ru = 'Запрашивать путь к каталогу хранения дампов'"), ?(StrOccurrenceCount(Template, "<dump") > 0 , True, False));
	ActionsToPerform.Add("PathToTL", NStr("en = 'Prompt for path to technological log file storage directory';ru = 'Запрашивать путь к каталогу хранения файлов технологического журнала'"), ?(StrOccurrenceCount(Template, "<log") > 0 , True, False));
	// Generating the automatic template details
	TemplateName = "Created on " + CurrentDate();
	TemplateDetails = TrimR(""+ ?(StrOccurrenceCount(Template, "<log") > 0 , NStr("en = 'Contains settings for creating the technological log.';ru = 'Содержит настройки создания технологического журнала.'"), "") + " " +
			TemplateDetails + ?(StrOccurrenceCount(Template, "<dump") > 0 , NStr("en = 'Contains settings for creating dumps.';ru = 'Содержит настройки создания дампов.'"), "") + " " +
			TemplateDetails + ?(StrOccurrenceCount(Template, "<leaks") > 0 , NStr("en = 'Contains settings for controlling memory leaks in the configuration.';ru = 'Содержит настройки контроля утечек памяти в конфигурации.'"), "") + " " +
			TemplateDetails + ?(StrOccurrenceCount(Template, "<mem") > 0 , NStr("en='Contains settings for controlling memory leaks on the server.'ru = 'Содержит настройки контроля утечек памяти на сервере.'"), "") + " " +
			TemplateDetails + ?(StrOccurrenceCount(Template, "<defaultlog") > 0 , NStr("en = 'Contains default settings for the technological log.';ru = 'Содержит настройки технологического журнала по умолчанию.'"), "") + " " +
			TemplateDetails + ?(StrOccurrenceCount(Template, "<system") > 0 , NStr("en = 'Contains settings for the system events.';ru = 'Содержит настройки системных событий.'"), ""));
EndProcedure
&AtClient
Procedure OKCommand(Command)
	Var Document, Counter, Action, FullMask, FileName, File;
	// Preparing the template text
	Document = New TextDocument;
	Document.SetText(Template);
	Counter = 1;
	Document.InsertLine(Counter, "Name:"); Counter = Counter + 1;
	Document.InsertLine(Counter, StrReplace(TemplateName, Chars.LF, "")); Counter = Counter + 1;
	Document.InsertLine(Counter, "Details:"); Counter = Counter + 1;
	Document.InsertLine(Counter, StrReplace(TemplateDetails, Chars.LF, "")); Counter = Counter + 1;
	If ActionsToPerform[0].Check Or ActionsToPerform[1].Check Then
		Document.InsertLine(Counter, "Actions:"); Counter = Counter + 1;
		For Each Action In ActionsToPerform Do
			If Action.Check Then
				Document.InsertLine(Counter, Action.Value); Counter = Counter + 1;
			EndIf;
		EndDo;
	EndIf;
	Document.InsertLine(Counter, "Template:"); Counter = Counter + 1;
	// Getting the next template file name
	FullMask = PathToTemplates + "config%.lct";
	Counter = 1;
	While True Do
		FileName = StrReplace(FullMask, "%", Format(Counter, "NG=0"));
		File = New File(FileName);
		If File.Exist() Then
			Counter = Counter + 1;
			Continue;
		EndIf;
		Break;
	EndDo;
	Document.Write(FileName);
	Close(DialogReturnCode.OK);
EndProcedure
