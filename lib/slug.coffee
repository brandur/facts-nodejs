exports.toSlug: (str) -> 
    str.toLowerCase().replace(/[^a-z0-9_ ]+/g, "").replace(/[ _]/g, "-")

