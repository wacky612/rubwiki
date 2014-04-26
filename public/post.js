function post(form_name, action) {
    var f = document.forms[form_name];
    f.method = "POST";
    f.action = action;
    f.submit();
    return true;
}
