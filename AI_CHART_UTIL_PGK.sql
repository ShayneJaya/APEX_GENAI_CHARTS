create or replace Package ai_chart_util_pgk IS
    FUNCTION build_genai_payload (p_model_name IN VARCHAR2,p_messages in clob) return clob;
    FUNCTION build_selectai_msg (p_profile_name IN VARCHAR2,p_prompt in varchar2) return clob;
    FUNCTION build_selectai_tbl_metadata (p_table_name IN VARCHAR2,p_schema_owner in varchar2) return clob;

End ai_chart_util_pgk;
/

create or replace PACKAGE BODY ai_chart_util_pgk IS
    
    FUNCTION build_genai_payload (p_model_name IN VARCHAR2,p_messages in clob)
        RETURN CLOB is
        l_payload clob;
    Begin
        apex_json.initialize_clob_output;
            apex_json.open_object;
              apex_json.write('compartmentId', '<ocid1.compartment.oc1.12345>');
              apex_json.open_object('servingMode');
                 apex_json.write('modelId', p_model_name);
                 apex_json.write('servingType', 'ON_DEMAND');
              apex_json.close_object;
              apex_json.open_object('chatRequest');
                 apex_json.write('messages', 'MSG_KEY');
                 apex_json.write('apiFormat', 'GENERIC');
                 apex_json.write('maxTokens', 600);
                 apex_json.write('isStream', false);
                 apex_json.write('numGenerations', 1);
                 apex_json.write('frequencyPenalty', 0);
                 apex_json.write('presencePenalty', 0);
                 apex_json.write('temperature', 0.1);
                 apex_json.write('topP', 1.0);
                 apex_json.write('topK', 1);
                 --add tool calls
              apex_json.close_object;
        apex_json.close_object;
        l_payload := apex_json.get_clob_output;
        apex_json.free_output;

        --l_payload := replace(l_payload,'\n','');
        l_payload := replace(l_payload,'"MSG_KEY"',p_messages);
    return l_payload;
End;

