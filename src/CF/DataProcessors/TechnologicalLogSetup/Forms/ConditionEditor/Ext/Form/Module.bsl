
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var ColumnType, ChoiceList, CurControl;
	// Copying the type table from the parameter to the form
	TypeList = New Structure;
	For Each ColumnType In Parameters.TypeList Do
		TypeList.Insert(ColumnType.Key, ?(TypeOf(ColumnType.Value) = Type("ValueList"), ColumnType.Value.Copy(), ColumnType.Value));
	EndDo;
	// Setting the choice list for the column list
	ChoiceList = Items.Property.ChoiceList;
	For Each Column In Parameters.ColumnList Do
		ChoiceList.Add(Column.Value, Column.Presentation);
	EndDo;
	// Setting editable values
	Property = Parameters.Property;
	Condition = Parameters.Condition;
	Value = Parameters.Value;
	SetConditionList();
	SetValueList();
	// If the parameter of the active item is specified, setting its value
	If Not IsBlankString(Parameters.CurrentColumn) Then
		CurControl = New Structure;
		CurControl.Insert("Property", Items.Property);
		CurControl.Insert("Condition", Items.Condition);
		CurControl.Insert("Value", Items.Value);
		ThisForm.CurrentItem = CurControl[Parameters.CurrentColumn];
	EndIf;
EndProcedure
&AtServer
Procedure SetConditionList()
	Var ColumnType, Result, List;
	If IsBlankString(Property) Then
		Return;
	EndIf;
	ColumnType = "";
	Result = TypeList.Property(Property, ColumnType);
	List = Items.Condition.ChoiceList;
	List.Clear();
	If ColumnType = "b" Or TypeOf(ColumnType) = Type("ValueList") Then
		List.Add("=", NStr("en = '= (Equal to)';ru = '= (Равно)';sys = ''", "en"));
		List.Add("<>", NStr("en = '<> (Not equal to)';ru = '<> (Не равно)';sys = ''", "en"));
	ElsIf ColumnType = "S" Then
		List.Add("=", NStr("en = '= (Equal to)';ru = '= (Равно)';sys = ''", "en"));
		List.Add("<>", NStr("en = '<> (Not equal to)';ru = '<> (Не равно)';sys = ''", "en"));
		List.Add("like", NStr("en = 'like (Like)';ru = 'like (Подобно)'sys = ''", "en"));
	Else
		List.Add("=", NStr("en = '= (Equal to)';ru = '= (Равно)';sys = ''", "en"));
		List.Add("<>", NStr("en = '<> (Not equal to)';ru = '<> (Не равно)';sys = ''", "en"));
		List.Add("<", NStr("en = '< (Less than)';ru = '< (Меньше)';sys = ''", "en"));
		List.Add("<=", NStr("en = '<= (Less than or equal to)';ru = '<= (Меньше или равно)';sys = ''", "en"));
		List.Add(">", NStr("en = '> (Greater than)';ru = '> (Больше)';sys = ''", "en"));
		List.Add(">=", NStr("en = '>= (Greater than or equal to)';ru = '>= (Больше или равно)';sys = ''", "en"));
		List.Add("like", NStr("en = 'like (Like)';ru = 'like (Подобно)';sys = ''", "en"));
	EndIf;
EndProcedure
&AtServer
Procedure SetValueList()
	Var ColumnType, Result, RestrictionItem, ChoiceList;
	If IsBlankString(Property) Then
		Return;
	EndIf;
	ColumnType = "";
	Result = TypeList.Property(Property, ColumnType);
	If Result Then
		ChoiceList = Items.Value.ChoiceList;
		ChoiceList.Clear();
		If TypeOf(ColumnType) = Type("ValueList") Then
			For Each RestrictionItem In ColumnType Do
				ChoiceList.Add(RestrictionItem.Value, RestrictionItem.Presentation);
			EndDo;
			Items.Value.ListChoiceMode = True;
		ElsIf ColumnType = "b" Then
			ChoiceList.Add("1", Format(True));
			ChoiceList.Add("0", Format(False));
			Items.Value.ListChoiceMode = True;
		Else
			Items.Value.ListChoiceMode = False;
		EndIf;
		ChoiceList.SortByPresentation();
	EndIf;
EndProcedure
&AtServerNoContext
Function GenerateChoiceData(Text, Val SearchList)
	Var ChoiceData, ChoiceItem, Value, Presentation;
	ChoiceData = New ValueList;
	For Each ChoiceItem In SearchList Do
		Value = ChoiceItem.Value;
		Presentation = StrReplace(ChoiceItem.Presentation, Chars.LF, " ");
		If Find(Value, Text) <> 0 Or Find(Lower(Presentation), Text) <> 0 Then
			ChoiceData.Add(Value, Presentation + " (" + StrReplace(Value, "_", ":") + ")");
		EndIf;
		If ChoiceData.Count() = 50 Then
			Break;
		EndIf;
	EndDo;
	Return ChoiceData;
EndFunction
&AtClient
Procedure PropertyAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	StandardProcessing = False;
	ChoiceData = GenerateChoiceData(Lower(Text), Item.ChoiceList);
EndProcedure
&AtClient
Procedure PropertyTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChoiceData = GenerateChoiceData(Lower(Text), Item.ChoiceList);
EndProcedure
&AtClient
Procedure PropertyOnChange(Item)
	Var Result;
	SetConditionList();
	SetValueList();
	Result = "";
	If TypeList.Property(Property, Result) And IsBlankString(Condition) Then
		If Result = "s" Then
			Condition = "like";
		Else
			Condition = "=";
		EndIf;
	EndIf;
	Value = "";
EndProcedure
&AtClient
Procedure Ok(Command)
	Var Result;
	Result = New Structure;
	Result.Insert("Property", Property);
	Result.Insert("Condition", Condition);
	Result.Insert("Value", Value);
	Close(Result);
EndProcedure
