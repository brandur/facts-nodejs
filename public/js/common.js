$().ready(function() {

    $("#category_form").ajaxForm({
        //clearForm: true, 
        dataType: "json", 
        resetForm: true, 
        success: function(data) {
            if (data.err === undefined) {
                $("#new_result").html(data.slug);
            } else {
                $("#new_result").html(data.err);
            }
        }
    });

    $("#parent_name").autocomplete("/category/search/", {
    });

});

