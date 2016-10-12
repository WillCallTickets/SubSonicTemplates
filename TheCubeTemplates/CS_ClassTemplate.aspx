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

    TableSchema.TableColumnCollection cols = tbl.Columns;
    string className = tbl.ClassName;
    string thisPK = null;
    string varPK = null;
    string varPKType = null;
    if(tbl.PrimaryKey != null)
    {
        thisPK = tbl.PrimaryKey.PropertyName;
        varPK = tbl.PrimaryKey.ArgumentName;
        varPKType = Utility.GetVariableType(tbl.PrimaryKey.DataType, tbl.PrimaryKey.IsNullable, lang);
    }
    const bool showGenerationInfo = false;

    string baseClass = tbl.Provider.TableBaseClass;
    string collectionBaseClass = String.Format("List<{0}>", className);

    if (baseClass == "RepositoryRecord" || baseClass == "ActiveRecord")
    {
        string baseSuffix;

        if (tbl.Provider.TableBaseClass == "RepositoryRecord")
        {
            baseSuffix = "IRecordBase";
            collectionBaseClass = String.Format("RepositoryList<{0}, {0}Collection>", className);
        }
        else
        {
            baseSuffix = "IActiveRecord";
            collectionBaseClass = String.Format("ActiveList<{0}, {0}Collection>", className);
        }
        baseClass += String.Format("<{0}>, {1}", className, baseSuffix);
    }

    %>

<%
    if(showGenerationInfo)
    {%>
 //Generated on <%=DateTime.Now.ToString()%> by <%=Environment.UserName%>
<%
    }%>
