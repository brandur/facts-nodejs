$().ready(function() {

    $("#category_form").ajaxForm({
        dataType: "json", 
        resetForm: true, 
        success: function(data) {
            if (data.err === undefined) {
                $("#categories").append('<li><a href="/category/' + data.slug + '" title="Go to ' + data.name + '">' + data.name + '</a></li>');
                $("#categories").children(":last").hide().slideDown("fast", function() {
                    $("#categories").children(":last").css("display", "");
                });
            } else {
                $("#flash").html(data.err);
            }
        }
    });

    $("#fact_form").ajaxForm({
        dataType: "json", 
        resetForm: true, 
        success: function(data) {
            if (data.err === undefined) {
                $("#facts").append("<li>" + data.content + "</li>");
                $("#facts").children(":last").hide().slideDown("fast", function() {
                    $("#facts").children(":last").css("display", "");
                });
            } else {
                $("#flash").html(data.err);
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

