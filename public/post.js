function _search(action) {
    var f = document.forms['search'];
    f.method = "GET";
    f.action = action + "/" + f.elements["keyword"].value;
    f.submit();
    return true;
}

function post(form_name, action) {
    var f = document.forms[form_name];
    f.method = "POST";
    f.action = action;
    f.submit();
    return true;
}
