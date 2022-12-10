local netname = NetProps.GetPropString(activator, "m_szNetname")
SetFakeClientConVarValue(activator, "name", netname)