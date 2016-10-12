<%@ Page Language="C#" %>
<%@ Import namespace="SubSonic.Utilities"%>
<%@ Import Namespace="SubSonic" %>
<%
    //The data we need
	const string providerName = "#PROVIDER#";
	const string tableName = "#TABLE#";
	TableSchema.Table tbl = DataService.GetSchema(tableName, providerName, TableType.Table);
	DataProvider provider = DataService.Providers[providerName];
    ICodeLanguage lang = new CSharpCodeLanguage();
    
    //The main vars we need
    TableSchema.TableColumnCollection cols = tbl.Columns;
    TableSchema.TableColumn[] keys = cols.GetPrimaryKeys();
    const bool showGenerationInfo = false;
  
%>

<% if(showGenerationInfo)
   { %>
 //Generated on <%=DateTime.Now.ToString() %> by <%=Environment.UserName %>
<% }  %>
<%
    if(keys.Length > 0)
    {
%>
namespace <%=provider.GeneratedNamespace %>
{
    /// <summary>
    /// Controller class for <%=tbl.Name %>
    /// </summary>
    [System.ComponentModel.DataObject]
    public partial class <%=tbl.ClassName %>Controller
    {
        // Preload our schema..
        <%=tbl.ClassName%> thisSchemaLoad = new <%=tbl.ClassName%>();

        private string userName = String.Empty;
        protected string UserName
        {
            get
            {
				if (userName.Length == 0) 
				{
    				if (System.Web.HttpContext.Current != null)
    				{
						userName=System.Web.HttpContext.Current.User.Identity.Name;
					}
					else
					{
						userName=System.Threading.Thread.CurrentPrincipal.Identity.Name;
					}
				}
				return userName;
            }
        }

        [DataObjectMethod(DataObjectMethodType.Select, true)]
        public <%=tbl.ClassName%>Collection FetchAll()
        {
            <%=tbl.ClassName%>Collection coll = new <%=tbl.ClassName%>Collection();
            Query qry = new Query(<%=tbl.ClassName%>.Schema);
            coll.LoadAndCloseReader(qry.ExecuteReader());
            return coll;
        }

        [DataObjectMethod(DataObjectMethodType.Select, false)]
        public <%=tbl.ClassName%>Collection FetchByID(object <%=tbl.PrimaryKey.PropertyName%>)
        {
            <%=tbl.ClassName%>Collection coll = new <%=tbl.ClassName%>Collection().Where("<%=tbl.PrimaryKey.ColumnName %>", <%=tbl.PrimaryKey.PropertyName%>).Load();
            return coll;
        }
		
		[DataObjectMethod(DataObjectMethodType.Select, false)]
        public <%=tbl.ClassName%>Collection FetchByQuery(Query qry)
        {
            <%=tbl.ClassName%>Collection coll = new <%=tbl.ClassName%>Collection();
            coll.LoadAndCloseReader(qry.ExecuteReader()); 
            return coll;
        }

        [DataObjectMethod(DataObjectMethodType.Delete, true)]
        public bool Delete(object <%=tbl.PrimaryKey.PropertyName%>)
        {
            return (<%=tbl.ClassName%>.Delete(<%=tbl.PrimaryKey.PropertyName%>) == 1);
        }

        [DataObjectMethod(DataObjectMethodType.Delete, false)]
        public bool Destroy(object <%=tbl.PrimaryKey.PropertyName%>)
        {
            return (<%=tbl.ClassName%>.Destroy(<%=tbl.PrimaryKey.PropertyName%>) == 1);
        }
        
        <%
            string deleteArgs = String.Empty;
            string whereArgs = String.Empty;

            string deleteDelim = String.Empty;
            string whereDelim = String.Empty;
			bool useNullables = tbl.Provider.GenerateNullableProperties;
            foreach (TableSchema.TableColumn key in keys)
            {
                string propName = key.PropertyName;
				bool useNullType = useNullables ? key.IsNullable : false;
                string varType = Utility.GetVariableType(key.DataType, useNullType, lang);

                deleteArgs += deleteDelim + varType + " " + propName;
                deleteDelim = ",";

                whereArgs += whereDelim + "(\"" + propName + "\", " + propName + ")";
                whereDelim = ".AND";
                
            }
            // add this delete method if the table has multiple keys
            if (keys.Length > 1)
            {
        %>
        
        [DataObjectMethod(DataObjectMethodType.Delete, true)]
        public bool Delete(<%=deleteArgs%>)
        {
            Query qry = new Query(<%=tbl.ClassName%>.Schema);
            qry.QueryType = QueryType.Delete;
            qry.AddWhere<%=whereArgs%>;
            qry.Execute();
            return (true);
        }        

       
    	<%
            }
			string insertArgs = String.Empty;
			string updateArgs = String.Empty;
			const string seperator = ",";

			foreach (TableSchema.TableColumn col in cols)
			{
				string propName = col.PropertyName;
				bool useNullType = useNullables ? col.IsNullable : false;
				string varType = Utility.GetVariableType(col.DataType, useNullType, lang);

				updateArgs += varType + " " + propName + seperator;
				if (!col.AutoIncrement)
				{
					insertArgs += varType + " " + propName + seperator;
				}
			}
			if (insertArgs.Length > 0)
				insertArgs = insertArgs.Remove(insertArgs.Length - seperator.Length, seperator.Length);
			if (updateArgs.Length > 0)
				updateArgs = updateArgs.Remove(updateArgs.Length - seperator.Length, seperator.Length);
%>
    	
	    /// <summary>
	    /// Inserts a record, can be used with the Object Data Source
	    /// </summary>
        [DataObjectMethod(DataObjectMethodType.Insert, true)]
	    public void Insert(<%=insertArgs%>)
	    {
		    <%=tbl.ClassName %> item = new <%= tbl.ClassName %>();
		    <% 
		    foreach (TableSchema.TableColumn col in cols) {
                if (!col.AutoIncrement) { 
            %>
            item.<%=col.PropertyName%> = <%=col.PropertyName%>;
            <%
                }
              } 
            %>
	    
		    item.Save(UserName);
	    }

    	
	    /// <summary>
	    /// Updates a record, can be used with the Object Data Source
	    /// </summary>
        [DataObjectMethod(DataObjectMethodType.Update, true)]
	    public void Update(<%=updateArgs%>)
	    {
		    <%=tbl.ClassName%> item = new <%=tbl.ClassName %>();
	        item.MarkOld();
	        item.IsLoaded = true;
		    <% 
		    foreach (TableSchema.TableColumn col in cols) 
			{
				%>
			item.<%=col.PropertyName%> = <%=col.PropertyName%>;
				<%
			} 
            %>
	        item.Save(UserName);
	    }

    }

}
<%
    }
    else
    {
%>
// The class <%= tbl.ClassName %>Controller was not generated because <%= tableName %> does not have a primary key.
<% } %>