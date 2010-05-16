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

    $("a.fact_delete").click(function() {
        var item = $(this).parent();
        $.post(
            "/fact/" + item.attr("id"), 
            { "_method": "delete" }, 
            function(data) {
                if (data.msg === "OK")
                    item.slideUp();
            }, 
            "json"
        );
    });

});

