<%@ Page Language="C#"%>
<%@ Import namespace="SubSonic.Utilities"%>
<%@ Import Namespace="SubSonic" %>
<%@ Import Namespace="System.Data" %>

<%
    const string providerName = "#PROVIDER#";
    ICodeLanguage language = new CSharpCodeLanguage();
	DataProvider provider = DataService.GetInstance(providerName);
    System.Collections.Generic.List<StoredProcedure> spList = DataService.GetSPSchemaCollection(providerName) ;
	ArrayList classStoredProcedures = new ArrayList();
	
%>
namespace <%=provider.GeneratedNamespace %>{

    public partial class <%=provider.SPClassName%>{
        <%foreach (StoredProcedure sp in spList)
{
    if(Utility.IsMatch(sp.TableName, provider.SPClassName))
    {
        //load up a the params
        string argList = String.Empty;
        bool isFirst = true;
        foreach(StoredProcedure.Parameter p in sp.Parameters)
        {
            if(!isFirst)
            {
                argList += ", ";
            }
            isFirst = false;
			// allow nullable types for SP parms - Thanks Jeff!
			string pType = Utility.GetVariableType(p.DBType, Utility.IsNullableDbType(p.DBType), language);
            string arg = p.DisplayName;
            argList += pType + " " + arg;
        }
%>
        /// <summary>
        /// Creates an object wrapper for the <%=sp.Name%> Procedure
        /// </summary>
        public static StoredProcedure <%=sp.DisplayName%>(<%=argList%>)
        {
            SubSonic.StoredProcedure sp = new SubSonic.StoredProcedure("<%=sp.Name%>", DataService.GetInstance("<%= providerName %>"), "<%=sp.SchemaName%>");
        	<%
        foreach(StoredProcedure.Parameter p in sp.Parameters)
        {
            string scaleValue = p.Scale.HasValue ? p.Scale.ToString() : "null";
            string precisionValue = p.Precision.HasValue ? p.Precision.ToString() : "null";
            
            if(p.Mode == ParameterDirection.InputOutput)
            {%>
            sp.Command.AddOutputParameter("<%=p.QueryParameter%>", DbType.<%=Enum.GetName(typeof(DbType), p.DBType)%>, <%= scaleValue %>, <%= precisionValue %>);
            <%
            }
			else
            {%>
            sp.Command.AddParameter("<%=p.QueryParameter%>", <%=p.DisplayName%>, DbType.<%=Enum.GetName(typeof(DbType), p.DBType)%>, <%= scaleValue %>, <%= precisionValue %>);
        	<%
            }
        }
%>
            return sp;
        }
        <%
    }
    else
    {
        classStoredProcedures.Add(sp);
    }
}
%>
    }
    <%
		foreach (StoredProcedure sp in classStoredProcedures)
		{
		    string className = sp.TableName;
		    TableSchema.Table tbl = DataService.GetTableSchema(sp.TableName, provider.Name, TableType.Table);
		    if(tbl != null)
		    {
		        className = tbl.ClassName;
		    }
		    string argList = String.Empty;
		    bool isFirst = true;
		    foreach(StoredProcedure.Parameter p in sp.Parameters)
		    {
		        if(!isFirst)
		        {
		            argList += ", ";
		        }
		        isFirst = false;
				// allow nullable types for SP parms - Thanks Jeff!
				string pType = Utility.GetVariableType(p.DBType, Utility.IsNullableDbType(p.DBType), language);
		        string arg = p.DisplayName;
		        argList += pType + " " + arg;
		    }
%>
		public partial class <%=className%>
		{
		/// <summary>
        /// Creates an object wrapper for the <%=sp.Name%> Procedure
        /// </summary>
        public static StoredProcedure <%=sp.DisplayName%>(<%=argList%>){
		
            SubSonic.StoredProcedure sp = new SubSonic.StoredProcedure("<%=sp.Name%>", DataService.GetInstance("<%= providerName %>"), "<%=sp.SchemaName%>");
        	<%
		    foreach(StoredProcedure.Parameter p in sp.Parameters)
		    {
                string scaleValue = p.Scale.HasValue ? p.Scale.ToString() : "null";
                string precisionValue = p.Precision.HasValue ? p.Precision.ToString() : "null";
		        
		        if(p.Mode == ParameterDirection.InputOutput)
		        {%>
            sp.Command.AddOutputParameter("<%=p.QueryParameter%>", DbType.<%=Enum.GetName(typeof(DbType), p.DBType)%>, <%= scaleValue %>, <%= precisionValue %>);
        	    <%
		        }
		        else
		        {%>
            sp.Command.AddParameter("<%=p.QueryParameter%>", <%=p.DisplayName%>, DbType.<%=Enum.GetName(typeof(DbType), p.DBType)%>, <%= scaleValue %>, <%= precisionValue %>);
        	    <%
		        }%>
            <%
		    }%>
            return sp;
        }
		
		}
		<%
		}
%>
}