<%
    if(thisPK != null)
    {
%>
namespace <%=provider.GeneratedNamespace%>
{
	/// <summary>
	/// Strongly-typed collection for the <%=className%> class.
	/// </summary>
    [Serializable]
	public partial class <%=className%>Collection : <%=collectionBaseClass%>
	{	   
		public <%=className%>Collection() {}
        
        /// <summary>
		/// Filters an existing collection based on the set criteria. This is an in-memory filter
		/// Thanks to developingchris for this!
        /// </summary>
        /// <returns><%=className%>Collection</returns>
		public <%=className%>Collection Filter()
        {
            for (int i = this.Count - 1; i > -1; i--)
            {
                <%=className%> o = this[i];
                foreach (SubSonic.Where w in this.wheres)
                {
                    bool remove = false;
                    System.Reflection.PropertyInfo pi = o.GetType().GetProperty(w.ColumnName);
                    if (pi.CanRead)
                    {
                        object val = pi.GetValue(o, null);
                        switch (w.Comparison)
                        {
                            case SubSonic.Comparison.Equals:
                                if (!val.Equals(w.ParameterValue))
                                {
                                    remove = true;
                                }
                                break;
                        }
                    }

                    if (remove)
                    {
                        this.Remove(o);
                        break;
                    }
                }
            }
            return this;
        }
		
		
	}

	/// <summary>
	/// This is an ActiveRecord class which wraps the <%=tableName%> table.
	/// </summary>
	[Serializable]
	public partial class <%=className%> : <%=baseClass%>
	{
		#region .ctors and Default Settings
		
		public <%=className%>()
		{
		  SetSQLProps();
		  InitSetDefaults();
		  MarkNew();
		}
		
		private void InitSetDefaults() { SetDefaults(); }
		
		public <%=className%>(bool useDatabaseDefaults)
		{
			SetSQLProps();
			if(useDatabaseDefaults)
				ForceDefaults();
			MarkNew();
		}

        <%
        if(tbl.Provider.TableBaseClass == "ActiveRecord")
        {%>
		public <%=className%>(object keyID)
		{
			SetSQLProps();
			InitSetDefaults();
			LoadByKey(keyID);
		}
		 
		public <%=className%>(string columnName, object columnValue)
		{
			SetSQLProps();
			InitSetDefaults();
			LoadByParam(columnName,columnValue);
		}
		<%
        }%>
		protected static void SetSQLProps() { GetTableSchema(); }
		
		#endregion
		
		#region Schema and Query Accessor	
		public static Query CreateQuery() { return new Query(Schema); }
		public static TableSchema.Table Schema
		{
			get
			{
				if (BaseSchema == null)
					SetSQLProps();
				return BaseSchema;
			}
		}
		
		private static void GetTableSchema() 
		{
			if(!IsSchemaInitialized)
			{
				//Schema declaration
				TableSchema.Table schema = new TableSchema.Table("<%=tableName%>", TableType.Table, DataService.GetInstance("<%=providerName%>"));
				schema.Columns = new TableSchema.TableColumnCollection();
				schema.SchemaName = @"<%=tbl.SchemaName%>";
				//columns
				<%
        foreach(TableSchema.TableColumn col in cols)
        {
            string varName = "col" + col.ArgumentName;
%>
				TableSchema.TableColumn <%=varName%> = new TableSchema.TableColumn(schema);
				<%=varName%>.ColumnName = "<%=col.ColumnName%>";
				<%=varName%>.DataType = DbType.<%=col.DataType%>;
				<%=varName%>.MaxLength = <%=col.MaxLength%>;
				<%=varName%>.AutoIncrement = <%=col.AutoIncrement.ToString().ToLower()%>;
				<%=varName%>.IsNullable = <%=col.IsNullable.ToString().ToLower()%>;
				<%=varName%>.IsPrimaryKey = <%=col.IsPrimaryKey.ToString().ToLower()%>;
				<%=varName%>.IsForeignKey = <%=col.IsForeignKey.ToString().ToLower()%>;
				<%=varName%>.IsReadOnly = <%=col.IsReadOnly.ToString().ToLower()%>;
				<%
            if(!String.IsNullOrEmpty(col.DefaultSetting))
%>
						<%=varName%>.DefaultSetting = @"<%=col.DefaultSetting%>";
				<%
            if(col.IsForeignKey)%>
					<%=varName%>.ForeignKeyTableName = "<%=col.ForeignKeyTableName%>";
				schema.Columns.Add(<%=varName%>);
				<%
        }
%>
				BaseSchema = schema;

				//add this schema to the provider
				//so we can query it later
				DataService.Providers["<%=providerName%>"].AddSchema("<%=tableName%>",schema);
			}
		}
		#endregion
		
		#region Props

		<%
        bool useNullables = tbl.Provider.GenerateNullableProperties;
        foreach(TableSchema.TableColumn col in cols)
        {
            string propName = col.PropertyName;
            string varType = Utility.GetVariableType(col.DataType, false, lang);
            string nullableVarType = Utility.GetVariableType(col.DataType, col.IsNullable, lang);

            if(useNullables || Utility.IsMatch(varType, nullableVarType))
            {
%>  
		[XmlAttribute("<%=propName%>")]
		[Bindable(true)]
		public <%=nullableVarType%> <%=propName%> 
		{
			get { return GetColumnValue[<]<%=nullableVarType%>[>](Columns.<%=col.PropertyName%>); }
			set { SetColumnValue(Columns.<%=col.PropertyName%>, value); }
		}
		<%
            }
            else
            {%>
		
		//private <%=nullableVarType%> prop<%=propName%>;

		[XmlAttribute("<%=propName%>")]
		[Bindable(true)]
		public <%=varType%> <%=propName%> 
		{
			get
			{
			<%=nullableVarType%> prop<%=propName%> = GetColumnValue[<]<%=nullableVarType%>[>](Columns.<%=col.PropertyName%>);
				if (!prop<%=propName%>.HasValue)
					return <%=Utility.GetDefaultValue(col, lang)%>;
				return prop<%=propName%>.Value;
			}
		   set { SetColumnValue(Columns.<%=col.PropertyName%>, value); }
		}
		
		[XmlIgnore]
		public bool <%=propName%>HasValue
		{

			get { return GetColumnValue[<]<%=nullableVarType%>[>]("<%=col.ColumnName%>") != null; }
			set
			{
				<%=nullableVarType%> prop<%=propName%> = GetColumnValue[<]<%=nullableVarType%>[>](Columns.<%=col.PropertyName%>);
				if (!value)
					SetColumnValue(Columns.<%=col.PropertyName%>, null);
				else if (value && !prop<%=propName%>.HasValue)
					SetColumnValue(Columns.<%=col.PropertyName%>, <%=Utility.GetDefaultValue(col, lang)%>);
		   }
		}
		
		<%
            }
        }
%>
		#endregion
		
		<%
        if(tbl.PrimaryKeyTables.Count > 0 && tbl.Provider.TableBaseClass == "ActiveRecord")
        {%>
		#region PrimaryKey Methods		
		
        protected override void SetPrimaryKey(object oValue)
        {
            base.SetPrimaryKey(oValue);
            
            SetPKValues();
        }
        
		<%
            TableSchema.PrimaryKeyTableCollection pkTables = tbl.PrimaryKeyTables;
            if(pkTables != null)
            {
                ArrayList usedMethodNames = new ArrayList();
                foreach(TableSchema.PrimaryKeyTable pk in pkTables)
                {
                    TableSchema.Table pkTbl = DataService.GetSchema(pk.TableName, providerName, TableType.Table);
                    if(pkTbl.PrimaryKey != null && CodeService.ShouldGenerate(pkTbl))
                    {
                        string pkClass = pk.ClassName;
                        string pkClassQualified = provider.GeneratedNamespace + "." + pkClass;
                        string pkMethod = pk.ClassNamePlural;
                        string pkColumn = pkTbl.GetColumn(pk.ColumnName).PropertyName;

                        if(Utility.IsMatch(pkClass, pkMethod))
                        {
                            pkMethod += "Records";
                        }

                        if(pk.ClassName == className)
                        {
                            pkMethod = "Child" + pkMethod;
                        }

                        if(usedMethodNames.Contains(pkMethod))
                        {
                            pkMethod += "From" + className;
                            if(usedMethodNames.Contains(pkMethod))
                            {
                                pkMethod += pkColumn;
                            }
                        }

                        usedMethodNames.Add(pkMethod);

                        if(!String.IsNullOrEmpty(provider.RelatedTableLoadPrefix))
                        {
                            pkMethod = provider.RelatedTableLoadPrefix + pkMethod;
                        }
                        
                        bool methodsNoLazyLoad = !provider.GenerateRelatedTablesAsProperties && !provider.GenerateLazyLoads;
                        bool methodsLazyLoad = !provider.GenerateRelatedTablesAsProperties && provider.GenerateLazyLoads;
                        bool propertiesNoLazyLoad = provider.GenerateRelatedTablesAsProperties && !provider.GenerateLazyLoads;
                        bool propertiesLazyLoad = provider.GenerateRelatedTablesAsProperties && provider.GenerateLazyLoads;

                        if(methodsNoLazyLoad)
                        {
%>
		public <%=pkClassQualified%>Collection <%=pkMethod%>()
		{
			return new <%=pkClassQualified%>Collection().Where(<%=pkTbl.ClassName%>.Columns.<%=pkColumn%>, <%=tbl.PrimaryKey.PropertyName%>).Load();
		}
<%
                        }
                        else if(methodsLazyLoad)
                        {
%>
		private <%=pkClassQualified%>Collection col<%=pkMethod%>;
		public <%=pkClassQualified%>Collection <%=pkMethod%>()
		{
			if(col<%=pkMethod%> == null)
			{
				col<%=pkMethod%> = new <%= pkClassQualified%>Collection().Where(<%=pkTbl.ClassName%>.Columns.<%=pkColumn%>, <%=tbl.PrimaryKey.PropertyName%>).Load();
				col<%=pkMethod%>.ListChanged += new ListChangedEventHandler(col<%=pkMethod%>_ListChanged);
			}

			return col<%=pkMethod%>;
		}
				
		void col<%=pkMethod%>_ListChanged(object sender, ListChangedEventArgs e)
		{
            if (e.ListChangedType == ListChangedType.ItemAdded)
            {
		        // Set foreign key value
		        col<%=pkMethod%>[e.NewIndex].<%= pkColumn%> = <%= thisPK%>;
				col<%=pkMethod%>.ListChanged += new ListChangedEventHandler(col<%=pkMethod%>_ListChanged);
            }
		}

<%
                        }
                        else if(propertiesNoLazyLoad)
                        {
%>
		public <%=pkClassQualified%>Collection <%=pkMethod%>
		{
			get { return new <%=pkClassQualified%>Collection().Where(<%=pkTbl.ClassName%>.Columns.<%=pkColumn%>, <%=tbl.PrimaryKey.PropertyName%>).Load(); }
		}
<%
                        }
                        else if(propertiesLazyLoad)
                        {
%>		
		private <%=pkClassQualified%>Collection col<%=pkMethod%>;
		public <%=pkClassQualified%>Collection <%=pkMethod%>
		{
			get
			{
				if(col<%=pkMethod%> == null)
				{
					col<%=pkMethod%> = new <%= pkClassQualified%>Collection().Where(<%=pkTbl.ClassName%>.Columns.<%=pkColumn%>, <%=tbl.PrimaryKey.PropertyName%>).Load();
					col<%=pkMethod%>.ListChanged += new ListChangedEventHandler(col<%=pkMethod%>_ListChanged);
				}

				return col<%=pkMethod%>;			
			}
			set 
			{ 
					col<%=pkMethod%> = value; 
					col<%=pkMethod%>.ListChanged += new ListChangedEventHandler(col<%=pkMethod%>_ListChanged);
			}
		}
		
		void col<%=pkMethod%>_ListChanged(object sender, ListChangedEventArgs e)
		{
		    if (e.ListChangedType == ListChangedType.ItemAdded)
		    {
		        // Set foreign key value
		        col<%=pkMethod%>[e.NewIndex].<%= pkColumn%> = <%= thisPK%>;
		    }
		}
		<%
                        }
                    }
                }
            }
%>
		#endregion
		<%
        }
%>
			
		<%
        if(tbl.ForeignKeys.Count > 0 && tbl.Provider.TableBaseClass == "ActiveRecord")
        {%>
		#region ForeignKey Properties
		<%
            TableSchema.ForeignKeyTableCollection fkTables = tbl.ForeignKeys;

            if(fkTables != null)
            {
                ArrayList usedPropertyNames = new ArrayList();
                foreach(TableSchema.ForeignKeyTable fk in fkTables)
                {
                    TableSchema.Table fkTbl = DataService.GetSchema(fk.TableName, providerName, TableType.Table);
                    if(CodeService.ShouldGenerate(fkTbl))
                    {
                        string fkClass = fk.ClassName;
                        string fkClassQualified = provider.GeneratedNamespace + "." + fkClass;
                        string fkMethod = fk.ClassName;
                        string fkID = tbl.GetColumn(fk.ColumnName).PropertyName;
                        string fkColumnID = fk.ColumnName;
                        

                        //it's possible this table is "relatin to itself"
                        //check to make sure the class names are not the same
                        //if they are, use the fk columnName
                        if(fk.ClassName == className)
                        {
                            fkMethod = "Parent" + fk.ClassName;
                        }

                        if(usedPropertyNames.Contains(fk.ClassName))
                        {
                            fkMethod += "To" + fkID;
                        }

                        if(tbl.GetColumn(fkMethod) != null)
                        {
                            fkMethod += "Record";
                        }
%>
		/// <summary>
		/// Returns a <%=fkClass%> ActiveRecord object related to this <%=className%>
		/// 
		/// </summary>
		private <%=fkClassQualified%> <%=fkMethod%>
		{
			get { return <%=fkClassQualified%>.FetchByID(this.<%=fkID%>); }
			set { SetColumnValue("<%=fkColumnID%>", value.<%=fkTbl.PrimaryKey.PropertyName%>); }
		}

        //set up an alternate mechanism to avoid a database call
		private <%=fkClassQualified%> _<%=fkMethod.ToLower()%>record = null;
		
		public <%=fkClassQualified%> <%=fkMethod%>Record
		{
		    get
            {
                if (_<%=fkMethod.ToLower()%>record == null)
                {
                    _<%=fkMethod.ToLower()%>record = new <%=fkClassQualified%>();
                    _<%=fkMethod.ToLower()%>record.CopyFrom(this.<%=fkMethod%>);
                }

                return _<%=fkMethod.ToLower()%>record;
            }
            set
            {
                if(value != null && _<%=fkMethod.ToLower()%>record == null)
			        _<%=fkMethod.ToLower()%>record = new <%=fkClassQualified%>();
                
                SetColumnValue("<%=fkColumnID%>", value.<%=fkTbl.PrimaryKey.PropertyName%>);
                _<%=fkMethod.ToLower()%>record.CopyFrom(value);                
            }
		}



		
		<%
                        usedPropertyNames.Add(fk.ClassName);
                    }
                }
            }
%>
		#endregion
		<%
        }
        else
        {%>
		//no foreign key tables defined (<%=tbl.ForeignKeys.Count.ToString()%>)
		<%
        }%>
		
		<%
        if(tbl.ManyToManys.Count > 0 && tbl.Provider.TableBaseClass == "ActiveRecord")
        {%>
		#region Many To Many Helpers
		<%
            TableSchema.ManyToManyRelationshipCollection mm = tbl.ManyToManys;
            if(mm != null)
            {
                ArrayList usedConstraints = new ArrayList();
                foreach(TableSchema.ManyToManyRelationship m in mm)
                {
                    TableSchema.Table fkSchema = DataService.GetSchema(m.ForeignTableName, providerName, TableType.Table);
                    if(fkSchema != null && !usedConstraints.Contains(fkSchema.ClassName) && CodeService.ShouldGenerate(fkSchema) &&
                       CodeService.ShouldGenerate(m.MapTableName, m.Provider.Name))
                    {
                        usedConstraints.Add(fkSchema.ClassName);
                        string fkClass = fkSchema.ClassName;
                        string fkClassQualified = provider.GeneratedNamespace + "." + fkClass;
                        string mapParameter = Utility.PrefixParameter(m.MapTableLocalTableKeyColumn, provider);
                        string getSql = "SELECT * FROM " + fkSchema.QualifiedName +
                                        SqlFragment.INNER_JOIN + Utility.QualifyTableName(m.SchemaName, m.MapTableName, provider) +
                                        SqlFragment.ON + Utility.QualifyColumnName(m.ForeignTableName, m.ForeignPrimaryKey, provider) + SqlFragment.EQUAL_TO +
                                        Utility.QualifyColumnName(m.MapTableName, m.MapTableForeignTableKeyColumn, provider) +
                                        SqlFragment.WHERE + Utility.QualifyColumnName(m.MapTableName, m.MapTableLocalTableKeyColumn, provider) + SqlFragment.EQUAL_TO +
                                        mapParameter;
                        string deleteSql = "DELETE FROM " + Utility.QualifyTableName(m.SchemaName, m.MapTableName, provider) +
                                           SqlFragment.WHERE + Utility.QualifyColumnName(m.MapTableName, m.MapTableLocalTableKeyColumn, provider) + SqlFragment.EQUAL_TO +
                                           mapParameter;
                        string varFKType = Utility.GetVariableType(fkSchema.PrimaryKey.DataType, fkSchema.PrimaryKey.IsNullable, lang);
%>
		 
		public <%=fkClassQualified%>Collection Get<%=fkClass%>Collection() { return <%=className%>.Get<%=fkClass%>Collection(this.<%=thisPK%>); }
		public static <%=fkClassQualified%>Collection Get<%=fkClass%>Collection(<%=varPKType%> <%=varPK%>)
		{
		    SubSonic.QueryCommand cmd = new SubSonic.QueryCommand("<%=getSql%>", <%=className%>.Schema.Provider.Name);
			cmd.AddParameter("<%=mapParameter%>", <%=varPK%>, DbType.<%=DataService.GetSchema(m.MapTableName, providerName).GetColumn(m.MapTableLocalTableKeyColumn).DataType.ToString()%>);
			IDataReader rdr = SubSonic.DataService.GetReader(cmd);
			<%=fkClass%>Collection coll = new <%=fkClass%>Collection();
			coll.LoadAndCloseReader(rdr);
			return coll;
		}
		
		public static void Save<%=fkClass%>Map(<%=varPKType%> <%=varPK%>, <%=fkClass%>Collection items)
		{
			QueryCommandCollection coll = new SubSonic.QueryCommandCollection();

			//delete out the existing
			QueryCommand cmdDel = new QueryCommand("<%=deleteSql%>", <%=className%>.Schema.Provider.Name);
			cmdDel.AddParameter("<%=mapParameter%>", <%=varPK%>, DbType.<%=DataService.GetSchema(m.MapTableName, providerName).GetColumn(m.MapTableLocalTableKeyColumn).DataType.ToString()%>);
			coll.Add(cmdDel);
			DataService.ExecuteTransaction(coll);
			foreach (<%=fkClass%> item in items)
			{
				<%=m.ClassName%> var<%=m.ClassName%> = new <%=m.ClassName%>();
				var<%=m.ClassName%>.SetColumnValue("<%=m.MapTableLocalTableKeyColumn%>", <%=varPK%>);
				var<%=m.ClassName%>.SetColumnValue("<%=m.MapTableForeignTableKeyColumn%>", item.GetPrimaryKeyValue());
				var<%=m.ClassName%>.Save();
			}
		}

		public static void Save<%=fkClass%>Map(<%=varPKType%> <%=varPK%>, System.Web.UI.WebControls.ListItemCollection itemList) 
		{
			QueryCommandCollection coll = new SubSonic.QueryCommandCollection();

			//delete out the existing
			 QueryCommand cmdDel = new QueryCommand("<%=deleteSql%>", <%=className%>.Schema.Provider.Name);
			cmdDel.AddParameter("<%=mapParameter%>", <%=varPK%>, DbType.<%=DataService.GetSchema(m.MapTableName, providerName).GetColumn(m.MapTableLocalTableKeyColumn).DataType.ToString()%>);
			coll.Add(cmdDel);
			DataService.ExecuteTransaction(coll);

			foreach (System.Web.UI.WebControls.ListItem l in itemList) 
			{
				if (l.Selected) 
				{
					<%=m.ClassName%> var<%=m.ClassName%> = new <%=m.ClassName%>();
					var<%=m.ClassName%>.SetColumnValue("<%=m.MapTableLocalTableKeyColumn%>", <%=varPK%>);
					var<%=m.ClassName%>.SetColumnValue("<%=m.MapTableForeignTableKeyColumn%>", l.Value);
					var<%=m.ClassName%>.Save();
				}
			}
		}

		public static void Save<%=fkClass%>Map(<%=varPKType%> <%=varPK%> , <%=varFKType%>[] itemList) 
		{
			QueryCommandCollection coll = new SubSonic.QueryCommandCollection();

			//delete out the existing
			 QueryCommand cmdDel = new QueryCommand("<%=deleteSql%>", <%=className%>.Schema.Provider.Name);
			cmdDel.AddParameter("<%=mapParameter%>", <%=varPK%>, DbType.<%=DataService.GetSchema(m.MapTableName, providerName).GetColumn(m.MapTableLocalTableKeyColumn).DataType.ToString()%>);
			coll.Add(cmdDel);
			DataService.ExecuteTransaction(coll);

			foreach (<%=varFKType%> item in itemList) 
			{
				<%=m.ClassName%> var<%=m.ClassName%> = new <%=m.ClassName%>();
				var<%=m.ClassName%>.SetColumnValue("<%=m.MapTableLocalTableKeyColumn%>", <%=varPK%>);
				var<%=m.ClassName%>.SetColumnValue("<%=m.MapTableForeignTableKeyColumn%>", item);
				var<%=m.ClassName%>.Save();
			}
		}
		
		public static void Delete<%=fkClass%>Map(<%=varPKType%> <%=varPK%>) 
		{
			QueryCommand cmdDel = new QueryCommand("<%=deleteSql%>", <%=className%>.Schema.Provider.Name);
			cmdDel.AddParameter("<%=mapParameter%>", <%=varPK%>, DbType.<%=DataService.GetSchema(m.MapTableName, providerName).GetColumn(m.MapTableLocalTableKeyColumn).DataType.ToString()%>);
			DataService.ExecuteQuery(cmdDel);
		}

		<%
                    }
                }
            }
%>
		#endregion
		<%
        }
        else
        {%>
		//no ManyToMany tables defined (<%=tbl.ManyToManys.Count.ToString()%>)
		<%
        }%>
        
        <%
        if(tbl.Provider.TableBaseClass == "ActiveRecord")
        {%>
		#region ObjectDataSource support
		<%
            string insertArgs = String.Empty;
            string updateArgs = String.Empty;
            const string seperator = ",";

            foreach(TableSchema.TableColumn col in cols)
            {
                string propName = col.ArgumentName;
                bool useNullType = useNullables ? col.IsNullable : false;
                string varType = Utility.GetVariableType(col.DataType, useNullType, lang);

                updateArgs += varType + " " + propName + seperator;
                if(!col.AutoIncrement)
                {
                    insertArgs += varType + " " + propName + seperator;
                }
            }
            if(insertArgs.Length > 0)
                insertArgs = insertArgs.Remove(insertArgs.Length - seperator.Length, seperator.Length);
            if(updateArgs.Length > 0)
                updateArgs = updateArgs.Remove(updateArgs.Length - seperator.Length, seperator.Length);
%>
		
		/// <summary>
		/// Inserts a record, can be used with the Object Data Source
		/// </summary>
		public static void Insert(<%=insertArgs%>)
		{
			<%=className%> item = new <%=className%>();
			<%
            foreach(TableSchema.TableColumn col in cols)
            {
                if(!col.AutoIncrement)
                {%>
			item.<%=col.PropertyName%> = <%=col.ArgumentName%>;
			<%
                }
            }
%>
		
			if (System.Web.HttpContext.Current != null)
				item.Save(System.Web.HttpContext.Current.User.Identity.Name);
			else
				item.Save(System.Threading.Thread.CurrentPrincipal.Identity.Name);
		}
		
		/// <summary>
		/// Updates a record, can be used with the Object Data Source
		/// </summary>
		public static void Update(<%=updateArgs%>)
		{
			<%=className%> item = new <%=className%>();
			<%
            foreach(TableSchema.TableColumn col in cols)
            {%>
				item.<%=col.PropertyName%> = <%=col.ArgumentName%>;
			<%
            }
%>
			item.IsNew = false;
			if (System.Web.HttpContext.Current != null)
				item.Save(System.Web.HttpContext.Current.User.Identity.Name);
			else
				item.Save(System.Threading.Thread.CurrentPrincipal.Identity.Name);
		}

		#endregion
        <%
        }%>
        
        
        #region Typed Columns
        <%
        for(int i = 0; i < cols.Count; i++)
        {%>
        
        public static TableSchema.TableColumn <%=cols[i].PropertyName%>Column
        {
            get { return Schema.Columns[<%=i%>]; }
        }
        
        <%
        }%>
        
        #endregion

		#region Columns Struct
		public struct Columns
		{
			<%
        foreach(TableSchema.TableColumn col in cols)
        {%> public static string <%=col.PropertyName%> = @"<%=col.ColumnName%>";
			<%
        }%>			
		}
		#endregion
		
		#region Update PK Collections
		
<%
    if (tbl.PrimaryKeyTables.Count > 0 && tbl.Provider.TableBaseClass == "ActiveRecord")
    {
        %>
        public void SetPKValues()
        {
<%
        TableSchema.PrimaryKeyTableCollection pkTables = tbl.PrimaryKeyTables;
        if (pkTables != null)
        {
            ArrayList usedMethodNames = new ArrayList();
            foreach (TableSchema.PrimaryKeyTable pk in pkTables)
            {
                TableSchema.Table pkTbl = DataService.GetSchema(pk.TableName, providerName, TableType.Table);
                if (pkTbl.PrimaryKey != null && CodeService.ShouldGenerate(pkTbl))
                {
                    string pkClass = pk.ClassName;
                    string pkClassQualified = provider.GeneratedNamespace + "." + pkClass;
                    string pkMethod = pk.ClassNamePlural;
                    string pkColumn = pkTbl.GetColumn(pk.ColumnName).PropertyName;

                    if (Utility.IsMatch(pkClass, pkMethod))
                    {
                        pkMethod += "Records";
                    }

                    if (pk.ClassName == className)
                    {
                        pkMethod = "Child" + pkMethod;
                    }

                    if (usedMethodNames.Contains(pkMethod))
                    {
                        pkMethod += "From" + className;
                        if (usedMethodNames.Contains(pkMethod))
                        {
                            pkMethod += pkColumn;
                        }
                    }

                    usedMethodNames.Add(pkMethod);

                    if (!String.IsNullOrEmpty(provider.RelatedTableLoadPrefix))
                    {
                        pkMethod = provider.RelatedTableLoadPrefix + pkMethod;
                    }

                    bool methodsNoLazyLoad = !provider.GenerateRelatedTablesAsProperties && !provider.GenerateLazyLoads;
                    bool methodsLazyLoad = !provider.GenerateRelatedTablesAsProperties && provider.GenerateLazyLoads;
                    bool propertiesNoLazyLoad = provider.GenerateRelatedTablesAsProperties && !provider.GenerateLazyLoads;
                    bool propertiesLazyLoad = provider.GenerateRelatedTablesAsProperties && provider.GenerateLazyLoads;

                    if (methodsLazyLoad || propertiesLazyLoad)
                    {
%>
                if (col<%=pkMethod%> != null)
                {
                    foreach (<%=pkClassQualified%> item in col<%=pkMethod%>)
                    {
                        if (item.<%=pkColumn%> != <%=thisPK%>)
                        {
                            item.<%=pkColumn%> = <%=thisPK%>;
                        }
                    }
               }
		<%
    }
}
}
}
        %>}<%
}
%>

        #endregion
    
        #region Deep Save
		
<%
    if (tbl.PrimaryKeyTables.Count > 0 && tbl.Provider.TableBaseClass == "ActiveRecord")
    {
        %>
        public void DeepSave()
        {
            Save();
            
<%
        TableSchema.PrimaryKeyTableCollection pkTables = tbl.PrimaryKeyTables;
        if (pkTables != null)
        {
            ArrayList usedMethodNames = new ArrayList();
            foreach (TableSchema.PrimaryKeyTable pk in pkTables)
            {
                TableSchema.Table pkTbl = DataService.GetSchema(pk.TableName, providerName, TableType.Table);
                if (pkTbl.PrimaryKey != null && CodeService.ShouldGenerate(pkTbl))
                {
                    string pkClass = pk.ClassName;
                    string pkClassQualified = provider.GeneratedNamespace + "." + pkClass;
                    string pkMethod = pk.ClassNamePlural;
                    string pkColumn = pkTbl.GetColumn(pk.ColumnName).PropertyName;

                    if (Utility.IsMatch(pkClass, pkMethod))
                    {
                        pkMethod += "Records";
                    }

                    if (pk.ClassName == className)
                    {
                        pkMethod = "Child" + pkMethod;
                    }

                    if (usedMethodNames.Contains(pkMethod))
                    {
                        pkMethod += "From" + className;
                        if (usedMethodNames.Contains(pkMethod))
                        {
                            pkMethod += pkColumn;
                        }
                    }

                    usedMethodNames.Add(pkMethod);

                    if (!String.IsNullOrEmpty(provider.RelatedTableLoadPrefix))
                    {
                        pkMethod = provider.RelatedTableLoadPrefix + pkMethod;
                    }

                    bool methodsNoLazyLoad = !provider.GenerateRelatedTablesAsProperties && !provider.GenerateLazyLoads;
                    bool methodsLazyLoad = !provider.GenerateRelatedTablesAsProperties && provider.GenerateLazyLoads;
                    bool propertiesNoLazyLoad = provider.GenerateRelatedTablesAsProperties && !provider.GenerateLazyLoads;
                    bool propertiesLazyLoad = provider.GenerateRelatedTablesAsProperties && provider.GenerateLazyLoads;

                    if (methodsLazyLoad || propertiesLazyLoad)
                    {
%>
                if (col<%=pkMethod%> != null)
                {
                    col<%=pkMethod%>.SaveAll();
               }
		<%
    }
}
}
}
        %>}<%
}
%>

        #endregion
	}
}
<%
    }
    else
    {
%>
// The class <%= className %> was not generated because <%= tableName %> does not have a primary key.
<% } %>