FUNCTION build_selectai_msg (p_profile_name IN VARCHAR2,p_prompt in varchar2)
        RETURN CLOB is
        l_tables_json clob;
        l_result_json clob;

    Begin
    Begin
        Select  b.attribute_value into l_tables_json
        from user_CLOUD_AI_PROFILES a, user_cloud_ai_profile_attributes b
        where a.profile_id = b.profile_id  
        and a.profile_name = p_profile_name
        and b.ATTRIBUTE_NAME = 'object_list';
        EXCEPTION 
            WHEN NO_DATA_FOUND then
                l_tables_json := '[]';
            WHEN TOO_MANY_ROWS THEN
                raise_application_error(-20010,'Multiple Object_list attributes found for profile ' ||p_profile_name);
    END;

    apex_json.initialize_clob_output;

    --initial message
    apex_json.open_array;
     apex_json.open_object;
        apex_json.write('role', 'SYSTEM');
        apex_json.open_array('content');
          apex_json.open_object;
            apex_json.write('type', 'TEXT');
            apex_json.write('text', '### Oracle SQL tables with their properties:');
          apex_json.close_object;
        apex_json.close_array;
      apex_json.close_object;
       --get profile table metadata
    FOR rec IN (
        SELECT jt.owner, jt.name AS table_name
        FROM JSON_TABLE(
          l_tables_json,
          '$[*]' COLUMNS (
            owner VARCHAR2(128) PATH '$.owner',
            name  VARCHAR2(128) PATH '$.name'
          )
        ) jt
      ) LOOP
        apex_json.open_object;
          apex_json.write('role', 'SYSTEM');
          apex_json.open_array('content');
            apex_json.open_object;
              apex_json.write('type', 'TEXT');
              apex_json.write('text', ai_chart_util_pgk.build_selectai_tbl_metadata(rec.table_name, rec.owner));
            apex_json.close_object;
          apex_json.close_array;
        apex_json.close_object;
      END LOOP; 
       --USER System Prompt
      apex_json.open_object;
          apex_json.write('role', 'USER');
          apex_json.open_array('content');
            apex_json.open_object;
              apex_json.write('type', 'TEXT');
              apex_json.write('text', '\n\nYou are a JSON-only assistant. For a natural-language chart request, return a JSON object with keys:{"chart_type": "<bar|pie|scatter|pyramid>","title": "<human readable title>","sql": "<A single SELECT statement that returns the required column(s)>"","label1":"<X axis label>","label2":"<Y axis label>"}. 
                                For bar or pie charts: return exactly 2 columns aliased `Label` and `Value` (in that order).
                                \n For scatter charts: return exactly 3 columns **in this exact order**: `label`, `value`, `value2`. `value` is the X numeric value (X axis).`value2` is the Y numeric value (Y axis).`label` is an optional string identifier (e.g., customer name). If the user asked for numeric fields only, `label` may be an id or empty string.
                                \n Return only raw JSON (no markdown, no code fences, no surrounding text). Generate a valid Oracle SQL query. Use only double quotes (") for identifiers, never use backticks (`)
                                Given an input Question, create a syntactically correct Oracle SQL query to run. Pretty print the SQL query. \n - Pay attention to using only the column names that you can see in the schema description.
                                \n - Be careful to not query for columns that do not exist. Also, pay attention to which column is in which table.\n - Please double check that the SQL query you generate is valid for Oracle Database.
                                \n - Consider table name, schema name and column name to be case sensitive and enclose in double quotes.  - Only use the tables listed below. 
                                \n - If the table definition includes the table owner, you should include both the owner name and user-qualified table name in the Oracle SQL. - DO NOT keep empty lines in the middle of the Oracle SQL.
                                \n - DO NOT write anything else except the Oracle SQL.\n - Always use table alias and easy to read column aliases. \n\nFor string comparisons in WHERE clause, CAREFULLY check if any string in the question is in DOUBLE QUOTES, and follow the rules: 
                                \n - If a string is in DOUBLE QUOTES, use case SENSITIVE comparisons with NO UPPER() function.
                                \n - If a string is not in DOUBLE QUOTES, use case INSENSITIVE comparisons by using UPPER() function around both operands of the string comparison.
                                \nNote: These rules apply strictly to string comparisons in the WHERE clause and do not affect column names, table names, or other query components.\n\nQuestion:'||p_prompt);
            apex_json.close_object;
          apex_json.close_array;
        apex_json.close_object;
      apex_json.close_array;

      l_result_json := apex_json.get_clob_output;
      apex_json.free_output;
      

  
    return l_result_json;
End;


FUNCTION build_selectai_tbl_metadata (p_table_name IN VARCHAR2,p_schema_owner in varchar2)
        RETURN CLOB is
        l_metadata clob;
    Begin
        SELECT '--''' || t.comments || ''' # CREATE TABLE "' || c.owner || '"."' || c.table_name || '" (' ||
       LISTAGG(
         '"' || c.column_name || '" ' || c.data_type ||
         CASE
           WHEN c.data_type IN ('VARCHAR2', 'CHAR') THEN '(' || c.data_length || ')'
           WHEN c.data_type IN ('NUMBER') AND (c.data_precision IS NOT NULL AND c.data_scale IS NOT NULL)
             THEN '(' || c.data_precision || ',' || c.data_scale || ')'
           WHEN c.data_type IN ('NUMBER') AND (c.data_precision IS NOT NULL AND c.data_scale IS NULL)
             THEN '(' || c.data_precision || ')'
           ELSE ''
         END ||
         CASE
           WHEN col.comments IS NOT NULL THEN ' ''' || REPLACE(col.comments, '''', '''''') || ''''
           ELSE ''
         END,
         ', '
       ) WITHIN GROUP (ORDER BY c.column_id)
       || ')'
into l_metadata
    FROM all_tab_columns c
    JOIN all_tab_comments t
      ON c.owner = t.owner AND c.table_name = t.table_name
    LEFT JOIN all_col_comments col
      ON c.owner = col.owner AND c.table_name = col.table_name AND c.column_name = col.column_name
    WHERE UPPER(c.owner) = UPPER(p_schema_owner)
      AND UPPER(c.table_name) = UPPER(p_table_name)
    GROUP BY t.comments, c.owner, c.table_name;

    return l_metadata;
End;

end ai_chart_util_pgk;
/
