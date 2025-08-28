declare
    l_response clob;
    l_sql clob;

    l_prompt varchar2(4000);
    l_cursor NUMBER := dbms_sql.open_cursor;
   
    l_model_name varchar2(2000) := '<MODEL_NAME>';
    l_messages clob;
    l_payload clob;
begin

-- ENABLE DEBUG
apex_debug.enable(apex_debug.c_log_level_info);


    l_messages := ai_chart_util_pgk.build_selectai_msg('<YOUR+PROFILE_NAME',:P2_PROMPT);
    APEX_DEBUG.MESSAGE(p_message => 'l_messages'||l_messages);
    l_payload := ai_chart_util_pgk.build_genai_payload(l_model_name,l_messages); 

      apex_web_service.set_request_headers(
        p_name_01 => 'Content-Type',
        p_value_01 => 'application/json',
        p_name_02 => 'User-Agent',
        p_value_02 => 'APEX',
        p_reset => false,
        p_skip_if_exists => true
      );
  
      l_response := apex_web_service.make_rest_request(
        p_url => 'https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/chat',
        p_http_method => 'POST',
        p_body => l_payload,
        p_credential_static_id => '<OCI_CREDENTAILS>'
      );

    l_response := JSON_VALUE(l_response,'$.chatResponse.choices[0].message.content[0].text');
    
    l_response := RTRIM(l_response);
    


    APEX_UTIL.SET_SESSION_STATE('P2_RAW_JSON',l_response);
    APEX_UTIL.SET_SESSION_STATE('P2_AI_SQL',json_VALUE(l_response,'$.sql'));
    APEX_UTIL.SET_SESSION_STATE('P2_CHART_TYPE',json_VALUE(l_response,'$.chart_type'));
    APEX_UTIL.SET_SESSION_STATE('P2_CHART_TITLE',json_VALUE(l_response,'$.title'));
    APEX_UTIL.SET_SESSION_STATE('P2_LABEL_1',json_VALUE(l_response,'$.label1'));
    APEX_UTIL.SET_SESSION_STATE('P2_LABEL_2',json_VALUE(l_response,'$.label2'));
   


   
   



end;
