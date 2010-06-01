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
                $(".facts").append("<li>" + data.content + "</li>");
                $(".facts").children(":last").hide().slideDown("fast", function() {
                    $(".facts").children(":last").css("display", "");
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
                else if (data.err)
                    $("#flash").html(data.err);
            }, 
            "json"
        );
    });

    $(".facts,.child_facts").droppable({
        accept: function(draggable) {
            return draggable.parent().attr("id") != $(this).attr("id");
        }, 
        drop: function(event, ui) {
            var fact = ui.draggable;
            var oldCategory = fact.parent();
            var newCategory = $(this);
            if (oldCategory.attr("id") != newCategory.attr("id")) {
                fact.detach();
                newCategory.append(fact);
                newCategory.children(":last").hide().slideDown("fast", function() {
                    newCategory.children(":last").css({
                        display: "", 
                        left: "", 
                        top: ""
                    });
                });
                $.post(
                    "/fact/move/" + fact.attr("id"), 
                    { old_category: oldCategory.attr("id"), 
                      new_category: newCategory.attr("id") }, 
                    function(data) {
                        if (data.err)
                            $("#flash").html(data.err);
                    }, 
                    "json"
                );
            }
        }
    });
    $(".facts li,.child_facts li").draggable({ revert: "invalid" });

});

