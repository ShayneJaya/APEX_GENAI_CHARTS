Declare
    l_query         clob := :P2_AI_SQL;
      l_check       boolean := false;
    l_cursor NUMBER := dbms_sql.open_cursor;
Begin

  if apex_collection.collection_exists('AI_CHART') then
        apex_collection.delete_collection('AI_CHART');
    end if;
  DBMS_SQL.PARSE (l_cursor, l_query, DBMS_SQL.native);
     APEX_COLLECTION.CREATE_COLLECTION_FROM_QUERY (
        p_collection_name => 'AI_CHART', 
        p_query => l_query,
        p_generate_md5 => 'YES');
   EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Error: '||l_query);
               apex_error.add_error(
            p_message           => 'SQL parse failed: ' || SUBSTR(SQLERRM, 1, 2000),
            p_display_location  => apex_error.c_inline_in_notification
          );
End;

